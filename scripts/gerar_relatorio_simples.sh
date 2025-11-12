#!/bin/bash
# ============================================================================
# GERADOR SIMPLES DE RELATÓRIO DE LEAD - CoreAdapt v4
# ============================================================================
# Script bash para gerar relatórios sem precisar de Node.js
# Usa psql para conectar direto no banco de dados
# ============================================================================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# CONFIGURAÇÃO - EDITE AQUI!
# ============================================================================

# Opção 1: Cole a URL de conexão completa do Supabase
# Formato: postgresql://postgres.abc123:[PASSWORD]@aws-0-us-east-1.pooler.supabase.com:6543/postgres
DATABASE_URL="${DATABASE_URL:-}"

# Opção 2: OU configure manualmente
DB_HOST="${DB_HOST:-}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-postgres}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-}"

# ============================================================================
# FUNÇÕES
# ============================================================================

print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

show_help() {
    cat << EOF
USO: $0 [OPÇÕES]

OPÇÕES:
    -i, --id <ID>           ID do contato no banco (obrigatório)
    -w, --whatsapp <NUM>    WhatsApp do contato (alternativa ao ID)
    -o, --output <FILE>     Arquivo de saída (padrão: relatorio_lead_<ID>.txt)
    -h, --help              Mostra esta ajuda

EXEMPLOS:
    # Gerar relatório do lead ID 123
    $0 --id 123

    # Gerar relatório e salvar em arquivo específico
    $0 --id 123 --output meu_relatorio.txt

    # Buscar por WhatsApp
    $0 --whatsapp "5585999855443@s.whatsapp.net"

CONFIGURAÇÃO:
    Configure as variáveis de ambiente antes de executar:

    export DATABASE_URL="postgresql://user:pass@host:5432/db"

    OU configure individualmente:

    export DB_HOST="host.supabase.co"
    export DB_PORT="5432"
    export DB_NAME="postgres"
    export DB_USER="postgres"
    export DB_PASSWORD="sua_senha"

EOF
}

check_dependencies() {
    if ! command -v psql &> /dev/null; then
        print_error "psql não está instalado!"
        echo ""
        echo "Instale o PostgreSQL client:"
        echo "  Ubuntu/Debian: sudo apt-get install postgresql-client"
        echo "  Mac: brew install postgresql"
        echo "  CentOS/RHEL: sudo yum install postgresql"
        exit 1
    fi
}

check_config() {
    if [ -z "$DATABASE_URL" ] && [ -z "$DB_HOST" ]; then
        print_error "Configuração de banco de dados não encontrada!"
        echo ""
        echo "Configure DATABASE_URL ou as variáveis DB_HOST, DB_USER, etc."
        echo "Veja --help para mais informações."
        exit 1
    fi
}

# ============================================================================
# PARSE DE ARGUMENTOS
# ============================================================================

CONTACT_ID=""
WHATSAPP=""
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--id)
            CONTACT_ID="$2"
            shift 2
            ;;
        -w|--whatsapp)
            WHATSAPP="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Opção desconhecida: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validação
if [ -z "$CONTACT_ID" ] && [ -z "$WHATSAPP" ]; then
    print_error "É necessário fornecer --id ou --whatsapp"
    show_help
    exit 1
fi

# ============================================================================
# MAIN
# ============================================================================

print_header "GERADOR DE RELATÓRIO DE LEAD"

# Verificar dependências
print_info "Verificando dependências..."
check_dependencies
print_success "psql encontrado"

# Verificar configuração
print_info "Verificando configuração..."
check_config
print_success "Configuração OK"

# Definir output file
if [ -z "$OUTPUT_FILE" ]; then
    if [ -n "$CONTACT_ID" ]; then
        OUTPUT_FILE="relatorio_lead_${CONTACT_ID}.txt"
    else
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        OUTPUT_FILE="relatorio_lead_${TIMESTAMP}.txt"
    fi
fi

# Caminho da query
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUERY_FILE="$SCRIPT_DIR/../queries/quick_lead_report.sql"

if [ ! -f "$QUERY_FILE" ]; then
    print_error "Arquivo de query não encontrado: $QUERY_FILE"
    exit 1
fi

print_info "Usando query: $QUERY_FILE"

# Ler query e substituir parâmetro
print_info "Preparando query..."
QUERY=$(cat "$QUERY_FILE")

if [ -n "$CONTACT_ID" ]; then
    QUERY="${QUERY//:contact_id/$CONTACT_ID}"
    print_info "Buscando lead com ID: $CONTACT_ID"
elif [ -n "$WHATSAPP" ]; then
    # Se for WhatsApp, substituir a condição WHERE
    QUERY="${QUERY//c.id = :contact_id/c.whatsapp = '$WHATSAPP'}"
    QUERY="${QUERY//ls.contact_id = :contact_id/ls.contact_id = (SELECT id FROM corev4_contacts WHERE whatsapp = '$WHATSAPP')}"
    QUERY="${QUERY//fe.contact_id = :contact_id/fe.contact_id = (SELECT id FROM corev4_contacts WHERE whatsapp = '$WHATSAPP')}"
    QUERY="${QUERY//sm.contact_id = :contact_id/sm.contact_id = (SELECT id FROM corev4_contacts WHERE whatsapp = '$WHATSAPP')}"
    QUERY="${QUERY//ch.contact_id = :contact_id/ch.contact_id = (SELECT id FROM corev4_contacts WHERE whatsapp = '$WHATSAPP')}"
    print_info "Buscando lead com WhatsApp: $WHATSAPP"
fi

# Executar query
print_info "Executando query..."

if [ -n "$DATABASE_URL" ]; then
    # Usar DATABASE_URL
    echo "$QUERY" | psql "$DATABASE_URL" > "$OUTPUT_FILE" 2>&1
else
    # Usar variáveis individuais
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -c "$QUERY" > "$OUTPUT_FILE" 2>&1
fi

# Verificar resultado
if [ $? -eq 0 ]; then
    print_success "Relatório gerado com sucesso!"
    print_info "Arquivo: $OUTPUT_FILE"

    # Mostrar tamanho do arquivo
    FILE_SIZE=$(wc -c < "$OUTPUT_FILE")
    print_info "Tamanho: ${FILE_SIZE} bytes"

    # Perguntar se quer abrir
    echo ""
    read -p "Deseja abrir o relatório agora? (s/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[SsYy]$ ]]; then
        if command -v less &> /dev/null; then
            less "$OUTPUT_FILE"
        elif command -v cat &> /dev/null; then
            cat "$OUTPUT_FILE"
        else
            print_warning "Não foi possível abrir o arquivo automaticamente"
            print_info "Abra manualmente: cat $OUTPUT_FILE"
        fi
    fi
else
    print_error "Erro ao gerar relatório!"
    print_info "Verifique o arquivo de erro: $OUTPUT_FILE"
    cat "$OUTPUT_FILE"
    exit 1
fi

echo ""
print_header "CONCLUÍDO"
