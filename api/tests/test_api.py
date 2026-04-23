"""API unit tests - uses real Redis service."""
import os
import sys
from unittest.mock import patch
import pytest  # noqa: F821
import fakeredis

# Fix path BEFORE any imports
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

# All imports AFTER path fix
from main import app  # noqa: E402


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


def test_health_check(client):
    """Test 1: Health check endpoint."""
    rv = client.get('/')
    assert rv.status_code == 200
    assert b'healthy' in rv.data  # Adjust to your response


def test_job_create(client):
    """Test 2: Create job endpoint."""
    job_data = {'task': 'test_task', 'priority': 1}
    rv = client.post('/jobs', json=job_data)
    assert rv.status_code == 201
    assert b'job created' in rv.data  # Adjust


def test_get_jobs(client):
    """Test 3: Get jobs endpoint."""
    client.post('/jobs', json={'task': 'test_task', 'priority': 1})
    rv = client.get('/jobs')
    assert rv.status_code == 200
    assert b'test_task' in rv.data
