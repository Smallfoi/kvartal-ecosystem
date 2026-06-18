"""
Django-настройки бэкенда экосистемы STAW (этап перехода с FastAPI).
Конфиг через переменные окружения (см. docker-compose.yml / .env.example).
БД — PostgreSQL (+ PostGIS включим для модуля территорий, D-09).
"""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "dev-secret-change-in-prod")
DEBUG = os.environ.get("DJANGO_DEBUG", "1") == "1"

# Прод: DJANGO_ALLOWED_HOSTS="api.staw.ru,staw.ru". Dev (по умолчанию) — "*".
ALLOWED_HOSTS = [
    h.strip() for h in os.environ.get("DJANGO_ALLOWED_HOSTS", "*").split(",") if h.strip()
]

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "corsheaders",
    "core",
    "accounts",
    "loyalty",
    "clubs",
    "leaderboard",
    "territories",
    "catalog",
    "orders",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.environ.get("POSTGRES_DB", "kvartal"),
        "USER": os.environ.get("POSTGRES_USER", "kvartal"),
        "PASSWORD": os.environ.get("POSTGRES_PASSWORD", "kvartal"),
        "HOST": os.environ.get("POSTGRES_HOST", "localhost"),
        "PORT": os.environ.get("POSTGRES_PORT", "5432"),
    }
}

# CORS. Прод: DJANGO_CORS_ORIGINS="https://staw.ru,https://www.staw.ru" — тогда
# разрешаем только их. Dev (переменная пуста) — разрешаем всё (приложения и сайт
# ходят с устройства/localhost).
_cors_origins = [
    o.strip() for o in os.environ.get("DJANGO_CORS_ORIGINS", "").split(",") if o.strip()
]
if _cors_origins:
    CORS_ALLOW_ALL_ORIGINS = False
    CORS_ALLOWED_ORIGINS = _cors_origins
    # CSRF для Django-admin за HTTPS (нужны со схемой).
    CSRF_TRUSTED_ORIGINS = _cors_origins
else:
    CORS_ALLOW_ALL_ORIGINS = True

# За HTTPS-прокси (nginx/traefik): доверяем заголовку схемы. Безопасно и в dev.
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")

REST_FRAMEWORK = {
    "DEFAULT_RENDERER_CLASSES": ["rest_framework.renderers.JSONRenderer"],
    # Аутентификация — свой JWT (common.security), session-auth/CSRF DRF не используем.
    "DEFAULT_AUTHENTICATION_CLASSES": [],
}

LANGUAGE_CODE = "ru-ru"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
