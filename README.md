# pasalapeli-database (Orquestador)

Repositorio orquestador de **Pasa La Peli**. Contiene:

- `docker-compose.yml` — define los 5 servicios del stack (MySQL, Movie, Ticket, BFF, Frontend)
- `init.sql` — script de creación de la base de datos `pasalapeli_db` con datos de prueba
- `scripts/bootstrap-ec2.sh` — setup completo de EC2 desde cero (Docker, repos, certificados, deploy)
- `scripts/renew-certs.sh` — renovación automática de certificados Let's Encrypt
- `.env.example` — plantilla de variables de entorno

## Despliegue con GitHub Actions

### Prerequisitos

1. Crear la instancia **EC2 Ubuntu 24.04** con Security Group que abra los puertos **22, 80, 443**.
2. Registrar los **GitHub Secrets** en este repo:

| Secret | Descripción |
|---|---|
| `EC2_HOST` | IP pública del EC2 |
| `EC2_USER` | Usuario SSH (usualmente `ubuntu`) |
| `EC2_SSH_KEY` | Clave privada SSH (.pem) |

3. Registrar las **GitHub Variables** (Settings → Variables → Actions):

| Variable | Descripción |
|---|---|
| `EC2_DOMAIN` | Dominio apuntando al EC2 (ej. `peli.midominio.cl`) |
| `CERTBOT_EMAIL` | Email para certificados Let's Encrypt |

### Primer despliegue (bootstrap)

1. Clonar localmente este repositorio
2. Copiar `.env.example` como `.env` y ajustar las variables
3. Hacer `git push` a `main` → el workflow `bootstrap.yml` ejecuta todo en el EC2
4. Verificar: `ssh ubuntu@EC2 "docker compose -f /opt/pasalapeli/pasalapeli-database/docker-compose.yml ps"`

### Desarrollo local

```bash
# Solo MySQL:
docker compose up -d mysql
docker compose -f docker-compose.yml up mysql    # o con docker normal

# Stack completo (requiere que los repos hermanos existan como dirs ../pasalapeli-*)
docker compose up -d --build
```
