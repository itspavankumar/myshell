import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import "../theme"

PopupWindow {
    id: root

    property var targetItem: null
    property var barWindow: null
    property var service: null

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
    readonly property bool shouldBeOpen: Theme.activePopup === "notifications"
    property bool popupVisible: false
    visible: popupVisible
    implicitWidth: 380
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
                closeAnim.restart();
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            anchor.updateAnchor();
        } else {
            popupVisible = false;
            if (Theme.activePopup === "notifications") {
                Theme.closePopup();
            }
        }
    }

    // Exact opening animation matching other popups
    ParallelAnimation {
        id: openAnim

        NumberAnimation {
            target: mainCard
            property: "opacity"
            from: mainCard.opacity
            to: 1.0
            duration: 260
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: popupScale
            property: "xScale"
            from: popupScale.xScale
            to: 1.0
            duration: 280
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: popupScale
            property: "yScale"
            from: popupScale.yScale
            to: 1.0
            duration: 280
            easing.type: Easing.OutCubic
        }
    }

    // Exact reverse closing animation
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
            duration: 200
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: popupScale
            property: "xScale"
            from: popupScale.xScale
            to: 0.94
            duration: 220
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: popupScale
            property: "yScale"
            from: popupScale.yScale
            to: 0.90
            duration: 220
            easing.type: Easing.InCubic
        }
    }

    Rectangle {
        id: mainCard
        width: 380
        implicitHeight: Math.min(560, Math.max(160, headerBar.implicitHeight + contentContainer.implicitHeight + 20))
        color: Theme.bgGlass
        border.color: Theme.borderNormal
        border.width: Theme.borderWidth
        radius: Theme.squareRadius
        clip: true
        opacity: 0.0

        transform: Scale {
            id: popupScale
            origin.x: mainCard.width - 20
            origin.y: 0
            xScale: 0.94
            yScale: 0.90
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ==========================================
            // HEADER BAR
            // ==========================================
            Rectangle {
                id: headerBar
                Layout.fillWidth: true
                implicitHeight: 44
                color: Theme.bgSurface
                border.color: Theme.borderNormal
                border.width: Theme.borderWidth
                radius: Theme.squareRadius

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    // Title Icon & Text
                    Text {
                        text: "󰂚"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: Theme.cyan
                    }

                    Text {
                        text: "Notifications"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontHeadline
                        font.weight: Font.Bold
                        font.letterSpacing: Theme.trackingLoose
                        color: Theme.textPrimary
                    }

                    // Count Badge
                    Rectangle {
                        visible: root.service && root.service.unreadCount > 0
                        implicitWidth: unreadCountText.implicitWidth + 8
                        implicitHeight: 16
                        radius: 8
                        color: Theme.cyan

                        Text {
                            id: unreadCountText
                            anchors.centerIn: parent
                            text: root.service ? root.service.unreadCount.toString() : "0"
                            renderType: Theme.renderType
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.Bold
                            font.letterSpacing: Theme.trackingNormal
                            color: Theme.bgBase
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // DND Toggle Pill
                    Rectangle {
                        implicitHeight: 22
                        implicitWidth: dndPillRow.implicitWidth + 12
                        radius: Theme.squareRadius
                        color: (root.service && root.service.dnd) ? Theme.yellow : (dndHover.containsMouse ? Theme.bgSurfaceHover : Theme.bgBase)
                        border.color: (root.service && root.service.dnd) ? Theme.yellow : (dndHover.containsMouse ? Theme.borderBright : Theme.borderNormal)
                        border.width: Theme.borderWidth

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            id: dndPillRow
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: (root.service && root.service.dnd) ? "󰂛" : "󰂚"
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: (root.service && root.service.dnd) ? Theme.bgBase : Theme.textSecondary
                            }

                            Text {
                                text: "DND"
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontCaption
                                font.weight: Font.Bold
                                font.letterSpacing: Theme.trackingNormal
                                color: (root.service && root.service.dnd) ? Theme.bgBase : Theme.textSecondary
                            }
                        }

                        MouseArea {
                            id: dndHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.service) root.service.toggleDnd();
                            }
                        }
                    }

                    // Clear All Button
                    Rectangle {
                        visible: root.service && root.service.unreadCount > 0
                        implicitHeight: 22
                        implicitWidth: clearPillRow.implicitWidth + 12
                        radius: Theme.squareRadius
                        color: clearHover.containsMouse ? Theme.bgSurfaceHover : Theme.bgBase
                        border.color: clearHover.containsMouse ? Theme.red : Theme.borderNormal
                        border.width: Theme.borderWidth

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            id: clearPillRow
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: "󰃢"
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: clearHover.containsMouse ? Theme.red : Theme.textSecondary
                            }

                            Text {
                                text: "Clear"
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontCaption
                                font.weight: Font.DemiBold
                                font.letterSpacing: Theme.trackingNormal
                                color: clearHover.containsMouse ? Theme.red : Theme.textSecondary
                            }
                        }

                        MouseArea {
                            id: clearHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.service) root.service.dismissAll();
                            }
                        }
                    }
                }
            }

            // ==========================================
            // CONTENT CONTAINER
            // ==========================================
            Item {
                id: contentContainer
                Layout.fillWidth: true
                Layout.fillHeight: true

                // 1. EMPTY STATE
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: !root.service || root.service.unreadCount === 0
                    spacing: 6

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰂚"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: 34
                        color: Theme.textMuted
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "All Caught Up"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontHeadline
                        font.weight: Font.DemiBold
                        font.letterSpacing: Theme.trackingTight
                        color: Theme.textSecondary
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No new notifications"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSubhead
                        font.letterSpacing: Theme.trackingTight
                        color: Theme.textMuted
                    }
                }

                // 2. SCROLLABLE NOTIFICATIONS
                Flickable {
                    id: notifFlick
                    anchors.fill: parent
                    anchors.margins: 10
                    visible: root.service && root.service.unreadCount > 0
                    contentWidth: width
                    contentHeight: groupsColumn.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    ColumnLayout {
                        id: groupsColumn
                        width: notifFlick.width
                        spacing: 10

                        Repeater {
                            model: root.computeGroups(root.service ? root.service.notifications : [])

                            delegate: ColumnLayout {
                                id: grpCol
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                spacing: 6

                                // App Group Header
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        text: root.getAppIcon(modelData.appName)
                                        renderType: Theme.renderType
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        color: Theme.cyan
                                    }

                                    Text {
                                        text: modelData.appName
                                        renderType: Theme.renderType
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSubhead
                                        font.weight: Font.Bold
                                        font.letterSpacing: Theme.trackingNormal
                                        color: Theme.textPrimary
                                    }

                                    Rectangle {
                                        implicitWidth: grpCountBadge.implicitWidth + 8
                                        implicitHeight: 16
                                        radius: 8
                                        color: Theme.bgSurface

                                        Text {
                                            id: grpCountBadge
                                            anchors.centerIn: parent
                                            text: modelData.items.length.toString()
                                            renderType: Theme.renderType
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontCaption
                                            font.weight: Font.Bold
                                            color: Theme.textMuted
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Clear this app's notifications
                                    Rectangle {
                                        implicitWidth: 18
                                        implicitHeight: 18
                                        radius: 3
                                        color: grpCloseArea.containsMouse ? Theme.bgSurfaceHover : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰅖"
                                            renderType: Theme.renderType
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            color: grpCloseArea.containsMouse ? Theme.red : Theme.textMuted
                                        }

                                        MouseArea {
                                            id: grpCloseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                             cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.service) root.service.dismissAppGroup(grpCol.modelData.appName);
                                            }
                                        }
                                    }
                                }

                                // Notifications list for this app
                                Repeater {
                                    model: modelData.items

                                    delegate: Rectangle {
                                        id: itemCard
                                        required property var modelData
                                        required property int index

                                        Layout.fillWidth: true
                                        implicitHeight: innerCol.implicitHeight + 14
                                        color: itemMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                                        border.color: modelData.urgency === 2 ? Theme.red : (itemMouse.containsMouse ? Theme.borderBright : Theme.borderNormal)
                                        border.width: Theme.borderWidth
                                        radius: Theme.squareRadius

                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        Behavior on border.color { ColorAnimation { duration: 120 } }

                                        // Left Urgency Strip
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

                                        // Click to focus app and close popup
                                        MouseArea {
                                            id: itemMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.service) {
                                                    root.service.focusApp(modelData);
                                                    Theme.closePopup();
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            id: innerCol
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 10
                                            anchors.topMargin: 7
                                            anchors.bottomMargin: 7
                                            spacing: 4

                                            // Summary & time & close
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Text {
                                                    text: modelData.summary
                                                    renderType: Theme.renderType
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSubhead
                                                    font.weight: Font.DemiBold
                                                    font.letterSpacing: Theme.trackingTight
                                                    color: Theme.textPrimary
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                }

                                                Text {
                                                    text: modelData.timeStr
                                                    renderType: Theme.renderType
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: Theme.fontCaption
                                                    font.letterSpacing: Theme.trackingTight
                                                    color: Theme.textMuted
                                                }

                                                Rectangle {
                                                    implicitWidth: 16
                                                    implicitHeight: 16
                                                    radius: 3
                                                    color: singleDelArea.containsMouse ? Theme.bgSurface : "transparent"

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "󰅖"
                                                        renderType: Theme.renderType
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: 9
                                                        color: singleDelArea.containsMouse ? Theme.red : Theme.textMuted
                                                    }

                                                    MouseArea {
                                                        id: singleDelArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (root.service) root.service.dismissNotification(itemCard.modelData);
                                                        }
                                                    }
                                                }
                                            }

                                            // Body Text
                                            Text {
                                                visible: modelData.body.length > 0
                                                text: modelData.body
                                                renderType: Theme.renderType
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontCaption
                                                font.letterSpacing: Theme.trackingTight
                                                color: Theme.textSecondary
                                                Layout.fillWidth: true
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 3
                                                elide: Text.ElideRight
                                            }

                                            // Image
                                            Image {
                                                visible: modelData.image && modelData.image.length > 0
                                                source: modelData.image || ""
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 90
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                smooth: true
                                                sourceSize: Qt.size(340, 90)
                                            }

                                            // Actions
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

                                                        implicitHeight: 20
                                                        implicitWidth: actBtnText.implicitWidth + 14
                                                        color: actBtnArea.containsMouse ? Theme.bgSurfaceHover : Theme.bgBase
                                                        border.color: actBtnArea.containsMouse ? Theme.cyan : Theme.borderNormal
                                                        border.width: Theme.borderWidth
                                                        radius: Theme.squareRadius

                                                        Text {
                                                            id: actBtnText
                                                            anchors.centerIn: parent
                                                            text: modelData ? modelData.text : ""
                                                            renderType: Theme.renderType
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: Theme.fontCaption
                                                            font.weight: Font.DemiBold
                                                            color: actBtnArea.containsMouse ? Theme.cyan : Theme.textPrimary
                                                        }

                                                        MouseArea {
                                                            id: actBtnArea
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                if (root.service) {
                                                                    root.service.invokeAction(itemCard.modelData, modelData);
                                                                    Theme.closePopup();
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
                    }
                }
            }
        }
    }

    // ==========================================
    // HELPER JAVASCRIPT FUNCTIONS
    // ==========================================
    function computeGroups(notifications) {
        if (!notifications) return [];
        let map = {};
        let order = [];
        for (let item of notifications) {
            let app = item.appName || "System";
            if (!map[app]) {
                map[app] = {
                    appName: app,
                    appIcon: item.appIcon || "",
                    items: []
                };
                order.push(app);
            }
            map[app].items.push(item);
        }
        return order.map(app => map[app]);
    }

    function getAppIcon(name) {
        if (!name) return "󰂚";
        let low = name.toLowerCase();
        if (low.indexOf("discord") !== -1 || low.indexOf("vesktop") !== -1) return "󰙯";
        if (low.indexOf("spotify") !== -1) return "󰓇";
        if (low.indexOf("zen") !== -1 || low.indexOf("firefox") !== -1 || low.indexOf("browser") !== -1 || low.indexOf("chrome") !== -1) return "󰈹";
        if (low.indexOf("code") !== -1 || low.indexOf("codium") !== -1) return "󰨞";
        if (low.indexOf("terminal") !== -1 || low.indexOf("ghostty") !== -1 || low.indexOf("kitty") !== -1) return "󰞷";
        if (low.indexOf("steam") !== -1) return "󰓓";
        if (low.indexOf("battery") !== -1) return "󰁹";
        return "󰂚";
    }
}
