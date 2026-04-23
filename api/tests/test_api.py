"""API unit tests - FastAPI with real Redis service."""
import os
import pytest
from fastapi.testclient import TestClient


from main import app


@pytest.fixture
def client():
    """Test client for FastAPI endpoints."""
    return TestClient(app)


def test_health_check(client):
    """Test 1: Health check endpoint."""
    rv = client.get('/health')
    assert rv.status_code == 200
    assert rv.json() == {"status": "ok"}


def test_job_create(client):
    """Test 2: Create job endpoint."""
    rv = client.post('/jobs')
    assert rv.status_code == 200

    job_id = rv.json()["job_id"]
    assert len(job_id) > 0


def test_get_jobs(client):
    """Test 3: Get job status."""
    job_response = client.post('/jobs')
    job_id = job_response.json()["job_id"]

    rv = client.get(f'/jobs/{job_id}')
    assert rv.status_code == 200
    assert rv.json()["status"] == "queued"
