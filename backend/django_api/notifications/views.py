"""Уведомления: GET /v1/notifications — лента пользователя; POST /v1/notifications/read —
отметить прочитанными ({ids:[]} или всё). Требуется Bearer-токен."""
from rest_framework.decorators import api_view
from rest_framework.response import Response

from common.security import user_id_from_request

from .models import Notification


@api_view(["GET"])
def notifications(request):
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    rows = Notification.objects.filter(user_id=uid)[:100]
    return Response([n.to_json() for n in rows])


@api_view(["POST"])
def notifications_read(request):
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    qs = Notification.objects.filter(user_id=uid, read=False)
    ids = request.data.get("ids")
    if ids:
        pks = [int(x) for x in ids if str(x).isdigit()]
        qs = qs.filter(pk__in=pks)
    marked = qs.update(read=True)
    return Response({"ok": True, "marked": marked})
