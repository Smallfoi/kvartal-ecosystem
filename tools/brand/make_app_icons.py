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
import math
import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
BRAND_REL = Path("logo") / "svg" / "Знак черный4.svg"  # знак в SVG (цвет задаём сами)

# Знак несимметричный: один длинный луч вправо, два диагональных влево. Центрировать его
# по габаритной рамке НЕЛЬЗЯ — рамку растягивает правый луч, и знак уезжает влево от
# оптического центра (замерено: 41.6 из 280 единиц, ~15% ширины; владелец увидел глазом).
# Поэтому сажаем знак по ЦЕНТРУ МАСС, а размер меряем описанной вокруг него окружностью:
# так знак занимает предсказуемую долю плитки независимо от того, куда торчат лучи.
FILL_ICON = 0.76      # диаметр описанного круга к стороне иконки
FILL_ADAPTIVE = 0.51  # adaptive-иконка Android: холст 108dp, видно центральные 72dp —
                      # 0.51 холста даёт те же ~0.76 внутри видимой зоны, иначе маска
                      # срежет лучи знака
FILL_SPLASH = 0.60    # сплэш: на Android 12+ иконку дополнительно обрезает круг
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
    """Знак: центр масс, радиус описанной окружности и отрисовка в нужном размере."""

    SS = 4  # суперсэмплинг

    def __init__(self, polys):
        self.polys = polys
        self.cx, self.cy = self._centroid()
        self.r = max(math.hypot(x - self.cx, y - self.cy) for p in polys for x, y in p)

    def _centroid(self, grid: int = 512) -> tuple[float, float]:
        """Центр масс залитой площади — оптический центр знака."""
        xs = [x for p in self.polys for x, _ in p]
        ys = [y for p in self.polys for _, y in p]
        x0, y0 = min(xs), min(ys)
        k = grid / max(max(xs) - x0, max(ys) - y0)
        img = Image.new("L", (grid, grid), 0)
        d = ImageDraw.Draw(img)
        for p in self.polys:
            d.polygon([((x - x0) * k, (y - y0) * k) for x, y in p], fill=255)
        px = img.load()
        sx = sy = n = 0
        for yy in range(grid):
            for xx in range(grid):
                if px[xx, yy] > 127:
                    sx += xx
                    sy += yy
                    n += 1
        return x0 + sx / n / k, y0 + sy / n / k

    def mask(self, size: int, fill: float) -> Image.Image:
        """Квадратная маска size×size: центр масс знака ровно в центре плитки."""
        ss = self.SS
        m = Image.new("L", (size * ss, size * ss), 0)
        d = ImageDraw.Draw(m)
        k = fill * size * ss / (2 * self.r)
        half = size * ss / 2
        for p in self.polys:
            d.polygon([((x - self.cx) * k + half, (y - self.cy) * k + half) for x, y in p], fill=255)
        return m.resize((size, size), Image.LANCZOS)

    def draw(self, size: int, bg, fg, fill: float, transparent: bool = False) -> Image.Image:
        im = Image.new("RGBA" if transparent else "RGB", (size, size),
                       (0, 0, 0, 0) if transparent else bg)
        im.paste(Image.new("RGB", (size, size), fg), (0, 0), self.mask(size, fill))
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
        write(mark.draw(px, bg, fg, FILL_ICON), iconset / name)  # RGB — без альфы

    print("iOS · сплэш")
    launch = app / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    base = 200  # сторона квадрата в поинтах; storyboard рисует картинку 1:1
    for scale, name in ((1, "LaunchImage.png"), (2, "LaunchImage@2x.png"), (3, "LaunchImage@3x.png")):
        write(mark.draw(base * scale, bg, fg, FILL_SPLASH, transparent=True), launch / name)

    story = app / "ios/Runner/Base.lproj/LaunchScreen.storyboard"
    text = story.read_text(encoding="utf-8")
    r, g, b = (c / 255 for c in bg)
    want = f'red="{r:.5f}" green="{g:.5f}" blue="{b:.5f}" alpha="1"'
    if want not in text:  # шаг идемпотентный: повторный запуск с тем же цветом ничего не трогает
        cur = re.search(r'<color key="backgroundColor" red="[\d.]+" green="[\d.]+" blue="[\d.]+" alpha="1"', text)
        if not cur:
            raise SystemExit("storyboard: не нашёл цвет фона экрана запуска")
        sub(story, cur.group(0), f'<color key="backgroundColor" {want}')
        text = story.read_text(encoding="utf-8")

    cur = re.search(r'<image name="LaunchImage" width="[\d.]+" height="[\d.]+"/>', text)
    want_img = f'<image name="LaunchImage" width="{base}" height="{base}"/>'
    if cur and cur.group(0) != want_img:
        sub(story, cur.group(0), want_img)


def build_android(app: Path, mark: Mark, bg, fg) -> None:
    res = app / "android/app/src/main/res"
    print("Android · иконки")
    for dens, px in ANDROID_DENSITIES.items():
        write(mark.draw(px, bg, fg, FILL_ICON), res / f"mipmap-{dens}/ic_launcher.png")

    fg_png = res / "drawable/ic_launcher_foreground.png"
    size = Image.open(fg_png).size[0] if fg_png.exists() else 432
    write(mark.draw(size, bg, fg, FILL_ADAPTIVE, transparent=True), fg_png)

    print("Android · сплэш")
    logo = res / "drawable/launch_logo.png"
    size = Image.open(logo).size[0] if logo.exists() else 432
    write(mark.draw(size, bg, fg, FILL_SPLASH, transparent=True), logo)

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
    ap.add_argument("--brand", default=str(ROOT / "brand"),
                    help="папка бренд-кита; нужна при запуске из git worktree, "
                         "куда локальная brand/ не попадает")
    a = ap.parse_args()

    svg = Path(a.brand) / BRAND_REL
    if not svg.exists():
        raise SystemExit(
            f"Нет бренд-кита: {svg}. Папка brand/ лежит локально и не "
            "коммитится; из worktree указывай путь через --brand."
        )
    app = ROOT / ("mata_kvartal" if a.app == "kvartal" else "mata_store")
    bg, fg = hex_rgb(a.bg), hex_rgb(a.fg)

    print(f"{a.app}: знак #{a.fg.upper()} на фоне #{a.bg.upper()}")
    mark = Mark(load_polys(svg))
    build_ios(app, mark, bg, fg)
    build_android(app, mark, bg, fg)
    print("Готово. Проверить: flutter clean && flutter run")


if __name__ == "__main__":
    main()
