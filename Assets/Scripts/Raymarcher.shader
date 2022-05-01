Shader "Unlit/Raymarcher"
{
    Properties {}
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct PrimitiveData
            {
                float3 position;
                float3 scale;
                int type;
                float4 color;
            };

            // Used to hold output to screen if DEBUG is true
            float debug = 0; // for some reason bool doesn't work
            float4 debugOutputColor;

            static const float EPSILON = 0.01f;
            static const float maxDist = 9999.0f;

            // Material properties passed in from C#
            float hFov;
            float vFov;
            StructuredBuffer<PrimitiveData> primitiveBuffer;
            int numPrimitives;
            float4 backgroundColor;
            float4 lightPos;
            float lightIntensity;

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 scrPos : TEXCOORD1;
            };

            // returns x mod y
            float3 modvec(float3 x, float y)
            {
                return x - (y * floor(x / y));
            }

            // Overrides the normal fragment shader output and instead outputs COLOR to the screen
            void setDebugOutput(float4 color)
            {
                debug = 1;
                debugOutputColor = color;
            }

            float sphereSDF(float3 p)
            {
                return length(p) - 1.0;
            }

            float boxSDF(float3 p)
            {
                // return length(max(abs(p)-b,0.0));
                float3 q = abs(p) - 1.0;
                return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
            }

            // source: https://www.shadertoy.com/view/WtfXzj
            float crossSDF(float3 p)
            {
                float3 sample = abs(p);
                float3 d = float3(max(sample.x, sample.y), max(sample.y, sample.z), max(sample.z, sample.x));
                return min(d.x, min(d.y, d.z)) - 1.0;
            }

            // https://lucodivo.github.io/menger_sponge.html
            float mengerSDF(float3 p)
            {
                float distance = boxSDF(p);

                float holeWidth = 1.0 / 3.0;
                for (int i = 0; i < 10; i++)
                {
                    float holeDist = holeWidth * 6.0;
                    float3 q = modvec(p + holeWidth, holeDist) - holeWidth;
                    float distCross = crossSDF(q / holeWidth) * holeWidth;

                    holeWidth = holeWidth / 3.0; // reduce hole size for next iter
                    distance = max(distance, -distCross);
                }

                return distance;
            }

            float sierpinskiSDF(float3 p)
            {
                float Scale = 2.0;
                float Offset = 3.0;

                int n = 0;
                while (n < 15)
                {
                    if (p.x + p.y < 0.0) p.xy = -p.yx; // fold 1
                    if (p.x + p.z < 0.0) p.xz = -p.zx; // fold 2
                    if (p.y + p.z < 0.0) p.zy = -p.yz; // fold 3
                    p = p * Scale - Offset * (Scale - 1.0);
                    n++;
                }
                return length(p) * pow(Scale, -float(n));
            }

            // calls corresponding SDF function based on primitive type of PRIM
            float primitiveSDF(PrimitiveData prim, float3 samplePoint)
            {
                float primSDF;
                // http://jamie-wong.com/2016/07/15/ray-marching-signed-distance-functions/#uniform-scaling
                float3 translated = (samplePoint - prim.position) / prim.scale;
                switch (prim.type)
                {
                // see Primitive.PrimitiveType enum for int to type mapping
                case 0:
                    primSDF = sphereSDF(translated);
                    break;
                case 1:
                    primSDF = boxSDF(translated);
                    break;
                case 2:
                    primSDF = mengerSDF(translated);
                    break;
                case 3:
                    primSDF = crossSDF(translated);
                    break;
                case 4:
                    primSDF = sierpinskiSDF(translated);
                    break;
                default:
                    primSDF = maxDist / prim.scale;
                    break;
                }
                return primSDF * prim.scale;
            }

            // takes min over SDF of all primitives in scene
            float sceneSDF(float3 samplePoint)
            {
                float minSDF = maxDist; // some arbitrarily large value; there's no float.INFINITY
                for (int i = 0; i < numPrimitives; ++i)
                {
                    PrimitiveData prim = primitiveBuffer[i];
                    minSDF = min(minSDF, primitiveSDF(prim, samplePoint));
                }
                return minSDF;
            }

            PrimitiveData closestPrimitive(float3 samplePoint)
            {
                float minSDF = maxDist; // some arbitrarily large value; there's no float.INFINITY
                PrimitiveData closest;
                for (int i = 0; i < numPrimitives; ++i)
                {
                    PrimitiveData prim = primitiveBuffer[i];
                    float primSDF = primitiveSDF(prim, samplePoint);
                    if (primSDF < minSDF)
                    {
                        minSDF = primSDF;
                        closest = prim;
                    }
                }
                return closest;
            }

            // from seb lague
            float3 calcNormal(float3 p, float dx)
            {
                float x = sceneSDF(float3(p.x + dx, p.y, p.z)) - sceneSDF(float3(p.x - dx, p.y, p.z));
                float y = sceneSDF(float3(p.x, p.y + dx, p.z)) - sceneSDF(float3(p.x, p.y - dx, p.z));
                float z = sceneSDF(float3(p.x, p.y, p.z + dx)) - sceneSDF(float3(p.x, p.y, p.z - dx));
                return normalize(float3(x, y, z));
            }

            float4 diffuseShading(float3 intersection, float kd, float4 primitiveColor)
            {
                float r = distance(intersection, lightPos.xyz);
                float3 n = calcNormal(intersection, EPSILON);
                float3 l = normalize(lightPos.xyz - intersection);
                float lightStrength = kd * (lightIntensity / (r * r)) * max(0, dot(n, l));
                return float4(lightStrength * primitiveColor);
            }

            /**
             * Generates ray starting from camera passing through sensor plane at coords returns ray direction
             * Coords are in range [0,1] for both x and y
             */
            float3 generateRayDir(float2 coords)
            {
                // proj 3-1 code courtesy of linda
                // float2 fov = float2(hFov, vFov);
                // float2 fovRad = fov * UNITY_PI / 180;
                // float2 camPos = tan(0.5 * fovRad) * (2 * coords - 1);
                // float3 dir = normalize(mul(unity_CameraToWorld, float4(camPos, 1.0f, 1.0f)).xyz);

                // sebastian lague
                // float4 dirImage = float4(coords, 0, 1);
                // float4 dirCamera = mul(unity_CameraInvProjection, dirImage);
                // float4 dirWorld = mul(unity_CameraToWorld, dirCamera);
                // float3 dir = normalize(dirWorld.xyz);

                // jamie wong
                // float2 xy = _ScreenParams.xy * (coords - 1 / 2);
                // float z = (_ScreenParams.y / 2) / tan(radians(vFov) / 2);
                // float3 dir = normalize(mul(unity_CameraToWorld, float3(xy, z)));

                float2 xy = 2 * coords - 1.5; // screen coordinates in [-1.5, 0.5] range
                // why do we subtract by 1.5 and not 1.0? i came up with 1.5 by pure guesswork
                xy.x *= _ScreenParams.x / _ScreenParams.y; // scale by aspect ratio
                float3 dir = normalize(mul(unity_CameraToWorld, float3(xy, 1)));

                // setDebugOutput(float4(dir.xyz, 1));
                return dir;
            }

            // sample code from jamie wong article
            float4 rayMarch(int maxSteps, float3 dir)
            {
                float depth = 0;
                for (int j = 0; j < maxSteps; ++j)
                {
                    float3 ray = _WorldSpaceCameraPos + depth * dir;
                    float dist = sceneSDF(ray);
                    if (dist < EPSILON)
                    {
                        PrimitiveData closest = closestPrimitive(ray);
                        return diffuseShading(ray, 1.00, closest.color) + 0.2 * closest.color;
                    }
                    depth += dist;
                }
                return backgroundColor;
            }


            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.scrPos = ComputeScreenPos(v.vertex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // https://forum.unity.com/threads/what-does-the-function-computescreenpos-in-unitycg-cginc-do.294470/ 
                float2 screenUV = i.scrPos.xy / i.scrPos.w; // in range [0, 1]
                float3 dir = generateRayDir(screenUV);
                float4 output = rayMarch(32, dir);
                return debug == 1 ? debugOutputColor : output;
            }
            ENDCG
        }
    }
}