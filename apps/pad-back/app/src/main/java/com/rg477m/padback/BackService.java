package com.rg477m.padback;

import android.accessibilityservice.AccessibilityService;
import android.content.SharedPreferences;
import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.accessibility.AccessibilityEvent;

import java.util.HashSet;
import java.util.Set;

// The chosen buttons on their controllers become Android's Back and Home. A single button is
// taken from the app in front; a pair of buttons acts when they are held together and let go,
// and each still reaches the app on its own.
public class BackService extends AccessibilityService {
    static final String PREFS = "padback";
    static final String[] ROLES = {"back", "home"};

    private final Set<Integer> down = new HashSet<>();

    static Set<Integer> keys(SharedPreferences p, String role) {
        Set<Integer> s = new HashSet<>();
        for (String k : p.getString(role + "_keys", "").split(",")) {
            if (!k.isEmpty()) {
                s.add(Integer.parseInt(k));
            }
        }
        return s;
    }

    private static boolean onDevice(SharedPreferences p, String role, KeyEvent e) {
        String device = p.getString(role + "_device", "");
        InputDevice d = e.getDevice();
        return device.isEmpty() || (d != null && device.equals(d.getName()));
    }

    @Override
    protected boolean onKeyEvent(KeyEvent e) {
        SharedPreferences p = getSharedPreferences(PREFS, MODE_PRIVATE);
        int code = e.getKeyCode();
        boolean up = e.getAction() == KeyEvent.ACTION_UP;
        boolean taken = false;
        for (String role : ROLES) {
            Set<Integer> combo = keys(p, role);
            if (!combo.contains(code) || !onDevice(p, role, e)) {
                continue;
            }
            if (combo.size() == 1) {
                if (up && !e.isCanceled()) {
                    act(role);
                }
                taken = true;
            } else if (up && down.containsAll(combo)) {
                act(role);
            }
        }
        if (up) {
            down.remove(code);
        } else {
            down.add(code);
        }
        return taken;
    }

    private void act(String role) {
        down.clear();
        performGlobalAction(role.equals("home") ? GLOBAL_ACTION_HOME : GLOBAL_ACTION_BACK);
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
    }

    @Override
    public void onInterrupt() {
    }
}
