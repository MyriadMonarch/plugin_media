pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string _path:
        Quickshell.env("HOME") + "/.local/share/quickshell/mediahub_settings.json"

    // ── Hub theme ──────────────────────────────────────────────────────────────
    property string hubTheme: "auto"     // "auto" | "dark" | "light"

    readonly property var hubThemes: [
        { name: "auto",  label: "Auto",  bg: "#00000000", onBg: "#00000000" },
        { name: "dark",  label: "Dark",  bg: "#1e1e24",   onBg: "#e8e8ee" },
        { name: "light", label: "Light", bg: "#f7f7fa",   onBg: "#1b1b21" }
    ]

    // ── Reading theme ──────────────────────────────────────────────────────────
    property string theme: "dark"          // "dark" | "sepia" | "light"

    readonly property var themes: [
        { name: "dark",  label: "Dark",  bg: "#0e0d0b", onBg: "#e3dac8" },
        { name: "sepia", label: "Sepia", bg: "#f4ecd9", onBg: "#4a3f2f" },
        { name: "light", label: "Light", bg: "#f7f7f7", onBg: "#1c1c1c" }
    ]

    // Chrome (header/footer bars) derived per reader theme
    readonly property color readerChrome: {
        const t = root.themeEntry()
        return t.name === "dark" ? Qt.rgba(0.1, 0.09, 0.08, 0.97)
             : t.name === "sepia" ? Qt.rgba(0.30, 0.26, 0.19, 0.97)
             : Qt.rgba(0.95, 0.95, 0.94, 0.97)
    }

    // Text on chrome bars — adapts so light/sepia chrome stays readable
    readonly property color readerChromeText: {
        const t = root.themeEntry()
        return t.name === "light" ? Qt.color(t.onBg) : "#f4ecd9"
    }

    readonly property color readerChromeHover:
        Qt.rgba(root.readerChromeText.r, root.readerChromeText.g, root.readerChromeText.b, 0.12)
    readonly property color readerChromeDim:
        Qt.rgba(root.readerChromeText.r, root.readerChromeText.g, root.readerChromeText.b, 0.08)

    function themeEntry() {
        for (var i = 0; i < root.themes.length; i++) {
            if (root.themes[i].name === root.theme) return root.themes[i]
        }
        return root.themes[0]
    }

    readonly property color readerBackground: root.themeEntry().bg
    readonly property color readerTextColor:
        root.novelFontColorCustom ? Qt.color(root.novelFontColor) : Qt.color(root.themeEntry().onBg)

    // ── Manga reader ─────────────────────────────────────────────────────────
    property real defaultZoom: 1.0         // 0.3 – 1.0 page scale on open

    // ── Novel reader ─────────────────────────────────────────────────────────
    property int    novelFontSize: 17      // 13 – 26
    property string novelFontColor: "#e3dac8"
    property bool novelFontColorCustom: false
    property string novelFontFamily: "Noto Serif"

    readonly property var fontFamilies: [
        { name: "Noto Serif", label: "Noto Serif" },
        { name: "Noto Sans",  label: "Noto Sans"  },
        { name: "Georgia",    label: "Georgia"    },
        { name: "Times New Roman", label: "Times New Roman" }
    ]

    readonly property var fontColors: [
        "#e3dac8",   // cream
        "#ffffff",   // white
        "#1c1c1c",   // black
        "#4a3f2f",   // sepia ink
        "#8f7a5a",   // soft brown
        "#5c8a5c",   // green
        "#c8a24a",   // gold
        "#7a9ec8"    // steel blue
    ]

    // ── Persistence ────────────────────────────────────────────────────────────
    FileView {
        id: settingsFile
        path: root._path
        onLoaded: {
            try {
                const d = JSON.parse(settingsFile.text())
                if (!d) return
                if (d.theme)           root.theme           = d.theme
                if (d.hubTheme)        root.hubTheme        = d.hubTheme
                if (d.defaultZoom)     root.defaultZoom     = d.defaultZoom
                if (d.novelFontSize)   root.novelFontSize   = d.novelFontSize
                if (d.novelFontColor)  root.novelFontColor  = d.novelFontColor
                if (d.novelFontColorCustom !== undefined) root.novelFontColorCustom = d.novelFontColorCustom
                if (d.novelFontFamily) root.novelFontFamily = d.novelFontFamily
                console.warn("[Settings] Loaded theme=" + root.theme + " entry=" + JSON.stringify(d))
            } catch (e) {
                console.warn("[Settings] Parse error:", e)
            }
        }
    }

    FileView {
        id: settingsWriter
        path: root._path
    }

    function save() {
        console.log("[Settings] save() theme=" + root.theme + " zoom=" + root.defaultZoom + " font=" + root.novelFontSize)
settingsWriter.setText(JSON.stringify({
            hubTheme:          root.hubTheme,
            theme:             root.theme,
            defaultZoom:     root.defaultZoom,
            novelFontSize:   root.novelFontSize,
novelFontColor:   root.novelFontColor,
            novelFontColorCustom: root.novelFontColorCustom,
            novelFontFamily: root.novelFontFamily
        }, null, 2))
        settingsWriter.save()
    }

    Component.onCompleted: settingsFile.reload()
}