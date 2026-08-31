"""События территорий (Квартал 2.0, Ф6): «кто у кого отрезал землю».

Лента угроз клуба и уведомления обороны строятся из этих событий; сами
полигоны об истории ничего не помнят (ST_Difference молчалив).
"""
from django.db import migrations

SQL = """
CREATE TABLE IF NOT EXISTS territory_events (
    id bigserial PRIMARY KEY,
    victim_owner varchar(40) NOT NULL,
    attacker varchar(40) NOT NULL,
    area_m2 double precision NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS territory_events_victim_idx
    ON territory_events (victim_owner, created_at);
CREATE INDEX IF NOT EXISTS territory_events_created_idx
    ON territory_events (created_at);
"""


class Migration(migrations.Migration):
    dependencies = [("territories", "0004_recent_captures")]
    operations = [
        migrations.RunSQL(SQL, reverse_sql="DROP TABLE IF EXISTS territory_events;")
    ]
