using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class ShaderRenderer : MonoBehaviour
{
    public Shader shader;
    public Primitive[] primitives;
    public Light sceneLight;
    
    private Camera cam;
    private Material mat;

    private bool initialized = false;
    
    private static readonly int HFov = Shader.PropertyToID("hFov");
    private static readonly int VFov = Shader.PropertyToID("vFov");
    private static readonly int PrimitiveBuffer = Shader.PropertyToID("primitiveBuffer");
    private static readonly int NumPrimitives = Shader.PropertyToID("numPrimitives");
    private static readonly int LightPos = Shader.PropertyToID("lightPos");
    private static readonly int LightIntensity = Shader.PropertyToID("lightIntensity");

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (!initialized) Init();
        
        var vFov = cam.fieldOfView;
        var hFov = Camera.VerticalToHorizontalFieldOfView(vFov, cam.aspect);
        
        var lightPosVec3 = sceneLight.transform.position;
        var lightPos = new Vector4(lightPosVec3.x, lightPosVec3.y, lightPosVec3.z, 1);
        var lightIntensity = sceneLight.intensity;
        
        var primitiveBuffer = new ComputeBuffer(primitives.Length, Primitive.PrimitiveData.sizeOf());
        primitiveBuffer.SetData(SceneData());
        
        mat.SetFloat(HFov, hFov);
        mat.SetFloat(VFov, vFov);
        mat.SetVector(LightPos, lightPos);
        mat.SetBuffer(PrimitiveBuffer, primitiveBuffer);
        mat.SetFloat(LightIntensity, lightIntensity);
        mat.SetInteger(NumPrimitives, primitives.Length);
        
        Graphics.Blit(src, dest, mat);
        // TODO: getting warning saying primitiveBuffer is garbage collected
        primitiveBuffer.Dispose();
    }

    private void Init()
    {
        if (!cam) cam = GetComponent<Camera>();
        if (!mat) mat = new Material(shader);
    }

    private Primitive.PrimitiveData[] SceneData()
    {
        var primitiveData = new Primitive.PrimitiveData[primitives.Length];
        for (int i = 0; i < primitives.Length; i++)
        {
            primitiveData[i] = primitives[i].data();
        }

        return primitiveData;
    }
    
}
