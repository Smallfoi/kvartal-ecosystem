"""Права Django выводим из вкладок (S-12).

Зачем backend, а не правка каждого ModelAdmin: списков моделей в админке два
десятка, и любой забытый класс стал бы дырой. Backend встраивается в
`user.has_perm()` — тот же вызов, которым Django сам гейтит все страницы
изменения, кнопки «Добавить», «Удалить» и групповые действия. Один источник
правды, ничего не забыть.

Суперпользователь сюда не попадает: ему права выдаёт штатный ModelBackend.
"""
from django.contrib.auth.backends import BaseBackend

from .access import levels_for
from .models import LEVEL_EDIT, LEVEL_FULL, LEVEL_VIEW  # уровни → действия
from .tabs import TABS

# Что означает уровень в терминах прав Django.
_ACTIONS = {
    LEVEL_VIEW: ("view",),
    LEVEL_EDIT: ("view", "add", "change"),
    LEVEL_FULL: ("view", "add", "change", "delete"),
}


class TabPermissionBackend(BaseBackend):
    """Только права. Логин не обрабатывает — этим занят штатный backend."""

    def authenticate(self, request, **kwargs):
        return None

    def get_user_permissions(self, user_obj, obj=None):
        return set()

    def get_group_permissions(self, user_obj, obj=None):
        return set()

    def get_all_permissions(self, user_obj, obj=None):
        # obj-права (на конкретную запись) не поддерживаем: вернуть здесь общий
        # набор значило бы разрешить действие над чужой записью.
        if obj is not None:
            return set()
        if not getattr(user_obj, "is_authenticated", False):
            return set()
        if not (user_obj.is_active and user_obj.is_staff) or user_obj.is_superuser:
            return set()

        cached = getattr(user_obj, "_mata_perm_cache", None)
        if cached is not None:
            return cached

        levels = levels_for(user_obj)
        perms = set()
        for tab in TABS:
            actions = _ACTIONS.get(levels.get(tab.key), ())
            for dotted in tab.models:
                app_label, model = dotted.split(".")
                for action in actions:
                    perms.add(f"{app_label}.{action}_{model}")
        user_obj._mata_perm_cache = perms
        return perms

    def has_perm(self, user_obj, perm, obj=None):
        return perm in self.get_all_permissions(user_obj, obj)

    def has_module_perms(self, user_obj, app_label):
        return any(p.startswith(f"{app_label}.") for p in self.get_all_permissions(user_obj))
