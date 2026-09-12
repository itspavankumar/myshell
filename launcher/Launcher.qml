import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../theme"

PanelWindow {
    id: root

    property var service: null

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: (root.service && root.service.isOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: (root.service && root.service.isOpen) || card.opacity > 0.005

    // ==========================================
    // TRANSPARENT DISMISSER (Click outside to close)
    // ==========================================
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (root.service) root.service.close();
        }
    }

    // ==========================================
    // MAIN LAUNCHER CARD (Centered Popup)
    // ==========================================
    Rectangle {
        id: card
        anchors.centerIn: parent

        width: 540
        height: 440
        color: Theme.bgGlass
        border.color: Theme.borderBright
        border.width: Theme.borderWidth
        radius: Theme.squareRadius

        opacity: (root.service && root.service.isOpen) ? 1.0 : 0.0

        transform: [
            Translate {
                y: (root.service && root.service.isOpen) ? 0 : 8
                Behavior on y {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
            },
            Scale {
                origin.x: card.width / 2
                origin.y: card.height / 2
                xScale: (root.service && root.service.isOpen) ? 1.0 : 0.96
                yScale: (root.service && root.service.isOpen) ? 1.0 : 0.96
                Behavior on xScale {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                Behavior on yScale {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
            }
        ]

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
        }

        // Prevent clicks inside card from closing backdrop
        MouseArea {
            anchors.fill: parent
            // Eat clicks
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ==========================================
            // SEARCH BAR HEADER
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 48
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    // Search Icon
                    Text {
                        text: "󰍉"
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        renderType: Theme.renderType
                        color: Theme.cyan
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Search Input
                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTitle
                        font.weight: Font.Medium
                        font.letterSpacing: 0.5
                        renderType: Theme.renderType
                        color: Theme.textPrimary
                        selectionColor: Theme.cyan
                        selectedTextColor: Theme.bgBase
                        clip: true

                        Text {
                            anchors.fill: parent
                            text: "Type to search apps..."
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTitle
                            font.weight: Font.Medium
                            font.letterSpacing: 0.5
                            renderType: Theme.renderType
                            color: Theme.textMuted
                            visible: !searchInput.text && !searchInput.inputMethodComposing
                        }

                        onTextChanged: {
                            if (root.service && root.service.searchQuery !== text) {
                                root.service.searchQuery = text;
                            }
                        }

                        Keys.onPressed: (event) => {
                            if (!root.service) return;

                            if (event.key === Qt.Key_Down) {
                                root.service.selectedIndex = Math.min(root.service.filteredApps.length - 1, root.service.selectedIndex + 1);
                                appListView.positionViewAtIndex(root.service.selectedIndex, ListView.Contain);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                root.service.selectedIndex = Math.max(0, root.service.selectedIndex - 1);
                                appListView.positionViewAtIndex(root.service.selectedIndex, ListView.Contain);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.service.launchIndex(root.service.selectedIndex);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                root.service.close();
                                event.accepted = true;
                            }
                        }
                    }

                    // Escape hint badge
                    Rectangle {
                        implicitWidth: escText.implicitWidth + 10
                        implicitHeight: 22
                        color: Theme.bgSurface
                        border.color: Theme.borderDim
                        border.width: 1
                        radius: Theme.squareRadius
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            id: escText
                            anchors.centerIn: parent
                            text: "ESC"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.Bold
                            font.letterSpacing: Theme.trackingNormal
                            renderType: Theme.renderType
                            color: Theme.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.service) root.service.close();
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
            // APPLICATION LIST
            // ==========================================
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: appListView
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    spacing: 2
                    model: root.service ? root.service.filteredApps : []
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: appItem
                        required property var modelData
                        required property int index

                        width: appListView.width
                        implicitHeight: 46
                        radius: Theme.squareRadius

                        readonly property bool isSelected: root.service && root.service.selectedIndex === index

                        color: isSelected ? Theme.bgSurfaceActive : (itemMouse.containsMouse ? Theme.bgSurfaceHover : "transparent")
                        border.color: isSelected ? Theme.cyan : (itemMouse.containsMouse ? Theme.borderBright : "transparent")
                        border.width: isSelected ? 1 : (itemMouse.containsMouse ? 1 : 0)

                        Behavior on color {
                            ColorAnimation { duration: 90 }
                        }
                        Behavior on border.color {
                            ColorAnimation { duration: 90 }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 12
                            spacing: 12

                            // App Icon
                            Item {
                                implicitWidth: 28
                                implicitHeight: 28
                                Layout.alignment: Qt.AlignVCenter

                                readonly property string iconUrl: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""

                                Image {
                                    id: appIconImg
                                    anchors.fill: parent
                                    source: parent.iconUrl
                                    sourceSize: Qt.size(28, 28)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !parent.iconUrl || appIconImg.status !== Image.Ready
                                    text: "󰘳"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 16
                                    color: appItem.isSelected ? Theme.cyan : Theme.textSecondary
                                }
                            }

                            // App Titles (Name & Description)
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                Text {
                                    text: modelData.name
                                    renderType: Theme.renderType
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontHeadline
                                    font.weight: appItem.isSelected ? Font.Bold : Font.DemiBold
                                    font.letterSpacing: Theme.trackingTight
                                    color: appItem.isSelected ? Theme.cyan : Theme.textPrimary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData.genericName || modelData.comment || modelData.execString || ""
                                    renderType: Theme.renderType
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSubhead
                                    font.weight: Font.Medium
                                    font.letterSpacing: Theme.trackingTight
                                    color: Theme.textSecondary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                }
                            }

                            // Terminal badge if runInTerminal
                            Rectangle {
                                visible: modelData.runInTerminal
                                implicitWidth: termTag.implicitWidth + 8
                                implicitHeight: 18
                                color: Theme.bgBase
                                border.color: Theme.borderDim
                                border.width: 1
                                radius: Theme.squareRadius
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    id: termTag
                                    anchors.centerIn: parent
                                    text: "TERM"
                                    renderType: Theme.renderType
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontCaption
                                    font.weight: Font.Bold
                                    font.letterSpacing: Theme.trackingNormal
                                    color: Theme.textMuted
                                }
                            }

                            // Return action key hint when selected
                            Rectangle {
                                visible: appItem.isSelected
                                implicitWidth: enterHint.implicitWidth + 8
                                implicitHeight: 18
                                color: Theme.bgSurface
                                border.color: Theme.cyan
                                border.width: 1
                                radius: Theme.squareRadius
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    id: enterHint
                                    anchors.centerIn: parent
                                    text: "↵"
                                    renderType: Theme.renderType
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSubhead
                                    font.weight: Font.Bold
                                    font.letterSpacing: Theme.trackingNormal
                                    color: Theme.cyan
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: {
                                if (root.service && root.service.selectedIndex !== index) {
                                    root.service.selectedIndex = index;
                                }
                            }
                            onClicked: {
                                if (root.service) root.service.launch(modelData);
                            }
                        }
                    }
                }

                // Empty state when no apps match
                Item {
                    anchors.fill: parent
                    visible: root.service && root.service.filteredApps.length === 0

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: "󰍉"
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: 28
                            color: Theme.textMuted
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "No applications found"
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontHeadline
                            font.weight: Font.DemiBold
                            font.letterSpacing: Theme.trackingTight
                            color: Theme.textSecondary
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: root.service ? ("No match for '" + root.service.searchQuery + "'") : ""
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSubhead
                            font.letterSpacing: Theme.trackingTight
                            color: Theme.textMuted
                            Layout.alignment: Qt.AlignHCenter
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
            // FOOTER (Stats & Shortcut Hints)
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14

                    // App count
                    Text {
                        text: {
                            if (!root.service) return "";
                            let total = root.service.allApps.length;
                            let count = root.service.filteredApps.length;
                            if (root.service.searchQuery) {
                                return count + " of " + total + " apps";
                            }
                            return total + " apps available";
                        }
                        renderType: Theme.renderType
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontCaption
                        font.letterSpacing: 0.4
                        color: Theme.textMuted
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    // Navigation Hints
                    RowLayout {
                        spacing: 12
                        Layout.alignment: Qt.AlignVCenter

                        RowLayout {
                            spacing: 4
                            Text {
                                text: "↑↓"
                                renderType: Theme.renderType
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontCaption
                                font.weight: Font.Bold
                                font.letterSpacing: 0.5
                                color: Theme.cyan
                            }
                            Text {
                                text: "navigate"
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontCaption
                                font.letterSpacing: Theme.trackingTight
                                color: Theme.textMuted
                            }
                        }

                        RowLayout {
                            spacing: 4
                            Text {
                                text: "↵"
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSubhead
                                font.weight: Font.Bold
                                font.letterSpacing: 0.5
                                color: Theme.cyan
                            }
                            Text {
                                text: "launch"
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontCaption
                                font.letterSpacing: Theme.trackingTight
                                color: Theme.textMuted
                            }
                        }

                        RowLayout {
                            spacing: 4
                            Text {
                                text: "esc"
                                renderType: Theme.renderType
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontCaption
                                font.weight: Font.Bold
                                font.letterSpacing: 0.5
                                color: Theme.textSecondary
                            }
                            Text {
                                text: "close"
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontCaption
                                font.letterSpacing: Theme.trackingTight
                                color: Theme.textMuted
                            }
                        }
                    }
                }
            }
        }
    }

    // Auto-focus search input whenever opened
    Connections {
        target: root.service
        function onIsOpenChanged() {
            if (root.service && root.service.isOpen) {
                searchInput.text = "";
                searchInput.forceActiveFocus();
            }
        }
    }
}

