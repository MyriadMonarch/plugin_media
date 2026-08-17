#!/usr/bin/env python3
"""Media Hub - Anime backend built on anipy-api (https://github.com/sdaqo/anipy-cli).

Exposes the endpoints expected by services/Anime.qml:
    GET /            -> endpoint documentation
    GET /health      -> {"status": "ok"}
    GET /search      ?q=<query>&mode=sub|dub
    GET /popular     ?size=20&page=1
    GET /latest      ?limit=26&page=1&mode=sub|dub&country=ALL
    GET /episodes    ?id=<provider:identifier>&mode=sub|dub&check=1
    GET /links       ?id=<provider:identifier>&ep=<n>&mode=sub|dub&quality=best

Provider logic is 100% from the anipy-cli api package (anipy_api); this file
only adapts it to the QML contract and adds caching.
"""

import argparse
import re
import threading
import time
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FutureTimeout
from datetime import datetime
from typing import Any, Callable, Optional
from urllib.parse import quote, unquote

import requests
from bs4 import BeautifulSoup
from flask import Flask, jsonify, request

from anipy_api.anime import Anime
from anipy_api.error import LangTypeNotAvailableError
from anipy_api.provider import Filters, Season, get_provider

app = Flask(__name__)

HOST = "127.0.0.1"
PORT = 5050

PROVIDER_ORDER = ["anidbapp", "animehub"]
DEFAULT_MODE = "sub"
SUPPORTED_MODES = ("sub", "dub")

# ── Cache (ttl in seconds) ──────────────────────────────────────────────────
SEARCH_TTL = 600
BROWSE_TTL = 3600
DETAIL_TTL = 3600
LINKS_TTL = 600

_cache: dict[str, tuple[float, Any]] = {}
_cache_locks: defaultdict = defaultdict(threading.Lock)

# Threadpool for upstream anipy provider calls (their requests have no timeout).
_PROVIDER_POOL = ThreadPoolExecutor(max_workers=6)

_SEARCH_TIMEOUT = 45
_BROWSE_TIMEOUT = 45
_DETAIL_TIMEOUT = 30
_LINKS_TIMEOUT = 30

ANIDB_BROWSE_URL = "https://anidb.app/browse"
ANIDB_EPISODES_URL = "https://anidb.app/api/frontend/anime/{}/episodes"
ANIDB_PAGE_CAP = 4          # enrich at most this many browse pages with posters
ANIDB_COUNT_CAP = 48        # enrich at most this many cards with episode counts
ANIDB_REQ_TIMEOUT = 8
# Same User-Agent anipy_api's request_page uses (site rejects requests without it).
_UA = ("Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 "
       "(KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36")

_ENRICH_POOL = ThreadPoolExecutor(max_workers=10)


def cached(key: str, ttl: int, loader: Callable[[], Any]) -> Any:
    """TTL cache with single-flight: the key lock is held while loading, so
    concurrent callers for the same key block instead of duplicating work."""
    with _cache_locks[key]:
        now = time.time()
        hit = _cache.get(key)
        if hit and hit[0] > now:
            return hit[1]
        value = loader()
        _cache[key] = (time.time() + ttl, value)
        return value


def with_timeout(fn: Callable[[], Any], timeout: float, default: Any) -> Any:
    """Run an upstream anipy call with a hard deadline; return `default` on
    timeout, re-raise everything else."""
    future = _PROVIDER_POOL.submit(fn)
    try:
        return future.result(timeout=timeout)
    except FutureTimeout:
        return default


# ── Provider helpers ────────────────────────────────────────────────────────
def _lang(mode: str):
    from anipy_api.provider import LanguageTypeEnum

    return LanguageTypeEnum.DUB if mode == "dub" else LanguageTypeEnum.SUB


def _other_lang(mode: str) -> str:
    return "dub" if mode == "sub" else "sub"


def _provider(name: str):
    # get_provider() returns a ready-to-use provider instance.
    return get_provider(name)


def _encode_id(provider: str, identifier: str) -> str:
    return provider + ":" + quote(identifier, safe="")


def _decode_id(encoded: str) -> Optional[tuple[str, str]]:
    """Split a QML show id like 'anidbapp:3880' back into (provider, identifier)."""
    if ":" not in str(encoded):
        return None
    provider, rest = encoded.split(":", 1)
    if provider not in PROVIDER_ORDER:
        return None
    return provider, unquote(rest)


