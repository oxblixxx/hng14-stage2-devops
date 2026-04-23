import pytest
import fakeredis
from fastapi.testclient import TestClient

from main import app, get_redis


@pytest.fixture
def client():
    app.dependency_overrides[get_redis] = lambda: fakeredis.FakeStrictRedis()
    return TestClient(app)


def test_health_check(client):
    rv = client.get("/")
    assert rv.status_code == 200


def test_job_create(client):
    rv = client.post("/jobs", json={"task": "test_task", "priority": 1})
    assert rv.status_code == 200 or rv.status_code == 201


def test_get_jobs(client):
    client.post("/jobs", json={"task": "test_task", "priority": 1})
    rv = client.get("/jobs/some-id")
    assert rv.status_code == 200 or rv.status_code == 404
