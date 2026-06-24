"""Защита от запуска в проде с небезопасной конфигурацией (P0 безопасность).

Самая частая катастрофа запуска — выкатить прод с дефолтными секретами из репо:
тогда `JWT_SECRET`/`DJANGO_SECRET_KEY` известны всем → любой подделывает токен
кого угодно. Эта проверка вызывается из settings и НЕ ДАЁТ приложению стартовать,
если `DEBUG=0`, а критичные секреты всё ещё дефолтные (или `ALLOWED_HOSTS=*`).
В dev (`DEBUG=1`) ничего не мешает — список пустой."""

_DEV_SECRET = "dev-secret-change-in-prod"
_DEV_DB_PASSWORD = "kvartal"


def insecure_prod_settings(
    *, debug, secret_key, jwt_secret, db_password, allowed_hosts
):
    """Список небезопасных для прода настроек (пусто = можно стартовать)."""
    if debug:
        return []
    bad = []
    if secret_key == _DEV_SECRET:
        bad.append("DJANGO_SECRET_KEY")
    if jwt_secret == _DEV_SECRET:
        bad.append("JWT_SECRET")
    if db_password == _DEV_DB_PASSWORD:
        bad.append("POSTGRES_PASSWORD")
    if not allowed_hosts or "*" in allowed_hosts:
        bad.append("DJANGO_ALLOWED_HOSTS")
    return bad
