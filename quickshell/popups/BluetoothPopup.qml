import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import "../theme"

PopupWindow {
    id: root

    property var targetItem: null
    property var barWindow: null

    function getWidgetCenterX() {
        if (!targetItem) return 0;
        try {
            let p = targetItem.mapToItem(null, 0, 0);
            return p.x + (targetItem.width / 2);
        } catch (e) {
            return targetItem.x + (targetItem.width / 2);
        }
    }

    anchor.window: barWindow ? barWindow : (targetItem ? targetItem.Window.window : null)
    anchor.rect.x: Math.round(getWidgetCenterX() - width / 2)
    anchor.rect.y: barWindow ? barWindow.height : Theme.barHeight
    anchor.rect.width: width
    anchor.rect.height: 0
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.margins.top: Theme.popupMarginTop
    anchor.adjustment: PopupAdjustment.Slide

    color: "transparent"
    readonly property bool shouldBeOpen: Theme.activePopup === "bluetooth"
    property bool popupVisible: false
    visible: popupVisible
    implicitWidth: 220
    implicitHeight: mainCard.implicitHeight

    onShouldBeOpenChanged: {
        if (shouldBeOpen) {
            closeAnim.stop();
            popupVisible = true;
            anchor.updateAnchor();
            openAnim.restart();
        } else {
            if (popupVisible) {
                openAnim.stop();
                if (Theme.activePopup !== "") {
                    mainCard.opacity = 0.0;
                    popupScale.xScale = 0.96;
                    popupScale.yScale = 0.96;
                    popupVisible = false;
                } else {
                    closeAnim.restart();
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            anchor.updateAnchor();
        } else {
            popupVisible = false;
            if (Theme.activePopup === "bluetooth") {
                Theme.closePopup();
            }
        }
    }

    ParallelAnimation {
        id: openAnim

        NumberAnimation {
            target: mainCard
            property: "opacity"
            from: mainCard.opacity
            to: 1.0
            duration: 160
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: popupScale
            property: "xScale"
            from: popupScale.xScale
            to: 1.0
            duration: 180
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: popupScale
            property: "yScale"
            from: popupScale.yScale
            to: 1.0
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: closeAnim
        onFinished: {
            if (!root.shouldBeOpen) {
                root.popupVisible = false;
            }
        }

        NumberAnimation {
            target: mainCard
            property: "opacity"
            from: mainCard.opacity
            to: 0.0
            duration: 120
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: popupScale
            property: "xScale"
            from: popupScale.xScale
            to: 0.96
            duration: 120
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: popupScale
            property: "yScale"
            from: popupScale.yScale
            to: 0.96
            duration: 120
            easing.type: Easing.InCubic
        }
    }

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool hasAdapter: adapter !== null
    readonly property bool isEnabled: hasAdapter && adapter.enabled

    Rectangle {
        id: mainCard
        width: parent.width
        implicitHeight: contentCol.implicitHeight + 22
        color: Theme.bgGlass
        border.color: Theme.borderBright
        border.width: Theme.borderWidth
        radius: Theme.squareRadius
        opacity: 0.0

        transform: Scale {
            id: popupScale
            origin.x: mainCard.width / 2
            origin.y: 0
            xScale: 0.95
            yScale: 0.92
        }

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            // ==========================================
            // HEADER: Title + Master Bluetooth Switch
            // ==========================================
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰂯"
                    renderType: Theme.renderType
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.blue
                }

                Text {
                    text: "BLUETOOTH"
                    renderType: Theme.renderType
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontHeadline
                    font.weight: Font.Bold
                    font.letterSpacing: Theme.trackingLoose
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }

                // Bluetooth Sliding Switch Button
                Rectangle {
                    id: btSwitch
                    implicitWidth: 32
                    implicitHeight: 18
                    color: root.isEnabled ? Theme.blue : Theme.bgBase
                    border.color: root.isEnabled ? Theme.blue : Theme.borderDim
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    // Sliding Thumb
                    Rectangle {
                        id: btThumb
                        width: 12
                        height: 12
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.isEnabled ? (parent.width - width - 3) : 3
                        color: root.isEnabled ? Theme.textDark : Theme.textMuted
                        radius: Theme.squareRadius

                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.hasAdapter) {
                                root.adapter.enabled = !root.adapter.enabled;
                            }
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.borderDim
            }

            // ==========================================
            // DEVICES LIST
            // ==========================================
            Text {
                text: "DEVICES"
                renderType: Theme.renderType
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption
                font.weight: Font.Bold
                font.letterSpacing: Theme.trackingLoose
                color: Theme.textMuted
                visible: root.isEnabled
            }

            ColumnLayout {
                id: devCol
                spacing: 4
                Layout.fillWidth: true
                visible: root.isEnabled

                Repeater {
                    model: {
                        if (!root.isEnabled || !Bluetooth.devices) return [];
                        let list = [];
                        for (let i = 0; i < Bluetooth.devices.values.length; i++) {
                            let dev = Bluetooth.devices.values[i];
                            if (dev && (dev.name || dev.deviceName)) {
                                list.push(dev);
                            }
                        }
                        return list.slice(0, 8);
                    }

                    Rectangle {
                        id: devItem
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 38
                        color: devMouse.containsMouse ? Theme.bgSurfaceHover : (modelData.connected ? Theme.bgSurfaceActive : Theme.bgSurface)
                        border.color: modelData.connected ? Theme.blue : (devMouse.containsMouse ? Theme.borderBright : Theme.borderDim)
                        border.width: Theme.borderWidth
                        radius: Theme.squareRadius

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Text {
                                text: modelData.connected ? "󰂱" : "󰂯"
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: modelData.connected ? Theme.cyan : Theme.textMuted
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    text: modelData.name || modelData.deviceName || "Device"
                                    renderType: Theme.renderType
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontBody
                                    font.weight: modelData.connected ? Font.Bold : Font.DemiBold
                                    font.letterSpacing: Theme.trackingTight
                                    color: modelData.connected ? Theme.textPrimary : Theme.textSecondary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    spacing: 4
                                    Text {
                                        text: modelData.connected ? "Connected" : (modelData.paired ? "Paired" : "Available")
                                        renderType: Theme.renderType
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontCaption
                                        font.weight: Font.Medium
                                        font.letterSpacing: Theme.trackingTight
                                        color: modelData.connected ? Theme.green : Theme.textMuted
                                    }

                                    Text {
                                        visible: modelData.batteryAvailable
                                        text: "• " + Math.round(modelData.battery * 100) + "%"
                                        renderType: Theme.renderType
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontCaption
                                        font.weight: Font.Medium
                                        color: Theme.cyan
                                    }
                                }
                            }

                            // Disconnect/Connect Action indicator
                            Text {
                                text: modelData.connected ? "󰄬" : (devMouse.containsMouse ? "󱘖" : "")
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: modelData.connected ? Theme.green : Theme.cyan
                            }
                        }

                        MouseArea {
                            id: devMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                devItem.modelData.connected = !devItem.modelData.connected;
                            }
                        }
                    }
                }
            }

            // Placeholder if no devices
            Text {
                visible: root.isEnabled && Bluetooth.devices.values.length === 0
                text: "No devices found."
                renderType: Theme.renderType
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSubhead
                color: Theme.textMuted
                Layout.alignment: Qt.AlignHCenter
            }

            // Disabled state
            Text {
                visible: !root.isEnabled
                text: "Bluetooth is off."
                renderType: Theme.renderType
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSubhead
                color: Theme.textMuted
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
