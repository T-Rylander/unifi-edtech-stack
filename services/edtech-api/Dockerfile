FROM python:3.12-alpine

# Metadata
LABEL maintainer="Travis Rylander"
LABEL description="Edtech API - AI-augmented VLAN management for UniFi"
LABEL version="0.1.0"

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apk add --no-cache \
    curl \
    gcc \
    musl-dev \
    linux-headers

# Copy requirements first (for layer caching)
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user
RUN addgroup -g 1000 edtech && \
    adduser -D -u 1000 -G edtech edtech && \
    chown -R edtech:edtech /app

# Switch to non-root user
USER edtech

# Expose Flask port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Run Flask app
CMD ["python", "app.py"]
