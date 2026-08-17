import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../services"
import Quickshell.Io
import qs.Common

Item {
    id: detailView
    readonly property string fontDisplay: "Noto Serif"
    readonly property string fontBody:    "Noto Sans"

    signal backRequested()

    readonly property bool _inLibrary:
        Anime.currentAnime ? Anime.isInLibrary(Anime.currentAnime.id) : false

    // ── MPV launcher ──────────────────────────────────────────────────────────
    Process {
        id: mpvProcess
    }

    function _playWithMpv(url, referer, title) {
        if (!url || url.length === 0) {
            console.warn("[AnimeDetail] _playWithMpv called with empty URL, aborting")
            return
        }

        mpvProcess.running = false

        var ytdlPath = Anime._scriptDir + "/../.venv/bin/yt-dlp"
        var args = [
            "mpv",
            "--fs",
            "--force-window=yes",
            "--title=" + (title || "Anime"),
            "--no-terminal",
            "--script-opts=ytdl_hook-ytdl_path=" + ytdlPath
        ]

        if (referer && referer.length > 0)
            args.push("--referrer=" + referer)

        args.push(url)
        mpvProcess.command = args
        mpvProcess.running = true
    }

    Rectangle { anchors.fill: parent; color: HubTheme.background }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            height: 52
            color: HubTheme.surfaceContainer
            z: 2

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: HubTheme.outlineVariant; opacity: 0.5
            }

            RowLayout {
                anchors { fill: parent; leftMargin: 6; rightMargin: 10 }
                spacing: 2

                // Back
                Item {
                    width: 44; height: 44

                    Rectangle {
                        anchors.centerIn: parent; width: 34; height: 34; radius: 17
                        color: backArea.containsMouse ? HubTheme.surfaceContainer : "transparent"
                            }
                    Text {
                        anchors.centerIn: parent
                        text: "←"; font.pixelSize: 18; color: HubTheme.surfaceText
                    }
                    MouseArea {
                        id: backArea; anchors.fill: parent; hoverEnabled: true
                        onClicked: detailView.backRequested()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: Anime.currentAnime
                        ? (Anime.currentAnime.englishName || Anime.currentAnime.name || "")
                        : ""
                    font.family: detailView.fontDisplay
                    font.pixelSize: 14; color: HubTheme.surfaceText; elide: Text.ElideRight
                }

                Item {
                    visible: Anime.currentAnime !== null
                    width: libBtnLabel.implicitWidth + 28; height: 32

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
                            color: detailView._inLibrary
                                ? HubTheme.surfaceText : HubTheme.surfaceText
                                    }
                        Text {
                            id: libBtnLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Library"
                            font.family: detailView.fontBody
                            font.pixelSize: 11; font.letterSpacing: 0.3
                            color: detailView._inLibrary
                                ? HubTheme.surfaceText : HubTheme.surfaceText
                                    }
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            if (detailView._inLibrary)
                                Anime.removeFromLibrary(Anime.currentAnime.id)
                            else
                                Anime.addToLibrary(Anime.currentAnime)
                        }
                    }
                }
            }
        }

        // ── Hero banner ─────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Anime.currentAnime !== null ? 160 : 0
            clip: true
            visible: Anime.currentAnime !== null
                && Anime.currentAnime.description
                && Anime.currentAnime.description.length > 0
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            // Blurred cover background
            Image {
                anchors.fill: parent
                source: Anime.currentAnime ? Anime.currentAnime.thumbnail : ""
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
                        source: Anime.currentAnime ? Anime.currentAnime.thumbnail : ""
                        fillMode: Image.PreserveAspectCrop; asynchronous: true
                    }
                    Rectangle {
                        anchors.fill: parent; radius: 8; color: "transparent"
                        border.color: HubTheme.outlineVariant; border.width: 1
                    }
                }

                // Description text (scrollable)
                Flickable {
                    width: parent.width - 104; height: parent.height
                    clip: true
                    contentHeight: descText.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded; width: 4; anchors.right: parent.right
                        background: Rectangle { color: "transparent" }
                        contentItem: Rectangle {
                            radius: 2; color: HubTheme.outlineVariant
                        }
                    }

                    Text {
                        id: descText
                        width: parent.width - 8
                        text: Anime.currentAnime ? Anime.currentAnime.description : ""
                        font.family: detailView.fontBody; font.pixelSize: 11
                        color: HubTheme.surfaceText; wrapMode: Text.Wrap
                        opacity: 0.8; lineHeight: 1.35
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: HubTheme.outlineVariant; opacity: 0.35
            }
        }

        Rectangle {
            Layout.fillWidth: true; height: 34
            color: HubTheme.surfaceContainer
            visible: Anime.currentAnime !== null

            RowLayout {
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }

                Text {
                    text: Anime.currentAnime
                        ? (Anime.currentAnime.episodes
                        ? Anime.currentAnime.episodes.length : 0) + " episodes"
                        : ""
                    font.family: detailView.fontBody
                    font.pixelSize: 11; font.letterSpacing: 1
                    color: HubTheme.surfaceVariantText
                }

                Item { Layout.fillWidth: true }

                // Last-watched badge
                Rectangle {
                    readonly property var _entry: Anime.currentAnime
                        ? Anime.getLibraryEntry(Anime.currentAnime.id) : null
                    visible: _entry !== null && _entry !== undefined
                        && _entry.lastWatchedEpNum !== ""
                        && _entry.lastWatchedEpNum !== undefined
                    height: 20; width: lastWatchedText.implicitWidth + 18; radius: 10
                    color: Qt.rgba(HubTheme.primary.r, HubTheme.primary.g, HubTheme.primary.b, 0.12)
                    border.color: HubTheme.primary; border.width: 1

                    Text {
                        id: lastWatchedText; anchors.centerIn: parent
                        text: {
                            var e = Anime.currentAnime
                                ? Anime.getLibraryEntry(Anime.currentAnime.id) : null
                            return e ? "Last: Ep. " + e.lastWatchedEpNum : ""
                        }
                        font.family: detailView.fontBody
                        font.pixelSize: 9; font.letterSpacing: 0.8; color: HubTheme.primary
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: HubTheme.outlineVariant; opacity: 0.3
            }
        }

        Item {
            Layout.fillWidth: true; Layout.fillHeight: true

            Rectangle {
                anchors.fill: parent; color: HubTheme.background
                visible: Anime.isFetchingDetail; z: 5

                Column {
                    anchors.centerIn: parent; spacing: 14

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "transparent"; border.color: HubTheme.primary; border.width: 2
                        RotationAnimator on rotation {
                            from: 0; to: 360; duration: 800
                            loops: Animation.Infinite; running: parent ? parent.visible : false
                            easing.type: Easing.Linear
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "fetching episodes"
                        color: HubTheme.surfaceVariantText
                        font.family: detailView.fontBody
                        font.pixelSize: 11; font.letterSpacing: 2; opacity: 0.7
                    }
                }
            }

            Rectangle {
                anchors.fill: parent; color: Qt.rgba(HubTheme.background.r, HubTheme.background.g, HubTheme.background.b, 0.88)
                visible: Anime.isFetchingLinks; z: 6

                Column {
                    anchors.centerIn: parent; spacing: 14

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "transparent"; border.color: HubTheme.primary; border.width: 2
                        RotationAnimator on rotation {
                            from: 0; to: 360; duration: 800
                            loops: Animation.Infinite; running: parent ? parent.visible : false
                            easing.type: Easing.Linear
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "fetching stream"
                        color: HubTheme.surfaceVariantText
                        font.family: detailView.fontBody
                        font.pixelSize: 11; font.letterSpacing: 2; opacity: 0.7
                    }
                }
            }

            // Links error toast
            Rectangle {
                id: linksErrorToast
                anchors {
                    bottom: parent.bottom; horizontalCenter: parent.horizontalCenter
                    bottomMargin: 12
                }
                height: 36; radius: 18
                width: linksErrText.implicitWidth + 28
                color: Qt.rgba(HubTheme.error.r, HubTheme.error.g, HubTheme.error.b, 0.2)
                visible: Anime.linksError.length > 0 && !Anime.isFetchingLinks
                z: 7

                Text {
                    id: linksErrText; anchors.centerIn: parent
                    text: Anime.linksError
                    font.family: detailView.fontBody
                    font.pixelSize: 11; color: HubTheme.error; elide: Text.ElideRight
                }
            }

            // Episodes empty state
            Column {
                anchors.centerIn: parent
                visible: !Anime.isFetchingDetail && Anime.currentAnime
                    && Anime.currentAnime.episodes && Anime.currentAnime.episodes.length === 0
                spacing: 8

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "⚠"
                    font.pixelSize: 20; opacity: 0.5
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No episodes available"
                    color: HubTheme.surfaceVariantText; font.family: detailView.fontBody
                    font.pixelSize: 12; opacity: 0.5
                }
            }

            ListView {
                id: epList
                anchors.fill: parent; clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: Anime.currentAnime ? Anime.currentAnime.episodes : []

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                implicitWidth: 3
                    contentItem: Rectangle {
                        implicitWidth: 3; color: HubTheme.primary; opacity: 0.45; radius: 2
                    }
                }

                delegate: Rectangle {
                    width: epList.width; height: 52

                    readonly property var _libEntry: Anime.currentAnime
                        ? Anime.getLibraryEntry(Anime.currentAnime.id) : null
                    readonly property bool isLastWatched:
                        _libEntry !== null && _libEntry !== undefined
                        && _libEntry.lastWatchedEpNum === String(modelData.number)

                    color: isLastWatched
                        ? HubTheme.primaryHover
                        : (epRowArea.pressed
                            ? HubTheme.surfaceContainerHigh
                            : (epRowArea.containsMouse ? HubTheme.surfaceContainer : "transparent"))
    
                    Rectangle {
                        anchors {
                            bottom: parent.bottom
                            left: parent.left; right: parent.right
                            leftMargin: 64; rightMargin: 16
                        }
                        height: 1; color: HubTheme.outlineVariant; opacity: 0.22
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                        spacing: 14

                        Rectangle {
                            width: epPillText.implicitWidth + 16; height: 26; radius: 13
                            color: isLastWatched ? HubTheme.primary : HubTheme.primaryContainer

                            Text {
                                id: epPillText; anchors.centerIn: parent
                                text: "Ep." + (modelData.number || "?")
                                font.family: detailView.fontBody
                                font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.5
                                color: isLastWatched ? HubTheme.onPrimary : HubTheme.surfaceText
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Episode " + (modelData.number || "")
                            font.family: detailView.fontBody
                            font.pixelSize: 12; color: HubTheme.surfaceText; elide: Text.ElideRight
                        }

                        // Play icon
                        Text {
                            text: "▶"; font.pixelSize: 13
                            color: epRowArea.containsMouse ? HubTheme.primary : HubTheme.outline
                            opacity: epRowArea.containsMouse ? 0.9 : 0.35
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                            Behavior on color   { ColorAnimation  { duration: 120 } }
                        }
                    }

                    MouseArea {
                        id: epRowArea; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            if (!Anime.currentAnime) return

                            Anime.fetchStreamLinks(
                                Anime.currentAnime.id,
                                modelData.number,
                                "best"
                            )

                            if (Anime.isInLibrary(Anime.currentAnime.id)) {
                                Anime.updateLastWatched(
                                    Anime.currentAnime.id,
                                    modelData.id,
                                    modelData.number
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: Anime
        function onSelectedLinkChanged() {
            if (!Anime.selectedLink) return
            var lnk = Anime.selectedLink
            if (lnk.error) {
                console.warn("[AnimeDetail] selectedLink has error:", lnk.error)
                Anime.clearStreamLinks()
                return
            }
            if (!lnk.url || lnk.url.length === 0) {
                console.warn("[AnimeDetail] selectedLink has no URL, aborting playback")
                Anime.clearStreamLinks()
                return
            }

            var title = Anime.currentAnime
                ? (Anime.currentAnime.englishName || Anime.currentAnime.name)
                + " — Ep." + Anime.currentEpisode
                : ""
            detailView._playWithMpv(lnk.url, lnk.referer, title)
            Anime.clearStreamLinks()
        }
    }
}
