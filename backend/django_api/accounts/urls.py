from django.urls import path

from . import views

urlpatterns = [
    path("register", views.register),
    path("login", views.login),
    path("phone/verify", views.phone_verify),
    path("me", views.me),
]
