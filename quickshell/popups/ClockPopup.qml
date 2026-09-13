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
    readonly property bool shouldBeOpen: Theme.activePopup === "clock"
    property bool popupVisible: false
    visible: popupVisible
    implicitWidth: 300
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
            if (Theme.activePopup === "clock") {
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
            duration: 300
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: popupScale
            property: "xScale"
            from: popupScale.xScale
            to: 1.0
            duration: 380
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: popupScale
            property: "yScale"
            from: popupScale.yScale
            to: 1.0
            duration: 380
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
            duration: 240
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: popupScale
            property: "xScale"
            from: popupScale.xScale
            to: 0.94
            duration: 260
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: popupScale
            property: "yScale"
            from: popupScale.yScale
            to: 0.90
            duration: 260
            easing.type: Easing.InCubic
        }
    }

    SystemClock {
        id: liveClock
        precision: root.visible ? SystemClock.Seconds : SystemClock.Hours
    }

    // Calendar state tracking
    property date viewedDate: new Date()

    readonly property int viewedYear: viewedDate.getFullYear()
    readonly property int viewedMonth: viewedDate.getMonth() // 0-11

    readonly property date today: liveClock.date

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    function firstDayOfWeek(year, month) {
        return new Date(year, month, 1).getDay(); // 0 (Sun) to 6 (Sat)
    }

    function prevMonth() {
        viewedDate = new Date(viewedYear, viewedMonth - 1, 1);
    }

    function nextMonth() {
        viewedDate = new Date(viewedYear, viewedMonth + 1, 1);
    }

    function resetToToday() {
        viewedDate = new Date();
    }

    Rectangle {
        id: mainCard
        width: parent.width
        implicitHeight: contentCol.implicitHeight + 24
        color: Theme.bgGlass
        border.color: Theme.borderBright
        border.width: Theme.borderWidth
        radius: Theme.squareRadius
        opacity: 0.0

        transform: Scale {
            id: popupScale
            origin.x: mainCard.width / 2
            origin.y: 0
            xScale: 0.94
            yScale: 0.90
        }

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // ==========================================
            // HEADER: Large Digital Clock & Full Date
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 70
                color: Theme.bgSurface
                border.color: Theme.purple
                border.width: Theme.borderWidth
                radius: Theme.squareRadius

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: Qt.formatDateTime(liveClock.date, "hh:mm:ss")
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontHero
                        font.weight: Font.Bold
                        font.letterSpacing: 1.0
                        renderType: Theme.renderType
                        color: Theme.textPrimary
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: Qt.formatDateTime(liveClock.date, "dddd, MMMM d, yyyy")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontHeadline
                        font.weight: Font.DemiBold
                        font.letterSpacing: Theme.trackingNormal
                        renderType: Theme.renderType
                        color: Theme.purple
                        Layout.alignment: Qt.AlignHCenter
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
            // CALENDAR MONTH CONTROLS
            // ==========================================
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: Qt.formatDate(root.viewedDate, "MMMM yyyy").toUpperCase()
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontHeadline
                    font.weight: Font.Bold
                    font.letterSpacing: Theme.trackingLoose
                    renderType: Theme.renderType
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }

                // Today jump button
                Rectangle {
                    implicitWidth: 52
                    implicitHeight: 22
                    color: todayMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: Theme.borderNormal
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Text {
                        anchors.centerIn: parent
                        text: "TODAY"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Bold
                        font.letterSpacing: Theme.trackingNormal
                        renderType: Theme.renderType
                        color: Theme.cyan
                    }

                    MouseArea {
                        id: todayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resetToToday()
                    }
                }

                // Prev Month Button
                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 22
                    color: prevMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: Theme.borderNormal
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Text {
                        anchors.centerIn: parent
                        text: "◀"
                        font.pixelSize: 10
                        renderType: Theme.renderType
                        color: Theme.textPrimary
                    }

                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.prevMonth()
                    }
                }

                // Next Month Button
                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 22
                    color: nextMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: Theme.borderNormal
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Text {
                        anchors.centerIn: parent
                        text: "▶"
                        font.pixelSize: 10
                        renderType: Theme.renderType
                        color: Theme.textPrimary
                    }

                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.nextMonth()
                    }
                }
            }

            // ==========================================
            // CALENDAR GRID
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: calCol.implicitHeight + 12
                color: Theme.bgSurface
                border.color: Theme.borderNormal
                border.width: Theme.borderWidth
                radius: Theme.squareRadius

                ColumnLayout {
                    id: calCol
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 4

                    // Days of week header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Repeater {
                            model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: 20

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSubhead
                                    font.weight: Font.Bold
                                    font.letterSpacing: Theme.trackingNormal
                                    renderType: Theme.renderType
                                    color: (index === 0 || index === 6) ? Theme.red : Theme.textMuted
                                }
                            }
                        }
                    }

                    // 42-day calendar matrix (6 weeks x 7 days)
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 7
                        rowSpacing: 2
                        columnSpacing: 2

                        readonly property int startOffset: root.firstDayOfWeek(root.viewedYear, root.viewedMonth)
                        readonly property int totalDays: root.daysInMonth(root.viewedYear, root.viewedMonth)
                        readonly property int prevTotalDays: root.daysInMonth(root.viewedYear, root.viewedMonth - 1)

                        Repeater {
                            model: 42

                            Rectangle {
                                id: dayCell
                                Layout.fillWidth: true
                                implicitHeight: 28

                                readonly property int dayNumber: {
                                    if (index < parent.startOffset) {
                                        return parent.prevTotalDays - (parent.startOffset - 1 - index);
                                    } else if (index < parent.startOffset + parent.totalDays) {
                                        return index - parent.startOffset + 1;
                                    } else {
                                        return index - (parent.startOffset + parent.totalDays) + 1;
                                    }
                                }

                                readonly property bool isCurrentMonth: (index >= parent.startOffset && index < parent.startOffset + parent.totalDays)

                                readonly property bool isToday: {
                                    return isCurrentMonth &&
                                           dayNumber === root.today.getDate() &&
                                           root.viewedMonth === root.today.getMonth() &&
                                           root.viewedYear === root.today.getFullYear();
                                }

                                color: isToday ? Theme.cyan : (cellMouse.containsMouse && isCurrentMonth ? Theme.bgSurfaceHover : "transparent")
                                border.color: isToday ? Theme.cyan : (cellMouse.containsMouse && isCurrentMonth ? Theme.borderBright : "transparent")
                                border.width: Theme.borderWidth
                                radius: Theme.squareRadius

                                Text {
                                    anchors.centerIn: parent
                                    text: dayCell.dayNumber.toString()
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSubhead
                                    font.weight: dayCell.isToday ? Font.Bold : Font.DemiBold
                                    font.letterSpacing: 0.4
                                    renderType: Theme.renderType
                                    color: {
                                        if (dayCell.isToday) return Theme.textDark;
                                        if (!dayCell.isCurrentMonth) return Theme.textMuted;
                                        return Theme.textPrimary;
                                    }
                                    opacity: dayCell.isCurrentMonth ? 1.0 : 0.35
                                }

                                MouseArea {
                                    id: cellMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: dayCell.isCurrentMonth
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

