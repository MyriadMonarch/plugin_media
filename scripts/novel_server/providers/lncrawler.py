"""
LightNovelCrawler provider  –  https://github.com/lncrawl/lightnovel-crawler

Wraps the installed `lightnovel-crawler` package ("lncrawl") as a scraping
backend for the novel server. Used for FINDING novels (multi-source search)
and CRAWLING any novel/chapter URL that lncrawl supports.

Implemented:
  - search()  → lncrawl search across a curated set of fast, no-login sources
  - info()    → read_novel() via the URL of the novel page
  - chapter() → download_chapter() via the URL of the chapter page
  - hot()     → novelbuddy.me /ranking (popular list)
  - latest()  → novelbuddy.me /latest (recent updates, paged)
"""

import re
import threading

from .base import NovelProvider
from .utils import cached, clean_text, fetch, fetch_bytes

TTL_HOT   = 300
TTL_LATEST = 120
TTL_SEARCH = 600
TTL_INFO   = 1800
TTL_CHAP   = 86400

# Curated search domains: verified parsers (novel info + chapters) that are
# fast and need no login. Other lncrawl sources still work if you open a URL
# directly — see the provider's full source registry.
SEARCH_DOMAINS = [
    "novelfire.net",
    "novelbuddy.com",
]

# novelbuddy.com (used by the lncrawl source) lives on novelbuddy.me now.
# Card slugs are converted to novelbuddy.com URLs so the lncrawl source
# handles info/chapter exactly like search results.
NB_BASE = "https://novelbuddy.me"
NB_CARD_DOMAIN = "https://novelbuddy.com"

SEARCH_LIMIT  = 8
SEARCH_CONC    = 4
SEARCH_TIMEOUT = 12

_lock = threading.Lock()
_ctx  = None


def _ensure_ctx():
    """Import + initialise the lncrawl app context exactly once (offline sources)."""
    global _ctx
    if _ctx is None:
        with _lock:
            if _ctx is None:
                from lncrawl.context import ctx
                ctx.setup(log_level=40, sync_remote_index=False)
                ctx.sources.ensure_load()
                _ctx = ctx
    return _ctx


JUNK_PARAS = {
    "translate to", "previous", "next", "prev", "next chapter",
    "previous chapter", "advertisement", "ads",
}


def _paragraphs(html: str) -> list:
    if not html:
        return []
    paras = re.findall(r"<p[^>]*>([\s\S]*?)</p>", html)
    if not paras:
        text = clean_text(html)
        paras = [ln.strip() for ln in text.splitlines() if ln.strip()]
    out = []
    for raw in paras:
        if "<script" in raw or "<div" in raw:
            continue
        t = clean_text(raw).strip()
        if t and t.lower() not in JUNK_PARAS:
            out.append(t)
    return out


