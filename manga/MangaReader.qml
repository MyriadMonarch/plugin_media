import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services"
import "./components"
import qs.Common

Item {
    id: root

    anchors {
        left: parent.left
        right: parent.right
        top: parent.top
        bottom: parent.bottom
    }
    implicitWidth: 600
    visible: true
    readonly property string fontBody: "Noto Sans"

    property int tabIndex: 0

    property int browseStack: 0
    property int libraryStack: 0

    property string selectedMangaId: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.tabIndex

            Item {

                BrowseView {
                    anchors.fill: parent
                    visible: root.browseStack === 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onMangaSelected: function(mangaId) {
                        root.selectedMangaId = mangaId
                        root.browseStack = 1
                    }
                }

                DetailView {
                    id: browseDetail
                    anchors.fill: parent
                    visible: root.browseStack === 1
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onBackRequested:   { root.browseStack = 0 }
                    onChapterSelected: { root.browseStack = 2 }
                }

                ReaderView {
                    id: browseReader
                    anchors.fill: parent
                    visible: root.browseStack === 2
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onBackRequested: {
                        root.browseStack = 1
                        browseReader.reset()
                    }
                }
            }

            Item {
                LibraryView {
                    anchors.fill: parent
                    visible: root.libraryStack === 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onMangaSelected: function(mangaId) {
                        root.selectedMangaId = mangaId
                        root.libraryStack = 1
                    }
                }

                DetailView {
                    id: libraryDetail
                    anchors.fill: parent
                    visible: root.libraryStack === 1
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onBackRequested:   { root.libraryStack = 0 }
                    onChapterSelected: { root.libraryStack = 2 }
                }

                ReaderView {
                    id: libraryReader
                    anchors.fill: parent
                    visible: root.libraryStack === 2
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onBackRequested: {
                        root.libraryStack = 1
                        libraryReader.reset()
                    }
                }
            }
        }

        // ── Bottom tab bar ────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 48
            color: HubTheme.surfaceContainer
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1; color: HubTheme.outlineVariant; opacity: 0.4
            }

            Row {
                anchors.fill: parent

                Repeater {
                    model: [
                        { label: "Browse",  icon: "⊞" },
                        { label: "Library", icon: "⊟" }
                    ]

                    delegate: Item {
                        width: root.width / 2
                        height: parent.height

                        readonly property bool active: root.tabIndex === index

                        Rectangle {
                            anchors.fill: parent
                            color: tabArea.containsMouse && !active
                                ? Qt.rgba(HubTheme.primary.r, HubTheme.primary.g, HubTheme.primary.b, 0.05)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                font.pixelSize: 13
                                color: active ? HubTheme.primary : HubTheme.surfaceVariantText
                                opacity: active ? 1 : 0.5
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                font.family: root.fontBody
                                font.pixelSize: 10
                                font.letterSpacing: 0.6
                                color: active ? HubTheme.primary : HubTheme.surfaceVariantText
                                opacity: active ? 1 : 0.5
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                        }

                        Rectangle {
                            anchors {
                                top: parent.top
                                horizontalCenter: parent.horizontalCenter
                            }
                            width: active ? 28 : 0
                            height: 2; radius: 1
                            color: HubTheme.primary
                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            id: tabArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.tabIndex = index
                        }
                    }
                }
            }
        }
    }
}
