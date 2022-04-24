using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class ShaderRenderer : MonoBehaviour
{
    public Material mat;
    private Camera cam;
    
    private static readonly int HFov = Shader.PropertyToID("hFov");
    private static readonly int VFov = Shader.PropertyToID("vFov");

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (!cam) cam = GetComponent<Camera>();
        
        var vFov = cam.fieldOfView;
        var hFov = Camera.VerticalToHorizontalFieldOfView(vFov, cam.aspect);
        
        mat.SetFloat(HFov, hFov);
        mat.SetFloat(VFov, vFov);
        
        Graphics.Blit(src, dest, mat);
    }

    // Start is called before the first frame update
    void Awake()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
