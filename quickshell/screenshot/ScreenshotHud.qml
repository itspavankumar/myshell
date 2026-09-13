import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    property var service: null

    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-screenshot-hud"
    WlrLayershell.keyboardFocus: (root.service && root.service.isHudOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 100

    visible: (root.service && root.service.isHudOpen) || hudContainer.opacity > 0.005

    // Click outside backdrop to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (root.service) root.service.closeHud();
        }
    }

    Item {
        id: hudContainer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 24
        width: hudPill.width
        height: hudPill.height

        opacity: (root.service && root.service.isHudOpen) ? 1.0 : 0.0
        transform: Translate {
            y: (root.service && root.service.isHudOpen) ? 0 : -14
            Behavior on y {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        // Prevent clicking inside HUD from dismissing
        MouseArea {
            anchors.fill: parent
        }

        focus: root.service && root.service.isHudOpen
        Keys.onPressed: (event) => {
            if (!root.service) return;

            if (event.key === Qt.Key_1 || event.key === Qt.Key_A || event.key === Qt.Key_R) {
                root.service.capture("region", root.service.delaySeconds);
                event.accepted = true;
            } else if (event.key === Qt.Key_2 || event.key === Qt.Key_W) {
                root.service.capture("window", root.service.delaySeconds);
                event.accepted = true;
            } else if (event.key === Qt.Key_3 || event.key === Qt.Key_F || event.key === Qt.Key_S) {
                root.service.capture("output", root.service.delaySeconds);
                event.accepted = true;
            } else if (event.key === Qt.Key_T) {
                root.service.cycleDelay();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.service.closeHud();
                event.accepted = true;
            }
        }

        Rectangle {
            id: hudPill
            implicitHeight: 46
            implicitWidth: contentRow.implicitWidth + 28
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
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                }

                // Mode 1: Area / Region
                Rectangle {
                    id: areaBtn
                    implicitHeight: 32
                    implicitWidth: areaRow.implicitWidth + 20
                    radius: Theme.squareRadius
                    color: areaMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: areaMouse.containsMouse ? Theme.cyan : Theme.borderNormal
                    border.width: 1

                    RowLayout {
                        id: areaRow
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
                            text: "Area"
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.DemiBold
                            color: Theme.textPrimary
                        }
                    }

                    MouseArea {
                        id: areaMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.service) root.service.capture("region", root.service.delaySeconds);
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
                    border.color: winMouse.containsMouse ? Theme.cyan : Theme.borderNormal
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
                            if (root.service) root.service.capture("window", root.service.delaySeconds);
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
                    border.color: screenMouse.containsMouse ? Theme.cyan : Theme.borderNormal
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
                            text: "Screen"
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
                            if (root.service) root.service.capture("output", root.service.delaySeconds);
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: 20
                    color: Theme.borderDim
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                }

                // Timer Delay Pill
                Rectangle {
                    id: timerBtn
                    implicitHeight: 32
                    implicitWidth: timerRow.implicitWidth + 16
                    radius: Theme.squareRadius
                    color: timerMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: (root.service && root.service.delaySeconds > 0) ? Theme.yellow : Theme.borderNormal
                    border.width: 1

                    RowLayout {
                        id: timerRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            text: "󱫌"
                            renderType: Theme.renderType
                            font.family: Theme.fontIcon
                            font.pixelSize: 13
                            color: (root.service && root.service.delaySeconds > 0) ? Theme.yellow : Theme.textMuted
                        }
                        Text {
                            text: (root.service && root.service.delaySeconds > 0) ? (root.service.delaySeconds + "s") : "Timer"
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.Medium
                            color: (root.service && root.service.delaySeconds > 0) ? Theme.yellow : Theme.textSecondary
                        }
                    }

                    MouseArea {
                        id: timerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.service) root.service.cycleDelay();
                        }
                    }
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
