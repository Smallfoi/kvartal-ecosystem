# -*- coding: utf-8 -*-
"""Страж кэша сайта: поменял файл — сдвинь метку версии.

Браузер запоминает `styles.css?v=20260702` и при следующем заходе берёт его из
своей памяти, не спрашивая сервер: адрес-то не изменился. Пока метка не сдвинута,
владелец на своём телефоне видит СТАРУЮ вёрстку, сколько бы мы ни выкатывали
(реальный случай: мобильные правки уехали на прод, а на iPhone «ничего не
поменялось»). Заголовков `Cache-Control` сервер не шлёт, так что метка в адресе —
единственное, что заставляет браузер перекачать файл.

Вторая половина беды — расхождение: `content.js?v=20260704` на главной и
`?v=20260825` на «Философии», а `styles.css` на «Философии» вообще без метки.
Тогда одна страница получает новый файл, другая живёт со старым.

Поэтому правило простое: **у всех своих .js/.css во всех страницах одна и та же
метка**. Скрипт проверяет это, а на PR ещё и то, что при изменении любого такого
файла метка отличается от той, что в main.

Запуск:
    python tools/check_site_cache_bust.py            # только единообразие
    python tools/check_site_cache_bust.py --base origin/main   # + сдвиг метки
"""
from __future__ import annotations

import argparse
import io
import re
import subprocess
import sys
from pathlib import Path

SITE = Path("САЙТ МАТА")
# src="script.js?v=20260828" / href="../styles.css" — свои файлы, не CDN.
REF = re.compile(r'(?:src|href)="(?!https?:|//)([^"?]+\.(?:js|css))(?:\?v=([^"]*))?"')


def refs(html: Path):
    """Ссылки на свои js/css в одной странице: (файл, метка или None, строка)."""
    text = io.open(html, encoding="utf-8", newline="").read()
    for n, line in enumerate(text.split("\n"), 1):
        for m in REF.finditer(line):
            yield m.group(1), m.group(2), n


def stamps_of(paths):
    """Метки версий во всех страницах: метка → [где встретилась]."""
    found = {}
    missing = []
    for html in paths:
        for target, stamp, line in refs(html):
            where = "%s:%d → %s" % (html.as_posix(), line, target)
            if stamp is None:
                missing.append(where)
            else:
                found.setdefault(stamp, []).append(where)
    return found, missing


def git(*args, default=""):
    # core.quotepath=off обязателен: иначе git отдаёт пути с кириллицей в виде
    # "Ð¡Ð..." — сравнение с "САЙТ МАТА/..." молча не срабатывает,
    # и страж пропускает ровно тот случай, ради которого написан.
    cmd = ("git", "-c", "core.quotepath=off") + args
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8")
        return out.stdout if out.returncode == 0 else default
    except OSError:
        return default


def base_stamp(base: str):
    """Единая метка в базовой ветке — если она там единая."""
    names = git("ls-tree", "-r", "--name-only", base).split("\n")
    pages = [n for n in names if n.startswith(SITE.as_posix() + "/") and n.endswith(".html")]
    found = {}
    for page in pages:
        text = git("show", "%s:%s" % (base, page))
        for m in REF.finditer(text):
            if m.group(2):
                found[m.group(2)] = True
    return list(found)[0] if len(found) == 1 else None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", help="ветка сравнения (обычно origin/main)")
    args = ap.parse_args()

    pages = sorted(SITE.rglob("*.html"))
    if not pages:
        print("Не нашёл страниц сайта — проверять нечего.", file=sys.stderr)
        return 1

    found, missing = stamps_of(pages)
    errors = []

    if missing:
        errors.append(
            "Без метки версии (браузер закэширует навсегда) — добавь ?v=<метка>:\n  "
            + "\n  ".join(missing))

    if len(found) > 1:
        detail = "\n".join(
            "  ?v=%s:\n    %s" % (s, "\n    ".join(w)) for s, w in sorted(found.items()))
        errors.append(
            "Метки разъехались — у всех своих js/css должна быть ОДНА метка,\n"
            "иначе одна страница получит новый файл, а другая останется со старым:\n" + detail)

    if args.base and not errors:
        changed = [
            p for p in git("diff", "--name-only", "%s...HEAD" % args.base).split("\n")
            if p.startswith(SITE.as_posix() + "/") and p.rsplit(".", 1)[-1] in ("js", "css")
        ]
        if changed:
            now = list(found)[0]
            was = base_stamp(args.base)
            if was is not None and was == now:
                errors.append(
                    "Изменены файлы сайта, а метка версии осталась прежней (?v=%s).\n"
                    "Браузеры отдадут старую копию из кэша — владелец увидит, что «ничего\n"
                    "не поменялось». Сдвинь метку во всех страницах.\nИзменены:\n  %s"
                    % (now, "\n  ".join(changed)))

    if errors:
        print("Страж кэша сайта: нашлись проблемы.\n", file=sys.stderr)
        for e in errors:
            print(e + "\n", file=sys.stderr)
        return 1

    print("Страж кэша сайта: метка ?v=%s, страниц %d — единообразно."
          % (list(found)[0] if found else "—", len(pages)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
