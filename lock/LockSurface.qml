pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Quickshell.Networking
import "../theme"

WlSessionLockSurface {
    id: root

    required property var service
    required property var wallpaperService

    color: Theme.bgBase

    // ==========================================
    // WALLPAPER BACKDROP & GLASS OVERLAY
    // ==========================================
    Image {
        id: bgImage
        anchors.fill: parent
        source: root.wallpaperService && root.wallpaperService.currentWallpaper
                ? "file://" + root.wallpaperService.currentWallpaper
                : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: status === Image.Ready
    }

    Rectangle {
        id: glassOverlay
        anchors.fill: parent
        color: "#ea0c0e14" // Deep dark glass tint
    }

    // Clicking anywhere on the lock screen re-focuses the password input
    MouseArea {
        anchors.fill: parent
        z: 0
        onClicked: {
            pwdInput.forceActiveFocus();
        }
    }

    // ==========================================
    // TOP BAR: STATUS INDICATORS
    // ==========================================
    RowLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 28
        z: 1

        // Left Status: Session info
        RowLayout {
            spacing: 8

            Text {
                text: "󰌾"
                renderType: Theme.renderType
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: Theme.blue
            }

            Text {
                text: "LOCKED SESSION"
                renderType: Theme.renderType
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption
                font.weight: Font.Bold
                font.letterSpacing: Theme.trackingLoose
                color: Theme.textMuted
            }
        }

        Item {
            Layout.fillWidth: true
        }

        // Right Status: Battery & Indicators
        RowLayout {
            spacing: 12

            // Battery Indicator
            readonly property var bDev: UPower.displayDevice
            readonly property bool hasBat: bDev !== null && bDev.isPresent
            readonly property int batPct: {
                if (!bDev) return 0;
                let p = bDev.percentage;
                return (p <= 1.0 && p > 0.0) ? Math.round(p * 100) : Math.round(p);
            }
            readonly property bool isCharging: bDev && bDev.state === UPowerDeviceState.Charging

            visible: hasBat

            Text {
                text: parent.isCharging ? "󰂄" : (parent.batPct >= 75 ? "󰂁" : (parent.batPct >= 30 ? "󰁿" : "󰁺"))
                renderType: Theme.renderType
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: parent.isCharging ? Theme.cyan : (parent.batPct >= 20 ? Theme.green : Theme.red)
            }

            Text {
                text: parent.batPct + "%"
                renderType: Theme.renderType
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSubhead
                font.weight: Font.DemiBold
                color: Theme.textPrimary
            }
        }
    }

    // ==========================================
    // CENTER CARD: CLOCK, USER, & PASSWORD
    // ==========================================
    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    ColumnLayout {
        id: centerCol
        anchors.centerIn: parent
        spacing: 24
        z: 1
        Layout.alignment: Qt.AlignHCenter

        // 1. Digital Clock & Date
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(sysClock.date, "hh:mm")
                renderType: Theme.renderType
                font.family: Theme.fontDisplay
                font.pixelSize: 76
                font.weight: Font.Bold
                font.letterSpacing: Theme.trackingTight
                color: Theme.textPrimary
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(sysClock.date, "dddd, MMMM d")
                renderType: Theme.renderType
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle
                font.weight: Font.DemiBold
                font.letterSpacing: Theme.trackingTight
                color: Theme.purple
            }
        }

        // 2. User Profile Info
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            // Profile Picture / Avatar Frame
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 68
                implicitHeight: 68
                radius: Theme.squareRadius
                color: Theme.bgSurface
                border.color: Theme.borderBright
                border.width: Theme.borderWidth

                Image {
                    id: avatarImg
                    anchors.fill: parent
                    anchors.margins: 2
                    source: root.service ? root.service.avatarUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: source !== "" && status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: !avatarImg.visible
                    text: "󰀉"
                    renderType: Theme.renderType
                    font.family: Theme.fontFamily
                    font.pixelSize: 34
                    color: Theme.blue
                }
            }

            // Username
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Quickshell.env("USER") || "User"
                renderType: Theme.renderType
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.weight: Font.Bold
                font.letterSpacing: Theme.trackingTight
                color: Theme.textPrimary
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Enter password to unlock"
                renderType: Theme.renderType
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSubhead
                font.weight: Font.Medium
                font.letterSpacing: Theme.trackingTight
                color: Theme.textMuted
            }
        }

        // 3. Password Box with Shake Animation
        Item {
            id: pwdBoxContainer
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 320
            implicitHeight: 44

            Rectangle {
                id: pwdBox
                width: parent.width
                height: parent.height
                x: 0
                radius: Theme.squareRadius
                color: Theme.bgSurface
                border.width: Theme.borderWidth
                border.color: root.service.showFailure
                              ? Theme.red
                              : (pwdInput.activeFocus ? Theme.borderAccent : Theme.borderNormal)

                Behavior on border.color { ColorAnimation { duration: 150 } }

                // Shake Animation
                SequentialAnimation {
                    id: shakeAnim
                    NumberAnimation { target: pwdBox; property: "x"; from: 0; to: -12; duration: 45; easing.type: Easing.OutQuad }
                    NumberAnimation { target: pwdBox; property: "x"; from: -12; to: 12; duration: 45; easing.type: Easing.OutQuad }
                    NumberAnimation { target: pwdBox; property: "x"; from: 12; to: -8; duration: 40; easing.type: Easing.OutQuad }
                    NumberAnimation { target: pwdBox; property: "x"; from: -8; to: 8; duration: 40; easing.type: Easing.OutQuad }
                    NumberAnimation { target: pwdBox; property: "x"; from: 8; to: -4; duration: 35; easing.type: Easing.OutQuad }
                    NumberAnimation { target: pwdBox; property: "x"; from: -4; to: 4; duration: 35; easing.type: Easing.OutQuad }
                    NumberAnimation { target: pwdBox; property: "x"; from: 4; to: 0; duration: 30; easing.type: Easing.OutQuad }
                }

                Connections {
                    target: root.service
                    function onFailed() {
                        shakeAnim.restart();
                        pwdInput.forceActiveFocus();
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 8

                    // Left Lock / Auth Spinner Icon
                    Text {
                        id: lockIcon
                        text: root.service.unlockInProgress ? "󰑐" : "󰌾"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        color: root.service.unlockInProgress ? Theme.cyan : Theme.blue

                        RotationAnimation on rotation {
                            running: root.service.unlockInProgress
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 1000
                        }
                    }

                    // Masked Password Input
                    TextInput {
                        id: pwdInput
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        font.family: Theme.fontMono
                        font.pixelSize: 14
                        renderType: Theme.renderType
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.textPrimary
                        focus: true
                        clip: true
                        enabled: !root.service.unlockInProgress

                        text: root.service.currentPassword

                        onTextChanged: {
                            if (root.service.currentPassword !== text) {
                                root.service.currentPassword = text;
                            }
                        }

                        onActiveFocusChanged: {
                            if (!activeFocus) {
                                forceActiveFocus();
                            }
                        }

                        Keys.onReturnPressed: {
                            root.service.tryUnlock();
                        }

                        Keys.onEnterPressed: {
                            root.service.tryUnlock();
                        }

                        // Placeholder Text
                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: pwdInput.text === "" && !root.service.unlockInProgress
                            text: "Enter Password..."
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBody
                            color: Theme.textMuted
                        }
                    }

                    // Submit Button
                    Rectangle {
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: Theme.squareRadius
                        color: submitMouse.containsMouse ? Theme.bgSurfaceHover : "transparent"
                        border.color: submitMouse.containsMouse ? Theme.borderBright : "transparent"
                        border.width: Theme.borderWidth

                        Text {
                            anchors.centerIn: parent
                            text: "󰁔"
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            color: pwdInput.text.length > 0 ? Theme.blue : Theme.textMuted
                        }

                        MouseArea {
                            id: submitMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.service.tryUnlock();
                            }
                        }
                    }
                }
            }
        }

        // 4. Caps Lock Warning Badge
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitHeight: 24
            implicitWidth: capsRow.implicitWidth + 16
            radius: Theme.squareRadius
            color: "#2a2215"
            border.color: Theme.yellow
            border.width: Theme.borderWidth
            visible: root.service.capsLockOn

            RowLayout {
                id: capsRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "󰌌"
                    renderType: Theme.renderType
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.yellow
                }

                Text {
                    text: "CAPS LOCK IS ON"
                    renderType: Theme.renderType
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption
                    font.weight: Font.Bold
                    font.letterSpacing: Theme.trackingNormal
                    color: Theme.yellow
                }
            }
        }

        // 5. Status / Error Message
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.service.showFailure
                  ? root.service.errorMessage
                  : (root.service.unlockInProgress ? "Authenticating..." : "")
            visible: text !== ""
            renderType: Theme.renderType
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSubhead
            font.weight: Font.DemiBold
            font.letterSpacing: Theme.trackingTight
            color: root.service.showFailure ? Theme.red : Theme.cyan
        }
    }

    // ==========================================
    // BOTTOM BAR: MEDIA PLAYER & POWER CONTROLS
    // ==========================================
    RowLayout {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 28
        z: 1

        // Left Side: Active Media Player Info (if active)
        readonly property var activePlayer: {
            let players = Mpris.players.values;
            for (let i = 0; i < players.length; i++) {
                if (players[i].trackTitle && players[i].trackTitle.length > 0) {
                    return players[i];
                }
            }
            return null;
        }

        Rectangle {
            visible: parent.activePlayer !== null
            implicitHeight: 32
            implicitWidth: mediaRow.implicitWidth + 18
            radius: Theme.squareRadius
            color: Theme.bgSurface
            border.color: Theme.borderNormal
            border.width: Theme.borderWidth

            RowLayout {
                id: mediaRow
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: "󰝚"
                    renderType: Theme.renderType
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.purple
                }

                Text {
                    text: {
                        let p = parent.parent.parent.activePlayer;
                        if (!p) return "";
                        let title = p.trackTitle || "";
                        let artist = p.trackArtist || "";
                        return (artist ? artist + " - " : "") + title;
                    }
                    renderType: Theme.renderType
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption
                    font.weight: Font.Medium
                    font.letterSpacing: Theme.trackingTight
                    color: Theme.textSecondary
                    elide: Text.ElideRight
                    Layout.maximumWidth: 260
                }

                // Play / Pause Button
                MouseArea {
                    implicitWidth: 20
                    implicitHeight: 20
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let p = parent.parent.parent.activePlayer;
                        if (p) p.togglePlaying();
                    }

                    Text {
                        anchors.centerIn: parent
                        text: {
                            let p = parent.parent.parent.parent.activePlayer;
                            return (p && p.playbackState === MprisPlaybackState.Playing) ? "󰏤" : "󰐊";
                        }
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.cyan
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        // Right Side: System Power Controls
        RowLayout {
            spacing: 8

            // Suspend / Sleep
            Rectangle {
                implicitHeight: 32
                implicitWidth: 36
                radius: Theme.squareRadius
                color: sleepMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                border.color: sleepMouse.containsMouse ? Theme.purple : Theme.borderNormal
                border.width: Theme.borderWidth

                Text {
                    anchors.centerIn: parent
                    text: "󰤄"
                    renderType: Theme.renderType
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: sleepMouse.containsMouse ? Theme.purple : Theme.textSecondary
                }

                MouseArea {
                    id: sleepMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.service.runCmd(["systemctl", "suspend"]);
                    }
                }
            }

            // Reboot
            Rectangle {
                implicitHeight: 32
                implicitWidth: 36
                radius: Theme.squareRadius
                color: rebMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                border.color: rebMouse.containsMouse ? Theme.yellow : Theme.borderNormal
                border.width: Theme.borderWidth

                Text {
                    anchors.centerIn: parent
                    text: "󰑐"
                    renderType: Theme.renderType
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: rebMouse.containsMouse ? Theme.yellow : Theme.textSecondary
                }

                MouseArea {
                    id: rebMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.service.runCmd(["systemctl", "reboot"]);
                    }
                }
            }

            // Power Off
            Rectangle {
                implicitHeight: 32
                implicitWidth: 36
                radius: Theme.squareRadius
                color: pwrMouse.containsMouse ? Theme.red : Theme.bgSurface
                border.color: pwrMouse.containsMouse ? Theme.red : Theme.borderNormal
                border.width: Theme.borderWidth

                Text {
                    anchors.centerIn: parent
                    text: "󰐥"
                    renderType: Theme.renderType
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: pwrMouse.containsMouse ? Theme.textDark : Theme.red
                }

                MouseArea {
                    id: pwrMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.service.runCmd(["systemctl", "poweroff"]);
                    }
                }
            }
        }
    }
}

