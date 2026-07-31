from django.contrib import admin

from .models import JournalArticle


@admin.register(JournalArticle)
class JournalArticleAdmin(admin.ModelAdmin):
    list_display = ["title", "category", "date", "is_published"]
    list_filter = ["category", "is_published", "date"]
    search_fields = ["title", "description"]
    prepopulated_fields = {"slug": ("title",)}
    fieldsets = [
        (None, {"fields": ["title", "slug", "category", "date"]}),
        ("Content", {"fields": ["image", "alt", "description", "content"]}),
        ("Status", {"fields": ["is_published"]}),
    ]