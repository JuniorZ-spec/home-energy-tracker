#!/usr/bin/env bash
set -euo pipefail

ACR_REGISTRY="${ACR_REGISTRY:-}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
AZURE_VM_HOST="${AZURE_VM_HOST:-}"
SSH_USER="${SSH_USER:-azureuser}"
APP_DIR="/home/${SSH_USER}/app"

if [[ -z "$ACR_REGISTRY" || -z "$AZURE_VM_HOST" ]]; then
  echo "Usage: ACR_REGISTRY=<registry> AZURE_VM_HOST=<host> IMAGE_TAG=<tag> SSH_USER=<user> ./scripts/deploy-azure-vm.sh"
  exit 1
fi

ssh -o StrictHostKeyChecking=no "$SSH_USER@$AZURE_VM_HOST" "mkdir -p $APP_DIR && cd $APP_DIR && printf 'ACR_REGISTRY=%s\nIMAGE_TAG=%s\n' '$ACR_REGISTRY' '$IMAGE_TAG' > .env"
scp -o StrictHostKeyChecking=no docker-compose.prod.yml "$SSH_USER@$AZURE_VM_HOST:$APP_DIR/docker-compose.yml"
ssh -o StrictHostKeyChecking=no "$SSH_USER@$AZURE_VM_HOST" "cd $APP_DIR && docker compose pull && docker compose up -d"
