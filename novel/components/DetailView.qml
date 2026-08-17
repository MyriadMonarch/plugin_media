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
        Novel.currentNovel ? Novel.isInLibrary(Novel.currentNovel.id) : false

    // ── Filter / sort state ───────────────────────────────────────────────────
    property bool   _sortAscending: false
    property string _chapterFilter: ""

    function reset() {
        _chapterFilter = ""
        _sortAscending = false
    }

    // ── Helper ────────────────────────────────────────────────────────────────
    function formatChapter(ch) {
        if (!ch) return "?"
        const match = String(ch).match(/\d+(\.\d+)?/)
        return match ? match[0] : String(ch)
    }

    // ── Processed (filtered + sorted) chapter list ────────────────────────────
    readonly property var _processedChapters: {
        if (!Novel.currentNovel) return []
        let chapters = Novel.currentNovel.chapters.slice()

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

    // ── Reading helpers (preserved from original) ─────────────────────────────
    function continueReading() {
        if (!Novel.currentNovel) return

        var entry = Novel.getLibraryEntry(Novel.currentNovel.id)
        var lastChapterId = entry ? entry.lastReadChapterId : null
        var targetChapter = null

        if (lastChapterId) {
            for (var i = 0; i < Novel.currentNovel.chapters.length; i++) {
                if (Novel.currentNovel.chapters[i].id === lastChapterId) {
                    targetChapter = Novel.currentNovel.chapters[i]
                    break
                }
            }
        }

        if (!targetChapter && Novel.currentNovel.chapters.length > 0)
            targetChapter = Novel.currentNovel.chapters[0]

        if (targetChapter) {
            Novel.fetchChapter(targetChapter.id)
            detailView.chapterSelected(targetChapter.id)
            if (detailView._inLibrary)
                Novel.updateLastRead(Novel.currentNovel.id, targetChapter.id, targetChapter.chapter)
        }
    }

    function readNext() {
        if (!Novel.currentNovel) return

        var entry = Novel.getLibraryEntry(Novel.currentNovel.id)
        var lastChapterId = entry ? entry.lastReadChapterId : null
        var targetChapter = null

        if (lastChapterId) {
            for (var i = 0; i < Novel.currentNovel.chapters.length - 1; i++) {
                if (Novel.currentNovel.chapters[i].id === lastChapterId) {
                    targetChapter = Novel.currentNovel.chapters[i + 1]
                    break
                }
            }
        }

        if (!targetChapter && Novel.currentNovel.chapters.length > 0)
            targetChapter = Novel.currentNovel.chapters[0]

        if (targetChapter) {
            Novel.fetchChapter(targetChapter.id)
            detailView.chapterSelected(targetChapter.id)
            if (detailView._inLibrary)
                Novel.updateLastRead(Novel.currentNovel.id, targetChapter.id, targetChapter.chapter)
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ────────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 56
            color: HubTheme.surfaceContainer; z: 2

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: HubTheme.outlineVariant; opacity: 0.5
            }

            RowLayout {
                anchors { fill: parent; leftMargin: 6; rightMargin: 10 }
                spacing: 2

                // Back button
                Item {
                    width: 44; height: 44
                    Rectangle {
                        anchors.centerIn: parent; width: 34; height: 34; radius: 17
                        color: backArea.containsMouse ? HubTheme.surfaceContainer : "transparent"
                            }
                    Text { anchors.centerIn: parent; text: "←"; font.pixelSize: 18; color: HubTheme.surfaceText }
                    MouseArea {
                        id: backArea; anchors.fill: parent; hoverEnabled: true
                        onClicked: { Novel.clearDetail(); detailView.backRequested() }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: Novel.currentNovel ? Novel.currentNovel.title : ""
                    font.family: detailView.fontDisplay
                    font.pixelSize: 15; color: HubTheme.surfaceText; elide: Text.ElideRight
                }

                // Library toggle
                Item {
                    visible: Novel.currentNovel !== null
                    width: libBtnLabel.implicitWidth + 28; height: 34

                    Rectangle {
                        anchors.fill: parent; radius: height / 2
                        color: detailView._inLibrary ? HubTheme.primaryContainer : HubTheme.surfaceContainer
                        border.color: detailView._inLibrary ? HubTheme.primary : HubTheme.outlineVariant
                        border.width: 1
                            }

                    Row {
                        anchors.centerIn: parent; spacing: 5
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: detailView._inLibrary ? "✓" : "+"
                            font.pixelSize: 11; font.bold: true
                            color: HubTheme.surfaceText
                                    }
                        Text {
                            id: libBtnLabel; anchors.verticalCenter: parent.verticalCenter
                            text: "Library"; font.family: detailView.fontBody
                            font.pixelSize: 11; font.letterSpacing: 0.3
                            color: HubTheme.surfaceText
                                    }
                    }

                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            if (detailView._inLibrary)
                                Novel.removeFromLibrary(Novel.currentNovel.id)
                            else
                                Novel.addToLibrary({
                                    id:       Novel.currentNovel.id,
                                    title:    Novel.currentNovel.title,
                                    coverUrl: Novel.currentNovel.coverUrl
                                })
                        }
                    }
                }
            }
        }

        // ── Hero banner ───────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Novel.currentNovel !== null ? 160 : 0
            clip: true
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            // Blurred cover background
            Image {
                anchors.fill: parent
                source: Novel.currentNovel ? Novel.currentNovel.coverUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true; opacity: 0.2
            }

            // Gradient overlay
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(HubTheme.surfaceContainer.r, HubTheme.surfaceContainer.g, HubTheme.surfaceContainer.b, 0.8) }
                    GradientStop { position: 1.0; color: HubTheme.background }
                }
            }

            // Content row
            Row {
                anchors { fill: parent; margins: 14 }
                spacing: 14

                // Cover thumbnail
                Rectangle {
                    width: 90; height: 130; radius: 8
                    color: HubTheme.surfaceContainerHigh; clip: true
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        source: Novel.currentNovel ? Novel.currentNovel.coverUrl : ""
                        fillMode: Image.PreserveAspectCrop; asynchronous: true
                    }
                    Rectangle {
                        anchors.fill: parent; radius: 8; color: "transparent"
                        border.color: HubTheme.outlineVariant; border.width: 1
                    }
                }

                ColumnLayout {
                    width: parent.width - 104; height: parent.height
                    spacing: 6

                    // Status badge
                    Rectangle {
                        visible: Novel.currentNovel && Novel.currentNovel.status.length > 0
                        height: 18; width: statusTxt.implicitWidth + 14; radius: 9
                        color: Qt.rgba(HubTheme.secondary.r, HubTheme.secondary.g, HubTheme.secondary.b, 0.15)
                        border.color: HubTheme.secondary; border.width: 1
                        Layout.alignment: Qt.AlignLeft

                        Text {
                            id: statusTxt; anchors.centerIn: parent
                            text: Novel.currentNovel ? (Novel.currentNovel.status || "").toUpperCase() : ""
                            font.family: detailView.fontBody; font.pixelSize: 9
                            font.letterSpacing: 1.2; font.bold: true; color: HubTheme.secondary
                        }
                    }

                    // Author
                    Text {
                        Layout.fillWidth: true
                        text: Novel.currentNovel ? Novel.currentNovel.author : ""
                        font.family: detailView.fontBody; font.pixelSize: 12; font.bold: true
                        color: HubTheme.surfaceText; elide: Text.ElideRight
                    }

                    // Genres
                    Text {
                        visible: Novel.currentNovel && Novel.currentNovel.genres.length > 0
                        Layout.fillWidth: true
                        text: Novel.currentNovel ? Novel.currentNovel.genres.join(" · ") : ""
                        font.family: detailView.fontBody; font.pixelSize: 10
                        color: HubTheme.primary; opacity: 0.85; elide: Text.ElideRight; font.letterSpacing: 0.2
                    }

                    // Description (scrollable)
                    Flickable {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true
                        contentHeight: descTextNovel.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded; width: 4; anchors.right: parent.right
                            background: Rectangle { color: "transparent" }
                            contentItem: Rectangle {
                                radius: 2; color: HubTheme.outlineVariant
                            }
                        }

                        Text {
                            id: descTextNovel
                            width: parent.width - 8
                            text: Novel.currentNovel ? Novel.currentNovel.description : ""
                            font.family: detailView.fontBody; font.pixelSize: 11
                            color: HubTheme.surfaceText; wrapMode: Text.Wrap
                            opacity: 0.8; lineHeight: 1.35
                        }
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: HubTheme.outlineVariant; opacity: 0.35
            }
        }

        // ── Chapter count + last-read strip ───────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 36
            color: HubTheme.surfaceContainer
            visible: Novel.currentNovel !== null

            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }

                Text {
                    text: Novel.currentNovel ? Novel.currentNovel.chapters.length + " chapters" : ""
                    font.family: detailView.fontBody; font.pixelSize: 11
                    font.letterSpacing: 1; color: HubTheme.surfaceVariantText
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    readonly property var _entry: Novel.currentNovel
                        ? Novel.getLibraryEntry(Novel.currentNovel.id) : null
                    visible: _entry !== null && _entry !== undefined
                        && _entry.lastReadChapterNum !== "" && _entry.lastReadChapterNum !== undefined
                    height: 20; width: lastReadTxt.implicitWidth + 18; radius: 10
                    color: Qt.rgba(HubTheme.primary.r, HubTheme.primary.g, HubTheme.primary.b, 0.12)
                    border.color: HubTheme.primary; border.width: 1

                    Text {
                        id: lastReadTxt; anchors.centerIn: parent
                        text: {
                            var e = Novel.currentNovel ? Novel.getLibraryEntry(Novel.currentNovel.id) : null
                            return e ? "Last: Ch. " + e.lastReadChapterNum : ""
                        }
                        font.family: detailView.fontBody; font.pixelSize: 9
                        font.letterSpacing: 0.8; color: HubTheme.primary
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: HubTheme.outlineVariant; opacity: 0.3
            }
        }

        // ── Continue / Next Chapter buttons ───────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 48
            color: HubTheme.surfaceContainer
            visible: Novel.currentNovel !== null

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 8

                Button {
                    text: "Continue"
                    font.family: detailView.fontBody; font.pixelSize: 12; font.bold: true
                    contentItem: Text {
                        text: parent.text; font: parent.font
                        color: HubTheme.onPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { color: HubTheme.primary; radius: 14; opacity: parent.enabled ? 1 : 0.6 }
                    onClicked: continueReading()
                }

                Button {
                    text: "Next Chapter"
                    font.family: detailView.fontBody; font.pixelSize: 12; font.bold: true
                    contentItem: Text {
                        text: parent.text; font: parent.font
                        color: HubTheme.onPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { color: HubTheme.primary; radius: 14; opacity: parent.enabled ? 1 : 0.6 }
                    onClicked: readNext()
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: HubTheme.outlineVariant; opacity: 0.3
            }
        }

        // ── Search & Sort bar ─────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 56
            color: HubTheme.surfaceContainer
            visible: Novel.currentNovel !== null

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 8

                // Search pill
                Rectangle {
                    Layout.fillWidth: true
                    height: 36; radius: 18
                    color: HubTheme.surfaceContainer
                    border.width: 1
                    border.color: chapterSearch.activeFocus
                        ? HubTheme.primary
                        : Qt.rgba(HubTheme.outline.r, HubTheme.outline.g, HubTheme.outline.b, 0.2)
                    Behavior on border.color { ColorAnimation { duration: 130 } }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 4 }
                        spacing: 6

                        Text {
                            text: "⌕"; font.pixelSize: 16
                            color: HubTheme.primary; opacity: 0.7
                        }

                        TextInput {
                            id: chapterSearch
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            font.family: detailView.fontBody; font.pixelSize: 12
                            color: HubTheme.surfaceText
                            selectionColor: Qt.rgba(HubTheme.primary.r, HubTheme.primary.g, HubTheme.primary.b, 0.35)
                            clip: true

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Filter chapters…"
                                font.family: detailView.fontBody; font.pixelSize: 12
                                color: HubTheme.surfaceVariantText
                                visible: chapterSearch.text === "" && !chapterSearch.activeFocus
                            }

                            onTextChanged: detailView._chapterFilter = text
                        }

                        // Clear button
                        Item {
                            width: visible ? 28 : 0; height: 28
                            visible: detailView._chapterFilter !== ""

                            Rectangle {
                                anchors.centerIn: parent; width: 22; height: 22; radius: 11
                                color: clearArea.containsMouse
                                    ? HubTheme.surfaceContainerHighest
                                    : "transparent"
                                            }
                            Text {
                                anchors.centerIn: parent
                                text: "✕"; font.pixelSize: 11; color: HubTheme.surfaceText
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

                // Sort toggle
                Item {
                    width: 36; height: 36

                    Rectangle {
                        anchors.fill: parent; radius: 18
                        color: sortArea.containsMouse
                            ? HubTheme.primaryContainer
                            : Qt.rgba(HubTheme.primaryContainer.r, HubTheme.primaryContainer.g, HubTheme.primaryContainer.b, 0.6)
                        border.color: HubTheme.primary; border.width: 1
                            }
                    Text {
                        anchors.centerIn: parent
                        text: detailView._sortAscending ? "↑" : "↓"
                        font.pixelSize: 16; font.bold: true
                        color: HubTheme.surfaceText
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
                height: 1; color: HubTheme.outlineVariant; opacity: 0.3
            }
        }

        // ── Chapter list ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            Rectangle { anchors.fill: parent; color: HubTheme.background }

            // Loading overlay
            Rectangle {
                anchors.fill: parent; color: HubTheme.background
                visible: Novel.isFetchingDetail; z: 5

                Column {
                    anchors.centerIn: parent; spacing: 14
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "transparent"; border.color: HubTheme.primary; border.width: 2
                        RotationAnimator on rotation {
                            from: 0; to: 360; duration: 800
                            loops: Animation.Infinite; running: parent ? parent.visible : false; easing.type: Easing.Linear
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "fetching chapters"
                        color: HubTheme.surfaceVariantText; font.family: detailView.fontBody
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
                    contentItem: Rectangle { implicitWidth: 3; color: HubTheme.primary; opacity: 0.45; radius: 2 }
                }

                delegate: Rectangle {
                    width: chapterList.width; height: 62

                    readonly property var _libEntry: Novel.currentNovel
                        ? Novel.getLibraryEntry(Novel.currentNovel.id) : null
                    readonly property bool isLastRead:
                        _libEntry !== null && _libEntry !== undefined
                        && _libEntry.lastReadChapterId === modelData.id

                    color: isLastRead
                        ? HubTheme.primaryHover
                        : (rowArea.pressed ? HubTheme.surfaceContainerHigh
                            : (rowArea.containsMouse ? HubTheme.surfaceContainer : "transparent"))
    
                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 72; rightMargin: 16 }
                        height: 1; color: HubTheme.outlineVariant; opacity: 0.25
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                        spacing: 14

                        // Chapter pill
                        Rectangle {
                            width: chPillTxt.implicitWidth + 16; height: 26; radius: 13
                            color: isLastRead ? HubTheme.primary : HubTheme.primaryContainer

                            Text {
                                id: chPillTxt; anchors.centerIn: parent
                                text: "Ch." + detailView.formatChapter(modelData.chapter)
                                font.family: detailView.fontBody; font.pixelSize: 9
                                font.bold: true; font.letterSpacing: 0.5
                                color: isLastRead ? HubTheme.onPrimary : HubTheme.surfaceText
                            }
                        }

                        Column {
                            Layout.fillWidth: true; spacing: 3

                            Text {
                                width: parent.width
                                text: modelData.title || ("Chapter " + detailView.formatChapter(modelData.chapter))
                                font.family: detailView.fontBody; font.pixelSize: 12
                                color: HubTheme.surfaceText; elide: Text.ElideRight
                            }

                            Text {
                                visible: false
                                font.family: detailView.fontBody; font.pixelSize: 10
                                color: HubTheme.surfaceVariantText; font.letterSpacing: 0.3
                            }
                        }

                        Text {
                            text: "›"; font.pixelSize: 20; color: HubTheme.outline
                            opacity: rowArea.containsMouse ? 0.9 : 0.4
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }
                    }

                    MouseArea {
                        id: rowArea; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            Novel.fetchChapter(modelData.id)
                            detailView.chapterSelected(modelData.id)
                            if (Novel.currentNovel && Novel.isInLibrary(Novel.currentNovel.id))
                                Novel.updateLastRead(Novel.currentNovel.id, modelData.id, modelData.chapter)
                        }
                    }
                }
            }
        }
    }
}
