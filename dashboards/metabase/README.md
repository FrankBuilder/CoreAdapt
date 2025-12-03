# Dashboards Metabase - CoreAdapt v4

## Estrutura de Dashboards para Demonstração

Este guia contém dashboards prontos para demonstração do CoreAdapt para clientes,
especificamente configurados para o tenant **CoreConnect** (robô Frank).

## Dashboards Disponíveis

### 1. Dashboard Executivo (`01_executivo.sql`)
**Público:** C-Level, Gestores de Vendas
**KPIs principais:**
- Funil de leads (total → qualificados → reuniões)
- Score ANUM médio e distribuição
- Tendência de novos leads
- Taxa de conversão

### 2. Dashboard de Operações (`02_operacoes.sql`)
**Público:** Time de Vendas, SDRs
**KPIs principais:**
- Campanhas de follow-up ativas
- Reuniões agendadas (próximos 7 dias)
- Leads por estágio de qualificação
- Top leads por score ANUM

### 3. Dashboard Financeiro/Custos (`03_custos_llm.sql`)
**Público:** Financeiro, Gestão de Produto
**KPIs principais:**
- Custo total LLM (USD)
- Custo por modelo
- Custo por lead
- Tendência de custos

### 4. Dashboard de Engajamento (`04_engajamento.sql`)
**Público:** Customer Success, Marketing
**KPIs principais:**
- Volume de mensagens
- Taxa de resposta
- Leads reengajados
- Categorias de dor

## Configuração no Metabase

### Passo 1: Conectar ao Banco de Dados
1. Admin → Databases → Add Database
2. Selecionar "PostgreSQL"
3. Configurar conexão Supabase:
   - Host: `db.xxxxx.supabase.co`
   - Port: `5432`
   - Database: `postgres`
   - Username: `postgres`
   - Password: `[sua-senha]`

### Passo 2: Criar as Perguntas (Questions)
1. New → SQL Query
2. Copiar a query do arquivo `.sql` correspondente
3. Salvar com nome descritivo
4. Selecionar visualização apropriada

### Passo 3: Montar os Dashboards
1. New → Dashboard
2. Adicionar as perguntas salvas
3. Organizar layout
4. Adicionar filtros globais (data)

## Filtro por Tenant

Todas as queries incluem filtro `WHERE company_id = 1` para CoreConnect.
Para outros tenants, ajuste o `company_id` conforme necessário.

### Filtro Dinâmico (Opcional)
Para criar filtro de empresa dinâmico no Metabase:
```sql
WHERE company_id = {{company_id}}
```
E criar uma variável do tipo "Field Filter" apontando para `corev4_companies.id`.

## Arquivos

```
metabase/
├── README.md                    # Este arquivo
├── 01_executivo.sql             # Dashboard Executivo (8 queries)
├── 02_operacoes.sql             # Dashboard de Operações (8 queries)
├── 03_custos_llm.sql            # Dashboard de Custos (6 queries)
├── 04_engajamento.sql           # Dashboard de Engajamento (6 queries)
└── 05_demonstracao_completa.sql # Todas as queries em um arquivo
```

## Tipos de Visualização Recomendados

| Query | Tipo de Gráfico | Notas |
|-------|-----------------|-------|
| KPI único | Number | Grande, destaque |
| Distribuição | Pie/Donut | Máximo 6-8 categorias |
| Tendência | Line | Com área preenchida |
| Comparação | Bar (horizontal) | Para categorias |
| Funil | Funnel | Progressão de etapas |
| Lista | Table | Top 10 leads |
| Progresso | Progress Bar | Campanhas |

## Cores Sugeridas (CoreConnect)

```
Primária: #2563EB (Azul)
Secundária: #10B981 (Verde)
Alerta: #F59E0B (Amarelo)
Crítico: #EF4444 (Vermelho)
Neutro: #6B7280 (Cinza)
```

---

**Última atualização:** 2025-12-03
**Versão:** CoreAdapt v4.1
