# ===========================
# Stage 1: Build environment
# ===========================
FROM python:3.10-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /install

# Install build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libffi-dev \
    libpq-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies into a separate directory
COPY requirements.txt .
RUN pip install --upgrade pip setuptools wheel \
    #&& pip install --prefix=/install -r requirements.txt
    && pip install --prefix=/install --no-cache-dir -r requirements.txt


# ===========================
# Stage 2: Final image
# ===========================
FROM python:3.10-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy app source code
COPY . .

# Expose Flask port
EXPOSE 5000

# Run with Gunicorn
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "app:app"]
