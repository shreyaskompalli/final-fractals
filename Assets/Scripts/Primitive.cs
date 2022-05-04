using System;
using UnityEngine;

public class Primitive : MonoBehaviour
{
    public PrimitiveType type;
    public Color color;
    // X = ka, Y = kd, Z = ks (parameters for phong shading)
    public Vector3 phong;

    public enum PrimitiveType
    {
        Sphere,
        Cube,
        Menger,
        Sierpinski,
        Mandelbulb
    };

    public PrimitiveData Data()
    {
        var myTransform = transform;
        var typeOrdinal = Array.IndexOf(Enum.GetValues(type.GetType()), type);
        return new PrimitiveData
        {
            position = myTransform.position,
            scale = myTransform.localScale,
            type = typeOrdinal,
            color = this.color,
            phongParams = phong
        };
    }
}

public struct PrimitiveData
{
    public Vector3 position;
    public Vector3 scale;
    public int type;
    public Color color;
    public Vector3 phongParams; // x = ka, y = kd, z = ks

    public static int SizeOf()
    {
        const int sizeofVector3 = sizeof(float) * 3;
        const int sizeofColor = sizeof(float) * 4;
        return 3 * sizeofVector3 + sizeofColor + sizeof(int);
    }
}