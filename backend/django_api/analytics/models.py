"""Продуктовая аналитика (D-30): единый поток СОБЫТИЙ по всей экосистеме МАТА.

Один аккаунт (SSO) → одна лента событий из всех продуктов (Квартал/Store/Сайт).
Пишется и сервером (`track(...)` в ключевых местах: регистрация/забег/покупка/захват),
и клиентами (`POST /v1/events` — экраны, клики). Пропсы — свободный JSON.

Событие — факт, а не деньги: сбой записи НЕ должен ломать основной поток (см. `track`).
Ретеншн/когорты считаются поверх событий и существующих сигналов — см. `analytics.retention`.
"""
from django.db import models
from django.utils import timezone

# Канонические имена серверных событий — единый словарь, чтобы не плодить опечатки строк.
E_REGISTER = "account_registered"
E_LOGIN = "account_login"
E_RUN_FINISHED = "run_finished"
E_PURCHASE = "purchase"
E_TERRITORY_CAPTURED = "territory_captured"


class Event(models.Model):
    """Одно событие аналитики. user_id — общий ID экосистемы (может быть пустым для
    анонимных клиентских событий). source — откуда пришло (kvartal/store/site/server)."""

    id = models.BigAutoField(primary_key=True, verbose_name="ID")
    user_id = models.CharField(
        max_length=40, db_index=True, blank=True, default="", verbose_name="Пользователь (ID)"
    )
    name = models.CharField(max_length=60, db_index=True, verbose_name="Событие")
    source = models.CharField(max_length=20, blank=True, default="server", verbose_name="Источник")
    props = models.JSONField(default=dict, blank=True, verbose_name="Свойства")
    created_at = models.DateTimeField(
        default=timezone.now, db_index=True, verbose_name="Время"
    )

    class Meta:
        db_table = "analytics_events"
        verbose_name = "Событие"
        verbose_name_plural = "Аналитика (события)"
        indexes = [models.Index(fields=["name", "created_at"])]

    def to_json(self) -> dict:
        return {
            "name": self.name,
            "source": self.source,
            "props": self.props or {},
            "createdAt": self.created_at.isoformat(),
        }


# Разрешённые источники клиентских событий (POST /v1/events). server — только внутренне.
CLIENT_SOURCES = {"kvartal", "store", "site"}


def track(name, user_id="", source="server", **props):
    """Записать событие. БЕЗОПАСНО: аналитика не критична — любой сбой глотаем, чтобы
    не ломать основной поток (начисления/заказы/захваты). Пустое имя игнорируем."""
    if not name:
        return None
    try:
        return Event.objects.create(
            user_id=user_id or "",
            name=str(name)[:60],
            source=(source or "server")[:20],
            props=props or {},
        )
    except Exception:
        return None
