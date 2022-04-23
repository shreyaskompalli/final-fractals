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
    private static readonly int C2W = Shader.PropertyToID("c2w");

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        var vFov = thisCam.fieldOfView;
        var hFov = Camera.VerticalToHorizontalFieldOfView(vFov, thisCam.aspect);
        var c2w = thisCam.cameraToWorldMatrix;
        mat.SetFloat(HFov, hFov);
        mat.SetFloat(VFov, vFov);
        mat.SetMatrix(C2W, c2w);
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
