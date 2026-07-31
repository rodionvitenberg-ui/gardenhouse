# backend/shop/views.py
from rest_framework import viewsets, status
from rest_framework.response import Response
from .models import Category, Product, Order
from .serializers import (
    CategorySerializer,
    ProductSerializer,
    OrderSerializer,
    OrderCreateSerializer,
)


class CategoryViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer


class ProductViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Product.objects.filter(is_active=True)
    serializer_class = ProductSerializer


class OrderViewSet(viewsets.ModelViewSet):
    queryset = Order.objects.prefetch_related('items__product')

    def get_serializer_class(self):
        if self.action == 'create':
            return OrderCreateSerializer
        return OrderSerializer
