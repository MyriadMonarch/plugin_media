"""
Combined anime backend — merges AllAnime + AniList/Node providers.
"""

import json
import re
import urllib.parse

from flask import Flask, jsonify, request

import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from anime_providers.providers.allanime import AllAnimeProvider
from anime_providers.providers.justalanime import JustalAnimeProvider

app = Flask(__name__)

aa = AllAnimeProvider()
jl = JustalAnimeProvider()


# ── Helpers ────────────────────────────────────────────────────────────

def _norm(t: str) -> str:
    return re.sub(r"[^a-z0-9]", "", t.lower())


def quality_select(all_links: list, quality: str):
    if not all_links:
        return None
    if quality == "best":
        return all_links[0]
    if quality == "worst":
        numeric = [l for l in all_links if re.match(r"\d+", l.get("quality", ""))]
        return numeric[-1] if numeric else all_links[-1]
    matched = [l for l in all_links if quality in l.get("quality", "")]
    return matched[0] if matched else all_links[0]


# ── Routes ─────────────────────────────────────────────────────────────

@app.route("/")
def index():
    return jsonify({
        "name": "ani-cli API (combined)",
        "endpoints": {
            "GET /search":         "Search both providers, merged results",
            "GET /episodes":       "Episodes with cross-provider fallback",
            "GET /links":          "Stream links with cross-provider fallback",
            "GET /latest":         "Recently-updated (AllAnime + Node supplements)",
            "GET /popular":        "Popular (both providers merged)",
            "GET /info":           "Show info",
            "GET /nextep":         "Next episode countdown",
            "GET /health":         "Health check",
        },
    })


@app.route("/health")
def health():
    return jsonify({"status": "ok"})


@app.route("/search")
def search_route():
    q = request.args.get("q", "").strip()
    mode = request.args.get("mode", "sub").strip()
    if not q:
        return jsonify({"error": "Missing q"}), 400
    try:
        aa_results = aa.search(q, mode)
        jl_results = jl.search(q, mode)

        seen: dict[str, dict] = {}
        out = []

        for r in aa_results:
            key = _norm(r.get("english_name") or r.get("name") or "")
            if key and key not in seen:
                r["source"] = "ALLANIME"
                r["aa_id"] = r["id"]
                en = r.get("english_name") or ""
                if en:
                    r["name"] = en  # prefer English name
                seen[key] = r
                out.append(r)

        for r in jl_results:
            key = _norm(r.get("english_name") or r.get("name") or "")
            if not key:
                continue
            rid = r.get("id", "")
            # Extract aa_id from jan: prefix
            jl_aa_id = r.get("aa_id", "")
            if not jl_aa_id and rid.startswith("jan:"):
                import base64
                try:
                    dec = base64.urlsafe_b64decode(rid[4:] + "===").decode()
                    parts = dec.split("||", 2)
                    if len(parts) > 2 and parts[2]:
                        jl_aa_id = parts[2]
                except Exception:
                    pass
            if key in seen:
                # Duplicate — store the justalanime aa_id as fallback on the existing entry
                existing = seen[key]
                if jl_aa_id and not existing.get("aa_id"):
                    existing["aa_id"] = jl_aa_id
                existing["_jl_id"] = rid
                existing["_fallback_title"] = r.get("name", "")
                continue
            r["source"] = "JUSTALANIME"
            r["aa_id"] = jl_aa_id
            seen[key] = r
            out.append(r)

        return jsonify({"query": q, "mode": mode, "count": len(out), "results": out})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/info")
