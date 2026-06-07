import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../services"
import qs.Common

Item {
    id: detailView
    readonly property string fontDisplay: "Noto Serif"
    readonly property string fontBody:    "Noto Sans"

    signal backRequested()
    signal chapterSelected(string chapterId)

    // ── Library state ─────────────────────────────────────────────────────────
    readonly property bool _inLibrary:
        Manga.currentManga ? Manga.isInLibrary(Manga.currentManga.id) : false

    // ── Filter / sort state ───────────────────────────────────────────────────
    property bool   _sortAscending:  false
    property string _chapterFilter:  ""

    function reset() {
        _chapterFilter  = ""
        _sortAscending  = false
    }

    // ── Helper ────────────────────────────────────────────────────────────────
    function formatChapter(ch) {
        if (!ch) return "?"
        const match = ch.match(/\d+(\.\d+)?/)
        return match ? match[0] : ch
    }

    // ── Processed (filtered + sorted) chapter list ────────────────────────────
    readonly property var _processedChapters: {
        if (!Manga.currentManga) return []
        let chapters = Manga.currentManga.chapters.slice()

        if (detailView._chapterFilter.trim() !== "") {
            const f = detailView._chapterFilter.trim().toLowerCase()
            chapters = chapters.filter(ch => {
                const num   = detailView.formatChapter(ch.chapter).toLowerCase()
                const title = (ch.title || "").toLowerCase()
                return num.includes(f) || title.includes(f)
            })
        }

        chapters.sort((a, b) => {
            const numA = parseFloat(detailView.formatChapter(a.chapter)) || 0
            const numB = parseFloat(detailView.formatChapter(b.chapter)) || 0
            return detailView._sortAscending ? numA - numB : numB - numA
        })

        return chapters
    }

    // ═════════════════════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ────────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 56
            color: Theme.surfaceContainer
            z: 2

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: Theme.outlineVariant; opacity: 0.5
            }

            RowLayout {
                anchors { fill: parent; leftMargin: 6; rightMargin: 10 }
                spacing: 2

                // ── Back button ───────────────────────────────────────────────
                Item {
                    width: 44; height: 44

                    Rectangle {
                        anchors.centerIn: parent
                        width: 34; height: 34; radius: 17
                        color: backArea.containsMouse ? Theme.surfaceContainer : "transparent"
                            }
                    Text {
                        anchors.centerIn: parent
                        text: "←"; font.pixelSize: 18; color: "#ffffff"
                    }
                    MouseArea {
                        id: backArea; anchors.fill: parent; hoverEnabled: true
                        onClicked: { Manga.clearChapterList(); detailView.backRequested() }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: Manga.currentManga ? Manga.currentManga.title : ""
                    font.family: detailView.fontDisplay
                    font.pixelSize: 15; color: "#ffffff"; elide: Text.ElideRight
                }

                // ── Library toggle ────────────────────────────────────────────
                Item {
                    visible: Manga.currentManga !== null
                    width: libBtnLabel.implicitWidth + 28
                    height: 34

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: detailView._inLibrary ? Theme.primaryContainer : Theme.surfaceContainer
                        border.color: detailView._inLibrary ? Theme.primary : Theme.outlineVariant
                        border.width: 1
                            }

                    Row {
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: detailView._inLibrary ? "✓" : "+"
                            font.pixelSize: 11; font.bold: true
                            color: detailView._inLibrary                                 ? Theme.surfaceText : "#ffffff"
                                    }
                        Text {
                            id: libBtnLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Library"
                            font.family: detailView.fontBody
                            font.pixelSize: 11; font.letterSpacing: 0.3
                            color: detailView._inLibrary                                 ? Theme.surfaceText : "#ffffff"
                                    }
                    }

                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            if (detailView._inLibrary)
                                Manga.removeFromLibrary(Manga.currentManga.id)
                            else
                                Manga.addToLibrary({
                                    id:       Manga.currentManga.id,
                                    title:    Manga.currentManga.title,
                                    coverUrl: Manga.currentManga.coverUrl
                                })
                        }
                    }
                }
            }
        }

        // ── Hero banner ───────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Manga.currentManga !== null ? 160 : 0
            clip: true
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            // Blurred cover background
            Image {
                anchors.fill: parent
                source: Manga.currentManga ? Manga.currentManga.coverUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true; opacity: 0.2
            }

            // Gradient overlay
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.8) }
                    GradientStop { position: 1.0; color: Theme.background }
                }
            }

            // Content row
            Row {
                anchors { fill: parent; margins: 14 }
                spacing: 14

                // Cover thumbnail
                Rectangle {
                    width: 90; height: 130; radius: 8
                    color: Theme.surfaceContainerHigh; clip: true
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        source: Manga.currentManga ? Manga.currentManga.coverUrl : ""
                        fillMode: Image.PreserveAspectCrop; asynchronous: true
                    }
                    Rectangle {
                        anchors.fill: parent; radius: 8; color: "transparent"
                        border.color: Theme.outlineVariant; border.width: 1
                    }
                }

                ColumnLayout {
                    id: mangaDescColumn
                    width: parent.width - 104; height: parent.height
                    spacing: 6

                    // Status badge
                    Rectangle {
                        visible: Manga.currentManga && Manga.currentManga.status.length > 0
                        height: 18; width: statusText.implicitWidth + 14; radius: 9
                        color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                        border.color: Theme.secondary; border.width: 1
                        Layout.alignment: Qt.AlignLeft

                        Text {
                            id: statusText; anchors.centerIn: parent
                            text: Manga.currentManga ? (Manga.currentManga.status || "").toUpperCase() : ""
                            font.family: detailView.fontBody
                            font.pixelSize: 9; font.letterSpacing: 1.2; font.bold: true
                            color: Theme.secondary
                        }
                    }

                    // Author
                    Text {
                        Layout.fillWidth: true
                        text: Manga.currentManga ? (Manga.currentManga.authors || []).join(", ") : ""
                        font.family: detailView.fontBody
                        font.pixelSize: 12; font.bold: true
                        color: "#ffffff"; elide: Text.ElideRight
                    }

                    // Description (scrollable)
                    Flickable {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true
                        contentHeight: mangaDescText.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded; width: 4; anchors.right: parent.right
                            background: Rectangle { color: "transparent" }
                            contentItem: Rectangle {
                                radius: 2; color: Qt.rgba(1, 1, 1, 0.3)
                            }
                        }

                        Text {
                            id: mangaDescText
                            width: parent.width - 8
                            text: Manga.currentManga ? Manga.currentManga.description : ""
                            font.family: detailView.fontBody; font.pixelSize: 11
                            color: "#ffffff"
                            wrapMode: Text.Wrap; opacity: 0.8; lineHeight: 1.35
                        }
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: Theme.outlineVariant; opacity: 0.35
            }
        }

        // ── Chapter count + last-read strip ───────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 36
            color: Theme.surfaceContainer
            visible: Manga.currentManga !== null

            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }

                Text {
                    text: Manga.currentManga ? Manga.currentManga.chapters.length + " chapters" : ""
                    font.family: detailView.fontBody
                    font.pixelSize: 11; font.letterSpacing: 1
                    color: "#ffffff"; opacity: 0.75
                }

                Item { Layout.fillWidth: true }

                // Last-read badge
                Rectangle {
                    readonly property var _entry: Manga.currentManga
                        ? Manga.getLibraryEntry(Manga.currentManga.id) : null
                    visible: _entry !== null && _entry !== undefined
                        && _entry.lastReadChapterNum !== ""
                        && _entry.lastReadChapterNum !== undefined
                    height: 20; width: lastReadText.implicitWidth + 18; radius: 10
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                    border.color: Theme.primary; border.width: 1

                    Text {
                        id: lastReadText; anchors.centerIn: parent
                        text: {
                            var e = Manga.currentManga
                                ? Manga.getLibraryEntry(Manga.currentManga.id) : null
                            return e ? "Last: Ch. " + detailView.formatChapter(e.lastReadChapterNum) : ""
                        }
                        font.family: detailView.fontBody
                        font.pixelSize: 9; font.letterSpacing: 0.8; color: Theme.primary
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: Theme.outlineVariant; opacity: 0.3
            }
        }

        // ── Search & Sort bar ─────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 56
            color: Theme.surfaceContainer
            visible: Manga.currentManga !== null

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 8

                // Search pill
                Rectangle {
                    Layout.fillWidth: true
                    height: 36; radius: 18
                    color: Theme.surfaceContainer
                    border.width: 1
                    border.color: chapterSearch.activeFocus ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                    Behavior on border.color { ColorAnimation { duration: 130 } }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 4 }
                        spacing: 6

                        Text {
                            text: "⌕"
                            font.pixelSize: 16
                            color: Theme.primary; opacity: 0.7
                        }

                        TextInput {
                            id: chapterSearch
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            font.family: detailView.fontBody
                            font.pixelSize: 12
                            color: "#ffffff"
                            selectionColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                            clip: true

                            // Placeholder text
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Filter chapters…"
                                font.family: detailView.fontBody
                                font.pixelSize: 12
                                color: "#ffffff"
                                opacity: 0.45
                                visible: chapterSearch.text === "" && !chapterSearch.activeFocus
                            }

                            onTextChanged: detailView._chapterFilter = text
                        }

                        // Clear button — only shown when there is text
                        Item {
                            width: visible ? 28 : 0; height: 28
                            visible: detailView._chapterFilter !== ""

                            Rectangle {
                                anchors.centerIn: parent
                                width: 22; height: 22; radius: 11
                                color: clearArea.containsMouse
                                    ? Qt.rgba(1, 1, 1, 0.12)
                                    : "transparent"
                                            }
                            Text {
                                anchors.centerIn: parent
                                text: "✕"; font.pixelSize: 11
                                color: "#ffffff"
                            }
                            MouseArea {
                                id: clearArea; anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    detailView._chapterFilter = ""
                                    chapterSearch.text = ""
                                }
                            }
                        }
                    }
                }

                // Sort toggle button
                Item {
                    width: 36; height: 36

                    Rectangle {
                        anchors.fill: parent; radius: 18
                        color: sortArea.containsMouse
                            ? Theme.primaryContainer
                            : Qt.rgba(Theme.primaryContainer.r, Theme.primaryContainer.g, Theme.primaryContainer.b, 0.6)
                        border.color: Theme.primary; border.width: 1
                            }
                    Text {
                        anchors.centerIn: parent
                        text: detailView._sortAscending ? "↑" : "↓"
                        font.pixelSize: 16; font.bold: true
                        color: Theme.surfaceText
                    }
                    MouseArea {
                        id: sortArea; anchors.fill: parent; hoverEnabled: true
                        onClicked: detailView._sortAscending = !detailView._sortAscending

                        ToolTip.visible: containsMouse
                        ToolTip.delay: 600
                        ToolTip.text: detailView._sortAscending ? "Sort: Ascending" : "Sort: Descending"
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: Theme.outlineVariant; opacity: 0.3
            }
        }

        // ── Chapter list ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            Rectangle { anchors.fill: parent; color: Theme.background }

            // Loading overlay
            Rectangle {
                anchors.fill: parent; color: Theme.background
                visible: Manga.isFetchingDetail; z: 5

                Column {
                    anchors.centerIn: parent; spacing: 14

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "transparent"; border.color: Theme.primary; border.width: 2
                        RotationAnimator on rotation {
                            from: 0; to: 360; duration: 800
                            loops: Animation.Infinite; running: parent ? parent.visible : false
                            easing.type: Easing.Linear
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "fetching chapters"
                        color: "#ffffff"
                        font.family: detailView.fontBody
                        font.pixelSize: 11; font.letterSpacing: 2; opacity: 0.7
                    }
                }
            }

            ListView {
                id: chapterList
                anchors.fill: parent; clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: detailView._processedChapters   // ← filtered + sorted

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                implicitWidth: 3
                    contentItem: Rectangle {
                        implicitWidth: 3; color: Theme.primary; opacity: 0.45; radius: 2
                    }
                }

                delegate: Rectangle {
                    width: chapterList.width; height: 58

                    readonly property var _libEntry: Manga.currentManga
                        ? Manga.getLibraryEntry(Manga.currentManga.id) : null
                    readonly property bool isLastRead:
                        _libEntry !== null && _libEntry !== undefined
                        && _libEntry.lastReadChapterId === modelData.id

                    color: isLastRead
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.07)
                        : (chapterRowArea.pressed
                            ? Theme.surfaceContainerHigh
                            : (chapterRowArea.containsMouse ? Theme.surfaceContainer : "transparent"))
    
                    Rectangle {
                        anchors {
                            bottom: parent.bottom
                            left: parent.left; right: parent.right
                            leftMargin: 72; rightMargin: 16
                        }
                        height: 1; color: Theme.outlineVariant; opacity: 0.25
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                        spacing: 14

                        // Chapter number pill
                        Rectangle {
                            width: chapterPillText.implicitWidth + 16
                            height: 26; radius: 13
                            color: isLastRead ? Theme.primary : Theme.primaryContainer

                            Text {
                                id: chapterPillText; anchors.centerIn: parent
                                text: "Ch." + detailView.formatChapter(modelData.chapter)
                                font.family: detailView.fontBody
                                font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.5
                                color: isLastRead ? Theme.onPrimary : Theme.surfaceText
                            }
                        }

                        Column {
                            Layout.fillWidth: true; spacing: 3

                            Text {
                                width: parent.width
                                text: modelData.title || ("Chapter " + detailView.formatChapter(modelData.chapter))
                                font.family: detailView.fontBody
                                font.pixelSize: 12; color: "#ffffff"; elide: Text.ElideRight
                            }
                            Text {
                                text: modelData.publishAt
                                    ? Qt.formatDate(new Date(modelData.publishAt), "MMM d, yyyy")
                                    : ""
                                font.family: detailView.fontBody
                                font.pixelSize: 10; color: "#ffffff"
                                opacity: 0.55; font.letterSpacing: 0.3
                            }
                        }

                        Text {
                            text: "›"; font.pixelSize: 20; color: Theme.outline
                            opacity: chapterRowArea.containsMouse ? 0.9 : 0.4
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }
                    }

                    MouseArea {
                        id: chapterRowArea; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            Manga.fetchChapterPages(modelData.id)
                            detailView.chapterSelected(modelData.id)
                            if (Manga.currentManga && Manga.isInLibrary(Manga.currentManga.id)) {
                                Manga.updateLastRead(
                                    Manga.currentManga.id,
                                    modelData.id,
                                    modelData.chapter
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
