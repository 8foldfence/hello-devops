"""hello-devops: a one-page website used to learn the DevOps lifecycle."""

import os
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from prometheus_client import Counter, make_asgi_app

APP_VERSION = os.getenv("APP_VERSION", "dev")
INDEX_HTML = (Path(__file__).parent / "static" / "index.html").read_text()

app = FastAPI(title="hello-devops")

# --- Monitoring: every request is counted so Prometheus/Grafana can graph it ---
REQUESTS = Counter(
    "http_requests_total", "HTTP requests", ["method", "path", "status"]
)


@app.middleware("http")
async def count_requests(request: Request, call_next):
    response = await call_next(request)
    if request.url.path != "/metrics":
        REQUESTS.labels(request.method, request.url.path, response.status_code).inc()
    return response


app.mount("/metrics", make_asgi_app())


@app.get("/", response_class=HTMLResponse)
def home():
    return INDEX_HTML.replace("{{VERSION}}", APP_VERSION)


@app.get("/healthz")
def healthz():
    """Kubernetes liveness/readiness probe."""
    return {"status": "ok", "version": APP_VERSION}
