"""Бэкап/восстановление PostgreSQL-БД экосистемы МАТА (launch §13).

БД крутится в docker-compose (сервис `db`, PostGIS). Скрипт делает логический дамп через
`pg_dump`, кладёт gzip в `backups/` и умеет восстанавливать. Команда `verify` доказывает,
что дамп РЕАЛЬНО восстановим (§13 «проверено восстановление»): дампит, разворачивает в
отдельную scratch-БД, сверяет число таблиц/строк и удаляет scratch — БЕЗ риска для dev-данных.

Прод: та же логика по cron/Celery-beat + выгрузка дампа в Object Storage (D-31) + снапшоты
диска. Дампы содержат ПДн (телефоны/почта/GPS) → каталог `backups/` в .gitignore, НЕ коммитить.

Запуск (из корня репо, Docker поднят):
  python scripts/backup_db.py backup            # создать дамп в backups/
  python scripts/backup_db.py verify            # дамп + пробное восстановление + сверка
  python scripts/backup_db.py restore <файл>    # восстановить в основную БД (ОПАСНО: перезапись)
  python scripts/backup_db.py restore <файл> --db kvartal_scratch   # в другую БД
"""
import argparse
import gzip
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COMPOSE = os.path.join(ROOT, "backend", "docker-compose.yml")
BACKUP_DIR = os.path.join(ROOT, "backups")
DB = os.environ.get("POSTGRES_DB", "kvartal")
USER = os.environ.get("POSTGRES_USER", "kvartal")


def _dc(*args, **kw):
    """docker compose ... (сервис db)."""
    return subprocess.run(
        ["docker", "compose", "-f", COMPOSE, *args],
        cwd=ROOT, **kw,
    )


def _psql(db, sql, check=True):
    return _dc(
        "exec", "-T", "db", "psql", "-U", USER, "-d", db, "-tAc", sql,
        check=check, capture_output=True, text=True,
    )


def _ts():
    """Метка времени из БД (не зависим от локали хоста)."""
    r = _psql(DB, "select to_char(now(),'YYYYMMDD_HH24MISS')")
    return r.stdout.strip()


def backup():
    os.makedirs(BACKUP_DIR, exist_ok=True)
    path = os.path.join(BACKUP_DIR, f"staw_{_ts()}.sql.gz")
    # pg_dump → stdout → gzip в файл (без временных файлов в контейнере).
    proc = _dc(
        "exec", "-T", "db", "pg_dump", "-U", USER, "-d", DB, "--no-owner", "--clean",
        "--if-exists", stdout=subprocess.PIPE,
    )
    if proc.returncode != 0:
        print("ОШИБКА: pg_dump не отработал (Docker поднят? БД здорова?)", file=sys.stderr)
        return None
    with gzip.open(path, "wb") as f:
        f.write(proc.stdout)
    size_kb = os.path.getsize(path) // 1024
    print(f"[OK] Дамп создан: {os.path.relpath(path, ROOT)} ({size_kb} КБ)")
    return path


def _restore_into(db, dump_path):
    """Развернуть дамп в БД db (db должна существовать)."""
    with gzip.open(dump_path, "rb") as f:
        data = f.read()
    proc = _dc(
        "exec", "-T", "db", "psql", "-U", USER, "-d", db, "-v", "ON_ERROR_STOP=0",
        input=data, capture_output=True,
    )
    return proc.returncode == 0


def _counts(db):
    """(число таблиц, число строк в accounts) — для сверки восстановления."""
    tbls = _psql(db, "select count(*) from information_schema.tables where table_schema='public'").stdout.strip()
    accs = _psql(db, "select count(*) from accounts", check=False).stdout.strip() or "0"
    return tbls, accs


def verify():
    path = backup()
    if not path:
        return 1
    scratch = "kvartal_verify"
    src_tbls, src_accs = _counts(DB)
    print(f"[..] Пробное восстановление в scratch-БД '{scratch}' (dev-данные не трогаем)")
    _psql("postgres", f'drop database if exists {scratch}', check=False)
    r = _psql("postgres", f'create database {scratch}', check=False)
    if r.returncode != 0:
        print("ОШИБКА: не удалось создать scratch-БД:", r.stderr.strip(), file=sys.stderr)
        return 1
    ok = _restore_into(scratch, path)
    dst_tbls, dst_accs = _counts(scratch)
    _psql("postgres", f'drop database if exists {scratch}', check=False)
    print(f"     таблиц: основная={src_tbls} scratch={dst_tbls} | accounts: основная={src_accs} scratch={dst_accs}")
    if ok and src_tbls == dst_tbls and src_accs == dst_accs:
        print("[OK] Восстановление проверено: дамп разворачивается, данные совпадают.")
        return 0
    print("[FAIL] Восстановление НЕ прошло сверку — разберись до продакшена.", file=sys.stderr)
    return 1


def restore(dump_path, db):
    if not os.path.isfile(dump_path):
        print(f"ОШИБКА: файл не найден: {dump_path}", file=sys.stderr)
        return 1
    print(f"[..] Восстанавливаю {os.path.basename(dump_path)} → БД '{db}' (перезапись)")
    ok = _restore_into(db, dump_path)
    print("[OK] Восстановлено." if ok else "[FAIL] Восстановление с ошибками.", file=sys.stderr if not ok else sys.stdout)
    return 0 if ok else 1


def main():
    p = argparse.ArgumentParser(description="Бэкап/восстановление БД МАТА")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("backup")
    sub.add_parser("verify")
    pr = sub.add_parser("restore")
    pr.add_argument("file")
    pr.add_argument("--db", default=DB)
    a = p.parse_args()
    if a.cmd == "backup":
        return 0 if backup() else 1
    if a.cmd == "verify":
        return verify()
    if a.cmd == "restore":
        return restore(a.file, a.db)
    return 1


if __name__ == "__main__":
    sys.exit(main())
