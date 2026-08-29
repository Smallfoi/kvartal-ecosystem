# -*- coding: utf-8 -*-
"""Логотипы для партнёрских заявок (COROS и далее).

Источник — эталон знака `build/mark_icon_1024.png`, из которого собираются
иконка приложения и заставка (`make_kvartal_icons.py`). Берём его и ту же
пропорцию: логотип в каталоге партнёра должен совпадать с тем, что человек
видит на телефоне.

ВАЖНО: не брать `assets/brand/kvartal-app-icon.png` — это старая иконка
(карта с маршрутом), она давно не стоит на приложении. Один раз уже приложил
её к заявке по ошибке.

Запуск из корня репозитория:
    python tools/brand/make_partner_logos.py
Файлы кладутся в «Презентации/COROS-заявка/» (папка не в репозитории).
"""
from pathlib import Path

from PIL import Image

BG = (42, 48, 44)          # #2A302C — фирменный графит иконки
FRAME_IN_MARK = 738.0      # ширина рамки знака в эталоне 1024
FRAME_RATIO = 0.72 * 0.78  # доля рамки от стороны — как в иконке приложения

# COROS требует 144 и 102 всегда; 120 и 300 — если просим синхронизацию
# тренировок (а мы просим). Другим партнёрам обычно хватает этого же набора.
SIZES = (144, 102, 120, 300)

ROOT = Path(__file__).resolve().parents[2]
MARK = ROOT / "mata_kvartal" / "build" / "mark_icon_1024.png"
OUT = ROOT / "Презентации" / "COROS-заявка"


def compose(mark: Image.Image, size: int) -> Image.Image:
    im = Image.new("RGBA", (size, size), BG + (255,))
    frame_px = FRAME_RATIO * size
    s = int(round(1024 * frame_px / FRAME_IN_MARK))
    im.alpha_composite(mark.resize((s, s), Image.LANCZOS), ((size - s) // 2,) * 2)
    return im.convert("RGB")


def main() -> int:
    if not MARK.exists():
        print(f"Не нашёл эталон знака: {MARK}")
        return 1
    mark = Image.open(MARK).convert("RGBA")
    OUT.mkdir(parents=True, exist_ok=True)
    for size in SIZES:
        path = OUT / f"MATA-logo-{size}x{size}.png"
        compose(mark, size).save(path, "PNG", optimize=True)
        print(f"  {path.name} — {path.stat().st_size // 1024} КБ")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
