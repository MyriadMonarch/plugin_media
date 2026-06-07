import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import "services"
Item {
    id: root

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

        delegate: DankSlideout {
            id: slideout
            title: "Media Hub"
            slideoutWidth: Math.round(modelData.width * 0.35)
            expandable: true
            expandedWidthValue: modelData.width
            customTransparency: 1.0

            content: Content {
                isExpanded: Qt.binding(function() { return slideout.expandedWidth })
                onHideRequested: slideout.hide()
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
