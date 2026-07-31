# backend/guests/admin.py
from django.contrib import admin
from .models import House, HouseImage, GalleryImage, BookingRequest

# Инлайн для добавления фотографий прямо на странице домика
class HouseImageInline(admin.TabularInline):
    model = HouseImage
    extra = 1

@admin.register(House)
class HouseAdmin(admin.ModelAdmin):
    list_display = ('title', 'price_per_night', 'max_guests', 'is_available')
    prepopulated_fields = {'slug': ('title',)}
    list_editable = ('price_per_night', 'is_available')
    inlines = [HouseImageInline]

@admin.register(GalleryImage)
class GalleryImageAdmin(admin.ModelAdmin):
    list_display = ('caption', 'category', 'sort_order', 'is_published')
    list_editable = ('sort_order', 'is_published')
    list_filter = ('category', 'is_published')
    search_fields = ('caption', 'alt')

@admin.register(BookingRequest)
class BookingRequestAdmin(admin.ModelAdmin):
    list_display = ('id', 'house', 'guest_name', 'check_in', 'check_out', 'status', 'created_at')
    list_filter = ('status', 'check_in', 'house')
    search_fields = ('guest_name', 'guest_phone', 'guest_email')
    list_editable = ('status',)
    readonly_fields = ('created_at',)