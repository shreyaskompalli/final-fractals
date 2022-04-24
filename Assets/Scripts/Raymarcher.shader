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
            static const float EPSILON = 0.001f;

            // Material properties passed in from C#
            float hFov;
            float vFov;
            StructuredBuffer<PrimitiveData> primitiveBuffer;
            int numPrimitives;

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 scrPos : TEXCOORD1;
            };

            // Overrides the normal fragment shader output and instead outputs COLOR to the screen
            void setDebugOutput(float4 color)
            {
                debug = 1;
                debugOutputColor = color;
            }


            float sphereSDF(float3 p, float3 origin, float radius)
            {
                return distance(p, origin) - radius;
            }

            float boxSDF(float3 p, float3 origin, float3 sideLength)
            {
                // return length(max(abs(p)-b,0.0));
                float3 q = abs(p - origin) - sideLength;
                return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
            }

            float sceneSDF(float3 samplePoint)
            {
                float maxDist = 9999.0f;
                float minSDF = maxDist; // some arbitrarily large value; there's no float.INFINITY
                for (int i = 0; i < numPrimitives; ++i)
                {
                    float primSDF;
                    PrimitiveData prim = primitiveBuffer[i];
                    switch (prim.type)
                    {
                    // see Primitive.PrimitiveType enum for int to type mapping
                    case 0:
                        primSDF = sphereSDF(samplePoint, prim.position, prim.scale);
                        break;
                    case 1:
                        primSDF = boxSDF(samplePoint, prim.position, prim.scale);
                        break;
                    default:
                        primSDF = maxDist;
                        break;
                    }
                    minSDF = min(minSDF, primSDF);
                }
                return minSDF;
            }

            PrimitiveData closestPrimitive(float3 samplePoint)
            {
                float maxDist = 9999.0f;
                float minSDF = maxDist; // some arbitrarily large value; there's no float.INFINITY
                PrimitiveData closest;
                for (int i = 0; i < numPrimitives; ++i)
                {
                    float primSDF;
                    PrimitiveData prim = primitiveBuffer[i];
                    switch (prim.type)
                    {
                    // see Primitive.PrimitiveType enum for int to type mapping
                    case 0:
                        primSDF = sphereSDF(samplePoint, prim.position, prim.scale);
                        break;
                    case 1:
                        primSDF = boxSDF(samplePoint, prim.position, prim.scale);
                        break;
                    default:
                        primSDF = maxDist;
                        break;
                    }
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

            /**
             * Generates ray starting from camera passing through sensor plane at coords returns ray direction
             */
            float3 generateRayDir(float2 coords)
            {
                // proj 3-1 code courtesy of linda
                float2 fov = float2(hFov, vFov);
                float2 fovRad = fov * UNITY_PI / 180;
                float2 camPos = 2 * tan(0.5 * fovRad) * coords - tan(0.5 * fovRad);
                float3 dir = normalize(mul(unity_CameraToWorld, float4(camPos, -1.0f, 1.0f)).xyz);

                // sebastian lague
                // float4 dirImage = float4(coords, 0, 1);
                // float4 dirCamera = mul(unity_CameraInvProjection, dirImage);
                // float4 dirWorld = mul(unity_CameraToWorld, dirCamera);
                // float3 dir = normalize(dirWorld.xyz);

                // jamie wong
                // float2 scaledCoords = coords * _ScreenParams.xy;
                // float2 xy = scaledCoords - _ScreenParams.xy / 2;
                // float z = (_ScreenParams.y / 2) / tan(radians(vFov) / 2);
                // float3 dir = normalize(mul(unity_CameraToWorld, float3(xy, -z)));
                // setDebugOutput(float4(dir.xyz, 1));
                return dir;
            }

            float4 diffuseShading(float3 intersection, float kd, float4 primitiveColor)
            {
                float3 lightPos = float3(2, -3, -10);
                float3 lightIntensity = float3(10, 10, 10);
                float r = distance(intersection, lightPos);
                float3 n = calcNormal(intersection, EPSILON);
                float3 l = normalize(lightPos - intersection);
                float3 rgb = kd * (lightIntensity / (r * r)) * max(0, dot(n, l));
                return float4(rgb * primitiveColor, 1);
                // return float4(rgb, 1);
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
                        // return closest.color;
                        return diffuseShading(ray, 1.00, closest.color);
                    }
                    depth += dist;
                }
                return float4(0, 0, 0, 1);
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