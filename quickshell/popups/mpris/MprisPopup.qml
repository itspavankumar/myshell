import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Widgets
import "../.."

PopupWindow {
    Variables { id: v }
    id: root

    property bool isOpen: false

    Timer {
        id: closeTimer
        interval: 0
        onTriggered: {
            root.visible = false;
        }
    }

    function toggle() {
        if (isOpen) {
            isOpen = false;
            root.visible = false;
        } else {
            closeTimer.stop();
            isOpen = true;
            visible = true;
        }
    }

    onVisibleChanged: {
        if (!visible && isOpen) {
            isOpen = false;
        }
    }

    implicitWidth: 360
    implicitHeight: contentColumn.implicitHeight + 48
    grabFocus: true

    property Item anchorItem: null

    anchor {
        item: anchorItem
        edges: Edges.Bottom
        rect.y: 12
        rect.x: anchorItem ? (anchorItem.width / 2 - root.width / 2) : 0
    }

    updatesEnabled: false
    color: "transparent"
    property string albumPlaceholder: ""
    property var player: null
    readonly property string artUrl: player?.trackArtUrl ?? ""
    readonly property string title: player?.trackTitle ?? "没有歌在播放"
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string album: player?.trackAlbum ?? ""
    readonly property bool canPlay: player?.canPlay ?? false
    readonly property bool canPause: player?.canPause ?? false
    readonly property bool canNext: player?.canGoNext ?? false
    readonly property bool canPrev: player?.canGoPrevious ?? false
    readonly property bool canSeek: player?.canSeek ?? false
    readonly property real position: player?.position ?? 0
    readonly property bool playing: player?.playbackState === MprisPlaybackState.Playing
    readonly property real length: player?.length ?? 0

    Item {
        id: animContainer
        anchors.fill: parent
        transformOrigin: Item.Top
        
        scale: root.isOpen ? 1.0 : 0.8
        opacity: root.isOpen ? 1.0 : 0.0
        
        Behavior on scale { SpringAnimation { id: closeAnim; spring: 3; damping: 0.2 } }
        Behavior on opacity { NumberAnimation { id: opacityAnim; duration: 150 } }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 16
        color: "transparent"
    RectangularShadow {
        anchors.fill: mprisBorder
        anchors.margins: 2
        radius: Math.max(0, mprisBorder.radius - 2)
        blur: 10
        color: v.shadowColor
    }

        Rectangle {
            id: mprisBorder
            anchors.fill: parent
            anchors.margins: 16
            radius: parent.radius

            color: v.popupBackground

            border.color: v.popupBorder

            border.width: 1

        }



        ColumnLayout {
            id: contentColumn
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 24
            }
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 16

                Rectangle {
                    visible: true
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 80
                    color: "transparent"

                    RectangularShadow {
                        anchors.fill: parent
                        radius: 10
                        blur: 8
                        color: Qt.rgba(0, 0, 0, 0.1)
                        spread: 4
                    }
                    ClippingRectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: 10
                        Image {
                            id: artImage
                            anchors.fill: parent
                            mipmap: true
                            source: root.artUrl || root.albumPlaceholder
                            fillMode: Image.PreserveAspectCrop
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: artImage.status !== Image.Ready
                        text: "♫"
                        font.pixelSize: 32
                        color: v.textColor
                    }
                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            root.player?.raise();
                            root.visible = false;
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        text: root.title
                        color: v.textColor
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignLeft
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.artist.length > 0 || root.album.length > 0
                        text: [root.artist, root.album].filter(Boolean).join("  ·  ")
                        color: v.textSecondary
                        font.pixelSize: 14
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignLeft
                    }
                }
            }
            Timer {
                running: playing && root.visible && !seekSlider.pressed
                interval: 1000
                repeat: true
                onTriggered: player.positionChanged()
            }
            Slider {
                id: seekSlider
                Layout.fillWidth: true
                Layout.topMargin: 12

                Layout.leftMargin: 0
                Layout.rightMargin: 0
                from: 0
                to: root.length
                value: root.position
                height: 20
                background: Rectangle {
                    x: seekSlider.leftPadding
                    y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                    width: seekSlider.availableWidth
                    height: 4
                    radius: 2
                    color: "#40ffffff"
                    
                    Rectangle {
                        width: seekSlider.visualPosition * (parent.width)
                        height: parent.height
                        color: v.textColor
                        radius: 2
                    }
                }
                handle: Rectangle {
                    x: seekSlider.leftPadding + seekSlider.visualPosition * (seekSlider.availableWidth - width)
                    y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                    implicitWidth: 8
                    implicitHeight: 16
                    radius: 4
                    color: v.textColor
                }

                onMoved: {
                    player.position = player.length * seekSlider.visualPosition;
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                Layout.bottomMargin: 6

                Layout.leftMargin: 4
                Layout.rightMargin: 4

                Text {
                    text: formatMs(root.position)
                    color: v.textSecondary
                    font.pixelSize: 10
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    text: root.length > 0 ? formatMs(root.length) : "-:--"
                    color: v.textSecondary
                    font.pixelSize: 10
                }
            }

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: controlRow.implicitHeight

                RowLayout {
                    id: controlRow
                    width: implicitWidth
                    anchors.centerIn: parent
                    spacing: 24

                    // Previous
                    ControlButton {
                        icon: "../../images/Media/media-skip-backward.svg"
                        size: 48
                        onActivated: root.player?.previous()
                    }

                    // Play / Pause
                    ControlButton {
                        icon: root.playing ? "../../images/Media/media-playback-pause.svg" : "../../images/Media/media-playback-start.svg"
                        size: 48
                        onActivated: root.playing ? root.player?.pause() : root.player?.play()
                    }

                    // Next
                    ControlButton {
                        icon: "../../images/Media/media-skip-forward.svg"
                        size: 48
                        onActivated: root.player?.next()
                    }
                }
            }
        } // ColumnLayout
    } // card Rectangle
    } // animContainer


    function formatMs(time) {
        if (!time || isNaN(time)) return "0:00";
        
        let totalSec = time / 1000000;
        
        // If a player incorrectly reports in seconds directly (e.g. VLC sometimes)
        if (totalSec > 0 && totalSec < 0.05 && time > 5) {
            totalSec = time;
        }

        totalSec = Math.floor(totalSec);
        const h = Math.floor(totalSec / 3600);
        const m = Math.floor((totalSec % 3600) / 60);
        const s = Math.floor(totalSec % 60);
        
        if (h > 0) {
            return h + ":" + String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0");
        }
        return m + ":" + String(s).padStart(2, "0");
    }
}
