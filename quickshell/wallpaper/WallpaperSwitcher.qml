import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
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
    WlrLayershell.namespace: "quickshell-wallpaper-switcher"
    WlrLayershell.keyboardFocus: (root.service && root.service.isOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    visible: (root.service && root.service.isOpen) || carouselArea.opacity > 0.005

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
    // PARALLELOGRAM CAROUSEL CONTAINER
    // ==========================================
    Item {
        id: carouselArea
        anchors.fill: parent

        opacity: (root.service && root.service.isOpen) ? 1.0 : 0.0

        transform: [
            Translate {
                y: (root.service && root.service.isOpen) ? 0 : 12
                Behavior on y {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
            },
            Scale {
                origin.x: carouselArea.width / 2
                origin.y: carouselArea.height / 2
                xScale: (root.service && root.service.isOpen) ? 1.0 : 0.96
                yScale: (root.service && root.service.isOpen) ? 1.0 : 0.96
                Behavior on xScale {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
                Behavior on yScale {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
            }
        ]

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
        }

        // Prevent clicks on carousel from closing backdrop
        MouseArea {
            anchors.fill: carouselView
        }

        // Keyboard navigation
        focus: root.service && root.service.isOpen
        Keys.onPressed: (event) => {
            if (!root.service) return;
            let total = root.service.wallpapers.length;
            if (total === 0) return;

            if (event.key === Qt.Key_Right) {
                root.service.selectedIndex = (root.service.selectedIndex + 1) % total;
                carouselView.positionViewAtIndex(root.service.selectedIndex, ListView.Center);
                event.accepted = true;
            } else if (event.key === Qt.Key_Left) {
                root.service.selectedIndex = (root.service.selectedIndex - 1 + total) % total;
                carouselView.positionViewAtIndex(root.service.selectedIndex, ListView.Center);
                event.accepted = true;
            } else if (event.key === Qt.Key_Space) {
                root.service.applyIndex(root.service.selectedIndex, true);
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.service.applyIndex(root.service.selectedIndex, false);
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                root.service.applyRandom();
                carouselView.positionViewAtIndex(root.service.selectedIndex, ListView.Center);
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.service.close();
                event.accepted = true;
            }
        }

        // ==========================================
        // TOP THEME COLLECTION PILL
        // ==========================================
        Rectangle {
            anchors.bottom: carouselView.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 20
            implicitHeight: 32
            implicitWidth: collectionRow.implicitWidth + 24
            color: Theme.bgGlass
            border.color: Theme.borderBright
            border.width: Theme.borderWidth
            radius: Theme.squareRadius

            RowLayout {
                id: collectionRow
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    width: 7
                    height: 7
                    radius: 3.5
                    color: Theme.cyan
                }

                Text {
                    text: (root.service && root.service.activeFolder ? root.service.activeFolder : Theme.activePalette.name) + " Collection"
                    renderType: Theme.renderType
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontBody
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                }

                Rectangle {
                    implicitWidth: countText.implicitWidth + 10
                    implicitHeight: 18
                    color: Theme.bgSurfaceActive
                    radius: Theme.squareRadius

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: (root.service ? root.service.wallpapers.length : 0).toString()
                        renderType: Theme.renderType
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Bold
                        color: Theme.cyan
                    }
                }
            }
        }

        // ==========================================
        // HORIZONTAL PARALLELOGRAM LISTVIEW
        // ==========================================
        ListView {
            id: carouselView
            anchors.centerIn: parent
            width: Math.min(parent.width - 60, 1280)
            height: 400

            orientation: ListView.Horizontal
            spacing: 3
            clip: false
            boundsBehavior: Flickable.StopAtBounds

            preferredHighlightBegin: (width - 580) / 2
            preferredHighlightEnd: (width + 580) / 2
            highlightRangeMode: ListView.ApplyRange

            model: root.service ? root.service.wallpapers : []

            delegate: Item {
                id: sliceItem
                required property var modelData
                required property int index

                readonly property bool isCurrent: root.service && root.service.selectedIndex === index
                readonly property real skew: 26

                width: isCurrent ? 580 : 115
                height: carouselView.height

                Behavior on width {
                    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                }

                z: isCurrent ? 10 : (itemMouse.containsMouse ? 5 : 1)

                // 1. Parallelogram Clipping Mask
                Item {
                    id: maskShape
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true

                    Shape {
                        anchors.fill: parent
                        antialiasing: true
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: "white"
                            strokeColor: "transparent"
                            startX: sliceItem.skew
                            startY: 0
                            PathLine { x: sliceItem.width; y: 0 }
                            PathLine { x: sliceItem.width - sliceItem.skew; y: sliceItem.height }
                            PathLine { x: 0; y: sliceItem.height }
                            PathLine { x: sliceItem.skew; y: 0 }
                        }
                    }
                }

                // 2. Wallpaper Image with MultiEffect Mask
                Item {
                    id: imgContainer
                    anchors.fill: parent

                    Image {
                        anchors.fill: parent
                        source: "file://" + modelData.path
                        sourceSize: Qt.size(580, 400)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                    }

                    // Darkness tint on collapsed slices
                    Rectangle {
                        anchors.fill: parent
                        color: "#000000"
                        opacity: sliceItem.isCurrent ? 0.0 : (itemMouse.containsMouse ? 0.15 : 0.45)
                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }
                    }

                    // Scrim gradient at bottom of active wallpaper
                    Rectangle {
                        visible: sliceItem.isCurrent
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 70
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: "#d90a0c12" }
                        }
                    }

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: maskShape
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }
                }

                // 3. Parallelogram Border Outline (Razor-sharp CurveRenderer)
                Shape {
                    anchors.fill: parent
                    antialiasing: true
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: sliceItem.isCurrent ? Theme.cyan : (itemMouse.containsMouse ? Theme.borderBright : Theme.borderDim)
                        strokeWidth: sliceItem.isCurrent ? 2 : 1
                        Behavior on strokeColor {
                            ColorAnimation { duration: 120 }
                        }
                        startX: sliceItem.skew
                        startY: 0
                        PathLine { x: sliceItem.width; y: 0 }
                        PathLine { x: sliceItem.width - sliceItem.skew; y: sliceItem.height }
                        PathLine { x: 0; y: sliceItem.height }
                        PathLine { x: sliceItem.skew; y: 0 }
                    }
                }

                // 4. Center Name Label Pill (Expanded Card Only)
                Rectangle {
                    visible: sliceItem.isCurrent
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 16
                    implicitHeight: 28
                    implicitWidth: Math.min(nameLabel.implicitWidth + 24, sliceItem.width - 60)
                    color: Theme.bgGlass
                    border.color: Theme.borderBright
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Text {
                        id: nameLabel
                        anchors.centerIn: parent
                        width: parent.width - 20
                        text: modelData.name
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSubhead
                        font.weight: Font.DemiBold
                        font.letterSpacing: Theme.trackingTight
                        color: Theme.textPrimary
                        elide: Text.ElideMiddle
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // 5. Active Wallpaper Indicator Badge
                Rectangle {
                    visible: sliceItem.isCurrent && (root.service && root.service.currentWallpaper === modelData.path)
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 16
                    implicitHeight: 20
                    implicitWidth: activeLabel.implicitWidth + 14
                    color: Theme.cyan
                    radius: 4

                    Text {
                        id: activeLabel
                        anchors.centerIn: parent
                        text: "ACTIVE"
                        renderType: Theme.renderType
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Bold
                        font.letterSpacing: Theme.trackingNormal
                        color: Theme.bgBase
                    }
                }

                // 6. Interactive Click and Hover
                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.service) {
                            if (sliceItem.isCurrent) {
                                // If already selected, apply and close
                                root.service.applyIndex(index, false);
                            } else {
                                // Expand this item
                                root.service.selectedIndex = index;
                                carouselView.positionViewAtIndex(index, ListView.Center);
                            }
                        }
                    }
                    onDoubleClicked: {
                        if (root.service) {
                            root.service.selectedIndex = index;
                            root.service.applyIndex(index, false);
                        }
                    }
                }
            }
        }

        // ==========================================
        // FLOATING BOTTOM KEY HINTS PILL
        // ==========================================
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 32
            implicitHeight: 32
            implicitWidth: hintsRow.implicitWidth + 28
            color: Theme.bgGlass
            border.color: Theme.borderBright
            border.width: Theme.borderWidth
            radius: Theme.squareRadius

            RowLayout {
                id: hintsRow
                anchors.centerIn: parent
                spacing: 16

                RowLayout {
                    spacing: 5
                    Text {
                        text: "← →"
                        renderType: Theme.renderType
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Bold
                        color: Theme.cyan
                    }
                    Text {
                        text: "navigate"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Medium
                        color: Theme.textSecondary
                    }
                }

                RowLayout {
                    spacing: 5
                    Text {
                        text: "space"
                        renderType: Theme.renderType
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Bold
                        color: Theme.cyan
                    }
                    Text {
                        text: "live preview"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Medium
                        color: Theme.textSecondary
                    }
                }

                RowLayout {
                    spacing: 5
                    Text {
                        text: "↵"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSubhead
                        font.weight: Font.Bold
                        color: Theme.cyan
                    }
                    Text {
                        text: "apply"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Medium
                        color: Theme.textSecondary
                    }
                }

                RowLayout {
                    spacing: 5
                    Text {
                        text: "r"
                        renderType: Theme.renderType
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Bold
                        color: Theme.yellow
                    }
                    Text {
                        text: "random"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Medium
                        color: Theme.textSecondary
                    }
                }

                RowLayout {
                    spacing: 5
                    Text {
                        text: "esc"
                        renderType: Theme.renderType
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Bold
                        color: Theme.textMuted
                    }
                    Text {
                        text: "close"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Medium
                        color: Theme.textSecondary
                    }
                }
            }
        }
    }

    // Auto-focus and center current item when opened
    Connections {
        target: root.service
        function onIsOpenChanged() {
            if (root.service && root.service.isOpen) {
                carouselArea.forceActiveFocus();
                if (carouselView.count > 0 && root.service.selectedIndex >= 0) {
                    carouselView.positionViewAtIndex(root.service.selectedIndex, ListView.Center);
                }
            }
        }
    }
}
