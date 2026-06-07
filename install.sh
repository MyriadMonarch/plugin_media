#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="mediaHub"
PLUGIN_SRC="$(cd "$(dirname "$0")" && pwd)"
DMS_PLUGINS="${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell/plugins"
INSTALL_DIR="$DMS_PLUGINS/$PLUGIN_ID"
VENV_DIR="$INSTALL_DIR/.venv"
PYTHON="python3"

# ── Colors ──────────────────────────────────────────────────────────────
RST='\033[0m';  RED='\033[0;31m';  GRN='\033[0;32m';  YLW='\033[0;33m'
info()  { echo -e "${GRN}[info]${RST}  $*"; }
warn()  { echo -e "${YLW}[warn]${RST}  $*"; }
error() { echo -e "${RED}[error]${RST} $*" >&2; }

# ── Pre-flight checks ───────────────────────────────────────────────────
if [ ! -d "$DMS_PLUGINS" ]; then
    error "DMS plugin directory not found: $DMS_PLUGINS"
    echo "  Make sure DankMaterialShell is installed and has been run at least once."
    exit 1
fi

command -v "$PYTHON"       >/dev/null 2>&1 || { error "Python 3 is required";  exit 1; }
command -v node            >/dev/null 2>&1 || { warn "Node.js not found — anime Node.js scraper won't work"; }
command -v mpv             >/dev/null 2>&1 || { warn "mpv not found — anime video playback won't work"; }

# ── Install files ───────────────────────────────────────────────────────
info "Installing plugin to $INSTALL_DIR"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"/{anime/components,manga/components,novel/components,services,scripts/{anime_providers/providers/node_api,novel_server/providers}}

# QML
cp "$PLUGIN_SRC"/plugin.json       "$INSTALL_DIR/"
cp "$PLUGIN_SRC"/MediaHub.qml      "$INSTALL_DIR/"
cp "$PLUGIN_SRC"/MediaHubSettings.qml "$INSTALL_DIR/"
cp "$PLUGIN_SRC"/Content.qml       "$INSTALL_DIR/"
cp "$PLUGIN_SRC"/anime/AnimePanel.qml  "$INSTALL_DIR"/anime/
cp "$PLUGIN_SRC"/anime/components/*.qml "$INSTALL_DIR"/anime/components/
cp "$PLUGIN_SRC"/manga/MangaReader.qml  "$INSTALL_DIR"/manga/
cp "$PLUGIN_SRC"/manga/components/*.qml "$INSTALL_DIR"/manga/components/
cp "$PLUGIN_SRC"/novel/NovelReader.qml  "$INSTALL_DIR"/novel/
cp "$PLUGIN_SRC"/novel/components/*.qml "$INSTALL_DIR"/novel/components/

# Services
cp "$PLUGIN_SRC"/services/*.qml  "$INSTALL_DIR"/services/
cp "$PLUGIN_SRC"/services/qmldir "$INSTALL_DIR"/services/

# Python scripts
cp    "$PLUGIN_SRC"/scripts/*.py                "$INSTALL_DIR"/scripts/
cp -r "$PLUGIN_SRC"/scripts/anime_providers     "$INSTALL_DIR"/scripts/
cp -r "$PLUGIN_SRC"/scripts/novel_server        "$INSTALL_DIR"/scripts/
# Remove cached bytecode (may be for wrong Python version)
find "$INSTALL_DIR"/scripts -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true

info "Plugin files installed."

# ── Python virtual environment ──────────────────────────────────────────
info "Setting up Python virtual environment at $VENV_DIR"
"$PYTHON" -m venv "$VENV_DIR"
info "Installing Python dependencies (flask, requests, curl_cffi)..."
"$VENV_DIR/bin/pip" install --quiet --upgrade pip
"$VENV_DIR/bin/pip" install --quiet flask requests curl_cffi
"$VENV_DIR/bin/pip" install --quiet yt-dlp  # for MPV embed resolution
info "Python venv ready."

# ── Done ────────────────────────────────────────────────────────────────
echo ""
echo -e "${GRN}┌────────────────────────────────────────────────────────┐${RST}"
echo -e "${GRN}│  Media Hub plugin installed successfully!              │${RST}"
echo -e "${GRN}│                                                        │${RST}"
echo -e "${GRN}│  To activate, restart DMS or run:                      │${RST}"
echo -e "${GRN}│    quickshell restart                                  │${RST}"
echo -e "${GRN}│                                                        │${RST}"
echo -e "${GRN}│  Three backend servers will auto-start on demand:      │${RST}"
echo -e "${GRN}│    Manga  → http://127.0.0.1:5150                      │${RST}"
echo -e "${GRN}│    Novel  → http://127.0.0.1:5151                      │${RST}"
echo -e "${GRN}│    Anime  → http://127.0.0.1:5050 (combined provider)  │${RST}"
echo -e "${GRN}└────────────────────────────────────────────────────────┘${RST}"
