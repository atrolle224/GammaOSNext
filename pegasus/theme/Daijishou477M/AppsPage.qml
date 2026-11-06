import QtQuick 2.15
import "Palette.js" as P

// The installed Android apps as an icon grid: A opens one, X marks it a favourite, B goes back
FocusScope {
    id: page

    property var model
    property var appAt
    property alias currentIndex: grid.currentIndex
    signal back()
    signal launch(int index)

    function open(index) {
        grid.currentIndex = Math.max(0, Math.min(index, grid.count - 1));
        grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
        grid.forceActiveFocus();
    }

    GridView {
        id: grid
        focus: true
        anchors.fill: parent
        anchors.leftMargin: vpx(28)
        anchors.rightMargin: vpx(28)
        anchors.topMargin: vpx(10)
        clip: true

        readonly property int columns: 7
        cellWidth: width / columns
        cellHeight: vpx(170)
        model: page.model
        keyNavigationWraps: false
        highlightMoveDuration: 90
        preferredHighlightBegin: vpx(10)
        preferredHighlightEnd: height - vpx(10)
        highlightRangeMode: GridView.ApplyRange

        highlight: Rectangle {
            radius: vpx(16)
            color: P.accent
            opacity: 0.9
        }

        delegate: Item {
            width: grid.cellWidth
            height: grid.cellHeight

            Image {
                id: icon
                anchors.top: parent.top
                anchors.topMargin: vpx(16)
                anchors.horizontalCenter: parent.horizontalCenter
                width: vpx(92)
                height: width
                source: model.assets.boxFront || model.assets.logo || ""
                sourceSize.width: 192
                sourceSize.height: 192
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                scale: parent.GridView.isCurrentItem ? 1.06 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }
            }

            Rectangle {
                visible: icon.status !== Image.Ready
                anchors.fill: icon
                radius: vpx(20)
                color: P.panelHi

                Text {
                    anchors.centerIn: parent
                    text: model.title.charAt(0).toUpperCase()
                    color: P.text
                    font.family: global.fonts.sans
                    font.pixelSize: vpx(40)
                    font.bold: true
                }
            }

            Text {
                anchors.top: icon.bottom
                anchors.topMargin: vpx(10)
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: vpx(8)
                anchors.rightMargin: vpx(8)
                horizontalAlignment: Text.AlignHCenter
                text: (model.favorite ? "★ " : "") + model.title
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                color: P.text
                font.family: global.fonts.sans
                font.pixelSize: vpx(15)
                font.bold: parent.GridView.isCurrentItem
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (grid.currentIndex === index)
                        page.launch(index);
                    else
                        grid.currentIndex = index;
                }
            }
        }

        Keys.onPressed: {
            if (api.keys.isPrevPage(event) || api.keys.isPageUp(event)) {
                event.accepted = true;
                currentIndex = Math.max(0, currentIndex - columns * 3);
                return;
            }
            if (api.keys.isNextPage(event) || api.keys.isPageDown(event)) {
                event.accepted = true;
                currentIndex = Math.min(count - 1, currentIndex + columns * 3);
                return;
            }
            if (event.isAutoRepeat)
                return;
            if (api.keys.isAccept(event)) {
                event.accepted = true;
                page.launch(currentIndex);
            } else if (api.keys.isCancel(event)) {
                event.accepted = true;
                page.back();
            } else if (api.keys.isDetails(event)) {
                event.accepted = true;
                var app = page.appAt(currentIndex);
                if (app)
                    app.favorite = !app.favorite;
            }
        }
    }

    Text {
        visible: grid.count === 0
        anchors.centerIn: parent
        width: parent.width * 0.7
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: "No apps listed. Press Start > Settings > Data sources and turn on Android Apps."
        color: P.dim
        font.family: global.fonts.sans
        font.pixelSize: vpx(20)
    }
}
