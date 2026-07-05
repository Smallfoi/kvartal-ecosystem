"""Медиа-хранилище (D-31): прод-S3 при заданных ключах, иначе локальный диск.

Аватары, фото отзывов и баннеров грузятся через `default_storage`. В dev это локальный
`FileSystemStorage` (том `/srv/media`, отдаётся под `/media/`). Для прода нужен объектный
S3-стор (Yandex Object Storage — S3-совместимый) + CDN: включается переменными окружения,
код и загрузки не меняются (URL берётся через `default_storage.url()`). Тот же паттерн
graceful degradation, что у SMS/оплаты/пуша: без ключей — dev-режим, с ключами — прод.

`storages.backends.s3` импортируется Django ЛЕНИВО (только при первом обращении к
хранилищу, т.е. фактически лишь в проде) — поэтому в dev/CI без S3 django-storages/boto3
не трогаются, даже если установлены.
"""

_STATIC = {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"}
_LOCAL = {"BACKEND": "django.core.files.storage.FileSystemStorage"}


def _s3_env(env):
    """Ключи S3, если заданы ВСЕ обязательные (bucket + access + secret)."""
    bucket = (env.get("MEDIA_S3_BUCKET") or "").strip()
    access = (env.get("MEDIA_S3_ACCESS_KEY") or "").strip()
    secret = (env.get("MEDIA_S3_SECRET_KEY") or "").strip()
    if bucket and access and secret:
        return bucket, access, secret
    return None


def media_backend_kind(env):
    """'s3' если объектное хранилище настроено, иначе 'local' (для launch-отчёта)."""
    return "s3" if _s3_env(env) else "local"


def media_storages(env):
    """Значение Django-настройки STORAGES. default = S3 при ключах, иначе локальный диск;
    staticfiles всегда локальные (collectstatic на сервере)."""
    creds = _s3_env(env)
    if not creds:
        return {"default": dict(_LOCAL), "staticfiles": dict(_STATIC)}
    bucket, access, secret = creds
    options = {
        "bucket_name": bucket,
        "access_key": access,
        "secret_key": secret,
        "endpoint_url": (env.get("MEDIA_S3_ENDPOINT") or "https://storage.yandexcloud.net").strip(),
        "region_name": (env.get("MEDIA_S3_REGION") or "ru-central1").strip(),
        "default_acl": "public-read",   # фото публичны (витрина/аватары)
        "querystring_auth": False,      # публичные URL без подписи
        "file_overwrite": False,        # не перезатирать по совпадению имени
    }
    custom = (env.get("MEDIA_S3_CUSTOM_DOMAIN") or "").strip()
    if custom:
        options["custom_domain"] = custom  # CDN-домен для отдачи медиа
    return {
        "default": {"BACKEND": "storages.backends.s3.S3Storage", "OPTIONS": options},
        "staticfiles": dict(_STATIC),
    }
