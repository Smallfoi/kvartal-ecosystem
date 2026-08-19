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
# Формы, которыми брендируем приложения. Обе берём из ВЕКТОРА — цвет задаём сами.
#   mark — знак-«вертушка» (Квартал);
#   slab — скошенный квадрат, «Элемент 1» (Store).
SHAPES = {
    "mark": {
        "svg": Path("logo") / "svg" / "Знак черный4.svg",
        "fit": "circle",  # размер меряем описанной окружностью
        "icon": 0.76, "adaptive": 0.51, "splash": 0.60,
    },
    "slab": {
        "svg": Path("elements") / "фирменные элементы.svg",
        "fit": "width",   # плашка широкая и низкая: окружность дала бы её крошечной
        "icon": 0.62, "adaptive": 0.41, "splash": 0.50,
    },
}

# Знак несимметричный: один длинный луч вправо, два диагональных влево. Центрировать его
# по габаритной рамке НЕЛЬЗЯ — рамку растягивает правый луч, и знак уезжает влево от
# оптического центра (замерено: 41.6 из 280 единиц, ~15% ширины; владелец увидел глазом).
# Поэтому сажаем знак по ЦЕНТРУ МАСС, а размер меряем описанной вокруг него окружностью:
# так знак занимает предсказуемую долю плитки независимо от того, куда торчат лучи.
# Доли в SHAPES: «icon» — обычная иконка; «adaptive» — Android-adaptive, где холст 108dp,
# а видно только центральные 72dp (0.51/0.41 холста дают ту же долю внутри видимой зоны —
# иначе маска срежет края); «splash» — на Android 12+ картинку дополнительно обрезает круг.
SLAB_RATIO = 1.71  # ширина/высота «Элемента 1», сверено с PNG-экспортом 476×278
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


def load_slab(svg_path: Path) -> list[list[tuple[float, float]]]:
    """Скошенный квадрат («Элемент 1») из общего SVG фирменных элементов.

    Ищем не по порядковому номеру, а по признаку: полигон, у которого после отбрасывания
    промежуточных точек на сторонах остаётся ровно 4 угла и противоположные стороны равны
    и параллельны. Так выбор не сломается, если студия пересохранит файл в другом порядке.
    """
    text = svg_path.read_text(encoding="utf-8")
    found = []
    for raw in re.findall(r'<polygon[^>]*points="([^"]+)"', text):
        nums = [float(x) for x in re.findall(r"-?\d+(?:\.\d+)?", raw)]
        pts = list(zip(nums[0::2], nums[1::2]))
        if pts and pts[0] == pts[-1]:
            pts = pts[:-1]
        corners = _drop_collinear(pts)
        if len(corners) == 4 and _is_parallelogram(corners):
            xs = [x for x, _ in corners]
            ys = [y for _, y in corners]
            found.append(((max(xs) - min(xs)) / (max(ys) - min(ys)), corners))
    if not found:
        raise SystemExit(f"В {svg_path} не нашлось ни одного параллелограмма")
    # Параллелограммов в файле несколько: сам элемент и длинные полосы паттерна
    # (отношение ~4.6). Берём тот, чьи пропорции совпадают с «Элементом 1» — 1.71,
    # сверено с PNG-экспортом 476×278.
    ratio, corners = min(found, key=lambda t: abs(t[0] - SLAB_RATIO))
    if abs(ratio - SLAB_RATIO) > 0.15:
        raise SystemExit(f"Похожего на «Элемент 1» не нашлось: ближайшее отношение {ratio:.2f}")
    return [corners]


def _drop_collinear(pts, eps: float = 0.5):
    """Убирает точки, лежащие на прямой между соседями (студия ставит их на сторонах)."""
    out = []
    n = len(pts)
    for i, p in enumerate(pts):
        a, b = pts[i - 1], pts[(i + 1) % n]
        area2 = abs((b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]))
        side = math.hypot(b[0] - a[0], b[1] - a[1]) or 1.0
        if area2 / side > eps:
            out.append(p)
    return out


def _is_parallelogram(c, eps: float = 0.5) -> bool:
    # Стороны 0→1 и 2→3 в параллелограмме противонаправлены: их сумма ≈ 0.
    return (abs((c[1][0] - c[0][0]) + (c[3][0] - c[2][0])) < eps
            and abs((c[1][1] - c[0][1]) + (c[3][1] - c[2][1])) < eps)


