pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"

PopupWindow {
    id: root

    property var menuHandle: null
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
    visible: popupVisible
    property bool popupVisible: false

    implicitWidth: Math.max(160, mainCard.implicitWidth)
    implicitHeight: mainCard.implicitHeight

    Connections {
        target: Theme
        function onActivePopupChanged() {
            if (Theme.activePopup !== "tray" && root.popupVisible) {
                root.close();
            }
        }
    }

    function open() {
        closeAnim.stop();
        Theme.activePopup = "tray";
        popupVisible = true;
        anchor.updateAnchor();
        openAnim.restart();
    }

    function close() {
        if (popupVisible) {
            openAnim.stop();
            closeAnim.restart();
            if (Theme.activePopup === "tray") {
                Theme.closePopup();
            }
        }
    }

    function toggle() {
        if (popupVisible) {
            close();
        } else {
            open();
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
            root.popupVisible = false;
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
            property: "yScale"
            from: popupScale.yScale
            to: 0.94
            duration: 140
            easing.type: Easing.InCubic
        }
    }

    QsMenuOpener {
        id: opener
        menu: root.menuHandle
    }

    Rectangle {
        id: mainCard
        implicitWidth: Math.max(160, menuCol.implicitWidth + 16)
        implicitHeight: menuCol.implicitHeight + 12
        color: Theme.bgGlass
        border.color: Theme.borderBright
        border.width: Theme.borderWidth
        radius: Theme.squareRadius
        opacity: 0.0

        transform: Scale {
            id: popupScale
            origin.x: 0
            origin.y: 0
            xScale: 1.0
            yScale: 0.94
        }

        ColumnLayout {
            id: menuCol
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Repeater {
                model: opener.children

                Rectangle {
                    id: entryItem
                    required property var modelData
                    readonly property var entry: modelData

                    Layout.fillWidth: true
                    implicitHeight: entry && entry.isSeparator ? 7 : 26
                    color: (!entry || entry.isSeparator) ? "transparent"
                           : (entryMouse.containsMouse && entry.enabled ? Theme.bgSurfaceHover : "transparent")
                    border.color: (!entry || entry.isSeparator) ? "transparent"
                                  : (entryMouse.containsMouse && entry.enabled ? Theme.borderNormal : "transparent")
                    border.width: 1
                    radius: Theme.squareRadius

                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    // Separator Line
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: 1
                        color: Theme.borderNormal
                        visible: entry && entry.isSeparator
                    }

                    // Interactive Menu Row
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8
                        visible: entry && !entry.isSeparator

                        // Checkbox / Radio State
                        Text {
                            visible: entry && entry.buttonType !== 0
                            text: (entry && entry.checkState !== Qt.Unchecked) ? "󰄲" : "󰄱"
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: (entry && entry.checkState !== Qt.Unchecked) ? Theme.cyan : Theme.textMuted
                        }

                        // Icon (if available)
                        Image {
                            visible: entry && entry.icon && entry.icon !== ""
                            source: entry && entry.icon ? entry.icon : ""
                            sourceSize.width: 14
                            sourceSize.height: 14
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 14
                            fillMode: Image.PreserveAspectFit
                        }

                        // Text Label
                        Text {
                            text: entry ? (entry.text || "") : ""
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBody
                            font.weight: Font.Medium
                            font.letterSpacing: Theme.trackingNormal
                            color: (entry && entry.enabled)
                                   ? (entryMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary)
                                   : Theme.textMuted
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        // Submenu Indicator
                        Text {
                            visible: entry && entry.hasChildren
                            text: "󰅂"
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.textMuted
                        }
                    }

                    MouseArea {
                        id: entryMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: (entry && entry.enabled && !entry.isSeparator) ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: entry && !entry.isSeparator && entry.enabled
                        onClicked: {
                            if (entry) {
                                entry.triggered();
                                root.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
