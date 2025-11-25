FROM python:3.11-slim

WORKDIR /app

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Copy only requirements first to leverage Docker layer caching
COPY requirements.txt .

# Install build tools temporarily, install Python deps (including PyTorch wheel),
# then remove build tools and apt lists in the same layer to keep the image small.
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential ca-certificates \
    && pip install --no-cache-dir torch==2.4.1 --index-url https://download.pytorch.org/whl/cpu \
    && pip install --no-cache-dir -r requirements.txt \
    && apt-get purge -y --auto-remove build-essential \
    && rm -rf /var/lib/apt/lists/* /root/.cache/pip

# Copy application code after installing dependencies to maximize cache hits
COPY . .

# Create non-root user and set ownership
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# Use uvicorn; keep single worker in container images by default (K8s / process managers
# can scale horizontally). Single worker reduces memory in many environments.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "6"]