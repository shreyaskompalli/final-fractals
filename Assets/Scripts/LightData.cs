using UnityEngine;

public struct LightData
{
    public Vector3 position;
    public float intensity;

    public static int SizeOf()
    {
        const int sizeofVector3 = sizeof(float) * 3;
        return sizeofVector3 + sizeof(float);
    }
}

public static class LightExtensions
{
    public static LightData Data(this Light light)
    {
        return new LightData
        {
            intensity = light.intensity,
            position = light.transform.position
        };
    }
}