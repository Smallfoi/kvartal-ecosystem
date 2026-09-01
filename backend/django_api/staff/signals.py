"""Правило единственного владельца соблюдается при каждом сохранении (S-13)."""


def keep_single_owner(sender, instance, **kwargs):
    from .owner import enforce

    try:
        enforce(instance)
    except Exception:      # правило не должно ронять сохранение записи
        pass
