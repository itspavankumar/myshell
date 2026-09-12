import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string icon: ""
    property real size: 32
    property bool active: false

    signal activated

    Layout.preferredWidth: size
    Layout.preferredHeight: size

    implicitWidth: size
    implicitHeight: size

    // Hover / press highlight
    Rectangle {
        anchors.centerIn: parent
        implicitWidth: root.size * 0.9
        implicitHeight: root.size * 0.9
        radius: width / 2
        color: "transparent"
    }

    Image {
        anchors.centerIn: parent
        sourceSize.width: root.size * 0.6
        sourceSize.height: root.size * 0.6
        source: root.icon
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.enabled)
            root.activated()
    }
}
