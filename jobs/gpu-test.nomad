job "gpu-test" {
  type = "batch"
  node_pool = "gpu"

  group "smi" {
    task "smi" {
      driver = "docker"

      config {
        image = "nvidia/cuda:12.8.1-base-ubuntu22.04"
        command = "bash"
        args    = ["-c", "nvidia-smi; sleep 300"]
      }

      resources {
        device "nvidia/gpu" {
          count = 1
        }
      }
    }
  }
}
