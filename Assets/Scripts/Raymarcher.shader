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
                return distance(p, origin + _WorldSpaceCameraPos.xyz) - radius;
            }

            float sceneSDF(float3 samplePoint)
            {
                return sphereSDF(samplePoint, float3(0, 0, 3), 2);
            }

            /**
             * Generates ray starting from camera passing through sensor plane at (x, y) returns ray direction
             */
            float3 generateRayDir(float2 coords)
            {
                // float hFovRad = (hFov * UNITY_PI) / 180;
                // float vFovRad = (vFov * UNITY_PI) / 180;
                // float xcam = 2 * tan(0.5 * hFovRad) * x - tan(0.5 * hFovRad);
                // float ycam = 2 * tan(0.5 * vFovRad) * y - tan(0.5 * vFovRad);
                // return mul(unity_CameraToWorld, normalize(float4(xcam, ycam, -1.0f, 1.0f))).xyz;
                float4 dirImage = float4(coords, 0, 1);
                float4 dirCamera = mul(unity_CameraInvProjection, dirImage);
                float4 dirWorld = mul(unity_CameraToWorld, dirCamera);
                return normalize(dirWorld.xyz);
            }

            // sample code from jamie wong article
            float4 rayMarch(int maxSteps, float3 dir)
            {
                float depth = 0;
                for (int j = 0; j < maxSteps; ++j)
                {
                    float dist = sceneSDF(_WorldSpaceCameraPos + depth * dir);
                    if (j == 1) setDebugOutput(float4(dist / 10, 0, 0, 1));
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
                float3 dir = generateRayDir(screenUV);
                float4 output = rayMarch(32, dir);
                return debug == 1 ? debugOutputColor : output;
            }
            ENDCG
        }
    }
}