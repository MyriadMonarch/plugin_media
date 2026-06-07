import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../services"
import qs.Common

Item {
    id: libraryView
    readonly property string fontDisplay: "Noto Serif"
    readonly property string fontBody:    "Noto Sans"

    signal animeSelected(var show)

    Rectangle { anchors.fill: parent; color: Theme.background }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ────────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 52
            color: Theme.surfaceContainer; z: 2

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: Theme.outlineVariant; opacity: 0.5
            }

            RowLayout {
                anchors { fill: parent; leftMargin: 18; rightMargin: 16 }

                Row {
                    spacing: 0; Layout.fillWidth: true

                    Text {
                        text: "A"; font.family: libraryView.fontDisplay
                        font.pixelSize: 22; font.letterSpacing: 1; color: Theme.primary
                    }
                    Text {
                        text: "nime Library"; font.family: libraryView.fontDisplay
                        font.pixelSize: 22; font.letterSpacing: 1
                        color: "#ffffff"; opacity: 0.85
                    }
                }

                // Entry count badge
                Rectangle {
                    visible: Anime.libraryList.length > 0
                    height: 22; width: libCountText.implicitWidth + 16; radius: 11
                    color: Theme.surfaceContainer
                    border.color: Theme.outlineVariant; border.width: 1

                    Text {
                        id: libCountText; anchors.centerIn: parent
                        text: Anime.libraryList.length
                        font.family: libraryView.fontBody
                        font.pixelSize: 10; font.letterSpacing: 0.5
                        color: "#ffffff"
                    }
                }
            }
        }

        // ── Empty state ───────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            visible: Anime.libraryList.length === 0 && Anime.libraryLoaded

            Column {
                anchors.centerIn: parent; spacing: 14

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "⊡"; font.pixelSize: 44; color: Theme.outline; opacity: 0.3
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Your library is empty"
                    font.family: libraryView.fontDisplay
                    font.pixelSize: 15; color: "#ffffff"; opacity: 0.45
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Open any anime and tap  + Library"
                    font.family: libraryView.fontBody
                    font.pixelSize: 11; color: "#ffffff"
                    opacity: 0.4; font.letterSpacing: 0.2
                }
            }
        }

        // ── Loading ───────────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            visible: !Anime.libraryLoaded

            Rectangle {
                width: 28; height: 28; radius: 14
                anchors.centerIn: parent
                color: "transparent"; border.color: Theme.primary; border.width: 2
                RotationAnimator on rotation {
                    from: 0; to: 360; duration: 800
                    loops: Animation.Infinite; running: parent ? parent.visible : false
                    easing.type: Easing.Linear
                }
            }
        }

        // ── Library grid ──────────────────────────────────────────────────────
        GridView {
            id: libGrid
            Layout.fillWidth: true; Layout.fillHeight: true
            visible: Anime.libraryList.length > 0
            topMargin: 10; leftMargin: 8; rightMargin: 8; bottomMargin: 10
            cellWidth: Math.floor((width - leftMargin - rightMargin) / 4)
            cellHeight: cellWidth * 1.78
            clip: true; boundsBehavior: Flickable.StopAtBounds
            model: Anime.libraryList

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                implicitWidth: 3
                contentItem: Rectangle {
                    implicitWidth: 3; color: Theme.primary; opacity: 0.45; radius: 2
                }
            }

            delegate: Item {
                width: libGrid.cellWidth
                height: libGrid.cellHeight

                readonly property var entry: modelData

                Rectangle {
                    id: libCard
                    anchors { fill: parent; margins: 5 }
                    radius: 12; color: Theme.surfaceContainer

                    // Cover
                    Image {
                        id: libCover
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: parent.height - libTitleBar.height - libEpBar.height
                        source: entry.thumbnail || ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true; cache: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }

                        Rectangle {
                            anchors.fill: parent; color: Theme.surfaceContainerHigh
                            visible: libCover.status !== Image.Ready
                            Text {
                                anchors.centerIn: parent; text: "◫"
                                font.pixelSize: 32; color: Theme.outline; opacity: 0.25
                            }
                        }

                        // Score badge
                        Rectangle {
                            visible: entry.score !== null && entry.score !== undefined
                            anchors { top: parent.top; left: parent.left; topMargin: 8; leftMargin: 8 }
                            height: 20; radius: 10; width: libScoreText.implicitWidth + 12
                            color: Qt.rgba(0, 0, 0, 0.72)

                            Text {
                                id: libScoreText; anchors.centerIn: parent
                                text: entry.score ? "★ " + (entry.score).toFixed(1) : ""
                                font.family: libraryView.fontBody
                                font.pixelSize: 8; font.bold: true
                                color: "#f5c518"
                            }
                        }

                        // Bookmark indicator
                        Rectangle {
                            visible: entry.bookmarked
                            anchors { top: parent.top; right: parent.right; topMargin: 8; rightMargin: 8 }
                            width: 22; height: 22; radius: 11
                            color: Qt.rgba(0, 0, 0, 0.65)

                            Text {
                                anchors.centerIn: parent; text: "♥"
                                font.pixelSize: 9; color: Theme.primary
                            }
                        }


                    }

                    // Title bar
                    Rectangle {
                        id: libTitleBar
                        anchors { bottom: libEpBar.top; left: parent.left; right: parent.right }
                        height: libTitleText.implicitHeight + 10
                        color: Theme.surfaceContainer
                        Text {
                            id: libTitleText
                            anchors {
                                left: parent.left; right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 10; rightMargin: 10
                            }
                            text: entry.englishName || entry.name || ""
                            font.family: libraryView.fontBody
                            font.pixelSize: 11; font.letterSpacing: 0.2
                            color: "#ffffff"
                            wrapMode: Text.Wrap; maximumLineCount: 2
                            elide: Text.ElideRight; lineHeight: 1.3
                        }
                    }

                    // Last-watched bar
                    Rectangle {
                        id: libEpBar
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: 28; color: Theme.surfaceContainerHigh; radius: 12

                        // Square off the top corners
                        Rectangle {
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: parent.radius; color: parent.color
                        }

                        Row {
                            anchors {
                                verticalCenter: parent.verticalCenter
                                left: parent.left; leftMargin: 10
                            }
                            spacing: 5

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "▶"; font.pixelSize: 7
                                color: entry.lastWatchedEpNum ? Theme.primary : Theme.outline
                                opacity: entry.lastWatchedEpNum ? 1 : 0.4
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: entry.lastWatchedEpNum
                                    ? "Ep. " + entry.lastWatchedEpNum
                                    : "Not started"
                                font.family: libraryView.fontBody
                                font.pixelSize: 10; font.letterSpacing: 0.4
                                color: entry.lastWatchedEpNum
                                    ? "#ffffff" : "#ffffff"
                                opacity: entry.lastWatchedEpNum ? 0.85 : 0.45
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent; radius: 12; color: Theme.primary
                        opacity: libCardArea.pressed ? 0.16 : (libCardArea.containsMouse ? 0.07 : 0)
                        Behavior on opacity { NumberAnimation { duration: 130 } }
                    }

                    transform: Scale {
                        origin.x: libCard.width / 2; origin.y: libCard.height / 2
                        xScale: libCardArea.pressed ? 0.97 : 1.0
                        yScale: libCardArea.pressed ? 0.97 : 1.0
                        Behavior on xScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on yScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        id: libCardArea; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            // Reconstruct a minimal show object for fetchAnimeDetail
                            libraryView.animeSelected({
                                id:          entry.id,
                                name:        entry.name,
                                englishName: entry.englishName,
                                nativeName:  entry.nativeName  || "",
                                thumbnail:   entry.thumbnail,
                                score:       entry.score,
                                type:        entry.type        || "",
                                episodeCount: entry.episodeCount || "",
                                availableEpisodes: entry.availableEpisodes || { sub: 0, dub: 0, raw: 0 },
                                season:      entry.season      || null
                            })
                        }
                    }
                }
            }
        }
    }
}
