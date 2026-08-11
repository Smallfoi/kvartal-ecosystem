"""Races API — публичная афиша забегов для вкладки «Старты» (токен не нужен).

GET /v1/races?region=&city=&lat=&lng=&type=&month=YYYY-MM&when=upcoming|past
  СТРОГО по региону клиента: показываем только те забеги, что проходят в регионе,
  где находится клиент (Якутск → только Республика Саха; Москва → Москва и область).
  Регион берём из region/city (профиль Квартала) или GPS lat/lng. Если регион не
  передан — отдаём всё (веб/тесты).
GET /v1/races/<id> — детали одного забега.
"""
from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.http import require_http_methods

from .models import Race
from .regions import canonical_region, region_display, resolve_client_region


@require_http_methods(["GET"])
def races(request):
    qs = Race.objects.filter(is_published=True)

    rtype = (request.GET.get("type") or "").strip()
    if rtype:
        qs = qs.filter(type=rtype)

    month = (request.GET.get("month") or "").strip()
    if month:
        try:
            y, m = month.split("-")
            qs = qs.filter(date__year=int(y), date__month=int(m))
        except (ValueError, AttributeError):
            pass

    when = (request.GET.get("when") or "").strip()
    today = timezone.localdate()
    if when == "upcoming":
        qs = qs.filter(date__gte=today).order_by("date", "id")
    elif when == "past":
        qs = qs.filter(date__lt=today).order_by("-date", "id")
    else:
        qs = qs.order_by("date", "id")

    # Регион клиента: строгий фильтр по совпадению канонического региона.
    region = (request.GET.get("region") or "").strip()
    city = (request.GET.get("city") or "").strip()
    client_slug = resolve_client_region(
        region=region, city=city,
        lat=request.GET.get("lat"), lng=request.GET.get("lng"),
    )

    races_qs = list(qs[:500])
    if client_slug:
        races_qs = [
            r for r in races_qs
            if canonical_region(r.region or r.city) == client_slug
        ]

    items = [r.to_json() for r in races_qs[:300]]
    cities = list(
        Race.objects.filter(is_published=True)
        .exclude(city="")
        .values_list("city", flat=True)
        .distinct()
        .order_by("city")
    )
    return JsonResponse({
        "races": items,
        "cities": cities,
        # Разрешённый регион клиента (для подписи «Ваш регион: …» в приложении).
        "region": region_display(client_slug, fallback=region or city),
    })


@require_http_methods(["GET"])
def race_detail(request, race_id):
    try:
        r = Race.objects.get(pk=int(race_id), is_published=True)
    except (Race.DoesNotExist, ValueError, TypeError):
        return JsonResponse({"detail": "Забег не найден"}, status=404)
    return JsonResponse(r.to_json())
