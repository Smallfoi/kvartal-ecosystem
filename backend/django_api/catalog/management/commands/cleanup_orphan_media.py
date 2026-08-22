"""Уборка осиротевших медиафайлов конструктора.

При замене фото/видео и (раньше) при удалении файлы оставались «сиротами» на диске.
Новые загрузки/удаления теперь чистятся на лету (admin_views), а эта команда сносит
УЖЕ накопившихся сирот — файлы в папках загрузок, на которые нет ни одной ссылки.

Безопасно: по умолчанию DRY-RUN (только показывает). Реальное удаление — с --apply.
Сноситься могут только файлы в SWEEP_DIRS; всё, на что ссылается любая модель или
любое значение bgvid.*, считается занятым и не трогается.

    python manage.py cleanup_orphan_media           # показать, что удалилось бы
    python manage.py cleanup_orphan_media --apply    # удалить
"""
from django.core.files.storage import default_storage
from django.core.management.base import BaseCommand

# Папки загрузок конструктора, где копятся сироты. Товары/категории правятся в
# админке отдельно — их не трогаем.
SWEEP_DIRS = ["uploads/site", "uploads/site-video", "uploads/banners"]


def _name_from_media_url(url):
    u = (url or "").split("?")[0].strip()
    if "/media/" in u:
        nm = u.split("/media/", 1)[1].lstrip("/")
        return nm if nm.startswith("uploads/") else None
    return None


class Command(BaseCommand):
    help = "Удаляет осиротевшие медиафайлы конструктора (dry-run; --apply чтобы удалить)."

    def add_arguments(self, parser):
        parser.add_argument("--apply", action="store_true", help="реально удалить (иначе только показать)")

    def handle(self, *args, **opts):
        from catalog.models import Banner, Category, Product, SiteContent

        referenced = set()
        # 1) все ImageField-модели
        for model, field in ((Category, "image"), (Product, "image"), (Banner, "image"), (SiteContent, "image")):
            for name in model.objects.exclude(**{field: ""}).exclude(**{field + "__isnull": True}).values_list(field, flat=True):
                if name:
                    referenced.add(str(name).replace("\\", "/"))
        try:
            from races.models import Race
            for name in Race.objects.exclude(cover="").exclude(cover__isnull=True).values_list("cover", flat=True):
                if name:
                    referenced.add(str(name).replace("\\", "/"))
        except Exception:
            pass
        # 2) видео-ссылки и любые /media/uploads/* в значениях контента (bgvid.* и пр.)
        for val in SiteContent.objects.exclude(value="").values_list("value", flat=True):
            nm = _name_from_media_url(val)
            if nm:
                referenced.add(nm)

        orphans, total = [], 0
        for d in SWEEP_DIRS:
            try:
                _dirs, files = default_storage.listdir(d)
            except Exception:
                files = []
            for fn in files:
                name = d + "/" + fn
                if name in referenced:
                    continue
                size = 0
                try:
                    size = default_storage.size(name)
                except Exception:
                    pass
                orphans.append((name, size))
                total += size

        if not orphans:
            self.stdout.write("Сирот не найдено — на диске чисто. Ссылок учтено: %d." % len(referenced))
            return

        self.stdout.write("Осиротевшие файлы (%d, ~%.1f МБ):" % (len(orphans), total / 1048576.0))
        for name, size in sorted(orphans):
            self.stdout.write("  %8.1f КБ  %s" % (size / 1024.0, name))

        if not opts["apply"]:
            self.stdout.write("\nЭто DRY-RUN. Чтобы удалить — запустите с --apply.")
            return

        removed = 0
        for name, _size in orphans:
            try:
                default_storage.delete(name)
                removed += 1
            except Exception as e:
                self.stderr.write("  не удалось удалить %s: %s" % (name, e))
        self.stdout.write("\nУдалено файлов: %d из %d (~%.1f МБ освобождено)." % (removed, len(orphans), total / 1048576.0))
