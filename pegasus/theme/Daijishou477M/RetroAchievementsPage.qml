import QtQuick 2.15
import "Palette.js" as P

// RetroAchievements: profile, points, rank, the game in progress and recent unlocks.
// Needs the user name and the Web API key (retroachievements.org > Settings > Keys),
// which stay in this theme's settings on the device.
FocusScope {
    id: page

    signal back()

    readonly property string apiBase: api.memory.get("ra_api") || "https://retroachievements.org/API/"
    readonly property string mediaBase: api.memory.get("ra_media") || "https://media.retroachievements.org"
    readonly property bool configured: !!api.memory.get("ra_user") && !!api.memory.get("ra_key")
    property bool editing: !configured
    property var summary: null
    property string error: ""
    property bool loading: false
    property date updated

    function media(path) {
        if (!path || path === "null")
            return "";
        return path.indexOf("http") === 0 ? path : mediaBase + path;
    }

    function open() {
        editing = !configured;
        if (editing) {
            userField.text = api.memory.get("ra_user") || "";
            keyField.text = "";
            userField.forceActiveFocus();
        } else {
            dashboard.forceActiveFocus();
            if (!summary || (new Date() - updated) > 60000)
                refresh();
        }
    }

    function save() {
        var u = userField.text.trim();
        var k = keyField.text.trim();
        if (!u || (!k && !api.memory.get("ra_key")))
            return;
        api.memory.set("ra_user", u);
        if (k)
            api.memory.set("ra_key", k);
        Qt.inputMethod.hide();
        summary = null;
        editing = false;
        dashboard.forceActiveFocus();
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
        running: page.visible && !page.editing
        repeat: true
        onTriggered: page.refresh()
    }

    // ---------------------------------------------------------------- sign-in

    FocusScope {
        id: form
        anchors.fill: parent
        visible: page.editing

        Column {
            anchors.centerIn: parent
            width: Math.min(parent.width - vpx(80), vpx(720))
            spacing: vpx(18)

            Text {
                width: parent.width
                text: "Connect RetroAchievements"
                color: P.text
                font.family: global.fonts.sans
                font.pixelSize: vpx(28)
                font.bold: true
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Your user name and your Web API key, from retroachievements.org > Settings > Keys. "
                      + "The key is not your password: this page only reads your profile. Both stay on this device."
                color: P.dim
                font.family: global.fonts.sans
                font.pixelSize: vpx(16)
                lineHeight: 1.15
            }

            Field {
                id: userField
                width: parent.width
                label: "User name"
                KeyNavigation.down: keyField
                onAccepted: keyField.forceActiveFocus()
            }

            Field {
                id: keyField
                width: parent.width
                label: api.memory.get("ra_key") ? "Web API key (leave empty to keep the saved one)" : "Web API key"
                secret: true
                KeyNavigation.up: userField
                KeyNavigation.down: saveButton
                onAccepted: page.save()
            }

            Rectangle {
                id: saveButton
                width: vpx(200)
                height: vpx(48)
                radius: height / 2
                color: activeFocus ? P.accent : P.panelHi
                KeyNavigation.up: keyField

                Text {
                    anchors.centerIn: parent
                    text: "Save"
                    color: P.text
                    font.family: global.fonts.sans
                    font.pixelSize: vpx(18)
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: page.save()
                }

                Keys.onPressed: {
                    if (api.keys.isAccept(event) && !event.isAutoRepeat) {
                        event.accepted = true;
                        page.save();
                    }
                }
            }
        }

        Keys.onPressed: {
            if (api.keys.isCancel(event) && !event.isAutoRepeat) {
                event.accepted = true;
                Qt.inputMethod.hide();
                if (page.configured) {
                    page.editing = false;
                    dashboard.forceActiveFocus();
                } else {
                    page.back();
                }
            }
        }
    }

    // ---------------------------------------------------------------- dashboard

    FocusScope {
        id: dashboard
        anchors.fill: parent
        anchors.leftMargin: vpx(28)
        anchors.rightMargin: vpx(28)
        anchors.topMargin: vpx(8)
        visible: !page.editing

        readonly property var s: page.summary

        Keys.onPressed: {
            if (event.isAutoRepeat)
                return;
            if (api.keys.isCancel(event)) {
                event.accepted = true;
                page.back();
            } else if (api.keys.isDetails(event)) {
                event.accepted = true;
                page.refresh();
            } else if (api.keys.isFilters(event)) {
                event.accepted = true;
                page.editing = true;
                userField.text = api.memory.get("ra_user") || "";
                keyField.text = "";
                userField.forceActiveFocus();
            }
        }

        Text {
            anchors.centerIn: parent
            visible: !dashboard.s
            width: parent.width * 0.7
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: page.error || "Loading RetroAchievements…"
            color: page.error ? P.accent : P.dim
            font.family: global.fonts.sans
            font.pixelSize: vpx(20)
        }

        // profile card
        Rectangle {
            id: profile
            visible: !!dashboard.s
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: vpx(170)
            radius: vpx(18)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: P.colours("retroachievements")[0] }
                GradientStop { position: 1.0; color: P.colours("retroachievements")[1] }
            }

            Rectangle {
                id: avatarFrame
                anchors.left: parent.left
                anchors.leftMargin: vpx(22)
                anchors.verticalCenter: parent.verticalCenter
                width: vpx(124)
                height: width
                radius: vpx(16)
                color: "#40000000"
                clip: true

                Image {
                    anchors.fill: parent
                    source: dashboard.s ? dashboard.s.avatar : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            Column {
                anchors.left: avatarFrame.right
                anchors.leftMargin: vpx(22)
                anchors.right: stats.left
                anchors.rightMargin: vpx(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: vpx(6)

                Text {
                    width: parent.width
                    text: dashboard.s ? dashboard.s.user : ""
                    elide: Text.ElideRight
                    color: P.text
                    font.family: global.fonts.sans
                    font.pixelSize: vpx(32)
                    font.bold: true
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: dashboard.s ? (dashboard.s.presence || dashboard.s.motto) : ""
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    color: P.text
                    opacity: 0.85
                    font.family: global.fonts.sans
                    font.pixelSize: vpx(16)
                }
                Text {
                    text: page.loading ? "Updating…"
                          : page.error ? page.error
                          : "Updated " + Qt.formatTime(page.updated, "HH:mm")
                    color: page.error ? "#ffd0d6" : P.text
                    opacity: 0.7
                    font.family: global.fonts.sans
                    font.pixelSize: vpx(13)
                }
            }

            Row {
                id: stats
                anchors.right: parent.right
                anchors.rightMargin: vpx(22)
                anchors.verticalCenter: parent.verticalCenter
                spacing: vpx(26)

                Stat { value: dashboard.s ? dashboard.s.hardcore : 0; label: "Hardcore points" }
                Stat { value: dashboard.s ? dashboard.s.softcore : 0; label: "Softcore points" }
                Stat {
                    value: dashboard.s && dashboard.s.rank ? dashboard.s.rank : 0
                    prefix: "#"
                    label: dashboard.s && dashboard.s.ranked ? "of " + Number(dashboard.s.ranked).toLocaleString(Qt.locale(), "f", 0) : "Rank"
                }
            }
        }

        // the game played last, and how far along it is
        Rectangle {
            id: gameCard
            visible: !!(dashboard.s && dashboard.s.game)
            anchors.top: profile.bottom
            anchors.topMargin: vpx(16)
            anchors.left: parent.left
            anchors.right: parent.right
            height: vpx(122)
            radius: vpx(16)
            color: P.panel

            readonly property var g: dashboard.s ? dashboard.s.game : null

            Image {
                id: gameIcon
                anchors.left: parent.left
                anchors.leftMargin: vpx(16)
                anchors.verticalCenter: parent.verticalCenter
                width: vpx(90)
                height: width
                source: gameCard.g ? gameCard.g.icon : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Column {
                anchors.left: gameIcon.right
                anchors.leftMargin: vpx(18)
                anchors.right: parent.right
                anchors.rightMargin: vpx(20)
                anchors.verticalCenter: parent.verticalCenter
                spacing: vpx(6)

                Text {
                    text: "LAST PLAYED"
                    color: P.dim
                    font.family: global.fonts.sans
                    font.pixelSize: vpx(12)
                    font.bold: true
                    font.letterSpacing: vpx(1.5)
                }
                Text {
                    width: parent.width
                    text: gameCard.g ? gameCard.g.title + (gameCard.g.console ? "  ·  " + gameCard.g.console : "") : ""
                    elide: Text.ElideRight
                    color: P.text
                    font.family: global.fonts.sans
                    font.pixelSize: vpx(21)
                    font.bold: true
                }

                Item {
                    width: parent.width
                    height: vpx(26)
                    visible: gameCard.g && gameCard.g.total > 0

                    Rectangle {
                        id: track
                        anchors.left: parent.left
                        anchors.right: progressText.left
                        anchors.rightMargin: vpx(14)
                        anchors.verticalCenter: parent.verticalCenter
                        height: vpx(10)
                        radius: height / 2
                        color: P.panelHi

                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            width: gameCard.g && gameCard.g.total ? parent.width * gameCard.g.got / gameCard.g.total : 0
                            color: "#e8b923"
                        }
                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            width: gameCard.g && gameCard.g.total ? parent.width * gameCard.g.gotHardcore / gameCard.g.total : 0
                            color: P.accent
                        }
                    }

                    Text {
                        id: progressText
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: gameCard.g ? gameCard.g.got + " / " + gameCard.g.total + "  ("
                              + Math.round(100 * gameCard.g.got / Math.max(1, gameCard.g.total)) + "%)" : ""
                        color: P.text
                        font.family: global.fonts.sans
                        font.pixelSize: vpx(16)
                    }
                }
            }
        }

        Text {
            id: recentTitle
            visible: !!dashboard.s
            anchors.top: gameCard.visible ? gameCard.bottom : profile.bottom
            anchors.topMargin: vpx(20)
            anchors.left: parent.left
            text: dashboard.s && dashboard.s.recent.length === 0 ? "No achievements unlocked lately." : "RECENT UNLOCKS"
            color: P.dim
            font.family: global.fonts.sans
            font.pixelSize: vpx(13)
            font.bold: true
            font.letterSpacing: vpx(1.5)
        }

        // two columns of recent achievements
        Grid {
            visible: !!dashboard.s
            anchors.top: recentTitle.bottom
            anchors.topMargin: vpx(10)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            columns: 2
            columnSpacing: vpx(14)
            rowSpacing: vpx(10)
            clip: true

            Repeater {
                model: dashboard.s ? Math.min(dashboard.s.recent.length, 10) : 0

                Rectangle {
                    readonly property var a: dashboard.s.recent[index]
                    width: (dashboard.width - vpx(14)) / 2
                    height: vpx(76)
                    radius: vpx(12)
                    color: P.panel

                    Image {
                        id: badge
                        anchors.left: parent.left
                        anchors.leftMargin: vpx(10)
                        anchors.verticalCenter: parent.verticalCenter
                        width: vpx(56)
                        height: width
                        source: a.badge
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                    }
                    Rectangle {
                        anchors.fill: badge
                        anchors.margins: -vpx(2)
                        color: "transparent"
                        radius: vpx(4)
                        border.width: vpx(2)
                        border.color: a.hardcore ? "#e8b923" : "transparent"
                    }

                    Column {
                        anchors.left: badge.right
                        anchors.leftMargin: vpx(12)
                        anchors.right: pts.left
                        anchors.rightMargin: vpx(8)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: vpx(3)

                        Text {
                            width: parent.width
                            text: a.title
                            elide: Text.ElideRight
                            color: P.text
                            font.family: global.fonts.sans
                            font.pixelSize: vpx(16)
                            font.bold: true
                        }
                        Text {
                            width: parent.width
                            text: a.game
                            elide: Text.ElideRight
                            color: P.dim
                            font.family: global.fonts.sans
                            font.pixelSize: vpx(13)
                        }
                        Text {
                            width: parent.width
                            text: a.date.substring(0, 16)
                            color: P.dim
                            opacity: 0.8
                            font.family: global.fonts.sans
                            font.pixelSize: vpx(12)
                        }
                    }

                    Text {
                        id: pts
                        anchors.right: parent.right
                        anchors.rightMargin: vpx(12)
                        anchors.verticalCenter: parent.verticalCenter
                        text: a.points
                        color: a.hardcore ? "#e8b923" : P.text
                        font.family: global.fonts.sans
                        font.pixelSize: vpx(22)
                        font.bold: true
                    }
                }
            }
        }
    }
}
