from django.db import models
from django.utils.text import slugify


class JournalArticle(models.Model):
    class Category(models.TextChoices):
        GARDEN_NOTES = "gardenNotes", "Garden Notes"
        SEASONAL_TIPS = "seasonalTips", "Seasonal Tips"
        GUEST_STORIES = "guestStories", "Guest Stories"

    title = models.CharField(max_length=255, verbose_name="Title")
    slug = models.SlugField(max_length=255, unique=True, verbose_name="URL slug")
    category = models.CharField(
        max_length=20,
        choices=Category.choices,
        default=Category.GARDEN_NOTES,
        verbose_name="Category",
    )
    image = models.ImageField(upload_to="journal/", blank=True, verbose_name="Image")
    alt = models.CharField(max_length=255, blank=True, verbose_name="Alt text")
    content = models.TextField(verbose_name="Content (HTML)")
    description = models.TextField(blank=True, verbose_name="Short description (teaser)")
    date = models.DateField(verbose_name="Publication date")
    is_published = models.BooleanField(default=True, verbose_name="Published")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Created at")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Updated at")

    class Meta:
        verbose_name = "Journal article"
        verbose_name_plural = "Journal articles"
        ordering = ["-date"]

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.title)
        super().save(*args, **kwargs)

    def __str__(self):
        return self.title