#!/usr/bin/env python3
"""Нагрузочный прогон API МАТА (launch-gate §13).

Читает только GET-эндпоинты — безопасно гонять и против боевого сервера.

    # dev
    python scripts/loadtest.py --tokens tokens.txt -c 20 -d 30
    # прод
    python scripts/loadtest.py --base https://api.<домен>/v1 --tokens tokens.txt -c 50 -d 60

**Почему нужен файл с токенами, а не один токен.** Rate-limit — 300/мин на
пользователя (5 rps) и 120/мин на IP для анонимных. С одним токеном прогон упрётся
в 429 и измерит throttle, а не производительность. Токены выпускаются на сервере:

    docker compose exec -T web python manage.py shell -c "
    from accounts.models import Account; from common.security import make_token
    print('\n'.join(make_token(a.id) for a in Account.objects.all()[:30]))"

Зависимостей нет — только стандартная библиотека.
"""
import argparse
import json
import statistics
import sys
import threading
import time
import urllib.error
import urllib.request
from collections import defaultdict

# Якутск — коробка карты, которую Квартал опрашивает при каждом обновлении слоя.
BBOX = "129.60,62.00,129.90,62.10"

# (имя, путь, нужен ли токен). Порядок = порядок в отчёте.
SCENARIOS = [
    ("health",        "/health",                        False),
    ("products",      "/products",                      False),
    ("categories",    "/categories",                    False),
    ("banners",       "/banners",                       False),
    ("product_search", "/products/search?q=%D0%BA",     False),
    ("site_content",  "/site/content",                  False),
    ("loyalty",       "/loyalty/account",               True),
    ("me_stats",      "/me/stats",                      True),
    ("notifications", "/notifications",                 True),
    ("orders",        "/orders",                        True),
    ("leaderboard",   "/leaderboard/users",             True),
    ("clubs_lb",      "/leaderboard/clubs",             True),
    ("territories",   f"/territories?bbox={BBOX}",      True),
    ("footprint",     "/footprint",                     True),
]


def fetch(url, token, timeout):
    """Один запрос. Возвращает (код, миллисекунды)."""
    req = urllib.request.Request(url, method="GET")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    t0 = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            r.read()
            code = r.status
    except urllib.error.HTTPError as e:
        e.read()
        code = e.code
    except Exception:
        code = 0  # таймаут/обрыв — считаем отказом
    return code, (time.perf_counter() - t0) * 1000


def main():
    p = argparse.ArgumentParser(description="Нагрузочный прогон API МАТА")
    p.add_argument("--base", default="http://127.0.0.1:8000/v1", help="базовый URL API")
    p.add_argument("--tokens", help="файл с JWT (по одному в строке)")
    p.add_argument("-c", "--concurrency", type=int, default=20, help="одновременных клиентов")
    p.add_argument("-d", "--duration", type=int, default=30, help="секунд под нагрузкой")
    p.add_argument("--timeout", type=float, default=20.0, help="таймаут запроса, с")
    a = p.parse_args()

    tokens = []
    if a.tokens:
        tokens = [ln.strip() for ln in open(a.tokens, encoding="utf-8") if ln.strip()]
    if not tokens:
        print("! Токенов нет — прогон только по анонимным эндпоинтам "
              "(упрётся в лимит 120/мин на IP).", file=sys.stderr)

    scenarios = [s for s in SCENARIOS if tokens or not s[2]]
    base = a.base.rstrip("/")
    lock = threading.Lock()
    stats = defaultdict(list)   # имя → [мс, ...]
    codes = defaultdict(lambda: defaultdict(int))  # имя → код → сколько

    # Прогрев: первый запрос к Django тянет ленивые импорты и прогревает кэш —
    # без него p99 показывает стоимость старта, а не работу под нагрузкой.
    for name, path, need in scenarios:
        fetch(base + path, tokens[0] if (need and tokens) else None, a.timeout)

    deadline = time.perf_counter() + a.duration
    started = time.perf_counter()

    def worker(idx):
        i = idx
        while time.perf_counter() < deadline:
            name, path, need = scenarios[i % len(scenarios)]
            # Токен меняем на КАЖДОМ запросе, а не закрепляем за клиентом: лимит
            # 300/мин считается на пользователя, и при закреплении потолок прогона =
            # (клиентов × 5 rps) — сколько токенов ни дай, лишние просто не используются.
            token = tokens[(i * 7 + idx) % len(tokens)] if tokens else None
            i += 1
            code, ms = fetch(base + path, token if need else None, a.timeout)
            with lock:
                stats[name].append(ms)
                codes[name][code] += 1

    threads = [threading.Thread(target=worker, args=(i,), daemon=True)
               for i in range(a.concurrency)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    elapsed = time.perf_counter() - started

    def pct(xs, q):
        xs = sorted(xs)
        return xs[min(len(xs) - 1, int(len(xs) * q))]

    total = sum(len(v) for v in stats.values())
    print(f"\nБаза: {base}   клиентов: {a.concurrency}   токенов: {len(tokens)}   "
          f"время: {elapsed:.1f}с")
    print(f"Запросов: {total}   RPS: {total / elapsed:.1f}\n")
    head = f"{'эндпоинт':<16}{'N':>7}{'ok':>7}{'429':>6}{'ош':>5}" \
           f"{'p50':>8}{'p95':>8}{'p99':>8}{'max':>8}"
    print(head)
    print("-" * len(head))
    worst = []
    for name, path, need in scenarios:
        v = stats.get(name)
        if not v:
            continue
        c = codes[name]
        ok = sum(n for code, n in c.items() if 200 <= code < 300)
        throttled = c.get(429, 0)
        errs = sum(n for code, n in c.items() if code == 0 or code >= 500
                   or (400 <= code < 500 and code != 429))
        p95 = pct(v, 0.95)
        worst.append((p95, name))
        print(f"{name:<16}{len(v):>7}{ok:>7}{throttled:>6}{errs:>5}"
              f"{statistics.median(v):>8.0f}{p95:>8.0f}{pct(v, 0.99):>8.0f}{max(v):>8.0f}")
    print("\nмиллисекунды; 429 — сработал rate-limit (не ошибка сервера)")
    worst.sort(reverse=True)
    print("\nСамые медленные по p95: " + ", ".join(f"{n} ({p:.0f}мс)" for p, n in worst[:3]))


if __name__ == "__main__":
    main()
