"""Базовый интерфейс импортёра забегов для авто-парсера «Стартов».

Каждый источник (сайт-агрегатор, JSON-фид и т.п.) — отдельный импортёр: знает,
как получить список забегов и вернуть их в НОРМАЛИЗОВАННОМ виде (список dict с
полями модели Race). Дедупликация/upsert — по ключу (source, external_id) в
services.run_import(). Так добавление нового источника = новый класс-импортёр,
без изменения остальной логики.
"""
from __future__ import annotations

import datetime as dt


class RaceImporter:
    """Интерфейс импортёра. Наследники реализуют fetch()."""

    #: короткий код источника, попадает в Race.source (для дедупа и фильтра в админке)
    source = "base"
    #: человекочитаемое имя (для логов/админки)
    label = "Базовый импортёр"

    def fetch(self) -> list[dict]:
        """Вернуть список нормализованных забегов (dict). См. normalize()/поля модели.

        ОБЯЗАТЕЛЬНЫЕ поля каждого dict: external_id (уникален в рамках источника),
        title, date (ISO-строка «YYYY-MM-DD» или date). Остальные — по возможности.
        Сетевые ошибки лучше глушить внутри и возвращать [], чтобы не валить всю задачу.
        """
        raise NotImplementedError


def parse_date(value) -> dt.date | None:
    """Строка «YYYY-MM-DD»/date → date. Некорректное → None."""
    if isinstance(value, dt.date):
        return value
    if not value:
        return None
    try:
        return dt.date.fromisoformat(str(value)[:10])
    except (ValueError, TypeError):
        return None


# Разрешённые типы забега (совпадают с Race.TYPE_CHOICES); прочее → "other".
_ALLOWED_TYPES = {"road", "trail", "night", "fest", "relay", "kids", "other"}
_ALLOWED_REG = {"open", "soon", "closed", "done"}


def normalize(raw: dict) -> dict | None:
    """Привести сырой dict источника к полям Race. None — если запись невалидна.

    Обложки НЕ импортируем (авторские права/ToS + в модели нет URL-поля обложки) —
    в приложении показывается градиент по типу. cover_url источника игнорируется.
    """
    external_id = str(raw.get("external_id") or "").strip()
    title = str(raw.get("title") or "").strip()
    date = parse_date(raw.get("date"))
    if not external_id or not title or date is None:
        return None

    rtype = str(raw.get("type") or "road").strip().lower()
    if rtype not in _ALLOWED_TYPES:
        rtype = "other"
    reg = str(raw.get("reg_status") or "soon").strip().lower()
    if reg not in _ALLOWED_REG:
        reg = "soon"

    scope = str(raw.get("scope") or "regional").strip().lower()
    if scope not in {"federal", "regional", "local"}:
        scope = "regional"

    dists = raw.get("distances") or []
    if not isinstance(dists, list):
        dists = []
    dists = [str(d).strip() for d in dists if str(d).strip()]

    def _num(key):
        try:
            return float(raw[key]) if raw.get(key) not in (None, "") else None
        except (TypeError, ValueError):
            return None

    points = raw.get("points") or 0
    try:
        points = int(points)
    except (TypeError, ValueError):
        points = 0

    return {
        "external_id": external_id,
        "title": title[:200],
        "date": date,
        "date_end": parse_date(raw.get("date_end")),
        "city": str(raw.get("city") or "").strip()[:120],
        "region": str(raw.get("region") or "").strip()[:120],
        "place": str(raw.get("place") or "").strip()[:200],
        "scope": scope,
        "type": rtype,
        "distances": dists,
        "reg_status": reg,
        "reg_url": str(raw.get("reg_url") or "").strip(),
        "description": str(raw.get("description") or "").strip(),
        "lat": _num("lat"),
        "lng": _num("lng"),
        "points": points,
        "source_url": str(raw.get("source_url") or "").strip(),
    }
