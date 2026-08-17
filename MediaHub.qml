import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets
import "services"
Item {
    id: root

    Component.onCompleted: console.warn("[MediaHub] plugin component instantiated")

    property var pluginService: null
    property string pluginId: "mediaHub"

    function toggle() {
        if (variants.instances.length > 0) {
            variants.instances[0].toggle()
        }
    }

    Variants {
        id: variants
        model: Quickshell.screens

        delegate: Item {
            id: screenDelegate
            required property var modelData

            readonly property bool useOverlayLayer:
                CompositorService.framePeerSurfacesUseOverlayForScreen(modelData)

            function toggle() {
                slideout.toggle()
            }

            // Click-outside-to-close: a transparent full-screen layer surface stacked
            // BELOW the slideout (declared first → created first → lower in the same
            // layer). Clicks on the slideout area hit the slideout (topmost there);
            // clicks anywhere else land here and close it. Disabled while expanded
            // (the slideout then covers the whole screen).
            PanelWindow {
                id: dismissCatcher
                screen: screenDelegate.modelData
                visible: slideout.isVisible && !slideout.expandedWidth
                color: "transparent"
                WlrLayershell.namespace: "dms:mediahub-dismiss"
                WlrLayershell.layer:
                    screenDelegate.useOverlayLayer ? WlrLayershell.Overlay : WlrLayershell.Top
                WlrLayershell.exclusiveZone: 0
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: slideout.hide()
                }
            }

            DankSlideout {
                id: slideout
                modelData: screenDelegate.modelData
                title: ""
                slideoutWidth: Math.round(modelData.width * 0.35)
                expandable: true
                expandedWidthValue: modelData.width
                customTransparency: 1.0

                content: Content {
                    isExpanded: Qt.binding(function() { return slideout.expandedWidth })
                    onHideRequested: slideout.hide()
                    onExpandRequested: slideout.expandedWidth = !slideout.expandedWidth
                }

                Component.onCompleted: {
                    container.anchors.leftMargin = 0
                    container.anchors.rightMargin = 0
                    container.anchors.bottomMargin = 0
                    container.anchors.topMargin = 0

                    Anime.isExpanded = Qt.binding(function() { return slideout.expandedWidth })
                    Manga.isExpanded = Qt.binding(function() { return slideout.expandedWidth })
                    Novel.isExpanded = Qt.binding(function() { return slideout.expandedWidth })
                }
            }
        }
    }
}