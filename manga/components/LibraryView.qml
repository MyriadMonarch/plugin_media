import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../services"
import qs.Common

Item {
    id: libraryView
    readonly property string fontDisplay: "Noto Serif"
    readonly property string fontBody:    "Noto Sans"

    // Emitted when the user taps an entry — parent handles navigation
    signal mangaSelected(string mangaId)

    // ── Background ────────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: Theme.background }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Empty state ───────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Manga.libraryList.length === 0 && Manga.libraryLoaded

            Column {
                anchors.centerIn: parent
                spacing: 14

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "⊡"
                    font.pixelSize: 44
                    color: Theme.outline
                    opacity: 0.3
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Your library is empty"
                    font.family: libraryView.fontDisplay
                    font.pixelSize: 15
                    color: "#ffffff"
                    opacity: 0.45
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Open any manga and tap  + Library"
                    font.family: libraryView.fontBody
                    font.pixelSize: 11
                    color: "#ffffff"
                    opacity: 0.4
                    font.letterSpacing: 0.2
                }
            }
        }

        // ── Loading (first open before file is read) ──────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !Manga.libraryLoaded

            Column {
                anchors.centerIn: parent
                spacing: 16
                Rectangle {
                    width: 28; height: 28; radius: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "transparent"
                    border.color: Theme.primary; border.width: 2
                    RotationAnimator on rotation {
                        from: 0; to: 360; duration: 800
                        loops: Animation.Infinite
                        running: parent ? parent.visible : false
                        easing.type: Easing.Linear
                    }
                }
            }
        }

        GridView {
            id: libGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Manga.libraryList.length > 0
            topMargin: 10
            leftMargin: 8
            rightMargin: 8
            bottomMargin: 10
            cellWidth: Math.floor((width - leftMargin - rightMargin) / 4)
            cellHeight: cellWidth * 1.72
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: Manga.libraryList

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                implicitWidth: 3
                contentItem: Rectangle {
                    implicitWidth: 3
                    color: Theme.primary
                    opacity: 0.45
                    radius: 2
                }
            }

            delegate: Item {
                width: libGrid.cellWidth
                height: libGrid.cellHeight

                readonly property var libEntry: modelData

                Rectangle {
                    id: libCard
                    anchors { fill: parent; margins: 5 }
                    radius: 12
                    color: Theme.surfaceContainer

                    Image {
                        id: libCover
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: parent.height - libTitleBar.height - libLastReadBar.height
                        source: libEntry.coverUrl || ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.surfaceContainerHigh
                            visible: libCover.status !== Image.Ready
                            Text {
                                anchors.centerIn: parent
                                text: "◫"
                                font.pixelSize: 32
                                color: Theme.outline
                                opacity: 0.25
                            }
                        }


                    }

                    Rectangle {
                        id: libTitleBar
                        anchors {
                            bottom: libLastReadBar.top
                            left: parent.left; right: parent.right
                        }
                        height: libTitleText.implicitHeight + 10
                        color: Theme.surfaceContainer
                        Text {
                            id: libTitleText
                            anchors {
                                left: parent.left; right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 10; rightMargin: 10
                            }
                            text: libEntry.title || ""
                            font.family: libraryView.fontBody
                            font.pixelSize: 11
                            font.letterSpacing: 0.2
                            color: "#ffffff"
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            lineHeight: 1.3
                        }
                    }

                    Rectangle {
                        id: libLastReadBar
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: 30
                        color: Theme.surfaceContainerHigh
                        radius: 12

                        Rectangle {
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: parent.radius
                            color: parent.color
                        }

                        Row {
                            anchors {
                                verticalCenter: parent.verticalCenter
                                left: parent.left; leftMargin: 10
                            }
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "▶"
                                font.pixelSize: 7
                                color: libEntry.lastReadChapterNum
                                    ? Theme.primary
                                    : Theme.outline
                                opacity: libEntry.lastReadChapterNum ? 1 : 0.4
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: libEntry.lastReadChapterNum
                                    ? "Ch. " + libEntry.lastReadChapterNum
                                    : "Not started"
                                font.family: libraryView.fontBody
                                font.pixelSize: 10
                                font.letterSpacing: 0.4
                                color: libEntry.lastReadChapterNum
                                    ? "#ffffff"
                                    : "#ffffff"
                                opacity: libEntry.lastReadChapterNum ? 0.85 : 0.45
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: Theme.primary
                        opacity: libCardArea.pressed
                            ? 0.16 : (libCardArea.containsMouse ? 0.07 : 0)
                        Behavior on opacity { NumberAnimation { duration: 130 } }
                    }

                    transform: Scale {
                        origin.x: libCard.width / 2
                        origin.y: libCard.height / 2
                        xScale: libCardArea.pressed ? 0.97 : 1.0
                        yScale: libCardArea.pressed ? 0.97 : 1.0
                        Behavior on xScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on yScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        id: libCardArea
                        anchors.fill: parent

                        onClicked: {
                            Manga.fetchMangaDetail(libEntry.id)
                            libraryView.mangaSelected(libEntry.id)
                        }
                    }
                }
            }
        }
    }
}
