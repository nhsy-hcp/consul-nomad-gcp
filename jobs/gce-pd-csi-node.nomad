job "gce-pd-csi-node" {
  type = "system"
  group "node" {
    restart {
      attempts = 0
      interval = "10m"
      delay    = "15s"
      mode     = "fail"
    }

    task "plugin" {
      driver = "docker"


      config {
        image = "gcr.io/gke-release/gcp-compute-persistent-disk-csi-driver:v1.20.2-gke.0"
        args = [
            "-endpoint=unix:///csi/csi.sock",
            "-v=6",
            "-logtostderr",
            "-run-controller-service=false",
            "--node-name=${node.unique.name}"
        ]
        privileged = true
      }

      csi_plugin {
          id        = "gce-pd"
          type      = "node"
          mount_dir = "/csi"
      }

      resources {
        memory = 256
      }
    }
  }
}

