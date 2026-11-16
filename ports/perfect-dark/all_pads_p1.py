"""477M: every connected controller also plays as player 1 (Input.AllPadsPlayer1, on by default),
so the built-in controls and a Bluetooth pad both work with nothing to set up."""
import sys

path = sys.argv[1]
src = open(path).read()


def edit(old, new):
    global src
    if src.count(old) != 1:
        sys.exit(f"all_pads_p1: expected one {old!r}")
    src = src.replace(old, new)


edit("static s32 firstController = 0;\n", """static s32 firstController = 0;
static s32 allPadsPlayer1 = 1;

/* player 1 reads every connected pad: the stick pushed furthest wins */
static s32 inputPadAxis(s32 idx, s32 axis)
{
	if (idx != 0 || !allPadsPlayer1) {
		return pads[idx] ? SDL_GameControllerGetAxis(pads[idx], axis) : 0;
	}
	s32 best = 0;
	for (s32 i = 0; i < INPUT_MAX_CONTROLLERS; ++i) {
		if (pads[i]) {
			const s32 v = SDL_GameControllerGetAxis(pads[i], axis);
			if (abs(v) > abs(best)) {
				best = v;
			}
		}
	}
	return best;
}

static s32 inputAnyPad(s32 idx)
{
	if (idx != 0 || !allPadsPlayer1) {
		return pads[idx] != NULL;
	}
	for (s32 i = 0; i < INPUT_MAX_CONTROLLERS; ++i) {
		if (pads[i]) {
			return 1;
		}
	}
	return 0;
}
""")

edit("""	if (!pads[idx]) {
		return 0;
	}

	s32 leftX = SDL_GameControllerGetAxis(pads[idx], cfg->axisMap[0][0]);
	s32 leftY = SDL_GameControllerGetAxis(pads[idx], cfg->axisMap[0][1]);
	s32 rightX = SDL_GameControllerGetAxis(pads[idx], cfg->axisMap[1][0]);
	s32 rightY = SDL_GameControllerGetAxis(pads[idx], cfg->axisMap[1][1]);
""", """	if (!inputAnyPad(idx)) {
		return 0;
	}

	s32 leftX = inputPadAxis(idx, cfg->axisMap[0][0]);
	s32 leftY = inputPadAxis(idx, cfg->axisMap[0][1]);
	s32 rightX = inputPadAxis(idx, cfg->axisMap[1][0]);
	s32 rightY = inputPadAxis(idx, cfg->axisMap[1][1]);
""")

edit("""		if (idx < 0 || idx >= INPUT_MAX_CONTROLLERS || !pads[idx]) {
			return 0;
		}
		vk = vk % INPUT_MAX_CONTROLLER_BUTTONS;
		// triggers
		if (vk == 30 || vk == 31) {
			const s32 trig = SDL_CONTROLLER_AXIS_TRIGGERLEFT + vk - 30;
			return SDL_GameControllerGetAxis(pads[idx], trig) > TRIG_THRESHOLD;
		}
		return SDL_GameControllerGetButton(pads[idx], vk);
""", """		if (idx < 0 || idx >= INPUT_MAX_CONTROLLERS || !inputAnyPad(idx)) {
			return 0;
		}
		vk = vk % INPUT_MAX_CONTROLLER_BUTTONS;
		for (s32 i = 0; i < INPUT_MAX_CONTROLLERS; ++i) {
			if (!pads[i] || (i != idx && (idx != 0 || !allPadsPlayer1))) {
				continue;
			}
			// triggers
			if (vk == 30 || vk == 31) {
				const s32 trig = SDL_CONTROLLER_AXIS_TRIGGERLEFT + vk - 30;
				if (SDL_GameControllerGetAxis(pads[i], trig) > TRIG_THRESHOLD) {
					return 1;
				}
			} else if (SDL_GameControllerGetButton(pads[i], vk)) {
				return 1;
			}
		}
		return 0;
""")

edit('	configRegisterInt("Input.FirstGamepadNum", &firstController, 0, 3);\n',
     '	configRegisterInt("Input.FirstGamepadNum", &firstController, 0, 3);\n'
     '	configRegisterInt("Input.AllPadsPlayer1", &allPadsPlayer1, 0, 1);\n')

open(path, "w").write(src)
