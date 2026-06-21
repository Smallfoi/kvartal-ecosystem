"""Документы и согласия (ECOSYSTEM: единые для всех продуктов).
- GET  /v1/legal/documents       — текущие опубликованные документы (с пометкой принятых, если есть Bearer);
- POST /v1/legal/consent         — принять согласия {accept:[типы], source} или {type};
- GET  /v1/legal/consents        — мои согласия (аудит), Bearer;
- POST /v1/legal/consent/revoke  — отозвать согласие {type}, Bearer (для необязательных)."""
from rest_framework.decorators import api_view
from rest_framework.response import Response
from django.utils import timezone

from common.security import user_id_from_request

from .models import LegalDocument, UserConsent, record_consent


@api_view(["GET"])
def documents(request):
    """Текущие опубликованные документы. Доступно без токена (нужно на регистрации);
    при наличии Bearer добавляем поле accepted по каждому документу."""
    uid = user_id_from_request(request)
    current = LegalDocument.current()
    accepted_doc_ids = set()
    if uid:
        accepted_doc_ids = set(
            UserConsent.objects.filter(
                user_id=uid, revoked_at__isnull=True
            ).values_list("document_id", flat=True)
        )
    return Response(
        [
            d.to_json(accepted=(d.pk in accepted_doc_ids) if uid else None)
            for d in current
        ]
    )


@api_view(["POST"])
def accept(request):
    """Принять согласия. Body: {"accept": ["terms","pd_consent"], "source": "kvartal"}
    или {"type": "marketing"}. Принимаются ТЕКУЩИЕ опубликованные версии по типу."""
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    source = request.data.get("source", "")
    types = request.data.get("accept")
    if not types:
        single = request.data.get("type")
        types = [single] if single else []
    if not types:
        return Response({"detail": "Не указаны типы согласий"}, status=400)
    current = {d.doc_type: d for d in LegalDocument.current()}
    recorded, skipped = [], []
    for t in types:
        doc = current.get(t)
        if doc:
            record_consent(uid, doc, source)
            recorded.append(t)
        else:
            skipped.append(t)  # нет опубликованного документа такого типа
    return Response({"ok": True, "recorded": recorded, "skipped": skipped})


@api_view(["GET"])
def my_consents(request):
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    rows = UserConsent.objects.filter(user_id=uid).select_related("document")
    return Response([c.to_json() for c in rows])


@api_view(["POST"])
def revoke(request):
    """Отозвать активное согласие по типу (для необязательных, напр. marketing).
    Body: {"type": "marketing"}."""
    uid = user_id_from_request(request)
    if not uid:
        return Response({"detail": "Нет токена"}, status=401)
    t = request.data.get("type")
    if not t:
        return Response({"detail": "Не указан тип"}, status=400)
    n = UserConsent.objects.filter(
        user_id=uid, document__doc_type=t, revoked_at__isnull=True
    ).update(revoked_at=timezone.now())
    return Response({"ok": True, "revoked": n})
