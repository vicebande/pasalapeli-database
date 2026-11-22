# Main Terraform file for EKS migration
# Agrupa todos los recursos de la infraestructura AWS

provider "aws" {
  region = "us-east-1"
}

# Versión de Kubernetes
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}
