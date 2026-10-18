#!/usr/bin/env bash
# ============================================================
# setup-messaging.sh - Recursos SNS/SQS de Pasa La Peli (aws CLI)
# Idempotente: re-ejecutable tras un "Stop Lab" del Learner Lab
# (mismos nombres -> mismos recursos, sin duplicados).
#
# Crea:
#   - Topic SNS:  pasalapeli-events
#   - Cola:       pasalapeli-notificaciones  (+ redrive a DLQ, max 3 intentos)
#   - DLQ:        pasalapeli-notificaciones-dlq (retencion 14 dias)
#   - Suscripcion SNS->SQS con FilterPolicy de tipos y RawMessageDelivery
#
# CERO recursos IAM (restriccion del AWS Academy Lab): usa las
# credenciales/rol existentes (LabRole) de la cuenta 513346712452.
#
# Uso:
#   export AWS_REGION=us-east-1   # por defecto si no esta definida
#   ./setup-messaging.sh
# ============================================================
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGION="$AWS_REGION"

TOPIC_NAME="pasalapeli-events"
QUEUE_NAME="pasalapeli-notificaciones"
DLQ_NAME="pasalapeli-notificaciones-dlq"

echo "== Pasa La Peli: provisionamiento SNS/SQS (region=$REGION, cuenta=$ACCOUNT_ID) =="

# ------------------------------------------------------------
# 1) Topic SNS (create-topic es idempotente: devuelve el ARN existente)
# ------------------------------------------------------------
TOPIC_ARN="$(aws sns create-topic --name "$TOPIC_NAME" --region "$REGION" --query TopicArn --output text)"
echo "[OK] Topic: $TOPIC_ARN"

# ------------------------------------------------------------
# 2) DLQ primero (la cola principal necesita su ARN para el redrive)
# ------------------------------------------------------------
DLQ_URL="$(aws sqs get-queue-url --queue-name "$DLQ_NAME" --region "$REGION" --query QueueUrl --output text 2>/dev/null || true)"
if [[ -z "$DLQ_URL" ]]; then
  DLQ_URL="$(aws sqs create-queue --queue-name "$DLQ_NAME" --region "$REGION" --query QueueUrl --output text)"
  echo "[OK] DLQ creada: $DLQ_URL"
else
  echo "[OK] DLQ ya existente: $DLQ_URL"
fi

aws sqs set-queue-attributes \
  --queue-url "$DLQ_URL" \
  --region "$REGION" \
  --attributes '{"MessageRetentionPeriod":"1209600"}'   # 14 dias
DLQ_ARN="$(aws sqs get-queue-attributes --queue-url "$DLQ_URL" --region "$REGION" \
  --attribute-names QueueArn --query Attributes.QueueArn --output text)"

# ------------------------------------------------------------
# 3) Cola principal + atributos (VisibilityTimeout 60 s, retencion 4 d,
#    redrive con maxReceiveCount=3 ~ los 3 reintentos previos de Rabbit)
# ------------------------------------------------------------
QUEUE_URL="$(aws sqs get-queue-url --queue-name "$QUEUE_NAME" --region "$REGION" --query QueueUrl --output text 2>/dev/null || true)"
if [[ -z "$QUEUE_URL" ]]; then
  QUEUE_URL="$(aws sqs create-queue --queue-name "$QUEUE_NAME" --region "$REGION" --query QueueUrl --output text)"
  echo "[OK] Cola creada: $QUEUE_URL"
else
  echo "[OK] Cola ya existente: $QUEUE_URL"
fi

aws sqs set-queue-attributes \
  --queue-url "$QUEUE_URL" \
  --region "$REGION" \
  --attributes "{
    \"VisibilityTimeout\": \"60\",
    \"MessageRetentionPeriod\": \"345600\",
    \"RedrivePolicy\": \"{\\\"deadLetterTargetArn\\\":\\\"$DLQ_ARN\\\",\\\"maxReceiveCount\\\":3}\"
  }"
QUEUE_ARN="$(aws sqs get-queue-attributes --queue-url "$QUEUE_URL" --region "$REGION" \
  --attribute-names QueueArn --query Attributes.QueueArn --output text)"

# Politica de la cola: permite a SNS (solo este topic) hacer SendMessage.
# Sin ella, SNS publica pero SQS descarta en silencio (denegacion implicita).
aws sqs set-queue-attributes \
  --queue-url "$QUEUE_URL" \
  --region "$REGION" \
  --attributes "{
    \"Policy\": \"{\\\"Version\\\":\\\"2012-10-17\\\",\\\"Statement\\\":[{\\\"Sid\\\":\\\"AllowSNSSendMessage\\\",\\\"Effect\\\":\\\"Allow\\\",\\\"Principal\\\":{\\\"Service\\\":\\\"sns.amazonaws.com\\\"},\\\"Action\\\":\\\"sqs:SendMessage\\\",\\\"Resource\\\":\\\"$QUEUE_ARN\\\",\\\"Condition\\\":{\\\"ArnEquals\\\":{\\\"aws:SourceArn\\\":\\\"$TOPIC_ARN\\\"}}}]}\"
  }"

# ------------------------------------------------------------
# 4) Suscripcion SNS -> SQS (idempotente: solo una por par topic/cola)
# ------------------------------------------------------------
SUB_ARN="$(aws sns list-subscriptions-by-topic --topic-arn "$TOPIC_ARN" --region "$REGION" \
  --query "Subscriptions[?Endpoint=='$QUEUE_ARN'].SubscriptionArn | [0]" --output text)"
if [[ -z "$SUB_ARN" || "$SUB_ARN" = "None" ]]; then
  SUB_ARN="$(aws sns subscribe \
    --topic-arn "$TOPIC_ARN" \
    --protocol sqs \
    --notification-endpoint "$QUEUE_ARN" \
    --region "$REGION" \
    --query SubscriptionArn --output text)"
  echo "[OK] Suscripcion creada: $SUB_ARN"
else
  echo "[OK] Suscripcion ya existente: $SUB_ARN"
fi

aws sns set-subscription-attributes \
  --subscription-arn "$SUB_ARN" \
  --attribute-name RawMessageDelivery \
  --attribute-value true \
  --region "$REGION"

aws sns set-subscription-attributes \
  --subscription-arn "$SUB_ARN" \
  --attribute-name FilterPolicy \
  --attribute-value '{"tipo":["PELICULA_CREADA","PELICULA_ELIMINADA","TICKET_PAGADO","TICKET_DEVUELTO"]}' \
  --region "$REGION"

# ------------------------------------------------------------
# 5) Export-ready para .env / compose / GitHub Secrets
# ------------------------------------------------------------
echo ""
echo "== Listo. Exporta estas variables en el .env de EC2-APPS =="
echo "export SNS_TOPIC_ARN=$TOPIC_ARN"
echo "export SQS_QUEUE_URL=$QUEUE_URL"
echo "export SQS_DLQ_URL=$DLQ_URL"
echo "export AWS_REGION=$REGION"
