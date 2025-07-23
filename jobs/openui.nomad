job "open-webui" {
  node_pool   = "gpu"
  type        = "service"

  group "open-webui" {
    count = 1

    update {
      min_healthy_time  = "30s"
      healthy_deadline  = "10m"
      progress_deadline = "15m"
  	}

    # ephemeral_disk {
    #   migrate = true
    #   size    = 1024 * 20 # 20GB
    #   sticky  = true
    # }

    volume "openwebui-ollama" {
      type      = "host"
      read_only = false
      source    = "openwebui-ollama"
    }
    volume "openwebui-data" {
      type      = "host"
      read_only = false
      source    = "openwebui-data"
    }

    network {
      mode = "bridge"
      port "api" {
        to = 11434
      }
      port "http" {
        to = 8080
      }
    }

    task "ollama" {
      driver = "docker"

      config {
        image = "ollama/ollama"
        ports = ["api"]
      }

      resources {
        cpu = 1000 * 2    # 2 CPU cores
        memory = 1024 * 4 # 4GB
        device "nvidia/gpu" {
          count = 1
        }
      }

      volume_mount {
        volume      = "openwebui-ollama"
        destination = "/root/.ollama"
        read_only   = false
      }

      service {
        name = "ollama"
        port = "api"
        check {
          type     = "tcp"
          port     = "api"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }

    task "open-webui" {
      driver = "docker"

      env {
        PORT = "${NOMAD_PORT_http}"
        OLLAMA_BASE_URL = "http://${NOMAD_HOST_ADDR_api}"
        ENABLE_SIGNUP = "false"
        DEFAULT_MODELS = "llama3.1"
        USE_OLLAMA = "true"
        ENABLE_RAG_WEB_SEARCH = "true"
        USER_AGENT = "openui-nomad"
        WEBUI_AUTH = "false"
      }

      config {
        image = "ghcr.io/open-webui/open-webui:cuda"
        ports = ["http"]
      }

      resources {
        cpu    = 1000     # 1 CPU core
        memory = 1024 * 4 # 1GB
      }

      volume_mount {
        volume      = "openwebui-data"
        destination = "/app/backend/data"
        read_only   = false
      }

      service {
        name = "open-webui"
        port = "http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.open-webui.entrypoints=websecure",
          "traefik.http.routers.open-webui.tls=true",
          "traefik.http.routers.open-webui.tls.certresolver=le",
        ]
        check {
          type     = "http"
          path     = "/health"
          port     = "http"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}