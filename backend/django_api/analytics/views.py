"""Приём клиентских событий аналитики (D-30). POST /v1/events — батч или одиночное.
Требует токен: событие привязывается к uid. Клиент НЕ может выдать себя за `server`."""
from rest_framework.decorators import api_view
from rest_framework.response import Response

from common.security import user_id_from_request

from .models import Event

_MAX_BATCH = 100  # защита от раздувания одного запроса


@api_view(["POST"])
def events(request):
    """body: {"events": [{"name","source","props"}, ...]} или одиночное {"name",...}."""
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    d = request.data
    items = (
        d.get("events")
        if isinstance(d, dict) and isinstance(d.get("events"), list)
        else [d]
    )
    objs = []
    for it in items[:_MAX_BATCH]:
        if not isinstance(it, dict):
            continue
        name = (str(it.get("name") or "")).strip()[:60]
        if not name:
            continue
        source = (str(it.get("source") or "app")).strip()[:20]
        if source == "server":
            source = "client"  # источник server — только для внутреннего track()
        props = it.get("props")
        if not isinstance(props, dict):
            props = {}
        objs.append(Event(user_id=uid, name=name, source=source, props=props))
    if objs:
        Event.objects.bulk_create(objs)
    return Response({"accepted": len(objs)})
