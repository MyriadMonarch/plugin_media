import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../services"
import qs.Common

Item {
    id: browseView
    readonly property string fontDisplay: "Noto Serif"
    readonly property string fontBody:    "Noto Sans"

    // Passes the full show object so DetailView can seed itself immediately
    signal animeSelected(var show)

    // ── Background ────────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: Theme.background }

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
                anchors { fill: parent; leftMargin: 18; rightMargin: 10 }
                spacing: 8

                // Wordmark (hidden when search is open)
                Row {
                    spacing: 0
                    visible: !searchBar.visible
                    Layout.fillWidth: true

                    Text {
                        text: "A"
                        font.family: browseView.fontDisplay
                        font.pixelSize: 24; font.letterSpacing: 1
                        color: Theme.primary
                    }
                    Text {
                        text: "nime"
                        font.family: browseView.fontDisplay
                        font.pixelSize: 24; font.letterSpacing: 1
                        color: "#ffffff"; opacity: 0.85
                    }
                }

                // Search bar
                Rectangle {
                    id: searchBar
                    Layout.fillWidth: true
                    height: 36; radius: 18
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
                            leftMargin: 14; rightMargin: 6
                        }
                        color: "#ffffff"
                        font.family: browseView.fontBody
                        font.pixelSize: 13
                        clip: true
                        onTextChanged: searchDebounce.restart()
                        Keys.onEscapePressed: {
                            searchBar.visible = false
                            text = ""
                            Anime.fetchPopular(true)
                        }
                    }

                    Text {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 14 }
                        text: "Search anime…"
                        color: "#ffffff"
                        font.family: browseView.fontBody
                        font.pixelSize: 13
                        visible: searchField.text.length === 0
                        opacity: 0.6
                    }

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
                            font.pixelSize: 9; font.bold: true
                        }
                        MouseArea { anchors.fill: parent; onClicked: searchField.text = "" }
                    }
                }

                Timer {
                    id: searchDebounce
                    interval: 350
                    onTriggered: {
                        if (searchField.text.trim().length > 0)
                            Anime.searchAnime(searchField.text.trim(), true)
                        else
                            Anime.fetchPopular(true)
                    }
                }

                // Search toggle
                Item {
                    width: 38; height: 38

                    Rectangle {
                        anchors.centerIn: parent
                        width: 32; height: 32; radius: 16
                        color: searchBar.visible ? Theme.primaryContainer : "transparent"
                            }
                    Text {
                        anchors.centerIn: parent
                        text: "⌕"; font.pixelSize: 18
                        color: searchBar.visible ? Theme.surfaceText : "#ffffff"
                            }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            searchBar.visible = !searchBar.visible
                            if (searchBar.visible) searchField.forceActiveFocus()
                            else {
                                searchField.text = ""
                                Anime.fetchPopular(true)
                            }
                        }
                    }
                }

                // Combined badge
                Rectangle {
                    height: 28; width: combLabel.implicitWidth + 20; radius: 14
                    color: Theme.surfaceContainer
                    border.color: Theme.outlineVariant; border.width: 1

                    Text {
                        id: combLabel; anchors.centerIn: parent
                        text: "◉ Combined"
                        font.family: browseView.fontBody
                        font.pixelSize: 10; font.letterSpacing: 0.5
                        color: "#ffffff"
                    }
                }

                // Sub / Dub toggle
                Rectangle {
                    height: 28
                    width: modeRow.implicitWidth + 16
                    radius: 14
                    color: Theme.surfaceContainer
                    border.color: Theme.outlineVariant; border.width: 1

                    Row {
                        id: modeRow
                        anchors.centerIn: parent
                        spacing: 0

                        Repeater {
                            model: ["sub", "dub"]

                            
                MouseArea {
                    anchors.fill: parent
                    propagateComposedEvents: true
                    onWheel: {
                        var step = wheel.angleDelta.y * 1.2
                        animeGrid.contentY = Math.max(0, Math.min(animeGrid.contentHeight - animeGrid.height, animeGrid.contentY - step))
                        wheel.accepted = true
                    }
                }
delegate: Item {
                                width: modeText.implicitWidth + 16
                                height: 28
                                readonly property bool active: Anime.currentMode === modelData

                                Rectangle {
                                    anchors { fill: parent; margins: 3 }
                                    radius: 11
                                    color: active ? Theme.primary : "transparent"
                                                    }
                                Text {
                                    id: modeText
                                    anchors.centerIn: parent
                                    text: modelData.toUpperCase()
                                    font.family: browseView.fontBody
                                    font.pixelSize: 10; font.letterSpacing: 1; font.bold: true
                                    color: active ? Theme.onPrimary : "#ffffff"
                                                    }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: Anime.setMode(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Filter chips ──────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 44
            color: Theme.surfaceContainer
            clip: true

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1; color: Theme.outlineVariant; opacity: 0.25
            }

            ListView {
                id: chipList
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                orientation: ListView.Horizontal
                spacing: 7; clip: true
                boundsBehavior: Flickable.StopAtBounds

                model: ListModel {
                    ListElement { label: "Popular"; view: "popular"; country: "ALL" }
                    ListElement { label: "Latest";  view: "latest";  country: "ALL" }
                    ListElement { label: "Japan";   view: "latest";  country: "JP"  }
                    ListElement { label: "China";   view: "latest";  country: "CN"  }
                    ListElement { label: "Korea";   view: "latest";  country: "KR"  }
                }

                delegate: Item {
                    width: chipRect.implicitWidth + 24
                    height: chipList.height

                    readonly property bool active:
                        Anime.currentView === view && Anime.currentCountry === country

                    Rectangle {
                        id: chipRect
                        anchors.centerIn: parent
                        implicitWidth: chipLbl.implicitWidth + 24
                        height: 28; radius: 14
                        color: active ? Theme.primary : Theme.surfaceContainer
                        border.color: active ? Theme.primary : Theme.outlineVariant
                        border.width: 1
        
                        Text {
                            id: chipLbl
                            anchors.centerIn: parent
                            text: label
                            font.family: browseView.fontBody
                            font.pixelSize: 11; font.letterSpacing: 0.5
                            color: active ? Theme.onPrimary : "#ffffff"
                                    }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            searchField.text = ""
                            searchBar.visible = false
                            Anime.currentCountry = country
                            if (view === "popular") Anime.fetchPopular(true)
                            else Anime.fetchLatest(true)
                        }
                    }
                }
            }

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1; color: Theme.outlineVariant; opacity: 0.3
            }
        }

        // ── Content area ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Loading
            Rectangle {
                anchors.fill: parent; color: Theme.background
                visible: Anime.isFetchingAnime && Anime.animeList.length === 0
                z: 10

                Column {
                    anchors.centerIn: parent; spacing: 14

                    Rectangle {
                        width: 34; height: 34; radius: 17
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: "transparent"
                        border.color: Theme.primary; border.width: 2.5
                        RotationAnimator on rotation {
                            from: 0; to: 360; duration: 800
                            loops: Animation.Infinite; running: parent ? parent.visible : false
                            easing.type: Easing.Linear
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "loading"
                        color: "#ffffff"
                        font.family: browseView.fontBody
                        font.pixelSize: 11; font.letterSpacing: 2.5; opacity: 0.7
                    }
                }
            }

            // Error
            Rectangle {
                anchors.fill: parent; color: Theme.background
                visible: Anime.animeError.length > 0 && !Anime.isFetchingAnime
                z: 9

                Column {
                    anchors.centerIn: parent; spacing: 10

                    Text {
                        text: "⚠"; font.pixelSize: 30; color: Theme.error
                        anchors.horizontalCenter: parent.horizontalCenter; opacity: 0.8
                    }
                    Text {
                        text: Anime.animeError
                        color: "#ffffff"; font.pixelSize: 12
                        font.family: browseView.fontBody
                        wrapMode: Text.Wrap; width: 260
                        horizontalAlignment: Text.AlignHCenter; lineHeight: 1.4
                    }
                }
            }

            // Grid
            GridView {
                id: animeGrid
                property real savedContentY: 0
                anchors.fill: parent; anchors.margins: 10
                readonly property int cols: Math.max(4, Math.floor(width / 190))
                cellWidth: width / cols
                cellHeight: cellWidth * 1.58
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 500
                model: Anime.animeList

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                implicitWidth: 3
                    contentItem: Rectangle {
                        implicitWidth: 3; color: Theme.primary; opacity: 0.45; radius: 2
                    }
                }

                onContentYChanged: {
                    if (contentY + height > contentHeight - cellHeight * 2) {
                        savedContentY = contentY
                        Anime.fetchNextPage()
                    }
                }

                
                MouseArea {
                    anchors.fill: parent
                    propagateComposedEvents: true
                    onWheel: {
                        var step = wheel.angleDelta.y * 1.2
                        animeGrid.contentY = Math.max(0, Math.min(animeGrid.contentHeight - animeGrid.height, animeGrid.contentY - step))
                        wheel.accepted = true
                    }
                }
                delegate: Item {
                    width: animeGrid.cellWidth
                    height: animeGrid.cellHeight

                    Rectangle {
                        id: card
                        anchors { fill: parent; margins: 5 }
                        radius: 12; color: Theme.surfaceContainer

                        // Cover
                        Image {
                            id: coverImg
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            height: parent.height - titleBar.height
                            source: modelData.thumbnail || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true; cache: true
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 300 } }

                            Rectangle {
                                anchors.fill: parent; color: Theme.surfaceContainerHigh
                                visible: coverImg.status !== Image.Ready
                                Text {
                                    anchors.centerIn: parent; text: "◫"
                                    font.pixelSize: 32; color: Theme.outline; opacity: 0.25
                                }
                            }

                            // Score badge
                            Rectangle {
                                visible: modelData.score !== null && modelData.score !== undefined
                                anchors { top: parent.top; left: parent.left; topMargin: 8; leftMargin: 8 }
                                height: 20; radius: 10
                                width: scoreText.implicitWidth + 12
                                color: Qt.rgba(0, 0, 0, 0.72)

                                Text {
                                    id: scoreText; anchors.centerIn: parent
                                    text: modelData.score !== null
                                        ? "★ " + (modelData.score || 0).toFixed(1) : ""
                                    font.family: browseView.fontBody
                                    font.pixelSize: 8; font.bold: true; font.letterSpacing: 0.5
                                    color: "#f5c518"
                                }
                            }

                            // Type badge
                            Rectangle {
                                visible: modelData.type && modelData.type.length > 0
                                anchors { top: parent.top; right: parent.right; topMargin: 8; rightMargin: 8 }
                                height: 20; radius: 10
                                width: typeText.implicitWidth + 12
                                color: Qt.rgba(0, 0, 0, 0.7)

                                Text {
                                    id: typeText; anchors.centerIn: parent
                                    text: (modelData.type || "").toUpperCase()
                                    font.family: browseView.fontBody
                                    font.pixelSize: 8; font.letterSpacing: 1; font.bold: true
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.7)
                                }
                            }

                            // Episode count badge (bottom-right of cover)
                            Rectangle {
                                visible: modelData.availableEpisodes
                                    && (modelData.availableEpisodes.sub > 0
                                        || modelData.availableEpisodes.dub > 0)
                                anchors {
                                    bottom: parent.bottom; right: parent.right
                                    bottomMargin: 8; rightMargin: 8
                                }
                                height: 20; radius: 10
                                width: epText.implicitWidth + 12
                                color: Qt.rgba(0, 0, 0, 0.72)

                                Text {
                                    id: epText; anchors.centerIn: parent
                                    text: {
                                        var avail = modelData.availableEpisodes
                                        var n = Anime.currentMode === "dub"
                                            ? avail.dub : avail.sub
                                        return n + " ep"
                                    }
                                    font.family: browseView.fontBody
                                    font.pixelSize: 8; font.letterSpacing: 0.5
                                    color: Qt.rgba(1, 1, 1, 0.85)
                                }
                            }

                            // Gradient

                        }

                        // Title bar
                        Rectangle {
                            id: titleBar
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: titleText.implicitHeight + 16
                            color: Theme.surfaceContainer; radius: 12

                            Text {
                                id: titleText
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 10; rightMargin: 10
                                }
                                text: modelData.englishName || modelData.name || ""
                                font.family: browseView.fontBody
                                font.pixelSize: 11; font.letterSpacing: 0.2
                                color: "#ffffff"
                                wrapMode: Text.Wrap; maximumLineCount: 2
                                elide: Text.ElideRight; lineHeight: 1.3
                            }
                        }

                        // Library bookmark dot
                        Rectangle {
                            visible: Anime.isInLibrary(modelData.id)
                            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 6 }
                            width: 7; height: 7; radius: 4
                            color: Theme.primary
                            opacity: 0.9
                        }

                        Rectangle {
                            anchors.fill: parent; radius: 12; color: Theme.primary
                            opacity: cardArea.pressed ? 0.16 : (cardArea.containsMouse ? 0.07 : 0)
                            Behavior on opacity { NumberAnimation { duration: 130 } }
                        }

                        transform: Scale {
                            origin.x: card.width / 2; origin.y: card.height / 2
                            xScale: cardArea.pressed ? 0.97 : 1.0
                            yScale: cardArea.pressed ? 0.97 : 1.0
                            Behavior on xScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Behavior on yScale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            id: cardArea
                            anchors.fill: parent; hoverEnabled: true
                            onClicked: browseView.animeSelected(modelData)
                        }
                    }
                }
                Connections {
                    target: Anime
                    function onIsFetchingAnimeChanged() {
                        if (!Anime.isFetchingAnime && animeGrid.savedContentY > 0) {
                            animeGrid.contentY = animeGrid.savedContentY
                            animeGrid.savedContentY = 0
                        }
                    }
                }
            }
        }
    }
}
