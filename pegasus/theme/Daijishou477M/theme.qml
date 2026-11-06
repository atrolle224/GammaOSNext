// Daijishou 477M: a Daijishou-style library for Pegasus on the Anbernic RG477M.
// Home is a platform carousel; A opens a platform's game list, B goes back.
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License, version 3 or later.

import QtQuick 2.15
import SortFilterProxyModel 0.2
import "Palette.js" as P

FocusScope {
    id: root

    // Home lists Recently Played and Favorites first, when they have games, then every collection.
    readonly property var platforms: {
        var list = [];
        if (recentGames.count > 0)
            list.push({ kind: "recent", shortName: "recent", name: "Recently Played", count: recentGames.count });
        if (favoriteGames.count > 0)
            list.push({ kind: "favorites", shortName: "favorites", name: "Favorites", count: favoriteGames.count });
        var colls = [];
        for (var i = 0; i < api.collections.count; i++) {
            var c = api.collections.get(i);
            colls.push({ kind: "collection", index: i, shortName: c.shortName, name: c.name, count: c.games.count });
        }
        colls.sort(function (a, b) { return P.rank(a.shortName) - P.rank(b.shortName) || a.name.localeCompare(b.name); });
        return list.concat(colls);
    }
    // the platform follows its name, not its place, as Favorites and Recently Played come and go
    property string platformShort: ""
    property bool restored: false
    readonly property var platform: {
        for (var i = 0; i < platforms.length; i++)
            if (platforms[i].shortName === platformShort)
                return platforms[i];
        return platforms.length > 0 ? platforms[0] : null;
    }

    function indexOfPlatform(shortName) {
        for (var i = 0; i < platforms.length; i++)
            if (platforms[i].shortName === shortName)
                return i;
        return -1;
    }

    onPlatformsChanged: {
        if (!restored)
            return;
        var i = indexOfPlatform(platformShort);
        if (i >= 0 && i !== carousel.currentIndex)
            carousel.currentIndex = i;
    }
    property bool inList: false
    property int sortMode: 0  // 0 by title, 1 by last played

    readonly property var currentGame: gameAt(gameList.currentIndex)

    function gameAt(i) {
        if (i < 0 || i >= games.count)
            return null;
        return games.sourceModel.get(games.mapToSource(i));
    }

    function openList() {
        if (!platform || platform.count === 0)
            return;
        inList = true;
        var saved = api.memory.get("game:" + platformShort);
        gameList.currentIndex = (saved !== undefined && saved < games.count) ? saved : 0;
        gameList.positionViewAtIndex(gameList.currentIndex, ListView.Center);
        gameList.forceActiveFocus();
    }

    function closeList() {
        api.memory.set("game:" + platformShort, gameList.currentIndex);
        inList = false;
        carousel.forceActiveFocus();
    }

    function launch() {
        if (!currentGame)
            return;
        api.memory.set("platform", platformShort);
        api.memory.set("game:" + platformShort, gameList.currentIndex);
        api.memory.set("inList", true);
        currentGame.launch();
    }

    // L1/R1 in the list: the first game of the previous/next letter
    function jumpLetter(step) {
        var n = games.count;
        if (n === 0)
            return;
        var letter = function (i) { var g = gameAt(i); return g ? g.sortBy.charAt(0).toUpperCase() : ""; };
        var cur = letter(gameList.currentIndex);
        var i = gameList.currentIndex;
        if (step > 0) {
            while (i < n - 1 && letter(i) === cur) i++;
        } else {
            while (i > 0 && letter(i) === cur) i--;
            var target = letter(i);
            while (i > 0 && letter(i - 1) === target) i--;
        }
        gameList.currentIndex = i;
    }

    SortFilterProxyModel {
        id: recentGames
        sourceModel: api.allGames
        filters: RangeFilter { roleName: "playCount"; minimumValue: 1 }
        sorters: RoleSorter { roleName: "lastPlayed"; sortOrder: Qt.DescendingOrder }
    }

    SortFilterProxyModel {
        id: favoriteGames
        sourceModel: api.allGames
        filters: ValueFilter { roleName: "favorite"; value: true }
    }

    SortFilterProxyModel {
        id: games
        sourceModel: !platform ? null
                   : platform.kind === "collection" ? api.collections.get(platform.index).games
                   : api.allGames
        filters: [
            RangeFilter { roleName: "playCount"; minimumValue: 1; enabled: platform && platform.kind === "recent" },
            ValueFilter { roleName: "favorite"; value: true; enabled: platform && platform.kind === "favorites" }
        ]
        sorters: [
            RoleSorter {
                roleName: "lastPlayed"; sortOrder: Qt.DescendingOrder
                enabled: (platform && platform.kind === "recent") || sortMode === 1
            },
            RoleSorter { roleName: "sortBy"; sortOrder: Qt.AscendingOrder }
        ]
    }

    // ---------------------------------------------------------------- background

    Rectangle {
        anchors.fill: parent
        color: P.bg
    }

    Rectangle {
        anchors.fill: parent
        opacity: 0.55
        gradient: Gradient {
            GradientStop { position: 0.0; color: P.colours(platformShort)[0] }
            GradientStop { position: 1.0; color: P.bg }
        }
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: inList && currentGame && (currentGame.assets.background || currentGame.assets.screenshot)
                ? (currentGame.assets.background || currentGame.assets.screenshot)
                : "assets/wallpapers/" + platformShort + ".jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 640
        visible: status === Image.Ready
        opacity: inList ? 0.22 : 0.4
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#a0000000" }
            GradientStop { position: 0.35; color: "#30000000" }
            GradientStop { position: 1.0; color: "#e0000000" }
        }
    }

    TopBar {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        title: inList && platform ? platform.name : "Library"
        subtitle: inList ? games.count + (games.count === 1 ? " game" : " games")
                : (platforms.length + " platforms")
    }

    // ---------------------------------------------------------------- home: platform carousel

    Item {
        id: home
        anchors.fill: parent
        visible: opacity > 0
        opacity: inList ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 160 } }

        ListView {
            id: carousel
            focus: !inList
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -vpx(30)
            height: vpx(380)

            orientation: ListView.Horizontal
            model: platforms.length
            spacing: vpx(4)
            keyNavigationWraps: true
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: (width - vpx(270)) / 2
            preferredHighlightEnd: preferredHighlightBegin + vpx(270)
            highlightMoveDuration: 180
            snapMode: ListView.SnapToItem

            delegate: PlatformCard {
                width: vpx(270)
                height: vpx(380)
                shortName: platforms[index].shortName
                name: platforms[index].name
                count: platforms[index].count
                selected: ListView.isCurrentItem

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (carousel.currentIndex === index)
                            root.openList();
                        else
                            carousel.currentIndex = index;
                    }
                }
            }

            Keys.onPressed: {
                if (event.isAutoRepeat && !(api.keys.isPrevPage(event) || api.keys.isNextPage(event)))
                    return;
                if (api.keys.isAccept(event)) {
                    event.accepted = true;
                    root.openList();
                } else if (api.keys.isPrevPage(event)) {
                    event.accepted = true;
                    decrementCurrentIndex();
                } else if (api.keys.isNextPage(event)) {
                    event.accepted = true;
                    incrementCurrentIndex();
                }
            }
            onCurrentIndexChanged: {
                if (!root.restored || !platforms[currentIndex])
                    return;
                root.platformShort = platforms[currentIndex].shortName;
                api.memory.set("platform", root.platformShort);
            }
        }

        Column {
            anchors.top: carousel.bottom
            anchors.topMargin: vpx(26)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: vpx(6)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: platform ? platform.name : "No games found"
                color: P.text
                font.family: global.fonts.sans
                font.pixelSize: vpx(28)
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: platforms.length > 0
                text: (indexOfPlatform(platformShort) + 1) + " / " + platforms.length
                color: P.dim
                font.family: global.fonts.sans
                font.pixelSize: vpx(16)
            }
        }

        Text {
            visible: platforms.length === 0
            anchors.centerIn: parent
            width: parent.width * 0.7
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "No games yet.\nPress Start, open Settings > Game directories, and add the ROMs folder on your SD card."
            color: P.dim
            font.family: global.fonts.sans
            font.pixelSize: vpx(20)
        }
    }

    // ---------------------------------------------------------------- game list and details

    Item {
        id: listPage
        anchors.top: topBar.bottom
        anchors.bottom: bottomBar.top
        anchors.left: parent.left
        anchors.right: parent.right
        visible: opacity > 0
        opacity: inList ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }

        ListView {
            id: gameList
            focus: inList
            anchors.left: parent.left
            anchors.leftMargin: vpx(20)
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: vpx(8)
            width: parent.width * 0.5
            clip: true

            model: games
            highlightMoveDuration: 90
            preferredHighlightBegin: height * 0.4
            preferredHighlightEnd: height * 0.4 + vpx(44)
            highlightRangeMode: ListView.ApplyRange
            keyNavigationWraps: true

            highlight: Rectangle {
                radius: vpx(10)
                color: P.accent
            }

            delegate: Item {
                width: ListView.view.width
                height: vpx(44)

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: vpx(16)
                    anchors.right: star.left
                    anchors.rightMargin: vpx(8)
                    anchors.verticalCenter: parent.verticalCenter
                    text: model.title
                    elide: Text.ElideRight
                    color: P.text
                    opacity: parent.ListView.isCurrentItem ? 1 : 0.82
                    font.family: global.fonts.sans
                    font.pixelSize: vpx(19)
                    font.bold: parent.ListView.isCurrentItem
                }

                Text {
                    id: star
                    anchors.right: parent.right
                    anchors.rightMargin: vpx(14)
                    anchors.verticalCenter: parent.verticalCenter
                    text: model.favorite ? "★" : ""
                    color: parent.ListView.isCurrentItem ? P.text : P.accent
                    font.pixelSize: vpx(18)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (gameList.currentIndex === index)
                            root.launch();
                        else
                            gameList.currentIndex = index;
                    }
                }
            }

            Keys.onPressed: {
                if (api.keys.isPrevPage(event)) {
                    event.accepted = true;
                    root.jumpLetter(-1);
                    return;
                }
                if (api.keys.isNextPage(event)) {
                    event.accepted = true;
                    root.jumpLetter(1);
                    return;
                }
                if (api.keys.isPageUp(event)) {
                    event.accepted = true;
                    currentIndex = Math.max(0, currentIndex - 10);
                    return;
                }
                if (api.keys.isPageDown(event)) {
                    event.accepted = true;
                    currentIndex = Math.min(count - 1, currentIndex + 10);
                    return;
                }
                if (event.isAutoRepeat)
                    return;
                if (api.keys.isAccept(event)) {
                    event.accepted = true;
                    root.launch();
                } else if (api.keys.isCancel(event)) {
                    event.accepted = true;
                    root.closeList();
                } else if (api.keys.isDetails(event)) {
                    event.accepted = true;
                    if (currentGame)
                        currentGame.favorite = !currentGame.favorite;
                } else if (api.keys.isFilters(event)) {
                    event.accepted = true;
                    root.sortMode = 1 - root.sortMode;
                    currentIndex = 0;
                }
            }
        }

        // details: box art, title, facts, description
        Item {
            id: details
            anchors.left: gameList.right
            anchors.leftMargin: vpx(24)
            anchors.right: parent.right
            anchors.rightMargin: vpx(24)
            anchors.top: parent.top
            anchors.topMargin: vpx(12)
            anchors.bottom: parent.bottom

            Rectangle {
                id: artFrame
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: parent.height * 0.5
                radius: vpx(14)
                color: P.panel
                clip: true

                Image {
                    id: art
                    anchors.fill: parent
                    anchors.margins: vpx(10)
                    source: currentGame ? (currentGame.assets.boxFront || currentGame.assets.screenshot
                                           || currentGame.assets.logo || "") : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize.height: 512
                }

                Text {
                    visible: art.status !== Image.Ready
                    anchors.centerIn: parent
                    width: parent.width - vpx(30)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: currentGame ? currentGame.title : ""
                    color: P.dim
                    font.family: global.fonts.sans
                    font.pixelSize: vpx(24)
                    font.bold: true
                }
            }

            Column {
                anchors.top: artFrame.bottom
                anchors.topMargin: vpx(16)
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: vpx(8)
                clip: true

                Text {
                    width: parent.width
                    text: currentGame ? currentGame.title : ""
                    color: P.text
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.family: global.fonts.sans
                    font.pixelSize: vpx(22)
                    font.bold: true
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: {
                        if (!currentGame)
                            return "";
                        var parts = [];
                        if (currentGame.releaseYear > 0) parts.push(currentGame.releaseYear);
                        if (currentGame.developer) parts.push(currentGame.developer);
                        if (currentGame.players > 1) parts.push("1-" + currentGame.players + " players");
                        if (currentGame.genre) parts.push(currentGame.genre);
                        return parts.join("  ·  ");
                    }
                    color: P.dim
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.family: global.fonts.sans
                    font.pixelSize: vpx(15)
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: {
                        if (!currentGame || currentGame.playCount === 0)
                            return "";
                        var mins = Math.round(currentGame.playTime / 60);
                        var played = mins >= 60 ? Math.floor(mins / 60) + " h " + (mins % 60) + " min" : mins + " min";
                        return "Played " + played + "  ·  last "
                               + Qt.formatDate(currentGame.lastPlayed, "d MMM yyyy");
                    }
                    color: P.accent
                    font.family: global.fonts.sans
                    font.pixelSize: vpx(14)
                }

                Text {
                    width: parent.width
                    text: currentGame ? (currentGame.summary || currentGame.description) : ""
                    color: P.text
                    opacity: 0.85
                    wrapMode: Text.WordWrap
                    maximumLineCount: 6
                    elide: Text.ElideRight
                    font.family: global.fonts.sans
                    font.pixelSize: vpx(15)
                    lineHeight: 1.15
                }
            }
        }
    }

    // ---------------------------------------------------------------- button hints

    Rectangle {
        id: bottomBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: vpx(48)
        color: "#cc0b0c10"

        Row {
            anchors.right: parent.right
            anchors.rightMargin: vpx(24)
            anchors.verticalCenter: parent.verticalCenter
            spacing: vpx(22)

            Hint { button: "L1 R1"; label: inList ? "Letter" : "Scroll" }
            Hint { visible: inList; button: "Y"; label: sortMode === 0 ? "Sort: A-Z" : "Sort: Recent" }
            Hint { visible: inList; button: "X"; label: currentGame && currentGame.favorite ? "Unfavorite" : "Favorite" }
            Hint { visible: inList; button: "B"; label: "Back" }
            Hint { button: "A"; label: inList ? "Play" : "Open"; face: P.accent }
        }

        Hint {
            anchors.left: parent.left
            anchors.leftMargin: vpx(24)
            anchors.verticalCenter: parent.verticalCenter
            button: "☰"
            label: "Menu"
        }
    }

    Component.onCompleted: {
        var start = Math.max(0, indexOfPlatform(api.memory.get("platform")));
        platformShort = platforms[start] ? platforms[start].shortName : "";
        carousel.currentIndex = start;
        carousel.positionViewAtIndex(start, ListView.Center);
        restored = true;
        if (api.memory.get("inList")) {
            api.memory.unset("inList");
            openList();
        } else {
            carousel.forceActiveFocus();
        }
    }
}