def info_route():
    show_id = request.args.get("id", "").strip()
    alt_id  = request.args.get("aa_id", "").strip()
    if not show_id:
        return jsonify({"error": "Missing id"}), 400
    try:
        info = {}
        if show_id.startswith("jan:"):
            info = jl.info(show_id)
        else:
            info = aa.info(show_id)
        if not info or not info.get("name"):
            if alt_id and not show_id.startswith("jan:"):
                jl_id = "jan:" + base64.b64encode(f"||{alt_id}".encode()).decode().rstrip("=")
                info = jl.info(jl_id) or info
        if not info:
            return jsonify({"error": "not found"}), 404
        return jsonify(info)
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/episodes")
def episodes_route():
    show_id = request.args.get("id", "").strip()
    mode = request.args.get("mode", "sub").strip()
    alt_id = request.args.get("aa_id", "").strip()
    if not show_id:
        return jsonify({"error": "Missing id"}), 400
    try:
        eps = []
        info = {}

        if show_id.startswith("jan:"):
            # Primary: justalanime
            try:
                eps = jl.episodes(show_id, mode)
                if eps:
                    info = jl.info(show_id)
            except Exception:
                pass
            # Fallback: extract aa_id from jan id
            if not eps:
                import base64
                try:
                    dec = base64.urlsafe_b64decode(show_id[4:] + "===").decode()
                    parts = dec.split("||", 2)
                    aa_id = parts[2] if len(parts) > 2 else ""
                    if aa_id:
                        eps = aa.episodes(aa_id, mode)
                        info = aa.info(aa_id) if eps else {}
                except Exception:
                    pass
        else:
            # Primary: allanime
            try:
                eps = aa.episodes(show_id, mode)
                if eps:
                    info = aa.info(show_id)
            except Exception:
                pass
            # Fallback: try name-based node search
            if not eps:
                try:
                    info_fb = aa.info(show_id)
                    name = info_fb.get("english_name") or info_fb.get("name") or ""
                    if name:
                        eps = jl.episodes_by_title(name, mode)
                        if eps:
                            info = info_fb
                except Exception:
                    pass

        if not info:
            info = {}
        return jsonify({
            "id": show_id, "mode": mode,
            "count": len(eps), "episodes": eps,
            "description": info.get("description", ""),
            "thumbnail": info.get("thumbnail", ""),
            "score": info.get("score"),
            "name": info.get("name", info.get("english_name", "")),
            "english_name": info.get("english_name", ""),
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/links")
def links_route():
    show_id = request.args.get("id", "").strip()
    ep_no = request.args.get("ep", "").strip()
    mode = request.args.get("mode", "sub").strip()
    quality = request.args.get("quality", "best").strip()

    if not show_id or not ep_no:
        return jsonify({"error": "Missing id or ep"}), 400

    try:
        all_links = []
        providers_map = {}

        if show_id.startswith("jan:"):
            # Primary: justalanime
            try:
                data = jl.links(show_id, ep_no, mode)
                all_links = [l for l in data.get("all_links", []) if not l.get("error")]
            except Exception:
                pass
            # Fallback: extract aa_id from jan id
            if not all_links:
                import base64
                try:
                    dec = base64.urlsafe_b64decode(show_id[4:] + "===").decode()
                    parts = dec.split("||", 2)
                    aa_id = parts[2] if len(parts) > 2 else ""
                    if aa_id:
                        all_links = [l for l in aa.links(aa_id, ep_no, mode).get("all_links", [])
                                     if not l.get("error")]
                except Exception:
                    pass
            # Fallback: try direct title slug (justalanime node API)
            if not all_links:
                try:
                    title = jl._parse_id(show_id)[0]
                    all_links = jl.links_by_title(title, ep_no, mode)
                except Exception:
                    pass
        else:
            # Primary: allanime
            try:
                all_links = [l for l in aa.links(show_id, ep_no, mode).get("all_links", [])
                             if not l.get("error")]
            except Exception:
                pass
            # Fallback: try node API with name-based search
            if not all_links:
                try:
                    info = aa.info(show_id)
                    name = info.get("english_name") or info.get("name") or ""
                    if name:
                        all_links = jl.links_by_title(name, ep_no, mode)
                except Exception:
                    pass

        for l in all_links:
            providers_map.setdefault(l.get("provider", "UNKNOWN"), []).append(l)

        result = {
            "show_id": show_id,
            "episode": ep_no,
            "mode": mode,
            "providers": providers_map,
            "all_links": all_links,
            "selected": quality_select(all_links, quality),
            "requested_quality": quality,
        }
        return jsonify(result)
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/latest")
def latest_route():
    try:
        limit = int(request.args.get("limit", 26))
        page  = int(request.args.get("page",  1))
    except ValueError:
        return jsonify({"error": "limit and page must be integers"}), 400

    mode    = request.args.get("mode",    "sub").strip()
    country = request.args.get("country", "ALL").strip()
    q       = request.args.get("q",       "").strip()

    search_dict = {"query": q} if q else None
    try:
        result = aa.latest(limit, page, mode, country, search_dict)
        aa_shows = result.get("shows", [])

        # Supplement with node popular when country is ALL and no search
        if country == "ALL" and not q:
            try:
                jl_pop = jl.popular(size=limit)
                jl_shows = jl_pop.get("shows", [])
                seen_ids = {s.get("id") for s in aa_shows}
                for s in jl_shows:
                    sid = s.get("id", "")
                    if sid and sid not in seen_ids:
                        seen_ids.add(sid)
                        s["source"] = "JUSTALANIME"
                        aa_shows.append(s)
                result["count"] = len(aa_shows)
                result["shows"] = aa_shows
            except Exception:
                pass

        return jsonify(result)
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/popular")
def popular_route():
    try:
        size       = int(request.args.get("size",       20))
        page       = int(request.args.get("page",        1))
        date_range = int(request.args.get("date_range",  1))
    except ValueError:
        return jsonify({"error": "size, page, date_range must be integers"}), 400

    def _bool(param, default=False):
        v = request.args.get(param, "").lower()
        if v in ("1", "true", "yes"): return True
        if v in ("0", "false", "no"): return False
        return default

    try:
        aa_result = aa.popular(size, page, date_range,
                                _bool("allow_adult"), _bool("allow_unknown"))
        jl_result = jl.popular(size=size, page=page)

        aa_shows = aa_result.get("shows", [])
        jl_shows = jl_result.get("shows", [])

        seen_ids = {s.get("id") for s in aa_shows}
        for s in jl_shows:
            sid = s.get("id", "")
            if sid and sid not in seen_ids:
                seen_ids.add(sid)
                s["source"] = "JUSTALANIME"
                aa_shows.append(s)

        return jsonify({
            "page": page, "size": size,
            "date_range": date_range,
            "total": len(aa_shows),
            "count": len(aa_shows),
            "shows": aa_shows,
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/nextep")
def nextep_route():
    q = request.args.get("q", "").strip()
    if not q:
        return jsonify({"error": "Missing q"}), 400
    try:
        return jsonify({"query": q, "results": aa.next_ep(q)})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=5050)
    parser.add_argument("--debug", action="store_true")
    args = parser.parse_args()

    print(f"""
  ┌─────────────────────────────────────────┐
  │     ani-cli API (combined mode)         │
  │  http://{args.host}:{args.port}              │
  │  Providers: AllAnime + AniList/Node     │
  ├─────────────────────────────────────────┤
  │  GET /search?q=solo+leveling           │
  │  GET /episodes?id=<id>                 │
  │  GET /links?id=<id>&ep=1              │
  │  GET /latest?country=JP                │
  │  GET /popular                          │
  └─────────────────────────────────────────┘
""")
    app.run(host=args.host, port=args.port, debug=args.debug)
