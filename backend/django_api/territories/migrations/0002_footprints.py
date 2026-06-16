from django.db import migrations


class Migration(migrations.Migration):
    """Вечный личный след (footprints): объединение всего, что юзер пробежал."""

    dependencies = [
        ("territories", "0001_initial"),
    ]

    operations = [
        migrations.RunSQL(
            sql=(
                "CREATE TABLE IF NOT EXISTS footprints ("
                "  owner_id TEXT PRIMARY KEY,"
                "  geom geometry(MultiPolygon, 4326),"
                "  updated_at timestamptz DEFAULT now()"
                ");"
                "CREATE INDEX IF NOT EXISTS footprints_gix ON footprints USING GIST (geom);"
            ),
            reverse_sql="DROP TABLE IF EXISTS footprints;",
        ),
    ]
