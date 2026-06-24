FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# Системные либы под PostGIS/GeoDjango добавим, когда дойдём до территорий
# (gdal-bin libgdal-dev). Пока — обычный Django + DRF + psycopg.
COPY requirements.txt .
# Свежий pip — закрывает CVE самого установщика (pip-audit); затем зависимости.
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
