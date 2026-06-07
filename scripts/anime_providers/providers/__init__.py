"""
Anime provider registry.

Usage (in server):
    import providers
    providers.get()          -> active AnimeProvider instance
    providers.switch("allanime")
    providers.list_all()     -> [{"name": "allanime", "label": "AllAnime"}, ...]
    providers.active_name()  -> "allanime"
"""

import threading

from anime_providers.providers.allanime import AllAnimeProvider
from anime_providers.providers.justalanime import JustalAnimeProvider

from anime_providers.providers.base import AnimeProvider

_REGISTRY: dict[str, type[AnimeProvider]] = {
    "allanime":    AllAnimeProvider,
    "justalanime": JustalAnimeProvider,
}

_lock   = threading.Lock()
_active: AnimeProvider = AllAnimeProvider()


def get() -> AnimeProvider:
    with _lock:
        return _active


def switch(name: str) -> None:
    global _active
    if name not in _REGISTRY:
        raise ValueError(f"Unknown provider '{name}'. Available: {list(_REGISTRY)}")
    with _lock:
        _active = _REGISTRY[name]()
    print(f"[anime-providers] Switched to '{name}'")


def active_name() -> str:
    with _lock:
        return _active.name


def list_all() -> list[dict]:
    return [
        {"name": cls.name, "label": cls.label}
        for cls in _REGISTRY.values()
    ]
