"""Имя пользователя и его клуб — по user_id.

Нужны везде, где показываем таблицу людей: рейтинг, зачёты лиги, клубные доски.
Держим одной реализацией: копии таких мелочей расходятся первыми (см. PITFALLS
про функции-двойники), а вместе с ними расходится и то, что видит пользователь.
"""
from accounts.models import Account
from clubs.models import Club, ClubMember


def name_of(uid: str) -> str:
    a = Account.objects.filter(id=uid).only("name").first()
    return a.name if a else "—"


def club_name_of(uid: str):
    m = ClubMember.objects.filter(user_id=uid).first()
    if not m:
        return None
    c = Club.objects.filter(id=m.club_id).only("name").first()
    return c.name if c else None


def names_of(uids) -> dict:
    """Имена пачкой — один запрос вместо N. Для таблиц на десятки строк."""
    uids = list(uids)
    if not uids:
        return {}
    return {a.id: a.name for a in Account.objects.filter(id__in=uids).only("id", "name")}


def club_names_of(uids) -> dict:
    """Клубы пачкой: user_id → название клуба (или отсутствует в словаре)."""
    uids = list(uids)
    if not uids:
        return {}
    members = ClubMember.objects.filter(user_id__in=uids).only("user_id", "club_id")
    by_user = {m.user_id: m.club_id for m in members}
    if not by_user:
        return {}
    clubs = {c.id: c.name for c in Club.objects.filter(id__in=set(by_user.values())).only("id", "name")}
    return {uid: clubs[cid] for uid, cid in by_user.items() if cid in clubs}
