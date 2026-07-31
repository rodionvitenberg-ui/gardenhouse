from rest_framework import viewsets
from rest_framework.permissions import AllowAny

from .models import JournalArticle
from .serializers import JournalArticleSerializer


class JournalArticleViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = JournalArticle.objects.filter(is_published=True)
    serializer_class = JournalArticleSerializer
    permission_classes = [AllowAny]
    lookup_field = "slug"