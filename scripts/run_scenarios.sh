#!/usr/bin/env bash
# Script de automação de cenários de teste de carga e erro para Elastic Stack

set -e

echo "=========================================================="
echo "  SIMULADOR DE CENÁRIOS DE LOGS - ELASTIC STACK (EFK/ELK) "
echo "=========================================================="
echo ""

python3 --version > /dev/null 2>&1 || { echo "Erro: Python 3 é necessário."; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIMULATOR="${SCRIPT_DIR}/simulate_logs.py"

show_menu() {
    echo "Escolha o cenário de teste a ser executado:"
    echo "1) Cenário Normal / Baseline (2 logs/s por 30s)"
    echo "2) Cenário de Carga Elevada / Stress Test (50 logs/s por 15s)"
    echo "3) Cenário de Surto de Erros / Error Spike (15 logs/s por 20s - ideal para validação de Alertas)"
    echo "4) Executar Teste Completo (Sequencial de todos os cenários)"
    echo "5) Sair"
    echo ""
}

run_normal() {
    echo ">>> Executando Cenário 1: Baseline Normal..."
    python3 "${SIMULATOR}" --mode normal --rate 2 --duration 30
    echo ">>> Cenário 1 Concluído!"
    echo ""
}

run_burst() {
    echo ">>> Executando Cenário 2: Carga Elevada (Stress Test)..."
    python3 "${SIMULATOR}" --mode burst --rate 50 --duration 15
    echo ">>> Cenário 2 Concluído!"
    echo ""
}

run_error_spike() {
    echo ">>> Executando Cenário 3: Surto de Erros (Validar Alertas)..."
    python3 "${SIMULATOR}" --mode error-spike --rate 15 --duration 20
    echo ">>> Cenário 3 Concluído!"
    echo ""
}

if [ "$1" != "" ]; then
    case "$1" in
        normal) run_normal ;;
        burst) run_burst ;;
        error-spike) run_error_spike ;;
        all) run_normal; run_burst; run_error_spike ;;
        *) echo "Uso: $0 {normal|burst|error-spike|all}"; exit 1 ;;
    esac
    exit 0
fi

show_menu
read -p "Opção [1-5]: " CHOICE

case $CHOICE in
    1) run_normal ;;
    2) run_burst ;;
    3) run_error_spike ;;
    4) run_normal; run_burst; run_error_spike ;;
    5) echo "Saindo..."; exit 0 ;;
    *) echo "Opção inválida."; exit 1 ;;
esac
