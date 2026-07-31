# backend/guests/models.py
from django.db import models


class House(models.Model):
    title = models.CharField(max_length=255, verbose_name="Название домика")
    slug = models.SlugField(max_length=255, unique=True, verbose_name="URL-слаг")
    description = models.TextField(verbose_name="Описание и удобства")
    max_guests = models.PositiveIntegerField(verbose_name="Макс. количество гостей")
    price_per_night = models.DecimalField(max_digits=10, decimal_places=2, verbose_name="Цена за сутки")
    is_available = models.BooleanField(default=True, verbose_name="Доступен для бронирования")

    class Meta:
        verbose_name = "Гостевой дом"
        verbose_name_plural = "Гостевые дома"

    def __str__(self):
        return self.title


class HouseImage(models.Model):
    house = models.ForeignKey(House, on_delete=models.CASCADE, related_name="images", verbose_name="Домик")
    image = models.ImageField(upload_to="houses/", verbose_name="Фотография")

    class Meta:
        verbose_name = "Фотография домика"
        verbose_name_plural = "Фотографии домиков"


class GalleryImage(models.Model):
    class CategoryChoices(models.TextChoices):
        GARDEN = "garden", "Garden"
        HOUSE = "house", "House"
        WORKSHOP = "workshop", "Workshop"
        GREENHOUSE = "greenhouse", "Greenhouse"

    image = models.ImageField(upload_to="gallery/", verbose_name="Изображение")
    caption = models.CharField(max_length=255, blank=True, verbose_name="Подпись")
    alt = models.CharField(max_length=255, blank=True, verbose_name="Alt-текст")
    category = models.CharField(
        max_length=50,
        choices=CategoryChoices.choices,
        default=CategoryChoices.GARDEN,
        verbose_name="Категория",
    )
    sort_order = models.PositiveIntegerField(default=0, verbose_name="Порядок сортировки")
    is_published = models.BooleanField(default=True, verbose_name="Опубликовано")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Создана")

    class Meta:
        ordering = ["sort_order", "-created_at"]
        verbose_name = "Фотография галереи"
        verbose_name_plural = "Фотографии галереи"

    def __str__(self):
        return self.caption or f"Gallery photo #{self.id}"


class BookingRequest(models.Model):
    class RequestStatus(models.TextChoices):
        PENDING = "PENDING", "Новая заявка"
        CONFIRMED = "CONFIRMED", "Подтверждено"
        CANCELED = "CANCELED", "Отклонено"

    house = models.ForeignKey(
        House, 
        on_delete=models.PROTECT, 
        related_name="bookings", 
        verbose_name="Выбранный домик"
    )
    guest_name = models.CharField(max_length=255, verbose_name="Имя гостя")
    guest_phone = models.CharField(max_length=50, verbose_name="Телефон")
    guest_email = models.EmailField(blank=True, verbose_name="Email")
    check_in = models.DateField(verbose_name="Дата заезда")
    check_out = models.DateField(verbose_name="Дата выезда")
    status = models.CharField(
        max_length=20,
        choices=RequestStatus.choices,
        default=RequestStatus.PENDING,
        verbose_name="Статус заявки"
    )
    comment = models.TextField(blank=True, verbose_name="Пожелания гостя")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Создана")

    class Meta:
        verbose_name = "Заявка на бронирование"
        verbose_name_plural = "Заявки на бронирование"
        indexes = [
            models.Index(fields=["status", "check_in"]),
        ]

    def __str__(self):
        return f"Заявка #{self.id} от {self.guest_name} ({self.house.title})"