#include "gamepad.h"

#include <math.h>

namespace fallout {

// Left stick moves the cursor, A and B are the mouse buttons; the rest press keys.
// Speed is in game pixels per poll at full tilt.
#define GAMEPAD_DEADZONE 7000
#define GAMEPAD_CURSOR_SPEED 12.0f
#define GAMEPAD_KEY_THRESHOLD 16000

static SDL_GameController* gGamepads[4];
static float gCursorRemainderX = 0.0f;
static float gCursorRemainderY = 0.0f;
static bool gLeftDown = false;
static bool gRightDown = false;
// right stick and triggers, as pressed keys
static SDL_Scancode gAxisKey[SDL_CONTROLLER_AXIS_MAX][2];

static SDL_Scancode buttonScancode(Uint8 button)
{
    switch (button) {
    case SDL_CONTROLLER_BUTTON_X:
        return SDL_SCANCODE_I;
    case SDL_CONTROLLER_BUTTON_Y:
        return SDL_SCANCODE_P;
    case SDL_CONTROLLER_BUTTON_BACK:
        return SDL_SCANCODE_C;
    case SDL_CONTROLLER_BUTTON_START:
        return SDL_SCANCODE_ESCAPE;
    case SDL_CONTROLLER_BUTTON_LEFTSHOULDER:
        return SDL_SCANCODE_B;
    case SDL_CONTROLLER_BUTTON_RIGHTSHOULDER:
        return SDL_SCANCODE_N;
    case SDL_CONTROLLER_BUTTON_LEFTSTICK:
        return SDL_SCANCODE_S;
    case SDL_CONTROLLER_BUTTON_RIGHTSTICK:
        return SDL_SCANCODE_RETURN;
    case SDL_CONTROLLER_BUTTON_DPAD_UP:
        return SDL_SCANCODE_UP;
    case SDL_CONTROLLER_BUTTON_DPAD_DOWN:
        return SDL_SCANCODE_DOWN;
    case SDL_CONTROLLER_BUTTON_DPAD_LEFT:
        return SDL_SCANCODE_LEFT;
    case SDL_CONTROLLER_BUTTON_DPAD_RIGHT:
        return SDL_SCANCODE_RIGHT;
    default:
        return SDL_SCANCODE_UNKNOWN;
    }
}

// [axis][0] = negative direction, [axis][1] = positive
static SDL_Scancode axisScancode(Uint8 axis, int positive)
{
    switch (axis) {
    case SDL_CONTROLLER_AXIS_RIGHTX:
        return positive ? SDL_SCANCODE_RIGHT : SDL_SCANCODE_LEFT;
    case SDL_CONTROLLER_AXIS_RIGHTY:
        return positive ? SDL_SCANCODE_DOWN : SDL_SCANCODE_UP;
    case SDL_CONTROLLER_AXIS_TRIGGERLEFT:
        return positive ? SDL_SCANCODE_SPACE : SDL_SCANCODE_UNKNOWN;
    case SDL_CONTROLLER_AXIS_TRIGGERRIGHT:
        return positive ? SDL_SCANCODE_A : SDL_SCANCODE_UNKNOWN;
    default:
        return SDL_SCANCODE_UNKNOWN;
    }
}

bool gamepadInit()
{
    return SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER) == 0;
}

static void gamepadOpen(int deviceIndex)
{
    if (!SDL_IsGameController(deviceIndex)) {
        return;
    }

    for (int index = 0; index < 4; index++) {
        if (gGamepads[index] == NULL) {
            gGamepads[index] = SDL_GameControllerOpen(deviceIndex);
            return;
        }
    }
}

static void gamepadClose(SDL_JoystickID instanceId)
{
    for (int index = 0; index < 4; index++) {
        if (gGamepads[index] != NULL
            && SDL_JoystickInstanceID(SDL_GameControllerGetJoystick(gGamepads[index])) == instanceId) {
            SDL_GameControllerClose(gGamepads[index]);
            gGamepads[index] = NULL;
        }
    }
}

int gamepadHandleEvent(SDL_Event* event, GamepadKey* keys)
{
    switch (event->type) {
    case SDL_CONTROLLERDEVICEADDED:
        gamepadOpen(event->cdevice.which);
        return 0;
    case SDL_CONTROLLERDEVICEREMOVED:
        gamepadClose(event->cdevice.which);
        return 0;
    case SDL_CONTROLLERBUTTONDOWN:
    case SDL_CONTROLLERBUTTONUP: {
        bool down = event->type == SDL_CONTROLLERBUTTONDOWN;
        if (event->cbutton.button == SDL_CONTROLLER_BUTTON_A) {
            gLeftDown = down;
            return 0;
        }
        if (event->cbutton.button == SDL_CONTROLLER_BUTTON_B) {
            gRightDown = down;
            return 0;
        }
        SDL_Scancode scancode = buttonScancode(event->cbutton.button);
        if (scancode == SDL_SCANCODE_UNKNOWN) {
            return 0;
        }
        keys[0].scancode = scancode;
        keys[0].down = down;
        return 1;
    }
    case SDL_CONTROLLERAXISMOTION: {
        Uint8 axis = event->caxis.axis;
        int value = event->caxis.value;
        int count = 0;
        if (axis >= SDL_CONTROLLER_AXIS_MAX) {
            return 0;
        }
        for (int positive = 0; positive < 2; positive++) {
            SDL_Scancode scancode = axisScancode(axis, positive);
            bool pressed = positive ? value > GAMEPAD_KEY_THRESHOLD : value < -GAMEPAD_KEY_THRESHOLD;
            bool wasPressed = gAxisKey[axis][positive] != SDL_SCANCODE_UNKNOWN;
            if (scancode == SDL_SCANCODE_UNKNOWN || pressed == wasPressed) {
                continue;
            }
            gAxisKey[axis][positive] = pressed ? scancode : SDL_SCANCODE_UNKNOWN;
            keys[count].scancode = scancode;
            keys[count].down = pressed;
            count++;
        }
        return count;
    }
    }

    return 0;
}

static float stickValue(Sint16 raw)
{
    int value = raw;
    if (value > -GAMEPAD_DEADZONE && value < GAMEPAD_DEADZONE) {
        return 0.0f;
    }

    float normalized = (fabsf((float)value) - GAMEPAD_DEADZONE) / (32767.0f - GAMEPAD_DEADZONE);
    if (normalized > 1.0f) {
        normalized = 1.0f;
    }

    // squared: fine aim near the centre, fast at full tilt
    normalized = normalized * normalized;
    return value < 0 ? -normalized : normalized;
}

void gamepadGetMouse(int* dx, int* dy, bool* left, bool* right)
{
    float x = 0.0f;
    float y = 0.0f;

    for (int index = 0; index < 4; index++) {
        if (gGamepads[index] != NULL) {
            x += stickValue(SDL_GameControllerGetAxis(gGamepads[index], SDL_CONTROLLER_AXIS_LEFTX));
            y += stickValue(SDL_GameControllerGetAxis(gGamepads[index], SDL_CONTROLLER_AXIS_LEFTY));
        }
    }

    gCursorRemainderX += x * GAMEPAD_CURSOR_SPEED;
    gCursorRemainderY += y * GAMEPAD_CURSOR_SPEED;
    *dx = (int)gCursorRemainderX;
    *dy = (int)gCursorRemainderY;
    gCursorRemainderX -= *dx;
    gCursorRemainderY -= *dy;
    *left = gLeftDown;
    *right = gRightDown;
}

} // namespace fallout
