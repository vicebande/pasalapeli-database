# pasalapeli-database (Orquestador)

Repositorio orquestador de **Pasa La Peli**. Contiene:

- `docker-compose.yml` — stack backend para **EC2-APPS**: `rabbitmq` (broker de mensajería), `movie`, `ticket`, `notification` y `bff`
- `docker-compose.web.yml` — stack para **EC2-WEB**: solo el `frontend` (nginx + HTTPS)
- `init.sql` — script de creación de la base de datos `pasalapeli_db` (9 tablas: Usuario, Pelicula, Funcion, Ticket, Pago, Notificacion, DestinoNotificacion, ReglaDistribucion, MensajeFallido) con datos de prueba
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
# Solo MySQL (la BDD en producción es EC2-BDD nativo, no contenedor):
docker run -d -p 3306:3306 -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=pasalapeli_db mysql:8

# Broker de mensajería (RabbitMQ) para probar notificaciones asincrónicas:
docker run -d -p 5672:5672 -p 15672:15672 \
  -e RABBITMQ_DEFAULT_USER=pasalapeli -e RABBITMQ_DEFAULT_PASS=pasalapeli123 \
  rabbitmq:3.13-management-alpine

# Stack completo en EC2-APPS (requiere que los repos hermanos existan como dirs ../pasalapeli-*)
docker compose up -d --build

# Frontend en EC2-WEB
docker compose -f docker-compose.web.yml up -d --build
```
