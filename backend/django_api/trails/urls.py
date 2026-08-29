from django.urls import path

from . import views

urlpatterns = [
    path("", views.trails),
    path("<str:trail_id>/boards", views.boards),
]