class Mark:
    """Знак: центр масс, радиус описанной окружности и отрисовка в нужном размере."""

    SS = 4  # суперсэмплинг

    def __init__(self, polys):
        self.polys = polys
        self.cx, self.cy = self._centroid()
        self.r = max(math.hypot(x - self.cx, y - self.cy) for p in polys for x, y in p)
        xs = [x for p in polys for x, _ in p]
        self.w = max(xs) - min(xs)

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

    def mask(self, size: int, fill: float, fit: str = "circle") -> Image.Image:
        """Квадратная маска size×size: центр масс фигуры ровно в центре плитки."""
        ss = self.SS
        m = Image.new("L", (size * ss, size * ss), 0)
        d = ImageDraw.Draw(m)
        base = 2 * self.r if fit == "circle" else self.w
        k = fill * size * ss / base
        half = size * ss / 2
        for p in self.polys:
            d.polygon([((x - self.cx) * k + half, (y - self.cy) * k + half) for x, y in p], fill=255)
        return m.resize((size, size), Image.LANCZOS)

    def draw(self, size: int, bg, fg, fill: float, fit: str = "circle",
             transparent: bool = False) -> Image.Image:
        im = Image.new("RGBA" if transparent else "RGB", (size, size),
                       (0, 0, 0, 0) if transparent else bg)
        im.paste(Image.new("RGB", (size, size), fg), (0, 0), self.mask(size, fill, fit))
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


def build_ios(app: Path, mark: Mark, bg, fg, sh: dict, sbg, sfg) -> None:
    iconset = app / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    meta = json.loads((iconset / "Contents.json").read_text(encoding="utf-8-sig"))
    print("iOS · иконки")
    for entry in meta["images"]:
        name = entry.get("filename")
        if not name:
            continue
        px = int(round(float(entry["size"].split("x")[0]) * float(entry["scale"].rstrip("x"))))
        write(mark.draw(px, bg, fg, sh["icon"], sh["fit"]), iconset / name)  # RGB — без альфы

    print("iOS · сплэш")
    launch = app / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    base = 200  # сторона квадрата в поинтах; storyboard рисует картинку 1:1
    for scale, name in ((1, "LaunchImage.png"), (2, "LaunchImage@2x.png"), (3, "LaunchImage@3x.png")):
        write(mark.draw(base * scale, sbg, sfg, sh["splash"], sh["fit"], transparent=True),
              launch / name)

    story = app / "ios/Runner/Base.lproj/LaunchScreen.storyboard"
    text = story.read_text(encoding="utf-8")
    r, g, b = (c / 255 for c in sbg)
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


ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
"""
ICON_BG_XML = """<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="@color/launch_background" />
</shape>
"""
LAUNCH_BG_XML = """<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/splash_background" />
    <item>
        <bitmap
            android:gravity="center"
            android:src="@drawable/launch_logo" />
    </item>
</layer-list>
"""
COLORS_XML = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Фон adaptive-иконки. -->
    <color name="launch_background">%s</color>
    <!-- Фон экрана запуска: у приложения может быть другая база, чем у иконки. -->
    <color name="splash_background">%s</color>
</resources>
"""
# Android 12+ рисует свой экран запуска и старый layer-list игнорирует.
STYLES_V31_XML = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="%s">
        <item name="android:windowBackground">@drawable/launch_background</item>
        <item name="android:windowSplashScreenBackground">@color/splash_background</item>
        <item name="android:windowSplashScreenAnimatedIcon">@drawable/launch_logo</item>
    </style>
