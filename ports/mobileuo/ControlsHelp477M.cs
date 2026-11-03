using UnityEngine;

// The controller layout, shown each time the app opens and whenever L3 is clicked.
// Any controller button or a tap closes it.
public class ControlsHelp477M : MonoBehaviour
{
    public static bool Visible;

    private const string Text =
        "CONTROLLER\n\n" +
        "Left stick\tWalk (push fully to run)\n" +
        "Right stick\tMove the cursor (click R3 to centre it)\n" +
        "A\tLeft-click, hold to drag\n" +
        "B\tRight-click: hold to walk to the cursor, tap to close a window\n" +
        "X\tDouble-click: use, open, attack\n" +
        "Y\tWar / peace (Tab)\n" +
        "L2 (hold)\tShow all names\n" +
        "R2\tChat (Enter)\n" +
        "Start\tEscape: cancel a target, close\n" +
        "Select\tF12\n" +
        "D-pad\tHotbar F1-F4, hold L1 for F5-F8, hold R1 for F9-F12\n" +
        "L3\tShow this screen again\n\n" +
        "Set what F1-F12 do in Options > Macros. Both controllers work at once.\n" +
        "Touch the screen to play by touch; move a stick to go back to the controller.\n\n" +
        "Press any button or tap to close";

    private GUIStyle style;
    private GUIStyle backdrop;
    private Texture2D shade;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    private static void Create()
    {
        var go = new GameObject("ControlsHelp477M");
        DontDestroyOnLoad(go);
        go.AddComponent<ControlsHelp477M>();
        Visible = true;
    }

    public static void Show()
    {
        Visible = true;
    }

    public static void Close()
    {
        Visible = false;
    }

    private void OnGUI()
    {
        if (!Visible)
        {
            return;
        }

        if (style == null)
        {
            shade = new Texture2D(1, 1);
            shade.SetPixel(0, 0, new Color(0f, 0f, 0f, 0.85f));
            shade.Apply();
            backdrop = new GUIStyle { normal = { background = shade } };
            style = new GUIStyle(GUI.skin.label)
            {
                fontSize = Mathf.Max(14, Screen.height / 34),
                wordWrap = true,
                richText = false,
                alignment = TextAnchor.UpperLeft,
                normal = { textColor = Color.white }
            };
        }

        GUI.depth = -1000;
        GUI.Box(new Rect(0, 0, Screen.width, Screen.height), GUIContent.none, backdrop);
        var margin = Screen.height / 16f;
        var area = new Rect(margin, margin, Screen.width - 2 * margin, Screen.height - 2 * margin);
        GUI.Label(area, Text.Replace("\t", "  -  "), style);

        var e = Event.current;
        if (e.type == EventType.MouseDown)
        {
            Close();
            e.Use();
        }
    }
}
