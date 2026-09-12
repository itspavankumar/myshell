//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "theme"
import "modules"
import "popups"
import "notifications"

Scope {
    id: root

    // Multi-monitor variant: creates a top bar on each connected monitor
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData

            // Map current Quickshell screen to Hyprland monitor
            readonly property HyprlandMonitor hypMon: Hyprland.monitorFor(barWindow.screen)

            anchors {
                top: true
                left: true
                right: true
            }

            margins {
                top: Theme.barMarginTop
                left: Theme.barMarginLeft
                right: Theme.barMarginRight
            }

            implicitHeight: Theme.barHeight
            visible: Theme.barVisible
            color: "transparent"

            // Bar background container with square borders
            Rectangle {
                id: barBackground
                anchors.fill: parent
                color: Theme.bgGlass
                border.color: Theme.borderNormal
                border.width: Theme.borderWidth
                radius: Theme.squareRadius

                // Clicking empty space on the bar closes any open popup
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: Theme.closePopup()
                }

                // Dead-Center Clock
                ClockModule {
                    barWindow: barWindow
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    z: 1
                }

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    height: Theme.moduleHeight
                    spacing: 8

                    // ==========================================
                    // LEFT SIDE: Workspaces with Dots & Active Title
                    // ==========================================
                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredHeight: Theme.moduleHeight
                        spacing: 8

                        // Workspaces with dots (Omarchy / Caelestia / Noctalia style)
                        Workspaces {
                            currentScreen: barWindow.screen
                        }

                        // Current window title
                        ActiveWindow {}
                    }

                    // ==========================================
                    // CENTER SPACING
                    // ==========================================
                    Item {
                        Layout.fillWidth: true
                    }

                    // ==========================================
                    // RIGHT SIDE: Tray, Wifi, BT, Sound, Battery, Control Center
                    // ==========================================
                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredHeight: Theme.moduleHeight
                        spacing: 6

                        // System Tray
                        TrayModule { barWindow: barWindow }

                        // Media Player (MPRIS) - left to WiFi
                        MediaModule { barWindow: barWindow }

                        // WiFi / Network
                        NetworkModule { barWindow: barWindow }

                        // Bluetooth
                        BluetoothModule { barWindow: barWindow }

                        // Battery / UPower
                        BatteryModule { barWindow: barWindow }

                        // Control Center
                        ControlCenterModule { barWindow: barWindow }

                        // Notification Bell (at the pitch right after the CC)
                        NotificationModule {
                            barWindow: barWindow
                            service: notificationService
                        }
                    }
                }
            }
        }
    }

    // Close any open popups when switching workspaces
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            Theme.closePopup();
        }
    }

    // Outside-click dismisser: catches clicks outside bar and popups to close active popup
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dismisserWindow
            required property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            margins {
                top: (Theme.barVisible ? (Theme.barHeight + Theme.barMarginTop) : 0)
            }

            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            focusable: false
            color: "transparent"
            visible: Theme.activePopup !== ""

            MouseArea {
                anchors.fill: parent
                onClicked: Theme.closePopup()
            }
        }
    }

    // ==========================================
    // NOTIFICATION SERVICE & TOASTS
    // ==========================================
    NotificationService {
        id: notificationService
    }

    Variants {
        model: Quickshell.screens

        NotificationToasts {
            required property var modelData
            screen: modelData
            service: notificationService
        }
    }

    // ==========================================
    // BAR VISIBILITY GLOBAL SHORTCUTS & IPC
    // ==========================================
    GlobalShortcut {
        appid: "quickshell"
        name: "bar_toggle"
        onPressed: Theme.toggleBar()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "toggle_bar"
        onPressed: Theme.toggleBar()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "ToggleBar"
        onPressed: Theme.toggleBar()
    }

    IpcHandler {
        target: "bar"

        function toggle(): void {
            Theme.toggleBar();
        }

        function show(): void {
            Theme.showBar();
        }

        function hide(): void {
            Theme.hideBar();
        }

        function isVisible(): bool {
            return Theme.barVisible;
        }
    }
}
