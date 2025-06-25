job "helloworld" {
  node_pool = "default"
  type = "service"

  group "helloworld" {
    count = 1

    network {
      port "http" {}
    }

    task "java" {
      driver = "java"
      config {
        jar_path = "local/hello-world.jar"
        jvm_options = ["-Xmx512m", "-Xms128m"]
        args = [
          "--server.port=${NOMAD_PORT_http}",
          "--spring.profiles.active=local",
        ]
      }

      artifact {
        source = "https://github.com/cloudsoft/hello-world-spring-boot/releases/latest/download/hello-world.jar"
        destination = "local"
        options {
          checksum = "sha256:0c7e89d1f52d3fc2c5ded96f2d53bd2397119fdc70a3ffef81469a7516a81cc2"
        }
      }

      resources {
        cpu    = 100
        memory = 512
      }
      service {
        name = "helloworld"
        port = "http"

        check {
          type     = "http"
          port     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.helloworld.entrypoints=websecure",
          "traefik.http.routers.helloworld.tls=true",
          "traefik.http.routers.helloworld.tls.certresolver=le",
          "traefik.http.services.helloworld.loadbalancer.server.port=${NOMAD_PORT_http}",
        ]
      }
    }
  }
}

# job "helloworld" {
#   node_pool = "default"
#   type      = "service"
#
#   group "helloworld" {
#     count = 1
#
#     network {
#       port "http" {
#         to = 8080
#       }
#     }
#
#     service {
#       name = "helloworld"
#       port = "http"
#
#       check {
#         type     = "http"
#         port     = "http"
#         path     = "/"
#         interval = "10s"
#         timeout  = "2s"
#       }
#         tags = [
#           "traefik.enable=true",
#           "traefik.http.routers.helloworld.entrypoints=websecure",
#           "traefik.http.routers.helloworld.tls=true",
#           "traefik.http.routers.helloworld.tls.certresolver=le",
#         ]
#     }
#
#
#     task "java" {
#       driver = "docker"
#       config {
#         image   = "openjdk:19-jdk-slim"
#         command = "java"
#         args = [
#           "-jar",
#           "local/hello-world.jar",
#           "--server.port=${NOMAD_PORT_http}",
#           "--spring.profiles.active=local",
#         ]
#         ports = ["http"]
#       }
#
#       artifact {
#         source      = "https://github.com/cloudsoft/hello-world-spring-boot/releases/latest/download/hello-world.jar"
#         destination = "local"
#       }
#
#       resources {
#         cpu    = 100
#         memory = 256
#       }
#     }
#   }
# }