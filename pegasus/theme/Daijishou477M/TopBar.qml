import QtQuick 2.15
import "Palette.js" as P

// the page title on the left, the clock and battery on the right
Item {
    property string title
    property string subtitle

    height: vpx(56)

    Text {
        id: titleText
        anchors.left: parent.left
        anchors.leftMargin: vpx(28)
        anchors.verticalCenter: parent.verticalCenter
        text: title
        color: P.text
        font.family: global.fonts.sans
        font.pixelSize: vpx(26)
        font.bold: true
    }

    Text {
        anchors.left: titleText.right
        anchors.leftMargin: vpx(14)
        anchors.baseline: titleText.baseline
        text: subtitle
        color: P.dim
        font.family: global.fonts.sans
        font.pixelSize: vpx(16)
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: vpx(28)
        anchors.verticalCenter: parent.verticalCenter
        spacing: vpx(18)

        Text {
            id: clock
            color: P.text
            font.family: global.fonts.sans
            font.pixelSize: vpx(18)
            text: Qt.formatTime(new Date(), "HH:mm")

            Timer {
                interval: 10000
                running: true
                repeat: true
                onTriggered: clock.text = Qt.formatTime(new Date(), "HH:mm")
            }
        }

        Row {
            spacing: vpx(6)
            visible: !isNaN(api.device.batteryPercent)
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                width: vpx(30)
                height: vpx(15)
                radius: vpx(3)
                color: "transparent"
                border.color: P.text
                border.width: vpx(1.5)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    x: vpx(3)
                    y: vpx(3)
                    height: parent.height - vpx(6)
                    width: Math.max(0, (parent.width - vpx(6)) * api.device.batteryPercent)
                    radius: vpx(1)
                    color: api.device.batteryCharging ? "#4cd964"
                         : api.device.batteryPercent < 0.2 ? P.accent : P.text
                }
            }

            Text {
                color: P.text
                font.family: global.fonts.sans
                font.pixelSize: vpx(16)
                text: Math.round(api.device.batteryPercent * 100) + "%"
            }
        }
    }
}
