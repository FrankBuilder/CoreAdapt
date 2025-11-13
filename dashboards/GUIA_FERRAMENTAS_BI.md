# 📊 Guia Completo de Ferramentas BI para CoreAdapt v4

## 🎯 Comparativo de Custos (Mensal)

| Ferramenta | Self-Hosted | Cloud Gerenciado | Facilidade | Visual |
|------------|-------------|------------------|------------|--------|
| **Apache Superset** | 💰 **$0-10** (Railway/Render) | 💰 **$20-100** (Preset) | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Redash** | 💰 **$0-10** | 💰 **$49-99** (Redash Cloud) | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Grafana** | 💰 **$0** | 💰 **$0-50** (Grafana Cloud) | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Evidence.dev** | 💰 **$0** (Vercel) | 💰 **$20** (Evidence Cloud) | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Metabase** | 💰 **$10-20** | 💰 **$85+** (Metabase Cloud) | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **PowerBI** | N/A | 💰 **$10-20/usuário** | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Tableau** | N/A | 💰 **$70+/usuário** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

---

## 🏆 Recomendação por Caso de Uso

### 1. **Dashboards Executivos (C-Level)**
**Use:** Superset ou Grafana
- Visual profissional
- KPIs destacados
- Atualização em tempo real

### 2. **Análise de Dados (você mesmo)**
**Use:** Redash
- SQL direto
- Fácil e rápido
- Queries parametrizadas

### 3. **Monitoramento em Tempo Real**
**Use:** Grafana
- Alertas automáticos
- Métricas ao vivo
- Mobile-friendly

### 4. **Dashboard Embedado no App**
**Use:** Cube.js + React
- API própria
- Customização total
- Performance

### 5. **Apresentação para Clientes**
**Use:** Superset (HTML export)
- Exporta PDF
- Visual limpo
- Profissional

---

## 🚀 Setup Detalhado

---

## 1️⃣ Apache Superset (Recomendado!)

### Opção A: Railway.app (Mais Fácil)

**Custo:** ~$5-10/mês

**Passo 1:** Criar conta no Railway
```
https://railway.app
```

**Passo 2:** Deploy template Superset
1. Vá para: https://railway.app/template/superset
2. Clique "Deploy Now"
3. Aguarde 5 minutos

**Passo 3:** Configurar
1. Clique no serviço Superset
2. Settings → Generate Domain
3. Acesse a URL gerada
4. Login: `admin` / senha que você configurou

**Passo 4:** Conectar Supabase
1. No Superset: Settings → Database Connections → + Database
2. Escolha: PostgreSQL
3. Connection String:
```
postgresql://postgres.abcxyz:[PASSWORD]@aws-0-us-east-1.pooler.supabase.com:6543/postgres?sslmode=require
```
4. Test Connection
5. Save

**Passo 5:** Criar Primeiro Dashboard
1. SQL Lab → SQL Editor
2. Cole uma query de `queries_para_superset.sql`
3. Run Query
4. Clique "Create Chart"
5. Escolha tipo de gráfico
6. Clique "Save & go to Dashboard"

**Pronto!** 🎉

---

### Opção B: Local no Mac (Grátis)

**Pré-requisitos:**
- Python 3.9+
- PostgreSQL client libs

**Instalação:**
```bash
cd ~/CoreAdapt

# Executar script de instalação
./scripts/setup_superset_local.sh

# Ou manualmente:
python3 -m venv superset_env
source superset_env/bin/activate
pip install apache-superset psycopg2-binary

# Configurar
superset db upgrade
export FLASK_APP=superset
superset fab create-admin \
    --username admin \
    --firstname Admin \
    --lastname User \
    --email admin@superset.com \
    --password admin

superset init

# Iniciar
superset run -p 8088 --with-threads
```

**Acessar:**
```
http://localhost:8088
Login: admin / admin
```

---

## 2️⃣ Redash

### Opção A: Redash Cloud (Mais Fácil)

**Custo:** $49/mês (plano básico)

**Setup:**
1. Vá para: https://redash.io/signup
2. Crie conta
3. Data Sources → New Data Source → PostgreSQL
4. Cole connection string do Supabase
5. Test Connection → Save

