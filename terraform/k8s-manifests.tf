# Kubernetes Manifests for microservicios

# Frontend Deployment
resource "kubernetes_deployment" "frontend" {
  metadata {
    name      = "pasalapeli-frontend"
    namespace = "default"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "pasalapeli-frontend"
      }
    }

    template_label = "app = pasalapeli-frontend"

    container {
      image = "${aws_ecr_repository.frontend.repository_url}/frontend:latest"
      name    = "frontend"

      ports {
        container_port = 80
      }

      env {
        name = "ENVIRONMENT"
        value = var.environment_name
      }
    }
  }
}

# Frontend Service
resource "kubernetes_service" "frontend" {
  metadata {
    name      = "pasalapeli-frontend-service"
    namespace = "default"
  }

  spec {
    selector = kubernetes_deployment.frontend.metadata[0].labels.app

    port {
      port = 80
      target_port = 80
    }

    type = LoadBalancer
  }
}

# RDS Service Exposition (internal)
resource "kubernetes_service" "db" {
  metadata {
    name      = "pasalapeli-db-service"
    namespace = "default"
  }

  spec {
    selector = kubernetes_deployment.frontend.metadata[0].labels.app

    port {
      port = 3306
      target_port = 3306
    }

    type = ClusterIP
  }
}
