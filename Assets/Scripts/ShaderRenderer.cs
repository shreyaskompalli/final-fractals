using UnityEngine;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class ShaderRenderer : MonoBehaviour
{
    [SerializeField] private Shader shader;
    [SerializeField] private Primitive[] primitives;
    [SerializeField] private Light sceneLight;
    
    private Camera cam;
    private Material mat;

    private bool initialized;
    
    private static readonly int HFov = Shader.PropertyToID("hFov");
    private static readonly int VFov = Shader.PropertyToID("vFov");
    private static readonly int PrimitiveBuffer = Shader.PropertyToID("primitiveBuffer");
    private static readonly int NumPrimitives = Shader.PropertyToID("numPrimitives");
    private static readonly int LightPos = Shader.PropertyToID("lightPos");
    private static readonly int LightIntensity = Shader.PropertyToID("lightIntensity");
    private static readonly int BackgroundColor = Shader.PropertyToID("backgroundColor");

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (!initialized) Init();
        
        var vFov = cam.fieldOfView;
        var hFov = Camera.VerticalToHorizontalFieldOfView(vFov, cam.aspect);
        
        var lightPosVec3 = sceneLight.transform.position;
        var lightPos = new Vector4(lightPosVec3.x, lightPosVec3.y, lightPosVec3.z, 1);
        var lightIntensity = sceneLight.intensity;

        var primitiveBuffer = new ComputeBuffer(primitives.Length, Primitive.PrimitiveData.SizeOf());
        primitiveBuffer.SetData(SceneData());
        
        mat.SetFloat(HFov, hFov);
        mat.SetFloat(VFov, vFov);
        mat.SetVector(LightPos, lightPos);
        mat.SetVector(BackgroundColor, cam.backgroundColor);
        mat.SetBuffer(PrimitiveBuffer, primitiveBuffer);
        mat.SetFloat(LightIntensity, lightIntensity);
        mat.SetInteger(NumPrimitives, primitives.Length);
        
        Graphics.Blit(src, dest, mat);
        // TODO: getting warning saying primitiveBuffer is garbage collected
        primitiveBuffer.Release();
    }

    private void Init()
    {
        if (!cam) cam = GetComponent<Camera>();
        if (!mat) mat = new Material(shader);
        initialized = true;
    }

    private Primitive.PrimitiveData[] SceneData()
    {
        var primitiveData = new Primitive.PrimitiveData[primitives.Length];
        for (var i = 0; i < primitives.Length; i++)
        {
            primitiveData[i] = primitives[i].Data();
        }

        return primitiveData;
    }
    
}
