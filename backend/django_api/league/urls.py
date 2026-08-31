from django.urls import path

from . import views

urlpatterns = [
    path("boards", views.boards),
    path("division", views.division),
    path("season/latest", views.season_latest),
]
