# backend/guests/views.py
from rest_framework import viewsets, mixins
from .models import House, GalleryImage, BookingRequest
from .serializers import HouseSerializer, GalleryImageSerializer, BookingRequestSerializer


class HouseViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = House.objects.filter(is_available=True)
    serializer_class = HouseSerializer


class GalleryImageViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = GalleryImage.objects.filter(is_published=True)
    serializer_class = GalleryImageSerializer


class BookingRequestViewSet(mixins.CreateModelMixin, viewsets.GenericViewSet):
    queryset = BookingRequest.objects.all()
    serializer_class = BookingRequestSerializer