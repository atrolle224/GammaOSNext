package com.rg477m.padback;

import android.accessibilityservice.AccessibilityService;
import android.content.SharedPreferences;
import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.accessibility.AccessibilityEvent;

// The chosen buttons on their controllers become Android's Back and Home; every other key passes.
public class BackService extends AccessibilityService {
    static final String PREFS = "padback";
    static final String[] ROLES = {"back", "home"};

    @Override
    protected boolean onKeyEvent(KeyEvent e) {
        SharedPreferences p = getSharedPreferences(PREFS, MODE_PRIVATE);
        for (String role : ROLES) {
            if (!matches(p, role, e)) {
                continue;
            }
            if (e.getAction() == KeyEvent.ACTION_UP && !e.isCanceled()) {
                performGlobalAction(role.equals("home") ? GLOBAL_ACTION_HOME : GLOBAL_ACTION_BACK);
            }
            return true;
        }
        return false;
    }

    static boolean matches(SharedPreferences p, String role, KeyEvent e) {
        int key = p.getInt(role + "_key", KeyEvent.KEYCODE_UNKNOWN);
        if (key == KeyEvent.KEYCODE_UNKNOWN || e.getKeyCode() != key) {
            return false;
        }
        String device = p.getString(role + "_device", "");
        InputDevice d = e.getDevice();
        return device.isEmpty() || (d != null && device.equals(d.getName()));
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
    }

    @Override
    public void onInterrupt() {
    }
}
