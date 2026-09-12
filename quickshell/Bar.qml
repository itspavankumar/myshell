import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Hyprland
import "components"

Scope {
    id: root
    property bool open: true

    GlobalShortcut {
        name: "ToggleBar"
        description: "Toggle Top Bar visibility"
        onPressed: root.open = !root.open
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            Variables { id: v }
            required property var modelData

            screen: modelData
            anchors.top: true
            anchors.left: true
            anchors.right: true
            implicitHeight: 24
            exclusiveZone: 24
            color: "transparent"
            WlrLayershell.namespace: "qs:bar"
            visible: root.open

            // ── Bar background ────────────────────────────
        Rectangle {
            id: barBackground
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            implicitHeight: 24
            //color: "#d1e4e7ef"
            color: v.barBackground

            RowLayout {
                anchors {
                    fill: parent
                    bottomMargin: 1
                }
                spacing: 4

                Workspaces {
                    Layout.leftMargin: 12
                }

                // ── Spacer ────────────────────────────
                Item {
                    Layout.fillWidth: true
                }

                // ── Right ─────────────────────────────
                TrayWidget {}
                MprisWidget {}
                VolumeWidget {}
                BluetoothWidget {}
                NetworkWidget {}
                BatteryWidget {}
                ControlCenterWidget {
                    Layout.rightMargin: 12
                }
            }

            Clock {
                anchors.centerIn: parent
            }

        }
        }
    }
}
