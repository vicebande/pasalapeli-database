# pasalapeli-database (Infraestructura compartida AWS)

Repositorio propietario de la **infraestructura compartida** de Pasa La Peli en AWS (Cloud Native). Despliega, vía Terraform + GitHub Actions:

- **VPC**: `10.0.0.0/16`, 2 subnets públicas (frontend/ALB) + 2 subnets privadas (backend/BBDD), Internet Gateway, NAT Gateway, route tables.
- **Security Groups**: `frontend-sg` (HTTP/HTTPS 0.0.0.0/0), `backend-sg` (desde frontend SG + MySQL desde privadas), `db-sg` (desde backend SG en 3306), `eks-sg` (cluster EKS).
- **EKS Cluster**: `pasalapeli-cluster` (K8s 1.28, endpoint privado, logging de control plane habilitado, node group `pasalapeli-workers` en subnets privadas).
- **ECR Repository**: `pasalapeli-images` (imágenes Docker de todos los microservicios, escaneo en push, tags inmutables).
- **RDS MySQL 8.0**: `pasalapeli-db` (db.t3.micro, subnets privadas, SG aislado, cifrado, backup 7 días, password generado aleatoriamente).
- **S3**: `pasalapeli-tfstate` (estado Terraform, versionado + cifrado), `pasalapeli-website-static`, `pasalapeli-uploads`.
- **SNS + SQS**: topic `pasalapeli-events`, cola `pasalapeli-events-queue` (24h retención) con suscripción SQS→SNS.
- **Kinesis**: `pasalapeli-metrics-stream` (1 shard, 24h retención).

## Despliegue CI/CD (GitHub Actions → Terraform → EKS)

Este repo **se despliega primero** (crea el bucket de estado de Terraform y el cluster EKS que los demás servicios consumen).

Workflow `.github/workflows/deploy.yml` en cada `push` a `main`:
1. Quality Gate: SonarCloud (bloquea si falla).
2. Terraform Init: backend S3 `pasalapeli-tfstate` (`pasalapeli-database/terraform.tfstate`).
3. Terraform Format / Validate / Plan.
4. Terraform Apply (`-auto-approve`, solo en `main`).

### GitHub Secrets requeridos
| Secret | Descripción |
|---|---|
| `AWS_ACCESS_KEY_ID` | Credencial AWS con permisos sobre EKS, RDS, S3, IAM, ECR, SNS, SQS, Kinesis |
| `AWS_SECRET_ACCESS_KEY` | Secreto asociado |
| `AWS_SESSION_TOKEN` | Token de sesión (si se usan credenciales temporales STS) |
| `SONAR_TOKEN` | Token de SonarCloud |
| `SONAR_HOST_URL` | `https://sonarcloud.io` |

### Orden de despliegue recomendado
1. `pasalapeli-database` (infra compartida — **primero**)
2. Los demás servicios (`frontend`, `movie-service`, `notification-service`, `bff-service`, `ticket-service`) en cualquier orden.

### Variables de entorno (terraform)
- `TF_VAR_environment_name` = `dev` (por defecto)
- `TF_VAR_domain_name` = `pasalapeli-database`
