from django.urls import path

from . import views

urlpatterns = [
    path("register", views.register),
    path("login", views.login),
    path("phone/request", views.phone_request),
    path("phone/verify", views.phone_verify),
    path("me", views.me),
]
