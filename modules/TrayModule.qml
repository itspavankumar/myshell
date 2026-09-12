import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../theme"
import "../popups"

Rectangle {
    id: root

    property var barWindow: null

    implicitHeight: Theme.barHeight - 8
    implicitWidth: Math.max(0, trayRow.implicitWidth + 12)
    visible: SystemTray.items.values.length > 0

    property int openPopupsCount: 0
    property int hoveredItemsCount: 0
    readonly property bool isAnyPopupOpen: openPopupsCount > 0
    readonly property bool isAnyHovered: hoveredItemsCount > 0

    color: (isAnyHovered || isAnyPopupOpen) ? Theme.bgSurfaceHover : Theme.bgSurface
    border.color: isAnyPopupOpen ? Theme.cyan : (isAnyHovered ? Theme.borderBright : Theme.borderNormal)
    border.width: Theme.borderWidth
    radius: Theme.squareRadius

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    RowLayout {
        id: trayRow
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: SystemTray.items

            Rectangle {
                id: trayItem
                required property var modelData
                implicitWidth: 16
                implicitHeight: 16
                color: (itemMouse.containsMouse || trayPopup.popupVisible) ? Theme.bgSurfaceActive : "transparent"
                radius: Theme.squareRadius

                Behavior on color { ColorAnimation { duration: 150 } }

                TrayMenuPopup {
                    id: trayPopup
                    menuHandle: trayItem.modelData.menu
                    targetItem: trayItem
                    barWindow: root.barWindow

                    onPopupVisibleChanged: {
                        if (popupVisible) {
                            root.openPopupsCount++;
                        } else {
                            root.openPopupsCount = Math.max(0, root.openPopupsCount - 1);
                        }
                    }
                }

                Image {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    sourceSize: Qt.size(14, 14)
                    fillMode: Image.PreserveAspectFit
                    source: trayItem.modelData.icon ?? ""
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onContainsMouseChanged: {
                        if (containsMouse) {
                            root.hoveredItemsCount++;
                        } else {
                            root.hoveredItemsCount = Math.max(0, root.hoveredItemsCount - 1);
                        }
                    }

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            if (trayItem.modelData.hasMenu) {
                                trayPopup.toggle();
                            }
                        } else if (mouse.button === Qt.MiddleButton) {
                            trayItem.modelData.secondaryActivate();
                        } else {
                            if (trayItem.modelData.onlyMenu && trayItem.modelData.hasMenu) {
                                trayPopup.toggle();
                            } else {
                                trayItem.modelData.activate();
                            }
                        }
                    }

                    onWheel: (wheel) => {
                        trayItem.modelData.scroll(wheel.angleDelta.y, false);
                    }
                }
            }
        }
    }
}
