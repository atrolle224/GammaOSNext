import QtQuick 2.15
import "Palette.js" as P

// a platform in the carousel: its wallpaper (or colour), name and game count
Item {
    id: card

    property string shortName
    property string name
    property int count
    property string unit: "game"
    property var previews: []
    property bool selected

    readonly property var cols: P.colours(shortName)

    scale: selected ? 1.0 : 0.86
    opacity: selected ? 1.0 : 0.7
    z: selected ? 2 : 1
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 140 } }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: vpx(18)
        clip: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: card.cols[0] }
            GradientStop { position: 1.0; color: card.cols[1] }
        }

        Image {
            id: wallpaper
            anchors.fill: parent
            source: "assets/wallpapers/" + card.shortName + ".jpg"
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * 0.45
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: "#e0000000" }
            }
        }

        // a few icons from the collection, for the Apps card
        Grid {
            visible: card.previews.length > 0 && !wallpaper.visible
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: vpx(30)
            columns: 5
            spacing: vpx(14)

            Repeater {
                model: card.previews

                Image {
                    width: vpx(54)
                    height: width
                    source: modelData
                    sourceSize.width: 128
                    sourceSize.height: 128
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
            }
        }

        Image {
            id: logo
            anchors.centerIn: parent
            width: parent.width * 0.78
            height: parent.height * 0.3
            source: "assets/logos/" + card.shortName + ".png"
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: status === Image.Ready
        }

        // a wallpaper with the platform's name in it needs no title over it
        Text {
            visible: !logo.visible && !wallpaper.visible
            anchors.centerIn: parent
            anchors.verticalCenterOffset: card.previews.length > 0 ? parent.height * 0.25 : 0
            width: parent.width - vpx(32)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: card.name
            color: P.text
            font.family: global.fonts.sans
            font.pixelSize: vpx(30)
            font.bold: true
            style: Text.Raised
            styleColor: "#60000000"
        }

        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: vpx(18)
            text: card.count < 0 ? "Your profile" : card.count + " " + card.unit + (card.count === 1 ? "" : "s")
            color: P.text
            font.family: global.fonts.sans
            font.pixelSize: vpx(16)
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