# ── Card mapping (shape matches services/Anime.qml _normaliseShow) ──────────
def _card(result, provider_name: str, poster: str = "", card_type: str = "",
          score: Any = None, ep_count: Optional[int] = None) -> dict:
    langs = [getattr(l, "value", str(l)) for l in result.languages]
    sub = (ep_count if ep_count is not None else 0)
    if sub == 0 and "sub" in langs:
        sub = 1
    dub = (ep_count if ep_count is not None else 0)
    if dub == 0 and "dub" in langs:
        dub = 1
    return {
        "id": _encode_id(provider_name, result.identifier),
        "name": result.name,
        "english_name": result.name,
        "native_name": "",
        "thumbnail": poster or "",
        "score": score,
        "type": card_type,
        "episode_count": str(ep_count) if ep_count is not None else "",
        "description": "",
        "available_episodes": {"sub": sub, "dub": dub, "raw": 0},
        "_provider": provider_name,
        "_identifier": result.identifier,
    }


def _strip_internal(card: dict) -> dict:
    return {k: v for k, v in card.items() if not k.startswith("_")}


# ── anidb.app enrichment (posters / type / score / episode counts) ──────────
def _browse_page(q: str, page: int) -> dict:
    """Fetch one /browse page and map identifier -> {poster, type, score}."""
    params: dict[str, Any] = {"page": page}
    if q:
        params["q"] = q
    try:
        res = requests.get(ANIDB_BROWSE_URL, params=params,
                           headers={"User-Agent": _UA}, timeout=ANIDB_REQ_TIMEOUT)
        res.raise_for_status()
    except requests.RequestException:
        return {}
    out: dict[str, dict] = {}
    soup = BeautifulSoup(res.text, "html.parser")
    for a in soup.find_all("a", attrs={"class": "anime-card"}):
        href = a.get("href") or ""
        ident = href.rstrip("/").split("-")[-1]
        if not ident or not ident.isdigit():
            continue
        poster = ""
        img = a.find("img")
        if img and img.get("src"):
            poster = img["src"]
        card_type = ""
        badge = a.find("span", attrs={"class": "badge-orange"})
        if badge and badge.text:
            card_type = badge.text.strip()
        score = None
        text = a.get_text(" ", strip=True)
        m = re.search(r"(\d+\.\d+)", text)
        if m:
            score = float(m.group(1))
        out[ident] = {"poster": poster, "type": card_type, "score": score}
    return out


def _browse_pages(q: str, pages: int) -> dict:
    futures = [_ENRICH_POOL.submit(_browse_page, q, p) for p in range(1, pages + 1)]
    merged: dict[str, dict] = {}
    for f in futures:
        try:
            merged.update(f.result(timeout=15))
        except Exception:
            pass
    return merged


def _count_episodes(identifier: str) -> Optional[int]:
    try:
        res = requests.get(ANIDB_EPISODES_URL.format(identifier),
                           headers={"User-Agent": _UA}, timeout=ANIDB_REQ_TIMEOUT)
        res.raise_for_status()
        return len(res.json().get("episodes", []))
    except requests.RequestException:
        return None


def _enrich(results, q: str) -> list[dict]:
    """Attach posters/type/score/ep-counts to anidbapp ProviderSearchResults."""
    meta = _browse_pages(q, ANIDB_PAGE_CAP)
    counts: dict[str, Optional[int]] = {}
    futures = {}
    for ident in [str(r.identifier) for r in results][:ANIDB_COUNT_CAP]:
        futures[_ENRICH_POOL.submit(_count_episodes, ident)] = ident
    for f, ident in tuple(futures.items()):
        try:
            counts[ident] = f.result(timeout=15)
        except Exception:
            counts[ident] = None
    cards = []
    for r in results:
        m = meta.get(str(r.identifier), {})
        cards.append(_card(
            r, "anidbapp",
            poster=m.get("poster", ""),
            card_type=m.get("type", ""),
            score=m.get("score"),
            ep_count=counts.get(str(r.identifier)),
        ))
    return cards


# ── Core lookups ────────────────────────────────────────────────────────────
def _search(provider_name: str, query: str) -> Optional[list[dict]]:
    """Search one provider; returns None on timeout so the caller can skip it."""
    provider = _provider(provider_name)
    results = with_timeout(lambda: provider.get_search(query), _SEARCH_TIMEOUT, None)
    if results is None:
        return None
    if provider_name == "anidbapp" and results:
        return _enrich(results, query)
    return [_card(r, provider_name) for r in results]


def search_multi(query: str) -> list[dict]:
    for provider_name in PROVIDER_ORDER:
        try:
            cards = cached("search:{}:{}".format(provider_name, query), SEARCH_TTL,
                           lambda p=provider_name: _search(p, query))
        except Exception:
            continue
        if cards:
            return cards
    return []


def _season_of(month: int) -> Season:
    if month in (12, 1, 2):
        return Season.WINTER
    if month in (3, 4, 5):
        return Season.SPRING
    if month in (6, 7, 8):
        return Season.SUMMER
    return Season.FALL


