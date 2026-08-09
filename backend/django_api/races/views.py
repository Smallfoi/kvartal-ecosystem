"""Races API — публичная афиша забегов для вкладки «Старты» (токен не нужен).

GET /v1/races?region=&city=&type=&month=YYYY-MM&when=upcoming|past
  Регион клиента: федеральные крупные старты видны всем; региональные/местные —
  только если совпал регион/город клиента (region/city из GPS или профиля Квартала).
GET /v1/races/<id> — детали одного забега.
"""
from django.db.models import Q
from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.http import require_http_methods

from .models import Race


@require_http_methods(["GET"])
def races(request):
    qs = Race.objects.filter(is_published=True)

    region = (request.GET.get("region") or "").strip()
    city = (request.GET.get("city") or "").strip()
    # Регион клиента: федеральные — всем; региональные/местные — по совпадению.
    if region or city:
        cond = Q(scope=Race.SCOPE_FEDERAL)
        if region:
            cond |= Q(region__iexact=region)
        if city:
            cond |= Q(city__iexact=city)
        qs = qs.filter(cond)

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

    items = [r.to_json() for r in qs[:300]]
    cities = list(
        Race.objects.filter(is_published=True)
        .exclude(city="")
        .values_list("city", flat=True)
        .distinct()
        .order_by("city")
    )
    return JsonResponse({"races": items, "cities": cities})


@require_http_methods(["GET"])
def race_detail(request, race_id):
    try:
        r = Race.objects.get(pk=int(race_id), is_published=True)
    except (Race.DoesNotExist, ValueError, TypeError):
        return JsonResponse({"detail": "Забег не найден"}, status=404)
    return JsonResponse(r.to_json())
