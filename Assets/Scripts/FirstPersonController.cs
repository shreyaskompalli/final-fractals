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
        var velocity = new Vector3();
        if (Input.GetKey(forwardKey))
            velocity.z += 1;
        if (Input.GetKey(downKey))
            velocity.z -= 1;
        if (Input.GetKey(leftKey))
            velocity.x -= 1;
        if (Input.GetKey(rightKey))
            velocity.x += 1;
        velocity = Vector3.Normalize(velocity);
        transform.position += transform.rotation * velocity * (speed * Time.deltaTime);
        
        // TODO: Bug where looking straight up or down flips controls
        var cursorDelta = new Vector3(-Input.GetAxis("Mouse Y"), Input.GetAxis("Mouse X"), 0);
        transform.eulerAngles += mouseSensitivity * cursorDelta;
    }
}