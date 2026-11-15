using UnityEngine;

// A CRT look over the game: a dark scanline every third row and a faint aperture
// grille, one tiled 3x3 texture drawn over everything. On by default; Select + L3
// turns it on or off (kept in PlayerPrefs).
public class CrtOverlay477M : MonoBehaviour
{
    private const string Key = "crt477m";
    public static bool On = true;
    private Texture2D tile;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    private static void Create()
    {
        On = PlayerPrefs.GetInt(Key, 1) == 1;
        var go = new GameObject("CrtOverlay477M");
        DontDestroyOnLoad(go);
        go.AddComponent<CrtOverlay477M>();
    }

    public static void Toggle()
    {
        On = !On;
        PlayerPrefs.SetInt(Key, On ? 1 : 0);
        PlayerPrefs.Save();
    }

    private void OnGUI()
    {
        if (!On || Event.current.type != EventType.Repaint)
        {
            return;
        }
        if (tile == null)
        {
            tile = new Texture2D(3, 3, TextureFormat.RGBA32, false)
            {
                filterMode = FilterMode.Point,
                wrapMode = TextureWrapMode.Repeat
            };
            var grille = new[]
            {
                new Color(1f, 0f, 0f, 0.05f), new Color(0f, 1f, 0f, 0.05f), new Color(0f, 0f, 1f, 0.05f)
            };
            for (var y = 0; y < 3; y++)
            {
                for (var x = 0; x < 3; x++)
                {
                    tile.SetPixel(x, y, y == 0 ? new Color(0f, 0f, 0f, 0.35f) : grille[x]);
                }
            }
            tile.Apply();
        }
        GUI.depth = -900;
        GUI.DrawTextureWithTexCoords(new Rect(0, 0, Screen.width, Screen.height), tile,
            new Rect(0, 0, Screen.width / 3f, Screen.height / 3f));
    }
}
