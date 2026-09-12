import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../theme"
import "../popups"

Rectangle {
    id: root

    property var barWindow: null

    // Select active player (prefer playing, fallback to first available)
    readonly property var activePlayer: {
        let players = Mpris.players.values;
        for (let i = 0; i < players.length; i++) {
            let p = players[i];
            if (p && p.playbackState === MprisPlaybackState.Playing) return p;
        }
        return players.length > 0 ? players[0] : null;
    }

    readonly property bool isPlaying: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
    readonly property string trackTitle: (activePlayer && activePlayer.trackTitle) ? activePlayer.trackTitle : ""
    readonly property string trackArtist: (activePlayer && activePlayer.trackArtist) ? activePlayer.trackArtist : ""
    readonly property string displayText: {
        if (!trackTitle && !trackArtist) return "Media";
        if (trackTitle && trackArtist) return trackArtist + " - " + trackTitle;
        return trackTitle || trackArtist;
    }

    visible: activePlayer !== null
    implicitHeight: Theme.moduleHeight
    implicitWidth: visible ? (contentRow.implicitWidth + 16) : 0
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: Theme.moduleHeight
    Layout.alignment: Qt.AlignVCenter

    property bool isHovered: false

    color: isHovered ? Theme.bgSurfaceHover : Theme.bgSurface
    border.color: isHovered ? Theme.borderBright : Theme.borderNormal
    border.width: Theme.borderWidth
    radius: Theme.squareRadius

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    HoverHandler {
        id: hoverHandler
        onHoveredChanged: {
            if (hovered) {
                collapseTimer.stop();
                root.isHovered = true;
            } else {
                collapseTimer.restart();
            }
        }
    }

    Timer {
        id: collapseTimer
        interval: 300
        repeat: false
        onTriggered: {
            root.isHovered = false;
        }
    }

    WheelHandler {
        target: root
        onWheel: (wheel) => {
            if (!root.activePlayer || !root.activePlayer.volumeSupported) return;
            let step = 0.05;
            if (wheel.angleDelta.y > 0) {
                root.activePlayer.volume = Math.min(1.0, root.activePlayer.volume + step);
            } else if (wheel.angleDelta.y < 0) {
                root.activePlayer.volume = Math.max(0.0, root.activePlayer.volume - step);
            }
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        // Music Glyph Icon
        Text {
            text: root.isPlaying ? "󰎆" : "󰏤"
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: root.isPlaying ? Theme.cyan : Theme.textMuted
            Layout.alignment: Qt.AlignVCenter
            renderType: Text.NativeRendering
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // Track Artist & Title
        Text {
            text: root.displayText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            font.weight: Font.DemiBold
            font.letterSpacing: Theme.trackingTight
            color: root.isPlaying ? Theme.textPrimary : Theme.textSecondary
            elide: Text.ElideRight
            Layout.maximumWidth: root.isHovered ? 180 : 140
            Layout.alignment: Qt.AlignVCenter
            renderType: Text.NativeRendering
            Behavior on color { ColorAnimation { duration: 150 } }

            // Clicking track text toggles play/pause
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.activePlayer) {
                        root.activePlayer.togglePlaying();
                    }
                }
            }
        }

        // ==========================================
        // RIGHT (HOVERED): Smooth Spring Animated Controls
        // ==========================================
        Item {
            id: controlsContainer
            clip: true
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: Theme.moduleHeight
            implicitHeight: Theme.moduleHeight
            implicitWidth: root.isHovered ? controlsRow.implicitWidth : 0
            opacity: root.isHovered ? 1.0 : 0.0

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: root.isHovered ? 340 : 420
                    easing.type: root.isHovered ? Easing.OutBack : Easing.OutCubic
                    easing.overshoot: 1.15
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: root.isHovered ? 240 : 320
                    easing.type: Easing.OutCubic
                }
            }

            RowLayout {
                id: controlsRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                // Subtle vertical separator
                Rectangle {
                    implicitWidth: 1
                    implicitHeight: 11
                    color: Theme.borderBright
                    Layout.leftMargin: 2
                    Layout.rightMargin: 3
                    Layout.alignment: Qt.AlignVCenter
                }

                // Previous Button
                Rectangle {
                    implicitWidth: 19
                    implicitHeight: 16
                    color: prevMouse.containsMouse ? Theme.bgSurfaceActive : "transparent"
                    radius: Theme.squareRadius
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: prevMouse.containsMouse ? Theme.cyan : Theme.textSecondary
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activePlayer && root.activePlayer.canGoPrevious) {
                                root.activePlayer.previous();
                            }
                        }
                    }
                }

                // Play / Pause Master Button
                Rectangle {
                    implicitWidth: 20
                    implicitHeight: 16
                    color: playMouse.containsMouse ? Theme.bgSurfaceActive : "transparent"
                    radius: Theme.squareRadius
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: root.isPlaying ? "󰏤" : "󰐊"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: playMouse.containsMouse ? Theme.textPrimary : (root.isPlaying ? Theme.cyan : Theme.textSecondary)
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activePlayer) {
                                root.activePlayer.togglePlaying();
                            }
                        }
                    }
                }

                // Next Button
                Rectangle {
                    implicitWidth: 19
                    implicitHeight: 16
                    color: nextMouse.containsMouse ? Theme.bgSurfaceActive : "transparent"
                    radius: Theme.squareRadius
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: nextMouse.containsMouse ? Theme.cyan : Theme.textSecondary
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.activePlayer && root.activePlayer.canGoNext) {
                                root.activePlayer.next();
                            }
                        }
                    }
                }
            }
        }
    }
}
