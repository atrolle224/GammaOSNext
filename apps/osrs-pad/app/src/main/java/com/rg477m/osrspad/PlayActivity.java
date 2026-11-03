package com.rg477m.osrspad;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.widget.Toast;

/** Daijishou's Play button: start the controller helper, then open Old School RuneScape. */
public class PlayActivity extends Activity {
    static final String OSRS = "com.jagex.oldscape.android";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        if (!PadService.running) {
            startForegroundService(new Intent(this, PadService.class));
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
