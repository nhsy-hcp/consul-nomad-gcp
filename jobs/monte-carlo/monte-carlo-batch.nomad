variable "gcs_bucket" {
  type        = string
  description = "Google Cloud Storage bucket for storing results"
  default     = "hc-2ea1d32d24964f82bedbf185c19-monte-carlo-impala"
}

variable "docker_image" {
  type        = string
  description = "Docker image for the Monte Carlo simulation"
  default     = "ghcr.io/nhsy-hcp/consul-nomad-gcp/monte-carlo:latest"
}

job "monte-carlo-batch" {
  datacenters = ["*"]
  type        = "batch"
  
  # Job priority
  priority = 50

  parameterized {
    # Single ticker per job for better isolation and resource management
    payload       = "optional"
    meta_required = ["TICKER"]
    meta_optional = ["DAYS", "SIMULATIONS", "GCS_BUCKET", "GCS_PREFIX", "ALPHA_VANTAGE_API_KEY"]
  }

  group "simulation" {
    count = 1

    task "monte-carlo" {
      driver = "docker"

      config {
        image = var.docker_image
        force_pull = true
        
        args = [
          "--tickers", "${NOMAD_META_TICKER}",
          "--days", "${NOMAD_META_DAYS}",
          "--simulations", "${NOMAD_META_SIMULATIONS}",
          "--output-dir", "/alloc/data",
          "--cache-dir", "/app/data",
          "--no-plots",  # Disable plots for batch jobs to save resources
          "--gcs-bucket", "${NOMAD_META_GCS_BUCKET}",
        ]
      }

      env {
        PYTHONPATH = "/app/src"
        PYTHONUNBUFFERED = "1"
        MPLBACKEND = "Agg"
        
        # Alpha Vantage API Key
        ALPHA_VANTAGE_API_KEY = "${NOMAD_META_ALPHA_VANTAGE_API_KEY}"
        
        # Add ticker to results prefix for easier identification
        RESULT_PREFIX = "${NOMAD_META_TICKER}_${NOMAD_ALLOC_ID}"
      }

      # Resource requirements (optimized for single ticker)
      resources {
        cpu    = 1000  # 1 CPU core
        memory = 1024  # 1GB RAM (reduced since single ticker)
      }

      # Configuration template
      template {
        data = <<EOF
# Monte Carlo Simulation Configuration for ${NOMAD_META_TICKER}
tickers:
  - ${NOMAD_META_TICKER}

# Simulation parameters
days: {{ env "NOMAD_META_DAYS" | or "252" }}
simulations: {{ env "NOMAD_META_SIMULATIONS" | or "10000" }}

# Risk analysis
confidence_levels:
  - 0.95
  - 0.99

# Data fetching settings
data:
  period: "2y"
  cache_duration_days: 1
  use_cache: true
  force_refresh: false
  
  # Alpha Vantage API configuration (uses environment variable)
  alpha_vantage_api_key: ""
  api_rate_limit_per_minute: 5
  api_daily_limit: 25

# Output settings
output:
  generate_plots: false    # Disabled for batch jobs
  export_csv: true
  results_prefix: "${NOMAD_META_TICKER}_"
  timestamp_suffix: false

# Performance settings
performance:
  max_paths_in_memory: 50000
  chunk_size: 1000
  use_numba: true

# Risk metrics
risk_metrics:
  calculate_var: true
  calculate_cvar: true
  calculate_maximum_drawdown: false
EOF
        destination = "local/simulation.yaml"
      }

      # Restart policy
      restart {
        attempts = 0
        interval = "30m"
        delay    = "15s"
        mode     = "fail"
      }

      # Kill timeout
      kill_timeout = "30s"
    }
  }

  # Spread jobs across different nodes for better performance
  spread {
    attribute = "${node.unique.id}"
    weight    = 100
  }

  # Job metadata
  meta {
    gcs_bucket = var.gcs_bucket
    image   = var.docker_image
    purpose = "monte-carlo-simulation"
    type    = "single-ticker-batch"
  }
}

# Example dispatch commands:
#
# Dispatch single ticker jobs:
# nomad job dispatch -meta TICKER=AAPL monte-carlo-batch
# nomad job dispatch -meta TICKER=MSFT monte-carlo-batch
# nomad job dispatch -meta TICKER=GOOG monte-carlo-batch
#
# With custom parameters:
# nomad job dispatch \
#   -meta TICKER=TSLA \
#   -meta DAYS=126 \
#   -meta SIMULATIONS=5000 \
#   monte-carlo-batch
#
# Monitor all dispatched jobs:
# nomad job status monte-carlo-batch