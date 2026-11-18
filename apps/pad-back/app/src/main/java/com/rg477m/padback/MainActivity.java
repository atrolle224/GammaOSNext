package com.rg477m.padback;

import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.provider.Settings;
import android.view.Gravity;
import android.view.InputDevice;
import android.view.KeyEvent;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.util.Set;
import java.util.TreeSet;

// Learns the buttons that should act as Back and Home: press "Choose", then the button.
public class MainActivity extends Activity {
    private TextView status;
    private String learning;
    private final Set<Integer> held = new TreeSet<>();

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setGravity(Gravity.CENTER_HORIZONTAL);
        int pad = (int) (24 * getResources().getDisplayMetrics().density);
        box.setPadding(pad, pad, pad, pad);

        status = new TextView(this);
        status.setTextSize(18);
        status.setGravity(Gravity.CENTER);
        box.addView(status);

        for (String role : BackService.ROLES) {
            Button choose = new Button(this);
            choose.setText("Choose the " + name(role) + " button");
            choose.setOnClickListener(v -> {
                learning = role;
                held.clear();
                status.setText("Press the button on your controller that should work as "
                        + name(role) + ", or hold two buttons together and let go.\n"
                        + "(If nothing happens, that button sends nothing Android can see.)");
            });
            box.addView(choose);
        }

        Button access = new Button(this);
        access.setText("Turn on Pad Back in Accessibility");
        access.setOnClickListener(v -> startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)));
        box.addView(access);

        Button clear = new Button(this);
        clear.setText("Forget all buttons");
        clear.setOnClickListener(v -> {
            prefs().edit().clear().apply();
            learning = null;
            show();
        });
        box.addView(clear);

        setContentView(box);
        show();
    }

    private static String name(String role) {
        switch (role) {
            case "home":
                return "Home";
            case "power":
                return "Power menu";
            case "clear":
                return "Close all apps";
            default:
                return "Back";
        }
    }

    private SharedPreferences prefs() {
        return getSharedPreferences(BackService.PREFS, MODE_PRIVATE);
    }

    private void show() {
        SharedPreferences p = prefs();
        StringBuilder s = new StringBuilder();
        for (String role : BackService.ROLES) {
            Set<Integer> keys = BackService.keys(p, role);
            s.append(name(role)).append(": ");
            if (keys.isEmpty()) {
                s.append("not chosen\n");
            } else {
                StringBuilder k = new StringBuilder();
                for (int code : keys) {
                    k.append(k.length() > 0 ? " + " : "")
                            .append(KeyEvent.keyCodeToString(code).replace("KEYCODE_", ""));
                }
                s.append(k).append(" on ")
                        .append(p.getString(role + "_device", "any controller")).append('\n');
            }
        }
        s.append("\nPad Back must also be on in Accessibility.");
        status.setText(s);
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent e) {
        if (learning == null) {
            return super.dispatchKeyEvent(e);
        }
        int code = e.getKeyCode();
        boolean pad = (e.getSource() & (InputDevice.SOURCE_GAMEPAD | InputDevice.SOURCE_JOYSTICK)) != 0;
        if (code == KeyEvent.KEYCODE_BACK && !pad) {
            return super.dispatchKeyEvent(e);
        }
        if (e.getAction() == KeyEvent.ACTION_DOWN) {
            held.add(code);
        } else if (e.getAction() == KeyEvent.ACTION_UP && !held.isEmpty()) {
            held.add(code);
            StringBuilder keys = new StringBuilder();
            for (int k : held) {
                keys.append(keys.length() > 0 ? "," : "").append(k);
            }
            InputDevice d = e.getDevice();
            prefs().edit()
                    .putString(learning + "_keys", keys.toString())
                    .putString(learning + "_device", d != null ? d.getName() : "")
                    .apply();
            learning = null;
            held.clear();
            show();
        }
        return true;
    }
}
