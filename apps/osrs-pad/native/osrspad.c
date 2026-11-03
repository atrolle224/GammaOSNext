/*
 * OSRS Pad 477M: controller play for the official Old School RuneScape app.
 *
 * Runs as root. While OSRS is in front it takes the controllers (EVIOCGRAB) and
 * turns them into a virtual touchscreen and keyboard: the right stick moves a
 * cursor (drawn by the app, which reads "C x y" lines on stdout), A taps there,
 * B long-presses (OSRS's right-click menu), the left stick taps the ground in its
 * direction once per push, L1/R1 pinch to zoom, the d-pad turns the camera.
 * Every controller action is a single game input; nothing repeats on its own.
 */
#define _GNU_SOURCE
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <linux/uinput.h>
#include <math.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

#define OSRS_PACKAGE "com.jagex.oldscape.android"
#define MAX_PADS 8
#define TOUCH_NAME "OSRS Pad 477M touch"
#define KEYS_NAME "OSRS Pad 477M keys"

#define CURSOR_SPEED 1.1    /* screen heights per second at full tilt */
#define CURSOR_DEAD 0.12
#define WALK_PUSH 0.6       /* stick tilt that counts as a push */
#define WALK_RELEASE 0.3
#define WALK_TURN 0.7       /* cos of the angle that counts as a new direction (about 45 degrees) */
#define WALK_RADIUS 0.32    /* walk tap distance from the player, in screen heights */
#define LONG_PRESS_MS 650
#define TAP_MS 60

typedef struct {
    int fd;
    char path[64];
    int abs_min[ABS_CNT], abs_max[ABS_CNT];
    int rx_axis, ry_axis;    /* right stick: ABS_RX/RY, or ABS_Z/RZ on Bluetooth pads */
    double lx, ly, rx, ry;
    int grabbed;
} Pad;

static Pad pads[MAX_PADS];
static int npads;
static int touch_fd = -1, keys_fd = -1;
static int screen_w = 1280, screen_h = 960;
static double cur_x, cur_y;
static int active;
static volatile sig_atomic_t quit;

/* touch state: slot 0 for taps and long-presses, slots 0+1 for pinches */
static int a_down;
static long long b_release_at;    /* when the long-press lifts, 0 if none */
static long long tap_release_at;  /* when a walk tap lifts */
static int pinch_dir;             /* -1 zoom out, 1 zoom in, 0 none */
static long long pinch_start;
static int tracking_id = 100;

static int walk_pushed;
static double walk_dx, walk_dy;

static long long now_ms(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long) ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static void emit(int fd, int type, int code, int value)
{
    struct input_event ev;
    memset(&ev, 0, sizeof(ev));
    ev.type = type;
    ev.code = code;
    ev.value = value;
    if (write(fd, &ev, sizeof(ev)) < 0) {
        /* the device is gone; the main loop recreates nothing, so stop */
        quit = 1;
    }
}

static void syn(int fd)
{
    emit(fd, EV_SYN, SYN_REPORT, 0);
}

static int bit_set(const unsigned long *bits, int bit)
{
    return (bits[bit / (8 * sizeof(long))] >> (bit % (8 * sizeof(long)))) & 1;
}

static void screen_size(void)
{
    FILE *p = popen("wm size 2>/dev/null", "r");
    char line[128];
    int w, h, got = 0;
    if (!p) {
        return;
    }
    while (fgets(line, sizeof(line), p)) {
        /* "Override size" wins over "Physical size" when both are printed */
        char *s = strstr(line, "size: ");
        if (s && sscanf(s + 6, "%dx%d", &w, &h) == 2 && w > 0 && h > 0) {
            screen_w = w;
            screen_h = h;
            got = 1;
        }
    }
    pclose(p);
    /* the 477M is a landscape panel; make sure width is the long side */
    if (got && screen_h > screen_w) {
        int t = screen_w;
        screen_w = screen_h;
        screen_h = t;
    }
}

