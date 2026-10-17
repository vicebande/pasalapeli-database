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
# ============================================================
set -euo pipefail

APP_DIR="/opt/pasalapeli"
REPO_OWNER="${REPO_OWNER:-}"
DOMAIN="${DOMAIN:-}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-}"

log() { echo "==> $*"; }

log "Instalando dependencias del sistema"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl git openssl

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
sudo mkdir -p "$APP_DIR"
sudo chown -R "$(whoami)" "$APP_DIR"

log "Clonando/actualizando repositorios (database + frontend)"
if [ -n "$REPO_OWNER" ]; then
  for repo in pasalapeli-database pasalapeli-frontend; do
    if [ -d "$APP_DIR/$repo/.git" ]; then
      (cd "$APP_DIR/$repo" && git pull --ff-only origin main)
    else
      git clone "https://github.com/$REPO_OWNER/$repo.git" "$APP_DIR/$repo"
    fi
  done
fi

CERT_DIR="$APP_DIR/pasalapeli-database/certs"
mkdir -p "$CERT_DIR"

log "Generando certificado HTTPS"
if [ ! -s "$CERT_DIR/fullchain.pem" ]; then
  if [ -n "$DOMAIN" ] && [ -n "$CERTBOT_EMAIL" ]; then
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
sudo chown -R "$(whoami)" "$CERT_DIR"

log "Bootstrap de EC2-WEB finalizado."