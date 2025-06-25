job "open-webui" {
  type        = "service"

  group "open-webui" {
    count = 1

    update {
      min_healthy_time  = "30s"
      healthy_deadline  = "10m"
      progress_deadline = "15m"
  	}

    ephemeral_disk {
      migrate = true
      size    = 1024 * 20 # 20GB
      sticky  = true
    }

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
        cpu = 1000 * 2 # 2 CPU core
        memory = 1024 * 8 # 12GB
        device "nvidia/gpu" {
          count = 1
        }
      }
      volume_mount {
        volume      = "openwebui-ollama"
        destination = "/root/.ollama"
        read_only   = false
      }
      volume_mount {
        volume      = "openwebui-data"
        destination = "/app/backend/data"
        read_only   = false
      }
    }

    task "web" {
      driver = "docker"

      env {
        PORT = "${NOMAD_PORT_http}"
        # OLLAMA_HOST = "${NOMAD_HOST_IP_api}"
        OLLAMA_BASE_URL = "http://${NOMAD_HOST_ADDR_api}"
        # OLLAMA_BASE_URLS = "http://localhost:11434;http://127.0.0.1:11434;http://host.docker.internal:11434"
        ENABLE_SIGNUP = false
        DEFAULT_MODELS = "llama3.1"
        USE_OLLAMA = true
        ENABLE_RAG_WEB_SEARCH = true
        USER_AGENT = "myagent"
        WEBUI_AUTH = false
      }

      # template {
      #   destination = "${NOMAD_SECRETS_DIR}/env.txt"
      #   env         = true
      #   data        = <<-EOH
      #     OPENAI_API_KEY={{ with nomadVar "nomad/jobs/open-webui" }}{{ .OPENAI_API_KEY }}{{ end }}
      #   EOH
      # }

      config {
        # image = "ghcr.io/open-webui/open-webui:0.3.30-ollama"
        image = "ghcr.io/open-webui/open-webui:cuda"
        ports = ["http"]
        # cpu_hard_limit = false
        # memory_hard_limit = 1024 * 12
      }
      resources {
        cpu    = 500  # MHz
        memory = 1024 * 4 # 12GB
      }
      volume_mount {
        volume      = "openwebui-ollama"
        destination = "/root/.ollama"
        read_only   = false
      }
      volume_mount {
        volume      = "openwebui-data"
        destination = "/app/backend/data"
        read_only   = false
      }
      service {
        name = "open-webui-api"
        port = "api"
        # provider = "nomad"
        check {
          type     = "tcp"
          port     = "api"
          interval = "10s"
          timeout  = "2s"
        }
      }
      service {
        name = "open-webui-http"
        port = "http"
        # provider = "nomad"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.open-webui.entrypoints=websecure",
          "traefik.http.routers.open-webui.tls=true",
          "traefik.http.routers.open-webui.tls.certresolver=le",
        ]
        check {
          type     = "tcp"
          port     = "http"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}