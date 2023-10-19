### React App
resource "kubernetes_namespace" "react_app" {
  metadata {
    annotations = {
      name = "react-app"
    }

    labels = {
      istio-injection = "enabled"
    }

    name = "react-app"
  }
}

resource "tls_private_key" "react_app" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "react_app" {
  private_key_pem = tls_private_key.react_app.private_key_pem

  subject {
    common_name = local.react_app_domain_name
  }

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth"
  ]
}

resource "kubernetes_secret" "react_app_istio" {
  metadata {
    name      = "react-app-tls"
    namespace = kubernetes_namespace.istio_ingress.metadata[0].name
  }
  data = {
    "tls.crt" = tls_self_signed_cert.react_app.cert_pem
    "tls.key" = tls_private_key.react_app.private_key_pem
  }
  type = "kubernetes.io/tls"
}
