package com.rg477m.osrspad;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.Path;
import android.graphics.PixelFormat;
import android.graphics.drawable.GradientDrawable;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.provider.Settings;
import android.util.DisplayMetrics;
import android.util.Log;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.view.accessibility.AccessibilityEvent;
import android.widget.ImageView;
import android.widget.TextView;

import java.util.HashSet;
import java.util.Set;

/**
 * Controller play for Old School RuneScape without root. While OSRS is in front, the controller
 * buttons arrive through the accessibility key filter and become taps, long-presses and pinches
 * at an on-screen cursor. Android gives accessibility services no stick or d-pad axes, so the
 * optional capture window (a focusable 1-pixel overlay) reads those; buttons work without it.
 */
public class PadAccessibilityService extends AccessibilityService {
    private static final String TAG = "OsrsPad";
    static volatile PadAccessibilityService instance;

    private static final long FRAME_MS = 16;
    private static final long TAP_MS = 40;
    private static final long LONG_PRESS_MS = 650;
    private static final float STICK_DEAD = 0.15f;

    private final Handler main = new Handler(Looper.getMainLooper());
    private final Set<String> ignoredPackages = new HashSet<>();
    private WindowManager wm;
    private SharedPreferences prefs;
    private int screenW, screenH;
    private float density;

    private boolean active;
    private float curX, curY;
    private ImageView cursor;
    private WindowManager.LayoutParams cursorParams;
    private View capture;
    private TextView card;

    // d-pad keys held (-1/0/1), hat and stick axes from the capture window
    private int keyX, keyY;
    private float hatX, hatY, stickX, stickY;
    private long heldSince;
    private boolean moving;
    private boolean cameraMode;
    private long lastCameraSwipe;

    private final Runnable frame = this::step;

    @Override
    protected void onServiceConnected() {
        instance = this;
        wm = getSystemService(WindowManager.class);
        prefs = getSharedPreferences(MainActivity.PREFS, MODE_PRIVATE);
        DisplayMetrics dm = new DisplayMetrics();
        wm.getDefaultDisplay().getRealMetrics(dm);
        screenW = Math.max(dm.widthPixels, dm.heightPixels);
        screenH = Math.min(dm.widthPixels, dm.heightPixels);
        density = dm.density;
        curX = screenW / 2f;
        curY = screenH / 2f;
        ignoredPackages.add(getPackageName());
        ignoredPackages.add("com.android.systemui");
        String ime = Settings.Secure.getString(getContentResolver(), Settings.Secure.DEFAULT_INPUT_METHOD);
        if (ime != null && ime.contains("/")) {
            ignoredPackages.add(ime.substring(0, ime.indexOf('/')));
        }
    }

    @Override
    public boolean onUnbind(android.content.Intent intent) {
        setActive(false);
        instance = null;
        return super.onUnbind(intent);
    }

    @Override
    public void onInterrupt() {
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        if (event.getEventType() != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED || event.getPackageName() == null) {
            return;
        }
        String pkg = event.getPackageName().toString();
        if (ignoredPackages.contains(pkg)) {
            return;
        }
        setActive(pkg.equals(PlayActivity.OSRS));
    }

    private void setActive(boolean on) {
        if (on == active) {
            return;
        }
        active = on;
        if (on) {
            showCursor();
            setCapture(prefs.getBoolean(MainActivity.KEY_CAPTURE, true));
            showCard(MainActivity.controls(), 9000);
        } else {
            keyX = keyY = 0;
            hatX = hatY = stickX = stickY = 0;
            cameraMode = false;
            main.removeCallbacks(frame);
            moving = false;
            setCapture(false);
            removeView(cursor);
            cursor = null;
            removeView(card);
            card = null;
        }
    }

    // ------------------------------------------------------------------ buttons

    @Override
    protected boolean onKeyEvent(KeyEvent event) {
        if (!active || !fromController(event)) {
            return false;
        }
        return handleKey(event);
    }

