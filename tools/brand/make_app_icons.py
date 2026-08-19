#!/usr/bin/env python3
"""Сборка иконок и сплэша приложений МАТА из фирменного знака (D-40).

Знак mudreza в SVG — три многоугольника без кривых, поэтому растрируем его сами
(PIL + суперсэмплинг ×4): не нужен ни ImageMagick, ни cairo, а результат резче, чем
масштабирование готового PNG в 2–3 раза.

Бренд-кит лежит ЛОКАЛЬНО в `brand/` и в репозиторий не коммитится (публичный репо,
см. `brand/README.md`). Коммитятся только собранные этим скриптом файлы в приложениях.

Запуск (из корня монорепо):
    python tools/brand/make_app_icons.py --app kvartal --bg 2A302C --fg EEEA83
    python tools/brand/make_app_icons.py --app store   --bg EEEA83 --fg 2A302C

Что обновляет:
  • iOS  — весь AppIcon.appiconset по Contents.json (без альфы: App Store отклоняет
           иконки с прозрачностью), LaunchImage 1x/2x/3x и фон LaunchScreen.storyboard;
  • Android — mipmap ic_launcher.png на 5 плотностей, adaptive-иконку
           (ic_launcher_foreground.png), сплэш launch_logo.png и цвет launch_background.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SVG = ROOT / "brand" / "logo" / "svg" / "Знак черный4.svg"

# Доля ширины иконки, которую занимает знак.
SCALE_ICON = 0.62      # обычная иконка (iOS, legacy-mipmap): знак крупный, но с полями
SCALE_ADAPTIVE = 0.41  # adaptive-иконка Android: холст 108dp, видно только центральные
                       # 72dp — 0.41 от холста даёт те же ~62% внутри безопасной зоны,
                       # иначе лаунчер срежет лучи знака маской
SCALE_SPLASH = 0.46    # сплэш: на Android 12+ иконку обрезает круг, поэтому скромнее
ANDROID_DENSITIES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}


def hex_rgb(s: str) -> tuple[int, int, int]:
    s = s.lstrip("#")
    return tuple(int(s[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def load_polys(svg_path: Path) -> list[list[tuple[float, float]]]:
    """Точки многоугольников знака. В SVG только M/L/Z с абсолютными координатами."""
    text = svg_path.read_text(encoding="utf-8")
    polys = []
    for d in re.findall(r'<path[^>]*\bd="([^"]+)"', text):
        nums = [float(x) for x in re.findall(r"-?\d+(?:\.\d+)?", d)]
        polys.append(list(zip(nums[0::2], nums[1::2])))
    if not polys:
        raise SystemExit(f"В {svg_path} не нашлось ни одного <path>")
    return polys


class Mark:
    """Силуэт знака, отрисованный в нужном размере."""

    def __init__(self, polys):
        xs = [x for p in polys for x, _ in p]
        ys = [y for p in polys for _, y in p]
        self.x0, self.x1 = min(xs), max(xs)
        self.y0, self.y1 = min(ys), max(ys)
        self.polys = polys
        self.aspect = (self.y1 - self.y0) / (self.x1 - self.x0)

    def mask(self, width: int, ss: int = 4) -> Image.Image:
        w, h = max(1, width), max(1, int(round(width * self.aspect)))
        img = Image.new("L", (w * ss, h * ss), 0)
        d = ImageDraw.Draw(img)
        kx = w * ss / (self.x1 - self.x0)
        ky = h * ss / (self.y1 - self.y0)
        for p in self.polys:
            d.polygon([((x - self.x0) * kx, (y - self.y0) * ky) for x, y in p], fill=255)
        return img.resize((w, h), Image.LANCZOS)

    def draw(self, size: int, bg, fg, scale: float, transparent: bool = False) -> Image.Image:
        im = Image.new("RGBA" if transparent else "RGB", (size, size),
                       (0, 0, 0, 0) if transparent else bg)
        m = self.mask(max(1, int(round(size * scale))))
        im.paste(Image.new("RGB", m.size, fg), ((size - m.size[0]) // 2, (size - m.size[1]) // 2), m)
        return im


def write(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"  {path.relative_to(ROOT)}  {img.size[0]}x{img.size[1]}")


def sub(path: Path, old: str, new: str, *, count: int = 1) -> None:
    """Точечная замена в текстовом файле с проверкой, что нашли ровно одно место."""
    raw = path.read_bytes()
    enc = "utf-8-sig" if raw.startswith(b"\xef\xbb\xbf") else "utf-8"
    text = raw.decode(enc)
    found = text.count(old)
    if found != count:
        raise SystemExit(f"{path.name}: ожидал {count} совпадений, нашёл {found} — не трогаю")
    path.write_bytes(text.replace(old, new).encode(enc))
    print(f"  {path.relative_to(ROOT)}  обновлён")


def build_ios(app: Path, mark: Mark, bg, fg) -> None:
    iconset = app / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    meta = json.loads((iconset / "Contents.json").read_text(encoding="utf-8-sig"))
    print("iOS · иконки")
    for entry in meta["images"]:
        name = entry.get("filename")
        if not name:
            continue
        px = int(round(float(entry["size"].split("x")[0]) * float(entry["scale"].rstrip("x"))))
        write(mark.draw(px, bg, fg, SCALE_ICON), iconset / name)  # RGB — без альфы

    print("iOS · сплэш")
    launch = app / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    base_w = 120  # в поинтах; storyboard показывает картинку в натуральную величину
    for scale, name in ((1, "LaunchImage.png"), (2, "LaunchImage@2x.png"), (3, "LaunchImage@3x.png")):
        w = base_w * scale
        m = mark.mask(w)
        im = Image.new("RGBA", m.size, (0, 0, 0, 0))
        im.paste(Image.new("RGB", m.size, fg), (0, 0), m)
        write(im, launch / name)

    story = app / "ios/Runner/Base.lproj/LaunchScreen.storyboard"
    r, g, b = (c / 255 for c in bg)
    sub(story,
        '<color key="backgroundColor" red="1" green="1" blue="1" alpha="1"',
        f'<color key="backgroundColor" red="{r:.5f}" green="{g:.5f}" blue="{b:.5f}" alpha="1"')
    sub(story,
        re.search(r'<image name="LaunchImage" width="[\d.]+" height="[\d.]+"/>',
                  story.read_text(encoding="utf-8")).group(0),
        f'<image name="LaunchImage" width="{base_w}" height="{int(round(base_w * mark.aspect))}"/>')


def build_android(app: Path, mark: Mark, bg, fg) -> None:
    res = app / "android/app/src/main/res"
    print("Android · иконки")
    for dens, px in ANDROID_DENSITIES.items():
        write(mark.draw(px, bg, fg, SCALE_ICON), res / f"mipmap-{dens}/ic_launcher.png")

    fg_png = res / "drawable/ic_launcher_foreground.png"
    size = Image.open(fg_png).size[0] if fg_png.exists() else 432
    write(mark.draw(size, bg, fg, SCALE_ADAPTIVE, transparent=True), fg_png)

    print("Android · сплэш")
    logo = res / "drawable/launch_logo.png"
    size = Image.open(logo).size[0] if logo.exists() else 432
    write(mark.draw(size, bg, fg, SCALE_SPLASH, transparent=True), logo)

    colors = res / "values/colors.xml"
    cur = re.search(r'<color name="launch_background">(#[0-9A-Fa-f]{6,8})</color>',
                    colors.read_text(encoding="utf-8-sig"))
    if not cur:
        raise SystemExit("colors.xml: не нашёл launch_background")
    new = "#%02X%02X%02X" % bg
    if cur.group(1).upper() != new:
        sub(colors, cur.group(0), f'<color name="launch_background">{new}</color>')


def main() -> None:
    ap = argparse.ArgumentParser(description="Иконки и сплэш МАТА из фирменного знака")
    ap.add_argument("--app", required=True, choices=["kvartal", "store"])
    ap.add_argument("--bg", required=True, help="цвет фона, HEX (например 2A302C)")
    ap.add_argument("--fg", required=True, help="цвет знака, HEX (например EEEA83)")
    a = ap.parse_args()

    if not SVG.exists():
        raise SystemExit(f"Нет бренд-кита: {SVG}\nПапка brand/ лежит локально и не коммитится.")
    app = ROOT / ("mata_kvartal" if a.app == "kvartal" else "mata_store")
    bg, fg = hex_rgb(a.bg), hex_rgb(a.fg)

    print(f"{a.app}: знак #{a.fg.upper()} на фоне #{a.bg.upper()}")
    mark = Mark(load_polys(SVG))
    build_ios(app, mark, bg, fg)
    build_android(app, mark, bg, fg)
    print("Готово. Проверить: flutter clean && flutter run")


if __name__ == "__main__":
    main()
