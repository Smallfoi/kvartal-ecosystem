# -*- coding: utf-8 -*-
"""Генерация иконок Квартала из эталона painter'а (build/mark_icon_1024.png).
Масштабы рамки сняты с прежних ассетов, чтобы сплэш-переход остался 1:1."""
from PIL import Image

BG = (42, 48, 44)  # #2A302C — фон иконки и нативного сплэша
FRAME_IN_MARK = 738.0  # ширина рамки знака в эталоне 1024 (34.6/48*1024)

mark = Image.open('build/mark_icon_1024.png').convert('RGBA')


def scaled(frame_px):
    """Знак, отмасштабированный так, чтобы рамка была frame_px."""
    s = int(round(1024 * frame_px / FRAME_IN_MARK))
    return mark.resize((s, s), Image.LANCZOS), s


def compose(canvas_px, frame_px, background=None):
    im = Image.new('RGBA', (canvas_px, canvas_px),
                   (background + (255,)) if background else (0, 0, 0, 0))
    m, s = scaled(frame_px)
    off = (canvas_px - s) // 2
    im.alpha_composite(m, (off, off))
    return im.convert('RGB') if background else im


# ── Android mipmap: full-bleed графит, знак 0.78 стороны ──
for dpi, n in (('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
               ('xxhdpi', 144), ('xxxhdpi', 192)):
    compose(n, 0.72 * 0.78 * n, BG).save(
        'android/app/src/main/res/mipmap-%s/ic_launcher.png' % dpi)

# ── adaptive foreground (432, рамка 167 как раньше) ──
compose(432, 167).save(
    'android/app/src/main/res/drawable/ic_launcher_foreground.png')

# ── нативный сплэш launch_logo ──
# Калибровка бесшовного запуска (2026-08-23): системная сплэш-иконка живёт в
# контейнере 240dp с центром выше центра экрана; OEM-зум плитки лаунчера
# заканчивается рамкой ~316px (90dp) ровно в центре экрана. Знак внутри холста
# 432 смещён вниз и уменьшен так, чтобы на экране встать точно в финал зума:
# рамка 196px холста, центр знака (216, 320) — по замерам rec5 система
# рисует контент с масштабом 1.611: экранная рамка 196*1.611=316px точно в
# финале зума. Сборка через расширенный холст: scaled-квадрат вылезает за
# 432 прозрачными полями — компонуем на 600 и режем.
li_mark, li_s = scaled(196)
tmp = Image.new('RGBA', (600, 600), (0, 0, 0, 0))
tmp.alpha_composite(li_mark, (300 - li_s // 2, 404 - li_s // 2))
tmp.crop((84, 84, 516, 516)).save(
    'android/app/src/main/res/drawable/launch_logo.png')

# ── iOS AppIcon (фон обязателен) ──
ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/'
for name, n in (('Icon-App-20x20@1x', 20), ('Icon-App-20x20@2x', 40),
                ('Icon-App-20x20@3x', 60), ('Icon-App-29x29@1x', 29),
                ('Icon-App-29x29@2x', 58), ('Icon-App-29x29@3x', 87),
                ('Icon-App-40x40@1x', 40), ('Icon-App-40x40@2x', 80),
                ('Icon-App-40x40@3x', 120), ('Icon-App-60x60@2x', 120),
                ('Icon-App-60x60@3x', 180), ('Icon-App-76x76@1x', 76),
                ('Icon-App-76x76@2x', 152), ('Icon-App-83.5x83.5@2x', 167),
                ('Icon-App-1024x1024@1x', 1024)):
    compose(n, 0.72 * 0.78 * n, BG).save(ios + name + '.png')

# ── iOS LaunchImage (рамки 91/183/274 как раньше) ──
li = 'ios/Runner/Assets.xcassets/LaunchImage.imageset/'
compose(200, 91).save(li + 'LaunchImage.png')
compose(400, 183).save(li + 'LaunchImage@2x.png')
compose(600, 274).save(li + 'LaunchImage@3x.png')

print('icons generated')
