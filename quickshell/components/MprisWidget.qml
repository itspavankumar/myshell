import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.popups.mpris
import ".."

Item {
    Variables { id: v }
    id: root

    Layout.leftMargin: 10
    Layout.fillHeight: true
    implicitWidth: visible ? (mprisLabel.implicitWidth + 12) : 0
    visible: Mpris.players.values.length > 0

    readonly property var player: {
        let players = Mpris.players.values;
        if (players.length === 0)
            return null;
        for (let i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing)
                return players[i];
        }
        return players[0];
    }

    readonly property string playerIcon: {
        if (!player)
            return "";
        if (player.playbackState === MprisPlaybackState.Paused)
            return "media-playback-pause-symbolic.svg";
        let id = player.identity.toLowerCase();
        if (id.includes("spotify"))
            return "com.spotify.Client-symbolic.svg";
        if (id.includes("firefox"))
            return "firefox-symbolic.svg";
        return "media-playback-start-symbolic.svg";
    }

    readonly property string trackTitle: {
        if (!player)
            return "";
        let t = player.trackTitle ?? "";
        return t.length > 24 ? t.substring(0, 22) + " ..." : t;
    }
    Rectangle {
        anchors.fill: parent
        radius: 6
        color: mprisPopup.isOpen ? v.widgetHighlight : "transparent"
    }

    Row {
        id: mprisLabel
        anchors.centerIn: parent
        spacing: 8
        Image {
            id: playerIconLabel
            source: root.playerIcon ? "../images/Media/" + root.playerIcon : ""
            sourceSize.width: 14
            sourceSize.height: 14
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.trackTitle
            font.family: "SF Pro"
            font.pixelSize: 15
            color: root.player?.playbackState === MprisPlaybackState.Playing ? v.textColor : v.textSecondary
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            mprisPopup.toggle();
            mprisPopup.updatesEnabled = mprisPopup.visible;
            root.player.positionChanged();
        }
    }

    MprisPopup {
        id: mprisPopup
        anchorItem: root
        player: root.player
    }
}
