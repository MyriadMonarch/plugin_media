# Media Hub — DMS Plugin

A slideout-based media browser for **Anime**, **Manga**, and **Novels** built as a
daemon plugin for [DankMaterialShell](https://github.com/AnomalyCod3/DankMaterialShell) (DMS).
It ships three self-contained Python backend servers (one per media type) that the
QML frontend talks to over `127.0.0.1`, plus a full reader/player experience:
stream anime in MPV, read manga chapters as scrollable images, read novel chapters
as paginated text — with libraries, offline downloads, and per-module settings.

---

## Features

### Anime
- **Search** across anipy-cli's provider stack (`anidbapp` primary, `animehub` fallback).
- **Browse** — *Popular* = current-year catalog; *Latest* = current-season catalog (country filter accepted).
- Cards enriched with posters, score, media type, and episode counts (scraped from anidb.app).
- **Episode list** with sub/dub support; **direct HLS stream links** (no referrer needed).
- Plays fullscreen via **MPV** (launched with `yt-dlp` hook only as a resolution fallback).

### Manga
- Browse **popular** and **latest** manga from **MangaDex** (via the WeebCentral API mirror).
- Search, filter by type, sort by update recency.
- Scrollable image reader with zoom (Ctrl+Wheel / +/- buttons, 0.3×–1.0×).
- Add to library, track progress, download chapters for offline reading.

### Novels
- Browse **popular** (ranking) and **latest** (recent updates) with infinite scroll.
- Search via **LightNovelCrawler** across curated sources (novelfire.net, novelbuddy.com) plus
  a raw FreeWebNovel fallback provider.
- Provider-agnostic backend — every ID is prefixed with the provider name, so favorites,
  downloads, and chapter URLs never collide across sources.
- Text reader with 3 themes (dark / sepia / light), chapter prev/next navigation,
  library tracking, and offline chapter downloads.

### General
- Right-side slideout panel (docked right, expandable to full width).
- Persisted **library** per module (favorites JSON + progress tracking).
- Persisted **settings** (`~/.local/share/quickshell/mediahub_settings.json`).
- Infinite scroll with position preservation across tabs.

---

## Architecture

```
plugin.json                      # Plugin manifest (daemon, slideout)
MediaHub.qml                     # Plugin root (daemon component)
├── Content.qml                   # Tab container (Manga / Novel / Anime / Settings)
├── MediaHubSettings.qml          # Settings entry point (plugin manifest)
│
├── anime/                        # Anime module
│   ├── AnimePanel.qml
│   └── components/
│       ├── BrowseView.qml
│       ├── DetailView.qml        # Episode list, sub/dub, MPV launch
│       └── LibraryView.qml
│
├── manga/                        # Manga module
│   ├── MangaReader.qml
│   └── components/
│       ├── BrowseView.qml
│       ├── DetailView.qml
│       ├── LibraryView.qml
│       └── ReaderView.qml        # Flickable + Column image reader (zoomable)
│
├── novel/                        # Novel module
│   ├── NovelReader.qml
│   └── components/
│       ├── BrowseView.qml
│       ├── DetailView.qml
│       ├── LibraryView.qml
│       └── ReaderView.qml        # Text reader (theming, prev/next)
│
├── settings/                     # Settings tab
│   └── SettingsPanel.qml
│
├── services/                     # QML service singletons (HTTP clients)
│   ├── Anime.qml                 #  ↔ anime_server.py :5050
│   ├── Manga.qml                 #  ↔ manga_server.py :5150
│   ├── Novel.qml                 #  ↔ novel_server/   :5151
│   ├── Settings.qml              #  persisted settings singleton
│   ├── HubTheme.qml              #  hub/reader theme definitions
│   └── qmldir
│
└── scripts/                      # Python backend servers
    ├── anime_server.py           # Flask, anipy-api wrapper      :5050
    ├── manga_server.py           # http.server, MangaDex wrapper :5150
    └── novel_server/
        ├── main.py               # entry point (argparse)
        ├── server.py             # http.server routing
        ├── storage.py            # favorites + offline downloads
        └── providers/
            ├── base.py           # NovelProvider interface + helpers
            ├── freewebnovel.py   # FreeWebNovel scraper
            ├── lncrawler.py      # LightNovelCrawler wrapper + novelbuddy browse
            ├── utils.py          # fetch (curl_cffi), caching, text cleaning
            └── __init__.py       # provider registry + ID prefixing
```

The QML `Process` components launch each backend lazily (on first use) from the
**plugin's own venv** — paths are always plugin-relative (`_scriptDir`), never
hardcoded to a user home, which keeps the plugin portable.

---

## Backend Servers

All three servers listen on loopback only and auto-start on demand.

| Port | Module | Server | Entry point |
|------|--------|--------|-------------|
| 5050 | Anime  | Flask (+ anipy-api) | `scripts/anime_server.py` |
| 5150 | Manga  | `http.server` | `scripts/manga_server.py` |
| 5151 | Novel  | `http.server` | `scripts/novel_server/main.py` (env `NOVEL_PORT` overrides) |

### Anime API (`:5050`)

| Endpoint | Description |
|----------|-------------|
| `GET /` | Endpoint documentation + provider list |
| `GET /health` | `{"status": "ok"}` |
| `GET /search?q=<query>&mode=sub\|dub` | Multi-provider search |
| `GET /popular?size=20&page=1` | Current-year catalog (paged) |
| `GET /latest?limit=26&page=1&mode=sub\|dub&country=ALL` | Current-season catalog (paged) |
| `GET /episodes?id=<provider:identifier>&mode=sub\|dub&check=1` | Episode list + details |
| `GET /links?id=<provider:identifier>&ep=<n>&mode=sub\|dub&quality=best` | Stream links |

- Show IDs cross the API as `"anidbapp:<urlencoded-identifier>"` (e.g. `anidbapp:3880`).
- `mode` selects subtitle language: `sub` / `dub` (anidbapp serves HLS with both when available).
- All responses TTL-cached (per-key single-flight); every upstream call runs under a
  timeout — the underlying anipy-api library has none.
- Enrichment (posters/score/type/episode counts) requires the anidb.app browser UI
  and sends a desktop Chrome user agent.

### Manga API (`:5150`)

| Endpoint | Description |
|----------|-------------|
| `GET /health` | `{"ok": true}` |
| `GET /hot` | Popular/trending list |
| `GET /latest?page=1` | Recently updated (paged) |
| `GET /search?q=<query>&type=<manga\|manhwa\|...>&offset=0&sort=Latest+Updates` | Search |
| `GET /info?id=<manga-id>` | Series details + chapter list |
| `GET /pages?chapterId=<chapter-id>` | Image page URLs |
| `GET /image?url=<encoded-url>` | Cover/image proxy (avoid hotlink bans) |
| `GET /favorites` `/favorites/check` | Library list / batch status |
| `POST /favorites/add` `/favorites/remove` `/favorites/mark-seen` | Library management |
| `GET /dl/list` `/dl/progress` `/dl/pages` | Offline download queries |
| `POST /dl/start` `/dl/delete` | Offline download control |

### Novel API (`:5151`)

| Endpoint | Description |
|----------|-------------|
| `GET /health` | `{"ok": true, "provider": "<active>"}` |
| `GET /provider/list` | Registered providers |
| `GET /provider/active` | Current provider name/label |
| `POST /provider/switch` | `{"provider": "lncrawl"}` |
| `GET /hot` | Popular list (current provider) |
| `GET /latest?page=1` | Recent updates, `{results, hasMore, nextPage}` |
| `GET /search?q=<query>&genre=&status=All&page=1` | Search, `{results, hasMore, nextPage}` |
| `GET /info?id=<prefixed-novel-id>` | Novel details + full chapter list (offline-first metadata) |
| `GET /chapter?id=<prefixed-chapter-id>` | Chapter body `{paragraphs, wordCount, prevId, nextId}` — serves offline copy first |
| `GET /image?url=<encoded-url>` | Cover proxy |
| `GET /favorites` `/favorites/check` | Library / progress lookup |
| `POST /favorites/add` `/favorites/remove` `/favorites/mark-seen` | Library management |
| `GET /dl/list` `/dl/progress` `/dl/chapter` | Offline download queries |
| `POST /dl/start` `/dl/delete` | Offline download control |

#### Providers & ID scheme

```
Internal (provider sees):   "novel/some-slug"
External (client sees):     "freewebnovel:novel/some-slug"     or "lncrawl:https://..."
```

Every ID crossing the HTTP boundary carries its provider prefix, so favorites and
downloads never collide. Unknown prefixes are tolerated (kept as-is) so old records
still load.

| Provider | Source | Used for |
|----------|--------|----------|
| `lncrawl` (default) | LightNovelCrawler package + novelbuddy.me browse | search (novelfire/novelbuddy), popular (`/ranking`), latest (`/latest?page=N`), info + chapter crawling |
| `freewebnovel` | freewebnovel.com scrapers | browse/hot/latest + chapters (currently in maintenance → falls back automatically) |

Browsing is resilient: if the active provider fails, the other provider's list is
served transparently (`require_results=True`). `lncrawl` novel/chapter URLs work
directly — huge catalogs (3,000+ chapters) load fast via per-novel TTL caching.

---

## Dependencies

### Required (installed into the plugin venv by `install.sh`)
| Package | Purpose |
|---------|---------|
| Python ≥ 3.10 | Backend servers |
| Flask | Anime HTTP API routing |
| requests | HTTP client |
| curl_cffi | Browser TLS fingerprinting (Cloudflare bypass) |
| anipy-api | Anime providers/streams (anipy-cli's API package) |
| lightnovel-crawler | Novel search + crawling engine |

### Optional but recommended
| Dependency | Purpose |
|-----------|---------|
| `mpv` (system package) | Anime video playback |
| `yt-dlp` | MPV resolution fallback for embed-based sources |

```bash
# Arch Linux
sudo pacman -S mpv            # yt-dlp is venv-installed by install.sh

# Ubuntu / Debian
sudo apt install mpv
```

---

## Installation

```bash
# Clone or copy the plugin directory
git clone <this-repo> ~/Projects/plugin_media

# Run the installer
cd ~/Projects/plugin_media
chmod +x install.sh
./install.sh
```

The installer:
1. Cleans and copies all plugin files to `~/.config/DankMaterialShell/plugins/mediaHub/`.
2. Creates a fresh Python virtual environment with Flask, requests, curl_cffi,
   anipy-api, lightnovel-crawler and yt-dlp.
3. Strips `__pycache__` from the install target.

Restart DMS to load the plugin:

```bash
systemctl --user restart dms.service
```

> Note: `quickshell restart` is **not** a valid command — DMS runs as the systemd
> user unit `dms.service`. The three backend servers then auto-start on first use.

Verify:

```bash
curl http://127.0.0.1:5050/health   # anime
curl http://127.0.0.1:5150/health   # manga
curl http://127.0.0.1:5151/health   # novel
```

## Opening / Toggling the Plugin

The plugin opens as a right-side slideout. Toggle it at any time with the DMS IPC call:

```bash
dms ipc call plugins toggle mediaHub
```

Other useful plugin IPC commands:

```bash
dms ipc call plugins status mediaHub    # "loaded" when active
dms ipc call plugins enable mediaHub    # force-enable
dms ipc call plugins disable mediaHub   # force-disable
```

---

## Data & Storage

| What | Where |
|------|-------|
| Plugin files | `~/.config/DankMaterialShell/plugins/mediaHub/` |
| Plugin venv | `~/.config/DankMaterialShell/plugins/mediaHub/.venv/` |
| Hub/reader settings | `~/.local/share/quickshell/mediahub_settings.json` |
| Manga library + downloads | `~/.local/share/quickshell-manga/` |
| Novel library + downloads | `~/.local/share/quickshell-novel/` |

---

## Usage Notes

- **MPV playback**: DetailView launches `mpv --fs --force-window=yes --title=<name>` with
  the plugin venv's `yt-dlp` wired as the resolve hook and a `--referrer` only when
  the source requires one. Direct HLS from hls.anidb.app needs no referrer.
- **Chapter downloads** render the text to JSON on the server and are served
  offline-first by `/chapter` — download a chapter once, and it reads instantly
  even if the source is down.
- **Reader themes**: dark / sepia / light for novels, plus hub-wide auto/dark/light
  in the Settings tab.
- **Novel browsing fallback chain**: default provider is `lncrawl` (novelbuddy.me);
  if it fails, the server automatically tries `freewebnovel` — and vice versa.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Nothing loads after updating QML | `systemctl --user restart dms.service` (QML `Process` commands are fixed at shell load) |
| Port already in use (`Address already in use`) | A stale server from an old install holds the port — `pgrep -af "novel_server\|anime_server\|manga_server"` and kill it; the QML watcher respawns its own |
| Novel browse empty while freewebnovel is maintenanced | Switch provider via `POST /provider/switch {"provider": "lncrawl"}` or rely on the automatic fallback |
| anidb.app enrichment fails | The API expects a desktop UA (`Mozilla/5.0 (Windows NT 10.0; WOW64) … Chrome/86`) — the server sends it automatically |
| `mpv` won't start | Install mpv system-wide (`sudo pacman -S mpv` / `sudo apt install mpv`) |

---

## Credits

- [DankMaterialShell](https://github.com/AnomalyCod3/DankMaterialShell) — the shell this plugin extends
- [anipy-cli / anipy-api](https://github.com/sdaqo/anipy-cli) — anime providers & stream resolution
- [LightNovelCrawler](https://github.com/lncrawl/lightnovel-crawler) — novel search + crawling engine
- MangaDex / WeebCentral — manga catalog + chapter images
- NovelBuddy ([novelbuddy.me](https://novelbuddy.me)) — novel browse (popular/latest) fallback