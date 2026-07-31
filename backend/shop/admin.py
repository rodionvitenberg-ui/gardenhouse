# backend/shop/admin.py
from django.contrib import admin
from .models import Category, Product, Order, OrderItem


class OrderItemInline(admin.TabularInline):
    model = OrderItem
    readonly_fields = ('unit_price',)
    extra = 0
    autocomplete_fields = ('product',)


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ('title', 'slug')
    prepopulated_fields = {'slug': ('title',)}


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ('title', 'category', 'price', 'stock', 'status', 'is_active')
    list_filter = ('status', 'is_active', 'category')
    search_fields = ('title', 'description')
    prepopulated_fields = {'slug': ('title',)}
    list_editable = ('price', 'stock', 'status', 'is_active')


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ('id', 'guest_name', 'guest_phone', 'status', 'created_at')
    list_filter = ('status',)
    search_fields = ('guest_name', 'guest_phone', 'guest_email')
    inlines = (OrderItemInline,)
    readonly_fields = ('created_at', 'updated_at')
