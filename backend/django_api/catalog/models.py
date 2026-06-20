"""Каталог Store на бэке (D-13): категории, товары, баннеры.
Контракт JSON совпадает с моделями SportStore (Category/Product), чтобы клиент
только переключил флаг useApiCatalog без правок парсинга."""
from django.db import models


class Category(models.Model):
    id = models.CharField(primary_key=True, max_length=40)
    name = models.CharField(max_length=120)
    emoji = models.CharField(max_length=16, blank=True, default="")
    image_url = models.CharField(max_length=300, null=True, blank=True)
    sort = models.IntegerField(default=0)

    class Meta:
        db_table = "catalog_categories"
        ordering = ["sort"]

    def to_json(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "emoji": self.emoji,
            "imageUrl": self.image_url,
        }


class Product(models.Model):
    id = models.CharField(primary_key=True, max_length=40)
    name = models.CharField(max_length=200)
    brand = models.CharField(max_length=120, blank=True, default="")
    category_id = models.CharField(max_length=40, db_index=True)
    price = models.FloatField()
    old_price = models.FloatField(null=True, blank=True)
    image_urls = models.JSONField(default=list)
    # Загруженное в админке фото (приоритетнее image_urls). Отдаётся по сети как
    # /media/uploads/products/... — видно в каталоге и трекере кроссовок Квартала.
    image = models.ImageField(upload_to="uploads/products/", null=True, blank=True)
    description = models.TextField(blank=True, default="")
    sizes = models.JSONField(default=list)
    colors = models.JSONField(default=list)
    is_new = models.BooleanField(default=False)
    is_featured = models.BooleanField(default=False)
    rating = models.FloatField(default=0)
    review_count = models.IntegerField(default=0)
    in_stock = models.BooleanField(default=True)
    # Draft→Publish: на витрине (сайт/приложение) видны только опубликованные;
    # черновик виден в админ-превью (?preview=1). Существующие → опубликованы.
    is_published = models.BooleanField(default=True, db_index=True)
    sort = models.IntegerField(default=0)

    class Meta:
        db_table = "catalog_products"
        ordering = ["sort"]

    def network_image_url(self) -> str:
        """Сетевой URL фото товара (для Квартала/сайта). Приоритет — загруженное
        в админке фото; иначе первый из старых бандл-ассетов как /media/products/…"""
        if self.image:
            return self.image.url
        imgs = self.image_urls or []
        if imgs:
            return f"/media/products/{str(imgs[0]).split('/')[-1]}"
        return ""

    def to_json(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "brand": self.brand,
            "categoryId": self.category_id,
            "price": self.price,
            "oldPrice": self.old_price,
            "imageUrls": self.image_urls or [],
            "imageUrl": self.network_image_url(),
            "description": self.description,
            "sizes": self.sizes or [],
            "colors": self.colors or [],
            "isNew": self.is_new,
            "isFeatured": self.is_featured,
            "rating": self.rating,
            "reviewCount": self.review_count,
            "inStock": self.in_stock,
        }


class Banner(models.Model):
    id = models.AutoField(primary_key=True)
    title = models.CharField(max_length=200)
    subtitle = models.CharField(max_length=200, blank=True, default="")
    image_url = models.CharField(max_length=300, blank=True, default="")
    action = models.CharField(max_length=80, blank=True, default="")
    is_published = models.BooleanField(default=True, db_index=True)
    sort = models.IntegerField(default=0)

    class Meta:
        db_table = "catalog_banners"
        ordering = ["sort"]

    def to_json(self) -> dict:
        return {
            "title": self.title,
            "subtitle": self.subtitle,
            "imageUrl": self.image_url,
            "action": self.action,
        }
