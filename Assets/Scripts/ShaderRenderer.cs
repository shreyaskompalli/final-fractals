using System.Linq;
using UnityEngine;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class ShaderRenderer : MonoBehaviour
{
    [SerializeField] private Shader shader;
    
    private Camera cam;
    private Material mat;
    private Primitive[] primitives;
    private Light[] lights;

    private bool initialized;
    
    private static readonly int PrimitiveBuffer = Shader.PropertyToID("primitiveBuffer");
    private static readonly int NumPrimitives = Shader.PropertyToID("numPrimitives");
    private static readonly int BackgroundColor = Shader.PropertyToID("backgroundColor");
    private static readonly int LightBuffer = Shader.PropertyToID("lightBuffer");
    private static readonly int NumLights = Shader.PropertyToID("numLights");

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (!initialized) Init();
        
        var primitiveBuffer = new ComputeBuffer(primitives.Length, PrimitiveData.SizeOf());
        primitiveBuffer.SetData(primitives.Select(x => x.Data()).ToArray());
        var lightBuffer = new ComputeBuffer(lights.Length, LightData.SizeOf());
        lightBuffer.SetData(lights.Select(x => x.Data()).ToArray());
        
        mat.SetVector(BackgroundColor, cam.backgroundColor);
        mat.SetBuffer(PrimitiveBuffer, primitiveBuffer);
        mat.SetBuffer(LightBuffer, lightBuffer);
        mat.SetInteger(NumPrimitives, primitives.Length);
        mat.SetInteger(NumLights, lights.Length);

        Graphics.Blit(src, dest, mat);
        primitiveBuffer.Release();
        lightBuffer.Release();
    }

    private void Init()
    {
        if (!cam) cam = GetComponent<Camera>();
        if (!mat) mat = new Material(shader);
        primitives = FindObjectsOfType<Primitive>();
        lights = FindObjectsOfType<Light>();
        initialized = true;
    }
}
