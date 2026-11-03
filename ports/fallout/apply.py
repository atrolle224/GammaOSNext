#!/usr/bin/env python3
"""Adds controller input and RG477M packaging to a fallout1-ce or fallout2-ce checkout.

usage: apply.py <checkout> <app name> <application id>
"""
import os
import shutil
import sys

root, app_name, app_id = sys.argv[1:4]
here = os.path.dirname(os.path.abspath(__file__))


def edit(path, old, new, count=1):
    with open(path) as f:
        s = f.read()
    if s.count(old) != count:
        sys.exit(f"{path}: expected {count} of {old!r}, found {s.count(old)}")
    with open(path, "w") as f:
        f.write(s.replace(old, new))


if os.path.exists(os.path.join(root, "src/dinput.cc")):
    # fallout2-ce
    src_dir, include, dinput, input_cc = "src", '"gamepad.h"', "src/dinput.cc", "src/input.cc"
    mouse_init, kb_disabled, process_key = "mouseDeviceInit()", "keyboardIsDisabled()", "_GNW95_process_key"
    cmake_anchor, cmake_entry = '    "src/dinput.cc"\n', '    "src/gamepad.cc"\n    "src/gamepad.h"\n'
else:
    # fallout1-ce
    src_dir, include, dinput, input_cc = "src/plib/gnw", '"plib/gnw/gamepad.h"', "src/plib/gnw/dxinput.cc", "src/plib/gnw/input.cc"
    mouse_init, kb_disabled, process_key = "dxinput_mouse_init()", "kb_is_disabled()", "GNW95_process_key"
    cmake_anchor, cmake_entry = '    "src/plib/gnw/dxinput.cc"\n', '    "src/plib/gnw/gamepad.cc"\n    "src/plib/gnw/gamepad.h"\n'

for name in ("gamepad.cc", "gamepad.h"):
    shutil.copy(os.path.join(here, name), os.path.join(root, src_dir, name))
if src_dir != "src":
    edit(os.path.join(root, src_dir, "gamepad.cc"), '#include "gamepad.h"', f"#include {include}")

edit(os.path.join(root, "CMakeLists.txt"), cmake_anchor, cmake_anchor + cmake_entry)

d = os.path.join(root, dinput)
with open(d) as f:
    first_line = f.readline()
edit(d, first_line, first_line + f"\n#include {include}\n")
edit(d, "bool " + mouse_init + "\n{\n", "bool " + mouse_init + "\n{\n    gamepadInit();\n")
edit(d, "    mouseState->buttons[1] = (buttons & SDL_BUTTON(SDL_BUTTON_RIGHT)) != 0;\n",
     """    mouseState->buttons[1] = (buttons & SDL_BUTTON(SDL_BUTTON_RIGHT)) != 0;

    int padX;
    int padY;
    bool padLeft;
    bool padRight;
    gamepadGetMouse(&padX, &padY, &padLeft, &padRight);
    mouseState->x += padX;
    mouseState->y += padY;
    mouseState->buttons[0] = mouseState->buttons[0] || padLeft;
    mouseState->buttons[1] = mouseState->buttons[1] || padRight;
""")

i = os.path.join(root, input_cc)
with open(i) as f:
    first_line = f.readline()
edit(i, first_line, first_line + f"\n#include {include}\n")
edit(i, "        case SDL_FINGERDOWN:\n", f"""        case SDL_CONTROLLERDEVICEADDED:
        case SDL_CONTROLLERDEVICEREMOVED:
        case SDL_CONTROLLERBUTTONDOWN:
        case SDL_CONTROLLERBUTTONUP:
        case SDL_CONTROLLERAXISMOTION: {{
            GamepadKey padKeys[2];
            int padCount = gamepadHandleEvent(&e, padKeys);
            if (!{kb_disabled}) {{
                for (int padIndex = 0; padIndex < padCount; padIndex++) {{
                    keyboardData.key = padKeys[padIndex].scancode;
                    keyboardData.down = padKeys[padIndex].down;
                    {process_key}(&keyboardData);
                }}
            }}
            break;
        }}
        case SDL_FINGERDOWN:
""")

# RG477M: own package beside the original, arm64 only, one signing key
g = os.path.join(root, "os/android/app/build.gradle")
with open(g) as f:
    s = f.read()
old_id = s.split("applicationId '")[1].split("'")[0]
edit(g, f"applicationId '{old_id}'", f"applicationId '{app_id}'")
edit(g, "abiFilters 'armeabi-v7a', 'arm64-v8a', 'x86', 'x86_64'", "abiFilters 'arm64-v8a'")
edit(g, "            applicationIdSuffix '.debug'\n", "")
strings = os.path.join(root, "os/android/app/src/main/res/values/strings.xml")
with open(strings) as f:
    s = f.read()
old_name = s.split('<string name="app_name">')[1].split("</string>")[0]
edit(strings, f'<string name="app_name">{old_name}</string>', f'<string name="app_name">{app_name}</string>')
print(f"{root}: gamepad input, {app_id}, \"{app_name}\"")
