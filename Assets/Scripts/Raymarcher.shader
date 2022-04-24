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

            // Used to hold output to screen if DEBUG is true
            float debug = 0; // for some reason bool doesn't work
            float4 debugOutputColor;

            // Material properties passed in from C#j
            float hFov;
            float vFov;

            const float EPSILON = 0.001f;

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 scrPos : TEXCOORD1;
            };

            void setDebugOutput(float4 color)
            {
                debug = 1;
                debugOutputColor = color;
            }

            float sphereSDF(float3 p, float3 origin, float radius)
            {
                return distance(p, origin) - radius;
            }

            float sceneSDF(float3 samplePoint)
            {
                return sphereSDF(samplePoint, float3(-1, -1, 2.8), 1.8);
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
                return mul(unity_CameraToWorld, normalize(float4(camPos, -1.0f, 1.0f))).xyz;

                // sebastian lague
                // float4 dirImage = float4(coords, 0, 1);
                // float4 dirCamera = mul(unity_CameraInvProjection, dirImage);
                // float4 dirWorld = mul(unity_CameraToWorld, dirCamera);
                // return normalize(dirWorld.xyz);

                // jamie wong
                // float2 xy = coords - _ScreenParams.xy / 2;
                // float z = (_ScreenParams.y / 2) / tan(radians(vFov) / 2);
                // return normalize(mul(unity_CameraToWorld, float3(xy, -z)));
            }

            // sample code from jamie wong article
            float4 rayMarch(int maxSteps, float3 dir)
            {
                float depth = 0;
                for (int j = 0; j < maxSteps; ++j)
                {
                    float dist = sceneSDF(_WorldSpaceCameraPos + depth * dir);
                    // if (j == 1) setDebugOutput(float4(dist / 10, 0, 0, 1));
                    if (dist < EPSILON) return float4(1, 0, 0, 1);
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
                float2 screenPos = screenUV * _ScreenParams.xy;
                float3 dir = generateRayDir(screenPos);
                float4 output = rayMarch(32, dir);
                return debug == 1 ? debugOutputColor : output;
            }
            ENDCG
        }
    }
}