from django.contrib import admin
from django.urls import include, path

from accounts import views as account_views

urlpatterns = [
    path("admin/", admin.site.urls),
    path("v1/", include("core.urls")),
    path("v1/auth/", include("accounts.urls")),
    path("v1/profile", account_views.update_profile),
    path("v1/loyalty/", include("loyalty.urls")),
]
