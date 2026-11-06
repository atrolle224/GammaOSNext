package com.rg477m.osrspad;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.widget.Toast;

/** Daijishou's Play button: open Old School RuneScape, or the setup if the service is off. */
public class PlayActivity extends Activity {
    static final String OSRS = "com.jagex.oldscape.android";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        if (PadAccessibilityService.instance == null) {
            Toast.makeText(this, "Turn on OSRS Pad 477M in Accessibility settings first", Toast.LENGTH_LONG).show();
            startActivity(new Intent(this, MainActivity.class));
            finish();
            return;
        }
        Intent game = getPackageManager().getLaunchIntentForPackage(OSRS);
        if (game != null) {
            game.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(game);
        } else {
            Toast.makeText(this, "Install Old School RuneScape from the Play Store first", Toast.LENGTH_LONG).show();
        }
        finish();
    }
}
