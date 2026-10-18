#!/usr/bin/env bash
# ============================================================
# Bootstrap del EC2 para "Pasa La Peli"
# Ejecutado por el workflow bootstrap.yml (o manualmente).
#
# Requiere las siguientes variables de entorno:
#   REPO_OWNER        (usuario/org de GitHub que contiene los repos)
#   MYSQL_ROOT_PASSWORD, SPRING_DATASOURCE_USERNAME, SPRING_DATASOURCE_PASSWORD
#   AZURE_AUTH_ENABLED, AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_APP_ID_URI
#   AZURE_AD_ISSUER_URI, AZURE_AD_JWK_SET_URI
#   SPRING_DATASOURCE_URL  (URL de la BDD externa EC2-BDD) opcional
#   CORS_ALLOWED_ORIGINS   (origen permitido del frontend, ej. https://peli.midominio.cl)
#   SNS_TOPIC_ARN, SQS_QUEUE_URL, SQS_DLQ_URL (salida de scripts/setup-messaging.sh)
#   AWS_REGION             (por defecto us-east-1)
#   DOMAIN            (dominio publico, ej. peli.midominio.cl) opcional
#   CERTBOT_EMAIL     (email para Let's Encrypt) opcional
#   FORCE_ENV         (true para sobrescribir .env existente) opcional
# ============================================================
set -euo pipefail

APP_DIR="/opt/pasalapeli"
REPOS=(pasalapeli-database pasalapeli-frontend pasalapeli-bff-service pasalapeli-movie-service pasalapeli-ticket-service pasalapeli-notification-service)
DOMAIN="${DOMAIN:-}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-}"
SPRING_DATASOURCE_URL="${SPRING_DATASOURCE_URL:-}"
CORS_ALLOWED_ORIGINS="${CORS_ALLOWED_ORIGINS:-*}"
REPO_OWNER="${REPO_OWNER:-}"

log() { echo "==> $*"; }

log "Instalando dependencias del sistema"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl git openssl nginx certbot python3-certbot-nginx cron

# El nginx del SO ocuparia los puertos 80/443; el frontend corre en contenedor.
sudo systemctl stop nginx 2>/dev/null || true
sudo systemctl disable nginx 2>/dev/null || true

if ! command -v docker >/dev/null 2>&1; then
  log "Instalando Docker Engine"
  curl --proto '=https' --proto-redir '=https' -fsSL https://get.docker.com | sudo sh
fi
sudo systemctl enable --now docker
sudo usermod -aG docker "$(whoami)"

log "Instalando plugin docker compose"
sudo mkdir -p /usr/local/lib/docker/cli-plugins
if [ ! -x /usr/local/lib/docker/cli-plugins/docker-compose ]; then
  sudo curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi
docker compose version

log "Preparando directorio de despliegue"
sudo mkdir -p "$APP_DIR" "$APP_DIR/certs"
sudo chown -R "$(whoami)" "$APP_DIR"

log "Clonando/actualizando repositorios"
if [ -n "$REPO_OWNER" ]; then
  for repo in "${REPOS[@]}"; do
    if [ -d "$APP_DIR/$repo/.git" ]; then
      (cd "$APP_DIR/$repo" && git fetch --prune origin && git reset --hard origin/main)
    else
      git clone "https://github.com/$REPO_OWNER/$repo.git" "$APP_DIR/$repo"
    fi
  done
fi