static int make_touch(void)
{
    struct uinput_user_dev dev;
    int fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) {
        return -1;
    }
    ioctl(fd, UI_SET_EVBIT, EV_KEY);
    ioctl(fd, UI_SET_EVBIT, EV_ABS);
    ioctl(fd, UI_SET_EVBIT, EV_SYN);
    ioctl(fd, UI_SET_KEYBIT, BTN_TOUCH);
    ioctl(fd, UI_SET_ABSBIT, ABS_MT_SLOT);
    ioctl(fd, UI_SET_ABSBIT, ABS_MT_TRACKING_ID);
    ioctl(fd, UI_SET_ABSBIT, ABS_MT_POSITION_X);
    ioctl(fd, UI_SET_ABSBIT, ABS_MT_POSITION_Y);
    ioctl(fd, UI_SET_ABSBIT, ABS_MT_PRESSURE);
    ioctl(fd, UI_SET_PROPBIT, INPUT_PROP_DIRECT);

    memset(&dev, 0, sizeof(dev));
    snprintf(dev.name, sizeof(dev.name), TOUCH_NAME);
    dev.id.bustype = BUS_VIRTUAL;
    dev.id.vendor = 0x477;
    dev.id.product = 0x1;
    dev.absmax[ABS_MT_SLOT] = 1;
    dev.absmax[ABS_MT_TRACKING_ID] = 65535;
    dev.absmax[ABS_MT_POSITION_X] = screen_w - 1;
    dev.absmax[ABS_MT_POSITION_Y] = screen_h - 1;
    dev.absmax[ABS_MT_PRESSURE] = 255;
    if (write(fd, &dev, sizeof(dev)) != sizeof(dev) || ioctl(fd, UI_DEV_CREATE) < 0) {
        close(fd);
        return -1;
    }
    return fd;
}

static const int key_list[] = {
    KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ESC, KEY_SPACE, KEY_ENTER,
    KEY_LEFTSHIFT, KEY_LEFTCTRL, KEY_TAB
};

static int make_keys(void)
{
    struct uinput_user_dev dev;
    size_t i;
    int fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) {
        return -1;
    }
    ioctl(fd, UI_SET_EVBIT, EV_KEY);
    ioctl(fd, UI_SET_EVBIT, EV_SYN);
    for (i = 0; i < sizeof(key_list) / sizeof(key_list[0]); i++) {
        ioctl(fd, UI_SET_KEYBIT, key_list[i]);
    }
    /* letters make Android treat it as a full keyboard, which OSRS listens to */
    for (i = KEY_Q; i <= KEY_P; i++) {
        ioctl(fd, UI_SET_KEYBIT, (int) i);
    }
    for (i = KEY_A; i <= KEY_L; i++) {
        ioctl(fd, UI_SET_KEYBIT, (int) i);
    }
    for (i = KEY_Z; i <= KEY_M; i++) {
        ioctl(fd, UI_SET_KEYBIT, (int) i);
    }
    memset(&dev, 0, sizeof(dev));
    snprintf(dev.name, sizeof(dev.name), KEYS_NAME);
    dev.id.bustype = BUS_VIRTUAL;
    dev.id.vendor = 0x477;
    dev.id.product = 0x2;
    if (write(fd, &dev, sizeof(dev)) != sizeof(dev) || ioctl(fd, UI_DEV_CREATE) < 0) {
        close(fd);
        return -1;
    }
    return fd;
}

static void key(int code, int down)
{
    emit(keys_fd, EV_KEY, code, down);
    syn(keys_fd);
}

static void touch_down(int slot, int x, int y)
{
    emit(touch_fd, EV_ABS, ABS_MT_SLOT, slot);
    emit(touch_fd, EV_ABS, ABS_MT_TRACKING_ID, tracking_id++ & 0xffff);
    emit(touch_fd, EV_ABS, ABS_MT_POSITION_X, x);
    emit(touch_fd, EV_ABS, ABS_MT_POSITION_Y, y);
    emit(touch_fd, EV_ABS, ABS_MT_PRESSURE, 60);
    emit(touch_fd, EV_KEY, BTN_TOUCH, 1);
    syn(touch_fd);
}

static void touch_move(int slot, int x, int y)
{
    emit(touch_fd, EV_ABS, ABS_MT_SLOT, slot);
    emit(touch_fd, EV_ABS, ABS_MT_POSITION_X, x);
    emit(touch_fd, EV_ABS, ABS_MT_POSITION_Y, y);
    syn(touch_fd);
}

static void touch_up(int slot, int last)
{
    emit(touch_fd, EV_ABS, ABS_MT_SLOT, slot);
    emit(touch_fd, EV_ABS, ABS_MT_TRACKING_ID, -1);
    if (last) {
        emit(touch_fd, EV_KEY, BTN_TOUCH, 0);
    }
    syn(touch_fd);
}

static int touching(void)
{
    return a_down || b_release_at || tap_release_at || pinch_dir;
}

static double norm(const Pad *p, int axis, int value)
{
    int lo = p->abs_min[axis], hi = p->abs_max[axis];
    double v;
    if (hi <= lo) {
        return 0;
    }
    v = (2.0 * (value - lo) / (hi - lo)) - 1.0;
    return v < -1 ? -1 : v > 1 ? 1 : v;
}

