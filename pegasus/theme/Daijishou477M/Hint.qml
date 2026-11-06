import QtQuick 2.15
import "Palette.js" as P

// one button hint in the bottom bar: a round face button and its action
Row {
    property string button
    property string label
    property color face: P.panelHi

    spacing: vpx(8)
    height: vpx(28)

    Rectangle {
        width: Math.max(vpx(26), buttonText.implicitWidth + vpx(12))
        height: vpx(26)
        radius: height / 2
        color: face
        anchors.verticalCenter: parent.verticalCenter

        Text {
            id: buttonText
            anchors.centerIn: parent
            text: button
            color: P.text
            font.family: global.fonts.sans
            font.pixelSize: vpx(13)
            font.bold: true
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: label
        color: P.dim
        font.family: global.fonts.sans
        font.pixelSize: vpx(15)
    }
}
