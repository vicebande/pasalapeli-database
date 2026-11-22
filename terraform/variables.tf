variable "environment_name" {
  description = "Nombre del entorno (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "domain_name" {
  description = "Dominio de la aplicación"
  type        = string
  default     = "$repo"
}
