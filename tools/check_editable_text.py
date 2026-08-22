#!/usr/bin/env python3
"""СТРАЖ редактируемости текстов приложения (mata_store).

Зачем: весь видимый КОНТЕНТ должен редактироваться владельцем в Конструкторе
(/admin/merch/), а не хардкодиться в коде. В приложении это делает виджет
`RemoteText(...)`. Если на НОВОМ экране появляется `Text('кириллица')` мимо
RemoteText — владелец не сможет это поменять, и придётся звать разработчика.
Страж ловит такое в CI и заставляет ОСОЗНАННО выбрать:

  1) Обернуть в RemoteText — если это КОНТЕНТ (заголовок/описание/подпись),
     который владелец правит в Конструкторе:
        RemoteText('screen.key', 'Текст по умолчанию')
  2) Пометить `// staw-static` — если это статичный служебный UI (кнопка
     диалога, системное сообщение), который править НЕ нужно:
        content: Text('Сессия истекла'),   // staw-static

Существующий на момент внедрения статический UI занесён в baseline-файл
(tools/editable_text_baseline.txt), поэтому страж падает ТОЛЬКО на НОВЫЙ
незакрытый хардкод. Обновить baseline осознанно: `--update-baseline`.

Эвристика намеренно простая (строковый литерал с кириллицей первым аргументом
`Text(...)`, интерполяция `$...` = динамика и не считается). `RemoteText(...)`
не матчится (граница слова у `\\bText\\(`). Область — только приложение mata_store.
Сайт (data-edit) сюда не входит.
"""
import os
import re
import sys

try:  # кириллица/символы в выводе не должны падать на Windows-cp1251
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCAN_DIR = os.path.join(ROOT, "mata_store", "lib")
BASELINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "editable_text_baseline.txt")
CYR = re.compile(r"[А-Яа-яЁё]")
# Text('....') / Text("....") — простой строковый литерал ПЕРВЫМ аргументом.
# \bText\( не матчит RemoteText( (нет границы слова перед Text).
TEXT_LIT = re.compile(r"""\bText\(\s*(['"])(.*?)\1""", re.DOTALL)
SUPPRESS = "staw-static"  # маркер осознанно-статичного текста


def line_of(src, idx):
    return src.count("\n", 0, idx) + 1


def norm(literal):
    """Ключ для baseline: сворачиваем переводы строк, чтобы был однострочным и стабильным."""
    return literal.replace("\r", " ").replace("\n", "\\n").strip()


def find_all():
    """Все кириллические Text('...') мимо RemoteText, кроме подавленных // staw-static.
    Возвращает список (relpath, line, normalized_literal)."""
    found = []
    for dirpath, _dirs, files in os.walk(SCAN_DIR):
        for name in files:
            if not name.endswith(".dart"):
                continue
            path = os.path.join(dirpath, name)
            with open(path, encoding="utf-8") as f:
                src = f.read()
            lines = src.splitlines()
            for m in TEXT_LIT.finditer(src):
                literal = m.group(2)
                if not CYR.search(literal) or "$" in literal:
                    continue  # нет кириллицы или интерполяция (динамика) — пропуск
                ln = line_of(src, m.start())
                cur = lines[ln - 1] if 0 < ln <= len(lines) else ""
                prev = lines[ln - 2] if ln >= 2 else ""
                if SUPPRESS in cur or SUPPRESS in prev:
                    continue  # осознанно статичный текст
                rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
                found.append((rel, ln, norm(literal)))
    return found


def bkey(rel, lit):
    return rel + "\t" + lit


def load_baseline():
    allowed = set()
    if os.path.exists(BASELINE):
        with open(BASELINE, encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                if not line or line.lstrip().startswith("#"):
                    continue
                allowed.add(line)
    return allowed


def write_baseline(found):
    lines = [
        "# baseline стража редактируемости (tools/check_editable_text.py).",
        "# Существующий статичный UI приложения на момент внедрения. Формат: relpath<TAB>текст.",
        "# Страж падает только на НОВЫЕ строки вне этого списка. Обновлять осознанно (--update-baseline).",
        "",
    ]
    for rel, lit in sorted(set((r, l) for r, _n, l in found)):
        lines.append(bkey(rel, lit))
    with open(BASELINE, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def main(argv):
    if not os.path.isdir(SCAN_DIR):
        print(f"check_editable_text: каталог не найден: {SCAN_DIR}", file=sys.stderr)
        return 1
    found = find_all()
    if "--update-baseline" in argv:
        write_baseline(found)
        print(f"✓ baseline обновлён: {len(set((r, l) for r, _n, l in found))} записей → {os.path.relpath(BASELINE, ROOT)}")
        return 0
    allowed = load_baseline()
    new = [(rel, ln, lit) for (rel, ln, lit) in found if bkey(rel, lit) not in allowed]
    if not new:
        print(f"✓ Страж редактируемости: нового хардкод-текста нет (baseline: {len(allowed)}).")
        return 0
    print("✗ Страж редактируемости: НОВЫЙ хардкод-текст мимо RemoteText:\n")
    for rel, ln, lit in sorted(new):
        print(f"  {rel}:{ln}:  Text('{lit[:70]}')")
    print(
        "\nВыберите для каждого:\n"
        "  • КОНТЕНТ (владелец правит в Конструкторе) → RemoteText('screen.key', 'Текст по умолчанию')\n"
        "  • Статичный служебный UI → в конце строки пометьте:  // staw-static\n"
        "  • (осознанно) внести в baseline:  python tools/check_editable_text.py --update-baseline\n"
    )
    print(f"Новых нарушений: {len(new)}")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
