from django.contrib import admin
from django.urls import include, path

from accounts import views as account_views
from catalog import views as catalog_views
from clubs import views as clubs_views
from territories import views as territories_views

urlpatterns = [
    path("admin/", admin.site.urls),
    path("v1/", include("core.urls")),
    path("v1/auth/", include("accounts.urls")),
    path("v1/profile", account_views.update_profile),
    path("v1/loyalty/", include("loyalty.urls")),
    # Клубы — порядок важен: 'me' и 'requests/...' раньше generic '<club_id>'.
    path("v1/clubs", clubs_views.clubs_root),
    path("v1/clubs/me", clubs_views.my_club),
    path("v1/clubs/requests/<str:req_id>/approve", clubs_views.approve_request),
    path("v1/clubs/requests/<str:req_id>/reject", clubs_views.reject_request),
    path("v1/clubs/<str:club_id>", clubs_views.club_detail_or_update),
    path("v1/clubs/<str:club_id>/join", clubs_views.join_club),
    path("v1/clubs/<str:club_id>/leave", clubs_views.leave_club),
    path("v1/clubs/<str:club_id>/requests", clubs_views.club_requests),
    path("v1/leaderboard/", include("leaderboard.urls")),
    # Территории (PostGIS, D-09)
    path("v1/territories/capture", territories_views.capture),
    path("v1/territories", territories_views.list_territories),
    # Вечный личный след (для профиля «исследовано км²»)
    path("v1/footprint", territories_views.footprint),
    # Каталог Store (D-13) — контракт как у ApiProductRepository в SportStore.
    # Порядок важен: 'search' и 'price-range' раньше generic '<pid>'.
    path("v1/categories", catalog_views.categories),
    path("v1/products/search", catalog_views.product_search),
    path("v1/products/price-range", catalog_views.product_price_range),
    path("v1/products", catalog_views.products),
    path("v1/products/<str:pid>", catalog_views.product_detail),
    path("v1/brands", catalog_views.brands),
    path("v1/sizes", catalog_views.sizes),
    path("v1/banners", catalog_views.banners),
]
