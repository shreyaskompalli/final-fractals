using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class SceneSwitcher : MonoBehaviour
{
    [SerializeField] private KeyCode sceneKey;

    [SerializeField] private KeyCode fogKey;

    [SerializeField] private KeyCode aoKey;

    [SerializeField] private KeyCode shadowKey;

    private ShaderRenderer shaderRenderer;
    
    // Start is called before the first frame update
    void Awake()
    {
        DontDestroyOnLoad(gameObject);
        SceneManager.activeSceneChanged += OnSceneChanged;
    }

    // Update is called once per frame
    void Update()
    {
        if (Input.GetKeyDown(sceneKey))
        {
            var nextSceneIndex = (SceneManager.GetActiveScene().buildIndex + 1) % SceneManager.sceneCount;
            SceneManager.LoadScene(sceneBuildIndex: nextSceneIndex);
        } 
        else if (Input.GetKeyDown(fogKey))
        {
            
        }
        else if (Input.GetKeyDown(aoKey))
        {
            
        }
        else if (Input.GetKeyDown(shadowKey))
        {
            
        }
    }

    private void OnSceneChanged(Scene current, Scene next)
    {
        
    }
}
