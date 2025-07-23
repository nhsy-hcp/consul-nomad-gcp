# Multi-stage build for optimized image size
FROM python:3.11-slim AS builder

# Install system dependencies for building Python packages
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Production stage
FROM python:3.11-slim AS production

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy virtual environment from builder stage
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Create non-root user for security
RUN groupadd -r montecarlo && useradd -r -g montecarlo montecarlo

# Create application directories and matplotlib cache directory
RUN mkdir -p /app/src /app/config /app/data /app/results && \
    mkdir -p /home/montecarlo/.config/matplotlib && \
    chown -R montecarlo:montecarlo /app /home/montecarlo

# Set working directory
WORKDIR /app

# Copy application code
COPY src/ /app/src/
COPY config/ /app/config/
COPY data/ /app/data/

# Make main script executable
RUN chmod +x /app/src/main.py

# Change ownership of application files
RUN chown -R montecarlo:montecarlo /app

# Switch to non-root user
USER montecarlo

# Set Python path
ENV PYTHONPATH="/app/src:$PYTHONPATH"

# GCS authentication environment variables
# These can be set at runtime for different authentication methods
ENV GOOGLE_APPLICATION_CREDENTIALS=""
ENV GOOGLE_CLOUD_PROJECT=""

# Set cache directory for matplotlib
ENV MPLCONFIGDIR="/home/montecarlo/.config/matplotlib"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import sys; sys.path.append('/app/src'); import monte_carlo, data_fetcher, visualizer" || exit 1

# Default command
ENTRYPOINT ["python", "/app/src/main.py"]

# Default arguments
CMD ["--help"]

# Labels for better container management
LABEL maintainer="Monte Carlo Simulation"
LABEL version="1.0"
LABEL description="Monte Carlo stock price simulation container"