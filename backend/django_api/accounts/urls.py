from django.urls import path

from . import views

urlpatterns = [
    path("register", views.register),
    path("login", views.login),
    path("phone/request", views.phone_request),
    path("phone/verify", views.phone_verify),
    # Тип канала: нужно ли вводить код или ждать подтверждения на телефоне.
    path("phone/channel", views.phone_channel),
    path("password/reset", views.password_reset),
    path("me", views.me),
]
