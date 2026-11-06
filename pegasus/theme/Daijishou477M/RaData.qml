import QtQuick 2.15

// The user's RetroAchievements summary, shared by the carousel card and the page.
// Refreshes on start, every 5 minutes, and when Pegasus comes back from a game.
Item {
    id: ra

    readonly property string apiBase: api.memory.get("ra_api") || "https://retroachievements.org/API/"
    readonly property string mediaBase: api.memory.get("ra_media") || "https://media.retroachievements.org"
    property bool configured: false
    property var summary: null
    property string error: ""
    property bool loading: false
    property date updated

    function media(path) {
        if (!path || path === "null")
            return "";
        return path.indexOf("http") === 0 ? path : mediaBase + path;
    }

    function setAccount(user, key) {
        api.memory.set("ra_user", user);
        if (key)
            api.memory.set("ra_key", key);
        configured = !!api.memory.get("ra_user") && !!api.memory.get("ra_key");
        summary = null;
        error = "";
        refresh();
    }

    function refresh() {
        if (!configured || loading)
            return;
        loading = true;
        error = "";
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            loading = false;
            if (xhr.status === 401 || xhr.status === 403) {
                error = "RetroAchievements refused the Web API key. Press Y to enter it again.";
                return;
            }
            if (xhr.status !== 200) {
                error = xhr.status === 0 ? "No connection to RetroAchievements." : "RetroAchievements answered " + xhr.status + ".";
                return;
            }
            try {
                summary = parse(JSON.parse(xhr.responseText));
                updated = new Date();
            } catch (e) {
                error = "RetroAchievements sent something unexpected. Check the user name and key (Y).";
            }
        };
        xhr.open("GET", apiBase + "API_GetUserSummary.php?u=" + encodeURIComponent(api.memory.get("ra_user"))
                 + "&y=" + encodeURIComponent(api.memory.get("ra_key")) + "&g=3&a=12");
        xhr.setRequestHeader("User-Agent", "Pegasus-Daijishou477M/1.0");
        xhr.send();
    }

    function parse(o) {
        if (!o || !o.User)
            throw "no user";
        var s = {
            user: o.User,
            avatar: media(o.UserPic),
            hardcore: o.TotalPoints || 0,
            softcore: o.TotalSoftcorePoints || 0,
            truePoints: o.TotalTruePoints || 0,
            rank: o.Rank,
            ranked: o.TotalRanked || 0,
            motto: o.Motto || "",
            presence: o.RichPresenceMsg || "",
            game: null,
            recent: []
        };
        var last = o.LastGame || (o.RecentlyPlayed && o.RecentlyPlayed[0]) || null;
        if (last) {
            var id = String(last.ID || last.GameID || o.LastGameID || "");
            var aw = (o.Awarded && o.Awarded[id]) || {};
            s.game = {
                title: last.Title || "",
                console: last.ConsoleName || "",
                icon: media(last.ImageIcon),
                boxArt: media(last.ImageBoxArt || last.ImageTitle),
                total: aw.NumPossibleAchievements || 0,
                got: aw.NumAchieved || 0,
                gotHardcore: aw.NumAchievedHardcore || 0
            };
        }
        var byGame = o.RecentAchievements;
        if (byGame && !Array.isArray(byGame)) {
            for (var g in byGame)
                for (var a in byGame[g]) {
                    var j = byGame[g][a];
                    s.recent.push({
                        title: j.Title || "",
                        description: j.Description || "",
                        game: j.GameTitle || "",
                        points: j.Points || 0,
                        hardcore: Number(j.HardcoreAchieved) === 1,
                        date: j.DateAwarded || "",
                        badge: j.BadgeName ? mediaBase + "/Badge/" + j.BadgeName + ".png" : ""
                    });
                }
        }
        s.recent.sort(function (l, r) { return l.date < r.date ? 1 : l.date > r.date ? -1 : 0; });
        return s;
    }

    Timer {
        interval: 5 * 60 * 1000
        running: ra.configured && Qt.application.state === Qt.ApplicationActive
        repeat: true
        onTriggered: ra.refresh()
    }

    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive && (new Date() - ra.updated) > 30000)
                ra.refresh();
        }
    }

    Component.onCompleted: {
        configured = !!api.memory.get("ra_user") && !!api.memory.get("ra_key");
        refresh();
    }
}
