package com.rg477m.playnext;

import android.app.Activity;
import android.os.Bundle;
import android.view.KeyEvent;
import android.webkit.WebSettings;
import android.webkit.WebView;

// The list is a page in the APK; the controller's buttons become the page's keys.
public class MainActivity extends Activity {
    private WebView web;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        web = new WebView(this);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        web.setBackgroundColor(0xFF15171C);
        setContentView(web);
        if (state != null) {
            web.restoreState(state);
        } else {
            web.loadUrl("file:///android_asset/index.html");
        }
        web.requestFocus();
    }

    @Override
    protected void onSaveInstanceState(Bundle out) {
        super.onSaveInstanceState(out);
        web.saveState(out);
    }

    private void pad(String key) {
        web.evaluateJavascript("window.pad&&pad('" + key + "')", null);
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent e) {
        String key = null;
        switch (e.getKeyCode()) {
            case KeyEvent.KEYCODE_DPAD_UP: key = "up"; break;
            case KeyEvent.KEYCODE_DPAD_DOWN: key = "down"; break;
            case KeyEvent.KEYCODE_DPAD_LEFT: key = "left"; break;
            case KeyEvent.KEYCODE_DPAD_RIGHT: key = "right"; break;
            case KeyEvent.KEYCODE_BUTTON_A:
            case KeyEvent.KEYCODE_DPAD_CENTER:
            case KeyEvent.KEYCODE_ENTER: key = "a"; break;
            case KeyEvent.KEYCODE_BUTTON_B:
            case KeyEvent.KEYCODE_BACK:
            case KeyEvent.KEYCODE_ESCAPE: key = "b"; break;
            case KeyEvent.KEYCODE_BUTTON_X: key = "x"; break;
            case KeyEvent.KEYCODE_BUTTON_Y: key = "y"; break;
            case KeyEvent.KEYCODE_BUTTON_L1: key = "l1"; break;
            case KeyEvent.KEYCODE_BUTTON_R1: key = "r1"; break;
            case KeyEvent.KEYCODE_BUTTON_L2: key = "l2"; break;
            case KeyEvent.KEYCODE_BUTTON_R2: key = "r2"; break;
            case KeyEvent.KEYCODE_BUTTON_START: key = "start"; break;
            case KeyEvent.KEYCODE_BUTTON_SELECT: key = "select"; break;
            default: break;
        }
        if (key == null) {
            return super.dispatchKeyEvent(e);
        }
        if (e.getAction() == KeyEvent.ACTION_DOWN) {
            if ("b".equals(key) && e.getKeyCode() == KeyEvent.KEYCODE_BACK && e.getRepeatCount() == 0) {
                web.evaluateJavascript("window.pad?pad('b'):false", v -> {
                    if (!"true".equals(v)) {
                        finish();
                    }
                });
                return true;
            }
            pad(key);
        }
        return true;
    }
}
