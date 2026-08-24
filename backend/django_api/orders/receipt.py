"""Состав чека по 54-ФЗ из заказа (D-13).

Чек обязателен при ЛЮБОМ способе расчёта — картой, по СБП, переводом. Формирует
его не наш сервер, а онлайн-касса: мы передаём состав чека вместе с платежом,
ЮKassa отдаёт его подключённой кассе, касса пробивает и шлёт покупателю и в ФНС.

Главное правило, из-за которого чеки чаще всего не проходят: **сумма позиций
должна в точности совпадать с суммой платежа**. У нас сверху доставка, снизу —
скидка баллами, поэтому сумму раскладываем сами.

Две ловушки, на которых легко ошибиться:

1. В позиции указывается **цена за единицу**, а не сумма строки. Поэтому две
   одинаковые вещи со скидкой не всегда делятся на копейки нацело.
2. Скидку нельзя просто вычесть из последней позиции: списанных баллов может
   быть больше, чем стоит доставка, и позиция уйдёт в минус.

Поэтому каждая единица товара идёт **отдельной позицией с количеством 1**, а
скидка раскладывается по позициям пропорционально, с точностью до копейки.
Чек становится чуть длиннее, зато сходится всегда и на любых суммах.

Маркировка. Одежда и обувь маркируются «Честным знаком»: в позиции должен
уходить код маркировки (`mark_code_info`). Кодов у нас пока нет — их выдаёт
«Честный знак» на конкретную единицу товара, и появятся они, когда владелец
зарегистрируется в системе. Место для кода готово: если в позиции заказа есть
`markCode`, он уйдёт в чек. Без кода чек на маркированный товар касса не примет —
это ограничение закона, а не наше.
"""
import os

_NAME_LIMIT = 128  # ограничение 54-ФЗ на наименование предмета расчёта


def _tax_system() -> int:
    """ЮKassa `tax_system_code`: 1 ОСН, 2 УСН доход, 3 УСН доход-расход,
    4 ЕНВД, 5 ЕСХН, 6 патент. ИП на УСН «доходы» — 2."""
    return int(os.environ.get("PAYMENT_TAX_SYSTEM") or 2)


def _vat() -> int:
    """Ставка НДС в позиции (`vat_code`): 1 — без НДС. Для УСН это она."""
    return int(os.environ.get("PAYMENT_VAT_CODE") or 1)


def receipts_enabled() -> bool:
    """Передавать ли состав чека провайдеру.

    Выключено, пока к ЮKassa не подключена касса: с включённым чеком и без кассы
    платёж не создастся вовсе, и покупатель упрётся в ошибку на ровном месте.
    """
    return (os.environ.get("PAYMENT_RECEIPT") or "").strip() in ("1", "true", "yes")


def _kop(value) -> int:
    """Рубли → копейки. Считаем в целых, иначе округления разъезжаются."""
    return int(round(float(value or 0) * 100))


def _rub(kopecks) -> str:
    return f"{kopecks / 100:.2f}"


def _name(item) -> str:
    """Наименование позиции: товар + размер и цвет, если они есть."""
    base = str(item.get("productName") or "Товар").strip()
    extra = [str(item.get(k)).strip() for k in ("size", "color") if item.get(k)]
    full = f"{base} ({', '.join(extra)})" if extra else base
    return full[:_NAME_LIMIT]


def _customer(checkout) -> dict:
    """Куда касса отправит чек. Без email или телефона чек пробить нельзя."""
    who = {}
    email = str(checkout.get("email") or "").strip()
    phone = str(checkout.get("phone") or "").strip()
    if email:
        who["email"] = email
    if phone:
        who["phone"] = phone
    return who


def _fit(prices, target):
    """Подогнать позиции под сумму платежа, сохранив пропорции.

    `prices` — цены позиций в копейках (каждая позиция — одна единица товара).
    Пропорциональное уменьшение даёт дробные копейки, поэтому округляем вниз,
    а остаток раздаём по копейке, начиная с самых дорогих позиций: так сумма
    сходится точно, а перекос цен минимален.
    """
    base = sum(prices)
    if base <= 0 or target <= 0:
        raise ValueError("Нулевая сумма — чек собрать нельзя")
    if target < len(prices):
        raise ValueError("Скидка съедает позиции до нуля — чек собрать нельзя")

    fitted = [max(1, p * target // base) for p in prices]
    left = target - sum(fitted)
    order = sorted(range(len(prices)), key=lambda i: prices[i], reverse=True)
    step = 1 if left > 0 else -1
    i = 0
    while left != 0:
        idx = order[i % len(order)]
        if step < 0 and fitted[idx] <= 1:  # ниже копейки позицию не опускаем
            i += 1
            continue
        fitted[idx] += step
        left -= step
        i += 1
    return fitted


def build_receipt(payload, amount):
    """Состав чека для ЮKassa или None, если чек передавать не нужно.

    Возвращает None при выключенной фискализации. Если фискализация включена, но
    состав собрать нельзя (нет позиций или контакта покупателя) — поднимает
    ValueError: молча отправить платёж без чека нельзя, это нарушение 54-ФЗ.
    """
    if not receipts_enabled():
        return None

    payload = payload or {}
    checkout = payload.get("checkoutData") or {}
    customer = _customer(checkout)
    if not customer:
        raise ValueError("Для чека нужен email или телефон покупателя")

    vat = _vat()
    lines = []  # (описание, цена в копейках, предмет расчёта, код маркировки)

    for it in payload.get("items") or []:
        qty = max(1, int(it.get("quantity") or 1))
        unit = _kop(it.get("price"))
        if unit <= 0:
            continue
        mark = str(it.get("markCode") or "").strip()
        # Каждая единица — отдельная позиция: так и скидка раскладывается точно,
        # и код маркировки привязывается к конкретной вещи (он у каждой свой).
        for _ in range(qty):
            lines.append((_name(it), unit, "commodity", mark))

    delivery = _kop(payload.get("deliveryCost"))
    if delivery > 0:
        lines.append(("Доставка", delivery, "service", ""))

    if not lines:
        raise ValueError("В заказе нет позиций для чека")
    if len(lines) > 100:
        raise ValueError("Слишком много позиций для одного чека")

    fitted = _fit([price for _, price, _, _ in lines], _kop(amount))

    items = []
    for (name, _price, subject, mark), value in zip(lines, fitted):
        position = {
            "description": name,
            "quantity": "1",
            "amount": {"value": _rub(value), "currency": "RUB"},
            "vat_code": vat,
            "payment_mode": "full_payment",
            "payment_subject": subject,
            "measure": "piece" if subject == "commodity" else "another",
        }
        if mark:
            position["mark_code_info"] = {"gs_1m": mark}
        items.append(position)

    return {"customer": customer, "tax_system_code": _tax_system(), "items": items}
