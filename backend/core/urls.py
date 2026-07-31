# backend/core/urls.py
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from rest_framework.routers import DefaultRouter

from shop.views import CategoryViewSet, ProductViewSet, OrderViewSet
from guests.views import HouseViewSet, GalleryImageViewSet, BookingRequestViewSet
from journal.views import JournalArticleViewSet

# Настройка роутера DRF
router = DefaultRouter()
router.register(r'categories', CategoryViewSet, basename='category')
router.register(r'products', ProductViewSet, basename='product')
router.register(r'houses', HouseViewSet, basename='house')
router.register(r'gallery', GalleryImageViewSet, basename='gallery')
router.register(r'bookings', BookingRequestViewSet, basename='booking')
router.register(r'journal', JournalArticleViewSet, basename='journal')
router.register(r'orders', OrderViewSet, basename='order')

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include(router.urls)), # Все эндпоинты будут доступны по префиксу /api/
]

# Раздача медиа-файлов в режиме разработки
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)