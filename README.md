# Important Thing
I just copied https://github.com/dhrruvsharma/shell and just converted the novel manga and anime model into a dms shell with opencode's DeepSeek V4 Flash Free, also i dont know if the install script will work(havent tried it yet) please give me feedback on wht i can do 

# Media Hub — DMS Plugin

A slideout-based media browser for **Manga**, **Novels**, and **Anime** built as a daemon plugin for [DankMaterialShell](https://github.com/AnomalyCod3/DankMaterialShell) (DMS).

## Features

### Manga
- Browse popular & latest manga from MangaDex
- Search by title
- Read chapters with a scrollable image reader
- Zoom in/out (Ctrl+Wheel or +/- buttons, range 0.3×–1.0×)
- Add to library / track progress

### Novels
- Browse popular & latest novels from NovelBin & FreeWebNovel
- Search by title
- Read chapters with a scrollable text reader
- Provider-agnostic backend with automatic fallback
- Add to library / track progress

### Anime
- Combined search across **AllAnime** + **AniList** (deduplicated, English titles preferred)
- Country-filtered latest tab (Japan / China / Korea)
- **Cross-provider streaming fallback**: tries AllAnime first, falls back to Node.js scrapers (animeflv / gogoanime)
- Plays via **MPV** with yt-dlp for embed URL resolution
- Sub / Dub toggle
- Provider-agnostic — no manual switching needed

### General
- Right-side slideout panel (always docked right)
- Library tracking per module
- Infinite scroll with position preservation
- Settings page with plugin info

## Architecture

```
plugin.json                      # Plugin manifest
MediaHub.qml                     # Plugin root (daemon component)
├── Content.qml                   # Tab container (Manga / Novel / Anime)
├── MediaHubSettings.qml          # Settings page
│
├── manga/                        # Manga module
│   ├── MangaReader.qml
│   └── components/
│       ├── BrowseView.qml
│       ├── DetailView.qml
│       ├── LibraryView.qml
│       └── ReaderView.qml        # Flickable + Column image reader
│
├── novel/                        # Novel module
│   ├── NovelReader.qml
│   └── components/
│       ├── BrowseView.qml
│       ├── DetailView.qml
│       ├── LibraryView.qml
│       └── ReaderView.qml
│
├── anime/                        # Anime module
│   ├── AnimePanel.qml
│   └── components/
│       ├── BrowseView.qml
│       ├── DetailView.qml
│       └── LibraryView.qml
│
├── services/                     # QML service singletons
│   ├── Anime.qml                 #  HTTP client ↔ anime_server.py :5050
│   ├── Manga.qml                 #  HTTP client ↔ manga_server.py :5150
│   ├── Novel.qml                 #  HTTP client ↔ novel_server/   :5151
│   └── qmldir
│
└── scripts/                      # Python backend servers
    ├── anime_server.py           # Combined provider (Flask) :5050
    ├── manga_server.py           # MangaDex API wrapper (http.server) :5150
    ├── anime_providers/
    │   └── providers/
    │       ├── allanime.py       # AllAnime GraphQL scraper
    │       ├── justalanime.py    # AniList + Node.js scraper wrapper
    │       ├── base.py           # Abstract provider
    │       └── node_api/
    │           ├── package.json
    │           ├── package-lock.json
    │           └── server.js     # Zero-dep Node.js HTTP scraper :5051
    └── novel_server/
        ├── main.py, server.py, storage.py
        └── providers/
            ├── novelbin.py
            ├── freewebnovel.py
            ├── base.py
            └── utils.py
```

## Dependencies

### Required
| Dependency | Version | Purpose |
|-----------|---------|---------|
| Python 3        | ≥ 3.12 | Backend servers |
| Flask           | ≥ 3.0  | Anime HTTP API routing |
| Requests        | ≥ 2.31 | HTTP client for scrapers |
| curl_cffi       | ≥ 0.7  | Browser TLS fingerprinting (Cloudflare bypass for WeebCentral / Novel providers) |

### Optional but recommended
| Dependency | Purpose |
|-----------|---------|
| **MPV** with **yt-dlp** | Anime video playback (embed URL resolution) |
| **Node.js** (≥ 18) | Anime fallback scraper (animeflv / gogoanime via server.js) |

Install MPV & yt-dlp:
```bash
# Arch Linux
sudo pacman -S mpv
pip install yt-dlp

# Ubuntu / Debian
sudo apt install mpv
pip install yt-dlp
```

## Installation

```bash
# Clone or copy the plugin directory
git clone <this-repo> ~/plugin_media

# Run the installer
cd ~/plugin_media
chmod +x install.sh
./install.sh
```

The installer:
1. Copies all files to `~/.config/DankMaterialShell/plugins/mediaHub/`
2. Creates a Python virtual environment with Flask, Requests, curl_cffi, and yt-dlp
3. Cleans up `__pycache__` directories from the install target
4. No `npm install` needed — the Node.js server uses only built-in modules (http, https)

Restart DMS after installation:
```bash
quickshell restart
```

## Backend Servers

Three backend servers start automatically on first use (lazy-started by QML `Process`):

| Port | Server | Type | Command |
|------|--------|------|---------|
| 5050 | Anime (combined) | Flask | `.venv/bin/python3 scripts/anime_server.py` |
| 5150 | Manga (WeebCentral) | `http.server` | `.venv/bin/python3 scripts/manga_server.py` |
| 5151 | Novel | `http.server` | `.venv/bin/python3 scripts/novel_server/main.py` |

Anime Node.js wrapper starts on port 5051 as a child process of the Python anime server (started by JustalAnime provider).

## Notes

- **Anime streaming** depends on source availability. AllAnime sometimes returns CAPTCHA errors; in that case the Node.js scraper (animeflv / gogoanime) is used as fallback. If neither works, the anime cannot be streamed through this plugin.
- **Manga** uses MangaDex via WeebCentral — images load from MangaDex CDN. The manga reader uses a Flickable+Column layout (no ListView) with sequential image loading (top-to-bottom) and `StopAtBounds` for natural scroll limits. Zoom range: 0.3×–1.0× via Ctrl+Wheel or +/- buttons.
- **Novels** use NovelBin and FreeWebNovel — chapter text may contain HTML entities (auto-decoded).
- **Bundled fixes**: All Python/QML paths use `_scriptDir`-relative paths instead of hardcoded home directories, making the plugin portable across systems.
- All backgrounds are fully opaque; font colors are `#ffffff` throughout.
