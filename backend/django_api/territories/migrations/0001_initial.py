from django.db import migrations


class Migration(migrations.Migration):
    initial = True
    dependencies = []

    operations = [
        migrations.RunSQL(
            sql=[
                "CREATE EXTENSION IF NOT EXISTS postgis;",
                """
                CREATE TABLE IF NOT EXISTS territories (
                    id TEXT PRIMARY KEY,
                    owner_id TEXT NOT NULL UNIQUE,
                    club_id TEXT,
                    geom geometry(MultiPolygon, 4326) NOT NULL,
                    captured_at timestamptz DEFAULT now()
                );
                """,
                "CREATE INDEX IF NOT EXISTS territories_geom_gix ON territories USING GIST (geom);",
            ],
            reverse_sql=["DROP TABLE IF EXISTS territories;"],
        ),
    ]
