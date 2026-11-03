package com.rg477m.osrspad;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.drawable.GradientDrawable;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.util.Log;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.widget.ImageView;
import android.widget.TextView;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;

/** Runs the root helper and draws the controller cursor and the controls card over OSRS. */
public class PadService extends Service {
    private static final String TAG = "OsrsPad";
    private static final String CHANNEL = "pad";
    static volatile boolean running;

    private final Handler main = new Handler(Looper.getMainLooper());
    private WindowManager wm;
    private ImageView cursor;
    private WindowManager.LayoutParams cursorParams;
    private TextView help;
    private Process helper;
    private Thread reader;

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (running) {
            return START_STICKY;
        }
        running = true;
        startForeground(1, notification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);
        wm = (WindowManager) getSystemService(Context.WINDOW_SERVICE);
        startHelper();
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        running = false;
        stopHelper();
        main.post(() -> {
            removeView(cursor);
            removeView(help);
            cursor = null;
            help = null;
        });
        super.onDestroy();
    }

    private Notification notification() {
        NotificationManager nm = getSystemService(NotificationManager.class);
        nm.createNotificationChannel(new NotificationChannel(CHANNEL, "Controller", NotificationManager.IMPORTANCE_MIN));
        PendingIntent open = PendingIntent.getActivity(this, 0, new Intent(this, MainActivity.class),
                PendingIntent.FLAG_IMMUTABLE);
        return new Notification.Builder(this, CHANNEL)
                .setSmallIcon(R.drawable.ic_pad)
                .setContentTitle("OSRS Pad 477M")
                .setContentText("Controller ready: it takes over while Old School RuneScape is open")
                .setContentIntent(open)
                .setOngoing(true)
                .build();
    }

    private void startHelper() {
        String bin = new File(getApplicationInfo().nativeLibraryDir, "libosrspad.so").getAbsolutePath();
        reader = new Thread(() -> {
            try {
                helper = new ProcessBuilder("su", "-c", bin).redirectErrorStream(false).start();
                BufferedReader in = new BufferedReader(new InputStreamReader(helper.getInputStream()));
                String line;
                while ((line = in.readLine()) != null) {
                    handle(line);
                }
                int code = helper.waitFor();
                Log.w(TAG, "helper exited " + code);
                if (running) {
                    main.post(() -> {
                        showHelp("The controller helper stopped (code " + code + "). Open OSRS Pad 477M and check "
                                + "that Magisk granted it root.", 8000);
                    });
                }
            } catch (Exception e) {
                Log.e(TAG, "helper", e);
            }
        }, "osrspad");
        reader.start();
    }

    private void stopHelper() {
        try {
            Runtime.getRuntime().exec(new String[] {"su", "-c", "pkill -f libosrspad.so"}).waitFor();
        } catch (Exception e) {
            Log.w(TAG, "stop", e);
        }
        if (helper != null) {
            helper.destroy();
        }
    }

    private void handle(String line) {
        String[] f = line.trim().split(" ");
        if (f.length == 0) {
            return;
        }
        switch (f[0]) {
            case "C":
                if (f.length == 3) {
                    int x = Integer.parseInt(f[1]);
                    int y = Integer.parseInt(f[2]);
                    main.post(() -> moveCursor(x, y));
                }
                break;
            case "V":
                boolean on = f.length > 1 && f[1].equals("1");
                main.post(() -> {
                    setCursorVisible(on);
                    if (on) {
                        showHelp(MainActivity.CONTROLS, 9000);
                    } else {
                        removeView(help);
                        help = null;
                    }
                });
                break;
            case "H":
                main.post(() -> showHelp(MainActivity.CONTROLS, 15000));
                break;
            case "E":
                main.post(() -> showHelp("The controller helper couldn't start: it needs root from Magisk.", 8000));
                break;
            default:
                break;
        }
    }

    private WindowManager.LayoutParams overlayParams(int w, int h) {
        WindowManager.LayoutParams p = new WindowManager.LayoutParams(w, h,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                        | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                        | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                        | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT);
        p.gravity = Gravity.TOP | Gravity.START;
        p.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS;
        return p;
    }

    private void setCursorVisible(boolean on) {
        if (on && cursor == null) {
            cursor = new ImageView(this);
            cursor.setImageResource(R.drawable.cursor);
            cursorParams = overlayParams(WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT);
            try {
                wm.addView(cursor, cursorParams);
            } catch (RuntimeException e) {
                Log.e(TAG, "overlay not allowed", e);
                cursor = null;
            }
        } else if (!on) {
            removeView(cursor);
            cursor = null;
        }
    }

    private void moveCursor(int x, int y) {
        if (cursor == null) {
            setCursorVisible(true);
        }
        if (cursor == null) {
            return;
        }
        cursorParams.x = x;
        cursorParams.y = y;
        wm.updateViewLayout(cursor, cursorParams);
    }

    private void showHelp(String text, long ms) {
        if (help == null) {
            help = new TextView(this);
            help.setTextColor(Color.WHITE);
            help.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
            int pad = Math.round(16 * getResources().getDisplayMetrics().density);
            help.setPadding(pad, pad, pad, pad);
            GradientDrawable bg = new GradientDrawable();
            bg.setColor(0xE0101418);
            bg.setCornerRadius(pad);
            help.setBackground(bg);
            WindowManager.LayoutParams p = overlayParams(WindowManager.LayoutParams.WRAP_CONTENT,
                    WindowManager.LayoutParams.WRAP_CONTENT);
            p.gravity = Gravity.CENTER;
            try {
                wm.addView(help, p);
            } catch (RuntimeException e) {
                Log.e(TAG, "overlay not allowed", e);
                help = null;
                return;
            }
        }
        help.setText(text);
        help.setVisibility(View.VISIBLE);
        main.removeCallbacksAndMessages(help);
        main.postAtTime(() -> {
            removeView(help);
            help = null;
        }, help, android.os.SystemClock.uptimeMillis() + ms);
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
