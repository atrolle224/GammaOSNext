#!/usr/bin/env python3
"""MobileUO 477M: controller play and the current UOAlive settings on a MobileUO checkout.

usage: apply.py <checkout>
"""
import json
import os
import shutil
import sys

root = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))


def edit(rel, old, new, count=1):
    path = os.path.join(root, rel)
    with open(path, encoding="utf-8-sig") as f:
        s = f.read()
    if s.count(old) != count:
        sys.exit(f"{rel}: expected {count} of {old!r}, found {s.count(old)}")
    with open(path, "w", encoding="utf-8") as f:
        f.write(s.replace(old, new))


for name in ("Gamepad477M.cs", "ControlsHelp477M.cs"):
    shutil.copy(os.path.join(here, name), os.path.join(root, "Assets/Scripts", name))

# Unity's Input System for gamepads, beside the old input that touch and keys use
manifest = os.path.join(root, "Packages/manifest.json")
with open(manifest) as f:
    m = json.load(f)
m["dependencies"].setdefault("com.unity.inputsystem", "1.11.2")
with open(manifest, "w") as f:
    json.dump(m, f, indent=2)
    f.write("\n")
edit("ProjectSettings/ProjectSettings.asset", "  activeInputHandler: 0\n", "  activeInputHandler: 2\n")

# own app beside MobileUO
edit("ProjectSettings/ProjectSettings.asset", "  productName: MobileUO\n", "  productName: MobileUO 477M\n")
edit("ProjectSettings/ProjectSettings.asset", "    Android: com.mobileuo.mobileuo\n", "    Android: com.mobileuo.mobileuo.rg477m\n")

gc = "Assets/Scripts/ClassicUO/src/ClassicUO.Client/GameController.cs"

edit(gc, """        private void MouseUpdate()
        {
            var oneOverScale = 1f / Batcher.scale;
""", """        private void MouseUpdate()
        {
            var oneOverScale = 1f / Batcher.scale;

            Gamepad477M.Poll();
            if (Gamepad477M.Active)
            {
                Mouse.Position = ConvertUnityMousePosition(Gamepad477M.Cursor, oneOverScale);
                Mouse.LButtonPressed = Gamepad477M.LeftHeld;
                Mouse.RButtonPressed = Gamepad477M.RightHeld;
                Mouse.IsDragging = Mouse.LButtonPressed || Mouse.RButtonPressed;
                return;
            }
""")

edit(gc, """        private void UnityInputUpdate()
        {
            var oneOverScale = 1f / Batcher.scale;
            
            //Finger/mouse handling
            if (UnityEngine.Application.isMobilePlatform && UserPreferences.UseMouseOnMobile.CurrentValue == 0)
""", """        private void UnityInputUpdate()
        {
            var oneOverScale = 1f / Batcher.scale;

            Gamepad477M.Poll();
            if (Gamepad477M.Active)
            {
                Mouse.Position = ConvertUnityMousePosition(Gamepad477M.Cursor, oneOverScale);
                if (Gamepad477M.DoubleClick)
                {
                    SimulateMouse(true, false, false, false, false, false);
                    SimulateMouse(false, true, false, false, false, false);
                    SimulateMouse(true, false, false, false, false, false);
                    SimulateMouse(false, true, false, false, false, false);
                }
                SimulateMouse(Gamepad477M.LeftDown, Gamepad477M.LeftUp, Gamepad477M.RightDown, Gamepad477M.RightUp, Gamepad477M.Moved, false);
            }
            //Finger/mouse handling
            else if (UnityEngine.Application.isMobilePlatform && UserPreferences.UseMouseOnMobile.CurrentValue == 0)
""")

# L2 held shows all names (Ctrl+Shift)
edit(gc, """            Keyboard.Shift = (keymod & SDL_Keymod.KMOD_SHIFT) != SDL_Keymod.KMOD_NONE;
""", """            if (Gamepad477M.Active && Gamepad477M.NamesHeld)
            {
                keymod |= SDL_Keymod.KMOD_LCTRL | SDL_Keymod.KMOD_LSHIFT;
            }

            Keyboard.Shift = (keymod & SDL_Keymod.KMOD_SHIFT) != SDL_Keymod.KMOD_NONE;
""")

# controller buttons go through the same path as hardware keys
edit(gc, """            if (EscOverride)
            {""", """            foreach (var padKey in Gamepad477M.KeyEvents)
            {
                var key = new SDL_KeyboardEvent {keysym = new SDL_Keysym {sym = (SDL_Keycode) padKey.Key, mod = keymod}};
                if (padKey.Value)
                {
                    Keyboard.OnKeyDown(key);

                    if (Plugin.ProcessHotkeys((int) key.keysym.sym, (int) key.keysym.mod, true))
                    {
                        _ignoreNextTextInput = false;
                        UIManager.KeyboardFocusControl?.InvokeKeyDown(key.keysym.sym, key.keysym.mod);
                        Scene.OnKeyDown(key);
                    }
                    else
                        _ignoreNextTextInput = true;
                }
                else
                {
                    Keyboard.OnKeyUp(key);
                    UIManager.KeyboardFocusControl?.InvokeKeyUp(key.keysym.sym, key.keysym.mod);
                    Scene.OnKeyUp(key);
                    Plugin.ProcessHotkeys(0, 0, false);
                }
            }

            if (EscOverride)
            {""")

