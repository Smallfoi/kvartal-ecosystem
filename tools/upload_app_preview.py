#!/usr/bin/env python3
"""Выгрузка web-сборки превью приложения (mata_store) в S3 (Yandex Object Storage).

Используется CI (.github/workflows/app-preview.yml): собирает `flutter build web`
и зеркалит build/web в бакет под префикс mata-app-preview/. Конструктор на проде
грузит это как превью приложения (APP_PREVIEW_URL). Публичное чтение (это web-app).

Зеркалирование: заливает все файлы + УДАЛЯЕТ из префикса устаревшие (которых нет
в новой сборке) — иначе старые ассеты копятся. Content-Type выставляется явно
(важно для .wasm CanvasKit и .js), Cache-Control: no-cache (превью всегда свежее).

Креды и параметры — из окружения:
  AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY  — ключ S3 (в CI из secrets)
  S3_ENDPOINT (по умолч. https://storage.yandexcloud.net)
  S3_BUCKET   (по умолч. mata-media)
  S3_PREFIX   (по умолч. mata-app-preview/)
  BUILD_DIR   (по умолч. mata_store/build/web)
"""
import os
import sys
import mimetypes

import boto3

ENDPOINT = os.environ.get("S3_ENDPOINT", "https://storage.yandexcloud.net")
BUCKET = os.environ.get("S3_BUCKET", "mata-media")
PREFIX = os.environ.get("S3_PREFIX", "mata-app-preview/")
BUILD_DIR = os.environ.get("BUILD_DIR", "mata_store/build/web")

# Явные типы — mimetypes не всегда знает .wasm/.js одинаково на всех раннерах.
CT = {
    ".js": "text/javascript", ".mjs": "text/javascript", ".wasm": "application/wasm",
    ".json": "application/json", ".html": "text/html; charset=utf-8", ".css": "text/css",
    ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".gif": "image/gif",
    ".svg": "image/svg+xml", ".ico": "image/x-icon", ".ttf": "font/ttf", ".otf": "font/otf",
    ".woff": "font/woff", ".woff2": "font/woff2", ".bin": "application/octet-stream",
    ".map": "application/json", ".txt": "text/plain", ".xml": "application/xml",
}


def content_type(name):
    ext = os.path.splitext(name)[1].lower()
    return CT.get(ext) or mimetypes.guess_type(name)[0] or "application/octet-stream"


def main():
    if not os.path.isdir(BUILD_DIR):
        sys.exit("BUILD_DIR не найден: %s (сначала flutter build web)" % BUILD_DIR)

    s3 = boto3.client(
        "s3", endpoint_url=ENDPOINT, region_name="ru-central1",
        aws_access_key_id=os.environ["AWS_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["AWS_SECRET_ACCESS_KEY"],
    )

    # 1) Заливаем всё из сборки.
    uploaded = set()
    total = 0
    for base, _, files in os.walk(BUILD_DIR):
        for fn in files:
            full = os.path.join(base, fn)
            rel = os.path.relpath(full, BUILD_DIR).replace("\\", "/")
            key = PREFIX + rel
            with open(full, "rb") as f:
                data = f.read()
            s3.put_object(
                Bucket=BUCKET, Key=key, Body=data, ContentType=content_type(fn),
                ACL="public-read", CacheControl="no-cache",
            )
            uploaded.add(key)
            total += len(data)
    print("Загружено %d файлов, %.1f МБ" % (len(uploaded), total / 1048576))

    # 2) Удаляем устаревшие объекты под префиксом (которых нет в новой сборке).
    stale = []
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=BUCKET, Prefix=PREFIX):
        for obj in page.get("Contents", []):
            if obj["Key"] not in uploaded:
                stale.append({"Key": obj["Key"]})
    for i in range(0, len(stale), 1000):
        s3.delete_objects(Bucket=BUCKET, Delete={"Objects": stale[i:i + 1000]})
    print("Удалено устаревших: %d" % len(stale))


if __name__ == "__main__":
    main()
