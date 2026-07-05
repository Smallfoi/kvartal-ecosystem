"""Каталог Store на бэке (D-13): категории, товары, баннеры.
Контракт JSON совпадает с моделями SportStore (Category/Product), чтобы клиент
только переключил флаг useApiCatalog без правок парсинга."""
from django.db import models
from django.utils import timezone


class Category(models.Model):
    id = models.CharField(primary_key=True, max_length=40, verbose_name="ID")
    name = models.CharField(max_length=120, verbose_name="Название")
    emoji = models.CharField(max_length=16, blank=True, default="", verbose_name="Эмодзи")
    image_url = models.CharField(max_length=300, null=True, blank=True, verbose_name="Ссылка на фото")
    # Загруженное в админке фото категории (приоритетнее image_url).
    image = models.ImageField(upload_to="uploads/categories/", null=True, blank=True, verbose_name="Фото")
    sort = models.IntegerField(default=0, verbose_name="Порядок")

    class Meta:
        db_table = "catalog_categories"
        ordering = ["sort"]
        verbose_name = "Категория"
        verbose_name_plural = "Категории"

    def __str__(self) -> str:
        return self.name

    def network_image_url(self) -> str:
        """Сетевой URL фото: приоритет — загруженное в админке, иначе ссылка."""
        if self.image:
            return self.image.url
        return self.image_url or ""

    def to_json(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "emoji": self.emoji,
            "imageUrl": self.network_image_url(),
        }


class Product(models.Model):
    id = models.CharField(primary_key=True, max_length=40, verbose_name="ID")
    name = models.CharField(max_length=200, verbose_name="Название")
    brand = models.CharField(max_length=120, blank=True, default="", verbose_name="Бренд")
    category_id = models.CharField(max_length=40, db_index=True, verbose_name="Категория")
    price = models.FloatField(verbose_name="Цена")
    old_price = models.FloatField(null=True, blank=True, verbose_name="Старая цена")
    image_urls = models.JSONField(default=list, verbose_name="Старые фото (бандл)")
    # Загруженное в админке фото (приоритетнее image_urls). Отдаётся по сети как
    # /media/uploads/products/... — видно в каталоге и трекере кроссовок Квартала.
    image = models.ImageField(upload_to="uploads/products/", null=True, blank=True, verbose_name="Фото")
    description = models.TextField(blank=True, default="", verbose_name="Описание")
    sizes = models.JSONField(default=list, verbose_name="Размеры")
    colors = models.JSONField(default=list, verbose_name="Цвета")
    is_new = models.BooleanField(default=False, verbose_name="Новинка")
    is_featured = models.BooleanField(default=False, verbose_name="Рекомендуемый")
    rating = models.FloatField(default=0, verbose_name="Рейтинг")
    review_count = models.IntegerField(default=0, verbose_name="Кол-во отзывов")
    in_stock = models.BooleanField(default=True, verbose_name="В наличии")
    # Draft→Publish: на витрине (сайт/приложение) видны только опубликованные;
    # черновик виден в админ-превью (?preview=1). Существующие → опубликованы.
    is_published = models.BooleanField(default=True, db_index=True, verbose_name="Опубликован")
    sort = models.IntegerField(default=0, verbose_name="Порядок")
    # Раздельный порядок витрины по площадкам (мерчендайзинг per-channel): данные
    # товара общие, а раскладка раздельная. API отдаёт порядок по ?platform=site|app
    # (sort_site / sort_app); без параметра — по общему sort (обратная совместимость).
    sort_site = models.IntegerField(default=0, verbose_name="Порядок (сайт)")
    sort_app = models.IntegerField(default=0, verbose_name="Порядок (приложение)")

    class Meta:
        db_table = "catalog_products"
        ordering = ["sort"]
        verbose_name = "Товар"
        verbose_name_plural = "Товары"

    def __str__(self) -> str:
        return self.name

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
    id = models.AutoField(primary_key=True, verbose_name="ID")
    title = models.CharField(max_length=200, verbose_name="Заголовок")
    subtitle = models.CharField(max_length=200, blank=True, default="", verbose_name="Подзаголовок")
    image_url = models.CharField(max_length=300, blank=True, default="", verbose_name="Ссылка на фото")
    # Загруженный в админке баннер (приоритетнее image_url) → /media/uploads/banners/…
    image = models.ImageField(upload_to="uploads/banners/", null=True, blank=True, verbose_name="Фото")
    action = models.CharField(max_length=80, blank=True, default="", verbose_name="Действие")
    is_published = models.BooleanField(default=True, db_index=True, verbose_name="Опубликован")
    # Подгон фото баннера: cover — заполнить (обрезка); contain — фото целиком (не режется).
    image_fit = models.CharField(max_length=10, default="cover", verbose_name="Подгон фото")
    # Фокус-область (background-position), напр. "50% 30%".
    image_focal = models.CharField(max_length=16, default="50% 50%", verbose_name="Фокус фото")
    sort = models.IntegerField(default=0, verbose_name="Порядок")
    # Раздельный порядок промо по площадкам (мерчендайзинг per-channel), как у товаров.
    sort_site = models.IntegerField(default=0, verbose_name="Порядок (сайт)")
    sort_app = models.IntegerField(default=0, verbose_name="Порядок (приложение)")

    class Meta:
        db_table = "catalog_banners"
        ordering = ["sort"]
        verbose_name = "Баннер"
        verbose_name_plural = "Баннеры"

    def __str__(self) -> str:
        return self.title

    def network_image_url(self) -> str:
        """Сетевой URL баннера: приоритет — загруженное в админке, иначе ссылка."""
        if self.image:
            return self.image.url
        return self.image_url or ""

    def to_json(self) -> dict:
        return {
            "id": self.id,
            "title": self.title,
            "subtitle": self.subtitle,
            "imageUrl": self.network_image_url(),
            "action": self.action,
            "imageFit": self.image_fit or "cover",
            "imageFocal": self.image_focal or "50% 50%",
        }


