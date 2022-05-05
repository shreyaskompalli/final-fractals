using System;
using UnityEngine;

public class Primitive : MonoBehaviour
{
    [SerializeField] private PrimitiveType type;

    [SerializeField] private Color color;

    // X = ka, Y = kd, Z = ks (parameters for phong shading)
    [SerializeField] private Vector3 phong;

    // x = minIterations, y = maxIterations
    [SerializeField] private Vector2 iterations;

    [SerializeField] private bool orbitTrap;

    public enum PrimitiveType
    {
        Sphere,
        Cube,
        Menger,
        Sierpinski,
        Mandelbulb,
        Julia
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
            phongParams = phong,
            iterations = this.iterations,
            orbitTrap = this.orbitTrap ? 1 : 0
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
    public Vector2 iterations;
    public float orbitTrap;

    public static int SizeOf()
    {
        const int sizeofVector3 = sizeof(float) * 3;
        const int sizeofColor = sizeof(float) * 4;
        const int sizeofVector2 = sizeof(float) * 2;
        return 3 * sizeofVector3 + sizeofColor + sizeofVector2 + sizeof(int) + sizeof(float);
    }
}