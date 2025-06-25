job "echoserver" {
  type = "service"
  node_pool = "default"

  group "echoserver" {
    count = 2

    network {
      # mode = "bridge"
      port "http" {
        to = 8080
      }
    }

    service {
      name     = "echoserver"
      # connect {
      #   sidecar_service {
      #     proxy {
      #       transparent_proxy {}
      #   }
      # }
      port     = "http"
      check {
        name     = "http"
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "3s"
      }

      tags = [
        "traefik.enable=true",
        # "traefik.consulcatalog.connect=true",
        "traefik.http.routers.echoserver.entrypoints=websecure",
        "traefik.http.routers.echoserver.tls=true",
        "traefik.http.routers.echoserver.tls.certresolver=le",
      ]
    }

    # Tasks are individual units of work that are run by Nomad.
    task "server" {
      # This particular task starts a simple web server within a Docker container
      driver = "docker"

      config {
        image   = "gcr.io/google_containers/echoserver:1.10"
        ports   = ["http"]
      }

      # Specify the maximum resources required to run the task
      resources {
        cpu    = 50
        memory = 64
      }
    }
  }
}