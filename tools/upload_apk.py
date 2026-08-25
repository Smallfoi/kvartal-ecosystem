#!/usr/bin/env python3
"""Выгрузка подписанного release-APK в S3 (Yandex Object Storage) + version.json.

Используется CI (.github/workflows/android-release.yml): после `flutter build apk
--release` заливает APK в бакет mata-media под app/<app>/ и пишет version.json, по
которому приложение и страница тестера узнают о новой версии.

Раскладка в бакете (публичное чтение):
  app/<app>/<app>-<buildNumber>.apk   — версионный файл (кешируется)
  app/<app>/latest.apk                — стабильная ссылка на последнюю (no-cache)
  app/<app>/version.json              — метаданные последней версии (no-cache)

Приложение сравнивает свой versionCode с version.json.versionCode: если серверный
больше — предлагает обновиться. Поэтому buildNumber монотонно растёт (в CI — число
коммитов), одинаковый и в сборке (--build-number), и в version.json.

Хранение: держим последние KEEP версионных APK, старые удаляем.

Параметры — из окружения:
  AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY  — S3-ключ (в CI из secrets)
  S3_ENDPOINT (по умолч. https://storage.yandexcloud.net)
  S3_BUCKET   (по умолч. mata-media)
  APP           — kvartal | store (короткое имя, префикс в бакете)
  APK_PATH      — путь к app-release.apk
  BUILD_NUMBER  — versionCode (целое, монотонное)
  VERSION_NAME  — versionName из pubspec (напр. 1.0.0)
  GIT_SHA       — коммит сборки
  NOTES         — сообщение коммита (берётся первая строка)
  BUILT_AT      — ISO-время сборки (необязательно)
"""
import json
import os
import sys

import boto3

ENDPOINT = os.environ.get("S3_ENDPOINT", "https://storage.yandexcloud.net")
BUCKET = os.environ.get("S3_BUCKET", "mata-media")
APP = os.environ["APP"]
APK_PATH = os.environ["APK_PATH"]
BUILD_NUMBER = int(os.environ["BUILD_NUMBER"])
VERSION_NAME = os.environ.get("VERSION_NAME", "").strip() or "1.0.0"
GIT_SHA = os.environ.get("GIT_SHA", "")[:12]
NOTES = (os.environ.get("NOTES", "") or "").strip().splitlines()
NOTES = NOTES[0] if NOTES else ""
BUILT_AT = os.environ.get("BUILT_AT", "")
KEEP = int(os.environ.get("KEEP", "5"))

PREFIX = "app/%s/" % APP
PUBLIC_BASE = "%s/%s" % (ENDPOINT, BUCKET)


def main():
    if not os.path.isfile(APK_PATH):
        sys.exit("APK не найден: %s" % APK_PATH)

    s3 = boto3.client(
        "s3", endpoint_url=ENDPOINT, region_name="ru-central1",
        aws_access_key_id=os.environ["AWS_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["AWS_SECRET_ACCESS_KEY"],
    )

    with open(APK_PATH, "rb") as f:
        apk = f.read()

    versioned_key = "%s%s-%d.apk" % (PREFIX, APP, BUILD_NUMBER)
    latest_key = "%slatest.apk" % PREFIX
    version_key = "%sversion.json" % PREFIX
    apk_url = "%s/%s" % (PUBLIC_BASE, versioned_key)
    latest_url = "%s/%s" % (PUBLIC_BASE, latest_key)

    # 1) Версионный APK (можно кешировать — он неизменен).
    s3.put_object(
        Bucket=BUCKET, Key=versioned_key, Body=apk,
        ContentType="application/vnd.android.package-archive",
        ACL="public-read", CacheControl="public, max-age=31536000, immutable",
    )
    # 2) latest.apk — стабильная ссылка (без кеша, всегда свежая).
    s3.put_object(
        Bucket=BUCKET, Key=latest_key, Body=apk,
        ContentType="application/vnd.android.package-archive",
        ACL="public-read", CacheControl="no-cache",
    )
    # 3) version.json — метаданные.
    version = {
        "app": APP,
        "versionName": VERSION_NAME,
        "versionCode": BUILD_NUMBER,
        "apkUrl": apk_url,
        "latestUrl": latest_url,
        "sizeBytes": len(apk),
        "notes": NOTES,
        "sha": GIT_SHA,
        "builtAt": BUILT_AT,
    }
    s3.put_object(
        Bucket=BUCKET, Key=version_key,
        Body=json.dumps(version, ensure_ascii=False).encode("utf-8"),
        ContentType="application/json; charset=utf-8",
        ACL="public-read", CacheControl="no-cache",
    )
    print("APK  → %s (%.1f МБ)" % (apk_url, len(apk) / 1048576))
    print("json → %s/%s  versionCode=%d" % (PUBLIC_BASE, version_key, BUILD_NUMBER))

    # 4) Чистка старых версионных APK (оставляем последние KEEP).
    versioned = []
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=BUCKET, Prefix=PREFIX):
        for obj in page.get("Contents", []):
            k = obj["Key"]
            if k.endswith(".apk") and k != latest_key:
                tail = k[len(PREFIX):]
                if tail.startswith(APP + "-") and tail.endswith(".apk"):
                    try:
                        n = int(tail[len(APP) + 1:-4])
                        versioned.append((n, k))
                    except ValueError:
                        pass
    versioned.sort(reverse=True)
    stale = [{"Key": k} for _, k in versioned[KEEP:]]
    if stale:
        s3.delete_objects(Bucket=BUCKET, Delete={"Objects": stale})
    print("Удалено старых APK: %d (оставлено %d)" % (len(stale), min(len(versioned), KEEP)))


if __name__ == "__main__":
    main()
