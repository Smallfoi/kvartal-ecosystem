"""Единственный владелец: закрепление по идентификатору учётной записи (S-13).

Задача владельца: «суперпользователь — только я, и это не должно зависеть от того,
какую почту, логин или пароль я себе поставлю и с какого устройства войду».

Поэтому закрепляем не почту и не логин (их меняют), а **числовой идентификатор
записи** — он выдаётся один раз при создании и не меняется никогда. Меняйте почту,
пароль, имя, входите откуда угодно — владельцем остаётся та же запись.

Где хранится закрепление, по убыванию силы:
1. `MATA_OWNER_ID` в окружении сервера — если задан, спорить не с чем;
2. строка `OwnerPin` в базе — ставится автоматически на первом же запуске по самому
   первому суперпользователю и переживает пересоздание сервера вместе с базой;
3. если ни того ни другого нет и суперпользователей нет вовсе — не принуждаем
   ничего: пустой системе нельзя навязывать владельца.

Правило соблюдается непрерывно, а не только при сохранении формы: любой другой
суперпользователь теряет флаг, а владелец — получает его обратно, даже если кто-то
снял. Обойти это из админки нельзя: галочки «суперпользователь» там больше нет.
"""
import logging

from django.conf import settings
from django.contrib.auth import get_user_model

log = logging.getLogger(__name__)


def _pinned_from_env():
    try:
        value = int(getattr(settings, "MATA_OWNER_ID", 0) or 0)
    except (TypeError, ValueError):
        return None
    return value or None


def owner_id():
    """Идентификатор владельца или None, если закреплять пока некого."""
    from .models import OwnerPin

    pinned = _pinned_from_env()
    if pinned:
        return pinned
    try:
        row = OwnerPin.objects.first()
        if row:
            return row.user_id
        User = get_user_model()
        first = User.objects.filter(is_superuser=True).order_by("pk").first()
        if first is None:
            return None
        # Первый суперпользователь системы и есть владелец: закрепляем и больше
        # не пересматриваем — иначе «владельцем» стал бы любой следующий.
        OwnerPin.objects.create(user=first)
        log.warning("Владелец закреплён автоматически: id=%s (%s)", first.pk, first.get_username())
        return first.pk
    except Exception:      # таблицы ещё нет (миграции, свежая база)
        return None


def is_owner(user) -> bool:
    if user is None or not getattr(user, "is_authenticated", False):
        return False
    pk = owner_id()
    return pk is not None and user.pk == pk


def enforce(user=None) -> bool:
    """Привести запись к правилу «суперпользователь — только владелец».

    Возвращает True, если что-то пришлось поправить. Пишем через `update()`, а не
    `save()`: иначе сигнал вызвал бы сам себя.
    """
    User = get_user_model()
    pk = owner_id()
    if pk is None:
        return False

    fixed = False

    if user is not None and user.pk is not None:
        if user.pk != pk and user.is_superuser:
            User.objects.filter(pk=user.pk).update(is_superuser=False)
            user.is_superuser = False
            log.warning("Снят флаг суперпользователя: id=%s (%s) — владелец только id=%s",
                        user.pk, user.get_username(), pk)
            fixed = True
        elif user.pk == pk:
            # Владельца нельзя ни разжаловать, ни отключить, ни лишить входа в
            # админку: иначе одним неверным сохранением он запрёт себя снаружи.
            restore = {}
            if not user.is_superuser:
                restore["is_superuser"] = True
            if not user.is_staff:
                restore["is_staff"] = True
            if not user.is_active:
                restore["is_active"] = True
            if restore:
                User.objects.filter(pk=pk).update(**restore)
                for field, value in restore.items():
                    setattr(user, field, value)
                log.warning("Владельцу возвращено: %s", ", ".join(restore))
                fixed = True
        return fixed

    # Полная проверка (команда обслуживания и старт приложения).
    others = User.objects.filter(is_superuser=True).exclude(pk=pk)
    n = others.count()
    if n:
        log.warning("Снимаю флаг суперпользователя у чужих записей: %s", n)
        others.update(is_superuser=False)
        fixed = True
    owner = User.objects.filter(pk=pk).first()
    if owner and not (owner.is_superuser and owner.is_staff and owner.is_active):
        User.objects.filter(pk=pk).update(is_superuser=True, is_staff=True, is_active=True)
        fixed = True
    return fixed
