package com.rg477m.rawidget;

import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.text.InputType;
import android.util.TypedValue;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

/** Where the user name and Web API key are typed once; they stay in this app's private storage. */
public class SetupActivity extends Activity {
    static final String PREFS = "ra";
    static final String KEY_USER = "user";
    static final String KEY_API = "web_api_key";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        SharedPreferences prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        int pad = dp(24);

        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(pad, pad, pad, pad);

        TextView title = new TextView(this);
        title.setText("RA Widget 477M");
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 28);
        box.addView(title);

        TextView help = new TextView(this);
        help.setText("Enter your RetroAchievements user name and your Web API key. The key is on "
                + "retroachievements.org under Settings > Keys (it is not your password). Both stay on "
                + "this device. Then add the \"RA Widget 477M\" widget on Daijishou's Widgets page and "
                + "make it as large as you like. Tap the widget to refresh it.");
        help.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        help.setPadding(0, dp(12), 0, dp(12));
        box.addView(help);

        EditText user = new EditText(this);
        user.setHint("User name");
        user.setSingleLine(true);
        user.setText(prefs.getString(KEY_USER, ""));
        box.addView(user, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        EditText key = new EditText(this);
        key.setHint(prefs.getString(KEY_API, "").isEmpty() ? "Web API key" : "Web API key (saved; type a new one to replace it)");
        key.setSingleLine(true);
        key.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        box.addView(key, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        Button save = new Button(this);
        save.setText("Save and refresh the widget");
        save.setOnClickListener(v -> {
            String u = user.getText().toString().trim();
            String k = key.getText().toString().trim();
            if (u.isEmpty()) {
                Toast.makeText(this, "Enter your user name", Toast.LENGTH_SHORT).show();
                return;
            }
            SharedPreferences.Editor e = prefs.edit().putString(KEY_USER, u);
            if (!k.isEmpty()) {
                e.putString(KEY_API, k);
            }
            e.apply();
            key.setText("");
            RaWidget.requestRefresh(this);
            Toast.makeText(this, "Saved", Toast.LENGTH_SHORT).show();
        });
        box.addView(save);

        ScrollView scroll = new ScrollView(this);
        scroll.addView(box);
        setContentView(scroll);
    }

    private int dp(int v) {
        return Math.round(v * getResources().getDisplayMetrics().density);
    }
}
