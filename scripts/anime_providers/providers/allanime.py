"""
AllAnime provider — scrapes allanime.day for anime search, episodes, and stream links.
"""

import base64
import hashlib
import json
import re
import subprocess
import urllib.parse
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests

from anime_providers.providers.base import AnimeProvider

AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0"
ALLANIME_REFR = "https://allmanga.to"
ALLANIME_BASE = "allanime.day"
ALLANIME_API = f"https://api.{ALLANIME_BASE}"
ALLANIME_KEY = hashlib.sha256(b"Xot36i3lK3:v1").hexdigest()

HEADERS = {
    "User-Agent": AGENT,
    "Referer": ALLANIME_REFR,
}

GQL_HEADERS = {
    "User-Agent": AGENT,
    "Referer": ALLANIME_REFR,
    "Content-Type": "application/json",
}

HEX_MAP = {
    "79": "A", "7a": "B", "7b": "C", "7c": "D", "7d": "E", "7e": "F", "7f": "G",
    "70": "H", "71": "I", "72": "J", "73": "K", "74": "L", "75": "M", "76": "N",
    "77": "O", "68": "P", "69": "Q", "6a": "R", "6b": "S", "6c": "T", "6d": "U",
    "6e": "V", "6f": "W", "60": "X", "61": "Y", "62": "Z",
    "59": "a", "5a": "b", "5b": "c", "5c": "d", "5d": "e", "5e": "f", "5f": "g",
    "50": "h", "51": "i", "52": "j", "53": "k", "54": "l", "55": "m", "56": "n",
    "57": "o", "48": "p", "49": "q", "4a": "r", "4b": "s", "4c": "t", "4d": "u",
    "4e": "v", "4f": "w", "40": "x", "41": "y", "42": "z",
    "08": "0", "09": "1", "0a": "2", "0b": "3", "0c": "4", "0d": "5",
    "0e": "6", "0f": "7", "00": "8", "01": "9",
    "15": "-", "16": ".", "67": "_", "46": "~", "02": ":", "17": "/",
    "07": "?", "1b": "#", "63": "[", "65": "]", "78": "@", "19": "!",
    "1c": "$", "1e": "&", "10": "(", "11": ")", "12": "*", "13": "+",
    "14": ",", "03": ";", "05": "=", "1d": "%",
}


ALLANIME_WEB = f"https://{ALLANIME_BASE}"

def _abs_thumb(url: str | None) -> str:
    if url and not url.startswith("http"):
        return f"{ALLANIME_WEB}/{url.lstrip('/')}"
    return url or ""


def decode_provider_url(encoded: str) -> str:
    pairs = [encoded[i:i+2] for i in range(0, len(encoded), 2)]
    result = "".join(HEX_MAP.get(p, p) for p in pairs)
    result = result.replace("/clock", "/clock.json")
    return result


def gql_post(variables: dict, query: str) -> str:
    payload = json.dumps({"variables": variables, "query": query})
    resp = requests.post(
        f"{ALLANIME_API}/api",
        data=payload,
        headers=GQL_HEADERS,
        timeout=15,
    )
    resp.raise_for_status()
    return resp.text


SEARCH_GQL = (
    "query( $search: SearchInput $limit: Int $page: Int "
    "$translationType: VaildTranslationTypeEnumType "
    "$countryOrigin: VaildCountryOriginEnumType ) { "
    "shows( search: $search limit: $limit page: $page "
    "translationType: $translationType countryOrigin: $countryOrigin ) "
    "{ edges { _id name englishName nativeName thumbnail score "
    "description availableEpisodes episodeCount __typename } }}"
)