# left stick walks, as the on-screen joystick does
edit("Assets/Scripts/ClientRunner.cs", """	        gameScene.JoystickInput = new Microsoft.Xna.Framework.Vector2(movementJoystick.Input.x, -1 * movementJoystick.Input.y);
        }
""", """	        gameScene.JoystickInput = new Microsoft.Xna.Framework.Vector2(movementJoystick.Input.x, -1 * movementJoystick.Input.y);
        }

        Gamepad477M.Poll();
        if (Gamepad477M.Active != padWasActive)
        {
	        padWasActive = Gamepad477M.Active;
	        UpdateMovementJoystick();
        }
        if (Gamepad477M.Active && Client.Game.Scene is GameScene padScene
            && (!movementJoystick.isActiveAndEnabled || movementJoystick.Input == UnityEngine.Vector2.zero))
        {
	        padScene.JoystickInput = new Microsoft.Xna.Framework.Vector2(Gamepad477M.Move.x, -1 * Gamepad477M.Move.y);
        }
""")

# the on-screen joystick hides while the controller is in use, and returns on touch
edit("Assets/Scripts/ClientRunner.cs", """	private MobileJoystick movementJoystick;
""", """	private MobileJoystick movementJoystick;
	private bool padWasActive;
""")
edit("Assets/Scripts/ClientRunner.cs", """	                                          && UserPreferences.UseMouseOnMobile.CurrentValue == 0);""", """	                                          && UserPreferences.UseMouseOnMobile.CurrentValue == 0
	                                          && !Gamepad477M.Active);""")

# MobileUO hides the game cursor on phones; draw it while the controller drives it
edit("Assets/Scripts/ClassicUO/src/ClassicUO.Client/Game/GameCursor.cs",
     "            if (!Settings.GlobalSettings.RunMouseInASeparateThread)\n            {\n                Graphic = AssignGraphicByState();",
     "            if (!Settings.GlobalSettings.RunMouseInASeparateThread || Gamepad477M.Active)\n            {\n                Graphic = AssignGraphicByState();")

# first launch goes straight to UOAlive: download its package, then the login screen
edit("Assets/Scripts/ServerConfiguration/ServerConfigurationModel.cs",
     """        SupportedServerConfigurations = new List<ServerConfiguration>(serverConfigurations);
    }
""", """        SupportedServerConfigurations = new List<ServerConfiguration>(serverConfigurations);

        if (ServerConfigurations.Count == 0)
        {
            var uoAlive = serverConfigurations.FirstOrDefault(x => x.UoServerUrl == "login.uoalive.com");
            if (uoAlive != null)
            {
                var config = uoAlive.Clone();
                config.Name = "UOAlive";
                config.AllFilesDownloaded = false;
                ServerConfigurations.Add(config);
                config.CreateDirectoryToSaveFiles();
                SaveServerConfigurations();
                PlayerPrefs.SetString(defaultConfigurationNameKey, config.Name);
                PlayerPrefs.Save();
                DefaultConfiguration = config;
            }
        }
    }
""")

# 90 and 120 fps in MobileUO's frame rate menu, 90 by default (the toolkit sets the panel to match)
edit("Assets/Scripts/PreferenceEnums.cs", """        _60 = 60,
        InGameFPS = -1""", """        _60 = 60,
        _90 = 90,
        _120 = 120,
        InGameFPS = -1""")
edit("Assets/Scripts/UserPreferences.cs",
     "TargetFrameRate = new IntPreference(nameof(TargetFrameRate), (int) TargetFrameRates._60);",
     "TargetFrameRate = new IntPreference(nameof(TargetFrameRate), (int) TargetFrameRates._90);")

# UOAlive's current mobile package (uoalive.com/playnow.html)
edit("Assets/Resources/SupportedServerConfigurations.asset",
     """    FileDownloadServerUrl: mobile.uoalive.com/uoalive_v1.zip
    FileDownloadServerPort: 80
    ClientVersion: 7.0.99.1
""", """    FileDownloadServerUrl: mobile.uoalive.com/uoalive_mobile.zip
    FileDownloadServerPort: 80
    ClientVersion: 7.0.117.0
""")
print(f"{root}: controller play, UOAlive 7.0.117.0, com.mobileuo.mobileuo.rg477m")
