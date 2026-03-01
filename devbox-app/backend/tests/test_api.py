import pytest
from django.urls import reverse
from rest_framework.test import APIClient


@pytest.mark.django_db
def test_health_ok(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.django_db
def test_create_and_list_items():
    client = APIClient()

    create_response = client.post("/api/items", {"name": "item-1"}, format="json")
    assert create_response.status_code == 201
    assert create_response.json()["name"] == "item-1"

    list_response = client.get("/api/items")
    assert list_response.status_code == 200
    payload = list_response.json()
    assert isinstance(payload, list)
    assert payload[0]["name"] == "item-1"
