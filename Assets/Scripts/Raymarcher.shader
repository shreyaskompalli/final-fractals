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

            float sphereSDF(float3 p, float3 origin, float radius)
            {
                return distance(p, origin) - radius;
            }

            float sceneSDF(float3 samplePoint)
            {
                return sphereSDF(samplePoint, float3(0, 0, 0), 10.04);
            }

            /**
             * Generates ray starting from camera passing through sensor plane at (x, y) returns ray direction
             */
            float3 generateRayDir(float x, float y)
            {
                // float hFovRad = (hFov * UNITY_PI) / 180;
                // float vFovRad = (vFov * UNITY_PI) / 180;
                // float xcam = 2 * tan(0.5 * hFovRad) * x - tan(0.5 * hFovRad);
                // float ycam = 2 * tan(0.5 * vFovRad) * y - tan(0.5 * vFovRad);
                // return mul(c2w, normalize(float4(xcam, ycam, -1.0f, 1.0f))).xyz;
                float4 dirImage = float4(x, y, 0, 1);
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
                    if (dist < EPSILON) return float4(1, 0, 0, 1);
                    depth += dist;
                }
                return float4(0, 0, 0, 1);
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                float4 vertScrPos = ComputeScreenPos(v.vertex);
                // https://forum.unity.com/threads/what-does-the-function-computescreenpos-in-unitycg-cginc-do.294470/ 
                o.scrPos = vertScrPos;
                
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float2 screenPos = i.scrPos.xy / i.scrPos.w;
                return rayMarch(32, generateRayDir(i.scrPos.x, i.scrPos.y));
            }
            ENDCG
        }
    }
}