def search_anime(query: str, mode: str = "sub") -> list[dict]:
    variables = {
        "search": {
            "allowAdult": False,
            "allowUnknown": False,
            "query": query,
        },
        "limit": 40,
        "page": 1,
        "translationType": mode,
        "countryOrigin": "ALL",
    }
    payload = json.dumps({"variables": variables, "query": SEARCH_GQL})
    resp = requests.post(
        f"{ALLANIME_API}/api",
        data=payload,
        headers=GQL_HEADERS,
        timeout=15,
    )
    resp.raise_for_status()
    data = resp.json()
    edges = data.get("data", {}).get("shows", {}).get("edges", [])
    results = []
    seen = set()
    for edge in edges:
        show_id = edge.get("_id")
        if not show_id or show_id in seen:
            continue
        seen.add(show_id)
        available = edge.get("availableEpisodes") or {}
        results.append({
            "id": show_id,
            "name": edge.get("name"),
            "english_name": edge.get("englishName"),
            "native_name": edge.get("nativeName"),
            "thumbnail": _abs_thumb(edge.get("thumbnail")),
            "score": edge.get("score"),
            "description": edge.get("description") or "",
            "episode_count": edge.get("episodeCount"),
            "available_episodes": {
                "sub": available.get("sub", 0),
                "dub": available.get("dub", 0),
                "raw": available.get("raw", 0),
            },
        })
    return results


EPISODES_LIST_GQL = (
    "query ($showId: String!) { show( _id: $showId ) { _id availableEpisodesDetail }}"
)


def episodes_list(show_id: str, mode: str = "sub") -> list[str]:
    payload = json.dumps({
        "variables": {"showId": show_id},
        "query": EPISODES_LIST_GQL,
    })
    resp = requests.post(
        f"{ALLANIME_API}/api",
        data=payload,
        headers=GQL_HEADERS,
        timeout=15,
    )
    resp.raise_for_status()
    raw = resp.text
    m = re.search(r'"' + mode + r'\":\[([0-9.\",]*)\]', raw)
    if not m:
        return []
    eps_raw = m.group(1)
    eps = [e.strip('"') for e in eps_raw.split(",") if e.strip('"')]
    try:
        eps.sort(key=lambda x: float(x))
    except ValueError:
        eps.sort()
    return eps


EPISODE_EMBED_GQL = (
    "query ($showId: String!, $translationType: VaildTranslationTypeEnumType!, "
    "$episodeString: String!) { episode( showId: $showId translationType: $translationType "
    "episodeString: $episodeString ) { episodeString sourceUrls }}"
)

SHOW_INFO_GQL = (
    "query ($showId: String!) { show( _id: $showId ) "
    "{ _id name englishName nativeName thumbnail description "
    "score availableEpisodes episodeCount } }"
)

PROVIDER_PATTERNS = {
    "wixmp":      r"Default\s*:([^\n]+)",
    "youtube":    r"Yt-mp4\s*:([^\n]+)",
    "sharepoint": r"S-mp4\s*:([^\n]+)",
    "filemoon":   r"Fm-mp4\s*:([^\n]+)",
    "hianime":    r"Luf-Mp4\s*:([^\n]+)",
}


def _extract_provider_id(resp_normalized: str, pattern: str) -> str | None:
    m = re.search(pattern, resp_normalized)
    if not m:
        return None
    encoded = m.group(1).strip()
    return decode_provider_url(encoded)


def b64url_to_hex(s: str) -> str:
    pad = {2: "==", 3: "=", 0: "", 1: ""}
    padded = s + pad[len(s) % 4]
    padded = padded.replace("-", "+").replace("_", "/")
    return base64.b64decode(padded).hex()


