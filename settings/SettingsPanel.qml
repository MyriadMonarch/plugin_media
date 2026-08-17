import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services"
import qs.Common

Item {
    id: settingsView

    readonly property string fontBody: "Noto Sans"

    Rectangle { anchors.fill: parent; color: HubTheme.background }

    Flickable {
        anchors.fill: parent
        contentHeight: settingsColumn.implicitHeight + 48
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 500

        Column {
            id: settingsColumn
            width: parent.width
            spacing: 26
            topPadding: 22

            // ── Page title ──────────────────────────────────────────────────
            Row {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 22; anchors.rightMargin: 22
                spacing: 8

                Text {
                    text: "⚙"
                    font.pixelSize: 22
                    color: HubTheme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Settings"
                    font.family: settingsView.fontBody
                    font.pixelSize: 20; font.weight: Font.Bold
                    font.letterSpacing: 0.5
                    color: HubTheme.surfaceText
                }
            }

            // ── Media hub theme ─────────────────────────────────────────────
            Row {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 22; anchors.rightMargin: 22
                spacing: 10

                Rectangle {
                    width: 3; height: 11; radius: 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: HubTheme.primary; opacity: 0.8
                }
                Text {
                    text: "MEDIA HUB THEME"
                    font.family: settingsView.fontBody
                    font.pixelSize: 10; font.bold: true
                    font.letterSpacing: 1.2
                    color: HubTheme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 22; anchors.rightMargin: 22
                spacing: 10

                Repeater {
                    model: Settings.hubThemes

                    delegate: Item {
                        width: (parent.width - 20) / 3
                        height: 74

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: Settings.hubTheme === modelData.name
                                ? HubTheme.primaryContainer
                                : HubTheme.surfaceContainer
                            border.color: Settings.hubTheme === modelData.name
                                ? HubTheme.primary : HubTheme.outlineVariant
                            border.width: Settings.hubTheme === modelData.name ? 1.5 : 1
                            Behavior on color { ColorAnimation { duration: 160 } }
                            Behavior on border.color { ColorAnimation { duration: 160 } }

                            Column {
                                anchors.centerIn: parent
                                spacing: 8

                                Item {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 34; height: 22

                                    Rectangle {
                                        anchors.fill: parent; radius: 4
                                        border.color: Qt.rgba(0, 0, 0, 0.15); border.width: 1
                                        visible: modelData.name !== "auto"
                                        color: modelData.bg
                                    }

                                    Row {
                                        anchors.fill: parent
                                        visible: modelData.name === "auto"
                                        Rectangle {
                                            width: parent.width / 2; height: parent.height
                                            radius: 4; border.color: Qt.rgba(0, 0, 0, 0.15); border.width: 1
                                            color: "#1e1e24"
                                        }
                                        Rectangle {
                                            width: parent.width / 2; height: parent.height
                                            radius: 4; border.color: Qt.rgba(0, 0, 0, 0.15); border.width: 1
                                            color: "#f7f7fa"
                                        }
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.label.toUpperCase()
                                    font.family: settingsView.fontBody
                                    font.pixelSize: 9; font.letterSpacing: 1
                                    color: Settings.hubTheme === modelData.name
                                        ? HubTheme.surfaceText : HubTheme.surfaceVariantText
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                Settings.hubTheme = modelData.name
                                Settings.save()
                            }
                        }
                    }
                }
            }

            Text {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 22; anchors.rightMargin: 22
                text: "Changes the whole media hub look. Auto follows the shell theme."
                font.family: settingsView.fontBody; font.pixelSize: 10
                color: HubTheme.surfaceVariantText; opacity: 0.7
                wrapMode: Text.WordWrap
            }

            // ── Reader theme ────────────────────────────────────────────────
            Row {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 22; anchors.rightMargin: 22
                spacing: 10

                Rectangle {
                    width: 3; height: 11; radius: 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: HubTheme.primary; opacity: 0.8
                }
                Text {
                    text: "READER THEME"
                    font.family: settingsView.fontBody
                    font.pixelSize: 10; font.bold: true
                    font.letterSpacing: 1.2
                    color: HubTheme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 22; anchors.rightMargin: 22
                spacing: 10

                Repeater {
                    model: Settings.themes

                    delegate: Item {
                        width: (parent.width - 20) / 3
                        height: 74

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: Settings.theme === modelData.name
                                ? HubTheme.primaryContainer
                                : HubTheme.surfaceContainer
                            border.color: Settings.theme === modelData.name
                                ? HubTheme.primary : HubTheme.outlineVariant
                            border.width: Settings.theme === modelData.name ? 1.5 : 1
                            Behavior on color { ColorAnimation { duration: 160 } }
                            Behavior on border.color { ColorAnimation { duration: 160 } }

                            Column {
                                anchors.centerIn: parent
                                spacing: 8

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 34; height: 22; radius: 4
                                    border.color: Qt.rgba(0, 0, 0, 0.15); border.width: 1
                                    color: modelData.bg

                                    Rectangle {
                                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                        height: 5
                                        color: Qt.rgba(0.5, 0.5, 0.5, 0.25)
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.label.toUpperCase()
                                    font.family: settingsView.fontBody
                                    font.pixelSize: 9; font.letterSpacing: 1
                                    color: Settings.theme === modelData.name
                                        ? HubTheme.surfaceText : HubTheme.surfaceVariantText
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    Settings.theme = modelData.name
                                    Settings.save()
                                }
                            }
                        }
                    }
                }
            }

            Text {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 22; anchors.rightMargin: 22
                text: "Applies to manga and novel readers."
                font.family: settingsView.fontBody; font.pixelSize: 10
                color: HubTheme.surfaceVariantText; opacity: 0.7
            }

            // ── Manga: default zoom ─────────────────────────────────────────
            Row {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 22; anchors.rightMargin: 22
                spacing: 10

                Rectangle {
                    width: 3; height: 11; radius: 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: HubTheme.primary; opacity: 0.8
                }
                Text {
                    text: "MANGA"
                    font.family: settingsView.fontBody
                    font.pixelSize: 10; font.bold: true
                    font.letterSpacing: 1.2
                    color: HubTheme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Column {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 22; anchors.rightMargin: 22
                spacing: 10

                Row {
                    width: parent.width
                    Text {
                        width: 140
                        text: "Default zoom"
                        font.family: settingsView.fontBody; font.pixelSize: 12
                        color: HubTheme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Slider {
                        id: zoomSlider
                        width: parent.width - 140 - 58
                        from: 0.3; to: 1.0; stepSize: 0.05
                        value: Settings.defaultZoom
                        onMoved: {
                            Settings.defaultZoom = zoomSlider.value
                            Settings.save()
                        }

                        background: Rectangle {
                            x: zoomSlider.leftPadding
                            y: zoomSlider.topPadding + zoomSlider.availableHeight / 2 - 2
                            width: zoomSlider.availableWidth
                            height: 4; radius: 2
                            color: HubTheme.surfaceContainerHighest

                            Rectangle {
                                width: zoomSlider.visualPosition * parent.width
                                height: parent.height; radius: 2
                                color: HubTheme.primary
                            }
                        }
                        handle: Rectangle {
                            x: zoomSlider.leftPadding + zoomSlider.visualPosition * (zoomSlider.availableWidth - width)
                            y: zoomSlider.topPadding + zoomSlider.availableHeight / 2 - height / 2
                            width: 14; height: 14; radius: 7
                            color: HubTheme.primary
                            border.color: HubTheme.onPrimary; border.width: 2
                        }
                    }
                    Text {
                        width: 58
                        text: Math.round(Settings.defaultZoom * 100) + "%"
                        font.family: settingsView.fontBody; font.pixelSize: 11
                        color: HubTheme.surfaceVariantText
                        horizontalAlignment: Text.AlignRight
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    width: parent.width
                    text: "Starting scale for manga pages."
                    font.family: settingsView.fontBody; font.pixelSize: 10
                    color: HubTheme.surfaceVariantText; opacity: 0.7
                    wrapMode: Text.Wrap
                }
            }

            // ── Novel: font ─────────────────────────────────────────────────
            Row {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 22; anchors.rightMargin: 22
                spacing: 10

                Rectangle {
                    width: 3; height: 11; radius: 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: HubTheme.primary; opacity: 0.8
                }
                Text {
                    text: "NOVEL"
                    font.family: settingsView.fontBody
                    font.pixelSize: 10; font.bold: true
                    font.letterSpacing: 1.2
                    color: HubTheme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Column {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 22; anchors.rightMargin: 22
                spacing: 18

                // Font size
                Row {
                    width: parent.width
                    Text {
                        width: 140
                        text: "Font size"
                        font.family: settingsView.fontBody; font.pixelSize: 12
                        color: HubTheme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Slider {
                        id: fsSlider
                        width: parent.width - 140 - 58
                        from: 13; to: 26; stepSize: 1
                        value: Settings.novelFontSize
                        onMoved: {
                            Settings.novelFontSize = fsSlider.value
                            Settings.save()
                        }

                        background: Rectangle {
                            x: fsSlider.leftPadding
                            y: fsSlider.topPadding + fsSlider.availableHeight / 2 - 2
                            width: fsSlider.availableWidth
                            height: 4; radius: 2
                            color: HubTheme.surfaceContainerHighest

                            Rectangle {
                                width: fsSlider.visualPosition * parent.width
                                height: parent.height; radius: 2
                                color: HubTheme.primary
                            }
                        }
                        handle: Rectangle {
                            x: fsSlider.leftPadding + fsSlider.visualPosition * (fsSlider.availableWidth - width)
                            y: fsSlider.topPadding + fsSlider.availableHeight / 2 - height / 2
                            width: 14; height: 14; radius: 7
                            color: HubTheme.primary
                            border.color: HubTheme.onPrimary; border.width: 2
                        }
                    }
                    Text {
                        width: 58
                        text: Settings.novelFontSize + " px"
                        font.family: settingsView.fontBody; font.pixelSize: 11
                        color: HubTheme.surfaceVariantText
                        horizontalAlignment: Text.AlignRight
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Font family
                Column {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "Font family"
                        font.family: settingsView.fontBody; font.pixelSize: 12
                        color: HubTheme.surfaceText
                    }

                    Row {
                        width: parent.width
                        spacing: 6
                        Repeater {
                            model: Settings.fontFamilies

                            delegate: Item {
                                width: (parent.width - 18) / 4
                                height: 40

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: Settings.novelFontFamily === modelData.name
                                        ? HubTheme.primaryContainer : HubTheme.surfaceContainer
                                    border.color: Settings.novelFontFamily === modelData.name
                                        ? HubTheme.primary : HubTheme.outlineVariant
                                    border.width: Settings.novelFontFamily === modelData.name ? 1.5 : 1
                                    Behavior on color { ColorAnimation { duration: 160 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.family: modelData.name
                                        font.pixelSize: 11
                                        color: HubTheme.surfaceText
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        Settings.novelFontFamily = modelData.name
                                        Settings.save()
                                    }
                                }
                            }
                        }
                    }
                }

                // Font colour swatches
                Column {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "Font colour"
                        font.family: settingsView.fontBody; font.pixelSize: 12
                        color: HubTheme.surfaceText
                    }

                    Flow {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: Settings.fontColors

                            delegate: Item {
                                width: 30; height: 30

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 15
                                    color: modelData

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 15
                                        color: "transparent"
                                        border.color: Settings.novelFontColor === modelData
                                            ? HubTheme.primary : Qt.rgba(0, 0, 0, 0.25)
                                        border.width: Settings.novelFontColor === modelData ? 3 : 1
                                        Behavior on border.color { ColorAnimation { duration: 140 } }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        Settings.novelFontColorCustom = true
                                        Settings.novelFontColor = modelData
                                        Settings.save()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 8 }
        }
    }
}