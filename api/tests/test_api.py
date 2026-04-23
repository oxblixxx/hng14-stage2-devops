"""API unit tests with Redis mocked."""
import os
import sys
from unittest.mock import patch
import pytest
import fakeredis

# Add api/ to path FIRST (fixes E402)
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from main import app  # noqa: F401  # Only app needed


@pytest.fixture
def mock_redis():
    """Mock Redis instance."""
    with patch('main.redis_client', fakeredis.FakeStrictRedis()):
        yield


@pytest.fixture
def client():
    """Test client for API endpoints."""
    app.testing = True
    with app.test_client() as client:
        yield client


def test_health_check(mock_redis, client):
    """Test 1: Health check endpoint."""
    rv = client.get('/')
    assert rv.status_code == 200
    assert b'healthy' in rv.data  # Adjust based on your response


def test_job_create(mock_redis, client):
    """Test 2: Create job endpoint."""
    job_data = {'task': 'test_task', 'priority': 1}
    rv = client.post('/jobs', json=job_data)
    assert rv.status_code == 201
    assert b'job created' in rv.data  # Adjust assertion


def test_get_jobs(mock_redis, client):
    """Test 3: Get jobs endpoint."""
    # Create a job first
    client.post('/jobs', json={'task': 'test_task', 'priority': 1})
    rv = client.get('/jobs')
    assert rv.status_code == 200
    assert b'test_task' in rv.data  # Verify job in response
