from django.urls import path

from . import views

urlpatterns = [
    path("coros/callback", views.coros_callback),
    path("coros/push", views.coros_push),
    path("coros/status", views.coros_status),
]
