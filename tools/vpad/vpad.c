/* A virtual Xbox-style gamepad through uinput, for emulator input tests.
   vpad            create it and keep it until killed
   Reads commands on stdin: "press <code>" "release <code>" "axis <code> <value>". */
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/uinput.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int fd;

static void emit(int type, int code, int value)
{
	struct input_event e;
	memset(&e, 0, sizeof e);
	e.type = type;
	e.code = code;
	e.value = value;
	if (write(fd, &e, sizeof e) < 0)
		perror("write");
}

static void absaxis(int code, int min, int max)
{
	struct uinput_abs_setup a;
	memset(&a, 0, sizeof a);
	a.code = code;
	a.absinfo.minimum = min;
	a.absinfo.maximum = max;
	ioctl(fd, UI_SET_ABSBIT, code);
	ioctl(fd, UI_ABS_SETUP, &a);
}

int main(void)
{
	static const int keys[] = {BTN_A, BTN_B, BTN_X, BTN_Y, BTN_TL, BTN_TR, BTN_SELECT, BTN_START,
	                           BTN_MODE, BTN_THUMBL, BTN_THUMBR};
	struct uinput_setup s;
	char line[128];
	unsigned i;

	fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
	if (fd < 0) {
		perror("uinput");
		return 1;
	}
	ioctl(fd, UI_SET_EVBIT, EV_KEY);
	for (i = 0; i < sizeof keys / sizeof keys[0]; i++)
		ioctl(fd, UI_SET_KEYBIT, keys[i]);
	ioctl(fd, UI_SET_EVBIT, EV_ABS);
	absaxis(ABS_X, -32768, 32767);
	absaxis(ABS_Y, -32768, 32767);
	absaxis(ABS_RX, -32768, 32767);
	absaxis(ABS_RY, -32768, 32767);
	absaxis(ABS_Z, 0, 1023);
	absaxis(ABS_RZ, 0, 1023);
	absaxis(ABS_HAT0X, -1, 1);
	absaxis(ABS_HAT0Y, -1, 1);
	memset(&s, 0, sizeof s);
	s.id.bustype = BUS_USB;
	s.id.vendor = 0x045e;
	s.id.product = 0x028e;
	strcpy(s.name, "Microsoft X-Box 360 pad");
	ioctl(fd, UI_DEV_SETUP, &s);
	ioctl(fd, UI_DEV_CREATE);
	fprintf(stderr, "vpad ready\n");
	while (fgets(line, sizeof line, stdin)) {
		int code, value;
		if (sscanf(line, "press %d", &code) == 1)
			emit(EV_KEY, code, 1);
		else if (sscanf(line, "release %d", &code) == 1)
			emit(EV_KEY, code, 0);
		else if (sscanf(line, "axis %d %d", &code, &value) == 2)
			emit(EV_ABS, code, value);
		else
			continue;
		emit(EV_SYN, SYN_REPORT, 0);
	}
	for (;;)
		pause();
}
