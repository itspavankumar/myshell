import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../theme"

Rectangle {
    id: root

    // Optional filter to screen monitor
    property var currentScreen: null

    implicitHeight: Theme.barHeight - 8
    implicitWidth: wsRow.implicitWidth + 16

    color: Theme.bgSurface
    border.color: Theme.borderNormal
    border.width: Theme.borderWidth
    radius: Theme.squareRadius

    // Determine total workspaces to display (min 5, or up to highest active workspace ID)
    readonly property int maxWorkspaceId: {
        let maxId = 5;
        for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
            let ws = Hyprland.workspaces.values[i];
            if (ws && ws.id > maxId && ws.id <= 10) {
                maxId = ws.id;
            }
        }
        return maxId;
    }

    // Scroll wheel on the entire workspace capsule to switch workspaces
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) {
                Hyprland.dispatch('hl.dsp.focus({ workspace = "e-1" })');
            } else if (wheel.angleDelta.y < 0) {
                Hyprland.dispatch('hl.dsp.focus({ workspace = "e+1" })');
            }
        }
    }

    RowLayout {
        id: wsRow
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: root.maxWorkspaceId

            Rectangle {
                id: dotItem
                readonly property int wsId: index + 1
                
                // Find matching workspace object from Hyprland
                readonly property var wsObj: {
                    for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
                        let w = Hyprland.workspaces.values[i];
                        if (w && w.id === wsId) return w;
                    }
                    return null;
                }

                readonly property bool isOccupied: wsObj !== null
                readonly property bool isActive: wsObj ? wsObj.active : false
                readonly property bool isFocused: wsObj ? wsObj.focused : (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId)
                readonly property bool isUrgent: wsObj ? wsObj.urgent : false

                // Dot dimensions: square dot or expanded pill
                implicitHeight: 8
                implicitWidth: isFocused ? 22 : (isActive ? 14 : (isOccupied ? 8 : 6))
                
                radius: Theme.squareRadius

                // Color calculation based on state
                color: {
                    if (isUrgent) return Theme.red;
                    if (isFocused) return Theme.cyan;
                    if (isActive) return Theme.blue;
                    if (dotMouse.containsMouse) return Theme.purple;
                    if (isOccupied) return Theme.textSecondary;
                    return Theme.textMuted;
                }

                opacity: {
                    if (isFocused || isUrgent) return 1.0;
                    if (isActive) return 0.9;
                    if (dotMouse.containsMouse) return 0.95;
                    if (isOccupied) return 0.7;
                    return 0.35;
                }

                // Smooth morphing animations
                Behavior on implicitWidth {
                    NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                }

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                // Interactive click to switch
                MouseArea {
                    id: dotMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Hyprland.dispatch("hl.dsp.focus({ workspace = " + dotItem.wsId + " })");
                    }
                }
            }
        }
    }
}
