# ---------- Builder stage ----------
FROM python:3.12-slim AS builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---------- Final stage ----------
FROM python:3.12-slim

WORKDIR /app
ENV PYTHONUNBUFFERED=1

# Create non-root user
RUN useradd -m appuser

# Install procps for pgrep
RUN apt-get update && \
    apt-get install -y procps --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Copy dependencies
COPY --from=builder /install /usr/local

COPY . .

RUN chown -R appuser:appuser /app

USER appuser

# Healthcheck: ensure worker is running
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD pgrep -f "worker.py" || exit 1

CMD ["python", "worker.py"]