def browse_dataset(kind: str) -> list[dict]:
    """Browse dataset: 'popular' -> current year, 'latest' -> current season."""
    now = datetime.now()
    filters = Filters(year=now.year)
    if kind == "latest":
        filters.season = _season_of(now.month)

    def loader() -> list[dict]:
        provider = _provider("anidbapp")
        results = with_timeout(
            lambda: provider.get_search("", filters=filters), _BROWSE_TIMEOUT, None)
        if results is None:
            raise RuntimeError("Browse timed out")
        return _enrich(results, "")

    return cached("browse:{}:{}".format(kind, now.year), BROWSE_TTL, loader)


# ── Endpoints ───────────────────────────────────────────────────────────────
@app.get("/")
def index():
    return jsonify({
        "name": "Media Hub Anime backend (anipy-api)",
        "version": "1.0.0",
        "providers": PROVIDER_ORDER,
        "endpoints": {
            "GET /health": "Health check",
            "GET /search?q=<query>&mode=<sub|dub>": "Search anime",
            "GET /popular?size=20&page=1": "Browse current year (paged)",
            "GET /latest?limit=26&page=1&mode=<sub|dub>&country=<ALL>": "Browse current season (paged)",
            "GET /episodes?id=<provider:identifier>&mode=<sub|dub>&check=1": "Episode list + details",
            "GET /links?id=<provider:identifier>&ep=<n>&mode=<sub|dub>&quality=<best>": "Stream links",
        },
    })


@app.get("/health")
def health():
    return jsonify({"status": "ok"})


@app.get("/search")
def search_route():
    q = (request.args.get("q") or "").strip()
    mode = request.args.get("mode") or DEFAULT_MODE
    if not q:
        return jsonify({"error": "Missing required param: q"}), 400
    if mode not in SUPPORTED_MODES:
        return jsonify({"error": "mode must be 'sub' or 'dub'"}), 400
    try:
        cards = with_timeout(lambda: search_multi(q), _SEARCH_TIMEOUT, None)
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    if cards is None:
        return jsonify({"error": "Search timed out"}), 504
    return jsonify({"query": q, "mode": mode, "count": len(cards),
                    "results": [_strip_internal(c) for c in cards]})


@app.get("/popular")
def popular_route():
    size = max(1, min(int(request.args.get("size") or 20), 100))
    page = max(1, int(request.args.get("page") or 1))
    try:
        dataset = with_timeout(lambda: browse_dataset("popular"), _BROWSE_TIMEOUT, None)
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    if dataset is None:
        return jsonify({"error": "Browse timed out"}), 504
    start = (page - 1) * size
    shows = [_strip_internal(c) for c in dataset[start:start + size]]
    return jsonify({"shows": shows, "total": len(dataset), "page": page, "size": size})


@app.get("/latest")
def latest_route():
    limit = max(1, min(int(request.args.get("limit") or 26), 100))
    page = max(1, int(request.args.get("page") or 1))
    country = request.args.get("country") or "ALL"
    try:
        dataset = with_timeout(lambda: browse_dataset("latest"), _BROWSE_TIMEOUT, None)
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    if dataset is None:
        return jsonify({"error": "Browse timed out"}), 504
    start = (page - 1) * limit
    shows = [_strip_internal(c) for c in dataset[start:start + limit]]
    return jsonify({"shows": shows, "total": len(dataset), "page": page,
                    "limit": limit, "country": country})


@app.get("/episodes")
def episodes_route():
    encoded = request.args.get("id") or ""
    mode = request.args.get("mode") or DEFAULT_MODE
    if not encoded:
        return jsonify({"error": "Missing required param: id"}), 400
    if mode not in SUPPORTED_MODES:
        return jsonify({"error": "mode must be 'sub' or 'dub'"}), 400
    parsed = _decode_id(encoded)
    if not parsed:
        return jsonify({"error": "Malformed id: " + encoded}), 400
    provider_name, identifier = parsed

    def loader() -> dict:
        provider = _provider(provider_name)
        try:
            episodes = with_timeout(
                lambda: provider.get_episodes(identifier, _lang(mode)),
                _DETAIL_TIMEOUT, None)
        except LangTypeNotAvailableError:
            episodes = with_timeout(
                lambda: provider.get_episodes(identifier, _lang(_other_lang(mode))),
                _DETAIL_TIMEOUT, None)
        except Exception:
            episodes = None
        if episodes is None:
            raise RuntimeError("Episode list timed out")

        info = None
        try:
            info = with_timeout(lambda: provider.get_info(identifier),
                                _DETAIL_TIMEOUT, None)
        except Exception:
            info = None

        status = ""
        if info and info.status is not None:
            status = getattr(info.status, "name", str(info.status))
        return {
            "id": encoded,
            "name": (info.name if info and info.name else "") or "",
            "provider": provider_name,
            "episodes": episodes,
            "count": len(episodes),
            "description": (info.synopsis if info and info.synopsis else "") or "",
            "thumbnail": (str(info.image) if info and info.image else "") or "",
            "score": None,
            "status": status,
            "type": "",
            "genres": (info.genres if info and info.genres else []) or [],
        }

    try:
        data = cached("episodes:{}:{}".format(encoded, mode), DETAIL_TTL, loader)
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    return jsonify(data)


