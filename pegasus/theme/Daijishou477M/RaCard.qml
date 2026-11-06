import QtQuick 2.15
import "Palette.js" as P

// The RetroAchievements card on the carousel: a live summary, no need to open it
Item {
    id: card

    property var ra
    property bool selected
    readonly property var s: ra ? ra.summary : null
    readonly property var g: s ? s.game : null

    scale: selected ? 1.0 : 0.86
    opacity: selected ? 1.0 : 0.75
    z: selected ? 2 : 1
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 140 } }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: vpx(18)
        clip: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: P.colours("retroachievements")[0] }
            GradientStop { position: 1.0; color: P.colours("retroachievements")[1] }
        }

        // signed out, loading or offline
        Column {
            visible: !card.s
            anchors.centerIn: parent
            width: parent.width - vpx(48)
            spacing: vpx(14)

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "RetroAchievements"
                color: P.text
                font.family: global.fonts.sans
                font.pixelSize: vpx(30)
                font.bold: true
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: !card.ra || !card.ra.configured ? "Press A to connect your account"
                      : card.ra.error ? card.ra.error : "Loading…"
                color: P.text
                opacity: 0.85
                font.family: global.fonts.sans
                font.pixelSize: vpx(17)
            }
        }

        Column {
            visible: !!card.s
            anchors.fill: parent
            anchors.margins: vpx(20)
            spacing: vpx(14)

            // who, points and rank
            Row {
                width: parent.width
                spacing: vpx(14)

                Rectangle {
                    id: avatar
                    width: vpx(76)
                    height: width
                    radius: vpx(12)
                    color: "#40000000"
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: card.s ? card.s.avatar : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                Column {
                    width: parent.width - avatar.width - parent.spacing
                    anchors.verticalCenter: avatar.verticalCenter
                    spacing: vpx(2)

                    Text {
                        width: parent.width
                        text: card.s ? card.s.user : ""
                        elide: Text.ElideRight
                        color: P.text
                        font.family: global.fonts.sans
                        font.pixelSize: vpx(24)
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        text: card.s ? Number(card.s.hardcore).toLocaleString(Qt.locale(), "f", 0) + " pts"
                              + (card.s.rank ? "   ·   #" + Number(card.s.rank).toLocaleString(Qt.locale(), "f", 0) : "") : ""
                        elide: Text.ElideRight
                        color: P.text
                        font.family: global.fonts.sans
                        font.pixelSize: vpx(20)
                    }
                }
            }

            // the last game and its progress
            Rectangle {
                width: parent.width
                height: vpx(96)
                radius: vpx(12)
                color: "#38000000"
                visible: !!card.g

                Image {
                    id: icon
                    anchors.left: parent.left
                    anchors.leftMargin: vpx(10)
                    anchors.verticalCenter: parent.verticalCenter
                    width: vpx(64)
                    height: width
                    source: card.g ? card.g.icon : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                Column {
                    anchors.left: icon.right
                    anchors.leftMargin: vpx(12)
                    anchors.right: parent.right
                    anchors.rightMargin: vpx(12)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: vpx(6)

                    Text {
                        width: parent.width
                        text: card.g ? card.g.title : ""
                        elide: Text.ElideRight
                        color: P.text
                        font.family: global.fonts.sans
                        font.pixelSize: vpx(18)
                        font.bold: true
                    }
                    Rectangle {
                        width: parent.width
                        height: vpx(8)
                        radius: height / 2
                        color: "#50000000"
                        visible: card.g && card.g.total > 0

                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            width: card.g && card.g.total ? parent.width * card.g.got / card.g.total : 0
                            color: "#ffe08a"
                        }
                    }
                    Text {
                        text: card.g && card.g.total ? card.g.got + " / " + card.g.total + " achievements" : (card.g ? card.g.console : "")
                        color: P.text
                        opacity: 0.85
                        font.family: global.fonts.sans
                        font.pixelSize: vpx(14)
                    }
                }
            }

            Text {
                text: "LATEST UNLOCKS"
                visible: card.s && card.s.recent.length > 0
                color: P.text
                opacity: 0.75
                font.family: global.fonts.sans
                font.pixelSize: vpx(12)
                font.bold: true
                font.letterSpacing: vpx(1.5)
            }

            Repeater {
                model: card.s ? Math.min(card.s.recent.length, 2) : 0

                Row {
                    readonly property var a: card.s.recent[index]
                    width: parent.width
                    spacing: vpx(10)

                    Image {
                        id: badge
                        width: vpx(40)
                        height: width
                        source: a.badge
                        asynchronous: true
                    }
                    Column {
                        width: parent.width - badge.width - pts.width - 2 * parent.spacing
                        anchors.verticalCenter: badge.verticalCenter

                        Text {
                            width: parent.width
                            text: a.title
                            elide: Text.ElideRight
                            color: P.text
                            font.family: global.fonts.sans
                            font.pixelSize: vpx(15)
                            font.bold: true
                        }
                        Text {
                            width: parent.width
                            text: a.game
                            elide: Text.ElideRight
                            color: P.text
                            opacity: 0.75
                            font.family: global.fonts.sans
                            font.pixelSize: vpx(12)
                        }
                    }
                    Text {
                        id: pts
                        anchors.verticalCenter: badge.verticalCenter
                        text: a.points
                        color: a.hardcore ? "#ffe08a" : P.text
                        font.family: global.fonts.sans
                        font.pixelSize: vpx(20)
                        font.bold: true
                    }
                }
            }
        }

        Text {
            visible: !!card.s
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: vpx(14)
            text: card.ra && card.ra.loading ? "Updating…" : "Updated " + Qt.formatTime(card.ra.updated, "HH:mm")
            color: P.text
            opacity: 0.6
            font.family: global.fonts.sans
            font.pixelSize: vpx(12)
        }
    }

    Rectangle {
        anchors.fill: body
        anchors.margins: -vpx(4)
        radius: body.radius + vpx(4)
        color: "transparent"
        border.color: P.text
        border.width: vpx(3)
        visible: card.selected
    }
}
