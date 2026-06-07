import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services"
import "./components"
import qs.Common

Item {
    id: root
    anchors {
        left:   parent.left
        bottom:  parent.bottom
        top: parent.top
    }
    implicitWidth: 540
    visible: true
    readonly property string fontBody: "Noto Sans"

    // ── Tab state ─────────────────────────────────────────────────────────────
    property int tabIndex: 0       // 0 = Browse, 1 = Library

    // ── Navigation stacks (0 = list, 1 = detail) ──────────────────────────────
    // No "reader" stack — MPV handles playback externally
    property int browseStack:  0
    property int libraryStack: 0

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Main content (Browse / Library stacks) ────────────────────────────
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.tabIndex

            // ── Browse tab ────────────────────────────────────────────────────
            Item {
                BrowseView {
                    anchors.fill: parent
                    visible: root.browseStack === 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onAnimeSelected: function(show) {
                        Anime.fetchAnimeDetail(show)
                        root.browseStack = 1
                    }
                }

                DetailView {
                    anchors.fill: parent
                    visible: root.browseStack === 1
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onBackRequested: {
                        root.browseStack = 0
                        Anime.clearDetail()
                    }
                }
            }

            // ── Library tab ───────────────────────────────────────────────────
            Item {
                LibraryView {
                    anchors.fill: parent
                    visible: root.libraryStack === 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onAnimeSelected: function(show) {
                        Anime.fetchAnimeDetail(show)
                        root.libraryStack = 1
                    }
                }

                DetailView {
                    anchors.fill: parent
                    visible: root.libraryStack === 1
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    onBackRequested: {
                        root.libraryStack = 0
                        Anime.clearDetail()
                    }
                }
            }
        }

        // ── Bottom tab bar ────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 48
            color: Theme.surfaceContainer
            // Top hairline
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1; color: Theme.outlineVariant; opacity: 0.4
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
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.05)
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
                                color: active ? Theme.primary : "#ffffff"
                                opacity: active ? 1 : 0.5
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                font.family: root.fontBody
                                font.pixelSize: 10
                                font.letterSpacing: 0.6
                                color: active ? Theme.primary : "#ffffff"
                                opacity: active ? 1 : 0.5
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                        }

                        // Active indicator — top edge (drawer is at bottom, indicator on top)
                        Rectangle {
                            anchors {
                                top: parent.top
                                horizontalCenter: parent.horizontalCenter
                            }
                            width: active ? 28 : 0
                            height: 2; radius: 1
                            color: Theme.primary
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
