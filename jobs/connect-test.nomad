job "connect-test" {
  type = "service"
  group "test" {
    count = 1
    network {
      mode = "bridge"
      port "http" {
        to = 8080
      }
    }
    service {
      name = "connect-test"
      port = "http"
      connect {
        sidecar_service {}
      }
    }
    task "web" {
      driver = "docker"
      config {
        image = "curlimages/curl:latest"
         args  = ["tail", "-f", "/dev/null"]
      }
      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}
