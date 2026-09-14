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
#   AWS_S3_ENABLED, AWS_S3_BUCKET, AWS_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
#   SPRING_DATASOURCE_URL  (URL de la BDD externa EC2-BDD) opcional
#   CORS_ALLOWED_ORIGINS   (origen permitido del frontend, ej. https://peli.midominio.cl)
#   DOMAIN            (dominio publico, ej. peli.midominio.cl) opcional
#   CERTBOT_EMAIL     (email para Let's Encrypt) opcional
#   FORCE_ENV         (true para sobrescribir .env existente) opcional
# ============================================================
set -euo pipefail

APP_DIR="/opt/pasalapeli"
REPOS=(pasalapeli-database pasalapeli-frontend pasalapeli-bff-service pasalapeli-movie-service pasalapeli-ticket-service)
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
  curl -fsSL https://get.docker.com | sudo sh
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
      (cd "$APP_DIR/$repo" && git pull --ff-only origin main)
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

AZURE_AUTH_ENABLED=${AZURE_AUTH_ENABLED:-false}
AZURE_CLIENT_ID=${AZURE_CLIENT_ID:-00000000-0000-0000-0000-000000000000}
AZURE_TENANT_ID=${AZURE_TENANT_ID:-common}
AZURE_APP_ID_URI=${AZURE_APP_ID_URI:-api://00000000-0000-0000-0000-000000000000}
AZURE_AD_ISSUER_URI=${AZURE_AD_ISSUER_URI:-https://login.microsoftonline.com/common/v2.0}
AZURE_AD_JWK_SET_URI=${AZURE_AD_JWK_SET_URI:-https://login.microsoftonline.com/common/discovery/v2.0/keys}

APP_BASE_URL=${APP_BASE_URL:-https://localhost}
CORS_ALLOWED_ORIGINS=${CORS_ALLOWED_ORIGINS:-*}

AWS_S3_ENABLED=${AWS_S3_ENABLED:-false}
AWS_S3_BUCKET=${AWS_S3_BUCKET:-pasalapeli-portadas}
AWS_REGION=${AWS_REGION:-us-east-1}
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-}
EOF
  chmod 600 "$ENV_FILE"
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

log "Levantando el stack completo"
cd "$APP_DIR/pasalapeli-database"
docker compose up -d --build

log "Estado de los contenedores:"
docker compose ps

log "Esperando healthcheck de los servicios (hasta 180s)"
SERVICES=(pasalapeli-bff pasalapeli-movie pasalapeli-ticket)
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
  log "Revise la conectividad a MySQL (<IP_BDD>:3306) y el secret SPRING_DATASOURCE_URL."
  docker compose logs --tail=50 bff-service movie-service ticket-service || true
  exit 1
fi

log "Bootstrap finalizado."