class Review(models.Model):
    """Отзыв на товар. Один отзыв на пользователя+товар (можно отредактировать).
    Рейтинг/кол-во в Product пересчитываются из отзывов."""

    id = models.CharField(primary_key=True, max_length=40, verbose_name="ID")
    product_id = models.CharField(max_length=40, db_index=True, verbose_name="Товар (ID)")
    user_id = models.CharField(max_length=40, db_index=True, verbose_name="Пользователь (ID)")
    rating = models.IntegerField(verbose_name="Оценка (1–5)")
    text = models.TextField(blank=True, default="", verbose_name="Текст")
    photos = models.JSONField(default=list, blank=True, verbose_name="Фото (URL)")
    hidden = models.BooleanField(default=False, verbose_name="Скрыт (модерация)")
    created_at = models.DateTimeField(default=timezone.now, verbose_name="Создан")

    class Meta:
        db_table = "catalog_reviews"
        unique_together = (("product_id", "user_id"),)
        ordering = ["-created_at"]
        verbose_name = "Отзыв"
        verbose_name_plural = "Отзывы"


class SiteContent(models.Model):
    """Редактируемый контент сайта (мини-CMS для «Конструктора»): тексты и фото
    шапки/hero/секций. Ключ → текст/фото. Сайт читает через GET /v1/site/content и
    подставляет в элементы с data-edit / data-edit-img; правится кликом в конструкторе."""

    key = models.CharField(primary_key=True, max_length=80, verbose_name="Ключ")
    value = models.TextField(blank=True, default="", verbose_name="Текст")
    image = models.ImageField(upload_to="uploads/site/", null=True, blank=True, verbose_name="Фото")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Обновлено")

    class Meta:
        db_table = "site_content"
        verbose_name = "Контент сайта"
        verbose_name_plural = "Контент сайта"

    def __str__(self) -> str:
        return self.key

    def image_url(self) -> str:
        return self.image.url if self.image else ""

    def to_json(self) -> dict:
        return {"value": self.value, "imageUrl": self.image_url()}
