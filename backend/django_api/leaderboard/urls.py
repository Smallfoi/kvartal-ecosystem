from django.urls import path

from . import views

urlpatterns = [
    path("users", views.users),
    path("clubs", views.clubs),
]