static int is_own(const char *name)
{
    return strstr(name, "OSRS Pad 477M") != NULL;
}

static void scan_pads(void)
{
    DIR *d = opendir("/dev/input");
    struct dirent *e;
    if (!d) {
        return;
    }
    while ((e = readdir(d)) && npads < MAX_PADS) {
        char path[64], name[128] = "";
        unsigned long keybits[(KEY_MAX + 1) / (8 * sizeof(long)) + 1];
        unsigned long absbits[(ABS_MAX + 1) / (8 * sizeof(long)) + 1];
        int fd, i, known = 0;
        Pad *p;
        if (strncmp(e->d_name, "event", 5) != 0) {
            continue;
        }
        snprintf(path, sizeof(path), "/dev/input/%s", e->d_name);
        for (i = 0; i < npads; i++) {
            if (strcmp(pads[i].path, path) == 0) {
                known = 1;
            }
        }
        if (known || (fd = open(path, O_RDONLY | O_NONBLOCK)) < 0) {
            continue;
        }
        memset(keybits, 0, sizeof(keybits));
        memset(absbits, 0, sizeof(absbits));
        ioctl(fd, EVIOCGNAME(sizeof(name)), name);
        ioctl(fd, EVIOCGBIT(EV_KEY, sizeof(keybits)), keybits);
        ioctl(fd, EVIOCGBIT(EV_ABS, sizeof(absbits)), absbits);
        if (is_own(name) || !bit_set(keybits, BTN_SOUTH) || !bit_set(absbits, ABS_X)) {
            close(fd);
            continue;
        }
        p = &pads[npads++];
        memset(p, 0, sizeof(*p));
        p->fd = fd;
        snprintf(p->path, sizeof(p->path), "%s", path);
        for (i = 0; i < ABS_CNT; i++) {
            struct input_absinfo info;
            if (bit_set(absbits, i) && ioctl(fd, EVIOCGABS(i), &info) == 0) {
                p->abs_min[i] = info.minimum;
                p->abs_max[i] = info.maximum;
            }
        }
        p->rx_axis = bit_set(absbits, ABS_RX) ? ABS_RX : ABS_Z;
        p->ry_axis = bit_set(absbits, ABS_RY) ? ABS_RY : ABS_RZ;
        if (active) {
            p->grabbed = ioctl(fd, EVIOCGRAB, 1) == 0;
        }
        fprintf(stderr, "controller: %s (%s)\n", name, path);
    }
    closedir(d);
}

static void drop_pad(int i)
{
    close(pads[i].fd);
    pads[i] = pads[--npads];
}

static int osrs_in_front(void)
{
    FILE *p = popen("dumpsys activity activities 2>/dev/null | grep -m1 topResumedActivity", "r");
    char line[512] = "";
    int front;
    if (!p) {
        return 0;
    }
    if (!fgets(line, sizeof(line), p)) {
        line[0] = '\0';
    }
    pclose(p);
    front = strstr(line, OSRS_PACKAGE) != NULL;
    return front;
}

static void release_all(void)
{
    size_t i;
    if (touching()) {
        touch_up(1, 0);
        touch_up(0, 1);
    }
    a_down = 0;
    b_release_at = tap_release_at = 0;
    pinch_dir = 0;
    for (i = 0; i < sizeof(key_list) / sizeof(key_list[0]); i++) {
        emit(keys_fd, EV_KEY, key_list[i], 0);
    }
    syn(keys_fd);
}

static void set_active(int on)
{
    int i;
    if (on == active) {
        return;
    }
    if (!on) {
        release_all();
    }
    for (i = 0; i < npads; i++) {
        pads[i].grabbed = ioctl(pads[i].fd, EVIOCGRAB, on ? 1 : 0) == 0 && on;
    }
    active = on;
    printf("V %d\n", on);
    fflush(stdout);
}