def get_filemoon_links(path: str) -> list[dict]:
    url = f"https://{ALLANIME_BASE}{path}"
    try:
        resp = requests.get(url, headers=HEADERS, timeout=15)
        resp.raise_for_status()
        raw = resp.text
    except Exception as e:
        return [{"error": str(e), "url": url}]
    try:
        data = json.loads(raw)
        iv = data.get("iv", "")
        payload = data.get("payload", "")
        key_parts = data.get("key_parts", [])
        if len(key_parts) < 2 or not iv or not payload:
            return [{"error": "Missing filemoon decryption fields"}]
        kp1_hex = b64url_to_hex(key_parts[0])
        kp2_hex = b64url_to_hex(key_parts[1])
        key_hex = kp1_hex + kp2_hex
        iv_hex = b64url_to_hex(iv) + "00000002"
        payload_pad = {2: "==", 3: "=", 0: "", 1: ""}
        payload_padded = payload + payload_pad[len(payload) % 4]
        payload_padded = payload_padded.replace("-", "+").replace("_", "/")
        payload_bytes = base64.b64decode(payload_padded)
        ct_bytes = payload_bytes[:-16]
        result = subprocess.run(
            [
                "openssl", "enc", "-d", "-aes-256-ctr",
                "-K", key_hex,
                "-iv", iv_hex,
                "-nosalt", "-nopad",
            ],
            input=ct_bytes,
            capture_output=True,
            timeout=10,
        )
        plain = result.stdout.decode("utf-8", errors="replace")
        links = []
        for chunk in re.split(r"[{}\[\]]", plain):
            m = re.search(r'"url":"([^"]*)".*?"height":(\d+)', chunk)
            if not m:
                m = re.search(r'"height":(\d+).*?"url":"([^"]*)"', chunk)
                if m:
                    height, stream_url = m.group(1), m.group(2)
                else:
                    continue
            else:
                stream_url, height = m.group(1), m.group(2)
            stream_url = stream_url.replace("\\u0026", "&").replace("\\u003D", "=")
            links.append({"quality": f"{height}p", "url": stream_url, "type": "mp4"})
        links.sort(key=lambda x: int(re.match(r"(\d+)", x.get("quality", "0")).group(1)) if re.match(r"(\d+)", x.get("quality", "0")) else 0, reverse=True)
        return links
    except Exception as e:
        return [{"error": f"Filemoon decryption failed: {e}"}]


def _get_links_from_url(path: str) -> list[dict]:
    url = path if path.startswith("http") else f"https://{ALLANIME_BASE}{path}"
    try:
        resp = requests.get(url, headers=HEADERS, timeout=15)
        resp.raise_for_status()
        raw = resp.text
    except Exception as e:
        return [{"error": str(e), "url": url}]
    links = []
    if "repackager.wixmp.com" in raw:
        for m in re.finditer(r'"link":"([^"]*repackager\.wixmp\.com[^"]*)".*?"resolutionStr":"([^"]*)"', raw):
            links.append({"quality": m.group(2), "url": m.group(1), "type": "mp4"})
        return links
    if "master.m3u8" in raw:
        m_url = re.search(r'"url":"([^"]*master\.m3u8[^"]*)"', raw)
        m_refr = re.search(r'"Referer":"([^"]*)"', raw)
        subtitle_m = re.search(r'"subtitles":\[.*?"lang":"en".*?"src":"([^"]*)"', raw)
        referer = m_refr.group(1) if m_refr else ALLANIME_REFR
        subtitle = subtitle_m.group(1) if subtitle_m else None
        if m_url:
            m3u8_url = m_url.group(1)
            try:
                m3u8_resp = requests.get(m3u8_url, headers={**HEADERS, "Referer": referer}, timeout=15)
                m3u8_text = m3u8_resp.text
                base = m3u8_url.rsplit("/", 1)[0] + "/"
                stream_re = re.compile(r'#EXT-X-STREAM-INF[^\n]*RESOLUTION=\d+x(\d+)[^\n]*\n([^\n]+)')
                for sm in stream_re.finditer(m3u8_text):
                    height = sm.group(1)
                    stream_path = sm.group(2).strip()
                    stream_url = stream_path if stream_path.startswith("http") else base + stream_path
                    links.append({
                        "quality": f"{height}p",
                        "url": stream_url,
                        "type": "m3u8",
                        "referer": referer,
                        **({"subtitle": subtitle} if subtitle else {}),
                    })
                if not links:
                    links.append({"quality": "best", "url": m3u8_url, "type": "m3u8", "referer": referer})
            except Exception as e:
                links.append({"quality": "best", "url": m3u8_url, "type": "m3u8",
                               "referer": referer, "parse_error": str(e)})
        return links
    for m in re.finditer(r'"link":"([^"]*)".*?"resolutionStr":"([^"]*)"', raw):
        links.append({"quality": m.group(2), "url": m.group(1), "type": "mp4"})
    if "tools.fast4speed.rsvp" in path:
        links.append({"quality": "best", "url": url, "type": "yt", "referer": ALLANIME_REFR})
    return links


