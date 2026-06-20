"""Данные для главной админки (KPI + график). Подключается через
UNFOLD['DASHBOARD_CALLBACK'] и используется в templates/admin/index.html."""
from datetime import timedelta

from django.db.models import Sum
from django.utils import timezone


def dashboard_callback(request, context):
    from accounts.models import Account
    from catalog.models import Product
    from clubs.models import Club
    from loyalty.models import LoyaltyTransaction
    from orders.models import Order
    from shoes.models import ShoeAsset

    now = timezone.now()
    today = now.date()
    week_ago = now - timedelta(days=7)

    def _sum(qs, field="amount"):
        return qs.aggregate(s=Sum(field))["s"] or 0

    orders_total = Order.objects.count()
    orders_today = Order.objects.filter(created_at__date=today).count()
    revenue = _sum(Order.objects.all(), "total")
    revenue_week = _sum(Order.objects.filter(created_at__gte=week_ago), "total")
    users = Account.objects.count()
    products = Product.objects.count()
    clubs = Club.objects.count()
    shoes_active = ShoeAsset.objects.filter(status="active").count()
    points_earned = _sum(LoyaltyTransaction.objects.filter(amount__gt=0))
    points_spent = -_sum(LoyaltyTransaction.objects.filter(amount__lt=0))

    # Заказы по дням за последнюю неделю — для столбчатого графика.
    daily = []
    for i in range(6, -1, -1):
        d = (now - timedelta(days=i)).date()
        daily.append({"label": d.strftime("%d.%m"),
                      "value": Order.objects.filter(created_at__date=d).count()})
    peak = max([x["value"] for x in daily] + [1])
    for x in daily:
        x["pct"] = round(x["value"] / peak * 100)

    context.update({
        "kpis": [
            {"title": "Заказов всего", "value": orders_total,
             "sub": f"+{orders_today} сегодня", "icon": "shopping_cart"},
            {"title": "Выручка, ₽", "value": int(revenue),
             "sub": f"+{int(revenue_week)} за неделю", "icon": "payments"},
            {"title": "Пользователей", "value": users,
             "sub": f"{products} товаров в каталоге", "icon": "group"},
            {"title": "Баллы экосистемы", "value": points_earned,
             "sub": f"−{points_spent} потрачено", "icon": "loyalty"},
        ],
        "extra_stats": [
            {"title": "Клубы", "value": clubs, "icon": "groups"},
            {"title": "Кроссовки в трекере", "value": shoes_active,
             "icon": "directions_run"},
            {"title": "Товаров", "value": products, "icon": "inventory_2"},
        ],
        "orders_daily": daily,
    })
    return context
