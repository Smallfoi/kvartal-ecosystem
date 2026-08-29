"""Точки подключения часов COROS.

Заявка в COROS требует указать три адреса ещё до выдачи ключей: куда вернуть
пользователя после разрешения доступа, куда присылать готовые тренировки и как
проверить, что наш сервис жив. Эти адреса должны существовать на момент
рассмотрения — поэтому они здесь, пусть пока и в минимальном виде.

Разбор данных появится, когда COROS выдаст Client ID и Secret: до этого проверить
подпись запроса нечем, а принимать чужие данные без проверки нельзя.
"""
import json

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
