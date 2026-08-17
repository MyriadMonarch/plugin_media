pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string apiUrl: "http://127.0.0.1:5150"

    // ── Manga list ───────────────────────────────────────────────────────────
    property list<var> mangaList: []
    property bool isFetchingManga: false
    property string mangaError: ""
    property bool hasMoreManga: false
    property int currentOffset: 0
    property int latestPage: 1
    property string currentSearchText: ""
    property string currentOrigin: ""

    // ── Manga detail ─────────────────────────────────────────────────────────
    property var currentManga: null
    property bool isFetchingDetail: false
    property string detailError: ""

    // ── Chapter pages ────────────────────────────────────────────────────────
    property list<var> chapterPages: []
    property bool isFetchingPages: false
    property string pagesError: ""
    property string currentChapterId: ""

    // ── Library ──────────────────────────────────────────────────────────────
    // Each entry: { id, title, coverUrl, lastReadChapterId, lastReadChapterNum, addedAt }
    property list<var> libraryList: []
    property bool libraryLoaded: false

    readonly property string _libraryPath:
        Quickshell.env("HOME") + "/.local/share/quickshell/manga_library.json"

    // FileView for reading
    FileView {
        id: libraryFile
        path: root._libraryPath
        onLoaded: {
            try {
                var data = JSON.parse(libraryFile.text())
                root.libraryList = Array.isArray(data) ? data : []
            } catch (e) {
                console.warn("[ServiceManga] library parse error:", e)
                root.libraryList = []
            }
            root.libraryLoaded = true
            console.log("[ServiceManga] Library loaded —", root.libraryList.length, "entries")
        }
        onLoadFailed: {
            // File doesn't exist yet — start empty
            root.libraryList = []
            root.libraryLoaded = true
            console.log("[ServiceManga] No library file found, starting fresh")
        }
    }

    // FileView for writing
    FileView {
        id: libraryWriter
        path: root._libraryPath
    }

    function _saveLibrary() {
        libraryWriter.setText(JSON.stringify(root.libraryList, null, 2))
        libraryWriter.save()
    }

    function addToLibrary(manga) {
        // manga must have: id, title, coverUrl
        if (isInLibrary(manga.id)) return
        var entry = {
            id:                  manga.id,
            title:               manga.title,
            coverUrl:            manga.coverUrl,
            lastReadChapterId:   "",
            lastReadChapterNum:  "",
            addedAt:             new Date().toISOString()
        }
        root.libraryList = [entry, ...root.libraryList]
        _saveLibrary()
        console.log("[ServiceManga] Added to library:", manga.title)
    }

    function removeFromLibrary(mangaId) {
        root.libraryList = root.libraryList.filter(function(e) { return e.id !== mangaId })
        _saveLibrary()
        console.log("[ServiceManga] Removed from library:", mangaId)
    }

    function isInLibrary(mangaId) {
        return root.libraryList.some(function(e) { return e.id === mangaId })
    }

    function updateLastRead(mangaId, chapterId, chapterNum) {
        root.libraryList = root.libraryList.map(function(e) {
            if (e.id !== mangaId) return e
            return Object.assign({}, e, {
                lastReadChapterId:  chapterId,
                lastReadChapterNum: chapterNum
            })
        })
        _saveLibrary()
        console.log("[ServiceManga] Last read updated —", mangaId, "ch.", chapterNum)
    }

    function getLibraryEntry(mangaId) {
        for (var i = 0; i < root.libraryList.length; i++) {
            if (root.libraryList[i].id === mangaId) return root.libraryList[i]
        }
        return null
    }

    // Load library as soon as the singleton initialises
    Component.onCompleted: libraryFile.reload()

    property bool isExpanded: false

    // ── Backend server ───────────────────────────────────────────────────────
    property bool serverReady: false

    readonly property string _scriptDir:
        Quickshell.env("HOME") + "/.config/DankMaterialShell/plugins/mediaHub/scripts"

