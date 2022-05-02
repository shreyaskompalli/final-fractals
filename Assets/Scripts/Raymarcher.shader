Shader "Unlit/Raymarcher"
{
    SubShader
    {
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

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 scrPos : TEXCOORD1;
            };

            // Used to hold output to screen if DEBUG is true
            float debug = 0; // for some reason bool doesn't work
            float4 debugOutputColor;

            // ray marcher parameters
            static const float EPSILON = 0.0003f;
            static const float maxDist = 25.0f;
            static const int maxSteps = 99;

            // Material properties passed in from C#
            float hFov;
            float vFov;
            StructuredBuffer<PrimitiveData> primitiveBuffer;
            int numPrimitives;
            float4 backgroundColor;
            float4 lightPos;
            float lightIntensity;

            // =================================== UTILITIES ===================================

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

            // returns point p rotated around z axis by zRad, then y axis by yRad, then x axis by xRad in radians
            // https://cs184.eecs.berkeley.edu/sp22/lecture/4-46/transforms
            float3 rotatePoint(float3 p, float xRad, float yRad, float zRad)
            {
                float4x4 rX = float4x4(1, 0, 0, 0,
                                       0, cos(xRad), -sin(xRad), 0,
                                       0, sin(xRad), cos(xRad), 0,
                                       0, 0, 0, 1);
                float4x4 rY = float4x4(cos(yRad), 0, sin(yRad), 0,
                                       0, 1, 0, 0,
                                       -sin(yRad), 0, cos(yRad), 0,
                                       0, 0, 0, 1);
                float4x4 rZ = float4x4(cos(zRad), -sin(zRad), 0, 0,
                                       sin(zRad), cos(zRad), 0, 0,
                                       0, 0, 1, 0,
                                       0, 0, 0, 1);
                float4 homogenous = mul(rX, mul(rY, mul(rZ, float4(p, 1))));
                return homogenous.xyz;
            }

            // =================================== SDFs =========================================

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

            // https://lucodivo.github.io/menger_sponge.html for explanation
            // https://iquilezles.org/articles/menger/ for optimized SDF
            float mengerSDF(float3 p)
            {
                float distance = boxSDF(p);

                float crossScale = 1.0;
                for (int i = 0; i < 11; i++)
                {
                    p = rotatePoint(p, _SinTime, _CosTime, 0);
                    float3 a = modvec(p * crossScale, 2.0) - 1.0;
                    crossScale *= 3.0;
                    float3 r = abs(1.0 - 3.0 * abs(a));

                    float da = max(r.x, r.y);
                    float db = max(r.y, r.z);
                    float dc = max(r.z, r.x);
                    float crossDist = (min(da, min(db, dc)) - 1.0) / crossScale;

                    distance = max(distance, crossDist);
                }
                return distance;
            }

            // http://blog.hvidtfeldts.net/index.php/2011/08/distance-estimated-3d-fractals-iii-folding-space/
            float sierpinskiSDF(float3 p)
            {
                float scale = 2.0;
                float offset = 3.0;

                int i = 0;
                while (i < 15)
                {
                    if (p.x + p.y < 0.0) p.xy = -p.yx; // fold 1
                    if (p.x + p.z < 0.0) p.xz = -p.zx; // fold 2
                    if (p.y + p.z < 0.0) p.zy = -p.yz; // fold 3
                    p = p * scale - offset * (scale - 1.0);
                    i++;
                }
                return length(p) * pow(scale, -float(i));
            }

            // http://blog.hvidtfeldts.net/index.php/2011/09/distance-estimated-3d-fractals-v-the-mandelbulb-different-de-approximations/
            float mandelbulbSDF(float3 p)
            {
                float3 z = p;
                float dr = 1.0;
                float r = 0.0;

                for (int i = 0; i < 15; i++)
                {
                    float sinTime = sin(_Time / 8);
                    float power = 10 * abs(sinTime);
                    p = rotatePoint(p, sinTime, sinTime, 0);
                    r = length(z);

                    if (r > 2)
                        break;

                    // convert to polar coordinates
                    float theta = acos(z.z / r);
                    float phi = atan2(z.y, z.x);
                    dr = pow(r, power - 1.0) * power * dr + 1.0;

                    // scale and rotate the point
                    float zr = pow(r, power);
                    theta = theta * power;
                    phi = phi * power;

                    // convert back to cartesian coordinates
                    z = zr * float3(sin(theta) * cos(phi), sin(phi) * sin(theta), cos(theta));
                    z += p;
                }
                return 0.5 * log(r) * r / dr;
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
                case 5:
                    primSDF = mandelbulbSDF(translated);
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

            // =================================== LIGHTING =====================================

            // https://iquilezles.org/articles/normalsSDF/
            float3 calcNormal(float3 p)
            {
                const float2 k = float2(1, -1);
                return normalize(k.xyy * sceneSDF(p + k.xyy * EPSILON) +
                    k.yyx * sceneSDF(p + k.yyx * EPSILON) +
                    k.yxy * sceneSDF(p + k.yxy * EPSILON) +
                    k.xxx * sceneSDF(p + k.xxx * EPSILON));
            }

            float diffuse(float3 intersection, float3 normal, float kd)
            {
                float r = distance(intersection, lightPos.xyz);
                float3 n = normal;
                float3 l = normalize(lightPos.xyz - intersection);
                return kd * (lightIntensity / (r * r)) * max(0, dot(n, l));
            }

            float specular(float3 intersection, float3 normal, float ks, float power)
            {
                float r = distance(intersection, lightPos.xyz);
                float3 v = normalize(_WorldSpaceCameraPos - intersection);
                float3 n = normal;
                float3 l = normalize(lightPos.xyz - intersection);
                float3 h = (v + l) / length(v + l);
                return ks * (lightIntensity / (r * r)) * pow(max(0, dot(n, h)), power);
            }

            float phong(float3 intersection, float3 normal, float ka, float kd, float ks, float specularPower)
            {
                return ka + diffuse(intersection, normal, kd) + specular(intersection, normal, ks, specularPower);
            }

            float ambientOcclusion(float3 intersection, float3 normal, float step_dist, float step_nbr)
            {
                float occlusion = 1.0f;
                while (step_nbr > 0.0)
                {
                    occlusion -= pow(step_nbr * step_dist -
                                     sceneSDF(intersection + normal * step_nbr * step_dist), 2) / step_nbr;
                    step_nbr--;
                }
                return occlusion;
            }

            // =================================== RAY MARCHING ================================

            // sample code from jamie wong article
            float4 rayMarch(int maxSteps, float3 dir)
            {
                float depth = 0;
                for (int j = 0; j < maxSteps && depth < maxDist; ++j)
                {
                    float3 ray = _WorldSpaceCameraPos + depth * dir;
                    float dist = sceneSDF(ray);
                    if (dist < EPSILON)
                    {
                        PrimitiveData closest = closestPrimitive(ray);
                        float3 normal = calcNormal(ray); // value is cached to reduce recomputation
                        float4 finalColor = closest.color;
                        finalColor *= phong(ray, normal, 0.25, 0.5, 0.5, 100);
                        finalColor *= pow(ambientOcclusion(ray, normal, 0.015, 20), 40);
                        // fog effect
                        finalColor = lerp(finalColor, backgroundColor, depth / maxDist);
                        return finalColor;
                    }
                    depth += dist;
                }
                return backgroundColor;
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
                float4 output = rayMarch(maxSteps, dir);
                return debug == 1 ? debugOutputColor : output;
            }
            ENDCG
        }
    }
}