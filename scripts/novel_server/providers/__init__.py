"""
Provider registry.

Usage (in server.py):
    import providers
    providers.get()          → active NovelProvider instance
    providers.switch("freewebnovel")
    providers.list_all()     → [{"name": "freewebnovel", "label": "FreeWebNovel"}, ...]
    providers.active_name()  → "freewebnovel"

ID namespacing
──────────────
Every novel/chapter ID that crosses the HTTP boundary is prefixed with the
provider name so that favorites and downloads never collide across sources:

    Internal (provider sees):   "novel/some-slug"
    External (client sees):     "freewebnovel:novel/some-slug"

Helper functions strip/add the prefix transparently. Unknown prefixes are
tolerated (kept as-is) so records saved in the past still load.
"""

import threading

from .freewebnovel import FreeWebNovelProvider
from .lncrawler import LightNovelCrawlerProvider

from .base import NovelProvider

# ── Registry ───────────────────────────────────────────────────────────────
# Add new providers here: name → class
_REGISTRY: dict[str, type[NovelProvider]] = {
    "freewebnovel": FreeWebNovelProvider,
    "lncrawl":      LightNovelCrawlerProvider,
}

_lock   = threading.Lock()
_active: NovelProvider = LightNovelCrawlerProvider()   # default on startup


# ── Public API ─────────────────────────────────────────────────────────────

def get() -> NovelProvider:
    """Return the currently active provider instance."""
    with _lock:
        return _active


def switch(name: str) -> None:
    """Switch the active provider. Raises ValueError for unknown names."""
    global _active
    if name not in _REGISTRY:
        raise ValueError(f"Unknown provider '{name}'. Available: {list(_REGISTRY)}")
    with _lock:
        _active = _REGISTRY[name]()
    print(f"[providers] Switched to '{name}'")


def active_name() -> str:
    with _lock:
        return _active.name


def list_all() -> list[dict]:
    return [
        {"name": cls.name, "label": cls.label}
        for cls in _REGISTRY.values()
    ]


def candidates() -> list:
    """Provider instances ordered: active first, then every other one (for fallback)."""
    with _lock:
        names = [_active.name] + [n for n in _REGISTRY if n != _active.name]
    return [_REGISTRY[n]() for n in names]


def browse(method: str, *args, require_results: bool = False):
    """
    Call <method>(*args) on the active provider, falling back to any other
    registered provider when it fails (dead sources happen) or — when
    require_results is set — when it returns no content (empty lists/dicts).
    Returns (provider, data) so the caller can prefix IDs correctly.
    """
    last_error: Exception | None = None
    active_result = None
    for p in candidates():
        try:
            result = getattr(p, method)(*args)
        except Exception as e:
            last_error = e
            print(f"[providers] {p.name}.{method} failed: {e}")
            continue
        if active_result is None:
            active_result = (p, result)
        if not require_results or _has_content(result):
            return p, result
    if active_result is not None:
        return active_result
    if last_error:
        raise last_error
    raise RuntimeError(f"No provider available for '{method}'")


def _has_content(result) -> bool:
    if isinstance(result, list):
        return len(result) > 0
    if isinstance(result, dict):
        return bool(result.get("results"))
    return result is not None


# ── ID namespacing helpers ─────────────────────────────────────────────────

def prefix_id(raw_id: str, provider_name: str | None = None) -> str:
    """
    Add a provider prefix to a raw ID.
    "novel/some-slug"  →  "freewebnovel:novel/some-slug"
    """
    pname = provider_name or active_name()
    if raw_id.startswith(f"{pname}:"):
        return raw_id          # already prefixed
    return f"{pname}:{raw_id}"


def strip_prefix(prefixed_id: str) -> tuple[str, str]:
    """
    Split a prefixed ID into (provider_name, raw_id).
    "freewebnovel:novel/some-slug"  →  ("freewebnovel", "novel/some-slug")
    Unknown prefixes are tolerated — the raw remainder is returned as-is so
    records from removed providers (e.g. novelbin) still load.
    """
    parts = prefixed_id.split(":", 1)
    if len(parts) != 2 or not parts[0] or not parts[1]:
        return "", prefixed_id
    return parts[0], parts[1]


def provider_for(prefixed_id: str) -> NovelProvider:
    """
    Return the provider instance that owns this prefixed ID.
    Instantiates a fresh instance each call so the active provider is unaffected.
    """
    pname, _ = strip_prefix(prefixed_id)
    if pname not in _REGISTRY:
        raise ValueError(f"Unknown provider '{pname}'. Available: {list(_REGISTRY)}")
    return _REGISTRY[pname]()