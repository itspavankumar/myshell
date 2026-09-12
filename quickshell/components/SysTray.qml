import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray

Item {
    id: root
    width: layout.width
    height: 32

    property bool expanded: false

    RowLayout {
        id: layout
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // Tray icons (only visible when expanded)
        RowLayout {
            visible: root.expanded
            spacing: 8
            Repeater {
                model: SystemTray.items
                delegate: Image {
                    source: modelData.icon
                    width: 16
                    height: 16
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) modelData.activate();
                            else if (mouse.button === Qt.RightButton) modelData.contextMenu();
                        }
                    }
                }
            }
        }

        // Toggle button
        Text {
            text: root.expanded ? ">" : "<"
            color: "#ffffff"
            font.family: "SF Pro"
            font.pixelSize: 16
            MouseArea {
                anchors.fill: parent
                onClicked: root.expanded = !root.expanded
            }
        }
    }
}
