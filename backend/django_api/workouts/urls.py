from django.urls import path

from . import views

urlpatterns = [
    path("", views.workouts),
    path("import", views.import_workouts),
    path("source/<str:source>", views.disconnect),
]
