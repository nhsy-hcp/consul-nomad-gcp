variable "password" {
  type = string
  default = "argon2:$argon2id$v=19$m=10240,t=10,p=8$TAR5kr9AqEkPmL+XMqQIiw$YHFirJGYWhS2krn+1dSJ/gKqhNCoAlBU2TsdT8dyeRQ"
}

job "jupyter" {
  node_pool = "default"
  type = "service"

  group "jupyter" {
    count = 1

    # Restart policy
    restart {
      attempts = 3
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    # Network configuration
    network {
      port "http" {}
    }

    task "server" {
      driver = "docker"

      # Volume mount
      volume_mount {
        volume      = "jupyter"
        destination = "/home/jovyan/work"
        read_only   = false
      }

      config {
        image = "jupyter/scipy-notebook:latest"
        ports = ["http"]

        # Run with custom configuration
        command = "start-notebook.sh"
        args = [
          "--NotebookApp.token=''",
          "--NotebookApp.password='${var.password}'",
          "--NotebookApp.allow_root=True",
          "--NotebookApp.ip=0.0.0.0",
          "--NotebookApp.port=${NOMAD_PORT_http}",
          "--NotebookApp.allow_origin='*'",
          "--NotebookApp.disable_check_xsrf=True"
        ]
      }

      # Environment variables
      env {
        JUPYTER_ENABLE_LAB = "yes"
        GRANT_SUDO         = "yes"
      }

      # Resource requirements
      resources {
        cpu    = 1000  # 1 CPU core
        memory = 2048  # 2GB RAM
      }

      # Service registration
      service {
        name = "jupyter"
        port = "http"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.jupyter.entrypoints=websecure",
          "traefik.http.routers.jupyter.tls=true",
          "traefik.http.routers.jupyter.tls.certresolver=le",
        ]

        check {
          type     = "http"
          path     = "/api"
          interval = "10s"
          timeout  = "3s"
        }
      }
    }
    volume "jupyter" {
      type      = "host"
      read_only = false
      source    = "jupyter"
    }
  }
}
