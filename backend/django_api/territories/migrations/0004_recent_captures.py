from django.db import migrations


class Migration(migrations.Migration):
    """Защита свежего захвата 24ч, Вариант Б (D-14): храним отдельные захваченные
    куски с временем. «Защищённое» игрока = объединение его кусков моложе окна.
    При перехвате срезается только незащищённая часть."""

    dependencies = [
        ("territories", "0003_processed_captures"),
    ]

    operations = [
        migrations.RunSQL(
            sql=(
                "CREATE TABLE IF NOT EXISTS recent_captures ("
                "  id bigserial PRIMARY KEY,"
                "  owner_id varchar(40) NOT NULL,"
                "  geom geometry(MultiPolygon, 4326),"
                "  captured_at timestamptz NOT NULL DEFAULT now()"
                ");"
                "CREATE INDEX IF NOT EXISTS recent_captures_gix ON recent_captures USING GIST (geom);"
                "CREATE INDEX IF NOT EXISTS recent_captures_owner_time "
                "  ON recent_captures (owner_id, captured_at);"
            ),
            reverse_sql="DROP TABLE IF EXISTS recent_captures;",
        ),
    ]