static void on_button(int code, int value)
{
    int x = (int) cur_x, y = (int) cur_y;
    switch (code) {
    case BTN_SOUTH: /* A: tap, hold to drag */
        if (value == 1 && !touching()) {
            a_down = 1;
            touch_down(0, x, y);
        } else if (value == 0 && a_down) {
            a_down = 0;
            touch_up(0, 1);
        }
        break;
    case BTN_EAST: /* B: long-press, OSRS's right-click menu */
        if (value == 1 && !touching()) {
            touch_down(0, x, y);
            b_release_at = now_ms() + LONG_PRESS_MS;
        }
        break;
    case BTN_TL: /* L1 / R1: pinch out / in */
    case BTN_TR:
        if (value == 1 && !touching()) {
            pinch_dir = code == BTN_TR ? 1 : -1;
            pinch_start = now_ms();
        }
        break;
    case BTN_NORTH: /* X on Xbox-style pads: continue dialogue */
        key(KEY_SPACE, value != 0);
        break;
    case BTN_WEST: /* Y: close the open interface */
        key(KEY_ESC, value != 0);
        break;
    case BTN_TL2: /* L2 / R2 held: Shift / Ctrl */
        key(KEY_LEFTSHIFT, value != 0);
        break;
    case BTN_TR2:
        key(KEY_LEFTCTRL, value != 0);
        break;
    case BTN_SELECT:
        key(KEY_ENTER, value != 0);
        break;
    case BTN_START:
        key(KEY_ESC, value != 0);
        break;
    case BTN_THUMBR: /* R3: cursor back to the middle */
        if (value == 1) {
            cur_x = screen_w / 2.0;
            cur_y = screen_h / 2.0;
            printf("C %d %d\n", (int) cur_x, (int) cur_y);
            fflush(stdout);
        }
        break;
    case BTN_THUMBL: /* L3: the app shows the controls */
        if (value == 1) {
            printf("H\n");
            fflush(stdout);
        }
        break;
    case BTN_DPAD_UP:
        key(KEY_UP, value != 0);
        break;
    case BTN_DPAD_DOWN:
        key(KEY_DOWN, value != 0);
        break;
    case BTN_DPAD_LEFT:
        key(KEY_LEFT, value != 0);
        break;
    case BTN_DPAD_RIGHT:
        key(KEY_RIGHT, value != 0);
        break;
    default:
        break;
    }
}

static int hat_x, hat_y;

static void on_hat(int axis, int value)
{
    if (axis == ABS_HAT0X) {
        if (value != hat_x) {
            if (hat_x < 0) key(KEY_LEFT, 0);
            if (hat_x > 0) key(KEY_RIGHT, 0);
            if (value < 0) key(KEY_LEFT, 1);
            if (value > 0) key(KEY_RIGHT, 1);
            hat_x = value;
        }
    } else {
        if (value != hat_y) {
            if (hat_y < 0) key(KEY_UP, 0);
            if (hat_y > 0) key(KEY_DOWN, 0);
            if (value < 0) key(KEY_UP, 1);
            if (value > 0) key(KEY_DOWN, 1);
            hat_y = value;
        }
    }
}

static int trigger_l, trigger_r;

static void on_trigger(Pad *p, int axis, int value)
{
    int held = norm(p, axis, value) > 0.0;
    if (axis == ABS_Z || axis == ABS_BRAKE) {
        if (held != trigger_l) {
            key(KEY_LEFTSHIFT, held);
            trigger_l = held;
        }
    } else if (held != trigger_r) {
        key(KEY_LEFTCTRL, held);
        trigger_r = held;
    }
}

static void read_pad(int i)
{
    Pad *p = &pads[i];
    struct input_event ev;
    ssize_t n;
    while ((n = read(p->fd, &ev, sizeof(ev))) == sizeof(ev)) {
        if (!active) {
            continue;
        }
        if (ev.type == EV_KEY) {
            on_button(ev.code, ev.value);
        } else if (ev.type == EV_ABS) {
            if (ev.code == ABS_X) {
                p->lx = norm(p, ABS_X, ev.value);
            } else if (ev.code == ABS_Y) {
                p->ly = norm(p, ABS_Y, ev.value);
            } else if (ev.code == p->rx_axis) {
                p->rx = norm(p, p->rx_axis, ev.value);
            } else if (ev.code == p->ry_axis) {
                p->ry = norm(p, p->ry_axis, ev.value);
            } else if (ev.code == ABS_HAT0X || ev.code == ABS_HAT0Y) {
                on_hat(ev.code, ev.value);
            } else if (ev.code == ABS_BRAKE || ev.code == ABS_GAS
                       || (p->rx_axis == ABS_RX && (ev.code == ABS_Z || ev.code == ABS_RZ))) {
                on_trigger(p, ev.code, ev.value);
            }
        }
    }
    if (n < 0 && errno != EAGAIN && errno != EWOULDBLOCK) {
        fprintf(stderr, "controller gone: %s\n", p->path);
        drop_pad(i);
    }
}

