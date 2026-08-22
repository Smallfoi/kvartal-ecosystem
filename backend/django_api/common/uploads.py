"""Проверка загружаемых изображений (D-37).

Раньше тип файла определялся по заголовку `Content-Type` и расширению из имени — и то,
и другое присылает клиент. Значит можно было положить в media файл `x.html` с любым
содержимым: nginx отдал бы его как страницу, то есть хранимый XSS на домене медиа.

Тип определяется ПО СОДЕРЖИМОМУ (сигнатуре файла), имя и заголовок игнорируются.
"""

MAX_IMAGE_BYTES = 40 * 1024 * 1024

# Сигнатуры (magic bytes) → расширение, которое мы сами и подставим в имя файла.
_SIGNATURES = (
    (b"\xff\xd8\xff", "jpg"),
    (b"\x89PNG\r\n\x1a\n", "png"),
    (b"GIF87a", "gif"),
    (b"GIF89a", "gif"),
)


def _sniff(head: bytes):
    for magic, ext in _SIGNATURES:
        if head.startswith(magic):
            return ext
    # WEBP: "RIFF" + 4 байта размера + "WEBP"
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        return "webp"
    return None


def image_extension(f):
    """(расширение, текст ошибки). Ошибка не None → загрузку отклонить."""
    if not f:
        return None, "Нет файла"
    if f.size > MAX_IMAGE_BYTES:
        return None, "Файл слишком большой (макс 40 МБ)"
    head = f.read(16)
    f.seek(0)  # вернуть курсор — файл ещё предстоит сохранить
    ext = _sniff(head or b"")
    if not ext:
        return None, "Нужен файл-изображение (JPEG, PNG, GIF или WebP)"
    return ext, None
