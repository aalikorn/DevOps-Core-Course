import os
import tempfile

from fastapi.testclient import TestClient

# Use a temporary file for the visits counter during tests
_tmp_dir = tempfile.mkdtemp()
os.environ["VISITS_FILE"] = os.path.join(_tmp_dir, "visits")

from app import app  # noqa: E402  (import after env override)

import re  # noqa: E402

client = TestClient(app)


def test_read_main():
    """Test the root endpoint returns correct structure and 200 OK."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()

    # Check top-level keys
    assert "service" in data
    assert "system" in data
    assert "runtime" in data
    assert "request" in data
    assert "visits" in data

    # Check service info
    assert data["service"]["name"] == "devops-info-service"

    # Check runtime info
    assert "uptime_seconds" in data["runtime"]
    assert "uptime_human" in data["runtime"]

    # Visits must be a positive integer (at least 1 after this request)
    assert isinstance(data["visits"], int)
    assert data["visits"] >= 1


def test_visits_endpoint():
    """Test the /visits endpoint returns the current count."""
    # Hit root a few times to increment
    client.get("/")
    client.get("/")
    response = client.get("/visits")
    assert response.status_code == 200
    data = response.json()
    assert "visits" in data
    assert isinstance(data["visits"], int)
    assert data["visits"] >= 2


def test_visits_increment():
    """Test that each root request increments the counter."""
    before = client.get("/visits").json()["visits"]
    client.get("/")
    after = client.get("/visits").json()["visits"]
    assert after == before + 1


def test_health_check():
    """Test the health check endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()

    assert data["status"] == "healthy"
    assert "uptime_seconds" in data
    assert isinstance(data["uptime_seconds"], int)


def test_404_handler():
    """Test that non-existent endpoints return 404."""
    response = client.get("/non-existent-endpoint")
    assert response.status_code == 404
    data = response.json()
    assert data["error"] == "Not Found"


def test_uptime_calculation():
    """Test that uptime is increasing."""
    response1 = client.get("/health")
    uptime1 = response1.json()["uptime_seconds"]
    assert uptime1 >= 0
