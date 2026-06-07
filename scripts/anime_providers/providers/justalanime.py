"""
JustalK ANIME-API provider.
Uses AniList for search/catalog and AllAnime for stream links.
"""

import base64
import json
import re
import subprocess
import threading
import time
import urllib.parse
import urllib.request
import urllib.error

from anime_providers.providers.base import AnimeProvider
from anime_providers.providers.allanime import AllAnimeProvider

NODE_API_PORT = 5051
NODE_API_URL = f"http://127.0.0.1:{NODE_API_PORT}"

_node_process: subprocess.Popen | None = None
_node_lock = threading.Lock()
_allanime: AllAnimeProvider | None = None


def _get_allanime():
    global _allanime
    if _allanime is None:
        _allanime = AllAnimeProvider()
    return _allanime


def _ensure_node_server():
    global _node_process
    with _node_lock:
        if _node_process is not None and _node_process.poll() is None:
            return
        import os
        node_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "node_api")
        server_js = os.path.join(node_dir, "server.js")
        try:
            _node_process = subprocess.Popen(
                ["node", server_js, str(NODE_API_PORT)],
                cwd=node_dir,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            for _ in range(50):
                try:
                    r = urllib.request.urlopen(f"{NODE_API_URL}/health", timeout=1)
                    if r.status == 200:
                        print(f"[justalanime] Node.js server ready on port {NODE_API_PORT}")
                        return
                except Exception:
                    pass
                time.sleep(0.1)
            print(f"[justalanime] Warning: Node.js server may not have started")
        except FileNotFoundError:
            print(f"[justalanime] WARNING: node not found")
            _node_process = None
        except Exception as e:
            print(f"[justalanime] Failed to start Node.js server: {e}")
            _node_process = None


def _node_get(path: str) -> dict:
    _ensure_node_server()
    url = f"{NODE_API_URL}{path}"
    try:
        r = urllib.request.urlopen(url, timeout=15)
        return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        try:
            return json.loads(body)
        except Exception:
            return {"error": f"HTTP {e.code}: {body[:200]}"}
    except Exception as e:
        return {"error": str(e)}


class JustalAnimeProvider(AnimeProvider):
    name = "justalanime"
    label = "ANIME-API"

    def _make_id(self, title: str, anilist_id: str, aa_id: str = "") -> str:
        data = f"{title}||{anilist_id}||{aa_id}"
        return f"jan:{base64.urlsafe_b64encode(data.encode()).decode()}"

    def _parse_id(self, show_id: str) -> tuple[str, str, str]:
        try:
            if not show_id.startswith("jan:"):
                return (show_id, "", "")
            encoded = show_id[4:]
            decoded = base64.urlsafe_b64decode(encoded).decode()
            parts = decoded.split("||", 2)
            title = parts[0]
            anilist_id = parts[1] if len(parts) > 1 else ""
            aa_id = parts[2] if len(parts) > 2 else ""
            return (title, anilist_id, aa_id)
        except Exception:
            return (show_id, "", "")

    def search(self, query: str, mode: str = "sub") -> list[dict]:
        data = _node_get(f"/search?q={urllib.parse.quote(query)}")
        if "error" in data:
            return []
        results = data.get("results", [])

        aa_results = _get_allanime().search(query, mode)
        aa_by_title: dict[str, str] = {}
        for r in aa_results:
            name = r.get("name", "").lower().strip()
            if name:
                aa_by_title[name] = r.get("id", "")

        out = []
        for r in results:
            title = r.get("title", "")
            anilist_id = r.get("id", "")
            image = r.get("image", "")
            score = r.get("score")
            eps = r.get("episodes", 0)

            aa_id = aa_by_title.get(title.lower().strip(), "")
            if not aa_id:
                alt_titles = r.get("alt_titles", []) or []
                for alt in [title.lower().replace("-", " ").replace(":", "").strip()] + [a.lower().strip() for a in alt_titles]:
                    found = aa_by_title.get(alt, "")
                    if found:
                        aa_id = found
                        break

            out.append({
                "id": self._make_id(title, anilist_id, aa_id),
                "name": title,
                "english_name": title,
                "native_name": "",
                "thumbnail": image,
                "score": score,
                "episode_count": eps,
                "available_episodes": {"sub": eps, "dub": 0, "raw": 0},
                "source": "ANILIST",
                "link": "",
                "description": r.get("description", ""),
                "genres": r.get("genres", []),
            })
        return out

    def _aa_search_by_title(self, title: str, mode: str = "sub") -> str:
        """Search AllAnime by title and return the ID of the best match."""
        try:
            aa = _get_allanime()
            results = aa.search(title, mode)
            if not results:
                return ""
            t = title.lower().strip()
            t_nospace = t.replace(" ", "")
            for r in results:
                name = r.get("name", "").lower().strip()
                rid = r.get("id", "")
                if name == t or name.replace(" ", "") == t_nospace:
                    return rid
            # First result is AllAnime's most relevant
            return results[0].get("id", "")
        except Exception:
            return ""

    def _make_slug(self, title: str) -> str:
        slug = title.lower().replace(" ", "-").replace(":", "").replace("'", "")
        slug = ''.join(c for c in slug if c.isalnum() or c == '-')
        return slug.strip('-')

    def _node_episodes(self, slug: str) -> list[str]:
        data = _node_get(f"/episodes?q={urllib.parse.quote(slug)}")
        if "error" not in data:
            eps = data.get("episodes", [])
            if eps:
                return sorted(eps, key=lambda x: int(x))
        return []

    def _node_stream_links(self, slug: str, ep_no: str) -> list[dict]:
        data = _node_get(f"/stream?q={urllib.parse.quote(slug)}&ep={ep_no}")
        if "error" not in data:
            return data.get("results", [])
        return []

    def episodes(self, show_id: str, mode: str = "sub") -> list[str]:
        title, anilist_id, aa_id = self._parse_id(show_id)
        if not aa_id:
            aa_id = self._aa_search_by_title(title, mode)
        if aa_id:
            try:
                return _get_allanime().episodes(aa_id, mode)
            except Exception:
                pass
        slug = self._make_slug(title)
        eps = self._node_episodes(slug)
        if eps:
            return eps
        # Try -tv suffix (animeflv convention)
        eps = self._node_episodes(f"{slug}-tv")
        return eps

    def links(self, show_id: str, ep_no: str, mode: str = "sub") -> dict:
        title, anilist_id, aa_id = self._parse_id(show_id)
        if not title:
            title = show_id

        all_links = []
        providers_map = {}

        if not aa_id:
            aa_id = self._aa_search_by_title(title, mode)

        if aa_id:
            try:
                data = _get_allanime().links(aa_id, ep_no, mode)
                for l in data.get("all_links", []):
                    url = l.get("url", "")
                    if not url or l.get("error"):
                        continue
                    entry = {
                        "url": url,
                        "quality": l.get("quality", "best"),
                        "type": l.get("type", "mp4"),
                        "provider": "ANIMEAPI",
                    }
                    all_links.append(entry)
                    providers_map.setdefault("ANIMEAPI", []).append(entry)
            except Exception:
                pass

        # Fallback: try Node.js stream endpoint if AllAnime gave no links
        if not all_links:
            slug = self._make_slug(title)
            for try_slug in [slug, f"{slug}-tv"]:
                try:
                    node_results = self._node_stream_links(try_slug, ep_no)
                    if node_results:
                        for r in node_results:
                            url = r.get("url", "")
                            if not url:
                                continue
                            entry = {
                                "url": url,
                                "quality": r.get("quality", "best"),
                                "type": r.get("type", "mp4"),
                                "provider": "NODEAPI",
                            }
                            all_links.append(entry)
                            providers_map.setdefault("NODEAPI", []).append(entry)
                        break  # stop trying slugs once we get results
                except Exception:
                    pass

        return {
            "show_id": show_id,
            "episode": ep_no,
            "mode": mode,
            "providers": providers_map,
            "all_links": all_links,
            "selected": all_links[0] if all_links else None,
        }

    def latest(self, limit: int = 26, page: int = 1,
               mode: str = "sub", country: str = "ALL",
               search: dict | None = None) -> dict:
        return {
            "page": page,
            "limit": limit,
            "total": 0,
            "count": 0,
            "shows": [],
        }

    def popular(self, size: int = 20, page: int = 1,
                date_range: int = 1,
                allow_adult: bool = False,
                allow_unknown: bool = False) -> dict:
        data = _node_get(f"/popular?size={size}&page={page}")
        if "error" in data:
            return {"page": page, "size": size, "date_range": date_range, "total": 0, "count": 0, "shows": []}
        shows = data.get("results", [])
        out = []
        for r in shows:
            title = r.get("title", {}).get("romaji", "") or r.get("title", {}).get("english", "") or ""
            image = (r.get("coverImage", {}) or {}).get("large", "") or (r.get("coverImage", {}) or {}).get("medium", "")
            out.append({
                "id": self._make_id(title, str(r.get("id", "")), ""),
                "name": title,
                "english_name": title,
                "native_name": "",
                "thumbnail": image,
                "score": r.get("averageScore"),
                "description": r.get("description") or "",
                "episode_count": r.get("episodes", 0),
                "available_episodes": {"sub": r.get("episodes", 0), "dub": 0, "raw": 0},
                "source": "ANILIST",
                "link": "",
            })
        return {
            "page": page,
            "size": size,
            "date_range": date_range,
            "total": len(out),
            "count": len(out),
            "shows": out,
        }

    def info(self, show_id: str) -> dict:
        title, anilist_id, aa_id = self._parse_id(show_id)
        if aa_id:
            try:
                return _get_allanime().info(aa_id)
            except Exception:
                pass
        if anilist_id:
            data = _node_get(f"/info?id={urllib.parse.quote(anilist_id)}")
            if "error" not in data:
                r = data.get("result", {})
                title = r.get("title", {}).get("romaji", "") or r.get("title", {}).get("english", "") or ""
                return {
                    "id": show_id,
                    "name": title,
                    "english_name": title,
                    "native_name": "",
                    "thumbnail": (r.get("coverImage", {}) or {}).get("large", "") or "",
                    "description": re.sub(r"<[^>]*>", "", r.get("description", "") or ""),
                    "score": r.get("averageScore"),
                    "episode_count": r.get("episodes", 0),
                }
        if title:
            aa_id = self._aa_search_by_title(title)
            if aa_id:
                try:
                    return _get_allanime().info(aa_id)
                except Exception:
                    pass
        return {}

    def next_ep(self, query: str) -> list[dict]:
        return []

    # ── Plain-title helpers (bypass jan: ID parsing) ─────────────────────

    def episodes_by_title(self, title: str, mode: str = "sub") -> list[str]:
        """Fetch episodes using slug-based Node API fallback only."""
        slug = self._make_slug(title)
        eps = self._node_episodes(slug)
        if eps:
            return eps
        return self._node_episodes(f"{slug}-tv")

    def links_by_title(self, title: str, ep_no: str, mode: str = "sub") -> list[dict]:
        """Fetch stream links using slug-based Node API fallback only."""
        slug = self._make_slug(title)
        for try_slug in [slug, f"{slug}-tv"]:
            results = self._node_stream_links(try_slug, ep_no)
            if results:
                return results
        return []
