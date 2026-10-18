#!/usr/bin/env bash
# ============================================================
# Bootstrap del EC2-WEB para "Pasa La Peli"
# Ejecutado por el workflow deploy.yml del repo pasalapeli-frontend.
# Prepara EC2-WEB de forma automatica (sin pasos manuales):
#   1) instala Docker Engine + plugin compose
#   2) clona/actualiza los repos necesario para el compose web
#   3) genera el certificado HTTPS (Let's Encrypt si hay DOMAIN +
#      CERTBOT_EMAIL, si no autofirmado) en database/certs/
#
# Requiere las siguientes variables de entorno:
#   REPO_OWNER        (usuario/org de GitHub que contiene los repos)
#   DOMAIN            (dominio publico, ej. peli.midominio.cl) opcional
#   CERTBOT_EMAIL     (email para Let's Encrypt) opcional
#   EC2_APPS_HOST     (IP privada de EC2-APPS, desde vars de GitHub) opcional
#   APP_BASE_URL      (URL base del frontend, desde vars de GitHub) opcional
# ============================================================
set -euo pipefail

APP_DIR="/opt/pasalapeli"
REPO_OWNER="${REPO_OWNER:-}"
DOMAIN="${DOMAIN:-}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-}"
EC2_APPS_HOST="${EC2_APPS_HOST:-}"
APP_BASE_URL="${APP_BASE_URL:-}"

log() { echo "==> $*"; }

# Upsert KEY=VALUE en .env (sin duplicar). Asi la config vive en las
# Variables de GitHub y viaja aqui; no se edita el .env a mano en la EC2.
env_upsert() {
  local file="$1" key="$2" val="$3"
  [[ -z "$val" ]] && return 0
  if grep -q "^${key}=" "$file" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${val}|" "$file"
  else
    printf '%s=%s\n' "$key" "$val" >> "$file"
  fi
}

log "Instalando dependencias del sistema"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl git openssl

if ! command -v docker >/dev/null 2>&1; then
  log "Instalando Docker Engine"
  curl --proto '=https' --proto-redir '=https' -fsSL https://get.docker.com | sudo sh
fi
sudo systemctl enable --now docker
sudo usermod -aG docker "$(whoami)"

log "Instalando plugin docker compose"
sudo mkdir -p /usr/local/lib/docker/cli-plugins
if [[ ! -x /usr/local/lib/docker/cli-plugins/docker-compose ]]; then
  sudo curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi
docker compose version

log "Preparando directorio de despliegue"
sudo mkdir -p "$APP_DIR"
sudo chown -R "$(whoami)" "$APP_DIR"

log "Clonando/actualizando repositorios (database + frontend)"
if [[ -n "$REPO_OWNER" ]]; then
  for repo in pasalapeli-database pasalapeli-frontend; do
    if [[ -d "$APP_DIR/$repo/.git" ]]; then
      (cd "$APP_DIR/$repo" && git fetch --prune origin && git reset --hard origin/main)
    else
      git clone "https://github.com/$REPO_OWNER/$repo.git" "$APP_DIR/$repo"
    fi
  done
fi

CERT_DIR="$APP_DIR/pasalapeli-database/certs"
mkdir -p "$CERT_DIR"

log "Generando certificado HTTPS"
if [[ ! -s "$CERT_DIR/fullchain.pem" ]]; then
  if [[ -n "$DOMAIN" && -n "$CERTBOT_EMAIL" ]]; then
    log "Opcion Let's Encrypt para $DOMAIN (se ejecuta ANTES de levantar el contenedor)"
    sudo apt-get install -y certbot
    sudo certbot certonly --standalone --non-interactive --agree-tos \
      -m "$CERTBOT_EMAIL" -d "$DOMAIN"
    sudo cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$CERT_DIR/fullchain.pem"
    sudo cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem"  "$CERT_DIR/privkey.pem"
    log "Configurando renovacion automatica (cron 03:15 diario)"
    sudo bash "$APP_DIR/pasalapeli-database/scripts/renew-certs.sh" install-cron "$DOMAIN" "$APP_DIR"
  else
    log "Sin DOMAIN/CERTBOT_EMAIL: certificado autofirmado (solo pruebas)."
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
      -keyout "$CERT_DIR/privkey.pem" \
      -out "$CERT_DIR/fullchain.pem" \
      -subj "/CN=localhost"
  fi
fi
# nginx corre como uid 101 (unprivileged): necesita lectura world en los certs
sudo chown -R "$(whoami)" "$CERT_DIR"
sudo chmod 644 "$CERT_DIR/fullchain.pem" "$CERT_DIR/privkey.pem"

ENV_FILE="$APP_DIR/pasalapeli-database/.env"
log "Escribiendo config de GitHub en .env (EC2_APPS_HOST/APP_BASE_URL)"
[[ -f "$ENV_FILE" ]] || touch "$ENV_FILE"
env_upsert "$ENV_FILE" EC2_APPS_HOST "$EC2_APPS_HOST"
env_upsert "$ENV_FILE" APP_BASE_URL "$APP_BASE_URL"
grep -E '^(EC2_APPS_HOST|APP_BASE_URL)=' "$ENV_FILE" || true

log "Bootstrap de EC2-WEB finalizado."