def decode_tobeparsed(blob: str) -> dict[str, str]:
    try:
        data = base64.b64decode(blob)
    except Exception:
        return {}
    iv_bytes = data[1:13]
    ciphertext = data[13:-16]
    ctr_hex = iv_bytes.hex() + "00000002"
    try:
        result = subprocess.run(
            [
                "openssl", "enc", "-d", "-aes-256-ctr",
                "-K", ALLANIME_KEY,
                "-iv", ctr_hex,
                "-nosalt", "-nopad",
            ],
            input=ciphertext,
            capture_output=True,
            timeout=10,
        )
        plain = result.stdout.decode("utf-8", errors="replace")
    except Exception:
        return {}
    sources: dict[str, str] = {}
    for chunk in re.split(r"[{}]", plain):
        m = re.search(r'"sourceUrl":"--([^"]*)".*"sourceName":"([^"]*)"', chunk)
        if m:
            enc_path, name = m.group(1), m.group(2)
            sources[name] = enc_path
    return sources


EPISODE_QUERY_HASH = "d405d0edd690624b66baba3068e0edc3ac90f1597d898a1ec8db4e5c43c00fec"


def get_episode_links(show_id: str, ep_no: str, mode: str = "sub") -> dict:
    query_vars = json.dumps({
        "showId": show_id,
        "translationType": mode,
        "episodeString": ep_no,
    })
    query_ext = json.dumps({
        "persistedQuery": {
            "version": 1,
            "sha256Hash": EPISODE_QUERY_HASH,
        }
    })
    get_headers = {
        "User-Agent": AGENT,
        "Referer": "https://youtu-chan.com",
        "Origin": "https://youtu-chan.com",
    }
    try:
        get_resp = requests.get(
            f"{ALLANIME_API}/api",
            params={"variables": query_vars, "extensions": query_ext},
            headers=get_headers,
            timeout=15,
        )
        get_resp.raise_for_status()
        raw = get_resp.text
    except Exception:
        raw = ""
    if not raw or "tobeparsed" not in raw:
        payload = json.dumps({
            "variables": {
                "showId": show_id,
                "translationType": mode,
                "episodeString": ep_no,
            },
            "query": EPISODE_EMBED_GQL,
        })
        resp = requests.post(
            f"{ALLANIME_API}/api",
            data=payload,
            headers=GQL_HEADERS,
            timeout=15,
        )
        resp.raise_for_status()
        raw = resp.text
    if '"tobeparsed"' in raw:
        blob_m = re.search(r'"tobeparsed":"([^"]*)"', raw)
        if blob_m:
            enc_sources = decode_tobeparsed(blob_m.group(1))
            sources = {name: decode_provider_url(enc) for name, enc in enc_sources.items()}
        else:
            sources = {}
    else:
        raw_norm = raw.replace("\\u002F", "/").replace("\\|", "")
        source_re = re.compile(r'sourceUrl":"--([^"]+)"[^}]*sourceName":"([^"]+)"')
        sources = {}
        for m in source_re.finditer(raw_norm):
            encoded_url, name = m.group(1), m.group(2)
            sources[name] = decode_provider_url(encoded_url)
    if not sources:
        return {"error": "No sources found for this episode", "raw_snippet": raw[:500]}
    provider_results = {}

    def fetch_provider(name, path):
        if name.lower() in ("fm-mp4", "filemoon") or "Fm-mp4" in name:
            return name, get_filemoon_links(path)
        return name, _get_links_from_url(path)

    with ThreadPoolExecutor(max_workers=6) as pool:
        futures = {pool.submit(fetch_provider, n, p): n for n, p in sources.items()}
        for future in as_completed(futures):
            pname, links = future.result()
            provider_results[pname] = links
    all_links = []
    for pname, links in provider_results.items():
        for link in links:
            if "error" not in link:
                all_links.append({**link, "provider": pname})

    def quality_key(x):
        q = x.get("quality", "")
        m = re.match(r"(\d+)", q)
        return int(m.group(1)) if m else 0

    all_links.sort(key=quality_key, reverse=True)
    return {
        "show_id": show_id,
        "episode": ep_no,
        "mode": mode,
        "providers": provider_results,
        "all_links": all_links,
    }


LATEST_QUERY_HASH = "a24c500a1b765c68ae1d8dd85174931f661c71369c89b92b88b75a725afc471c"


