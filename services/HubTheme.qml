pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

// Hub-level theme. "auto" follows the DMS shell theme; "dark"/"light" override
// the whole media hub palette independently of the shell.
Singleton {
    id: root

    property string mode: Settings.hubTheme // "auto" | "dark" | "light"

    onModeChanged: console.warn("[HubTheme] mode=" + root.mode
        + " bg=" + root.background + " surface=" + root.surfaceContainer
        + " text=" + root.surfaceText + " primary=" + root.primary)

    function _pal(p, l, d) {
        return root.mode === "light" ? l : (root.mode === "dark" ? d : p)
    }

    // ── Accent ────────────────────────────────────────────────────────────
    property color primary:      _pal(Theme.primary, Qt.darker(Theme.primary, 1.45), Theme.primary)
    property color onPrimary:    _pal(Theme.onPrimary, "#ffffff", Theme.onPrimary)
    property color primaryContainer: _pal(Theme.primaryContainer,
        "#e0ddff",
        Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.28))
    property color primaryHover: Qt.rgba(root.primary.r, root.primary.g, root.primary.b, 0.12)
    property color secondary:    _pal(Theme.secondary, "#6a5ab5", Theme.secondary)

    // ── Surfaces ──────────────────────────────────────────────────────────
    property color background:        _pal(Theme.background, "#f7f7fa", "#0f0f13")
    property color surface:           _pal(Theme.surface, "#ffffff", "#17171c")
    property color surfaceContainer:  _pal(Theme.surfaceContainer, "#efeff4", "#1e1e24")
    property color surfaceContainerHigh:    _pal(Theme.surfaceContainerHigh, "#e7e7ee", "#26262e")
    property color surfaceContainerHighest: _pal(Theme.surfaceContainerHighest, "#dddee6", "#33333c")

    // ── Text ──────────────────────────────────────────────────────────────
    property color surfaceText:       _pal(Theme.surfaceText, "#1b1b21", "#e8e8ee")
    property color surfaceVariantText: _pal(Theme.surfaceVariantText, "#5d5d68", "#a8a8b4")

    // ── Lines & status ────────────────────────────────────────────────────
    property color outline:        _pal(Theme.outline, "#757580", "#71717e")
    property color outlineVariant: _pal(Theme.outlineVariant, "#c9c9d3", "#45454f")
    property color error:          _pal(Theme.error, "#b3261e", "#f2b8b5")

    // ── Typography scale ──────────────────────────────────────────────────
    property real fontSizeMedium: Theme.fontSizeMedium
    property real fontSizeLarge:  Theme.fontSizeLarge
}