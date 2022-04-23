Shader "Unlit/Raymarcher"
{
    Properties 
    {
        hFov ("hFov", Float) = 0.0
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
            float hFov;

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
            };

            float sphereSDF(float3 p, float radius)
            {
                return length(p) - radius;
            }

            float sceneSDF(float3 samplePoint)
            {
                return sphereSDF(samplePoint, 1);
            }

            /**
             * Generates ray starting from camera passing through sensor plane at (x, y) returns ray direction
             */
            float3 generateRay(float x, float y)
            {
                
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float depth = 0;
                int MAX_MARCHING_STEPS = 10;
                for (int j = 0; j < MAX_MARCHING_STEPS; ++j)
                {
                    // float dist = sceneSDF(_WorldSpaceCameraPos + depth * )
                }
                return hFov;
            }
            ENDCG
        }
    }
}