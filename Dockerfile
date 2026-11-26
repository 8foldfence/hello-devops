FROM python:3.12-slim

WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app ./app

# Version is stamped in at build time by the release pipeline
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}

# Don't run as root
RUN useradd --uid 10001 appuser
USER 10001

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
