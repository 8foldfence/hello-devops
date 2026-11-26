from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_home_page_loads():
    r = client.get("/")
    assert r.status_code == 200
    assert "Hello, DevOps!" in r.text


def test_health_check():
    r = client.get("/healthz")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_metrics_exposed():
    client.get("/")
    r = client.get("/metrics")
    assert r.status_code == 200
    assert "http_requests_total" in r.text
