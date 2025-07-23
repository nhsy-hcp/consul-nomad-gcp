variable "gcs_bucket" {
  type        = string
  description = "Google Cloud Storage bucket for storing results"
}

variable "gcp_project" {
  description = "Google Cloud Project ID"
}

variable "gcp_wi_provider" {
  description = "Google Cloud IAM Workload Identity Pool Provider Name"
}

variable "gcp_service_account" {
  description = "Google Cloud Service Account Email"
}

variable "docker_image" {
  type        = string
  description = "Docker image for the Monte Carlo simulation"
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
    meta_optional = ["DAYS", "SIMULATIONS", "ALPHA_VANTAGE_API_KEY"]
  }

  group "simulation" {
    count = 1

    # Reschedule policy - disable to ignore placement errors
    reschedule {
      attempts       = 15
      interval       = "1h"
      delay          = "30s"
      delay_function = "exponential"
      max_delay      = "120s"
      unlimited      = false
    }

    task "monte-carlo" {
      driver = "docker"

      config {
        image = var.docker_image
        force_pull = false
        
        args = [
          "--tickers", "${NOMAD_META_TICKER}",
          "--days", "${NOMAD_META_DAYS}",
          "--simulations", "${NOMAD_META_SIMULATIONS}",
          "--output-dir", "/alloc/data",
          "--cache-dir", "/app/data",
          "--no-plots",
          "--gcs-bucket", var.gcs_bucket,
          "--gcs-prefix", "${NOMAD_ALLOC_ID}",
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

        # Google Cloud credentials
        GOOGLE_APPLICATION_CREDENTIALS = "/local/cred.json"

      }

      # Resource requirements (optimized for single ticker)
      resources {
        cpu    = 100   # 0.5 CPU core to fit available resources
        memory = 512  # 1GB RAM (reduced since single ticker)
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
        interval = "10m"
        delay    = "15s"
        mode     = "fail"
      }

      # Nomad Workload Identity for authenticating with Google Federated
      # Workload Identity Provider
      identity {
        # Name must match the file parameter in the credential config template
        # below *and* the principal used in the Service Account IAM Binding.
        name = "tutorial"
        file = true

        # Audience must match the audience specified in the Google IAM Workload
        # Identity Pool Provider.
        aud  = ["gcp"]
        ttl  = "1h"
      }

      template {
              destination = "local/cred.json"
              data        = <<EOF
{
  "type": "external_account",
  "audience": "//iam.googleapis.com/{{ env "NOMAD_META_wi_provider" }}",
  "subject_token_type": "urn:ietf:params:oauth:token-type:jwt",
  "token_url": "https://sts.googleapis.com/v1/token",
  "service_account_impersonation_url": "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/{{ env "NOMAD_META_service_account" }}:generateAccessToken",
  "credential_source": {
    "file": "/secrets/nomad_tutorial.jwt",
    "format": {
      "type": "text"
    }
  }
}
EOF
      }
    }
  }

  # # Spread jobs across different nodes for better performance
  # spread {
  #   attribute = "${node.unique.id}"
  #   weight    = 100
  # }

  # Job metadata
  meta {
    bucket          = var.gcs_bucket
    project         = var.gcp_project
    wi_provider     = var.gcp_wi_provider
    service_account = var.gcp_service_account
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