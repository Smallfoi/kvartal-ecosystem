from django.urls import path

from . import views

urlpatterns = [
    path("boards", views.boards),
]