static void tick(double dt)
{
    double rx = 0, ry = 0, lx = 0, ly = 0, tilt, len;
    int i;
    long long t = now_ms();

    for (i = 0; i < npads; i++) {
        if (pads[i].rx * pads[i].rx + pads[i].ry * pads[i].ry > rx * rx + ry * ry) {
            rx = pads[i].rx;
            ry = pads[i].ry;
        }
        if (pads[i].lx * pads[i].lx + pads[i].ly * pads[i].ly > lx * lx + ly * ly) {
            lx = pads[i].lx;
            ly = pads[i].ly;
        }
    }

    /* right stick: cursor */
    tilt = sqrt(rx * rx + ry * ry);
    if (tilt > CURSOR_DEAD) {
        double k = (fmin(tilt, 1.0) - CURSOR_DEAD) / (1.0 - CURSOR_DEAD);
        double step = k * k * CURSOR_SPEED * screen_h * dt / tilt;
        cur_x = fmin(fmax(cur_x + rx * step, 0), screen_w - 1);
        cur_y = fmin(fmax(cur_y + ry * step, 0), screen_h - 1);
        if (a_down) {
            touch_move(0, (int) cur_x, (int) cur_y);
        }
        printf("C %d %d\n", (int) cur_x, (int) cur_y);
        fflush(stdout);
    }

    /* left stick: one walk tap per push or new direction */
    len = sqrt(lx * lx + ly * ly);
    if (len > WALK_PUSH) {
        double dx = lx / len, dy = ly / len;
        if (!walk_pushed || dx * walk_dx + dy * walk_dy < WALK_TURN) {
            if (!touching()) {
                int x = (int) (screen_w / 2.0 + dx * WALK_RADIUS * screen_h);
                int y = (int) (screen_h / 2.0 + dy * WALK_RADIUS * screen_h);
                touch_down(0, x, y);
                tap_release_at = t + TAP_MS;
            }
            walk_pushed = 1;
            walk_dx = dx;
            walk_dy = dy;
        }
    } else if (len < WALK_RELEASE) {
        walk_pushed = 0;
    }

    if (tap_release_at && t >= tap_release_at) {
        tap_release_at = 0;
        touch_up(0, 1);
    }
    if (b_release_at && t >= b_release_at) {
        b_release_at = 0;
        touch_up(0, 1);
    }

    /* pinch around the screen centre over 250 ms */
    if (pinch_dir) {
        double f = fmin((t - pinch_start) / 250.0, 1.0);
        double from = pinch_dir > 0 ? 0.08 : 0.30, to = pinch_dir > 0 ? 0.30 : 0.08;
        double r = (from + (to - from) * f) * screen_h;
        int cx = screen_w / 2, cy = screen_h / 2;
        if (t == pinch_start || f == 0.0) {
            touch_down(0, (int) (cx - r), cy);
            touch_down(1, (int) (cx + r), cy);
        } else {
            touch_move(0, (int) (cx - r), cy);
            touch_move(1, (int) (cx + r), cy);
        }
        if (f >= 1.0) {
            touch_up(1, 0);
            touch_up(0, 1);
            pinch_dir = 0;
        }
    }
}

static void on_signal(int sig)
{
    (void) sig;
    quit = 1;
}

int main(void)
{
    long long last_front = 0, last_scan = 0, last_tick;
    struct pollfd pfd[MAX_PADS];
    int i;

    signal(SIGTERM, on_signal);
    signal(SIGINT, on_signal);
    signal(SIGPIPE, on_signal);

    screen_size();
    cur_x = screen_w / 2.0;
    cur_y = screen_h / 2.0;
    touch_fd = make_touch();
    keys_fd = make_keys();
    if (touch_fd < 0 || keys_fd < 0) {
        fprintf(stderr, "can't create the virtual devices (is it running as root?)\n");
        printf("E uinput\n");
        fflush(stdout);
        return 1;
    }
    printf("S %d %d\n", screen_w, screen_h);
    fflush(stdout);
    scan_pads();
    last_tick = now_ms();

    while (!quit) {
        long long t = now_ms();
        if (t - last_front >= 1000) {
            last_front = t;
            set_active(osrs_in_front());
        }
        if (t - last_scan >= 3000) {
            last_scan = t;
            scan_pads();
        }
        for (i = 0; i < npads; i++) {
            pfd[i].fd = pads[i].fd;
            pfd[i].events = POLLIN;
            pfd[i].revents = 0;
        }
        poll(pfd, npads, 8);
        for (i = npads - 1; i >= 0; i--) {
            if (pfd[i].revents & (POLLIN | POLLERR | POLLHUP)) {
                read_pad(i);
            }
        }
        t = now_ms();
        if (active) {
            tick((t - last_tick) / 1000.0);
        }
        last_tick = t;
    }

    set_active(0);
    for (i = 0; i < npads; i++) {
        close(pads[i].fd);
    }
    ioctl(touch_fd, UI_DEV_DESTROY);
    ioctl(keys_fd, UI_DEV_DESTROY);
    return 0;
}
