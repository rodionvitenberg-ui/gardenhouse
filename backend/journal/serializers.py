from rest_framework import serializers
from .models import JournalArticle


class JournalArticleSerializer(serializers.ModelSerializer):
    class Meta:
        model = JournalArticle
        fields = [
            "id", "title", "slug", "category", "image", "alt",
            "content", "description", "date", "is_published",
            "created_at", "updated_at",
        ]