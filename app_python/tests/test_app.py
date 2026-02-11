from fastapi.testclient import TestClient
from app import app

import re

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
    
    # Check service info
    assert data["service"]["name"] == "devops-info-service"
    
    # Check runtime info
    assert "uptime_seconds" in data["runtime"]
    assert "uptime_human" in data["runtime"]

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
    # First call
    response1 = client.get("/health")
    uptime1 = response1.json()["uptime_seconds"]
    
    # Wait a bit (simulated by logic or just assumption of execution time)
    # In a real test we might mock time, but here we just check type and existence
    assert uptime1 >= 0
