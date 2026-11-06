import QtQuick 2.15
import "Palette.js" as P

// a big number with a caption under it
Column {
    property var value: 0
    property string prefix
    property string label

    spacing: vpx(2)

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: prefix + Number(value).toLocaleString(Qt.locale(), "f", 0)
        color: P.text
        font.family: global.fonts.sans
        font.pixelSize: vpx(30)
        font.bold: true
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: label
        color: P.text
        opacity: 0.75
        font.family: global.fonts.sans
        font.pixelSize: vpx(13)
    }
}
