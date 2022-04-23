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
    private static readonly int C2W = Shader.PropertyToID("c2w");
    private static readonly int I2C = Shader.PropertyToID("i2c");

    private void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        var vFov = cam.fieldOfView;
        var hFov = Camera.VerticalToHorizontalFieldOfView(vFov, cam.aspect);
        var c2w = cam.cameraToWorldMatrix;
        var i2c = cam.projectionMatrix.inverse; // image to world
        
        mat.SetFloat(HFov, hFov);
        mat.SetFloat(VFov, vFov);
        mat.SetMatrix(C2W, c2w);
        mat.SetMatrix(I2C, i2c);
        Graphics.Blit(src, dest, mat);
    }

    // Start is called before the first frame update
    void Awake()
    {
        cam = GetComponent<Camera>();
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