</resources>
"""


def put(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    print(f"  {path.relative_to(ROOT)}  записан")


def scaffold_android(res: Path, bg, splash_bg) -> None:
    """Дособирает файлы, которых нет в стоковом шаблоне Flutter (Store был на нём).

    Существующее не переписываем — кроме launch_background.xml, если он ещё шаблонный
    (белый фон без логотипа): иначе экран запуска остался бы пустым.
    """
    if not (res / "values/colors.xml").exists():
        put(res / "values/colors.xml",
            COLORS_XML % ("#%02X%02X%02X" % bg, "#%02X%02X%02X" % splash_bg))
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        if not (res / "mipmap-anydpi-v26" / name).exists():
            put(res / "mipmap-anydpi-v26" / name, ADAPTIVE_XML)
    if not (res / "drawable/ic_launcher_background.xml").exists():
        put(res / "drawable/ic_launcher_background.xml", ICON_BG_XML)
    for sub_dir in ("drawable", "drawable-v21"):
        f = res / sub_dir / "launch_background.xml"
        if f.exists() and "launch_logo" not in f.read_text(encoding="utf-8"):
            put(f, LAUNCH_BG_XML)
    v31 = res / "values-v31/styles.xml"
    if not v31.exists():
        base = re.search(r'<style name="LaunchTheme" parent="([^"]+)"',
                         (res / "values/styles.xml").read_text(encoding="utf-8-sig"))
        put(v31, STYLES_V31_XML % (base.group(1) if base else "@android:style/Theme.Light.NoTitleBar"))


def build_android(app: Path, mark: Mark, bg, fg, sh: dict, sbg, sfg) -> None:
    res = app / "android/app/src/main/res"
    scaffold_android(res, bg, sbg)
    print("Android · иконки")
    for dens, px in ANDROID_DENSITIES.items():
        write(mark.draw(px, bg, fg, sh["icon"], sh["fit"]), res / f"mipmap-{dens}/ic_launcher.png")

    fg_png = res / "drawable/ic_launcher_foreground.png"
    size = Image.open(fg_png).size[0] if fg_png.exists() else 432
    write(mark.draw(size, bg, fg, sh["adaptive"], sh["fit"], transparent=True), fg_png)

    print("Android · сплэш")
    logo = res / "drawable/launch_logo.png"
    size = Image.open(logo).size[0] if logo.exists() else 432
    write(mark.draw(size, sbg, sfg, sh["splash"], sh["fit"], transparent=True), logo)

    colors = res / "values/colors.xml"
    text = colors.read_text(encoding="utf-8-sig")
    for name, value in (("launch_background", bg), ("splash_background", sbg)):
        want = "#%02X%02X%02X" % value
        cur = re.search(r'<color name="%s">(#[0-9A-Fa-f]{6,8})</color>' % name, text)
        if cur is None:
            # Ресурса ещё нет (приложение делали до разделения цветов) — добавляем.
            text = text.replace("</resources>",
                                '    <color name="%s">%s</color>\n</resources>' % (name, want))
            colors.write_text(text, encoding="utf-8")
            print(f"  {colors.relative_to(ROOT)}  добавлен {name}")
        elif cur.group(1).upper() != want:
            sub(colors, cur.group(0), f'<color name="{name}">{want}</color>')
            text = colors.read_text(encoding="utf-8-sig")

    # Экраны запуска старых приложений ссылались на цвет иконки — переводим на свой.
    for rel in ("drawable/launch_background.xml", "drawable-v21/launch_background.xml",
                "values-v31/styles.xml"):
        f = res / rel
        if not f.exists():
            continue
        t = f.read_text(encoding="utf-8-sig")
        if "windowSplashScreenBackground" in t or "layer-list" in t:
            t2 = t.replace("@color/launch_background", "@color/splash_background")
            if t2 != t:
                f.write_text(t2, encoding="utf-8")
                print(f"  {f.relative_to(ROOT)}  сплэш переведён на splash_background")


def main() -> None:
    ap = argparse.ArgumentParser(description="Иконки и сплэш МАТА из фирменного знака")
    ap.add_argument("--app", required=True, choices=["kvartal", "store"])
    ap.add_argument("--bg", required=True, help="цвет фона, HEX (например 2A302C)")
    ap.add_argument("--fg", required=True, help="цвет знака, HEX (например EEEA83)")
    ap.add_argument("--splash-bg", help="фон экрана запуска, HEX (по умолчанию — как у иконки)")
    ap.add_argument("--splash-fg", help="цвет знака на экране запуска (по умолчанию — как у иконки)")
    ap.add_argument("--shape", default="mark", choices=sorted(SHAPES),
                    help="mark — знак-вертушка (Квартал); slab — скошенный квадрат (Store)")
    ap.add_argument("--brand", default=str(ROOT / "brand"),
                    help="папка бренд-кита; нужна при запуске из git worktree, "
                         "куда локальная brand/ не попадает")
    a = ap.parse_args()

    sh = SHAPES[a.shape]
    svg = Path(a.brand) / sh["svg"]
    if not svg.exists():
        raise SystemExit(
            f"Нет бренд-кита: {svg}. Папка brand/ лежит локально и не "
            "коммитится; из worktree указывай путь через --brand."
        )
    app = ROOT / ("mata_kvartal" if a.app == "kvartal" else "mata_store")
    bg, fg = hex_rgb(a.bg), hex_rgb(a.fg)
    sbg = hex_rgb(a.splash_bg) if a.splash_bg else bg
    sfg = hex_rgb(a.splash_fg) if a.splash_fg else fg

    print(f"{a.app}: {a.shape} #{a.fg.upper()} на фоне #{a.bg.upper()}")
    mark = Mark(load_polys(svg) if a.shape == "mark" else load_slab(svg))
    build_ios(app, mark, bg, fg, sh, sbg, sfg)
    build_android(app, mark, bg, fg, sh, sbg, sfg)
    print("Готово. Проверить: flutter clean && flutter run")


if __name__ == "__main__":
    main()
