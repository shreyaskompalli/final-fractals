using UnityEngine;

public class FirstPersonController : MonoBehaviour
{
    [SerializeField] private float mouseSensitivity;

    [SerializeField] private float speed;
    [SerializeField] private KeyCode forwardKey;
    [SerializeField] private KeyCode leftKey;
    [SerializeField] private KeyCode downKey;
    [SerializeField] private KeyCode rightKey;

    // Start is called before the first frame update
    private void Start()
    {
        Cursor.lockState = CursorLockMode.Locked;
    }

    // Update is called once per frame
    private void Update()
    {
        var cursorDelta = new Vector3(-Input.GetAxis("Mouse Y"), Input.GetAxis("Mouse X"), 0);
        transform.eulerAngles += mouseSensitivity * cursorDelta;

        var velocity = new Vector3();
        if (Input.GetKey(forwardKey))
            velocity.z += speed;
        if (Input.GetKey(downKey))
            velocity.z -= speed;
        if (Input.GetKey(leftKey))
            velocity.x -= speed;
        if (Input.GetKey(rightKey))
            velocity.x += speed;
        transform.position += transform.rotation * velocity;
    }
}