package com.rg477m.osrspad;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.provider.Settings;
import android.util.TypedValue;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

/** Start/stop, the one-time permissions, and the controls. */
public class MainActivity extends Activity {
    static final String PREFS = "pad";
    static final String KEY_AUTOSTART = "autostart";

    static final String CONTROLS =
            "OSRS PAD 477M CONTROLS\n\n"
            + "Right stick  -  move the cursor (R3 centres it)\n"
            + "A  -  tap / attack / interact where the cursor is (hold to drag)\n"
            + "B  -  long-press: the right-click options menu\n"
            + "Left stick  -  walk: one step-tap per push in that direction\n"
            + "D-pad  -  turn the camera\n"
            + "L1 / R1  -  zoom out / in\n"
            + "X  -  continue dialogue (Space)\n"
            + "Y or Start  -  close the open interface (Esc)\n"
            + "L2 / R2 (hold)  -  Shift / Ctrl\n"
            + "Select  -  chat (Enter)\n"
            + "L3  -  show these controls again\n\n"
            + "Both controllers work at once. Touch still works as normal.";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        SharedPreferences prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        int pad = Math.round(20 * getResources().getDisplayMetrics().density);

        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(pad, pad, pad, pad);

        TextView title = new TextView(this);
        title.setText("OSRS Pad 477M");
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 26);
        box.addView(title);

        TextView about = new TextView(this);
        about.setText("Plays the official Old School RuneScape app with your controller. It only takes over "
                + "while OSRS is open and does nothing on its own: every button press is one action. "
                + "The first start asks Magisk for root and turns on the cursor overlay.");
        about.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
        about.setPadding(0, pad / 2, 0, pad / 2);
        box.addView(about);

        TextView status = new TextView(this);
        status.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        box.addView(status);

        Button start = new Button(this);
        start.setText("Start");
        start.setOnClickListener(v -> {
            grantOnce();
            startForegroundService(new Intent(this, PadService.class));
            status.setText("Running. Open Old School RuneScape.");
        });
        box.addView(start);

        Button stop = new Button(this);
        stop.setText("Stop");
        stop.setOnClickListener(v -> {
            stopService(new Intent(this, PadService.class));
            status.setText("Stopped.");
        });
        box.addView(stop);

        CheckBox auto = new CheckBox(this);
        auto.setText("Start automatically after a reboot");
        auto.setChecked(prefs.getBoolean(KEY_AUTOSTART, true));
        auto.setOnCheckedChangeListener((b, on) -> prefs.edit().putBoolean(KEY_AUTOSTART, on).apply());
        box.addView(auto);

        TextView controls = new TextView(this);
        controls.setText(CONTROLS);
        controls.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
        controls.setPadding(0, pad, 0, 0);
        box.addView(controls);

        status.setText(PadService.running ? "Running." : "Not running.");

        ScrollView scroll = new ScrollView(this);
        scroll.addView(box);
        setContentView(scroll);
    }

    /** Overlay and notification permissions, granted through Magisk so there is no settings detour. */
    private void grantOnce() {
        String pkg = getPackageName();
        if (!Settings.canDrawOverlays(this)) {
            try {
                Runtime.getRuntime().exec(new String[] {"su", "-c", "appops set " + pkg + " SYSTEM_ALERT_WINDOW allow; "
                        + "pm grant " + pkg + " " + Manifest.permission.POST_NOTIFICATIONS}).waitFor();
            } catch (Exception ignored) {
                // falls back to the settings screen below
            }
        }
        if (!Settings.canDrawOverlays(this)) {
            startActivity(new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    android.net.Uri.parse("package:" + pkg)));
        }
    }
}
