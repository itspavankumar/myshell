//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "theme"

Scope {
    id: root

    property bool isOpen: false
    property int selectedIndex: 0
    readonly property var themeList: Palettes.list

    function open() {
        // Sync selectedIndex to active theme
        for (let i = 0; i < themeList.length; i++) {
            if (themeList[i] === Theme.currentTheme) {
                selectedIndex = i;
                break;
            }
        }
        isOpen = true;
    }

    function close() {
        isOpen = false;
    }

    function toggle() {
        if (isOpen) {
            close();
        } else {
            open();
        }
    }

    function selectTheme(themeId) {
        Theme.setTheme(themeId);
        close();
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "theme_toggle"
        onPressed: root.toggle()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "toggle_theme"
        onPressed: root.toggle()
    }

    IpcHandler {
        target: "themes"

        function open(): void {
            root.open();
        }

        function close(): void {
            root.close();
        }

        function toggle(): void {
            root.toggle();
        }

        function selectTheme(name: string): void {
            root.selectTheme(name);
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: switcherWindow
            required property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-theme-switcher"
            WlrLayershell.keyboardFocus: root.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            visible: root.isOpen || card.opacity > 0.005

            Connections {
                target: root
                function onIsOpenChanged() {
                    if (root.isOpen) {
                        keyHandler.forceActiveFocus();
                        themeListView.positionViewAtIndex(root.selectedIndex, ListView.Center);
                    }
                }
            }

            // Outside dismisser
            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }

            // Centered Modal Card
            Rectangle {
                id: card
                anchors.centerIn: parent
                width: 620
                height: 560
                color: Theme.bgGlass
                border.color: Theme.borderBright
                border.width: Theme.borderWidth
                radius: Theme.squareRadius

                opacity: root.isOpen ? 1.0 : 0.0
                scale: root.isOpen ? 1.0 : 0.96

                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                // Trap clicks inside card
                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                // Keyboard Navigation
                Item {
                    id: keyHandler
                    anchors.fill: parent
                    focus: true

                    Keys.onEscapePressed: root.close()

                    Keys.onUpPressed: {
                        if (root.selectedIndex > 0) root.selectedIndex--;
                        else root.selectedIndex = root.themeList.length - 1;
                        themeListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                    }

                    Keys.onDownPressed: {
                        if (root.selectedIndex < root.themeList.length - 1) root.selectedIndex++;
                        else root.selectedIndex = 0;
                        themeListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                    }

                    Keys.onReturnPressed: {
                        let t = root.themeList[root.selectedIndex];
                        if (t) root.selectTheme(t);
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    // Header Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            width: 32
                            height: 32
                            color: Theme.bgSurface
                            border.color: Theme.borderNormal
                            border.width: Theme.borderWidth
                            radius: Theme.squareRadius

                            Text {
                                anchors.centerIn: parent
                                text: "󰏘"
                                font.family: Theme.fontFamily
                                font.pixelSize: 16
                                color: Theme.accent
                                renderType: Theme.renderType
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: "COLOR SCHEMES"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontTitle
                                font.weight: Font.Bold
                                font.letterSpacing: Theme.trackingTight
                                color: Theme.textPrimary
                                renderType: Theme.renderType
                            }

                            Text {
                                text: "Select a curated dark palette for the entire shell"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSubhead
                                color: Theme.textMuted
                                renderType: Theme.renderType
                            }
                        }

                        // Close button
                        Rectangle {
                            width: 26
                            height: 26
                            color: closeMouse.containsMouse ? Theme.bgSurfaceHover : "transparent"
                            border.color: closeMouse.containsMouse ? Theme.borderBright : Theme.borderDim
                            border.width: Theme.borderWidth
                            radius: Theme.squareRadius

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: closeMouse.containsMouse ? Theme.red : Theme.textMuted
                                renderType: Theme.renderType
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.close()
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.borderDim
                    }

                    // Scrollable Theme List
                    ListView {
                        id: themeListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.themeList
                        currentIndex: root.selectedIndex

                        delegate: Rectangle {
                            id: themeRow
                            required property string modelData
                            required property int index

                            readonly property var palette: Palettes.get(modelData)
                            readonly property bool isCurrent: modelData === Theme.currentTheme
                            readonly property bool isSelected: index === root.selectedIndex

                            width: themeListView.width
                            height: 44
                            color: isSelected ? Theme.bgSurfaceActive : (rowMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface)
                            border.color: isCurrent ? Theme.accent : (isSelected ? Theme.borderBright : Theme.borderNormal)
                            border.width: Theme.borderWidth
                            radius: Theme.squareRadius

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                // Active Indicator Dot
                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: themeRow.isCurrent ? themeRow.palette.accent : "transparent"
                                    border.color: themeRow.isCurrent ? themeRow.palette.accent : Theme.borderDim
                                    border.width: 1
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Theme Info
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Layout.alignment: Qt.AlignVCenter

                                    RowLayout {
                                        spacing: 8
                                        Text {
                                            text: themeRow.palette.name
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontBody
                                            font.weight: themeRow.isCurrent ? Font.Bold : Font.DemiBold
                                            color: themeRow.isCurrent ? themeRow.palette.accent : Theme.textPrimary
                                            renderType: Theme.renderType
                                        }

                                        Rectangle {
                                            visible: themeRow.isCurrent
                                            width: 46
                                            height: 16
                                            color: themeRow.palette.accent
                                            opacity: 0.18
                                            radius: 2
                                        }

                                        Text {
                                            visible: themeRow.isCurrent
                                            text: "ACTIVE"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                            font.letterSpacing: 0.5
                                            color: themeRow.palette.accent
                                            renderType: Theme.renderType
                                            Layout.leftMargin: -48
                                        }
                                    }

                                    Text {
                                        text: themeRow.palette.desc
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontCaption
                                        color: Theme.textMuted
                                        renderType: Theme.renderType
                                        elide: Text.ElideRight
                                    }
                                }

                                // Color Swatches Preview
                                Row {
                                    spacing: 4
                                    Layout.alignment: Qt.AlignVCenter

                                    Repeater {
                                        model: themeRow.palette.swatches

                                        Rectangle {
                                            required property string modelData
                                            width: 14
                                            height: 14
                                            color: modelData
                                            border.color: Theme.borderDim
                                            border.width: 1
                                            radius: 2
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedIndex = index;
                                    root.selectTheme(themeRow.modelData);
                                }
                            }
                        }
                    }

                    // Footer with hint
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "↑↓ Navigate"
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            color: Theme.textMuted
                            renderType: Theme.renderType
                        }

                        Text {
                            text: "•"
                            color: Theme.borderBright
                            font.pixelSize: 10
                        }

                        Text {
                            text: "Enter Select"
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            color: Theme.textMuted
                            renderType: Theme.renderType
                        }

                        Text {
                            text: "•"
                            color: Theme.borderBright
                            font.pixelSize: 10
                        }

                        Text {
                            text: "Esc Dismiss"
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            color: Theme.textMuted
                            renderType: Theme.renderType
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "11 Dark Palettes"
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: Theme.accent
                            renderType: Theme.renderType
                        }
                    }
                }
            }
        }
    }
}

