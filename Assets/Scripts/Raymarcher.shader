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
                float3 phongParams; // x = ka, y = kd, z = ks
                // only for fractals
                float2 iterations; // x = min iterations, y = max iterations
                float usesOrbitTrap; // 0 for solid color, anything else for orbit trap
            };

            struct LightData
            {
                float3 position;
                float intensity;
            };

            // SDFs should return more than just the distance, as some data is needed for lighting calcs
            struct Intersection
            {
                float distance;
                PrimitiveData primitive;
                float orbitTrap;
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
            static const float MAX_DIST = 25.0f;
            static const int MAX_STEPS = 99; // some arbitrarily large value; there's no float.INFINITY

            // Material properties passed in from C#
            StructuredBuffer<PrimitiveData> primitiveBuffer;
            StructuredBuffer<LightData> lightBuffer;
            int numPrimitives;
            int numLights;
            float4 backgroundColor;

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

            // Fold a point across a plane defined by a point and a normal
            // The normal should face the side to be reflected
            float3 fold(float3 p, float3 pointOnPlane, float3 planeNormal)
            {
                // Center plane on origin for distance calculation
                float distToPlane = dot(p - pointOnPlane, planeNormal);

                // We only want to reflect if the dist is negative
                distToPlane = min(distToPlane, 0.0);
                // https://math.stackexchange.com/questions/13261/how-to-get-a-reflection-vector
                return p - 2.0 * distToPlane * planeNormal;
            }

            // =================================== COLORING =====================================

            // https://www.shadertoy.com/view/4lK3Dc
            float mengerTrap(float3 p)
            {
                return abs(sin(p.x) - p.y) + abs(sin(p.y) - p.z) + abs(sin(p.z) - p.x);
            }

            float sierpinskiTrap(float3 p)
            {
                return abs(sin(p.x) - p.y) + abs(sin(p.y) - p.z) + abs(sin(p.z) - p.x);
            }
            
            float mandelbulbTrap(float3 p)
            {
                return abs(sin(p.x) - p.y) + abs(sin(p.y) - p.z) + abs(sin(p.z) - p.x);
            }

            // =================================== SDFs =========================================

            float sphereSDF(float3 p)
            {
                return length(p) - 1.0;
            }

            float boxSDF(float3 p)
            {
                return length(max(abs(p) - 1.0, 0.0));
            }

            // source: https://www.shadertoy.com/view/WtfXzj
            float crossSDF(float3 p)
            {
                float3 sample = abs(p);
                float3 d = float3(max(sample.x, sample.y), max(sample.y, sample.z), max(sample.z, sample.x));
                return min(d.x, min(d.y, d.z)) - 1.0;
            }

            // https://www.shadertoy.com/view/Ws23zt
            float tetrahedronSDF(float3 p)
            {
                return (max(abs(p.x + p.y) - p.z, abs(p.x - p.y) + p.z) - 1.0) / sqrt(3.0);
            }

            // https://lucodivo.github.io/menger_sponge.html 
            float mengerSDF(float3 p, int iterations, out float orbitTrap)
            {
                float dist = boxSDF(p);
                orbitTrap = MAX_DIST;

                float scale = 1.0;
                for (int i = 0; i < iterations; ++i)
                {
                    float boxedWidth = 2 / scale;
                    float3 modRay = modvec(p + boxedWidth / 2.0, boxedWidth);
                    orbitTrap = min(orbitTrap, mengerTrap(p));
                    modRay -= boxedWidth / 2.0;
                    modRay *= scale;
                    float crossDist = crossSDF(modRay * 3.0);
                    scale *= 3.0;
                    crossDist /= scale;
                    dist = max(dist, -crossDist);
                }

                return dist;
            }

            // https://www.shadertoy.com/view/wsVBz1
            float sierpinskiSDF(float3 p, int iterations, out float orbitTrap)
            {
                orbitTrap = 0;
                // vertices of a tetrahedron
                const float3 vertices[4] =
                {
                    float3(1.0, 1.0, 1.0),
                    float3(-1.0, 1.0, -1.0),
                    float3(-1.0, -1.0, 1.0),
                    float3(1.0, -1.0, -1.0)
                };

                float scale = 1.0;
                for (int i = 0; i < iterations; i++)
                {
                    // Scale p toward corner vertex, update scale accumulator
                    p -= vertices[0];
                    p *= 2.0;
                    p += vertices[0];

                    scale *= 2.0;

                    // Fold p across each plane
                    for (int j = 1; j <= 3; j++)
                    {
                        // The plane is defined by:
                        // Point on plane: The vertex that we are reflecting across
                        // Plane normal: The direction from said vertex to the corner vertex
                        float3 normal = normalize(vertices[0] - vertices[j]);
                        orbitTrap = min(orbitTrap, p);
                        p = fold(p, vertices[j], normal);
                    }
                }
                // Now that the space has been distorted by the IFS,
                // just return the distance to a tetrahedron
                // Divide by scale accumulator to correct the distance field
                return tetrahedronSDF(p) / scale;
            }

            // http://blog.hvidtfeldts.net/index.php/2011/09/distance-estimated-3d-fractals-v-the-mandelbulb-different-de-approximations/
            float mandelbulbSDF(float3 p, int iterations, out float orbitTrap)
            {
                float3 z = p;
                float dr = 1.0;
                float r = 0.0;
                orbitTrap = MAX_DIST;

                for (int i = 0; i < iterations; i++)
                {
                    float sinTime = sin(_Time[1] / 5);
                    float power = 10 + 8 * sinTime;
                    // p = rotatePoint(p, sinTime, sinTime, 0);
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

                    orbitTrap = min(orbitTrap, mengerTrap(z));
                }
                return 0.5 * log(r) * r / dr;
            }

            // calls corresponding SDF function based on primitive type of PRIM
            Intersection primitiveSDF(PrimitiveData prim, float3 samplePoint)
            {
                float primSDF;
                // http://jamie-wong.com/2016/07/15/ray-marching-signed-distance-functions/#uniform-scaling
                float3 translated = (samplePoint - prim.position) / prim.scale;
                float rayLength = length(samplePoint - _WorldSpaceCameraPos);
                int iterations;
                Intersection output;

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
                    // TODO: find better way get # iterations
                    // # of iterations should decrease with ray length
                    // # of iterations should increase with scale
                    iterations = 12 / lerp(1.5, 4, rayLength / MAX_DIST);
                    iterations = clamp(iterations, prim.iterations.x, prim.iterations.y);
                    primSDF = mengerSDF(translated, iterations, output.orbitTrap);
                    break;
                case 3:
                    iterations = 15 / lerp(1.5, 4, rayLength / MAX_DIST);
                    iterations = clamp(iterations, prim.iterations.x, prim.iterations.y);
                    primSDF = sierpinskiSDF(translated, iterations, output.orbitTrap);
                    break;
                case 4:
                    primSDF = mandelbulbSDF(translated, 4, output.orbitTrap);
                    break;
                default:
                    primSDF = MAX_DIST / prim.scale;
                    break;
                }

                output.distance = primSDF * prim.scale;
                output.primitive = prim;
                return output;
            }

            // takes min over SDF of all primitives in scene
            Intersection sceneIntersection(float3 samplePoint)
            {
                Intersection mintersect;
                mintersect.distance = MAX_DIST;
                mintersect.primitive.color = backgroundColor;

                for (int i = 0; i < numPrimitives; ++i)
                {
                    PrimitiveData prim = primitiveBuffer[i];
                    Intersection isect = primitiveSDF(prim, samplePoint);
                    if (isect.distance < mintersect.distance)
                    {
                        mintersect = isect;
                    }
                }
                return mintersect;
            }

            float sceneSDF(float3 samplePoint)
            {
                return sceneIntersection(samplePoint).distance;
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

            float diffuse(float3 intersection, float3 normal, float3 lightPos, float lightIntensity, float kd)
            {
                float r = distance(intersection, lightPos.xyz);
                float3 n = normal;
                float3 l = normalize(lightPos.xyz - intersection);
                return kd * (lightIntensity / (r * r)) * max(0, dot(n, l));
            }

            float specular(float3 intersection, float3 normal, float3 lightPos, float lightIntensity, float ks,
                           float power)
            {
                float r = distance(intersection, lightPos.xyz);
                float3 v = normalize(_WorldSpaceCameraPos - intersection);
                float3 n = normal;
                float3 l = normalize(lightPos.xyz - intersection);
                float3 h = (v + l) / length(v + l);
                return ks * (lightIntensity / (r * r)) * pow(max(0, dot(n, h)), power);
            }

            // https://cs184.eecs.berkeley.edu/sp22/lecture/6-31/rasterization-pipeline
            float phong(float3 intersection, float3 normal, float ka, float kd, float ks, float specularPower)
            {
                float output = ka;
                for (int i = 0; i < numLights; i++)
                {
                    LightData light = lightBuffer[i];
                    output += diffuse(intersection, normal, light.position, light.intensity, kd);
                    output += specular(intersection, normal, light.position, light.intensity, ks, specularPower);
                }
                return output;
            }

            // https://typhomnt.github.io/teaching/ray_tracing/raymarching_intro/#bonus-effect-ambient-occulsion-
            float ambientOcclusion(float3 intersection, float3 normal, float stepDist, float numSteps, float power)
            {
                float occlusion = 1.0f;
                while (numSteps > 0.0)
                {
                    occlusion -= pow(numSteps * stepDist -
                                     sceneSDF(intersection + normal * numSteps * stepDist), 2) / numSteps;
                    numSteps--;
                }
                return pow(occlusion, power);
            }

            // https://iquilezles.org/articles/rmshadows/
            float softShadow(float3 rayOrigin, float k, float ka)
            {
                float totalShadow = 0;
                float shadowOffset = 10 * EPSILON;
                float ph = EPSILON;
                for (int i = 0; i < numLights; i++)
                {
                    float res = 1;
                    float depth = shadowOffset;
                    int maxShadowSteps = 10;
                    LightData light = lightBuffer[i];
                    float3 dir = normalize(light.position - rayOrigin);
                    for (int j = 0; j < maxShadowSteps && depth < light.intensity; j++)
                    {
                        float dist = sceneSDF(rayOrigin + depth * dir);
                        if (dist < EPSILON)
                        {
                            res = ka;
                            break;
                        }
                        float y = dist * dist / (2 * ph);
                        float d = sqrt(dist * dist - y * y);
                        res = min(res, k * d / max(0, depth - y));
                        ph = dist;
                        depth += dist;
                    }
                    totalShadow += res;
                }
                return clamp(totalShadow, 0, 1);
            }

            // =================================== RAY MARCHING ================================

            // http://jamie-wong.com/2016/07/15/ray-marching-signed-distance-functions/#the-raymarching-algorithm
            float4 rayMarch(float3 dir)
            {
                float depth = 0;
                for (int j = 0; j < MAX_STEPS && depth < MAX_DIST; j++)
                {
                    float3 ray = _WorldSpaceCameraPos + depth * dir;
                    float dist = sceneSDF(ray);

                    if (dist < EPSILON)
                    {
                        Intersection isect = sceneIntersection(ray);
                        PrimitiveData closest = isect.primitive;
                        float3 normal = calcNormal(ray); // value is cached to reduce recomputation
                        float4 finalColor = closest.color;

                        if (closest.usesOrbitTrap != 0)
                        {
                            float ot = isect.orbitTrap;
                            // arbitrary; play around with this
                            finalColor = float4(ot / 2.5, (sin(ot) + 1) / 3.5, (cos(ot) + 1) / 5, 1);
                        }

                        float3 phongParams = closest.phongParams;
                        finalColor *= phong(ray, normal, phongParams[0], phongParams[1], phongParams[2], 100);
                        finalColor *= ambientOcclusion(ray, normal, 0.05, 5, 50);
                        finalColor *= softShadow(ray, 1, phongParams[0]);
                        // fog effect
                        finalColor = lerp(finalColor, backgroundColor, 1.0 * depth / MAX_DIST);
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
                float2 xy = 2 * coords - 1.5; // screen coordinates in [-1.5, 0.5] range
                // why do we subtract by 1.5 and not 1.0? i came up with 1.5 by pure guesswork
                xy.x *= _ScreenParams.x / _ScreenParams.y; // scale by aspect ratio
                float3 dir = normalize(mul(unity_CameraToWorld, float3(xy, 1)));
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
                float4 output = rayMarch(dir);
                return debug == 1 ? debugOutputColor : output;
            }
            ENDCG
        }
    }
}