Process {
    id: serverProcess

    workingDirectory: root._scriptDir

    command: [
        root._scriptDir + "/../.venv/bin/python3",
        "manga_server.py"
    ]

    running: true

    onExited: (code) => {
        console.warn("[ServiceManga] exited:", code, "— restarting")
        root.serverReady = false
        serverProcess.running = true
    }
}

    Timer {
        id: healthPoller
        interval: 150
        repeat: true
        running: true
        onTriggered: {
            var xhr = new XMLHttpRequest()
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                    healthPoller.stop()
                    root.serverReady = true
                    console.log("[ServiceManga] Backend ready at", root.apiUrl)
                    fetchByOrigin("", true)
                }
            }
            xhr.open("GET", root.apiUrl + "/health")
            xhr.send()
        }
    }

    // ── HTTP helpers ──────────────────────────────────────────────────────────
    function _get(url, onDone) {
        var xhr = new XMLHttpRequest()
        var settled = false
        xhr.timeout = 20000
        xhr.ontimeout = function() {
            if (settled) return
            settled = true
            onDone("timeout", null)
        }
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (settled) return
            settled = true
            if (xhr.status === 200) onDone(null, xhr.responseText)
            else onDone("HTTP " + xhr.status, null)
        }
        xhr.open("GET", url)
        xhr.send()
    }

    function _post(url, data, onDone) {
        var xhr = new XMLHttpRequest()
        var settled = false
        xhr.timeout = 20000
        xhr.ontimeout = function() {
            if (settled) return
            settled = true
            onDone("timeout", null)
        }
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (settled) return
            settled = true
            if (xhr.status === 200) onDone(null, xhr.responseText)
            else onDone("HTTP " + xhr.status, null)
        }
        xhr.open("POST", url)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify(data))
    }

    // ── Origin → type mapping ─────────────────────────────────────────────────
    function _originType(origin) {
        if (origin === "ko") return "Manhwa"
        if (origin === "ja") return "Manga"
        if (origin === "zh") return "Manhua"
        return ""
    }

    // ── Browse / Search ───────────────────────────────────────────────────────
    function fetchByOrigin(origin, reset) {
        if (isFetchingManga) return
        if (reset) { mangaList = []; currentOffset = 0; latestPage = 1 }
        currentOrigin = origin
        currentSearchText = ""

        if (origin === "") {
            isFetchingManga = true
            mangaError = ""
            const url = root.apiUrl + "/hot"
            _get(url, function(err, body) {
                if (err) { mangaError = "Request failed: " + err; isFetchingManga = false; return }
                _parseMangaResults(body)
            })
        } else if (origin === "latest") {
            if (reset) latestPage = 1
            isFetchingManga = true
            mangaError = ""
            const url = root.apiUrl + "/latest?page=" + latestPage
            _get(url, function(err, body) {
                if (err) { mangaError = "Request failed: " + err; isFetchingManga = false; return }
                _parseMangaResults(body)
            })
        } else {
            _doSearch("a", _originType(origin), currentOffset, "Popularity")
        }
    }

    function searchManga(query, reset) {
        if (isFetchingManga) return
        if (reset) { mangaList = []; currentOffset = 0 }
        currentSearchText = query
        _doSearch(query, _originType(currentOrigin), currentOffset, "Best Match")
    }

    function fetchNextMangaPage() {
        if (!hasMoreManga || isFetchingManga) return
        if (currentSearchText.length > 0) {
            _doSearch(currentSearchText, _originType(currentOrigin), currentOffset, "Best Match")
        } else if (currentOrigin === "latest") {
            latestPage++
            fetchByOrigin("latest", false)
        } else {
            _doSearch("a", _originType(currentOrigin), currentOffset, "Popularity")
        }
    }

    function _doSearch(query, type, offset, sort) {
        isFetchingManga = true
        mangaError = ""
        let url = root.apiUrl + "/search?q=" + encodeURIComponent(query)
            + "&offset=" + offset + "&sort=" + encodeURIComponent(sort)
        if (type) url += "&type=" + encodeURIComponent(type)
        _get(url, function(err, body) {
            if (err) { mangaError = "Request failed: " + err; isFetchingManga = false; return }
            _parseMangaResults(body)
        })
    }

    function _parseMangaResults(json) {
        try {
            const data = JSON.parse(json)
            if (data.error) { mangaError = data.error; isFetchingManga = false; return }

            const isHot    = Array.isArray(data)
            const isLatest = !isHot && data.nextPage !== undefined
            const items    = isHot ? data : (data.results || [])

            mangaList = [...mangaList, ...items.map(item => ({
                id:       item.id     || "",
                title:    root._decode(item.title || ""),
                thumbUrl: item.image  || "",
                status:   item.status || "",
                type:     item.type   || "",
                author:   ""
            }))]

            hasMoreManga = isHot ? false : (data.hasMore || false)
            if (!isHot && !isLatest)
                currentOffset = data.nextOffset || (currentOffset + items.length)

            mangaError = ""
        } catch (e) {
            mangaError = "Parse error: " + e
            console.error("[ServiceManga]", e)
        }
        isFetchingManga = false
    }

    // ── Manga detail ──────────────────────────────────────────────────────────
    function fetchMangaDetail(mangaId) {
        if (isFetchingDetail) return
        isFetchingDetail = true
        currentManga = null
        detailError = ""
        const url = root.apiUrl + "/info?id=" + encodeURIComponent(mangaId)
        _get(url, function(err, body) {
            if (err) { detailError = "Request failed: " + err; isFetchingDetail = false; return }
            _parseMangaDetail(body)
        })
    }

    function _parseMangaDetail(json) {
        try {
            const data = JSON.parse(json)
            if (data.error) { detailError = data.error; isFetchingDetail = false; return }
            currentManga = {
                id:          data.id          || "",
                title:       data.title       || "",
                description: data.description || "",
                status:      data.status      || "",
                year:        0,
                coverUrl:    data.image       || "",
                authors:     data.authors     || [],
                tags:        data.tags        || [],
                chapters:    (data.chapters   || []).map(ch => ({
                    id:        ch.id        || "",
                    chapter:   ch.chapter   || "",
                    title:     ch.title     || "",
                    pages:     0,
                    group:     "",
                    publishAt: ch.publishAt || ""
                }))
            }
            detailError = ""
        } catch (e) {
            detailError = "Parse error: " + e
            console.error("[ServiceManga]", e)
        }
        isFetchingDetail = false
    }

    // ── Chapter pages ─────────────────────────────────────────────────────────
    function fetchChapterPages(chapterId) {
        if (isFetchingPages) return
        isFetchingPages = true
        currentChapterId = chapterId
        chapterPages = []
        pagesError = ""
        const url = root.apiUrl + "/pages?chapterId=" + encodeURIComponent(chapterId)
        _get(url, function(err, body) {
            if (err) { pagesError = "Request failed: " + err; isFetchingPages = false; return }
            _parseChapterPages(body)
        })
    }

    function _parseChapterPages(json) {
        try {
            const data = JSON.parse(json)
            if (data.error || !Array.isArray(data)) {
                pagesError = data.error || "Invalid response"
                isFetchingPages = false
                return
            }
            if (data.length === 0) {
                pagesError = "No pages found for this chapter"
                isFetchingPages = false
                return
            }
            chapterPages = data.map((p, idx) => ({
                index:     idx,
                url:       p.img || "",
                localPath: p.img || "",
                ready:     true
            }))
            pagesError = ""
            isFetchingPages = false
        } catch (e) {
            pagesError = "Parse error: " + e
            isFetchingPages = false
        }
    }

    // ── Utility ───────────────────────────────────────────────────────────────
    function clearChapterList() {
        if (currentManga)
            currentManga = Object.assign({}, currentManga, { chapters: [] })
    }

    function clearChapterPages() {
        chapterPages = []
        currentChapterId = ""
        pagesError = ""
    }

    function _decode(str) {
        return str
            .replace(/&#39;/g, "'")
            .replace(/&#x27;/g, "'")
            .replace(/&amp;/g, "&")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, '"')
            .replace(/&#\d+;/g, "")
    }
}
