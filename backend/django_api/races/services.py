"""Логика авто-импорта забегов: прогнать импортёры и upsert по (source, external_id).

Идемпотентно: повторный импорт того же external_id обновляет запись, а не плодит
дубликаты (UniqueConstraint(source, external_id) на модели). Ручные записи
(source="manual") НЕ трогаем — обновляем только строки своего источника.
"""
from __future__ import annotations

import logging

from .importers import get_importers
from .importers.base import normalize
from .models import Race

logger = logging.getLogger(__name__)


def _blank_stats() -> dict:
    return {"created": 0, "updated": 0, "skipped": 0, "errors": 0}


def run_import(sources=None, dry_run: bool = False) -> dict:
    """Запустить импортёры и записать забеги. Возвращает статистику по источникам."""
    total = _blank_stats()
    per_source: dict[str, dict] = {}

    for imp in get_importers(sources):
        s = _blank_stats()
        try:
            raw_items = imp.fetch()
        except Exception as exc:  # источник упал целиком — не валим остальные
            logger.warning("races import: источник %s упал: %s", imp.source, exc)
            s["errors"] += 1
            per_source[imp.source] = s
            _accumulate(total, s)
            continue

        for raw in raw_items or []:
            item = normalize(raw)
            if item is None:
                s["skipped"] += 1
                continue
            if dry_run:
                s["skipped"] += 1
                continue
            try:
                external_id = item.pop("external_id")
                _, created = Race.objects.update_or_create(
                    source=imp.source,
                    external_id=external_id,
                    defaults={**item, "is_published": True},
                )
                s["created" if created else "updated"] += 1
            except Exception as exc:
                logger.warning("races import: запись пропущена (%s): %s", imp.source, exc)
                s["errors"] += 1

        per_source[imp.source] = s
        _accumulate(total, s)

    total["sources"] = per_source
    return total


def _accumulate(total: dict, s: dict) -> None:
    for k in ("created", "updated", "skipped", "errors"):
        total[k] += s[k]
