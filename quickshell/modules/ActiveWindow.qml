import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../theme"

Rectangle {
    id: root

    implicitHeight: Theme.barHeight - 8
    implicitWidth: Math.min(380, Math.max(120, contentRow.implicitWidth + 20))
    visible: Hyprland.activeToplevel !== null && windowTitleText.text.length > 0

    color: Theme.bgSurface
    border.color: Theme.borderNormal
    border.width: Theme.borderWidth
    radius: Theme.squareRadius

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8

        // Small indicator icon / glyph
        Text {
            text: "󰣆"
            font.family: Theme.fontFamily
            font.pixelSize: 13
            color: Theme.purple
            renderType: Text.NativeRendering
        }

        Text {
            id: windowTitleText
            Layout.fillWidth: true
            text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            font.weight: Font.DemiBold
            font.letterSpacing: Theme.trackingTight
            color: Theme.textPrimary
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            renderType: Text.NativeRendering
        }
    }
}
