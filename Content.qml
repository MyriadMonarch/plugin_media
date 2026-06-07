import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "services"
import qs.Common
Item {
    id: root

    signal hideRequested()
    readonly property string fontBody: "Noto Sans"

    property int activeTab: 0
    property bool isExpanded: false

    Rectangle {
        anchors.fill: parent
        color: Theme.background

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 1; color: Theme.outlineVariant; opacity: 0.5
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                id: header
                Layout.fillWidth: true
                height: 44
                color: Theme.surfaceContainer
                z: 10

                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 1; color: Theme.outlineVariant; opacity: 0.4
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 4

                    Repeater {
                        model: ["Manga", "Novel", "Anime"]

                        delegate: Item {
                            width: parent.width / 3
                            height: parent.height

                            readonly property bool active: root.activeTab === index

                            Rectangle {
                                anchors.fill: parent
                                color: tabArea.containsMouse && !active
                                    ? Qt.hsla(0, 0, 1, 0.05)
                                    : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: 12
                                font.family: root.fontBody
                                font.letterSpacing: 0.6
                                color: active ? Theme.primary : "#ffffff"
                                opacity: active ? 1 : 0.5
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }

                            Rectangle {
                                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                                width: active ? 28 : 0
                                height: 2; radius: 1
                                color: Theme.primary
                                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            }

                            MouseArea {
                                id: tabArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.activeTab = index
                            }
                        }
                    }
                }

            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.activeTab

                Loader { source: "manga/MangaReader.qml"; active: root.activeTab === 0 }
                Loader { source: "novel/NovelReader.qml"; active: root.activeTab === 1 }
                Loader { source: "anime/AnimePanel.qml"; active: root.activeTab === 2 }
            }
        }
    }
}
