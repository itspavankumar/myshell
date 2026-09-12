// MenuItem.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../.."

Rectangle {
    Variables { id: v }
    id: item
    property alias labelElement: labelText
    property alias mouseArea: mouseArea
    property alias iconName: iconButton.icon.name
    property bool selected: false
    property string label: ""
    signal triggered

    Layout.fillWidth: true
    Layout.leftMargin: 8
    Layout.rightMargin: 8
    implicitHeight: 32
    radius: 8
    color: hovered ? v.widgetHighlight : "transparent"

    property bool hovered: false

    Image {
        source: "../../images/System/checkmark-symbolic.svg"
        sourceSize.width: 14
        sourceSize.height: 14
        visible: item.selected
        anchors.verticalCenter: parent.verticalCenter
        x: 4
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 24
            rightMargin: 14
        }
        spacing: 10
        Text {
            id: labelText
            text: item.label
            color: v.textColor
            font.family: "SF Pro"
            font.pixelSize: 18
            font.weight: item.selected ? Font.Bold : Font.Normal
            Layout.fillWidth: true
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        Button {
            id: iconButton
            implicitWidth: 24
            implicitHeight: 24

            icon.name: "headphone"
            icon.color: selected ? "#007aff" : v.textSecondary
            flat: true
            background: Item {}
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onEntered: item.hovered = true
        onExited: item.hovered = false
        onClicked: item.triggered()
        cursorShape: Qt.PointingHandCursor
    }
}
