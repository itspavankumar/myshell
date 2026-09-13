import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    property var service: null

    anchors {
        top: true
        right: true
    }

    margins {
        top: (Theme.barVisible ? (Theme.barHeight + Theme.barMarginTop) : 0) + 8
        right: 12
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notification-toasts"
    color: "transparent"

    implicitWidth: 360
    implicitHeight: toastsCol.implicitHeight

    visible: service && service.activeToasts.length > 0

    ColumnLayout {
        id: toastsCol
        width: 360
        spacing: 8

        Repeater {
            model: root.service ? root.service.activeToasts : []

            delegate: Rectangle {
                id: toastCard
                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: cardContent.implicitHeight + 20
                color: Theme.bgGlass
                border.color: modelData.urgency === 2 ? Theme.red : Theme.borderNormal
                border.width: Theme.borderWidth
                radius: Theme.squareRadius

                // Left urgency accent strip
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 1
                    anchors.topMargin: 1
                    anchors.bottomMargin: 1
                    width: 3
                    radius: 2
                    color: modelData.urgency === 2 ? Theme.red : (modelData.urgency === 0 ? Theme.borderNormal : Theme.cyan)
                }

                // Auto-dismiss Timer
                Timer {
                    id: autoTimer
                    interval: {
                        if (modelData.notif && modelData.notif.expireTimeout > 0) {
                            return modelData.notif.expireTimeout;
                        }
                        // Critical doesn't auto-dismiss, others dismiss after 5.5s
                        return modelData.urgency === 2 ? 0 : 5500;
                    }
                    running: interval > 0
                    repeat: false
                    onTriggered: {
                        if (root.service) root.service.dismissToast(modelData.id);
                    }
                }

                // Click card to focus app
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.service) {
                            root.service.focusApp(modelData);
                            root.service.dismissToast(modelData.id);
                        }
                    }
                }

                ColumnLayout {
                    id: cardContent
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    spacing: 6

                    // ==========================================
                    // HEADER: App Name, Time, Close
                    // ==========================================
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        // App Icon / Symbol
                        Text {
                            text: "󰂚"
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.cyan
                        }

                        Text {
                            text: modelData.appName
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSubhead
                            font.weight: Font.DemiBold
                            color: Theme.textSecondary
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: modelData.timeStr
                            renderType: Theme.renderType
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontCaption
                            color: Theme.textMuted
                        }

                        // Close button
                        Rectangle {
                            implicitWidth: 18
                            implicitHeight: 18
                            radius: 3
                            color: closeMouse.containsMouse ? Theme.bgSurfaceHover : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: closeMouse.containsMouse ? Theme.red : Theme.textMuted
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.service) root.service.dismissNotification(modelData);
                                }
                            }
                        }
                    }

                    // ==========================================
                    // SUMMARY / TITLE
                    // ==========================================
                    Text {
                        visible: modelData.summary.length > 0
                        text: modelData.summary
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontHeadline
                        font.weight: Font.Bold
                        font.letterSpacing: Theme.trackingTight
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    // ==========================================
                    // BODY TEXT
                    // ==========================================
                    Text {
                        visible: modelData.body.length > 0
                        text: modelData.body
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                        font.letterSpacing: Theme.trackingTight
                        color: Theme.textSecondary
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }

                    // ==========================================
                    // ATTACHED IMAGE (if any)
                    // ==========================================
                    Image {
                        id: toastAttachedImg
                        visible: modelData.image && modelData.image.length > 0 && status === Image.Ready
                        source: (modelData.image && modelData.image.startsWith("/")) ? ("file://" + modelData.image) : (modelData.image || "")
                        Layout.fillWidth: true
                        Layout.preferredHeight: (visible && status === Image.Ready) ? 120 : 0
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        sourceSize: Qt.size(330, 120)
                    }

                    // ==========================================
                    // ACTION BUTTONS
                    // ==========================================
                    RowLayout {
                        visible: modelData.notif && modelData.notif.actions && modelData.notif.actions.length > 0
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        spacing: 6

                        Repeater {
                            model: (modelData.notif && modelData.notif.actions) ? modelData.notif.actions : []

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                implicitHeight: 22
                                implicitWidth: actText.implicitWidth + 16
                                color: actMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                                border.color: actMouse.containsMouse ? Theme.cyan : Theme.borderNormal
                                border.width: Theme.borderWidth
                                radius: Theme.squareRadius

                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                Text {
                                    id: actText
                                    anchors.centerIn: parent
                                    text: modelData ? modelData.text : ""
                                    renderType: Theme.renderType
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontCaption
                                    font.weight: Font.DemiBold
                                    color: actMouse.containsMouse ? Theme.cyan : Theme.textPrimary
                                }

                                MouseArea {
                                    id: actMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.service) {
                                            root.service.invokeAction(toastCard.modelData, modelData);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
