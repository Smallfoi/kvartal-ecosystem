"""Онбординг сотрудника: второй фактор обязателен, вход — на доступную вкладку (S-12).

Почему второй фактор обязателен именно для сотрудников. У владельца он
подключается командой на сервере (D-49) и остаётся его личным делом. Сотрудник
такой возможности не имеет, а пароль от админки у него настоящий — значит,
единственный честный вариант: не пускать дальше, пока телефон не привязан.
Страницу входа это не трогает: пароль проверяется как раньше.

Второе: сотруднику, которому не выдан «Дашборд», незачем видеть чужие цифры на
главной. Отправляем его на первую вкладку, к которой доступ есть.
"""
from django.http import HttpResponseRedirect
from .access import can, tab_url, visible_tabs

SETUP_PATH = "/admin/2fa/setup/"

# Куда можно ходить, не подключив второй фактор: сама привязка, ввод кода,
# вход/выход и приём приглашения.
NO_ACCESS_PATH = "/admin/no-access/"
_FREE = (SETUP_PATH, NO_ACCESS_PATH, "/admin/2fa/", "/admin/login/",
         "/admin/logout/", "/admin/invite/")


class StaffOnboardingMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        path = request.path
        user = getattr(request, "user", None)

        # Правило «суперпользователь — только владелец» проверяем на каждом запросе,
        # а не только при сохранении записи: если флаг появился в обход Django (SQL,
        # чужая команда), он не должен продержаться дольше одного обращения.
        if user is not None and getattr(user, "is_superuser", False):
            from .owner import enforce
            enforce(user)

        if (path.startswith("/admin")
                and not path.startswith(_FREE)
                and user is not None
                and user.is_authenticated
                and user.is_staff
                and user.is_active
                and not user.is_superuser):

            from common.admin2fa import user_has_device
            if not user_has_device(user):
                return HttpResponseRedirect(SETUP_PATH)

            if path == "/admin/" and not can(user, "dashboard"):
                # Совсем без прав — на страницу-заглушку, а не на сводку
                # с выручкой: «ничего не выдали» не должно означать «видно всё».
                return HttpResponseRedirect(self._first_tab(user) or NO_ACCESS_PATH)

        return self.get_response(request)

    @staticmethod
    def _first_tab(user):
        for tab in visible_tabs(user):
            if tab.key == "dashboard":
                continue
            url = tab_url(tab)
            if url:
                return url
        return None