**Criar Query:**
1. Create → Query
2. Cole SQL de `queries_para_superset.sql`
3. Execute
4. Clique em "New Visualization"
5. Escolha tipo de gráfico
6. Adicione ao Dashboard

---

### Opção B: Self-Hosted no Railway

**Custo:** ~$7/mês

**Setup:**
1. Fork: https://github.com/getredash/redash
2. Deploy no Railway:
   - New Project → Deploy from GitHub
   - Escolha o fork do Redash
   - Aguarde deploy

---

## 3️⃣ Grafana

### Opção A: Grafana Cloud (Grátis até 10k séries)

**Custo:** $0-50/mês

**Setup:**
1. Vá para: https://grafana.com/auth/sign-up
2. Crie conta no Grafana Cloud
3. Connections → Data Sources → Add PostgreSQL
4. Configure:
```
Host: aws-0-us-east-1.pooler.supabase.com:6543
Database: postgres
User: postgres.abcxyz
Password: [SUA_SENHA]
SSL Mode: require
```
5. Save & Test

**Criar Dashboard:**
1. Dashboards → New Dashboard → Add Visualization
2. Query Editor → Code (SQL)
3. Cole query SQL
4. Run Query
5. Escolha tipo de visualização
6. Save Dashboard

---

### Opção B: Local no Mac

**Instalação:**
```bash
# Via Homebrew
brew install grafana

# Iniciar
brew services start grafana

# Acessar
# http://localhost:3000
# Login: admin / admin
```

---

## 4️⃣ Evidence.dev (Moderno!)

**Custo:** $0 (Vercel) ou $20/mês (Evidence Cloud)

**Setup Local:**
```bash
# Instalar
npm install -g @evidence-dev/cli

# Criar projeto
npx degit evidence-dev/template my-dashboard
cd my-dashboard
npm install

# Configurar Supabase
# Edite: sources/supabase.md
# Cole connection string

# Desenvolver
npm run dev

# Deploy no Vercel (grátis!)
npm run build
vercel
```

**Criar Dashboard:**

Edite `pages/index.md`:

```markdown
# Dashboard CoreAdapt

## Total de Leads

```sql leads_totais
SELECT
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE is_active = true) as ativos,
    COUNT(*) FILTER (WHERE opt_out = true) as opt_outs
FROM corev4_contacts
```

<BigValue data={leads_totais} value=total />

## ANUM Médio por Mês

```sql anum_mensal
SELECT
    DATE_TRUNC('month', analyzed_at) as mes,
    AVG(total_score) as anum_medio
FROM corev4_lead_state
WHERE analyzed_at >= NOW() - INTERVAL '6 months'
GROUP BY mes
ORDER BY mes
```

<LineChart data={anum_mensal} x=mes y=anum_medio />
```

**Super legal!** Dashboards como código! 🚀

---

## 📊 Exemplos de Dashboards

### Dashboard 1: Visão Executiva

**KPIs Principais:**
- Total de Leads (Big Number)
- ANUM Médio (Gauge Chart)
- Taxa de Conversão (%)
- Reuniões Agendadas (Counter)

**Gráficos:**
- Leads por Mês (Line Chart)
- ANUM por Estágio (Bar Chart)
- Origem de Leads (Pie Chart)
- Funil de Conversão (Funnel)

**Query Base:**
```sql
-- Ver arquivo: dashboards/queries_para_superset.sql
-- Query #1, #2, #3, #4
```

---

### Dashboard 2: Performance de Follow-ups

**Métricas:**
- Taxa de Execução por Passo
- Leads Reengajados
- Campanhas Ativas vs Paradas
- Motivos de Parada

**Gráficos:**
- Follow-ups por Passo (Stacked Bar)
- Taxa de Resposta (Line Chart)
- Razões de Parada (Pie Chart)

**Query Base:**
```sql
-- Ver: queries_para_superset.sql
-- Query #5, #6, #14
```

---

### Dashboard 3: Análise Financeira

**Métricas:**
- Custo Total (USD)
- Custo por Lead
- Tokens Consumidos
- ROI por Campanha UTM

