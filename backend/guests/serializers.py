# backend/guests/serializers.py
from rest_framework import serializers
from .models import House, HouseImage, GalleryImage, BookingRequest


class HouseImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = HouseImage
        fields = ['id', 'image']


class HouseSerializer(serializers.ModelSerializer):
    images = HouseImageSerializer(many=True, read_only=True)

    class Meta:
        model = House
        fields = [
            'id', 'title', 'slug', 'description', 'max_guests', 
            'price_per_night', 'is_available', 'images'
        ]


class GalleryImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = GalleryImage
        fields = ['id', 'image', 'caption', 'alt', 'category', 'sort_order']


class BookingRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model = BookingRequest
        fields = [
            'id', 'house', 'guest_name', 'guest_phone', 'guest_email', 
            'check_in', 'check_out', 'comment', 'status', 'created_at'
        ]
        read_only_fields = ['status', 'created_at']

    def validate(self, data):
        if data['check_in'] >= data['check_out']:
            raise serializers.ValidationError({
                "check_out": "Дата выезда должна быть строго позже даты заезда."
            })
        return data