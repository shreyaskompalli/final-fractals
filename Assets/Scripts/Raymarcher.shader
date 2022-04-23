Shader "Unlit/Raymarcher"
{
    Properties 
    {
    }
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
            float4x4 c2w;

            const float EPSILON = 0.0001f;
            const float end = 999999.9f;

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 scrPos : TEXCOORD1;
            };

            float sphereSDF(float3 p, float radius)
            {
                return length(p) - radius;
            }

            float sceneSDF(float3 samplePoint)
            {
                return sphereSDF(samplePoint, 10);
            }

            /**
             * Generates ray starting from camera passing through sensor plane at (x, y) returns ray direction
             */
            float3 generateRayDir(float x, float y)
            {
                float hFovRad = (hFov * UNITY_PI) / 180;
                float vFovRad = (vFov * UNITY_PI) / 180;
                float xcam = 2 * tan(0.5 * hFovRad) * x - tan(0.5 * hFovRad);
                float ycam = 2 * tan(0.5 * vFovRad) * y - tan(0.5 * vFovRad);
                return mul(c2w, normalize(float4(xcam, ycam, -1.0f, 1.0f))).xyz;
            }

            // sample code from jamie wong article
            float rayMarch(int maxSteps, float3 dir)
            {
                float depth = 0;
                for (int j = 0; j < maxSteps; ++j)
                {
                    float dist = sceneSDF(_WorldSpaceCameraPos + depth * dir);
                    if (dist < EPSILON) return depth;
                    depth += dist;
                    if (depth >= end) return end;
                }
                return end;
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
                float distTraveled = rayMarch(10, generateRayDir(i.scrPos.x, i.scrPos.y));
                if (distTraveled < end) return fixed4(1, 0, 0, 1);
                return fixed4(0, 0, 0, 1);
            }
            ENDCG
        }
    }
}