**Gráficos:**
- Custo ao Longo do Tempo (Area Chart)
- Top 10 Leads Mais Caros (Table)
- Custo vs ANUM (Scatter Plot)

**Query Base:**
```sql
-- Ver: queries_para_superset.sql
-- Query #10, #12
```

---

## 🎨 Dicas de Design

### 1. Paleta de Cores para ANUM

```
Pre-qualified (<30):    #FF4136 (vermelho)
Developing (30-69):     #FF851B (laranja)
Qualified (70-84):      #2ECC40 (verde)
Highly Qualified (85+): #0074D9 (azul)
```

### 2. KPIs Essenciais

**Sempre mostrar:**
- Total de Leads Ativos
- ANUM Médio Geral
- Taxa de Qualificação (%)
- Reuniões Este Mês

### 3. Atualização

**Tempo Real:**
- Grafana (1min)
- Superset (5min cache)
- Redash (manual ou scheduled)

---

## 💡 Receitas Prontas

### Receita 1: Dashboard em 10 Minutos (Superset)

```bash
# 1. Deploy no Railway (2 min)
https://railway.app/template/superset

# 2. Conectar Supabase (1 min)
Settings → Databases → Add PostgreSQL

# 3. Copiar 5 queries (2 min)
SQL Lab → Cole queries do arquivo queries_para_superset.sql

# 4. Criar visualizações (3 min)
Explore → Escolher gráficos

# 5. Montar dashboard (2 min)
Dashboards → Add Charts
```

**Total: 10 minutos!** ⚡

---

### Receita 2: Dashboard Grátis com Evidence

```bash
# 1. Criar projeto (1 min)
npx degit evidence-dev/template dashboard-coreadapt
cd dashboard-coreadapt
npm install

# 2. Configurar Supabase (2 min)
# Editar sources/supabase.md com connection string

# 3. Copiar queries para pages/ (3 min)
# Criar páginas .md com SQL inline

# 4. Deploy no Vercel (2 min)
npm run build
vercel --prod

# 5. Compartilhar URL (0 min)
```

**Total: 8 minutos! Grátis!** 🎉

---

## 🔒 Segurança

### Boas Práticas:

1. **Connection String:**
   - Use variáveis de ambiente
   - Nunca commite no Git
   - Use SSL (`sslmode=require`)

2. **Credenciais:**
   - Crie usuário read-only no Supabase
   - Restrinja acesso por IP (se possível)
   - Ative 2FA no BI tool

3. **Dashboards:**
   - Controle quem pode ver/editar
   - Não exponha dados sensíveis
   - Use Row Level Security (RLS) no Supabase

---

## 📞 Próximos Passos

1. **Testar Superset:**
   - Deploy no Railway (10min)
   - Conectar Supabase
   - Criar primeiro dashboard

2. **Explorar Queries:**
   - Abrir `queries_para_superset.sql`
   - Testar no Supabase SQL Editor
   - Adaptar para suas necessidades

3. **Compartilhar:**
   - Exportar dashboards como PDF
   - Criar relatórios agendados
   - Embedar no seu site

---

## 🎯 Resumo Final

### Para Começar HOJE:
1. **Deploy Superset no Railway** (~10min, $5/mês)
2. **Conectar Supabase**
3. **Copiar queries prontas**
4. **Criar 3-5 visualizações**
5. **Montar primeiro dashboard**

### Alternativa Grátis:
1. **Evidence.dev + Vercel** (grátis!)
2. Dashboards como código
3. Deploy automático via Git

### Se Quiser Investir:
- **Superset Preset Cloud** ($20/mês) - Gerenciado, sem manutenção
- **Metabase Cloud** ($85/mês) - Mais fácil, mas caro
- **Grafana Cloud** ($0-50/mês) - Melhor para tempo real

---

**Recomendação:** Comece com **Superset no Railway** ($5/mês). Se gostar e quiser facilidade, migre para **Preset** ($20/mês). Se quiser grátis, use **Evidence.dev + Vercel**.

Bora criar dashboards lindos! 🚀📊
