#ifndef FALLOUT_GAMEPAD_H_
#define FALLOUT_GAMEPAD_H_

#include <SDL.h>

namespace fallout {

typedef struct GamepadKey {
    SDL_Scancode scancode;
    bool down;
} GamepadKey;

bool gamepadInit();

// Returns how many entries of keys (room for 2) the event pressed or released.
int gamepadHandleEvent(SDL_Event* event, GamepadKey* keys);

void gamepadGetMouse(int* dx, int* dy, bool* left, bool* right);

} // namespace fallout

#endif /* FALLOUT_GAMEPAD_H_ */
