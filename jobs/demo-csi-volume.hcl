id        = "demo"
namespace = "default"
name      = "demo"
type      = "csi"
region    = "europe-west1"
plugin_id = "gce-pd"

# For 'nomad volume create', specify a snapshot ID or volume to clone. You can
# specify only one of these two fields.
#snapshot_id = "snap-12345"
# clone_id    = "vol-abcdef"

# Optional: for 'nomad volume create', specify a maximum and minimum capacity.
# Registering an existing volume will record but ignore these fields.
capacity_min = "1GiB"
capacity_max = "5GiB"

# Required (at least one): for 'nomad volume create', specify one or more
# capabilities to validate. Registering an existing volume will record but
# ignore these fields.
capability {
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}

# Optional: for 'nomad volume create', specify mount options to validate for
# 'attachment_mode = "file-system". Registering an existing volume will record
# but ignore these fields.
mount_options {
  fs_type     = "xfs"
  mount_flags = ["rw"]
}

parameters {
  type = "pd-balanced"
  replication-type = "regional-pd"
}

topology_request {
  required {
    topology {
      segments {
        "topology.gke.io/zone" = "europe-west1-b"
      }
    }
    topology {
      segments {
        "topology.gke.io/zone" = "europe-west1-c"
      }
    }
  }
}
