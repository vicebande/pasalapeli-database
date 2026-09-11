#!/usr/bin/env bash
# ============================================================
# Renovacion de certificados Let's Encrypt para el frontend.
#
# Uso:
#   renew-certs.sh renew DOMAIN APP_DIR   -> renueva y recarga
#   renew-certs.sh install-cron DOMAIN APP_DIR -> instala cron 03:15
# ============================================================
set -euo pipefail

MODE="${1:-renew}"
DOMAIN="${2:-}"
APP_DIR="${3:-/opt/pasalapeli}"

if [ "$MODE" = "install-cron" ]; then
  echo "==> Instalando cron de renovacion para $DOMAIN"
  CRON_LINE="15 3 * * * $APP_DIR/pasalapeli-database/scripts/renew-certs.sh renew $DOMAIN $APP_DIR >> /var/log/certbot-renew.log 2>&1"
  ( crontab -l 2>/dev/null | grep -v "renew-certs.sh" || true; echo "$CRON_LINE" ) | crontab -
  echo "==> Cron instalado."
  exit 0
fi

if [ -z "$DOMAIN" ]; then
  echo "ERROR: DOMAIN requerido" >&2
  exit 1
fi

COMPOSE_DIR="$APP_DIR/pasalapeli-database"
CERT_DIR="$APP_DIR/certs"

echo "==> Deteniendo frontend para liberar puertos 80/443"
docker compose -f "$COMPOSE_DIR/docker-compose.yml" stop frontend

set +e
echo "==> Ejecutando certbot renew (standalone)"
sudo certbot renew --cert-name "$DOMAIN" --standalone --non-interactive
RENEW_RC=$?
set -e
# certbot devuelve 1 cuando el certificado no vence aun; no es un error fatal.
if [ "$RENEW_RC" -ne 0 ] && [ "$RENEW_RC" -ne 1 ]; then
  echo "ERROR: certbot renew fallo (rc=$RENEW_RC)" >&2
fi

echo "==> Copiando certificados actualizados"
sudo cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$CERT_DIR/fullchain.pem"
sudo cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem"  "$CERT_DIR/privkey.pem"
sudo chown "$(whoami)" "$CERT_DIR/"*

echo "==> Re-iniciando frontend"
docker compose -f "$COMPOSE_DIR/docker-compose.yml" up -d frontend

echo "==> Renovacion finalizada."