log "Generando .env (solo si no existe o FORCE_ENV=true)"
ENV_FILE="$APP_DIR/pasalapeli-database/.env"
if [ ! -s "$ENV_FILE" ] || [ "${FORCE_ENV:-false}" = "true" ]; then
  # Backup del .env previo antes de regenerar (facil de revertir si algo falla)
  [ -s "$ENV_FILE" ] && cp "$ENV_FILE" "$ENV_FILE.bak"
  cat > "$ENV_FILE" <<EOF
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-root}
MYSQL_DATABASE=pasalapeli_db
SPRING_DATASOURCE_USERNAME=${SPRING_DATASOURCE_USERNAME:-root}
SPRING_DATASOURCE_PASSWORD=${SPRING_DATASOURCE_PASSWORD:-root}
SPRING_DATASOURCE_URL=${SPRING_DATASOURCE_URL:-jdbc:mysql://mysql:3306/pasalapeli_db?createDatabaseIfNotExist=false&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC}

AZURE_AUTH_ENABLED=${AZURE_AUTH_ENABLED:-true}
AZURE_CLIENT_ID=${AZURE_CLIENT_ID:-00000000-0000-0000-0000-000000000000}
AZURE_TENANT_ID=${AZURE_TENANT_ID:-common}
AZURE_APP_ID_URI=${AZURE_APP_ID_URI:-api://00000000-0000-0000-0000-000000000000}
AZURE_AD_ISSUER_URI=${AZURE_AD_ISSUER_URI:-https://login.microsoftonline.com/common/v2.0}
AZURE_AD_JWK_SET_URI=${AZURE_AD_JWK_SET_URI:-https://login.microsoftonline.com/common/discovery/v2.0/keys}
INTERNAL_API_TOKEN=${INTERNAL_API_TOKEN:-dev-internal-token}

APP_BASE_URL=${APP_BASE_URL:-https://localhost}
CORS_ALLOWED_ORIGINS=${CORS_ALLOWED_ORIGINS:-*}

# --- Mensajeria asincrona (AWS SNS/SQS; provista por scripts/setup-messaging.sh) ---
AWS_REGION=${AWS_REGION:-us-east-1}
SNS_TOPIC_ARN=${SNS_TOPIC_ARN:-}
SQS_QUEUE_URL=${SQS_QUEUE_URL:-}
SQS_DLQ_URL=${SQS_DLQ_URL:-}
EOF
  chmod 600 "$ENV_FILE"
fi

# --- Migraciones SQL idempotentes (se ejecutan ANTES de tocar contenedores) ---
MIG_SQL="$APP_DIR/pasalapeli-database/migrations/002-parches.sql"
if [ -f "$MIG_SQL" ]; then
  DB_URL=$(grep -E '^SPRING_DATASOURCE_URL=' "$ENV_FILE" | head -1 | cut -d= -f2- || true)
  DB_USER=$(grep -E '^SPRING_DATASOURCE_USERNAME=' "$ENV_FILE" | head -1 | cut -d= -f2- || true)
  DB_PASS=$(grep -E '^SPRING_DATASOURCE_PASSWORD=' "$ENV_FILE" | head -1 | cut -d= -f2- || true)
  DB_HOST=$(printf '%s' "$DB_URL" | sed -E 's#^jdbc:mysql://([^:/?]+).*#\1#')
  if [ -n "$DB_URL" ] && [ -n "$DB_HOST" ] && [ "$DB_HOST" != "$DB_URL" ]; then
    log "Aplicando migraciones SQL idempotentes a $DB_HOST (usuario $DB_USER)"
    docker run --rm -i -e "MYSQL_PWD=$DB_PASS" mysql:8 \
      mysql -h"$DB_HOST" -u"$DB_USER" --default-character-set=utf8mb4 < "$MIG_SQL"
    log "Migraciones SQL aplicadas OK."
  else
    log "AVISO: SPRING_DATASOURCE_URL no valida; se omite migracion 002."
  fi
fi

if [ -n "$DOMAIN" ] && [ -n "$CERTBOT_EMAIL" ]; then
  log "Emitiendo certificado Let's Encrypt para $DOMAIN"
  if [ ! -s "$APP_DIR/certs/fullchain.pem" ]; then
    # Requiere puertos 80/443 libres -> se ejecuta ANTES de levantar el frontend
    sudo certbot certonly --standalone --non-interactive --agree-tos \
      -m "$CERTBOT_EMAIL" -d "$DOMAIN"
    sudo cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$APP_DIR/certs/fullchain.pem"
    sudo cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem"  "$APP_DIR/certs/privkey.pem"
    sudo chown "$(whoami)" "$APP_DIR/certs/"*
  fi
  log "Configurando renovacion automatica (cron 03:15 diario)"
  RENEW_SCRIPT="$APP_DIR/pasalapeli-database/scripts/renew-certs.sh"
  sudo bash "$RENEW_SCRIPT" install-cron "$DOMAIN" "$APP_DIR"
else
  log "Sin DOMAIN/CERTBOT_EMAIL: se genera certificado autofirmado (solo pruebas)."
  if [ ! -s "$APP_DIR/certs/fullchain.pem" ]; then
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
      -keyout "$APP_DIR/certs/privkey.pem" \
      -out "$APP_DIR/certs/fullchain.pem" \
      -subj "/CN=localhost"
    chmod 600 "$APP_DIR/certs/"*
  fi
  log "CORS_ALLOWED_ORIGINS queda configurado en EC2-APPS"
  sed -i "s|^CORS_ALLOWED_ORIGINS=.*|CORS_ALLOWED_ORIGINS=${CORS_ALLOWED_ORIGINS}|" "$ENV_FILE"
  sed -i 's|^APP_BASE_URL=.*|APP_BASE_URL=https://localhost|' "$ENV_FILE"
fi

log "Limpiando contenedores previos/huerfanos (evita conflictos de nombre con stacks antiguos)"
docker ps -aq --filter "name=pasalapeli" | xargs -r docker rm -f
# Limpieza explicita del contenedor RabbitMQ de versiones anteriores (ya no se usa)
docker rm -f pasalapeli-rabbitmq 2>/dev/null || true

log "Levantando el stack completo"
cd "$APP_DIR/pasalapeli-database"
docker compose up -d --build

log "Estado de los contenedores:"
docker compose ps

log "Esperando healthcheck de los servicios (hasta 180s)"
SERVICES=(pasalapeli-bff pasalapeli-movie pasalapeli-ticket pasalapeli-notification)
ALL_HEALTHY=0
for i in $(seq 1 36); do
  ALL_HEALTHY=1
  for c in "${SERVICES[@]}"; do
    STATUS=$(docker inspect --format '{{.State.Health.Status}}' "$c" 2>/dev/null || echo "starting")
    [ "$STATUS" = "healthy" ] || ALL_HEALTHY=0
  done
  if [ "$ALL_HEALTHY" = "1" ]; then
    log "Todos los servicios healthy (iteracion $i)."
    break
  fi
  sleep 5
done
if [ "$ALL_HEALTHY" != "1" ]; then
  log "ERROR: los servicios no quedaron healthy tras 180s."
  log "Revise la conectividad a MySQL (<IP_BDD>:3306), el secret SPRING_DATASOURCE_URL"
  log "y las variables SNS_TOPIC_ARN/SQS_QUEUE_URL (ejecutar scripts/setup-messaging.sh)."
  docker compose logs --tail=50 bff-service movie-service ticket-service notification-service || true
  exit 1
fi

log "Bootstrap finalizado."