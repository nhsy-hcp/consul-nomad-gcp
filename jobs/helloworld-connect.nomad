job "helloworld" {
  node_pool = "default"
  type      = "service"

  group "helloworld" {
    count = 2

    network {
      mode = "bridge"
      port "expose" {}
    }

    service {
      name = "helloworld"
      port = 8080
      connect {
        sidecar_service {
          proxy {
            transparent_proxy {}
          }
        }
      }

      check {
        expose   = true
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",
        "traefik.http.routers.helloworld.entrypoints=websecure",
        "traefik.http.routers.helloworld.tls=true",
        "traefik.http.routers.helloworld.tls.certresolver=le",
      ]
    }

    task "java" {
      driver = "java"

      config {
        jar_path = "local/hello-world.jar"
        jvm_options = ["-Xmx512m", "-Xms128m"]
        args = [
          "--server.port=8080",
          "--spring.profiles.active=local",
        ]
      }

      artifact {
        source      = "https://github.com/cloudsoft/hello-world-spring-boot/releases/latest/download/hello-world.jar"
        destination = "local"
        options {
          checksum = "sha256:0c7e89d1f52d3fc2c5ded96f2d53bd2397119fdc70a3ffef81469a7516a81cc2"
        }
      }

      resources {
        cpu    = 100
        memory = 512
      }
    }
  }
}
