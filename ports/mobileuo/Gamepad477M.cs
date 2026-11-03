using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.Controls;

// Controller play for the RG477M, laid out like a Steam Input desktop config:
// left stick walks, right stick moves the cursor, A/B are the mouse buttons,
// X double-clicks, the d-pad is a 12-slot hotbar (F1-F12 with L1/R1).
// Every connected controller plays at once (the built-in one and a Bluetooth pad).
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

        var pads = Gamepad.all;
        if (ControlsHelp477M.Visible)
        {
            Release();
            if (pads.Count > 0 && AnyButtonPressed(pads))
            {
                ControlsHelp477M.Close();
            }
            return;
        }
        if (pads.Count == 0)
        {
            Release();
            return;
        }

        if (Input.touchCount > 0)
        {
            Release();
            return;
        }

        var left = Strongest(pads, p => p.leftStick.ReadValue());
        var right = Strongest(pads, p => p.rightStick.ReadValue());
        if (!Active && (left.magnitude > 0.3f || right.magnitude > 0.3f || AnyButtonPressed(pads)))
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
        if (Pressed(pads, p => p.leftStickButton))
        {
            ControlsHelp477M.Show();
            Release();
            return;
        }
        if (Pressed(pads, p => p.rightStickButton))
        {
            Cursor = new Vector2(Screen.width * 0.5f, Screen.height * 0.5f);
            Moved = true;
        }

        LeftDown = Pressed(pads, p => p.buttonSouth);
        LeftHeld = Held(pads, p => p.buttonSouth);
        LeftUp = Released(pads, p => p.buttonSouth);
        RightDown = Pressed(pads, p => p.buttonEast);
        RightHeld = Held(pads, p => p.buttonEast);
        RightUp = Released(pads, p => p.buttonEast);
        DoubleClick = Pressed(pads, p => p.buttonWest);
        NamesHeld = Held(pads, p => p.leftTrigger);

        Key(pads, p => p.buttonNorth, KeyCode.Tab);
        Key(pads, p => p.rightTrigger, KeyCode.Return);
        Key(pads, p => p.startButton, KeyCode.Escape);
        Key(pads, p => p.selectButton, KeyCode.F12);

        Hotbar(pads);
    }

    // F1-F4 on the d-pad; with L1 held F5-F8, with R1 held F9-F12
    private static void Hotbar(IReadOnlyList<Gamepad> pads)
    {
        var bank = Held(pads, p => p.leftShoulder) ? 4 : Held(pads, p => p.rightShoulder) ? 8 : 0;
        DpadButton(pads, p => p.dpad.up, KeyCode.F1 + bank);
        DpadButton(pads, p => p.dpad.right, KeyCode.F2 + bank);
        DpadButton(pads, p => p.dpad.down, KeyCode.F3 + bank);
        DpadButton(pads, p => p.dpad.left, KeyCode.F4 + bank);
    }

    private static void DpadButton(IReadOnlyList<Gamepad> pads, Func<Gamepad, ButtonControl> button, KeyCode key)
    {
        if (Pressed(pads, button))
        {
            if (dpadKey != KeyCode.None)
            {
                KeyEvents.Add(new KeyValuePair<KeyCode, bool>(dpadKey, false));
            }
            dpadKey = key;
            KeyEvents.Add(new KeyValuePair<KeyCode, bool>(key, true));
        }
        else if (Released(pads, button) && dpadKey != KeyCode.None)
        {
            KeyEvents.Add(new KeyValuePair<KeyCode, bool>(dpadKey, false));
            dpadKey = KeyCode.None;
        }
    }

    private static void Key(IReadOnlyList<Gamepad> pads, Func<Gamepad, ButtonControl> button, KeyCode key)
    {
        if (Pressed(pads, button))
        {
            KeyEvents.Add(new KeyValuePair<KeyCode, bool>(key, true));
        }
        else if (Released(pads, button))
        {
            KeyEvents.Add(new KeyValuePair<KeyCode, bool>(key, false));
        }
    }

    private static Vector2 Strongest(IReadOnlyList<Gamepad> pads, Func<Gamepad, Vector2> stick)
    {
        var best = Vector2.zero;
        for (var i = 0; i < pads.Count; i++)
        {
            var v = stick(pads[i]);
            if (v.sqrMagnitude > best.sqrMagnitude)
            {
                best = v;
            }
        }
        return best;
    }

    private static bool Pressed(IReadOnlyList<Gamepad> pads, Func<Gamepad, ButtonControl> button)
    {
        for (var i = 0; i < pads.Count; i++)
        {
            if (button(pads[i]).wasPressedThisFrame)
            {
                return true;
            }
        }
        return false;
    }

    private static bool Held(IReadOnlyList<Gamepad> pads, Func<Gamepad, ButtonControl> button)
    {
        for (var i = 0; i < pads.Count; i++)
        {
            if (button(pads[i]).isPressed)
            {
                return true;
            }
        }
        return false;
    }

    // released on one pad and held on none
    private static bool Released(IReadOnlyList<Gamepad> pads, Func<Gamepad, ButtonControl> button)
    {
        var released = false;
        for (var i = 0; i < pads.Count; i++)
        {
            var b = button(pads[i]);
            if (b.isPressed)
            {
                return false;
            }
            released |= b.wasReleasedThisFrame;
        }
        return released;
    }

    private static bool AnyButtonPressed(IReadOnlyList<Gamepad> pads)
    {
        for (var i = 0; i < pads.Count; i++)
        {
            foreach (var control in pads[i].allControls)
            {
                if (control is ButtonControl b && b.wasPressedThisFrame)
                {
                    return true;
                }
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
