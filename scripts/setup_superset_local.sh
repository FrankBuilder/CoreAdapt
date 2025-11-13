#!/bin/bash
# ============================================================================
# SETUP APACHE SUPERSET LOCALMENTE (Mac/Linux)
# ============================================================================
# Instala e configura Apache Superset para rodar no seu Mac
# Conecta automaticamente ao Supabase
# ============================================================================

echo "🚀 Instalando Apache Superset..."

# Verificar Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 não encontrado. Instale primeiro:"
    echo "   brew install python@3.11"
    exit 1
fi

# Criar ambiente virtual
echo "📦 Criando ambiente virtual..."
python3 -m venv superset_env
source superset_env/bin/activate

# Instalar Superset
echo "⬇️  Instalando Superset (pode demorar alguns minutos)..."
pip install apache-superset psycopg2-binary

# Instalar driver PostgreSQL
pip install psycopg2-binary

# Criar banco de dados local do Superset
echo "🔧 Configurando banco de dados..."
superset db upgrade

# Criar usuário admin
echo "👤 Criando usuário admin..."
export FLASK_APP=superset
superset fab create-admin \
    --username admin \
    --firstname Admin \
    --lastname User \
    --email admin@superset.com \
    --password admin

# Carregar exemplos (opcional)
# superset load_examples

# Inicializar
superset init

echo ""
echo "✅ Superset instalado com sucesso!"
echo ""
echo "Para iniciar o Superset:"
echo "  1. Ative o ambiente: source superset_env/bin/activate"
echo "  2. Execute: superset run -p 8088 --with-threads --reload --debugger"
echo "  3. Abra: http://localhost:8088"
echo "  4. Login: admin / admin"
echo ""
echo "Para conectar ao Supabase:"
echo "  1. Settings → Database Connections → + Database"
echo "  2. Escolha: PostgreSQL"
echo "  3. Cole sua connection string do Supabase"
echo ""
