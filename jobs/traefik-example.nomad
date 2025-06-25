variable "consul_token" {
  type = string
}

variable "domain" {
  type = string
}

variable "letsencrypt_email" {
  type = string
}

job "traefik" {
  type = "service" #"system"
  node_pool = "default"

  group "server" {
    count = 1

    update {
      min_healthy_time  = "10s"
      healthy_deadline  = "10m"
      progress_deadline = "15m"
    }

    network {
      # mode = "bridge"
      port "http" {
        static = 80
      }
      port "https" {
        static = 443
      }
      port "https-8443" {
        static = 8443
      }
    }

    service {
      name = "traefik"
      # port = "http"

      # connect {
      #   sidecar_service {
      #     proxy {
      #       transparent_proxy {}
      #   }
      # }
      check {
        name            = "tcp-80-healthcheck"
        type            = "tcp"
        port            = "http"
        interval        = "10s"
        timeout         = "2s"
      }
      check {
        name            = "tcp-443-healthcheck"
        type            = "tcp"
        path            = "/"
        port            = "https"
        interval        = "10s"
        timeout         = "2s"
      }
      check {
        name            = "tcp-8443-healthcheck"
        type            = "tcp"
        path            = "/"
        port            = "https-8443"
        interval        = "10s"
        timeout         = "2s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v3"
       #  args   = [
       #    "--configfile=/local/traefik.toml",
       # ]
        network_mode = "host"
        ports = [
          "http",
          "https",
          "https-8443"
        ]
        volumes =[
          "local/traefik.toml:/etc/traefik/traefik.toml",
        ]
     }
      resources {
        cpu    = 500
        memory = 512
      }

      template {
        destination = "/local/traefik.toml"
        left_delimiter  = "[["
        right_delimiter = "]]"
        data        = <<-EOH
[api]
  dashboard = true

[certificatesResolvers.le.acme]
  caServer = "https://acme-staging-v02.api.letsencrypt.org/directory"
  email = "${var.letsencrypt_email}"
  keyType = "EC384"
  storage = "/local/acme/acme.json"
  [certificatesResolvers.le.acme.tlsChallenge]

[entryPoints]
  [entryPoints.web]
    address = ":80"
    [entryPoints.web.http.redirections.entryPoint]
      to = "websecure"
      scheme = "https"
  [entryPoints.websecure]
    address = ":443"
  [entryPoints.websecure-8443]
    address = ":8443"

[global]
  sendAnonymousUsage = false

[log]
  level = "DEBUG"

[providers]
  [providers.consulCatalog]
    exposedByDefault = false
    defaultRule = "Host(`{{ lower .Name }}.ingress.${var.domain}`)"
    [providers.consulCatalog.endpoint]
      address = "${var.domain}:8501"
      scheme = "https"
      token = "${var.consul_token}"
      [providers.consulCatalog.endpoint.tls]
        insecureSkipVerify = true
  [providers.file]
    directory = "/local/dynamic"
    watch = true

EOH
      }

      template {
        destination = "/local/dynamic/traefik_dynamic.toml"
        left_delimiter  = "[["
        right_delimiter = "]]"
        data        = <<-EOH
[tls.stores]
  [tls.stores.default.defaultGeneratedCert]
    resolver = "le"
    [tls.stores.default.defaultGeneratedCert.domain]
      main = "ingress.${var.domain}"

[http]
  [http.routers]
    [http.routers.dashboard]
      entryPoints = ["websecure-8443"]
      rule = "Host(`ingress.${var.domain}`) && (PathPrefix(`/dashboard`) || PathPrefix(`/api`))"
      service = "api@internal"
      [http.routers.dashboard.tls]
EOH
      }

      volume_mount {
        volume      = "traefik"
        destination = "/local/acme"
        read_only   = false
      }
    }

    # # claim the dynamic host volume for the allocation
    # volume "groupvol" {
    #   type            = "host"
    #   source          = "traefik-acme"
    #   access_mode     = "single-node-single-writer"
    #   attachment_mode = "file-system"
    # }
    volume "traefik" {
      type      = "host"
      read_only = false
      source    = "traefik"
    }
  }
}