@app.get("/links")
def links_route():
    encoded = request.args.get("id") or ""
    ep = request.args.get("ep") or ""
    mode = request.args.get("mode") or DEFAULT_MODE
    quality = request.args.get("quality") or "best"
    if not encoded:
        return jsonify({"error": "Missing required param: id"}), 400
    if not ep:
        return jsonify({"error": "Missing required param: ep"}), 400
    if mode not in SUPPORTED_MODES:
        return jsonify({"error": "mode must be 'sub' or 'dub'"}), 400
    parsed = _decode_id(encoded)
    if not parsed:
        return jsonify({"error": "Malformed id: " + encoded}), 400
    provider_name, identifier = parsed
    try:
        episode_num = float(ep)
    except ValueError:
        return jsonify({"error": "ep must be a number"}), 400

    def loader() -> dict:
        provider = _provider(provider_name)
        try:
            streams = with_timeout(
                lambda: provider.get_video(identifier, episode_num, _lang(mode)),
                _LINKS_TIMEOUT, [])
        except LangTypeNotAvailableError:
            streams = with_timeout(
                lambda: provider.get_video(identifier, episode_num,
                                           _lang(_other_lang(mode))),
                _LINKS_TIMEOUT, [])
        except Exception:
            streams = []

        unique = []
        seen = set()
        for s in streams:
            if s.url in seen:
                continue
            seen.add(s.url)
            unique.append({
                "url": s.url,
                "quality": str(s.resolution),
                "type": s.container or "hls",
                "provider": provider_name,
                "referer": s.referrer or "",
                "subtitle": str(s.subtitle) if s.subtitle else "",
                "error": None,
            })

        selected = None
        if unique:
            anime = Anime(provider, "", identifier, {_lang(mode)})
            chosen = with_timeout(
                lambda: anime.get_video(episode_num, _lang(mode),
                                        preferred_quality=quality),
                _LINKS_TIMEOUT, None)
            if chosen:
                selected = {
                    "url": chosen.url,
                    "quality": str(chosen.resolution),
                    "type": chosen.container or "hls",
                    "provider": provider_name,
                    "referer": chosen.referrer or "",
                    "subtitle": str(chosen.subtitle) if chosen.subtitle else "",
                    "error": None,
                }
            else:
                selected = unique[0]

        return {"id": encoded, "ep": ep, "mode": mode, "quality": quality,
                "all_links": unique, "selected": selected}

    try:
        data = cached("links:{}:{}:{}".format(encoded, ep, mode), LINKS_TTL, loader)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

    if not data["all_links"]:
        return jsonify({
            "id": encoded, "ep": ep, "mode": mode, "quality": quality,
            "all_links": [], "selected": {"error": "No working stream found for this episode"},
        })
    return jsonify(data)


def _warm_up():
    """Pre-populate browse caches so the first UI request is fast."""
    def run():
        for kind in ("popular", "latest"):
            try:
                browse_dataset(kind)
            except Exception as e:
                print("[warm-up] {} failed: {}".format(kind, e))
    threading.Thread(target=run, daemon=True).start()


def main():
    global HOST, PORT
    parser = argparse.ArgumentParser(description="Media Hub Anime API server (anipy-api)")
    parser.add_argument("--host", default="127.0.0.1", help="Host to bind (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=5050, help="Port to listen on (default: 5050)")
    parser.add_argument("--debug", action="store_true", help="Enable Flask debug mode")
    args = parser.parse_args()
    HOST, PORT = args.host, args.port

    print(f"""
  ┌─────────────────────────────────────────┐
  │        Media Hub Anime backend          │
  │        (anipy-api providers)            │
  │  http://{HOST}:{PORT}                       │
  ├─────────────────────────────────────────┤
  │  providers: {", ".join(PROVIDER_ORDER)}          │
  │  GET /search?q=one+piece               │
  │  GET /episodes?id=anidbapp:3880        │
  │  GET /links?id=anidbapp:3880&ep=1     │
  │  GET /latest | /popular                │
  │  GET /                 (docs)          │
  └─────────────────────────────────────────┘
""")
    _warm_up()
    app.run(host=HOST, port=PORT, debug=args.debug, threaded=True)


if __name__ == "__main__":
    main()