def _parse_latest_show(edge: dict) -> dict:
    last_ep_info = edge.get("lastEpisodeInfo", {})
    last_ep_date = edge.get("lastEpisodeDate", {})
    available = edge.get("availableEpisodes", {})
    season = edge.get("season") or {}
    aired = edge.get("airedStart") or {}

    def ep_str(mode: str) -> str | None:
        info = last_ep_info.get(mode)
        return info.get("episodeString") if info else None

    def ep_date(mode: str) -> dict | None:
        d = last_ep_date.get(mode)
        return d if d else None

    return {
        "id": edge.get("_id"),
        "name": edge.get("name"),
        "english_name": edge.get("englishName"),
        "native_name": edge.get("nativeName"),
        "type": edge.get("type"),
        "thumbnail": _abs_thumb(edge.get("thumbnail")),
        "score": edge.get("score"),
        "episode_count": edge.get("episodeCount"),
        "episode_duration_ms": edge.get("episodeDuration"),
        "available_episodes": {
            "sub": available.get("sub", 0),
            "dub": available.get("dub", 0),
            "raw": available.get("raw", 0),
        },
        "last_episode": {
            "sub": ep_str("sub"),
            "dub": ep_str("dub"),
        },
        "last_episode_date": {
            "sub": ep_date("sub"),
            "dub": ep_date("dub"),
        },
        "season": {
            "quarter": season.get("quarter"),
            "year": season.get("year"),
        },
        "aired_start": aired if aired else None,
        "last_update": edge.get("lastUpdateEnd"),
    }


def latest_shows(
    limit: int = 26,
    page: int = 1,
    mode: str = "sub",
    country: str = "ALL",
    search: dict | None = None,
) -> dict:
    variables = {
        "search": search or {},
        "limit": limit,
        "page": page,
        "translationType": mode,
        "countryOrigin": country,
    }
    params = {
        "variables": json.dumps(variables),
        "extensions": json.dumps({
            "persistedQuery": {
                "version": 1,
                "sha256Hash": LATEST_QUERY_HASH,
            }
        }),
    }
    resp = requests.get(
        f"{ALLANIME_API}/api",
        params=params,
        headers=HEADERS,
        timeout=15,
    )
    resp.raise_for_status()
    data = resp.json()
    shows_data = (
        data.get("data", {}).get("shows", {})
        if isinstance(data, dict)
        else {}
    )
    total = shows_data.get("pageInfo", {}).get("total", 0)
    edges = shows_data.get("edges", [])
    return {
        "page": page,
        "limit": limit,
        "total": total,
        "count": len(edges),
        "shows": [_parse_latest_show(e) for e in edges],
    }


POPULAR_QUERY_HASH = "60f50b84bb545fa25ee7f7c8c0adbf8f5cea40f7b1ef8501cbbff70e38589489"


def _parse_popular_show(rec: dict) -> dict:
    card = rec.get("anyCard") or {}
    status = rec.get("pageStatus") or {}
    last_ep_date = card.get("lastEpisodeDate") or {}
    available = card.get("availableEpisodes") or {}
    aired = card.get("airedStart") or {}

    def ep_date(mode: str) -> dict | None:
        d = last_ep_date.get(mode)
        return d if d else None

    return {
        "id": card.get("_id"),
        "name": card.get("name"),
        "english_name": card.get("englishName"),
        "native_name": card.get("nativeName"),
        "thumbnail": _abs_thumb(card.get("thumbnail")),
        "score": card.get("score"),
        "available_episodes": {
            "sub": available.get("sub", 0),
            "dub": available.get("dub", 0),
            "raw": available.get("raw", 0),
        },
        "last_episode_date": {
            "sub": ep_date("sub"),
            "dub": ep_date("dub"),
        },
        "aired_start": aired if aired else None,
        "views": {
            "total": status.get("views"),
            "range": status.get("rangeViews"),
        },
        "is_manga": status.get("isManga"),
    }


