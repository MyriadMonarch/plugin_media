import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../services"
import qs.Common

Item {
    id: browseView

    // ── Exposed API ──────────────────────────────────────────────────────────
    readonly property string fontDisplay: "Noto Serif"
    readonly property string fontBody:    "Noto Sans"

    // Emitted when the user taps a manga card
    signal mangaSelected(string mangaId)

    property string currentTagId: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ──────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: Theme.surfaceContainer
            z: 2

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1
                color: Theme.outlineVariant
                opacity: 0.5
            }

            RowLayout {
                anchors { fill: parent; leftMargin: 18; rightMargin: 12 }
                spacing: 10

                // Wordmark
                Row {
                    spacing: 0
                    visible: !searchBar.visible
                    Layout.fillWidth: true

                    Text {
                        text: "M"
                        font.family: browseView.fontDisplay
                        font.pixelSize: 24
                        font.letterSpacing: 1
                        color: Theme.primary
                    }
                    Text {
                        text: "anga"
                        font.family: browseView.fontDisplay
                        font.pixelSize: 24
                        font.letterSpacing: 1
                        color: "#ffffff"
                        opacity: 0.85
                    }
                }

                // Search bar
                Rectangle {
                    id: searchBar
                    Layout.fillWidth: true
                    height: 38
                    radius: 19
                    color: Theme.surfaceContainer
                    visible: false
                    border.color: searchField.activeFocus ? Theme.primary : Theme.outlineVariant
                    border.width: searchField.activeFocus ? 1.5 : 1
                    Behavior on border.width { NumberAnimation { duration: 120 } }

                    TextInput {
                        id: searchField
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: parent.left; right: clearBtn.left
                            leftMargin: 16; rightMargin: 6
                        }
                        color: "#ffffff"
                        font.family: browseView.fontBody
                        font.pixelSize: 13
                        clip: true
                        onTextChanged: searchDebounce.restart()
                        Keys.onEscapePressed: {
                            searchBar.visible = false
                            text = ""
                            Manga.fetchByOrigin(browseView.currentTagId, true)
                        }
                    }

                    Text {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 16 }
                        text: "Search titles…"
                        color: "#ffffff"
                        font.family: browseView.fontBody
                        font.pixelSize: 13
                        visible: searchField.text.length === 0
                        opacity: 0.6
                    }

                    // Clear button
                    Item {
                        id: clearBtn
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 10 }
                        width: 22; height: 22
                        visible: searchField.text.length > 0
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 100 } }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 18; height: 18; radius: 9
                            color: Theme.surfaceContainerHighest
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: "#ffffff"
                            font.pixelSize: 9
                            font.bold: true
                        }
                        MouseArea { anchors.fill: parent; onClicked: searchField.text = "" }
                    }
                }

                Timer {
                    id: searchDebounce
                    interval: 350
                    onTriggered: {
                        if (searchField.text.trim().length > 0)
                            Manga.searchManga(searchField.text.trim(), true)
                        else
                            Manga.fetchByOrigin(browseView.currentTagId, true)
                    }
                }

                // Search toggle button
                Item {
                    width: 40; height: 40

                    Rectangle {
                        anchors.centerIn: parent
                        width: 34; height: 34; radius: 17
                        color: searchBar.visible ? Theme.primaryContainer : "transparent"
                            }
                    Text {
                        anchors.centerIn: parent
                        text: "⌕"
                        font.pixelSize: 19
                        color: searchBar.visible ? Theme.surfaceText : "#ffffff"
                            }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            searchBar.visible = !searchBar.visible
                            if (searchBar.visible) {
                                searchField.forceActiveFocus()
                            } else {
                                searchField.text = ""
                                Manga.fetchByOrigin(browseView.currentTagId, true)
                            }
                        }
                    }
                }
            }
        }

        // ── Tag filter chips ─────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 48
            color: Theme.surfaceContainer
            clip: true

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                color: Theme.outlineVariant
                opacity: 0.25
            }

            ListView {
                id: tagList
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                orientation: ListView.Horizontal
                spacing: 7
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                model: ListModel {
                    ListElement { label: "Hot";     tagId: ""       }
                    ListElement { label: "Latest";  tagId: "latest" }
                    ListElement { label: "Manga";   tagId: "ja"     }
                    ListElement { label: "Manhwa";  tagId: "ko"     }
                    ListElement { label: "Manhua";  tagId: "zh"     }
                }

                delegate: Item {
                    width: chip.implicitWidth + 28
                    height: tagList.height

                    Rectangle {
                        id: chip
                        anchors.centerIn: parent
                        implicitWidth: chipLabel.implicitWidth + 28
                        height: 30
                        radius: 15
                        color: browseView.currentTagId === tagId
                            ? Theme.primary
                            : Theme.surfaceContainer
                        border.color: browseView.currentTagId === tagId
                            ? Theme.primary
                            : Theme.outlineVariant
                        border.width: 1
        
                        Text {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: label
                            font.family: browseView.fontBody
                            font.pixelSize: 12
                            font.letterSpacing: 0.6
                            color: browseView.currentTagId === tagId
                                ? Theme.onPrimary
                                : "#ffffff"
                                    }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            browseView.currentTagId = tagId
                            searchField.text = ""
                            searchBar.visible = false
                            Manga.fetchByOrigin(tagId, true)
                        }
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1
                color: Theme.outlineVariant
                opacity: 0.3
            }
        }

        // ── Main content area ────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Loading state
            Rectangle {
                anchors.fill: parent
                color: Theme.background
                visible: Manga.isFetchingManga && Manga.mangaList.length === 0
                z: 10

                Column {
                    anchors.centerIn: parent
                    spacing: 16

                    Rectangle {
                        width: 36; height: 36; radius: 18
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "transparent"
                        border.color: Theme.primary
                        border.width: 2.5
                        RotationAnimator on rotation {
                            from: 0; to: 360; duration: 800
                            loops: Animation.Infinite
                            running: parent.visible
                            easing.type: Easing.Linear
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "loading"
                        color: "#ffffff"
                        font.family: browseView.fontBody
                        font.pixelSize: 11
                        font.letterSpacing: 2.5
                        opacity: 0.7
                    }
                }
            }

            // Error state
            Rectangle {
                anchors.fill: parent
                color: Theme.background
                visible: Manga.mangaError.length > 0 && !Manga.isFetchingManga
                z: 9

                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    Text {
                        text: "⚠"
                        font.pixelSize: 32
                        color: Theme.error
                        anchors.horizontalCenter: parent.horizontalCenter
                        opacity: 0.8
                    }
                    Text {
                        text: Manga.mangaError
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.family: browseView.fontBody
                        wrapMode: Text.Wrap
                        width: 260
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: 1.4
                    }
                }
            }

            // ── Manga grid ───────────────────────────────────────────────────
            GridView {
                id: mangaGrid
                property real savedContentY: 0
                anchors.fill: parent
                anchors.margins: 10
                readonly property int cols: Math.max(4, Math.floor(width / 190))
                cellWidth: width / cols
                cellHeight: cellWidth * 1.58
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 500
                model: Manga.mangaList

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

                MouseArea {
                    anchors.fill: parent
                    propagateComposedEvents: true
                    onWheel: {
                        var step = wheel.angleDelta.y * 1.2
                        mangaGrid.contentY = Math.max(0, Math.min(mangaGrid.contentHeight - mangaGrid.height, mangaGrid.contentY - step))
                        wheel.accepted = true
                    }
                }

                onContentYChanged: {
                    if (contentY + height > contentHeight - cellHeight * 2) {
                        savedContentY = contentY
                        Manga.fetchNextMangaPage()
                    }
                }

                delegate: Item {
                    width: mangaGrid.cellWidth
                    height: mangaGrid.cellHeight

                    Rectangle {
                        id: card
                        anchors { fill: parent; margins: 5 }
                        radius: 12
                        color: Theme.surfaceContainer
                        clip: true

                        // Cover image
                        Image {
                            id: coverImg
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: parent.height - titleBar.height
                            source: modelData.thumbUrl || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 300 } }

                            // Placeholder shimmer
                            Rectangle {
                                anchors.fill: parent
                                color: Theme.surfaceContainerHigh
                                visible: coverImg.status !== Image.Ready
                                Text {
                                    anchors.centerIn: parent
                                    text: "◫"
                                    font.pixelSize: 32
                                    color: Theme.outline
                                    opacity: 0.25
                                }
                            }

                            // Type badge
                            Rectangle {
                                visible: modelData.type && modelData.type.length > 0
                                anchors { top: parent.top; right: parent.right; topMargin: 8; rightMargin: 8 }
                                height: 20
                                radius: 10
                                width: typeText.implicitWidth + 14
                                color: Qt.rgba(0, 0, 0, 0.7)

                                Text {
                                    id: typeText
                                    anchors.centerIn: parent
                                    text: (modelData.type || "").toUpperCase()
                                    font.family: browseView.fontBody
                                    font.pixelSize: 8
                                    font.letterSpacing: 1
                                    font.bold: true
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.7)
                                }
                            }

    
                        }

                        // Title bar
                        Rectangle {
                            id: titleBar
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: titleText.implicitHeight + 18
                            color: Theme.surfaceContainer
                            radius: 12

                            Text {
                                id: titleText
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 10; rightMargin: 10
                                }
                                text: modelData.title || ""
                                font.family: browseView.fontBody
                                font.pixelSize: 11
                                font.letterSpacing: 0.2
                                color: "#ffffff"
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                lineHeight: 1.3
                            }
                        }

                        // Hover + press overlay
                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: Theme.primary
                            opacity: cardArea.pressed
                                ? 0.16
                                : (cardArea.containsMouse ? 0.07 : 0)
                            Behavior on opacity { NumberAnimation { duration: 130 } }
                        }

                        // Scale effect on hover
                        transform: Scale {
                            origin.x: card.width / 2
                            origin.y: card.height / 2
                            xScale: cardArea.pressed ? 0.97 : 1.0
                            yScale: cardArea.pressed ? 0.97 : 1.0
                            Behavior on xScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Behavior on yScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            id: cardArea
                            anchors.fill: parent
    
                            onClicked: {
                                Manga.fetchMangaDetail(modelData.id)
                                browseView.mangaSelected(modelData.id)
                            }
                        }
                    }
                }
                Connections {
                    target: Manga
                    function onIsFetchingMangaChanged() {
                        if (!Manga.isFetchingManga && mangaGrid.savedContentY > 0) {
                            mangaGrid.contentY = mangaGrid.savedContentY
                            mangaGrid.savedContentY = 0
                        }
                    }
                }
            }
        }
    }
}
