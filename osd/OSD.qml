import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    property var service: null

    anchors {
        bottom: true
    }
    margins.bottom: 28

    implicitWidth: 220
    implicitHeight: 46
    color: "transparent"
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"

    Rectangle {
        id: card
        anchors.fill: parent
        color: Theme.bgGlass
        border.color: Theme.borderBright
        border.width: Theme.borderWidth
        radius: Theme.squareRadius
        visible: opacity > 0.001
        opacity: (root.service && root.service.osdVisible) ? 1.0 : 0.0

        transform: Translate {
            y: (root.service && root.service.osdVisible) ? 0 : 8
            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
        }

        // ==========================================
        // STATUS PILL VIEW (Caps Lock / Mic Mute)
        // ==========================================
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8
            visible: root.service && (root.service.osdType === "capslock" || root.service.osdType === "mic")

            Text {
                text: root.service ? root.service.icon : ""
                renderType: Theme.renderType
                font.family: Theme.fontFamily
                font.pixelSize: 16
                color: (root.service && root.service.isMuted) ? Theme.red : Theme.cyan
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: root.service ? root.service.title : ""
                renderType: Theme.renderType
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSubhead
                font.weight: Font.DemiBold
                color: Theme.textPrimary
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                implicitWidth: statusTxt.implicitWidth + 10
                implicitHeight: 20
                color: Theme.bgSurface
                border.color: (root.service && root.service.isMuted) ? Theme.red : Theme.cyan
                border.width: Theme.borderWidth
                radius: Theme.squareRadius
                Layout.alignment: Qt.AlignVCenter

                Text {
                    id: statusTxt
                    anchors.centerIn: parent
                    text: root.service ? root.service.textValue : ""
                    renderType: Theme.renderType
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption
                    font.weight: Font.Bold
                    color: (root.service && root.service.isMuted) ? Theme.red : Theme.cyan
                }
            }
        }

        // ==========================================
        // SLIDER PROGRESS VIEW (Volume / Brightness / Kbd)
        // ==========================================
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8
            visible: root.service && root.service.osdType !== "capslock" && root.service.osdType !== "mic"

            Text {
                text: root.service ? root.service.icon : ""
                renderType: Theme.renderType
                font.family: Theme.fontFamily
                font.pixelSize: 16
                color: (root.service && root.service.isMuted) ? Theme.red : Theme.cyan
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: root.service ? root.service.title : ""
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.DemiBold
                        color: Theme.textSecondary
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.service ? root.service.textValue : ""
                        renderType: Theme.renderType
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSubhead
                        font.weight: Font.Bold
                        color: (root.service && root.service.isMuted) ? Theme.red : Theme.textPrimary
                    }
                }

                // Progress Bar
                Rectangle {
                    id: trackBar
                    Layout.fillWidth: true
                    implicitHeight: 4
                    color: Theme.bgBase
                    border.color: Theme.borderDim
                    border.width: 1
                    radius: Theme.squareRadius

                    Rectangle {
                        id: progressBar
                        height: parent.height
                        width: root.service ? Math.max(0, Math.min(parent.width, parent.width * root.service.value)) : 0
                        color: (root.service && root.service.isMuted) ? Theme.textMuted : Theme.cyan
                        radius: Theme.squareRadius

                        Behavior on width {
                            enabled: card.opacity > 0.8
                            NumberAnimation {
                                duration: 75
                                easing.type: Easing.OutQuad
                            }
                        }
                    }

                    // Segmented notches for keyboard brightness (3 levels)
                    Row {
                        anchors.fill: parent
                        visible: root.service && root.service.osdType === "kbd"
                        Repeater {
                            model: 2
                            Rectangle {
                                x: Math.round((trackBar.width / 3) * (index + 1)) - 1
                                width: 1
                                height: parent.height
                                color: Theme.bgGlass
                            }
                        }
                    }
                }
            }
        }
    }
}