def popular_shows(
    size: int = 20,
    page: int = 1,
    date_range: int = 1,
    allow_adult: bool = False,
    allow_unknown: bool = False,
) -> dict:
    variables = {
        "type": "anime",
        "size": size,
        "dateRange": date_range,
        "page": page,
        "allowAdult": allow_adult,
        "allowUnknown": allow_unknown,
    }
    params = {
        "variables": json.dumps(variables),
        "extensions": json.dumps({
            "persistedQuery": {
                "version": 1,
                "sha256Hash": POPULAR_QUERY_HASH,
            }
        }),
    }
    resp = requests.get(
        f"{ALLANIME_API}/api",
        params=params,
        headers=HEADERS,
        timeout=15,
    )
    resp.raise_for_status()
    data = resp.json() if isinstance(resp.json(), dict) else {}
    popular_data = data.get("data", {}).get("queryPopular", {})
    total = popular_data.get("total", 0)
    recommendations = popular_data.get("recommendations", [])
    return {
        "page": page,
        "size": size,
        "date_range": date_range,
        "total": total,
        "count": len(recommendations),
        "shows": [_parse_popular_show(r) for r in recommendations],
    }


def show_info(show_id: str) -> dict:
    """Fetch full show info including description."""
    payload = json.dumps({
        "variables": {"showId": show_id},
        "query": SHOW_INFO_GQL,
    })
    resp = requests.post(
        f"{ALLANIME_API}/api",
        data=payload,
        headers=GQL_HEADERS,
        timeout=15,
    )
    resp.raise_for_status()
    data = resp.json()
    show = data.get("data", {}).get("show") or {}
    available = show.get("availableEpisodes") or {}
    return {
        "id": show.get("_id", show_id),
        "name": show.get("name") or "",
        "english_name": show.get("englishName") or "",
        "native_name": show.get("nativeName") or "",
        "thumbnail": _abs_thumb(show.get("thumbnail") or ""),
        "description": show.get("description") or "",
        "score": show.get("score"),
        "episode_count": show.get("episodeCount"),
        "available_episodes": {
            "sub": available.get("sub", 0),
            "dub": available.get("dub", 0),
            "raw": available.get("raw", 0),
        },
    }


def next_ep_countdown(query: str) -> list[dict]:
    base = "https://animeschedule.net"
    q = query.replace(" ", "+")
    try:
        r = requests.get(f"{base}/api/v3/anime", params={"q": q}, headers=HEADERS, timeout=15)
        r.raise_for_status()
        raw = r.text
    except Exception as e:
        return [{"error": str(e)}]
    routes = re.findall(r'"route":"([^"]+)"', raw)
    results = []
    for route in routes:
        try:
            page = requests.get(f"{base}/anime/{route}", headers=HEADERS, timeout=15)
            text = page.text
            next_raw = re.search(r'countdown-time-raw"[^>]*datetime="([^"]*)"', text)
            next_sub = re.search(r'countdown-time"[^>]*datetime="([^"]*)"', text)
            eng_title = re.search(r'english-title">([^<]*)<', text)
            jp_title = re.search(r'main-title"[^>]*>([^<]*)<', text)
            results.append({
                "route": route,
                "english_title": eng_title.group(1) if eng_title else None,
                "japanese_title": jp_title.group(1) if jp_title else None,
                "next_raw_release": next_raw.group(1) if next_raw else None,
                "next_sub_release": next_sub.group(1) if next_sub else None,
                "status": "Ongoing" if next_raw else "Finished",
            })
        except Exception as e:
            results.append({"route": route, "error": str(e)})
    return results


class AllAnimeProvider(AnimeProvider):
    name = "allanime"
    label = "AllAnime"

    def search(self, query: str, mode: str = "sub") -> list[dict]:
        return search_anime(query, mode)

    def episodes(self, show_id: str, mode: str = "sub") -> list[str]:
        return episodes_list(show_id, mode)

    def links(self, show_id: str, ep_no: str, mode: str = "sub") -> dict:
        return get_episode_links(show_id, ep_no, mode)

    def latest(self, limit: int = 26, page: int = 1,
               mode: str = "sub", country: str = "ALL",
               search: dict | None = None) -> dict:
        return latest_shows(limit=limit, page=page, mode=mode,
                            country=country, search=search)

    def popular(self, size: int = 20, page: int = 1,
                date_range: int = 1,
                allow_adult: bool = False,
                allow_unknown: bool = False) -> dict:
        return popular_shows(size=size, page=page, date_range=date_range,
                             allow_adult=allow_adult, allow_unknown=allow_unknown)

    def info(self, show_id: str) -> dict:
        return show_info(show_id)

    def next_ep(self, query: str) -> list[dict]:
        return next_ep_countdown(query)
