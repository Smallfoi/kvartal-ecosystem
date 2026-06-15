from datetime import datetime, timezone

from django.db import connection
from rest_framework.decorators import api_view
from rest_framework.response import Response


@api_view(["GET"])
def health(_request):
    """Тот же контракт, что у FastAPI /v1/health (для совместимости при переходе)."""
    db_ok = True
    try:
        with connection.cursor() as cur:
            cur.execute("SELECT 1")
            cur.fetchone()
    except Exception:
        db_ok = False
    return Response(
        {
            "status": "ok" if db_ok else "degraded",
            "service": "staw-ecosystem-django",
            "db": db_ok,
            "time": datetime.now(timezone.utc).isoformat(),
        }
    )
