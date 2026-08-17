import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../services"
import qs.Common

Item {
    id: readerView

    // ── Exposed API ──────────────────────────────────────────────────────────
    readonly property string fontDisplay: "Noto Serif"
    readonly property string fontBody:    "Noto Sans"

    // Emitted when the user navigates back
    signal backRequested()

    // ── Internal state ───────────────────────────────────────────────────────
    property bool headerVisible: true
    property real zoomLevel: Settings.defaultZoom
    readonly property real zoomMin: 0.3
    readonly property real zoomMax: 1.0

    function _applyDefaultZoom() { zoomLevel = Settings.defaultZoom }



    // ── Chapter navigation helpers ────────────────────────────────────────────
    readonly property var _chapters: Manga.currentManga ? Manga.currentManga.chapters : []

    readonly property int _currentIdx: {
        var chs = _chapters
        for (var i = 0; i < chs.length; i++) {
            if (chs[i].id === Manga.currentChapterId) return i
        }
        return -1
    }

    readonly property bool _hasPrevChapter: _currentIdx > 0
    readonly property bool _hasNextChapter: _currentIdx >= 0 && _currentIdx < _chapters.length - 1

    // Track current page from scroll position by walking Column children.
    readonly property int _currentPage: {
        var count = Manga.chapterPages.length
        if (count === 0) return 0
        var y = Math.max(0, pageFlick.contentY)
        var children = pageColumn ? pageColumn.children : []
        // At the very bottom → last page
        if (y >= Math.max(0, pageFlick.contentHeight - pageFlick.height) - 1)
            return count
        // Walk Column children (skip Repeater, count delegates)
        var pageIdx = 0
        for (var i = 0; i < children.length; i++) {
            if (children[i] === pageRepeater) continue
            pageIdx++
            if (children[i].y <= y + 1 && children[i].y + children[i].height > y + 1)
                return pageIdx
        }
        // Fallback: estimate from scroll progress
        var range = Math.max(1, pageFlick.contentHeight - pageFlick.height)
        return Math.min(Math.floor((y / range) * count) + 1, count)
    }

    function goToPrevChapter() {
        if (_currentIdx <= 0) return
        Manga.fetchChapterPages(_chapters[_currentIdx - 1].id)
        readerView._applyDefaultZoom()
    }

    function goToNextChapter() {
        if (_currentIdx < 0 || _currentIdx >= _chapters.length - 1) return
        Manga.fetchChapterPages(_chapters[_currentIdx + 1].id)
        readerView._applyDefaultZoom()
    }

    // ── Public API ────────────────────────────────────────────────────────────
    // Called by the parent to reset state when re-entering this view
    function reset() {
        headerVisible = true
        readerView._applyDefaultZoom()
    }

    function zoomIn() {
        zoomLevel = Math.min(zoomMax, zoomLevel + 0.1)
    }

    function zoomOut() {
        zoomLevel = Math.max(zoomMin, zoomLevel - 0.1)
    }

    // ── Ink-black background ─────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: Settings.readerBackground }

    // ── Sequential image loading (top → bottom) ──────────────────────────────
    property int _loadIndex: -1
    Timer {
        id: seqLoad; interval: 120; repeat: true
        running: Manga.chapterPages.length > 0 && readerView._loadIndex < Manga.chapterPages.length - 1
        onTriggered: { if (readerView._loadIndex < 0) readerView._loadIndex = 0; else readerView._loadIndex = readerView._loadIndex + 1 }
    }



    // ── Reader header ────────────────────────────────────────────────────────
    Rectangle {
        id: readerHeader
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 54
        color: Qt.rgba(0.05, 0.05, 0.08, 0.95)
        z: 10
        opacity: readerView.headerVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        // Bottom hairline
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: Qt.rgba(1, 1, 1, 0.07)
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 6; rightMargin: 16 }
            spacing: 2

            // Back button
            Item {
                width: 44; height: 44

                Rectangle {
                    anchors.centerIn: parent
                    width: 34; height: 34; radius: 17
                    color: readerBackArea.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.1)
                        : "transparent"
                    }
                Text {
                    anchors.centerIn: parent
                    text: "←"
                    font.pixelSize: 18
                    color: Qt.rgba(1, 1, 1, 0.7)
                }
                MouseArea {
                    id: readerBackArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        Manga.clearChapterPages()
                        readerView.backRequested()
                    }
                }
            }

            // Title
            Text {
                Layout.fillWidth: true
                text: Manga.currentManga ? Manga.currentManga.title : ""
                font.family: readerView.fontDisplay
                font.pixelSize: 13
                color: Qt.rgba(1, 1, 1, 0.85)
                elide: Text.ElideRight
            }

            // Zoom controls
            Item {
                visible: Manga.chapterPages.length > 0
                height: 24; width: zoomRow.width

                Row {
                    id: zoomRow
                    anchors.centerIn: parent
                    spacing: 2

                    Rectangle {
                        height: 24; width: 24; radius: 12
                        color: zoomOutArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "−"
                            font.pixelSize: 14
                            color: Qt.rgba(1, 1, 1, 0.7)
                        }
                        MouseArea {
                            id: zoomOutArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: readerView.zoomOut()
                        }
                    }
                    Text {
                        text: Math.round(readerView.zoomLevel * 100) + "%"
                        font.family: readerView.fontBody
                        font.pixelSize: 10
                        color: Qt.rgba(1, 1, 1, 0.5)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Rectangle {
                        height: 24; width: 24; radius: 12
                        color: zoomInArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            font.pixelSize: 14
                            color: Qt.rgba(1, 1, 1, 0.7)
                        }
                        MouseArea {
                            id: zoomInArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                readerView.zoomIn()
                                // zoomIn may exceed 1.0 but we cap at zoomMax
                            }
                        }
                    }
                }
            }

            // Page counter badge
            Rectangle {
                visible: Manga.chapterPages.length > 0
                height: 24
                width: pageCountText.implicitWidth + 18
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.09)
                border.color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1

                Text {
                    id: pageCountText
                    anchors.centerIn: parent
                    text: readerView._currentPage + " / " + Manga.chapterPages.length
                    font.family: readerView.fontBody
                    font.pixelSize: 10
                    font.letterSpacing: 0.5
                    color: Qt.rgba(1, 1, 1, 0.65)
                }
            }

            // ── Prev / Next chapter arrows ──────────────────────────────────
            Item {
                visible: Manga.chapterPages.length > 0
                height: 24; width: 52
                Row {
                    anchors.centerIn: parent; spacing: 4

                    Rectangle {
                        height: 24; width: 24; radius: 12
                        color: prevChapArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                        opacity: readerView._hasPrevChapter ? 1 : 0.3
                        Text {
                            anchors.centerIn: parent
                            text: "◀"; font.pixelSize: 10
                            color: Qt.rgba(1, 1, 1, 0.7)
                        }
                        MouseArea {
                            id: prevChapArea; anchors.fill: parent; hoverEnabled: true
                            enabled: readerView._hasPrevChapter
                            onClicked: readerView.goToPrevChapter()
                        }
                    }
                    Rectangle {
                        height: 24; width: 24; radius: 12
                        color: nextChapArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                        opacity: readerView._hasNextChapter ? 1 : 0.3
                        Text {
                            anchors.centerIn: parent
                            text: "▶"; font.pixelSize: 10
                            color: Qt.rgba(1, 1, 1, 0.7)
                        }
                        MouseArea {
                            id: nextChapArea; anchors.fill: parent; hoverEnabled: true
                            enabled: readerView._hasNextChapter
                            onClicked: readerView.goToNextChapter()
                        }
                    }
                }
            }
        }
    }

    // ── Fetching pages overlay ───────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: HubTheme.background
        visible: Manga.isFetchingPages
        z: 8

        Column {
            anchors.centerIn: parent
            spacing: 16

            Rectangle {
                width: 40; height: 40; radius: 20
                anchors.horizontalCenter: parent.horizontalCenter
                color: "transparent"
                border.color: HubTheme.primary; border.width: 2.5
                RotationAnimator on rotation {
                    from: 0; to: 360; duration: 800
                    loops: Animation.Infinite
                    running: parent ? parent.visible : false
                    easing.type: Easing.Linear
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "loading pages"
                color: Qt.rgba(1, 1, 1, 0.4)
                font.family: readerView.fontBody
                font.pixelSize: 11
                font.letterSpacing: 2.5
            }
        }
    }

    // ── Pages error overlay ──────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: HubTheme.background
        visible: Manga.pagesError.length > 0 && !Manga.isFetchingPages
        z: 7

        Column {
            anchors.centerIn: parent
            spacing: 10

            Text {
                text: "⚠"
                font.pixelSize: 32
                color: HubTheme.error
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: 0.85
            }
            Text {
                text: Manga.pagesError
                color: Qt.rgba(1, 1, 1, 0.45)
                font.pixelSize: 11
                font.family: readerView.fontBody
                wrapMode: Text.Wrap
                width: 260
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.4
            }
        }
    }

    // ── Page list (simple scrollable container) ──────────────────────────────
    Flickable {
        id: pageFlick
        anchors {
            fill: parent
            topMargin: readerView.headerVisible ? 54 : 0
            bottomMargin: Manga.chapterPages.length > 0 ? 43 : 0
        }
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 500
        contentHeight: pageColumn.height
        Behavior on anchors.topMargin { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }


        // Tap anywhere to toggle header
        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onClicked: {
                readerView.headerVisible = !readerView.headerVisible
                mouse.accepted = false
            }
            onWheel: {
                if (wheel.modifiers & Qt.ControlModifier) {
                    readerView.zoomLevel = Math.max(readerView.zoomMin,
                        Math.min(readerView.zoomMax,
                            readerView.zoomLevel + wheel.angleDelta.y * 0.002))
                } else {
                    var y = pageFlick.contentY - wheel.angleDelta.y * 2
                    var maxY = Math.max(0, pageFlick.contentHeight - pageFlick.height)
                    pageFlick.contentY = Math.max(0, Math.min(y, maxY))
                }
            }
        }

        Column {
            id: pageColumn
            width: parent.width
            spacing: 3

            Repeater {
                id: pageRepeater
                model: Manga.chapterPages

                delegate: Item {
                    width: pageColumn.width
                    height: (pageImg.implicitHeight > 0
                        ? pageImg.implicitHeight * (pageColumn.width / pageImg.implicitWidth)
                        : pageColumn.width * 1.42) * readerView.zoomLevel
                    clip: true

                    Image {
                        id: pageImg
                        width: parent.width
                        height: parent.height
                        anchors.centerIn: parent
                        source: readerView._loadIndex >= 0 && index <= readerView._loadIndex ? (modelData.url || "") : ""
                        fillMode: Image.PreserveAspectFit
                        sourceSize: Qt.size(2560, 0)
                        asynchronous: true
                        cache: true
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 350 } }

                        // Loading placeholder
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0, 0, 0, 0.35)
                            visible: pageImg.status !== Image.Ready

                            Column {
                                anchors.centerIn: parent
                                spacing: 10

                                Rectangle {
                                    width: 18; height: 18; radius: 9
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: "transparent"
                                    border.color: Qt.rgba(1, 1, 1, 0.2)
                                    border.width: 1.5
                                    RotationAnimator on rotation {
                                        from: 0; to: 360; duration: 1200
                                        loops: Animation.Infinite
                                        running: parent ? parent.visible : false
                                        easing.type: Easing.Linear
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "p. " + (modelData.index + 1)
                                    color: Qt.rgba(1, 1, 1, 0.2)
                                    font.pixelSize: 10
                                    font.family: readerView.fontBody
                                    font.letterSpacing: 1.5
                                }
                            }
                        }
                    }
                }
            }
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            implicitWidth: 2
            contentItem: Rectangle {
                implicitWidth: 2
                color: HubTheme.primary
                opacity: 0.35
                radius: 1
            }
        }
    }

    // ── Bottom chapter nav bar ────────────────────────────────────────────────
    Rectangle {
        anchors {
            bottom: parent.bottom; left: parent.left; right: parent.right
            bottomMargin: 3
        }
        height: 40
        z: 9
        visible: Manga.chapterPages.length > 0
        color: Qt.rgba(0.05, 0.05, 0.08, 0.92)

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Prev chapter
            Item {
                Layout.preferredWidth: 100; Layout.fillHeight: true
                opacity: readerView._hasPrevChapter ? 1 : 0.35

                Rectangle {
                    anchors.fill: parent; color: prevBtnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                }
                Row {
                    anchors.centerIn: parent; spacing: 4
                    Text { text: "◀"; font.pixelSize: 9; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: "Prev Ch."
                        font.family: readerView.fontBody; font.pixelSize: 10
                        color: "#ffffff"; font.letterSpacing: 0.5
                    }
                }
                MouseArea {
                    id: prevBtnArea; anchors.fill: parent; hoverEnabled: true
                    enabled: readerView._hasPrevChapter
                    onClicked: readerView.goToPrevChapter()
                }
            }

            // Chapter label
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: {
                    var idx = readerView._currentIdx
                    if (idx < 0) return ""
                    var ch = readerView._chapters[idx]
                    return ch ? "Ch. " + (ch.chapter || "") : ""
                }
                font.family: readerView.fontBody; font.pixelSize: 10
                color: Qt.rgba(1, 1, 1, 0.5); font.letterSpacing: 0.8
                elide: Text.ElideRight
            }

            // Next chapter
            Item {
                Layout.preferredWidth: 100; Layout.fillHeight: true
                opacity: readerView._hasNextChapter ? 1 : 0.35

                Rectangle {
                    anchors.fill: parent; color: nextBtnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                }
                Row {
                    anchors.centerIn: parent; spacing: 4
                    Text {
                        text: "Next Ch."
                        font.family: readerView.fontBody; font.pixelSize: 10
                        color: "#ffffff"; font.letterSpacing: 0.5
                    }
                    Text { text: "▶"; font.pixelSize: 9; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    id: nextBtnArea; anchors.fill: parent; hoverEnabled: true
                    enabled: readerView._hasNextChapter
                    onClicked: readerView.goToNextChapter()
                }
            }
        }

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 1; color: Qt.rgba(1, 1, 1, 0.08)
        }
    }

    // ── Reading progress bar (bottom) ─────────────────────────────────────────
    Item {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: 3
        z: 10
        visible: Manga.chapterPages.length > 0

        // Track
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        // Fill
        Rectangle {
            width: Manga.chapterPages.length > 0
                ? parent.width * (readerView._currentPage / Manga.chapterPages.length)
                : 0
            height: parent.height
            color: HubTheme.primary
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }
    }


}


