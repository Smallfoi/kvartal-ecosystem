"""Races API — публичная афиша забегов для вкладки «Старты» (токен не нужен).

GET /v1/races?region=&city=&lat=&lng=&all=&scope=&type=&month=YYYY-MM&when=upcoming|past
  Режимы показа (переключатель региона в приложении):
  - по умолчанию (region/city/lat/lng) — СТРОГО регион клиента (Якутск → только Саха,
    Москва → Москва и область). `region` может быть слагом (moscow) или названием.
  - all=1        — «Вся Россия»: без фильтра по региону.
  - scope=federal — «Крупные марафоны»: только федеральные крупные старты (для поездок).
  Ответ: {races, cities, region} — где region это подпись выбранного режима для шапки.
GET /v1/races/regions — список регионов, где есть забеги (для пикера) + счётчики.
GET /v1/races/<id> — детали одного забега.
"""
from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.http import require_http_methods

from .models import Race
from .regions import canonical_region, region_display, resolve_client_region

_TRUE = {"1", "true", "yes", "on"}


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

    scope = (request.GET.get("scope") or "").strip()
    show_all = (request.GET.get("all") or "").strip().lower() in _TRUE
    region = (request.GET.get("region") or "").strip()
    city = (request.GET.get("city") or "").strip()

    races_list = list(qs[:500])
    label = ""
    if scope == Race.SCOPE_FEDERAL:
        # «Крупные марафоны» — федеральные крупные старты со всей страны.
        races_list = [r for r in races_list if r.scope == Race.SCOPE_FEDERAL]
        label = "Крупные марафоны"
    elif show_all:
        # «Вся Россия» — без фильтра по региону.
        label = "Вся Россия"
    else:
        # Строго по региону клиента / выбранному региону.
        client_slug = resolve_client_region(
            region=region, city=city,
            lat=request.GET.get("lat"), lng=request.GET.get("lng"),
        )
        if client_slug:
            races_list = [
                r for r in races_list
                if canonical_region(r.region or r.city) == client_slug
            ]
            label = region_display(client_slug, fallback=region or city)

    items = [r.to_json() for r in races_list[:300]]
    cities = list(
        Race.objects.filter(is_published=True)
        .exclude(city="")
        .values_list("city", flat=True)
        .distinct()
        .order_by("city")
    )
    return JsonResponse({"races": items, "cities": cities, "region": label})


@require_http_methods(["GET"])
def race_regions(request):
    """Список регионов с забегами (для пикера «показать другой регион»)."""
    by_slug = {}  # slug -> {"name": ..., "count": int}
    for r in Race.objects.filter(is_published=True).only("region", "city"):
        slug = canonical_region(r.region or r.city)
        if not slug:
            continue
        entry = by_slug.setdefault(slug, {"name": "", "count": 0})
        entry["count"] += 1
        if not entry["name"]:
            # Красивое имя из справочника; иначе — исходный текст региона забега.
            entry["name"] = region_display(slug, fallback=(r.region or r.city).strip())

    regions = [
        {"slug": slug, "name": v["name"], "count": v["count"]}
        for slug, v in by_slug.items()
    ]
    regions.sort(key=lambda x: (-x["count"], x["name"]))
    majors = Race.objects.filter(is_published=True, scope=Race.SCOPE_FEDERAL).count()
    return JsonResponse({"regions": regions, "majorsCount": majors})


@require_http_methods(["GET"])
def race_detail(request, race_id):
    try:
        r = Race.objects.get(pk=int(race_id), is_published=True)
    except (Race.DoesNotExist, ValueError, TypeError):
        return JsonResponse({"detail": "Забег не найден"}, status=404)
    return JsonResponse(r.to_json())
