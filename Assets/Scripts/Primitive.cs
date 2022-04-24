using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Primitive : MonoBehaviour
{
    public PrimitiveType type;
    public Color color;

    public enum PrimitiveType
    {
        Sphere, Cube
    };

    public PrimitiveData data()
    {
        var myTransform = transform;
        var typeOrdinal = Array.IndexOf(Enum.GetValues(type.GetType()), type);
        return new PrimitiveData()
        {
            position = myTransform.position,
            scale = myTransform.localScale,
            type = typeOrdinal,
            color = this.color
        };
    }

    public struct PrimitiveData
    {
        public Vector3 position;
        public Vector3 scale;
        public int type;
        public Color color;

        public static int sizeOf()
        {
            var sizeofVector3 = sizeof(float) * 3;
            var sizeofColor = sizeof(float) * 4;
            return 2 * sizeofVector3 + sizeofColor + sizeof(int);
        }
    }
}