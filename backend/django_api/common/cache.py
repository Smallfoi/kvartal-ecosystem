"""Кэш тяжёлых агрегатов (D-29) на общем кэше Django — Redis в проде/стеке (REDIS_URL),
LocMem в dev-без-Redis. Код работает и там, и там: бэкенд сам выбирает бэкенд кэша.

Стратегия (почему по-разному):
- **Лейдерборд** (users/clubs/districts) — ГОРЯЧИЙ ГЛОБАЛЬНЫЙ агрегат (Sum по всем
  транзакциям + N имён/клубов + PostGIS). Меняется от действий ЛЮБОГО юзера, поэтому
  пер-write инвалидация на общем ключе = постоянный пересчёт/стемпид. Правильно —
  короткий TTL: пересчёт не чаще раза в минуту, рейтинг терпит секунды устаревания.
- **/me/stats** и **/loyalty/account** — агрегаты НА ЮЗЕРА (read-only отображение).
  Кэш по uid + **явная инвалидация** при любой его транзакции (`add_txn` ⇒ `invalidate_user`)
  → свои данные свежие сразу после своего действия. Плюс safety-TTL на изменения мимо add_txn.
  ВАЖНО: авторитетные проверки (redeem — «хватает ли баллов», before в add_txn) читают СЫРОЙ
  `balance_of`, НЕ кэш — иначе по устаревшему балансу можно уйти в минус. Кэшируем только показ.
"""
from django.core.cache import cache

LEADERBOARD_TTL = 60   # сек: лейдерборд пересчитывается не чаще раза в минуту
STATS_TTL = 120        # сек: safety-net для /me/stats помимо явной инвалидации
LOYALTY_TTL = 120      # сек: safety-net для /loyalty/account помимо явной инвалидации


def cache_json(key, ttl, producer):
    """get-or-compute: вернуть закэшированное или посчитать producer() и положить в кэш.
    Producer'ы возвращают dict/list (не None), поэтому None надёжно значит «промах»."""
    value = cache.get(key)
    if value is None:
        value = producer()
        cache.set(key, value, ttl)
    return value


def leaderboard_key(tab, period, limit):
    return f"lb:{tab}:{period}:{limit}"


def stats_key(uid):
    return f"stats:{uid}"


def loyalty_key(uid):
    return f"loyalty:{uid}"


def invalidate_stats(uid):
    """Сбросить кэш личной статистики юзера (после его новой транзакции/забега/заказа)."""
    if uid:
        cache.delete(stats_key(uid))


def invalidate_loyalty(uid):
    """Сбросить кэш карточки лояльности юзера (баланс/уровень/история)."""
    if uid:
        cache.delete(loyalty_key(uid))


def invalidate_user(uid):
    """Сбросить ВСЕ пер-юзерные кэши после его транзакции: статистика + карточка лояльности.
    Зовётся из add_txn — единая точка инвалидации на любое изменение баллов юзера."""
    invalidate_stats(uid)
    invalidate_loyalty(uid)
