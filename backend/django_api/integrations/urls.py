from django.urls import path

from . import views

urlpatterns = [
    path("coros/callback", views.coros_callback),
    path("coros/push", views.coros_push),
    path("coros/status", views.coros_status),
    path("1c/catalog", views.onec_catalog),
    path("1c/prices", views.onec_prices),
    path("1c/status", views.onec_status),
]
