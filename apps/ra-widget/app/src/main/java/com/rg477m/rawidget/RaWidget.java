package com.rg477m.rawidget;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.view.View;
import android.widget.RemoteViews;

import java.text.NumberFormat;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/** A large RetroAchievements widget: profile, current game and the latest achievements. Tap to refresh. */
public class RaWidget extends AppWidgetProvider {
    static final String ACTION_REFRESH = "com.rg477m.rawidget.REFRESH";
    private static final int ROWS = 5;
    private static final int[] ROW_IDS = {R.id.ach0, R.id.ach1, R.id.ach2, R.id.ach3, R.id.ach4};
    private static final int[] BADGE_IDS = {R.id.ach0_badge, R.id.ach1_badge, R.id.ach2_badge, R.id.ach3_badge, R.id.ach4_badge};
    private static final int[] TITLE_IDS = {R.id.ach0_title, R.id.ach1_title, R.id.ach2_title, R.id.ach3_title, R.id.ach4_title};
    private static final int[] SUB_IDS = {R.id.ach0_sub, R.id.ach1_sub, R.id.ach2_sub, R.id.ach3_sub, R.id.ach4_sub};
    private static final int[] POINT_IDS = {R.id.ach0_points, R.id.ach1_points, R.id.ach2_points, R.id.ach3_points, R.id.ach4_points};

    @Override
    public void onUpdate(Context context, AppWidgetManager manager, int[] ids) {
        refreshAsync(context, goAsync());
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        if (ACTION_REFRESH.equals(intent.getAction())) {
            refreshAsync(context, goAsync());
            return;
        }
        super.onReceive(context, intent);
    }

    static void requestRefresh(Context context) {
        Intent i = new Intent(context, RaWidget.class).setAction(ACTION_REFRESH);
        context.sendBroadcast(i);
    }

    private static void refreshAsync(Context context, PendingResult result) {
        Context app = context.getApplicationContext();
        new Thread(() -> {
            try {
                refresh(app);
            } finally {
                result.finish();
            }
        }, "ra-widget").start();
    }

    private static void refresh(Context context) {
        AppWidgetManager manager = AppWidgetManager.getInstance(context);
        int[] ids = manager.getAppWidgetIds(new ComponentName(context, RaWidget.class));
        if (ids.length == 0) {
            return;
        }

        SharedPreferences prefs = context.getSharedPreferences(SetupActivity.PREFS, Context.MODE_PRIVATE);
        String user = prefs.getString(SetupActivity.KEY_USER, "");
        String key = prefs.getString(SetupActivity.KEY_API, "");

        RemoteViews v = new RemoteViews(context.getPackageName(), R.layout.widget);
        Intent tap = new Intent(context, RaWidget.class).setAction(ACTION_REFRESH);
        v.setOnClickPendingIntent(R.id.root, PendingIntent.getBroadcast(context, 0, tap,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE));

        if (user.isEmpty() || key.isEmpty()) {
            v.setTextViewText(R.id.user, "RetroAchievements");
            v.setTextViewText(R.id.points, "Open RA Widget 477M to sign in");
            manager.updateAppWidget(ids, v);
            return;
        }

        try {
            RaApi.Summary s = RaApi.fetch(user, key, ROWS);
            NumberFormat n = NumberFormat.getIntegerInstance();
            v.setTextViewText(R.id.user, s.user);
            String points = n.format(s.points) + " points";
            if (s.truePoints > 0) {
                points += "  ·  " + n.format(s.truePoints) + " true";
            }
            if (!s.rank.isEmpty()) {
                points += "  ·  rank " + s.rank;
            }
            v.setTextViewText(R.id.points, points);
            Bitmap avatar = RaApi.image(s.avatarUrl, 168);
            if (avatar != null) {
                v.setImageViewBitmap(R.id.avatar, avatar);
            }

            if (s.gameTitle != null && !s.gameTitle.isEmpty()) {
                v.setViewVisibility(R.id.game, View.VISIBLE);
                v.setTextViewText(R.id.game_title, s.gameTitle);
                String sub = s.richPresence != null && !s.richPresence.isEmpty() ? s.richPresence : s.gameConsole;
                v.setTextViewText(R.id.game_sub, sub);
                Bitmap icon = RaApi.image(s.gameIconUrl, 128);
                if (icon != null) {
                    v.setImageViewBitmap(R.id.game_icon, icon);
                }
            }

            v.setViewVisibility(R.id.recent_label, s.recent.isEmpty() ? View.GONE : View.VISIBLE);
            for (int i = 0; i < ROWS; i++) {
                if (i >= s.recent.size()) {
                    v.setViewVisibility(ROW_IDS[i], View.GONE);
                    continue;
                }
                RaApi.Achievement a = s.recent.get(i);
                v.setViewVisibility(ROW_IDS[i], View.VISIBLE);
                v.setTextViewText(TITLE_IDS[i], a.title);
                v.setTextViewText(SUB_IDS[i], a.game + (a.hardcore ? "  ·  hardcore" : ""));
                v.setTextViewText(POINT_IDS[i], a.points + " pts");
                Bitmap badge = RaApi.image(a.badgeUrl, 112);
                if (badge != null) {
                    v.setImageViewBitmap(BADGE_IDS[i], badge);
                }
            }
            v.setTextViewText(R.id.updated, new SimpleDateFormat("HH:mm", Locale.getDefault()).format(new Date()));
        } catch (Exception e) {
            v.setTextViewText(R.id.user, user);
            v.setTextViewText(R.id.points, "Couldn't update: " + e.getMessage() + ". Tap to retry.");
        }
        manager.updateAppWidget(ids, v);
    }
}
