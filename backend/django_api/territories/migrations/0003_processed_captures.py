from django.db import migrations


class Migration(migrations.Migration):
    """Идемпотентность захвата (S-04): дедуп повторных отправок одной пробежки
    (ретраи из офлайн-очереди клиента не должны задвоить территорию)."""

    dependencies = [
        ("territories", "0002_footprints"),
    ]

    operations = [
        migrations.RunSQL(
            sql=(
                "CREATE TABLE IF NOT EXISTS processed_captures ("
                "  capture_id varchar(64) PRIMARY KEY,"
                "  owner_id varchar(40) NOT NULL,"
                "  area_m2 double precision,"
                "  created_at timestamptz NOT NULL DEFAULT now()"
                ");"
            ),
            reverse_sql="DROP TABLE IF EXISTS processed_captures;",
        ),
    ]
