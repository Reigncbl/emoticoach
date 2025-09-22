# Stage 1: Builder
FROM python:3.11-slim-bullseye as builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages to a target directory
ENV PYTHONPATH=/install/lib/python3.11/site-packages \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1

# Create virtual environment to isolate dependencies
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy and install requirements in groups for better caching
COPY requirements.txt .

# Install dependencies in optimized order
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir torch==2.0.1 --extra-index-url https://download.pytorch.org/whl/cpu && \
    pip install --no-cache-dir numpy pandas scikit-learn faiss-cpu && \
    pip install --no-cache-dir -r requirements.txt && \
    find /opt/venv -type d -name "__pycache__" -exec rm -r {} + || true

# Stage 2: Final
FROM python:3.11-slim-bullseye

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    PYTHONPATH=/app

WORKDIR /app

# Copy virtual environment
COPY --from=builder /opt/venv /opt/venv

# Copy only necessary application files
COPY main.py .
COPY AIModel/ AIModel/
COPY core/ core/
COPY model/ model/
COPY routes/ routes/
COPY services/ services/
COPY utilities/ utilities/

# Create non-root user and fix permissions
RUN useradd -m appuser && \
    chown -R appuser:appuser /app /opt/venv && \
    find /opt/venv -type d -exec chmod 555 {} + && \
    find /opt/venv -type f -exec chmod 444 {} + && \
    chmod +x /opt/venv/bin/*

USER appuser

EXPOSE 8000

CMD ["python", "main.py"]