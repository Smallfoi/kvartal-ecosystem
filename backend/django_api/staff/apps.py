from django.apps import AppConfig


class StaffConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "staff"
    verbose_name = "Сотрудники и доступы"

    def ready(self):
        """Подписка на сохранение учётных записей: правило «суперпользователь —
        только владелец» должно держаться и когда запись меняют не через нашу
        вкладку — из консоли, командой или чужим кодом (S-13)."""
        from django.contrib.auth import get_user_model
        from django.db.models.signals import post_save

        from . import signals

        post_save.connect(signals.keep_single_owner, sender=get_user_model(),
                          dispatch_uid="staff.keep_single_owner")
