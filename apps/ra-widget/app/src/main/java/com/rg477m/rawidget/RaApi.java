package com.rg477m.rawidget;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Iterator;
import java.util.List;

/** RetroAchievements Web API: the profile summary the widget shows. */
final class RaApi {
    private static final String API = "https://retroachievements.org/API/";
    private static final String MEDIA = "https://media.retroachievements.org";
    private static final String USER_AGENT = "RA-Widget-477M/1.0";

    static final class Achievement {
        String title;
        String game;
        int points;
        boolean hardcore;
        String date;
        String badgeUrl;
    }

    static final class Summary {
        String user;
        String avatarUrl;
        long points;
        long truePoints;
        String rank;
        String gameTitle;
        String gameConsole;
        String gameIconUrl;
        String richPresence;
        final List<Achievement> recent = new ArrayList<>();
    }

    private RaApi() {
    }

    static Summary fetch(String user, String apiKey, int maxAchievements) throws IOException {
        String url = API + "API_GetUserSummary.php?u=" + URLEncoder.encode(user, "UTF-8")
                + "&y=" + URLEncoder.encode(apiKey, "UTF-8") + "&g=1&a=" + maxAchievements;
        JSONObject o;
        try {
            o = new JSONObject(new String(get(url), "UTF-8"));
        } catch (org.json.JSONException e) {
            throw new IOException("RetroAchievements sent something unexpected (check the user name and Web API key)");
        }

        Summary s = new Summary();
        s.user = o.optString("User", user);
        s.avatarUrl = media(o.optString("UserPic", ""));
        s.points = o.optLong("TotalPoints", 0);
        s.truePoints = o.optLong("TotalTruePoints", 0);
        Object rank = o.opt("Rank");
        s.rank = rank == null || rank == JSONObject.NULL ? "" : String.valueOf(rank);
        s.richPresence = o.optString("RichPresenceMsg", "");

        JSONObject last = o.optJSONObject("LastGame");
        JSONArray played = o.optJSONArray("RecentlyPlayed");
        if (last == null && played != null && played.length() > 0) {
            last = played.optJSONObject(0);
        }
        if (last != null) {
            s.gameTitle = last.optString("Title", "");
            s.gameConsole = last.optString("ConsoleName", "");
            s.gameIconUrl = media(last.optString("ImageIcon", ""));
        }

        // {gameId: {achievementId: {...}}}, or [] when there are none
        JSONObject byGame = o.optJSONObject("RecentAchievements");
        if (byGame != null) {
            for (Iterator<String> g = byGame.keys(); g.hasNext(); ) {
                JSONObject achievements = byGame.optJSONObject(g.next());
                if (achievements == null) {
                    continue;
                }
                for (Iterator<String> a = achievements.keys(); a.hasNext(); ) {
                    JSONObject j = achievements.optJSONObject(a.next());
                    if (j == null) {
                        continue;
                    }
                    Achievement x = new Achievement();
                    x.title = j.optString("Title", "");
                    x.game = j.optString("GameTitle", "");
                    x.points = j.optInt("Points", 0);
                    x.hardcore = j.optInt("HardcoreAchieved", 0) == 1;
                    x.date = j.optString("DateAwarded", "");
                    String badge = j.optString("BadgeName", "");
                    x.badgeUrl = badge.isEmpty() ? null : MEDIA + "/Badge/" + badge + ".png";
                    s.recent.add(x);
                }
            }
        }
        Collections.sort(s.recent, (l, r) -> r.date.compareTo(l.date));
        while (s.recent.size() > maxAchievements) {
            s.recent.remove(s.recent.size() - 1);
        }
        return s;
    }

    static Bitmap image(String url, int maxPx) {
        if (url == null || url.isEmpty()) {
            return null;
        }
        try {
            byte[] data = get(url);
            Bitmap b = BitmapFactory.decodeByteArray(data, 0, data.length);
            if (b != null && (b.getWidth() > maxPx || b.getHeight() > maxPx)) {
                b = Bitmap.createScaledBitmap(b, maxPx, maxPx, true);
            }
            return b;
        } catch (IOException | RuntimeException e) {
            return null;
        }
    }

    private static String media(String path) {
        if (path == null || path.isEmpty() || path.equals("null")) {
            return null;
        }
        return path.startsWith("http") ? path : MEDIA + path;
    }

    private static byte[] get(String url) throws IOException {
        HttpURLConnection c = (HttpURLConnection) new URL(url).openConnection();
        c.setConnectTimeout(15000);
        c.setReadTimeout(20000);
        c.setRequestProperty("User-Agent", USER_AGENT);
        try {
            int code = c.getResponseCode();
            if (code == 401 || code == 403) {
                throw new IOException("RetroAchievements refused the Web API key");
            }
            if (code != 200) {
                throw new IOException("RetroAchievements answered " + code);
            }
            try (InputStream in = c.getInputStream()) {
                ByteArrayOutputStream out = new ByteArrayOutputStream();
                byte[] buf = new byte[16384];
                int n;
                while ((n = in.read(buf)) > 0) {
                    out.write(buf, 0, n);
                }
                return out.toByteArray();
            }
        } finally {
            c.disconnect();
        }
    }
}
