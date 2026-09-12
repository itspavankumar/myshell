import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import ".."
import qs.popups.volume

Item {
    Variables { id: v }
    id: root

    Layout.fillHeight: true
    Layout.leftMargin: 8
    implicitWidth: icon.implicitWidth + 12

    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    readonly property real volume: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio.volume : 0.0
    readonly property bool muted: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio.muted : false

    Rectangle {
        id: volumeWidget
        anchors.fill: parent
        radius: 6
        color: volumePopup.isOpen ? v.widgetHighlight : "transparent"
    }

    readonly property string iconSource: {
        if (muted || volume === 0.0)
            return "../images/Audio/audio-volume-muted-symbolic.svg";
        if (volume < 0.34)
            return "../images/Audio/audio-volume-low-symbolic.svg";
        if (volume < 0.67)
            return "../images/Audio/audio-volume-medium-symbolic.svg";
        return "../images/Audio/audio-volume-high-symbolic.svg";
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            volumePopup.toggle();
        }
    }
    Image {
        id: icon
        anchors.centerIn: parent
        sourceSize.width: 18
        sourceSize.height: 18
        source: root.iconSource
        visible: true
    }
    VolumePopup {
        id: volumePopup
    }
}
