import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Mpris
import "../theme"

PopupWindow {
    id: root

    property var targetItem: null
    property var barWindow: null
    property var player: null

    function getWidgetCenterX() {
        if (!targetItem) return 0;
        let _reactive = targetItem.x + targetItem.width;
        try {
            let rootItem = barWindow ? barWindow.contentItem : null;
            let p = targetItem.mapToItem(rootItem, 0, 0);
            if (p.x > 0) return p.x + (targetItem.width / 2);
        } catch (e) {}
        try {
            let p2 = targetItem.mapToItem(null, 0, 0);
            if (p2.x > 0) return p2.x + (targetItem.width / 2);
        } catch (e) {}
        return targetItem.x + (targetItem.width / 2);
    }

    function updatePosition() {
        if (!targetItem) return;
        let cx = getWidgetCenterX();
        if (cx > 0) {
            anchor.rect.x = Math.round(cx - implicitWidth / 2);
        }
        anchor.updateAnchor();
    }

    anchor.window: barWindow ? barWindow : (targetItem ? targetItem.Window.window : null)
    anchor.rect.x: {
        if (!targetItem) return 0;
        let _reactive = targetItem.x + targetItem.width;
        return Math.round(getWidgetCenterX() - implicitWidth / 2);
    }
    anchor.rect.y: barWindow ? barWindow.height : Theme.barHeight
    anchor.rect.width: implicitWidth
    anchor.rect.height: 0
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.margins.top: Theme.popupMarginTop
    anchor.adjustment: PopupAdjustment.Slide

    color: "transparent"
    visible: Theme.activePopup === "media"
    implicitWidth: 250
    implicitHeight: mainCard.implicitHeight

    onVisibleChanged: {
        if (visible) {
            updatePosition();
        } else if (Theme.activePopup === "media") {
            Theme.closePopup();
        }
    }

    Rectangle {
        id: mainCard
        width: parent.width
        implicitHeight: contentCol.implicitHeight + 20
        color: Theme.bgGlass
        border.color: Theme.borderBright
        border.width: Theme.borderWidth
        radius: Theme.squareRadius

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            // ==========================================
            // TOP ROW: Artwork + Track Metadata
            // ==========================================
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // Album Art / App Icon Container
                Rectangle {
                    implicitWidth: 46
                    implicitHeight: 46
                    color: Theme.bgSurface
                    border.color: Theme.borderDim
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius
                    clip: true

                    Image {
                        id: albumArtImg
                        anchors.fill: parent
                        source: (root.player && root.player.trackArtUrl) ? root.player.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready && source !== ""
                    }

                    // Fallback app icon or music glyph (Firefox / Spotify / etc.)
                    Rectangle {
                        anchors.fill: parent
                        visible: !albumArtImg.visible
                        color: Theme.bgSurface
                        radius: Theme.squareRadius

                        Text {
                            anchors.centerIn: parent
                            text: {
                                let id = root.player ? (root.player.identity || "").toLowerCase() : "";
                                if (id.indexOf("firefox") !== -1) return "󰈹";
                                if (id.indexOf("spotify") !== -1) return "󰓇";
                                if (id.indexOf("chrome") !== -1 || id.indexOf("chromium") !== -1) return "󰕼";
                                return "󰎆";
                            }
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: 22
                            color: {
                                let id = root.player ? (root.player.identity || "").toLowerCase() : "";
                                if (id.indexOf("firefox") !== -1) return Theme.orange;
                                if (id.indexOf("spotify") !== -1) return Theme.green;
                                return Theme.cyan;
                            }
                        }
                    }
                }

                // Track Title & Artist / Album
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: (root.player && root.player.trackTitle) ? root.player.trackTitle : "No Media Playing"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontHeadline
                        font.weight: Font.Bold
                        font.letterSpacing: Theme.trackingTight
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: {
                            if (!root.player) return "No Player Active";
                            let artist = root.player.trackArtist || "";
                            let album = root.player.trackAlbum || "";
                            if (artist && album) return artist + " — " + album;
                            return artist || album || (root.player.identity || "Unknown Artist");
                        }
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSubhead
                        font.weight: Font.Medium
                        font.letterSpacing: Theme.trackingTight
                        color: Theme.textSecondary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            // ==========================================
            // BOTTOM ROW: Clean Playback Controls
            // ==========================================
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 28

                // Previous Track
                Text {
                    id: prevBtn
                    text: "󰒮"
                    renderType: Theme.renderType
                    font.family: Theme.fontFamily
                    font.pixelSize: 19
                    color: prevMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary

                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.player && root.player.canGoPrevious) {
                                root.player.previous();
                            }
                        }
                    }
                }

                // Play / Pause Master Button
                Text {
                    id: playBtn
                    text: (root.player && root.player.playbackState === MprisPlaybackState.Playing) ? "󰏤" : "󰐊"
                    renderType: Theme.renderType
                    font.family: Theme.fontFamily
                    font.pixelSize: 24
                    color: playMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.player) {
                                root.player.togglePlaying();
                            }
                        }
                    }
                }

                // Next Track
                Text {
                    id: nextBtn
                    text: "󰒭"
                    renderType: Theme.renderType
                    font.family: Theme.fontFamily
                    font.pixelSize: 19
                    color: nextMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary

                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.player && root.player.canGoNext) {
                                root.player.next();
                            }
                        }
                    }
                }
            }
        }
    }
}
