using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.Controls;

// Controller play for the RG477M, laid out like a Steam Input desktop config:
// left stick walks, right stick moves the cursor, A/B are the mouse buttons,
// X double-clicks, the d-pad is a 12-slot hotbar (F1-F12 with L1/R1).
// Touching the screen hands control back to touch.
public static class Gamepad477M
{
    private const float StickDeadZone = 0.2f;
    private const float CursorDeadZone = 0.12f;
    // cursor speed at full tilt, in screen heights per second
    private const float CursorSpeed = 1.1f;

    public static bool Active { get; private set; }
    public static Vector2 Cursor;
    public static Vector2 Move;
    public static bool LeftDown, LeftUp, LeftHeld;
    public static bool RightDown, RightUp, RightHeld;
    public static bool DoubleClick;
    public static bool Moved;
    public static bool NamesHeld;
    public static readonly List<KeyValuePair<KeyCode, bool>> KeyEvents = new List<KeyValuePair<KeyCode, bool>>();

    private static int lastFrame = -1;
    private static KeyCode dpadKey = KeyCode.None;

    public static void Poll()
    {
        if (Time.frameCount == lastFrame)
        {
            return;
        }
        lastFrame = Time.frameCount;

        LeftDown = LeftUp = RightDown = RightUp = DoubleClick = Moved = false;
        KeyEvents.Clear();

        var pad = Gamepad.current;
        if (pad == null)
        {
            Release();
            return;
        }

        if (Input.touchCount > 0)
        {
            Release();
            return;
        }

        var left = pad.leftStick.ReadValue();
        var right = pad.rightStick.ReadValue();
        if (!Active && (left.magnitude > 0.3f || right.magnitude > 0.3f || AnyButtonPressed(pad)))
        {
            Active = true;
            Cursor = new Vector2(Screen.width * 0.5f, Screen.height * 0.5f);
        }
        if (!Active)
        {
            return;
        }

        Move = left.magnitude > StickDeadZone ? left : Vector2.zero;

        var tilt = right.magnitude;
        if (tilt > CursorDeadZone)
        {
            var t = (Mathf.Min(tilt, 1f) - CursorDeadZone) / (1f - CursorDeadZone);
            Cursor += right.normalized * (t * t * CursorSpeed * Screen.height * Time.unscaledDeltaTime);
            Cursor.x = Mathf.Clamp(Cursor.x, 0f, Screen.width - 1);
            Cursor.y = Mathf.Clamp(Cursor.y, 0f, Screen.height - 1);
            Moved = true;
        }
        if (pad.rightStickButton.wasPressedThisFrame)
        {
            Cursor = new Vector2(Screen.width * 0.5f, Screen.height * 0.5f);
            Moved = true;
        }

        LeftDown = pad.buttonSouth.wasPressedThisFrame;
        LeftUp = pad.buttonSouth.wasReleasedThisFrame;
        LeftHeld = pad.buttonSouth.isPressed;
        RightDown = pad.buttonEast.wasPressedThisFrame;
        RightUp = pad.buttonEast.wasReleasedThisFrame;
        RightHeld = pad.buttonEast.isPressed;
        DoubleClick = pad.buttonWest.wasPressedThisFrame;
        NamesHeld = pad.leftTrigger.isPressed;

        Key(pad.buttonNorth, KeyCode.Tab);
        Key(pad.rightTrigger, KeyCode.Return);
        Key(pad.startButton, KeyCode.Escape);
        Key(pad.selectButton, KeyCode.F12);

        Hotbar(pad);
    }

    // F1-F4 on the d-pad; with L1 held F5-F8, with R1 held F9-F12
    private static void Hotbar(Gamepad pad)
    {
        var bank = pad.leftShoulder.isPressed ? 4 : pad.rightShoulder.isPressed ? 8 : 0;
        DpadButton(pad.dpad.up, KeyCode.F1 + bank);
        DpadButton(pad.dpad.right, KeyCode.F2 + bank);
        DpadButton(pad.dpad.down, KeyCode.F3 + bank);
        DpadButton(pad.dpad.left, KeyCode.F4 + bank);
    }

    private static void DpadButton(ButtonControl button, KeyCode key)
    {
        if (button.wasPressedThisFrame)
        {
            if (dpadKey != KeyCode.None)
            {
                KeyEvents.Add(new KeyValuePair<KeyCode, bool>(dpadKey, false));
            }
            dpadKey = key;
            KeyEvents.Add(new KeyValuePair<KeyCode, bool>(key, true));
        }
        else if (button.wasReleasedThisFrame && dpadKey != KeyCode.None)
        {
            KeyEvents.Add(new KeyValuePair<KeyCode, bool>(dpadKey, false));
            dpadKey = KeyCode.None;
        }
    }

    private static void Key(ButtonControl button, KeyCode key)
    {
        if (button.wasPressedThisFrame)
        {
            KeyEvents.Add(new KeyValuePair<KeyCode, bool>(key, true));
        }
        else if (button.wasReleasedThisFrame)
        {
            KeyEvents.Add(new KeyValuePair<KeyCode, bool>(key, false));
        }
    }

    private static bool AnyButtonPressed(Gamepad pad)
    {
        foreach (var control in pad.allControls)
        {
            if (control is ButtonControl b && b.wasPressedThisFrame)
            {
                return true;
            }
        }
        return false;
    }

    private static void Release()
    {
        if (Active)
        {
            if (LeftHeld)
            {
                LeftUp = true;
            }
            if (RightHeld)
            {
                RightUp = true;
            }
            if (dpadKey != KeyCode.None)
            {
                KeyEvents.Add(new KeyValuePair<KeyCode, bool>(dpadKey, false));
                dpadKey = KeyCode.None;
            }
        }
        Active = false;
        Move = Vector2.zero;
        LeftHeld = RightHeld = NamesHeld = false;
    }
}
