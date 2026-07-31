# backend/shop/serializers.py
from rest_framework import serializers
from .models import Category, Product, Order, OrderItem


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ['id', 'title', 'slug', 'description', 'image']


class ProductSerializer(serializers.ModelSerializer):
    category = CategorySerializer(read_only=True)
    category_id = serializers.PrimaryKeyRelatedField(
        queryset=Category.objects.all(),
        source='category',
        write_only=True,
    )

    class Meta:
        model = Product
        fields = [
            'id', 'category', 'category_id', 'title', 'slug',
            'description', 'price', 'stock', 'status', 'image', 'is_active',
        ]


class OrderItemSerializer(serializers.ModelSerializer):
    product = ProductSerializer(read_only=True)

    class Meta:
        model = OrderItem
        fields = ['id', 'product', 'quantity', 'unit_price']


class OrderItemWriteSerializer(serializers.ModelSerializer):
    product_id = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.filter(is_active=True),
        source='product',
        write_only=True,
    )

    class Meta:
        model = OrderItem
        fields = ['product_id', 'quantity']


class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)

    class Meta:
        model = Order
        fields = [
            'id', 'guest_name', 'guest_phone', 'guest_email',
            'comment', 'status', 'items', 'created_at',
        ]


class OrderCreateSerializer(serializers.ModelSerializer):
    items = OrderItemWriteSerializer(many=True, write_only=True)

    class Meta:
        model = Order
        fields = [
            'guest_name', 'guest_phone', 'guest_email', 'comment', 'items',
        ]

    def create(self, validated_data):
        items_data = validated_data.pop('items')
        order = Order.objects.create(**validated_data)
        for item_data in items_data:
            product = item_data['product']
            OrderItem.objects.create(
                order=order,
                product=product,
                quantity=item_data['quantity'],
                unit_price=product.price,
            )
        return order
