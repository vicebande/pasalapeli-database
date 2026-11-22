#!/usr/bin/env bash
# =============================================================================
# deploy-streaming.sh — Provisiona la arquitectura de streaming de Pasa La Peli
# con AWS CloudFormation (idempotente).
#
#   Stack 1: pasalapeli-streaming-kinesis  -> stream-ventas + stream-security-logs
#   Stack 2: pasalapeli-streaming-siem     -> OpenSearch + Firehose + S3 + IAM
#
# Uso:
#   ./scripts/deploy-streaming.sh              # despliega ambos stacks
#   ./scripts/deploy-streaming.sh kinesis      # solo el stack de Kinesis
#   ./scripts/deploy-streaming.sh siem         # solo el stack SIEM
#
# Requiere: AWS CLI v2 con credenciales (perfil default o AWS_*).
# Variables opcionales: AWS_REGION (por defecto us-east-1).
# =============================================================================
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CF_DIR="${SCRIPT_DIR}/../cloudformation"
TARGET="${1:-all}"

deploy_stack() {
  local name="$1" template="$2"
  echo ">>> Desplegando stack ${name} (${template}, región ${REGION})"
  aws cloudformation deploy \
    --region "${REGION}" \
    --stack-name "${name}" \
    --template-file "${template}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --no-fail-on-empty-changeset
  echo ">>> Stack ${name}: OK"
}

print_outputs() {
  local name="$1"
  echo "--- Outputs de ${name} ---"
  aws cloudformation describe-stacks \
    --region "${REGION}" \
    --stack-name "${name}" \
    --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' \
    --output table || true
}

case "${TARGET}" in
  kinesis)
    deploy_stack "pasalapeli-streaming-kinesis" "${CF_DIR}/streaming-kinesis.yml"
    print_outputs "pasalapeli-streaming-kinesis"
    ;;
  siem)
    deploy_stack "pasalapeli-streaming-siem" "${CF_DIR}/streaming-siem.yml"
    print_outputs "pasalapeli-streaming-siem"
    ;;
  all)
    deploy_stack "pasalapeli-streaming-kinesis" "${CF_DIR}/streaming-kinesis.yml"
    print_outputs "pasalapeli-streaming-kinesis"
    deploy_stack "pasalapeli-streaming-siem" "${CF_DIR}/streaming-siem.yml"
    print_outputs "pasalapeli-streaming-siem"
    ;;
  *)
    echo "Uso: $0 [kinesis|siem|all]" >&2
    exit 2
    ;;
esac

echo ">>> Deploy de streaming completado."
