package com.rg477m.osrspad;

import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Bundle;
import android.provider.Settings;
import android.util.TypedValue;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.SeekBar;
import android.widget.TextView;

/** Turning the service on, the options, and the controls. */
public class MainActivity extends Activity {
    static final String PREFS = "pad";
    static final String KEY_CAPTURE = "capture";
    static final String KEY_SPEED = "speed";

    private TextView status;

    static String controls() {
        return "OSRS PAD 477M CONTROLS\n\n"
                + "D-pad (or either stick)  -  move the cursor, faster the longer you hold\n"
                + "A or R3 (right stick click)  -  tap / attack / interact at the cursor\n"
                + "B or L3 (left stick click)  -  long-press: the right-click options menu\n"
                + "L1 / R1  -  zoom out / in\n"
                + "X  -  camera mode: the d-pad turns the camera (cursor turns blue)\n"
                + "Y  -  back: close the open interface\n"
                + "Select  -  sticks on/off (off lets the touch keyboard type in chat)\n"
                + "Start  -  show these controls\n\n"
                + "Touch still works as normal.";
    }

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
        about.setText("Plays the official Old School RuneScape app with your controller, no root needed. "
                + "It only acts while OSRS is open, and every button press is one action.\n\n"
                + "One-time setup:\n"
                + "1. Tap \"Accessibility settings\" and turn on OSRS Pad 477M.\n"
                + "2. If Android says it's a restricted setting: tap \"App info\" below, then the ⋮ menu "
                + "(top right) → \"Allow restricted settings\", and do step 1 again.");
        about.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
        about.setPadding(0, pad / 2, 0, pad / 2);
        box.addView(about);

        status = new TextView(this);
        status.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        box.addView(status);

        Button access = new Button(this);
        access.setText("Accessibility settings");
        access.setOnClickListener(v -> startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)));
        box.addView(access);

        Button info = new Button(this);
        info.setText("App info");
        info.setOnClickListener(v -> startActivity(new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:" + getPackageName()))));
        box.addView(info);

        Button play = new Button(this);
        play.setText("Play Old School RuneScape");
        play.setOnClickListener(v -> startActivity(new Intent(this, PlayActivity.class)));
        box.addView(play);

        CheckBox capture = new CheckBox(this);
        capture.setText("Read the d-pad and sticks (needed on controllers whose d-pad works like a stick, "
                + "such as Xbox ones; turn off if OSRS misbehaves)");
        capture.setChecked(prefs.getBoolean(KEY_CAPTURE, true));
        capture.setOnCheckedChangeListener((b, on) -> prefs.edit().putBoolean(KEY_CAPTURE, on).apply());
        box.addView(capture);

        TextView speedLabel = new TextView(this);
        speedLabel.setText("Cursor speed");
        speedLabel.setPadding(0, pad / 2, 0, 0);
        box.addView(speedLabel);
        SeekBar speed = new SeekBar(this);
        speed.setMax(6);
        speed.setProgress(prefs.getInt(KEY_SPEED, 2));
        speed.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar s, int value, boolean fromUser) {
                prefs.edit().putInt(KEY_SPEED, value).apply();
            }

            @Override
            public void onStartTrackingTouch(SeekBar s) {
            }

            @Override
            public void onStopTrackingTouch(SeekBar s) {
            }
        });
        box.addView(speed);

        TextView controls = new TextView(this);
        controls.setText(controls());
        controls.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
        controls.setPadding(0, pad, 0, 0);
        box.addView(controls);

        ScrollView scroll = new ScrollView(this);
        scroll.addView(box);
        setContentView(scroll);
    }

    @Override
    protected void onResume() {
        super.onResume();
        status.setText(PadAccessibilityService.instance != null
                ? "Ready: open Old School RuneScape."
                : "Off: turn it on in Accessibility settings.");
    }
}
