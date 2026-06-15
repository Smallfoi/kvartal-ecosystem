# Территории хранятся в PostGIS-таблице `territories` (geometry MultiPolygon).
# Работаем с ней через raw SQL (ST_Union/ST_Difference/...), без GeoDjango/GDAL.
# Схема создаётся миграцией 0001_initial (RunSQL).
