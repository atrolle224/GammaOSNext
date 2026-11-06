import QtQuick 2.15
import "Palette.js" as P

// a labelled text box; A or a tap opens the keyboard, Enter moves on
FocusScope {
    id: field

    property string label
    property bool secret: false
    property alias text: input.text
    signal accepted()

    height: vpx(84)

    Text {
        id: caption
        text: field.label
        color: P.dim
        font.family: global.fonts.sans
        font.pixelSize: vpx(14)
    }

    Rectangle {
        anchors.top: caption.bottom
        anchors.topMargin: vpx(6)
        anchors.left: parent.left
        anchors.right: parent.right
        height: vpx(52)
        radius: vpx(10)
        color: P.panel
        border.width: vpx(2)
        border.color: field.activeFocus ? P.accent : P.panelHi

        TextInput {
            id: input
            focus: true
            anchors.fill: parent
            anchors.leftMargin: vpx(16)
            anchors.rightMargin: vpx(16)
            verticalAlignment: TextInput.AlignVCenter
            color: P.text
            font.family: global.fonts.sans
            font.pixelSize: vpx(20)
            clip: true
            echoMode: field.secret ? TextInput.Password : TextInput.Normal
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
            onAccepted: field.accepted()

            Keys.onPressed: {
                // A on a controller arrives as Enter on some pads: open the keyboard instead of moving on
                if (api.keys.isAccept(event) && !Qt.inputMethod.visible && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter) {
                    event.accepted = true;
                    Qt.inputMethod.show();
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                input.forceActiveFocus();
                Qt.inputMethod.show();
            }
        }
    }
}
