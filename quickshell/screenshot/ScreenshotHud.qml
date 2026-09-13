import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    property var service: null

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-screenshot-hud"
    WlrLayershell.keyboardFocus: (root.service && root.service.isHudOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Cover full screen so Hyprland treats this as a non-docking overlay without window dodging
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    margins {
        top: 0
        bottom: 0
        left: 0
        right: 0
    }

    // Instant unmapping on close so slurp/grim capture cleanly without overlay artifacts
    visible: root.service && root.service.isHudOpen

    // Click anywhere on the transparent backdrop to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (root.service) root.service.closeHud();
        }
    }

    Item {
        id: hudContainer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        width: hudPill.width
        height: hudPill.height

        // Block clicks on the pill from hitting the backdrop dismisser
        MouseArea {
            anchors.fill: parent
        }

        focus: root.service && root.service.isHudOpen
        Keys.onPressed: (event) => {
            if (!root.service) return;

            if (event.key === Qt.Key_1 || event.key === Qt.Key_R || event.key === Qt.Key_A) {
                root.service.captureRegion();
                event.accepted = true;
            } else if (event.key === Qt.Key_2 || event.key === Qt.Key_W) {
                root.service.captureWindow();
                event.accepted = true;
            } else if (event.key === Qt.Key_3 || event.key === Qt.Key_F || event.key === Qt.Key_S) {
                root.service.captureOutput();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.service.closeHud();
                event.accepted = true;
            }
        }

        Rectangle {
            id: hudPill
            width: contentRow.implicitWidth + 24
            height: 46
            implicitHeight: height
            implicitWidth: width
            color: Theme.bgGlass
            border.color: Theme.borderBright
            border.width: Theme.borderWidth
            radius: Theme.squareRadius

            RowLayout {
                id: contentRow
                anchors.centerIn: parent
                spacing: 8

                // Header Badge
                RowLayout {
                    spacing: 8
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: Theme.cyan
                    }
                    Text {
                        text: "Screenshot"
                        renderType: Theme.renderType
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontBody
                        font.weight: Font.Bold
                        color: Theme.textPrimary
                    }
                }

                Rectangle {
                    width: 1
                    height: 20
                    color: Theme.borderDim
                    Layout.leftMargin: 2
                    Layout.rightMargin: 2
                }

                // Mode 1: Region / Area
                Rectangle {
                    id: regionBtn
                    implicitHeight: 32
                    implicitWidth: regionRow.implicitWidth + 20
                    radius: Theme.squareRadius
                    color: regionMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: regionMouse.containsMouse ? Theme.cyan : Theme.borderNormal
                    border.width: 1

                    RowLayout {
                        id: regionRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "󰩬"
                            renderType: Theme.renderType
                            font.family: Theme.fontIcon
                            font.pixelSize: 14
                            color: Theme.cyan
                        }
                        Text {
                            text: "Region"
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary
                        }
                    }

                    MouseArea {
                        id: regionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.service) root.service.captureRegion();
                        }
                    }
                }

                // Mode 2: Window
                Rectangle {
                    id: winBtn
                    implicitHeight: 32
                    implicitWidth: winRow.implicitWidth + 20
                    radius: Theme.squareRadius
                    color: winMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: winMouse.containsMouse ? Theme.purple : Theme.borderNormal
                    border.width: 1

                    RowLayout {
                        id: winRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "󰖲"
                            renderType: Theme.renderType
                            font.family: Theme.fontIcon
                            font.pixelSize: 14
                            color: Theme.purple
                        }
                        Text {
                            text: "Window"
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary
                        }
                    }

                    MouseArea {
                        id: winMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.service) root.service.captureWindow();
                        }
                    }
                }

                // Mode 3: Fullscreen
                Rectangle {
                    id: screenBtn
                    implicitHeight: 32
                    implicitWidth: screenRow.implicitWidth + 20
                    radius: Theme.squareRadius
                    color: screenMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: screenMouse.containsMouse ? Theme.green : Theme.borderNormal
                    border.width: 1

                    RowLayout {
                        id: screenRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "󰍹"
                            renderType: Theme.renderType
                            font.family: Theme.fontIcon
                            font.pixelSize: 14
                            color: Theme.green
                        }
                        Text {
                            text: "Fullscreen"
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary
                        }
                    }

                    MouseArea {
                        id: screenMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.service) root.service.captureOutput();
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: 20
                    color: Theme.borderDim
                    Layout.leftMargin: 2
                    Layout.rightMargin: 2
                }

                // Close Button
                Rectangle {
                    implicitHeight: 32
                    implicitWidth: 32
                    radius: Theme.squareRadius
                    color: closeMouse.containsMouse ? Theme.bgSurfaceHover : "transparent"
                    border.color: closeMouse.containsMouse ? Theme.borderBright : "transparent"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: closeMouse.containsMouse ? Theme.red : Theme.textMuted
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.service) root.service.closeHud();
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: root.service
        function onIsHudOpenChanged() {
            if (root.service && root.service.isHudOpen) {
                hudContainer.forceActiveFocus();
            }
        }
    }
}
