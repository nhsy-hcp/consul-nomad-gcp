# Generate letsencrypt TLS cert
resource "tls_private_key" "default" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "acme_registration" "default" {
  account_key_pem = tls_private_key.default.private_key_pem
  email_address   = var.letsencrypt_email
}

resource "acme_certificate" "default" {
  account_key_pem = acme_registration.default.account_key_pem
  common_name     = local.fqdn
  subject_alternative_names = [
    "*.${local.fqdn}"
  ]
  dns_challenge {
    provider = "gcloud"
    config = {
      GCE_PROJECT = var.gcp_project
    }
  }
  lifecycle {
    # Prevent destroy to reduce rate_limits exceeding
    prevent_destroy = false
  }
}
