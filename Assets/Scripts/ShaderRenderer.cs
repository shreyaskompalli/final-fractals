using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class ShaderRenderer : MonoBehaviour
{
    public Material mat;
    private Camera thisCam;
    private static readonly int HFov = Shader.PropertyToID("hFov");
    private static readonly int VFov = Shader.PropertyToID("vFov");

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        var vFov = thisCam.fieldOfView;
        var hFov = Camera.VerticalToHorizontalFieldOfView(vFov, thisCam.aspect);
        mat.SetFloat(HFov, hFov);
        mat.SetFloat(VFov, vFov);
        Graphics.Blit(src, dest, mat);
    }

    // Start is called before the first frame update
    void Awake()
    {
        thisCam = GetComponent<Camera>();
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
