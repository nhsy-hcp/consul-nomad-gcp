# Monte Carlo Stock Price Simulation

A comprehensive Monte Carlo simulation tool for financial risk analysis, built with Python and designed for deployment on HashiCorp Nomad with Google Cloud Storage integration.

## Features

- **Monte Carlo Engine**: Geometric Brownian Motion modeling for stock price simulation
- **Historical Data**: Support for CSV data import and mock data generation
- **Risk Analysis**: Value at Risk (VaR), statistical summaries, and distribution analysis
- **Visualizations**: Comprehensive plots including price paths, distributions, and risk metrics
- **Cloud Storage**: Seamless Google Cloud Storage integration for result persistence
- **Container Ready**: Optimized Docker container with security best practices
- **Nomad Integration**: Parameterized batch jobs for scalable execution
- **Testing**: 44+ comprehensive tests with full coverage

## Table of Contents

- [Quick Start](#-quick-start)
- [Installation](#-installation)
- [Usage](#-usage)
- [Docker](#-docker)
- [Nomad Deployment](#-nomad-deployment)
- [Nomad Batch Jobs](#-nomad-batch-jobs)
- [Configuration](#-configuration)
- [Testing](#-testing)
- [Project Structure](#-project-structure)
- [Examples](#-examples)
- [Troubleshooting](#-troubleshooting)

## Quick Start

### Using Docker (Recommended)

```bash
# Pull from GitHub Container Registry
docker pull ghcr.io/nhsy-hcp/consul-nomad-gcp/monte-carlo:latest

# Run a simple simulation
docker run --rm ghcr.io/nhsy-hcp/consul-nomad-gcp/monte-carlo:latest \
  --tickers AAPL MSFT GOOGL \
  --days 252 \
  --simulations 10000
```

### Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run simulation (creates ./results and ./data directories)
python src/main.py --tickers AAPL --days 126 --simulations 5000

# Results will be saved to ./results/ directory
# Cache data will be stored in ./data/ directory
```

## Installation

### Prerequisites

- Python 3.11+
- Docker (for containerized deployment)
- HashiCorp Nomad (for cluster deployment)
- Google Cloud SDK (for GCS integration)

### Python Dependencies

Install all dependencies:

```bash
pip install -r requirements.txt
```

## Usage

### Command Line Interface

```bash
python src/main.py [OPTIONS]
```

#### Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--tickers` | `-t` | Stock ticker symbols | Required |
| `--days` | `-d` | Number of days to simulate | 252 |
| `--simulations` | `-s` | Number of Monte Carlo paths | 10000 |
| `--output-dir` | `-o` | Local output directory | `./results` (local) / `/app/results` (Docker) |
| `--cache-dir` | | Data cache directory | `./data` (local) / `/app/data` (Docker) |
| `--config` | `-c` | Configuration file path | `./config/simulation.yaml` (local) / `/app/config/simulation.yaml` (Docker) |
| `--confidence-levels` | | VaR confidence levels | `[0.95, 0.99]` |
| `--gcs-bucket` | | GCS bucket URL for uploads | None |
| `--gcs-prefix` | | GCS object prefix | `monte-carlo-results` |
| `--no-plots` | | Skip generating visualizations | False |

### Basic Examples

```bash
# Simple simulation
python src/main.py --tickers AAPL

# Multiple tickers with custom parameters
python src/main.py --tickers AAPL MSFT GOOGL --days 126 --simulations 5000

# Upload results to Google Cloud Storage
python src/main.py --tickers NVDA --gcs-bucket gs://my-bucket/results

# Generate only data without plots (saves to ./results by default)
python src/main.py --tickers TSLA --no-plots

# Specify custom output directory
python src/main.py --tickers TSLA --output-dir ./custom-results
```

## Docker

### Building and Publishing

```bash
# Create and use a multi-platform builder
docker buildx create --name multiarch --use
docker buildx inspect --bootstrap

# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u nhsy-hcp --password-stdin

# Build and push multi-architecture image
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ghcr.io/nhsy-hcp/consul-nomad-gcp/monte-carlo:latest \
  --push .

# Pull from GHCR
docker pull ghcr.io/nhsy-hcp/consul-nomad-gcp/monte-carlo:latest

# Pull specific architecture if needed
docker pull --platform linux/amd64 ghcr.io/nhsy-hcp/consul-nomad-gcp/monte-carlo:latest
```

### Running Simulations

```bash
# Basic simulation
docker run --rm ghcr.io/nhsy-hcp/consul-nomad-gcp/monte-carlo:latest --tickers AAPL --days 60

# Mount local directory for results
docker run --rm \
  -v $(pwd)/results:/app/results \
  ghcr.io/nhsy-hcp/consul-nomad-gcp/monte-carlo:latest \
  --tickers AAPL MSFT \
  --output-dir /app/results

# With GCS upload
docker run --rm \
  -e GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
  -v /path/to/service-account.json:/path/to/service-account.json:ro \
  ghcr.io/nhsy-hcp/consul-nomad-gcp/monte-carlo:latest \
  --tickers GOOGL \
  --gcs-bucket gs://my-bucket/monte-carlo
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to GCS service account key |
| `GOOGLE_CLOUD_PROJECT` | GCP project ID |
| `MPLCONFIGDIR` | Matplotlib config directory |

## Nomad Deployment

### Submit the Job

```bash
nomad job run monte-carlo.nomad
```

### Dispatch Simulations

```bash
# Basic dispatch
nomad job dispatch monte-carlo-batch

# Custom parameters
nomad job dispatch \
  -meta TICKER="AAPL" \
  -meta DAYS="126" \
  -meta SIMULATIONS="5000" \
  monte-carlo-batch

# With GCS upload
nomad job dispatch \
  -meta TICKER="NVDA" \
  -meta DAYS="60" \
  -meta GCS_BUCKET="gs://my-bucket/monte-carlo-results" \
  -meta GCS_PREFIX="simulation-$(date +%Y%m%d)" \
  monte-carlo-batch
```

### Monitoring Jobs

```bash
# List job dispatches
nomad job status monte-carlo-batch

# View logs
nomad logs -f <allocation-id>

# Access results
nomad fs ls <allocation-id>/alloc/results/
```

## Nomad Batch Jobs

This guide explains how to run Monte Carlo simulations for multiple tickers as separate Nomad batch jobs.

### Overview

The batch job system allows you to:
- Run separate simulations for each ticker (better isolation)
- Leverage shared caching to avoid API rate limits
- Monitor and manage multiple jobs efficiently
- Scale horizontally across Nomad cluster nodes

### Quick Start

#### 1. Deploy the Batch Job

```bash
# Deploy the parameterized job template
nomad job run monte-carlo-batch.nomad
```

#### 2. Dispatch Multiple Ticker Jobs

```bash
# Dispatch jobs for multiple tickers
./dispatch-batch-jobs.sh AAPL MSFT GOOG TSLA NVDA

# With custom parameters
./dispatch-batch-jobs.sh -d 365 -s 5000 AAPL MSFT GOOG TSLA

# Monitor progress
./dispatch-batch-jobs.sh -m AAPL MSFT GOOG
```

#### 3. Monitor Jobs

```bash
# Watch job status continuously
nomad job status monte-carlo-batch

# Show logs for specific allocation
nomad alloc logs <ALLOC_ID>

# List recent job dispatches
nomad job status -short monte-carlo-batch
```

### Architecture

#### Job Structure
- **Parameterized Job**: `monte-carlo-batch` accepts ticker parameters
- **Single Ticker Per Job**: Each dispatch runs one ticker simulation
- **Shared Storage**: Cache and results volumes prevent API exhaustion
- **Resource Isolation**: Jobs run independently with dedicated resources

#### Volume Configuration
- **Cache Volume**: `/opt/nomad/volumes/monte-carlo-cache`
  - Shared Alpha Vantage API response cache
  - Prevents hitting rate limits (25 calls/day)
  - Persists between job runs
- **Results Volume**: `/opt/nomad/volumes/monte-carlo-results`
  - Centralized storage for simulation outputs
  - Accessible across all nodes

### Usage Examples

#### Basic Dispatch
```bash
# Single ticker
nomad job dispatch -meta TICKER=AAPL monte-carlo-batch

# With custom parameters
nomad job dispatch \
  -meta TICKER=TSLA \
  -meta DAYS=126 \
  -meta SIMULATIONS=5000 \
  monte-carlo-batch
```

#### Batch Operations
```bash
# Dispatch multiple jobs with monitoring
./dispatch-batch-jobs.sh -m AAPL MSFT GOOG TSLA NVDA

# Custom simulation parameters for all tickers
./dispatch-batch-jobs.sh -d 60 -s 2500 AAPL MSFT GOOG

# Wait for all jobs to complete
./dispatch-batch-jobs.sh -w AAPL MSFT
```

#### Monitoring
```bash
# Real-time status monitoring
watch nomad job status monte-carlo-batch

# Show recent job summary
nomad job status -short monte-carlo-batch

# View logs for specific allocation
nomad alloc logs <ALLOC_ID>

# List available results
nomad alloc fs <ALLOC_ID> /alloc/results/
```

### Batch Job Configuration

#### Job Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `TICKER` | Stock ticker symbol (required) | - |
| `DAYS` | Trading days to simulate | 252 |
| `SIMULATIONS` | Number of Monte Carlo paths | 10000 |

#### Resource Allocation
- **CPU**: 1000 (1 core per job)
- **Memory**: 1024 MB (1 GB per job)
- **Disk**: Shared volumes for cache/results

#### API Rate Limiting
- **Alpha Vantage Free Tier**: 5 calls/minute, 25 calls/day
- **Caching Strategy**: Shared volume prevents duplicate API calls
- **Cache Duration**: 1 day (configurable)

### File Structure

```
monte-carlo/
├── monte-carlo-batch.nomad     # Parameterized job definition
├── dispatch-batch-jobs.sh      # Job dispatch script
├── setup-volumes.sh            # Volume setup script
└── nomad-volumes.hcl          # Generated volume config
```

### Best Practices

#### Performance Optimization
1. **Stagger Job Dispatch**: Use small delays between dispatches
2. **Resource Planning**: Monitor cluster capacity for concurrent jobs
3. **Cache Warming**: Run popular tickers first to populate cache

#### Monitoring Strategy
1. **Real-time Monitoring**: Use `watch` mode during active periods
2. **Log Analysis**: Check logs for API errors or simulation issues
3. **Result Verification**: Validate output files after completion

#### Error Handling
1. **Failed Jobs**: Check logs for API limits or configuration errors
2. **Retry Strategy**: Jobs auto-retry twice with 15s delay
3. **Cleanup**: Use `cleanup` command to stop problematic jobs

### Batch Job Troubleshooting

#### Common Issues

**Job Dispatch Fails**
```bash
# Check if job exists
nomad job status monte-carlo-batch

# Verify job is parameterized
nomad job inspect monte-carlo-batch | grep -A5 parameterized
```

**Volume Mount Errors**
```bash
# Verify volumes exist on client nodes
nomad node status -self | grep -A10 "Host Volumes"

# Check directory permissions
ls -la /opt/nomad/volumes/
```

**API Rate Limit Exceeded**
```bash
# Check cache utilization
ls -la /opt/nomad/volumes/monte-carlo-cache/

# Monitor API usage in job logs
nomad alloc logs <ALLOC_ID> | grep "rate limit"
```

#### Debugging Commands

```bash
# Check job template
nomad job plan monte-carlo-batch.nomad

# Inspect running allocation
nomad alloc status <ALLOC_ID>

# Access allocation filesystem
nomad alloc fs <ALLOC_ID> /alloc/results/

# View allocation logs
nomad alloc logs <ALLOC_ID>
```

### Advanced Usage

#### Custom Job Templates
You can modify `monte-carlo-batch.nomad` to:
- Add GCS upload parameters
- Adjust resource requirements
- Configure different output formats
- Add custom environment variables

#### Integration with CI/CD
```bash
# Example GitLab CI job
deploy_batch_simulation:
  script:
    - nomad job run monte-carlo-batch.nomad
    - ./dispatch-batch-jobs.sh -w $TICKERS
```

#### Periodic Batch Jobs
Uncomment the `periodic` block in the job file to enable scheduled runs:
```hcl
periodic {
  cron             = "0 9 * * MON-FRI"  # 9 AM weekdays
  prohibit_overlap = true
  timezone         = "America/New_York"
}
```

## Configuration

### Configuration File (`config/simulation.yaml`)

```yaml
# Stock tickers to simulate
tickers:
  - AAPL
  - MSFT
  - GOOGL

# Simulation parameters
days: 252
simulations: 10000

# Risk analysis
confidence_levels:
  - 0.95
  - 0.99

# Data settings
data:
  period: "2y"
  cache_duration_days: 1
  use_cache: true

# Output settings
output:
  generate_plots: true
  export_csv: true

# Model parameters (optional overrides)
model:
  random_seed: 42
  type: "geometric_brownian_motion"
```

### Google Cloud Storage Authentication

#### Service Account Key

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
```

#### Application Default Credentials

```bash
gcloud auth application-default login
```

#### Workload Identity (GKE/Nomad on GCP)

Configure workload identity for seamless authentication in cloud environments.

## Testing

### Run All Tests

```bash
# Using pytest
python -m pytest tests/ -v

# With coverage
python -m pytest tests/ --cov=src --cov-report=html

# In Docker
docker run --rm -v $(pwd):/workspace -w /workspace --entrypoint="" \
  ghcr.io/nhsy-hcp/consul-nomad-gcp/monte-carlo:latest python -m pytest tests/ -v
```

### Test Categories

- **Unit Tests**: Core Monte Carlo algorithms
- **Integration Tests**: Data fetching and caching
- **GCS Tests**: Cloud storage integration
- **Mock Tests**: External API interactions

## Project Structure

```
monte-carlo/
├── README.md                    # This file
├── requirements.txt             # Python dependencies
├── Dockerfile                   # Container definition
├── monte-carlo-batch.nomad      # Nomad job specification
├── dispatch-batch-jobs.sh       # Job dispatch script
├── notes.txt                    # Development notes
├── src/                         # Source code
│   ├── main.py                  # CLI entry point
│   ├── monte_carlo.py           # Monte Carlo engine
│   ├── data_fetcher.py          # Data processing utilities
│   ├── visualizer.py            # Plotting and charts
│   └── gcs_uploader.py          # Google Cloud Storage
├── config/
│   └── simulation.yaml          # Default configuration
├── data/                        # Historical data cache
│   ├── *.csv                    # Stock price data files
│   └── *.json                   # Metadata files
├── results/                     # Simulation outputs
│   ├── *.csv                    # Results data
│   └── *.json                   # Upload manifests
└── tests/                       # Test suite
    ├── __init__.py
    ├── test_monte_carlo.py
    ├── test_data_fetcher.py
    └── test_gcs_uploader.py
```

## Examples

### 1. Risk Analysis for Tech Stocks

```bash
python src/main.py \
  --tickers AAPL MSFT GOOG NVDA \
  --days 252 \
  --simulations 50000 \
  --confidence-levels 0.90 0.95 0.99
```

### 2. Short-term Volatility Study

```bash
python src/main.py \
  --tickers TSLA GME AMC \
  --days 30 \
  --simulations 25000
```

### 3. Portfolio Simulation with Cloud Storage

```bash
python src/main.py \
  --tickers SPY QQQ IWM \
  --days 252 \
  --simulations 100000 \
  --gcs-bucket gs://financial-analysis \
  --gcs-prefix "analysis-$(date +%Y%m%d)"
```

### 4. Automated Daily Analysis (Nomad)

```bash
nomad job run monte-carlo.nomad

# Or dispatch daily
nomad job dispatch \
  -meta TICKER="^GSPC" \
  -meta DAYS="5" \
  -meta GCS_BUCKET="gs://daily-market-analysis" \
  monte-carlo-batch
```

## Troubleshooting

### Common Issues

#### 1. GCS Permission Errors

```
Error: Failed to upload results to GCS: 403 Forbidden
```

**Solutions**:
- Verify `GOOGLE_APPLICATION_CREDENTIALS` is set correctly
- Ensure service account has `Storage Object Creator` role
- Check bucket permissions and existence

#### 2. Docker Permission Issues

```
PermissionError: [Errno 13] Permission denied: '/home/montecarlo'
```

**Solution**: The Docker image creates proper directories and permissions automatically. Rebuild the image if issues persist.

#### 3. Insufficient Data

```
ValueError: Insufficient historical data (need at least 30 days)
```

**Solution**: Some tickers may have limited historical data. Try different tickers or shorter periods.

### Performance Optimization

- **Simulations**: Start with 10,000 simulations, increase for more accuracy
- **Caching**: Enable data caching to reduce API calls
- **Parallelization**: Use Nomad for running multiple simulations concurrently
- **Memory**: For large simulations (>100k paths), consider increasing container memory

### Debugging

Enable verbose logging by modifying the configuration:

```yaml
logging:
  level: "DEBUG"
```