#!/usr/bin/env bash
# ==============================================================================
# Setup Inicial para Observabilidade (Elastic Stack) na VPS
# Executar como root ou com sudo
# ==============================================================================

set -euo pipefail

echo "=========================================================="
echo "    PREPARAÇÃO DA VPS PARA STACK DE OBSERVABILIDADE       "
echo "=========================================================="

DEPLOY_PATH="${1:-/opt/observability}"
DOCKER_NETWORK="${2:-app-network}"

echo ">>> 1. Configurando parâmetros de memória do Kernel para o Elasticsearch..."
CURRENT_MAP=$(sysctl -n vm.max_map_count 2>/dev/null || echo 0)
if [ "$CURRENT_MAP" -lt 262144 ]; then
    echo "Ajustando vm.max_map_count para 262144..."
    sudo sysctl -w vm.max_map_count=262144
    echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/99-elasticsearch.conf > /dev/null
    sudo sysctl --system > /dev/null
    echo "✅ vm.max_map_count atualizado e persistido com sucesso."
else
    echo "✅ vm.max_map_count já está configurado ($CURRENT_MAP >= 262144)."
fi

echo ">>> 2. Verificando Docker e Docker Compose..."
if ! command -v docker > /dev/null 2>&1; then
    echo "❌ Docker não encontrado! Instale o Docker antes de prosseguir."
    exit 1
fi
echo "Docker versão: $(docker --version)"

if ! docker compose version > /dev/null 2>&1; then
    echo "❌ docker compose (v2) não encontrado! Verifique a instalação."
    exit 1
fi
echo "Docker Compose versão: $(docker compose version)"

echo ">>> 3. Criando rede Docker compartilhada ('$DOCKER_NETWORK')..."
if ! docker network inspect "$DOCKER_NETWORK" > /dev/null 2>&1; then
    docker network create "$DOCKER_NETWORK"
    echo "✅ Rede Docker '$DOCKER_NETWORK' criada com sucesso."
else
    echo "✅ Rede Docker '$DOCKER_NETWORK' já existe."
fi

echo ">>> 4. Criando diretório de deploy ($DEPLOY_PATH)..."
sudo mkdir -p "$DEPLOY_PATH"
sudo chown -R "$(whoami)":"$(whoami)" "$DEPLOY_PATH" 2>/dev/null || true
echo "✅ Diretório $DEPLOY_PATH preparado."

echo ""
echo "=========================================================="
echo "✅ Setup concluído! A VPS está pronta para receber o deploy."
echo "=========================================================="
