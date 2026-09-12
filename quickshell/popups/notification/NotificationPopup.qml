import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../.."

PopupWindow {
    Variables { id: v }
    id: root

    implicitWidth: 340
    implicitHeight: outerLayout.implicitHeight
    grabFocus: true
    anchor {
        item: notifWidget
        edges: Edges.Bottom
        rect.y: 16
        rect.x: notifWidget.width - root.width + 32
    }
    color: "transparent"

    Item {
        id: animContainer
        anchors.fill: parent
        transformOrigin: Item.Top
        
        scale: root.visible ? 1.0 : 0.8
        opacity: root.visible ? 1.0 : 0.0
        
        Behavior on scale {
            SpringAnimation {
                spring: 3.0
                damping: 0.15
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

    ColumnLayout {
        id: outerLayout
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: -16

        Rectangle {
            id: card2
            Layout.fillWidth: true
            radius: 16
            color: "transparent"

            implicitHeight: contentColumn2.implicitHeight + 32

            Rectangle {
                id: borderRect2
                anchors.fill: card2
                anchors.margins: 16
                radius: card2.radius
                color: v.popupBackground
                border.color: v.popupBorder
                border.width: 1
            }

            Rectangle {
                anchors.fill: card2
                anchors.margins: 15
                radius: card2.radius
                color: "transparent"
                border.color: v.outerBorderColor
                border.width: 1
            }

            ColumnLayout {
                id: contentColumn2
                anchors {
                    top: card2.top
                    left: card2.left
                    right: card2.right
                    margins: 16
                }
                spacing: 0

                // ── Heading ───────────────────────────────────────
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    Layout.bottomMargin: 8
                    text: "Notifications"
                    font.pixelSize: 14
                    font.family: "SF Pro"
                    font.weight: Font.Bold
                    color: v.textColor
                    horizontalAlignment: Text.AlignHCenter
                }

                // ── Empty state ───────────────────────────────────
                Text {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 16
                    text: "No notifications"
                    font.pixelSize: 12
                    font.family: "SF Pro"
                    font.weight: Font.Medium
                    color: v.textPlaceholder
                    horizontalAlignment: Text.AlignHCenter
                    visible: true
                }

                // ── Notification list ─────────────────────────────
                ColumnLayout {
                    id: notifList
                    Layout.fillWidth: true
                    Layout.bottomMargin: 12
                    spacing: 6
                    visible: false
                }
            }
        }
    }
    }
}
