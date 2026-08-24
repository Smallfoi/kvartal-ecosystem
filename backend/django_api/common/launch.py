"""Готовность к запуску (launch-gate): что осталось включить владельцу.

Каркасы интеграций (SMS/оплата/пуш) в dev работают как no-op — реальные вызовы
активируются переменными окружения (провайдер + ключи аккаунта владельца). Этот модуль
собирает единый отчёт: какие интеграции настроены, безопасна ли прод-конфигурация,
опубликованы ли обязательные юр-документы. Печатает команда `check_launch_readiness`.
См. docs/LAUNCH_READINESS.md.
"""
import os

from common.media import media_backend_kind
from common.prodcheck import insecure_prod_settings


def _env(name):
    return (os.environ.get(name) or "").strip()


def integrations():
    """Внешние интеграции: provider задан И ключи есть → ready; иначе dev-режим (no-op)."""
    sms_p, pay_p, push_p = _env("SMS_PROVIDER"), _env("PAYMENT_PROVIDER"), _env("PUSH_PROVIDER")
    return [
        {
            "key": "sms",
            "name": "SMS-вход (коды подтверждения)",
            "provider": sms_p or "—",
            "ready": bool(sms_p) and bool(_env("SMS_LOGIN") and _env("SMS_PASSWORD")),
            "needs": "SMS_PROVIDER=smsc + SMS_LOGIN/SMS_PASSWORD",
        },
        {
            "key": "payment",
            "name": "Оплата заказов",
            "provider": pay_p or "—",
            "ready": bool(pay_p) and bool(_env("YOOKASSA_SHOP_ID") and _env("YOOKASSA_SECRET_KEY")),
            "needs": "PAYMENT_PROVIDER=yookassa + YOOKASSA_SHOP_ID/YOOKASSA_SECRET_KEY",
        },
        {
            # Чек обязателен при любом способе расчёта, включая СБП. Без него
            # оплату включать нельзя — это нарушение 54-ФЗ, а не «доделаем потом».
            "key": "receipt",
            "name": "Чек 54-ФЗ (онлайн-касса)",
            "provider": "ЮKassa + касса" if _env("PAYMENT_RECEIPT") else "—",
            "ready": _env("PAYMENT_RECEIPT") in ("1", "true", "yes"),
            "needs": "подключить кассу с ФФД 1.2 к ЮKassa, затем PAYMENT_RECEIPT=1",
        },
        {
            "key": "push",
            "name": "Push-уведомления",
            "provider": push_p or "—",
            # RuStore Push шлёт по адресу проекта — без PROJECT_ID один ключ бесполезен.
            "ready": bool(push_p) and bool(_env("RUSTORE_PROJECT_ID") and _env("RUSTORE_PUSH_KEY")),
            "needs": "PUSH_PROVIDER=rustore + RUSTORE_PROJECT_ID + RUSTORE_PUSH_KEY",
        },
    ]


def infra():
    """Инфра, обязательная для прод-масштаба (несколько воркеров gunicorn)."""
    return [
        {
            "key": "redis",
            "name": "Redis (общий кэш + брокер Celery)",
            "ready": bool(_env("REDIS_URL") or _env("CELERY_BROKER_URL")),
            "needs": "REDIS_URL (иначе LocMem-кэш и Celery EAGER — только dev/один воркер)",
        },
        {
            "key": "sentry",
            "name": "Sentry (мониторинг ошибок)",
            "ready": bool(_env("SENTRY_DSN")),
            "needs": "SENTRY_DSN (self-host РФ, D-25)",
        },
        {
            "key": "media",
            "name": "Медиа-хранилище (аватары/фото/баннеры)",
            "ready": media_backend_kind(os.environ) == "s3",
            "needs": "MEDIA_S3_BUCKET + MEDIA_S3_ACCESS_KEY/MEDIA_S3_SECRET_KEY "
                     "(иначе локальный диск — не для прода; D-31)",
        },
    ]


def security():
    """Прод-безопасность: не остались ли дефолтные секреты / ALLOWED_HOSTS=*."""
    debug = os.environ.get("DJANGO_DEBUG", "1") == "1"
    insecure = insecure_prod_settings(
        debug=debug,
        secret_key=_env("DJANGO_SECRET_KEY") or "dev-secret-change-in-prod",
        jwt_secret=_env("JWT_SECRET") or "dev-secret-change-in-prod",
        db_password=_env("POSTGRES_PASSWORD") or "kvartal",
        allowed_hosts=[h.strip() for h in _env("DJANGO_ALLOWED_HOSTS").split(",") if h.strip()] or ["*"],
    )
    return {"prodMode": not debug, "insecure": insecure}


def admin_access():
    """Админка: двухфакторный вход и отсутствие дефолтных паролей (D-49)."""
    from django.contrib.auth import get_user_model

    from common.admin2fa import user_has_device

    # Пароли, которые ходили по документации и переписке: в проде их быть не должно.
    known = ["staw-admin-2026", "admin", "admin123", "password"]
    weak, no2fa = [], []
    try:
        for u in get_user_model().objects.filter(is_superuser=True):
            if any(u.check_password(p) for p in known):
                weak.append(u.get_username())
            # Второй фактор обязателен для каждого админа: без него утёкший
            # пароль = полный доступ к возвратам, персональным данным и контенту.
            if not user_has_device(u):
                no2fa.append(u.get_username())
    except Exception:
        pass
    return {"weakPasswordUsers": sorted(weak), "usersWithout2fa": sorted(no2fa)}


def legal_gate():
    """Обязательные юр-документы опубликованы? (launch-gate §3/§13 LAUNCH_READINESS)."""
    from legal.models import LegalDocument

    required = set(
        LegalDocument.objects.filter(is_required=True).values_list("doc_type", flat=True)
    )
    published = set(
        LegalDocument.objects.filter(is_required=True, published_at__isnull=False)
        .values_list("doc_type", flat=True)
    )
    missing = sorted(required - published)
    return {
        "requiredTypes": sorted(required),
        "missing": missing,
        "ok": bool(required) and not missing,
    }


def launch_report():
    """Единый отчёт готовности к запуску."""
    return {
        "integrations": integrations(),
        "infra": infra(),
        "security": security(),
        "admin": admin_access(),
        "legal": legal_gate(),
    }
