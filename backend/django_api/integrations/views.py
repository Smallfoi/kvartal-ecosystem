"""Точки подключения часов COROS.

Заявка в COROS требует указать три адреса ещё до выдачи ключей: куда вернуть
пользователя после разрешения доступа, куда присылать готовые тренировки и как
проверить, что наш сервис жив. Эти адреса должны существовать на момент
рассмотрения — поэтому они здесь, пусть пока и в минимальном виде.

Разбор данных появится, когда COROS выдаст Client ID и Secret: до этого проверить
подпись запроса нечем, а принимать чужие данные без проверки нельзя.
"""
import json
import secrets

from django.conf import settings

from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response


@api_view(["GET"])
@permission_classes([AllowAny])
def coros_callback(request):
    """Куда COROS возвращает человека после того, как он разрешил доступ.

    Придут `code` и `state`; на код меняется токен доступа — этот обмен добавим
    вместе с ключами. Сейчас отвечаем понятной страницей, а не ошибкой: человек
    не должен упереться в пустоту, если попал сюда раньше времени.
    """
    code = request.query_params.get("code", "")
    return Response({
        "ok": True,
        "received": bool(code),
        "detail": "Подключение COROS готовится. Вернитесь в приложение.",
    })


@api_view(["POST"])
@permission_classes([AllowAny])
def coros_push(request):
    """Сюда COROS присылает завершённые тренировки.

    Отвечаем 200 на любой корректный запрос: для отправителя это подтверждение
    доставки. Пока ключей нет, содержимое не разбираем — подпись проверить нечем,
    а верить неподписанным данным о чужих тренировках нельзя.
    """
    try:
        body = request.data if isinstance(request.data, (dict, list)) else json.loads(request.body or b"{}")
    except (ValueError, TypeError):
        return Response({"detail": "Некорректный JSON"}, status=400)
    count = len(body) if isinstance(body, list) else 1
    print(f"COROS push: получено записей {count} в {timezone.now().isoformat()}.")
    return Response({"ok": True, "received": count})


@api_view(["GET"])
@permission_classes([AllowAny])
def coros_status(request):
    """Проверка «сервис жив» — её COROS опрашивает сам."""
    return Response({"status": "ok", "service": "MATA integrations", "time": timezone.now().isoformat()})


# ─────────────────────────── Обмен с 1С (D-62) ───────────────────────────

def _onec_authorized(request) -> bool:
    """Токен обмена: заголовок Authorization: Bearer <токен>.
    Пустой токен в настройках = приём выключен."""
    expected = (settings.INTEGRATION_1C_TOKEN or "").strip()
    if not expected:
        return False
    got = (request.headers.get("Authorization") or "").strip()
    if got.lower().startswith("bearer "):
        got = got[7:].strip()
    return secrets.compare_digest(got, expected)


def _onec_items(request, key: str):
    """Принимаем и массив, и объект вида {"products": [...]} — 1С удобнее слать по-разному."""
    data = request.data
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        for k in (key, "items", "data"):
            if isinstance(data.get(k), list):
                return data[k]
    return None


@api_view(["POST"])
@permission_classes([AllowAny])
def onec_catalog(request):
    """Карточки товаров из 1С. Переопределённые владельцем поля не трогаем."""
    if not _onec_authorized(request):
        return Response({"detail": "Требуется токен обмена"}, status=401)
    items = _onec_items(request, "products")
    if items is None:
        return Response({"detail": "Ожидается массив товаров или {\"products\": [...]}"}, status=400)
    from .onec import import_catalog
    return Response(import_catalog(items))


@api_view(["POST"])
@permission_classes([AllowAny])
def onec_prices(request):
    """Цены и остатки из 1С — частый поток."""
    if not _onec_authorized(request):
        return Response({"detail": "Требуется токен обмена"}, status=401)
    items = _onec_items(request, "prices")
    if items is None:
        return Response({"detail": "Ожидается массив позиций или {\"prices\": [...]}"}, status=400)
    from .onec import import_prices
    return Response(import_prices(items))


@api_view(["GET"])
@permission_classes([AllowAny])
def onec_status(request):
    """Проверка «приём работает» — её опрашивает сторона 1С."""
    return Response({
        "status": "ok",
        "service": "MATA 1C exchange",
        "enabled": bool((settings.INTEGRATION_1C_TOKEN or "").strip()),
        "time": timezone.now().isoformat(),
    })