    private static boolean fromController(KeyEvent event) {
        int source = event.getSource();
        return KeyEvent.isGamepadButton(event.getKeyCode())
                || (source & InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD
                || (source & InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK
                || (source & InputDevice.SOURCE_DPAD) == InputDevice.SOURCE_DPAD;
    }

    private boolean handleKey(KeyEvent event) {
        boolean down = event.getAction() == KeyEvent.ACTION_DOWN;
        boolean first = down && event.getRepeatCount() == 0;
        switch (event.getKeyCode()) {
            case KeyEvent.KEYCODE_DPAD_LEFT:
                keyX = down ? -1 : (keyX == -1 ? 0 : keyX);
                break;
            case KeyEvent.KEYCODE_DPAD_RIGHT:
                keyX = down ? 1 : (keyX == 1 ? 0 : keyX);
                break;
            case KeyEvent.KEYCODE_DPAD_UP:
                keyY = down ? -1 : (keyY == -1 ? 0 : keyY);
                break;
            case KeyEvent.KEYCODE_DPAD_DOWN:
                keyY = down ? 1 : (keyY == 1 ? 0 : keyY);
                break;
            case KeyEvent.KEYCODE_BUTTON_A:
            case KeyEvent.KEYCODE_BUTTON_THUMBR:
            case KeyEvent.KEYCODE_DPAD_CENTER:
                if (first) {
                    press(TAP_MS);
                }
                return true;
            case KeyEvent.KEYCODE_BUTTON_B:
            case KeyEvent.KEYCODE_BUTTON_THUMBL:
                if (first) {
                    press(LONG_PRESS_MS);
                }
                return true;
            case KeyEvent.KEYCODE_BUTTON_L1:
                if (first) {
                    pinch(false);
                }
                return true;
            case KeyEvent.KEYCODE_BUTTON_R1:
                if (first) {
                    pinch(true);
                }
                return true;
            case KeyEvent.KEYCODE_BUTTON_X:
                if (first) {
                    cameraMode = !cameraMode;
                    tintCursor();
                    showCard(cameraMode ? "Camera mode: the d-pad turns the camera. X to go back."
                            : "Cursor mode", 1500);
                }
                return true;
            case KeyEvent.KEYCODE_BUTTON_Y:
                if (first) {
                    performGlobalAction(GLOBAL_ACTION_BACK);
                }
                return true;
            case KeyEvent.KEYCODE_BUTTON_SELECT:
                if (first) {
                    boolean on = capture == null;
                    setCapture(on);
                    showCard(on ? "Sticks on" : "Sticks off: the touch keyboard works for chat. Select to turn "
                            + "them back on.", 2500);
                }
                return true;
            case KeyEvent.KEYCODE_BUTTON_START:
                if (first) {
                    showCard(MainActivity.controls(), 15000);
                }
                return true;
            default:
                return false;
        }
        if (down) {
            startMoving();
        }
        return true;
    }

    // ------------------------------------------------------------------ cursor movement

    private void startMoving() {
        if (!moving) {
            moving = true;
            heldSince = SystemClock.uptimeMillis();
            main.post(frame);
        }
    }

    private void step() {
        float dx = keyX != 0 ? keyX : (hatX != 0 ? hatX : stickX);
        float dy = keyY != 0 ? keyY : (hatY != 0 ? hatY : stickY);
        if (!active || (dx == 0 && dy == 0)) {
            moving = false;
            return;
        }
        long now = SystemClock.uptimeMillis();
        if (cameraMode) {
            if (now - lastCameraSwipe > 180) {
                lastCameraSwipe = now;
                swipeCamera(dx, dy);
            }
        } else {
            float base = prefs.getInt(MainActivity.KEY_SPEED, 2) * 0.25f + 0.25f;
            // speeds up over the first second of holding, for both fine aim and crossing the screen
            float ramp = Math.min(1f, (now - heldSince) / 1000f);
            float speed = screenH * base * (0.35f + 0.65f * ramp) * FRAME_MS / 1000f;
            curX = clamp(curX + dx * speed, 0, screenW - 1);
            curY = clamp(curY + dy * speed, 0, screenH - 1);
            placeCursor();
        }
        main.postDelayed(frame, FRAME_MS);
    }

    private static float clamp(float v, float lo, float hi) {
        return Math.max(lo, Math.min(hi, v));
    }

    private void onAxes(MotionEvent e) {
        hatX = Math.round(e.getAxisValue(MotionEvent.AXIS_HAT_X));
        hatY = Math.round(e.getAxisValue(MotionEvent.AXIS_HAT_Y));
        float rx = e.getAxisValue(MotionEvent.AXIS_Z);
        float ry = e.getAxisValue(MotionEvent.AXIS_RZ);
        if (Math.hypot(rx, ry) < STICK_DEAD) {
            rx = e.getAxisValue(MotionEvent.AXIS_X);
            ry = e.getAxisValue(MotionEvent.AXIS_Y);
        }
        if (Math.hypot(rx, ry) < STICK_DEAD) {
            rx = ry = 0;
        }
        boolean wasStill = stickX == 0 && stickY == 0;
        stickX = rx;
        stickY = ry;
        if (hatX != 0 || hatY != 0 || stickX != 0 || stickY != 0) {
            if (wasStill && !moving) {
                heldSince = SystemClock.uptimeMillis();
            }
            startMoving();
        }
    }

    // ------------------------------------------------------------------ gestures

    private void press(long ms) {
        Path p = new Path();
        p.moveTo(curX, curY);
        dispatch(new GestureDescription.StrokeDescription(p, 0, ms));
    }

    private void pinch(boolean in) {
        float cx = screenW / 2f, cy = screenH / 2f;
        float near = screenH * 0.06f, far = screenH * 0.22f;
        float from = in ? near : far, to = in ? far : near;
        Path a = new Path();
        a.moveTo(cx - from, cy);
        a.lineTo(cx - to, cy);
        Path b = new Path();
        b.moveTo(cx + from, cy);
        b.lineTo(cx + to, cy);
        dispatch(new GestureDescription.StrokeDescription(a, 0, 200),
                new GestureDescription.StrokeDescription(b, 0, 200));
    }

    private void swipeCamera(float dx, float dy) {
        float cx = screenW / 2f, cy = screenH * 0.45f;
        float len = screenH * 0.18f;
        Path p = new Path();
        p.moveTo(cx, cy);
        p.lineTo(cx - Math.signum(dx) * len, cy - Math.signum(dy) * len * 0.6f);
        dispatch(new GestureDescription.StrokeDescription(p, 0, 150));
    }

    private void dispatch(GestureDescription.StrokeDescription... strokes) {
        GestureDescription.Builder g = new GestureDescription.Builder();
        for (GestureDescription.StrokeDescription s : strokes) {
            g.addStroke(s);
        }
        if (!dispatchGesture(g.build(), null, null)) {
            Log.w(TAG, "gesture refused");
        }
    }

    // ------------------------------------------------------------------ overlays

    private WindowManager.LayoutParams overlay(int flags) {
        WindowManager.LayoutParams p = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                flags | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                        | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                        | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT);
        p.gravity = Gravity.TOP | Gravity.START;
        p.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS;
        return p;
    }

    private void showCursor() {
        if (cursor != null) {
            return;
        }
        cursor = new ImageView(this);
        cursor.setImageResource(R.drawable.cursor);
        cursorParams = overlay(WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE);
        placeCursorParams();
        if (!addView(cursor, cursorParams)) {
            cursor = null;
        }
        tintCursor();
    }

    private void placeCursorParams() {
        // the arrow's tip is 2/24 of the 34dp drawable in from its corner
        int tip = Math.round(34 * density * 2 / 24f);
        cursorParams.x = Math.round(curX) - tip;
        cursorParams.y = Math.round(curY) - tip;
    }

    private void placeCursor() {
        if (cursor == null) {
            return;
        }
        placeCursorParams();
        wm.updateViewLayout(cursor, cursorParams);
    }

    private void tintCursor() {
        if (cursor == null) {
            return;
        }
        if (cameraMode) {
            cursor.setColorFilter(0xFF6EC6FF, android.graphics.PorterDuff.Mode.MULTIPLY);
        } else {
            cursor.clearColorFilter();
        }
    }

    /** The 1-pixel focusable window that receives the d-pad hat and sticks. */
    private void setCapture(boolean on) {
        if (on && capture == null) {
            capture = new View(this) {
                @Override
                public boolean onGenericMotionEvent(MotionEvent e) {
                    if ((e.getSource() & InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK
                            && e.getAction() == MotionEvent.ACTION_MOVE) {
                        onAxes(e);
                        return true;
                    }
                    return super.onGenericMotionEvent(e);
                }

                @Override
                public boolean dispatchKeyEvent(KeyEvent e) {
                    // buttons normally arrive through the key filter; this catches any it missed
                    return (active && fromController(e) && handleKey(e)) || super.dispatchKeyEvent(e);
                }
            };
            capture.setFocusable(true);
            capture.setFocusableInTouchMode(true);
            WindowManager.LayoutParams p = overlay(0);
            p.width = 1;
            p.height = 1;
            if (addView(capture, p)) {
                capture.requestFocus();
            } else {
                capture = null;
            }
        } else if (!on && capture != null) {
            removeView(capture);
            capture = null;
            hatX = hatY = stickX = stickY = 0;
        }
    }

    private void showCard(String text, long ms) {
        if (card == null) {
            card = new TextView(this);
            card.setTextColor(Color.WHITE);
            card.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
            int pad = Math.round(16 * density);
            card.setPadding(pad, pad, pad, pad);
            GradientDrawable bg = new GradientDrawable();
            bg.setColor(0xE0101418);
            bg.setCornerRadius(pad);
            card.setBackground(bg);
            WindowManager.LayoutParams p = overlay(WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE);
            p.gravity = Gravity.CENTER;
            if (!addView(card, p)) {
                card = null;
                return;
            }
        }
        card.setText(text);
        main.removeCallbacksAndMessages(card);
        TextView shown = card;
        main.postAtTime(() -> {
            if (card == shown) {
                removeView(card);
                card = null;
            }
        }, shown, SystemClock.uptimeMillis() + ms);
    }

    private boolean addView(View v, WindowManager.LayoutParams p) {
        try {
            wm.addView(v, p);
            return true;
        } catch (RuntimeException e) {
            Log.e(TAG, "overlay", e);
            return false;
        }
    }

    private void removeView(View v) {
        if (v != null) {
            try {
                wm.removeView(v);
            } catch (RuntimeException ignored) {
                // already gone
            }
        }
    }
}
