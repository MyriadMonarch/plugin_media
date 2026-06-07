"""
Base provider interface for anime sources.
"""

from abc import ABC, abstractmethod


class AnimeProvider(ABC):
    name: str = ""
    label: str = ""

    @abstractmethod
    def search(self, query: str, mode: str = "sub") -> list[dict]:
        """
        Returns list of show dicts with at least:
            { id, name, englishName, nativeName, thumbnail, score,
              episodeCount, availableEpisodes: {sub, dub, raw} }
        """

    @abstractmethod
    def episodes(self, show_id: str, mode: str = "sub") -> list[str]:
        """Return sorted list of episode strings."""

    @abstractmethod
    def links(self, show_id: str, ep_no: str, mode: str = "sub") -> dict:
        """
        Returns {
            show_id, episode, mode,
            providers: {name: [links]},
            all_links: [{url, quality, type, provider, ...}],
            selected: best-link
        }
        """

    @abstractmethod
    def latest(self, limit: int = 26, page: int = 1,
               mode: str = "sub", country: str = "ALL",
               search: dict | None = None) -> dict:
        """
        Returns { page, limit, total, count,
                  shows: [show_dict, ...] }
        """

    @abstractmethod
    def popular(self, size: int = 20, page: int = 1,
                date_range: int = 1,
                allow_adult: bool = False,
                allow_unknown: bool = False) -> dict:
        """
        Returns { page, size, date_range, total, count,
                  shows: [show_dict, ...] }
        """

    def info(self, show_id: str) -> dict:
        """Optional: full show info (description, thumbnail, etc). Returns empty dict if not implemented."""
        return {}

    def next_ep(self, query: str) -> list[dict]:
        """Optional: next episode countdown."""
        return []