class LightNovelCrawlerProvider(NovelProvider):
    name  = "lncrawl"
    label = "LightNovelCrawler"

    # ── Internal helpers ──────────────────────────────────────────────────

    def _key(self, *parts) -> str:
        return f"{self.name}:" + ":".join(str(p) for p in parts)

    @staticmethod
    def _proxy(img_url: str, port: int = 5151) -> str:
        from urllib.parse import quote
        return f"http://127.0.0.1:{port}/image?url={quote(img_url, safe='')}"

    def _crawl(self, url: str):
        """Return an initialised lncrawl crawler for the URL's host."""
        ctx = _ensure_ctx()
        crawler = ctx.sources.init_crawler(url)
        return ctx, crawler

    # ── NovelProvider interface ───────────────────────────────────────────

    def search(self, query, genre=None, status="All", page=1) -> dict:
        key = self._key("search", query)
        return cached(key, TTL_SEARCH, lambda: self._search(query))

    def info(self, novel_url: str) -> dict:
        key = self._key("info", novel_url)
        return cached(key, TTL_INFO, lambda: self._info(novel_url))

    def chapter(self, chapter_url: str) -> dict:
        key = self._key("chapter", chapter_url)
        return cached(key, TTL_CHAP, lambda: self._chapter(chapter_url))

    def hot(self) -> list:
        return cached(self._key("hot"), TTL_HOT, self._hot)

    def latest(self, page: int = 1) -> dict:
        return cached(self._key("latest", page), TTL_LATEST,
                      lambda: self._latest(page))

    def fetch_image(self, url: str) -> tuple:
        return fetch_bytes(url)

    # ── NovelBuddy browsing (hot / latest) ────────────────────────────────
    #
    # /ranking and /latest both render <article class="group …"> cards:
    #   <a href="/slug">…<img src="https://rs.novelbuddy.me/covers/<slug>.webp" alt="Title"></a>
    #   <a title="Title" href="/slug"><span>Title</span></a>
    #   <a href="/slug/chapter-110"><span class="truncate">Chapter 110</span></a>

    def _nb_cards(self, html: str) -> list:
        results = []
        seen    = set()
        for block in re.finditer(
            r'<article class="group[^"]*">([\s\S]*?)</article>', html, re.S
        ):
            b = block.group(1)

            slug_m = re.search(r'href="/([a-z0-9-]+)"', b)
            if not slug_m:
                continue
            slug = slug_m.group(1)
            if slug in seen:
                continue
            seen.add(slug)

            title = ""
            title_m = re.search(
                r'title="([^"]+)"\s+href="/' + re.escape(slug) + r'"', b)
            if not title_m:
                title_m = re.search(r'aria-label="([^"]+)"', b)
            if not title_m:
                title_m = re.search(
                    r'<img[^>]*alt="([^"]+)"', b)
            if title_m:
                title = clean_text(title_m.group(1))

            img = ""
            img_m = re.search(r'<img[^>]*src="(https://rs\.novelbuddy\.me/covers/[^"]+)"', b)
            if img_m:
                img = img_m.group(1)

            latest = ""
            chap_m = re.search(
                r'href="/' + re.escape(slug) + r'/chapter-[^"]*"[^>]*>\s*<span[^>]*>([^<]+)</span>',
                b
            )
            if chap_m:
                latest = clean_text(chap_m.group(1))
            if not latest:
                count_m = re.search(r'([\d,]+)\s+chapters?', b)
                if count_m:
                    latest = count_m.group(1) + " chapters"

            results.append({
                "id":            f"{NB_CARD_DOMAIN}/{slug}",
                "title":         title or slug,
                "image":         self._proxy(img) if img else "",
                "author":        "",
                "latestChapter": latest,
                "genres":        [],
            })
        return results

    def _hot(self) -> list:
        html = fetch(f"{NB_BASE}/ranking")
        return self._nb_cards(html)

    def _latest(self, page: int) -> dict:
        url  = f"{NB_BASE}/latest" if page == 1 else f"{NB_BASE}/latest?page={page}"
        html = fetch(url)
        has_next = bool(re.search(r'href="/latest\?page=' + str(page + 1) + r'"', html))
        return {
            "results":  self._nb_cards(html),
            "hasMore":  has_next,
            "nextPage": page + 1,
        }

    # ── Search ────────────────────────────────────────────────────────────

    def _search(self, query: str) -> dict:
        from lncrawl.commands.search.helper import perform_search

        ctx = _ensure_ctx()
        sources = []
        for name in SEARCH_DOMAINS:
            sources += [
                s for s in ctx.sources.list(name, can_search=True, include_rejected=False)
            ]

        with _lock:
            groups = perform_search(
                query,
                sources,
                limit=SEARCH_LIMIT,
                concurrency=SEARCH_CONC,
                timeout=SEARCH_TIMEOUT,
            )

        results = []
        seen    = set()
        for group in groups:
            title = group.title or ""
            for n in group.novels:
                url = getattr(n, "url", "") or ""
                if not url or url in seen:
                    continue
                seen.add(url)
                results.append({
                    "id":            url,
                    "title":         title,
                    "image":         "",
                    "author":        "",
                    "latestChapter": getattr(n, "info", "") or "",
                })

        return {"results": results, "hasMore": False, "nextPage": 1}

    # ── Novel info + chapter list ─────────────────────────────────────────

    def _info(self, novel_url: str) -> dict:
        from lncrawl.core import Novel as CrawlerNovel

        _, crawler = self._crawl(novel_url)
        try:
            model = CrawlerNovel(url=novel_url)
            crawler.read_novel(model)
            crawler.format_novel(model)
        finally:
            try:
                crawler.close()
            except Exception:
                pass

        chapters = []
        for c in model.chapters or []:
            ch_num = re.search(r"(\d+(?:\.\d+)?)", c.title or "")
            chapters.append({
                "id":      c.url or "",
                "title":   c.title or "",
                "chapter": ch_num.group(1) if ch_num else (c.title or ""),
            })

        return {
            "id":          novel_url,
            "title":       model.title or "",
            "description": model.synopsis or "",
            "status":      "",
            "author":      model.author or "",
            "image":       self._proxy(model.cover_url) if model.cover_url else "",
            "genres":      model.tags or [],
            "chapters":    chapters,
        }

    # ── Chapter content ───────────────────────────────────────────────────

    def _chapter(self, chapter_url: str) -> dict:
        from lncrawl.core import Chapter as CrawlerChapter

        _, crawler = self._crawl(chapter_url)
        try:
            model = CrawlerChapter(url=chapter_url, id=0, title="")
            crawler.download_chapter(model)
            try:
                crawler.format_chapter(model)
            except Exception:
                base = chapter_url.rstrip("/").rsplit("/", 1)[-1]
                model.title = model.title or f"Chapter {re.sub(r'[^0-9.]', '', base)}"
        finally:
            try:
                crawler.close()
            except Exception:
                pass

        paragraphs = _paragraphs(model.body or "")
        if not paragraphs:
            raise RuntimeError(f"Chapter body is empty: {chapter_url}")

        # Prev/next navigation from the chapter page's nav arrows
        prev_id, next_id = "", ""
        try:
            html = fetch(chapter_url)
            base = re.match(r"https?://[^/]+", chapter_url).group(0)

            def _nav(aria: str) -> str:
                m = re.search(
                    r'<a[^>]*aria-label="' + aria + r'"[^>]*href="([^"]+)"', html
                )
                if not m:
                    return ""
                p = m.group(1)
                return p if p.startswith("http") else base + p

            prev_id = _nav("Previous chapter")
            next_id = _nav("Next chapter")
        except Exception:
            pass

        return {
            "id":         chapter_url,
            "title":      model.title or "",
            "paragraphs": paragraphs,
            "wordCount":  sum(len(p.split()) for p in paragraphs),
            "prevId":     prev_id,
            "nextId":     next_id,
        }