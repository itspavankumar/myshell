import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root
    width: layout.width
    Layout.fillHeight: true

    RowLayout {
        id: layout
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
            model: 5
            delegate: Image {
                sourceSize.width: 18
                sourceSize.height: 18
                source: (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === (index + 1)) ? "../images/System/circle-active.svg" : "../images/System/circle-inactive.svg"
                opacity: (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === (index + 1)) ? 1.0 : 0.6
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
