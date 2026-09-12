import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../.."

PopupWindow {
    Variables { id: v }
    id: root

    property QsMenuHandle menuHandle
    property MouseArea anchorPoint

    QsMenuOpener {
        id: opener
        menu: menuHandle
    }
    implicitWidth: 240
    implicitHeight: menuColumn.implicitHeight + 16
    grabFocus: true

    anchor {
        item: anchorPoint
        edges: Edges.Bottom
        rect.y: 32
        rect.x: anchorPoint.width / 2 - root.width / 2
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
    RectangularShadow {
        anchors.fill: dropdown
        anchors.margins: 2
        radius: Math.max(0, dropdown.radius - 2)
        blur: 10
        color: v.shadowColor
    }



    Rectangle {


        id: dropdown


        anchors.fill: parent


        anchors.margins: 8


        anchors.topMargin: 0


        radius: 16


        color: v.popupBackground


        border.color: v.popupBorder


        border.width: 1


    }

    // ── menu contents ────────────────────────────────────────────────────────
    ColumnLayout {
        id: menuColumn
        anchors {
            top: dropdown.top
            left: dropdown.left
            right: dropdown.right
            topMargin: 4
            bottomMargin: 4
            leftMargin: 0
            rightMargin: 0
        }
        spacing: 0
        Repeater {
            model: opener.children

            delegate: TrayMenuItem {
                required property QsMenuHandle modelData
                dropdown: root
                menuHandle: modelData
            }
        }
    }
    }
}
