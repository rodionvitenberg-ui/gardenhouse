# backend/shop/models.py
from django.db import models
from django.core.validators import MinValueValidator


class Category(models.Model):
    title = models.CharField(max_length=255, verbose_name="Название")
    slug = models.SlugField(max_length=255, unique=True, verbose_name="URL-слаг")
    description = models.TextField(blank=True, verbose_name="Описание")
    image = models.ImageField(upload_to="categories/", blank=True, verbose_name="Изображение")

    class Meta:
        verbose_name = "Категория"
        verbose_name_plural = "Категории"

    def __str__(self):
        return self.title


class Product(models.Model):
    class Availability(models.TextChoices):
        AVAILABLE = "AVAILABLE", "В наличии"
        PREORDER = "PREORDER", "Предзаказ (ожидается сезон)"
        OUT_OF_STOCK = "OUT_OF_STOCK", "Закончилось"

    category = models.ForeignKey(
        Category,
        on_delete=models.PROTECT,
        related_name="products",
        verbose_name="Категория",
    )
    title = models.CharField(max_length=255, verbose_name="Название сорта/товара")
    slug = models.SlugField(max_length=255, unique=True, verbose_name="URL-слаг")
    description = models.TextField(blank=True, verbose_name="Описание")
    price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0.0)],
        verbose_name="Цена",
    )
    stock = models.PositiveIntegerField(default=0, verbose_name="Остаток на складе")
    status = models.CharField(
        max_length=20,
        choices=Availability.choices,
        default=Availability.AVAILABLE,
        verbose_name="Статус доступности",
    )
    image = models.ImageField(upload_to="products/", blank=True, verbose_name="Изображение")
    is_active = models.BooleanField(default=True, verbose_name="Активен на сайте")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Дата добавления")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Дата обновления")

    class Meta:
        verbose_name = "Товар"
        verbose_name_plural = "Товары"
        indexes = [
            models.Index(fields=["status", "is_active"]),
        ]

    def __str__(self):
        return self.title


class Order(models.Model):
    class OrderStatus(models.TextChoices):
        NEW = "NEW", "Новый заказ"
        PROCESSING = "PROCESSING", "В обработке"
        SHIPPED = "SHIPPED", "Отправлен"
        CANCELLED = "CANCELLED", "Отменён"

    guest_name = models.CharField(max_length=255, verbose_name="Имя заказчика")
    guest_phone = models.CharField(max_length=50, verbose_name="Телефон")
    guest_email = models.EmailField(blank=True, verbose_name="Email")
    comment = models.TextField(blank=True, verbose_name="Комментарий к заказу")
    status = models.CharField(
        max_length=20,
        choices=OrderStatus.choices,
        default=OrderStatus.NEW,
        verbose_name="Статус заказа",
    )
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Дата создания")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Дата обновления")

    class Meta:
        verbose_name = "Заказ"
        verbose_name_plural = "Заказы"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["status"]),
        ]

    def __str__(self):
        return f"Заказ #{self.id} от {self.guest_name}"


class OrderItem(models.Model):
    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name="items",
        verbose_name="Заказ",
    )
    product = models.ForeignKey(
        Product,
        on_delete=models.PROTECT,
        related_name="order_items",
        verbose_name="Товар",
    )
    quantity = models.PositiveIntegerField(default=1, verbose_name="Количество")
    unit_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        verbose_name="Цена за единицу на момент заказа",
    )

    class Meta:
        verbose_name = "Позиция заказа"
        verbose_name_plural = "Позиции заказов"

    def __str__(self):
        return f"{self.product.title} × {self.quantity}"