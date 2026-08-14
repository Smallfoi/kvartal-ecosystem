"""JSON-фид импортёр — реальный, готовый к работе механизм авто-импорта.

Тянет забеги с настраиваемого URL (settings.RACES_IMPORT_FEED_URL или env
RACES_IMPORT_FEED_URL), который отдаёт JSON: либо список объектов-забегов, либо
{"races": [...]}. Поля объектов — как в normalize() (external_id/title/date/…).

Так владелец/будущий скрейпер может публиковать нормализованный фид (например,
результат отдельного парсера-воркера), а бэкенд — периодически его подхватывать,
без хрупкого HTML-скрейпинга в самом Django. Если URL не задан — импортёр молчит
(возвращает []). Без внешних зависимостей (urllib).
"""
from __future__ import annotations

import json
import urllib.request

from django.conf import settings


class JsonFeedImporter:
    source = "jsonfeed"
    label = "JSON-фид (настраиваемый URL)"

    def _url(self) -> str:
        return (getattr(settings, "RACES_IMPORT_FEED_URL", "") or "").strip()

    def fetch(self) -> list[dict]:
        url = self._url()
        if not url:
            return []
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "MATA-races-importer/1.0"})
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read().decode("utf-8"))
        except Exception:
            # Сетевые/парсинг-ошибки не валят всю задачу импорта.
            return []
        if isinstance(data, dict):
            data = data.get("races") or data.get("items") or []
        if not isinstance(data, list):
            return []
        # Пометим источник записей как jsonfeed, если внутри не указан свой.
        out = []
        for it in data:
            if isinstance(it, dict):
                out.append(it)
        return out
