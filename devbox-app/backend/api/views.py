from rest_framework import mixins, viewsets

from .models import Item
from .serializers import ItemSerializer


class ItemViewSet(mixins.ListModelMixin, mixins.CreateModelMixin, viewsets.GenericViewSet):
    queryset = Item.objects.order_by("-created_at")
    serializer_class = ItemSerializer
