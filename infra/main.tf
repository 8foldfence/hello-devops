# INFRASTRUCTURE AS CODE: one `terraform apply` builds the whole platform on your laptop:
#   - a Kubernetes cluster (kind, running inside Docker)
#   - Argo CD (deployments)
#   - Prometheus + Grafana + Alertmanager (monitoring)

terraform {
  required_version = ">= 1.5"
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.6"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}

resource "kind_cluster" "this" {
  name           = "hello-devops"
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
      # Website NodePort 30080 -> http://localhost:8080 on your laptop
      extra_port_mappings {
        container_port = 30080
        host_port      = 8080
      }
    }
  }
}

provider "helm" {
  kubernetes {
    host                   = kind_cluster.this.endpoint
    client_certificate     = kind_cluster.this.client_certificate
    client_key             = kind_cluster.this.client_key
    cluster_ca_certificate = kind_cluster.this.cluster_ca_certificate
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }
}

resource "helm_release" "monitoring" {
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 600

  values = [file("${path.module}/monitoring-values.yaml")]
}

output "next_steps" {
  value = <<-EOT
    Cluster ready. Now run:  make deploy
    Website:  http://localhost:8080
    Argo CD:  make argocd   -> http://localhost:8081
    Grafana:  make grafana  -> http://localhost:3000  (admin / admin)
  EOT
}
