# Guia de Implementação — Looker Studio para CoreAdapt

**Versão:** 1.0
**Data:** 2025-12-26
**Objetivo:** Implementar dashboards de analytics para clientes CoreAdapt usando Google Looker Studio (grátis)

---

## Sumário

1. [Visão Geral](#1-visão-geral)
2. [Pré-requisitos](#2-pré-requisitos)
3. [Configuração do Supabase](#3-configuração-do-supabase)
4. [Conectando Looker Studio ao Supabase](#4-conectando-looker-studio-ao-supabase)
5. [Criando os Dashboards](#5-criando-os-dashboards)
6. [Multi-tenancy (Separação por Cliente)](#6-multi-tenancy-separação-por-cliente)
7. [Compartilhamento e Embedding](#7-compartilhamento-e-embedding)
8. [Manutenção e Boas Práticas](#8-manutenção-e-boas-práticas)

---

## 1. Visão Geral

### Por que Looker Studio?

| Vantagem | Descrição |
|----------|-----------|
| **Custo Zero** | 100% gratuito, sem limites de usuários |
| **Fácil de Usar** | Interface drag-and-drop, sem código |
| **Integração Google** | Funciona com toda suite Google |
| **PostgreSQL Nativo** | Conecta direto ao Supabase |
| **Compartilhamento** | Links, embed, PDF, email agendado |
| **Mobile** | Dashboards responsivos |

### Arquitetura Final

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      COREADAPT ANALYTICS ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌──────────────┐      ┌──────────────┐      ┌──────────────┐             │
│   │   SUPABASE   │      │    VIEWS     │      │   LOOKER     │             │
│   │  PostgreSQL  │─────▶│  Agregadas   │─────▶│   STUDIO     │             │
│   │              │      │              │      │              │             │
│   └──────────────┘      └──────────────┘      └──────────────┘             │
│         │                                            │                      │
│         │                                            ▼                      │
│         │                                    ┌──────────────┐               │
│         │                                    │   CLIENTE    │               │
│         │                                    │  (Browser)   │               │
│         │                                    └──────────────┘               │
│         │                                            ▲                      │
│         │                                            │                      │
│         ▼                                            │                      │
│   ┌──────────────┐                           ┌──────────────┐               │
│   │   n8n FLOWS  │                           │   PORTAL     │               │
│   │ (Alimentam   │                           │  COREADAPT   │               │
│   │   dados)     │                           │  (Embed)     │               │
│   └──────────────┘                           └──────────────┘               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Pré-requisitos

### Checklist

- [ ] Conta Google (Gmail ou Workspace)
- [ ] Acesso ao Supabase com credenciais
- [ ] Tabelas do CoreAdapt criadas no banco
- [ ] IP do Looker Studio liberado no Supabase (se necessário)

### Informações Necessárias do Supabase

```
Host:     db.XXXXXXXXXXXXX.supabase.co
Port:     5432
Database: postgres
Username: postgres
Password: [sua senha do projeto Supabase]
```

**Onde encontrar:**
1. Acesse https://supabase.com/dashboard
2. Selecione seu projeto
3. Vá em Settings → Database
4. Copie as credenciais de "Connection string"

---

## 3. Configuração do Supabase

### 3.1 Liberar Acesso Externo (se necessário)

Por padrão, Supabase permite conexões externas. Mas verifique:

1. **Supabase Dashboard** → Settings → Database
2. Em "Connection Pooling", verifique se está habilitado
3. Use a porta `6543` para pooling (recomendado) ou `5432` para conexão direta

### 3.2 Criar Views de Analytics

Execute no SQL Editor do Supabase:

```sql
-- ============================================
-- VIEWS PARA LOOKER STUDIO - COREADAPT
-- Execute este script no Supabase SQL Editor
-- ============================================

-- ---------------------------------------------
-- VIEW 1: Funil de Conversão Geral
-- ---------------------------------------------
CREATE OR REPLACE VIEW vw_analytics_funil AS
SELECT
    e.id as empresa_id,
    e.name as empresa,
    DATE_TRUNC('day', p.created_at)::date as data,
    COUNT(DISTINCT p.id) as total_prospects,
    COUNT(DISTINCT CASE
        WHEN p.status IN ('contacted', 'engaged', 'qualified', 'converted')
        THEN p.id
    END) as contatados,
    COUNT(DISTINCT CASE
        WHEN p.status IN ('engaged', 'qualified', 'converted')
        THEN p.id
    END) as engajados,
    COUNT(DISTINCT CASE
        WHEN p.status IN ('qualified', 'converted')
        THEN p.id
    END) as qualificados,
    COUNT(DISTINCT CASE
        WHEN p.status = 'converted'
        THEN p.id
    END) as convertidos
FROM corev4_prospects p
JOIN corev4_empresas e ON p.empresa_id = e.id
WHERE p.created_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY e.id, e.name, DATE_TRUNC('day', p.created_at)::date
ORDER BY data DESC;

-- ---------------------------------------------
-- VIEW 2: Métricas de Campanhas Outbound
-- ---------------------------------------------
CREATE OR REPLACE VIEW vw_analytics_campanhas AS
SELECT
    e.id as empresa_id,
    e.name as empresa,
    c.id as campanha_id,
    c.name as campanha,
    c.status as campanha_status,
    DATE_TRUNC('day', ce.executed_at)::date as data,
    COUNT(ce.id) as total_envios,
    SUM(CASE WHEN ce.delivery_status = 'delivered' THEN 1 ELSE 0 END) as entregues,
    SUM(CASE WHEN ce.delivery_status = 'failed' THEN 1 ELSE 0 END) as falharam,
    SUM(CASE WHEN ce.response_type = 'opt_in' THEN 1 ELSE 0 END) as opt_ins,
    SUM(CASE WHEN ce.response_type = 'opt_out' THEN 1 ELSE 0 END) as opt_outs,
    SUM(CASE WHEN ce.response_type = 'ignored' THEN 1 ELSE 0 END) as ignorados,
    ROUND(
        100.0 * SUM(CASE WHEN ce.delivery_status = 'delivered' THEN 1 ELSE 0 END) /
        NULLIF(COUNT(ce.id), 0),
        2
    ) as taxa_entrega_pct,
    ROUND(
        100.0 * SUM(CASE WHEN ce.response_type = 'opt_in' THEN 1 ELSE 0 END) /
        NULLIF(COUNT(ce.id), 0),
        2
    ) as taxa_engajamento_pct,
    ROUND(
        100.0 * SUM(CASE WHEN ce.response_type = 'opt_out' THEN 1 ELSE 0 END) /
        NULLIF(COUNT(ce.id), 0),
        2
    ) as taxa_optout_pct
FROM corev4_campaign_executions ce
JOIN corev4_outbound_campaigns c ON ce.campaign_id = c.id
JOIN corev4_empresas e ON c.empresa_id = e.id
WHERE ce.executed_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY e.id, e.name, c.id, c.name, c.status, DATE_TRUNC('day', ce.executed_at)::date
ORDER BY data DESC;

-- ---------------------------------------------
-- VIEW 3: Warmup Status
-- ---------------------------------------------
CREATE OR REPLACE VIEW vw_analytics_warmup AS
SELECT
    e.id as empresa_id,
    e.name as empresa,
    w.phone_number,
    w.current_daily_limit,
    w.max_daily_limit,
    w.warmup_day,
    w.total_days,
    w.status as warmup_status,
    ROUND(100.0 * w.warmup_day / NULLIF(w.total_days, 0), 0) as progresso_pct,
    w.health_score,
    w.last_send_at,
    w.created_at as warmup_iniciado
FROM corev4_warmup_status w
JOIN corev4_empresas e ON w.empresa_id = e.id
WHERE w.status != 'completed';

-- ---------------------------------------------
-- VIEW 4: Qualificação ANUM
-- ---------------------------------------------
CREATE OR REPLACE VIEW vw_analytics_qualificacao AS
SELECT
    e.id as empresa_id,
    e.name as empresa,
    l.id as lead_id,
    l.name as lead_nome,
    l.phone as lead_telefone,
    qr.authority_score,
    qr.need_score,
    qr.urgency_score,
    qr.money_score,
    qr.total_score,
    CASE
        WHEN qr.total_score >= 80 THEN 'Hot'
        WHEN qr.total_score >= 50 THEN 'Warm'
        ELSE 'Cold'
    END as temperatura,
    qr.qualification_status,
    qr.disqualification_reason,
    qr.created_at as qualificado_em
FROM corev4_qualification_results qr
JOIN corev4_leads l ON qr.lead_id = l.id
JOIN corev4_empresas e ON l.empresa_id = e.id
WHERE qr.created_at >= CURRENT_DATE - INTERVAL '90 days'
ORDER BY qr.created_at DESC;

-- ---------------------------------------------
-- VIEW 5: Agendamentos e Reuniões
-- ---------------------------------------------
CREATE OR REPLACE VIEW vw_analytics_agendamentos AS
SELECT
    e.id as empresa_id,
    e.name as empresa,
    m.id as meeting_id,
    l.name as lead_nome,
    l.company as lead_empresa,
    m.scheduled_at,
    DATE_TRUNC('day', m.scheduled_at)::date as data_reuniao,
    EXTRACT(DOW FROM m.scheduled_at) as dia_semana,
    EXTRACT(HOUR FROM m.scheduled_at) as hora,
    m.confirmed,
    m.reminder_sent,
    m.attended,
    CASE
        WHEN m.attended = true THEN 'Compareceu'
        WHEN m.attended = false AND m.scheduled_at < NOW() THEN 'No-show'
        WHEN m.confirmed = true THEN 'Confirmado'
        ELSE 'Pendente'
    END as status_reuniao,
    m.meeting_link,
    m.created_at as agendado_em
FROM corev4_meetings m
JOIN corev4_leads l ON m.lead_id = l.id
JOIN corev4_empresas e ON m.empresa_id = e.id
WHERE m.scheduled_at >= CURRENT_DATE - INTERVAL '90 days'
ORDER BY m.scheduled_at DESC;

-- ---------------------------------------------
-- VIEW 6: Métricas Diárias Consolidadas
-- ---------------------------------------------
CREATE OR REPLACE VIEW vw_analytics_diario AS
SELECT
    e.id as empresa_id,
    e.name as empresa,
    d.date as data,
    -- Prospecção
    d.prospects_created,
    d.prospects_contacted,
    d.messages_sent,
    d.messages_delivered,
    d.opt_ins,
    d.opt_outs,
    -- Qualificação
    d.conversations_started,
    d.conversations_completed,
    d.leads_qualified,
    d.leads_disqualified,
    -- Agendamento
    d.meetings_scheduled,
    d.meetings_confirmed,
    d.meetings_attended,
    d.meetings_no_show,
    -- Calculados
    CASE WHEN d.messages_sent > 0
        THEN ROUND(100.0 * d.messages_delivered / d.messages_sent, 2)
        ELSE 0
    END as taxa_entrega_pct,
    CASE WHEN d.messages_delivered > 0
        THEN ROUND(100.0 * d.opt_ins / d.messages_delivered, 2)
        ELSE 0
    END as taxa_engajamento_pct,
    CASE WHEN d.meetings_scheduled > 0
        THEN ROUND(100.0 * d.meetings_attended / d.meetings_scheduled, 2)
        ELSE 0
    END as taxa_comparecimento_pct
FROM corev4_daily_metrics d
JOIN corev4_empresas e ON d.empresa_id = e.id
WHERE d.date >= CURRENT_DATE - INTERVAL '90 days'
ORDER BY d.date DESC;

-- ---------------------------------------------
-- VIEW 7: Resumo Executivo (Últimos 30 dias)
-- ---------------------------------------------
CREATE OR REPLACE VIEW vw_analytics_resumo_executivo AS
SELECT
    e.id as empresa_id,
    e.name as empresa,
    -- Totais
    COALESCE(SUM(d.prospects_created), 0) as total_prospects,
    COALESCE(SUM(d.prospects_contacted), 0) as total_contatados,
    COALESCE(SUM(d.opt_ins), 0) as total_engajados,
    COALESCE(SUM(d.leads_qualified), 0) as total_qualificados,
    COALESCE(SUM(d.meetings_scheduled), 0) as total_agendamentos,
    COALESCE(SUM(d.meetings_attended), 0) as total_compareceram,
    -- Taxas
    CASE WHEN SUM(d.messages_sent) > 0
        THEN ROUND(100.0 * SUM(d.messages_delivered) / SUM(d.messages_sent), 2)
        ELSE 0
    END as taxa_entrega_media,
    CASE WHEN SUM(d.prospects_contacted) > 0
        THEN ROUND(100.0 * SUM(d.opt_ins) / SUM(d.prospects_contacted), 2)
        ELSE 0
    END as taxa_engajamento_media,
    CASE WHEN SUM(d.opt_ins) > 0
        THEN ROUND(100.0 * SUM(d.leads_qualified) / SUM(d.opt_ins), 2)
        ELSE 0
    END as taxa_qualificacao_media,
    CASE WHEN SUM(d.meetings_scheduled) > 0
        THEN ROUND(100.0 * SUM(d.meetings_attended) / SUM(d.meetings_scheduled), 2)
        ELSE 0
    END as taxa_comparecimento_media
FROM corev4_daily_metrics d
JOIN corev4_empresas e ON d.empresa_id = e.id
WHERE d.date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY e.id, e.name;

-- ---------------------------------------------
-- VIEW 8: Horários de Melhor Resposta
-- ---------------------------------------------
CREATE OR REPLACE VIEW vw_analytics_melhores_horarios AS
SELECT
    e.id as empresa_id,
    e.name as empresa,
    EXTRACT(HOUR FROM mh.received_at) as hora,
    EXTRACT(DOW FROM mh.received_at) as dia_semana,
    COUNT(*) as total_respostas,
    SUM(CASE WHEN mh.sentiment = 'positive' THEN 1 ELSE 0 END) as respostas_positivas
FROM corev4_message_history mh
JOIN corev4_leads l ON mh.lead_id = l.id
JOIN corev4_empresas e ON l.empresa_id = e.id
WHERE mh.direction = 'inbound'
  AND mh.received_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY e.id, e.name, EXTRACT(HOUR FROM mh.received_at), EXTRACT(DOW FROM mh.received_at)
ORDER BY total_respostas DESC;

-- ---------------------------------------------
-- GRANTS (para o usuário do Looker)
-- ---------------------------------------------
-- Se você criar um usuário específico para Looker:
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO looker_user;
-- GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO looker_user;

-- ---------------------------------------------
-- Verificar se as views foram criadas
-- ---------------------------------------------
SELECT table_name
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name LIKE 'vw_analytics%';
```

### 3.3 Tabela de Métricas Diárias (se não existir)

```sql
-- Criar tabela para métricas agregadas diárias
-- (melhora performance do Looker Studio)

CREATE TABLE IF NOT EXISTS corev4_daily_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    empresa_id UUID NOT NULL REFERENCES corev4_empresas(id),
    date DATE NOT NULL,

    -- Prospecção
    prospects_created INT DEFAULT 0,
    prospects_contacted INT DEFAULT 0,
    messages_sent INT DEFAULT 0,
    messages_delivered INT DEFAULT 0,
    opt_ins INT DEFAULT 0,
    opt_outs INT DEFAULT 0,

    -- Qualificação
    conversations_started INT DEFAULT 0,
    conversations_completed INT DEFAULT 0,
    leads_qualified INT DEFAULT 0,
    leads_disqualified INT DEFAULT 0,

    -- Agendamento
    meetings_scheduled INT DEFAULT 0,
    meetings_confirmed INT DEFAULT 0,
    meetings_attended INT DEFAULT 0,
    meetings_no_show INT DEFAULT 0,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(empresa_id, date)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_daily_metrics_empresa
    ON corev4_daily_metrics(empresa_id);
CREATE INDEX IF NOT EXISTS idx_daily_metrics_date
    ON corev4_daily_metrics(date DESC);
CREATE INDEX IF NOT EXISTS idx_daily_metrics_empresa_date
    ON corev4_daily_metrics(empresa_id, date DESC);
```

---

## 4. Conectando Looker Studio ao Supabase

### Passo a Passo com Screenshots

#### 4.1 Acessar Looker Studio

1. Abra o navegador
2. Acesse: **https://lookerstudio.google.com**
3. Faça login com sua conta Google

#### 4.2 Criar Nova Fonte de Dados

1. Clique no botão **"+ Create"** (canto superior esquerdo)
2. Selecione **"Data source"**

```
┌─────────────────────────────────────────┐
│  + Create ▼                             │
│  ┌─────────────────────────────────┐    │
│  │ 📊 Report                       │    │
│  │ 📁 Data source          ◀──────│────│── Clique aqui
│  │ 📈 Explorer                     │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

#### 4.3 Selecionar Conector PostgreSQL

1. Na barra de busca, digite **"PostgreSQL"**
2. Clique no conector **"PostgreSQL"** (ícone azul do elefante)

```
┌─────────────────────────────────────────────────────────────┐
│  Connect to data                                            │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ 🔍 postgresql                                       │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  Google Connectors                Partner Connectors        │
│  ┌─────────────┐                                           │
│  │ 🐘          │                                           │
│  │ PostgreSQL  │ ◀── Clique aqui                           │
│  └─────────────┘                                           │
└─────────────────────────────────────────────────────────────┘
```

#### 4.4 Preencher Credenciais

Preencha os campos:

```
┌─────────────────────────────────────────────────────────────┐
│  PostgreSQL                                                 │
│                                                             │
│  Host Name or IP *                                          │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ db.xxxxxxxxxxxxx.supabase.co                        │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  Port *                      Database *                     │
│  ┌───────────────┐          ┌───────────────────────┐      │
│  │ 5432          │          │ postgres              │      │
│  └───────────────┘          └───────────────────────┘      │
│                                                             │
│  Username *                                                 │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ postgres                                            │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  Password *                                                 │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ ••••••••••••••••                                    │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ☑ Enable SSL                                               │
│                                                             │
│                              [ AUTHENTICATE ]               │
└─────────────────────────────────────────────────────────────┘
```

**Valores:**
| Campo | Valor |
|-------|-------|
| Host | `db.XXXXX.supabase.co` (pegue no Supabase) |
| Port | `5432` (ou `6543` para pooling) |
| Database | `postgres` |
| Username | `postgres` |
| Password | Senha do seu projeto Supabase |
| Enable SSL | ✅ Marcado |

5. Clique em **"AUTHENTICATE"**

#### 4.5 Selecionar a View

Após autenticar, você verá a lista de tabelas/views:

1. No dropdown **"Table"**, selecione uma view:
   - `vw_analytics_funil` (para dashboard de funil)
   - `vw_analytics_campanhas` (para dashboard de campanhas)
   - etc.

2. Clique em **"CONNECT"**

```
┌─────────────────────────────────────────────────────────────┐
│  Select a table                                             │
│                                                             │
│  Table *                                                    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ vw_analytics_funil                              ▼   │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  Tables available:                                          │
│  • vw_analytics_funil                                       │
│  • vw_analytics_campanhas                                   │
│  • vw_analytics_warmup                                      │
│  • vw_analytics_qualificacao                                │
│  • vw_analytics_agendamentos                                │
│  • vw_analytics_diario                                      │
│  • vw_analytics_resumo_executivo                            │
│  • vw_analytics_melhores_horarios                           │
│                                                             │
│                              [ CONNECT ]                    │
└─────────────────────────────────────────────────────────────┘
```

#### 4.6 Configurar Campos

Após conectar, configure os tipos de dados:

```
┌───────────────────────────────────────────────────────────────────────────┐
│  vw_analytics_funil                                                       │
│                                                                           │
│  Field              │ Type      │ Aggregation │ Description              │
│  ───────────────────┼───────────┼─────────────┼────────────────────────  │
│  empresa_id         │ Text      │ None        │ ID da empresa            │
│  empresa            │ Text      │ None        │ Nome da empresa          │
│  data               │ Date      │ None        │ Data do registro         │
│  total_prospects    │ Number    │ Sum         │ Total de prospects       │
│  contatados         │ Number    │ Sum         │ Prospects contatados     │
│  engajados          │ Number    │ Sum         │ Prospects engajados      │
│  qualificados       │ Number    │ Sum         │ Leads qualificados       │
│  convertidos        │ Number    │ Sum         │ Leads convertidos        │
│                                                                           │
│                              [ CREATE REPORT ]                            │
└───────────────────────────────────────────────────────────────────────────┘
```

7. Clique em **"CREATE REPORT"** para ir direto para o dashboard

---

## 5. Criando os Dashboards

### 5.1 Dashboard: Visão Geral Executiva

#### Layout do Dashboard

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  COREADAPT ANALYTICS                    [Empresa ▼]  [Período ▼]           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │    523       │  │    312       │  │    127       │  │     47       │    │
│  │  Prospects   │  │  Contatados  │  │  Engajados   │  │ Qualificados │    │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                                              │
│  ┌────────────────────────────────────┐  ┌──────────────────────────────┐  │
│  │      FUNIL DE CONVERSÃO            │  │    EVOLUÇÃO SEMANAL          │  │
│  │                                    │  │                              │  │
│  │  [=============================]   │  │    📈 Gráfico de Linha       │  │
│  │  [===================]             │  │                              │  │
│  │  [==========]                      │  │                              │  │
│  │  [====]                            │  │                              │  │
│  │                                    │  │                              │  │
│  └────────────────────────────────────┘  └──────────────────────────────┘  │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  TAXAS DE CONVERSÃO                                                    │  │
│  │                                                                         │  │
│  │  Contato → Engajamento: 40.7%    Engajamento → Qualificação: 37.0%    │  │
│  │  Qualificação → Agendamento: 48.9%                                     │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Passo a Passo para Criar

**1. Adicionar Scorecards (KPIs no topo)**

```
Menu: Insert → Scorecard

Configuração:
- Data source: vw_analytics_resumo_executivo
- Metric: total_prospects (SUM)
- Style:
  - Font size: 48
  - Show metric name: ✓
  - Compact numbers: ✓
```

Repita para: `total_contatados`, `total_engajados`, `total_qualificados`, `total_agendamentos`

**2. Adicionar Gráfico de Funil**

```
Menu: Insert → Chart → Bar chart

Configuração:
- Data source: vw_analytics_funil
- Dimension: (criar campo calculado "Etapa")
- Metric: (valor de cada etapa)
- Style:
  - Horizontal bars
  - Single color
  - Show data labels
```

**Campo calculado para Funil:**
```
Etapa:
CASE
  WHEN Record Count = 1 THEN "1. Prospects"
  WHEN Record Count = 2 THEN "2. Contatados"
  WHEN Record Count = 3 THEN "3. Engajados"
  WHEN Record Count = 4 THEN "4. Qualificados"
  WHEN Record Count = 5 THEN "5. Convertidos"
END
```

**3. Adicionar Gráfico de Linha (Evolução)**

```
Menu: Insert → Time series chart

Configuração:
- Data source: vw_analytics_diario
- Dimension: data
- Metrics:
  - prospects_created
  - leads_qualified
  - meetings_scheduled
- Style:
  - Smooth line
  - Show points
  - Legend at bottom
```

**4. Adicionar Filtros**

```
Menu: Insert → Drop-down list (para filtro de Empresa)

Configuração:
- Control field: empresa
- Metric: None
- Style: Single select
```

```
Menu: Insert → Date range control (para filtro de Período)

Configuração:
- Default date range: Last 30 days
- Auto date range: ✓
```

### 5.2 Dashboard: Campanhas Outbound

#### Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  CAMPANHAS OUTBOUND                     [Empresa ▼]  [Período ▼]           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  PERFORMANCE POR CAMPANHA                                              │  │
│  ├───────────────────────────────────────────────────────────────────────┤  │
│  │  Campanha       │ Enviados │ Entrega │ Engaj. │ Opt-out │ Status      │  │
│  │  Dentistas SP   │    250   │  97.2%  │ 18.4%  │   1.2%  │ 🟢 Ativa    │  │
│  │  Advogados RJ   │    180   │  95.8%  │ 22.1%  │   0.8%  │ 🟢 Ativa    │  │
│  │  Contadores MG  │     45   │  98.0%  │ 15.6%  │   2.0%  │ 🟡 Warmup   │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌──────────────────────────────────┐  ┌────────────────────────────────┐  │
│  │     TAXA DE ENTREGA              │  │    DISTRIBUIÇÃO RESPOSTAS      │  │
│  │                                  │  │                                │  │
│  │        🎯 96.7%                  │  │   Opt-in   ████████    62%     │  │
│  │     [==============]             │  │   Opt-out  ██          8%     │  │
│  │                                  │  │   Ignorado ████       30%     │  │
│  └──────────────────────────────────┘  └────────────────────────────────┘  │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  ENVIOS POR DIA                                                        │  │
│  │                                                                         │  │
│  │  📊 [Gráfico de barras com envios diários]                             │  │
│  │                                                                         │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Componentes

**1. Tabela de Campanhas**
```
Menu: Insert → Table

Configuração:
- Data source: vw_analytics_campanhas
- Dimensions: campanha, campanha_status
- Metrics:
  - SUM(total_envios)
  - AVG(taxa_entrega_pct)
  - AVG(taxa_engajamento_pct)
  - AVG(taxa_optout_pct)
- Style:
  - Heatmap on metrics
  - Conditional formatting (red if opt-out > 5%)
```

**2. Gauge de Taxa de Entrega**
```
Menu: Insert → Gauge

Configuração:
- Metric: AVG(taxa_entrega_pct)
- Range: 0 to 100
- Style:
  - Green: 90-100
  - Yellow: 80-90
  - Red: 0-80
```

**3. Pie Chart de Respostas**
```
Menu: Insert → Pie chart

Configuração:
- Dimension: response_type (criar campo calculado)
- Metric: COUNT
- Style:
  - Donut
  - Show percentages
```

### 5.3 Dashboard: Agendamentos

#### Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  AGENDAMENTOS                           [Empresa ▼]  [Período ▼]           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │      23      │  │     87%      │  │     92%      │  │      8%      │    │
│  │  Agendados   │  │ Confirmados  │  │ Compareceram │  │   No-show    │    │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  PRÓXIMAS REUNIÕES                                                      │  │
│  ├───────────────────────────────────────────────────────────────────────┤  │
│  │  Data/Hora      │ Lead           │ Empresa      │ Status              │  │
│  │  27/12 10:00    │ João Silva     │ TechCorp     │ ✅ Confirmado       │  │
│  │  27/12 14:30    │ Maria Santos   │ DigitalMKT   │ ⏳ Pendente         │  │
│  │  28/12 11:00    │ Pedro Costa    │ ConsultPro   │ ✅ Confirmado       │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌──────────────────────────────────┐  ┌────────────────────────────────┐  │
│  │    REUNIÕES POR DIA DA SEMANA    │  │  PREFERÊNCIA DE HORÁRIO        │  │
│  │                                  │  │                                │  │
│  │  Seg  ████████████     32%       │  │  Manhã (9-12)   ████████ 45%   │  │
│  │  Ter  ██████████       28%       │  │  Tarde (14-17)  ██████   35%   │  │
│  │  Qua  ███████          20%       │  │  Final tarde    ████     20%   │  │
│  │  Qui  █████            14%       │  │                                │  │
│  │  Sex  ██                6%       │  │                                │  │
│  └──────────────────────────────────┘  └────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Campos Calculados Úteis

```sql
-- Dia da Semana em Português
CASE dia_semana
  WHEN 0 THEN "Domingo"
  WHEN 1 THEN "Segunda"
  WHEN 2 THEN "Terça"
  WHEN 3 THEN "Quarta"
  WHEN 4 THEN "Quinta"
  WHEN 5 THEN "Sexta"
  WHEN 6 THEN "Sábado"
END

-- Período do Dia
CASE
  WHEN hora >= 9 AND hora < 12 THEN "Manhã"
  WHEN hora >= 12 AND hora < 14 THEN "Almoço"
  WHEN hora >= 14 AND hora < 17 THEN "Tarde"
  ELSE "Outro"
END

-- Status com Emoji
CASE status_reuniao
  WHEN "Compareceu" THEN "✅ Compareceu"
  WHEN "Confirmado" THEN "📅 Confirmado"
  WHEN "Pendente" THEN "⏳ Pendente"
  WHEN "No-show" THEN "❌ No-show"
END
```

---

## 6. Multi-tenancy (Separação por Cliente)

### Opção A: Filtro no Dashboard (Simples)

Cada dashboard tem um filtro de "Empresa". O cliente seleciona sua empresa.

**Problema:** Cliente pode ver outras empresas.

### Opção B: Link com Parâmetro (Recomendado)

Criar link específico por cliente com filtro pré-aplicado:

```
https://lookerstudio.google.com/reporting/REPORT_ID?params={"empresa_id":"uuid-da-empresa"}
```

**Como fazer:**
1. No Looker Studio, vá em **File → Report settings**
2. Em "URL Parameters", adicione `empresa_id`
3. No filtro, configure para usar o parâmetro

### Opção C: Relatórios Separados (Mais Seguro)

Criar uma cópia do dashboard para cada cliente, com filtro fixo.

**Automação:**
```javascript
// Script Google Apps Script para duplicar dashboards
function duplicateDashboardForClient(templateId, clientName, empresaId) {
  // Use Looker Studio API para duplicar e configurar
}
```

### Opção D: Row-Level Security (Avançado)

Se você criar usuários no Google Workspace para cada cliente:

1. Crie um Google Group por cliente
2. No Supabase, crie política RLS baseada em email
3. Configure Looker Studio para passar o email do usuário

```sql
-- No Supabase
CREATE POLICY "Clientes veem só seus dados" ON corev4_prospects
FOR SELECT USING (
  empresa_id IN (
    SELECT empresa_id FROM corev4_user_empresa_mapping
    WHERE email = current_user
  )
);
```

---

## 7. Compartilhamento e Embedding

### 7.1 Compartilhar por Link

1. No dashboard, clique em **Share** (canto superior direito)
2. Selecione **"Get report link"**
3. Escolha permissão:
   - **Anyone with link can view** (público)
   - **Restricted** (só emails específicos)

### 7.2 Agendar Envio por Email

1. **File → Schedule email delivery**
2. Configure:
   - Destinatários
   - Frequência (diário, semanal, mensal)
   - Formato (PDF ou link)

```
┌─────────────────────────────────────────────────────────────┐
│  Schedule email delivery                                    │
│                                                             │
│  To: cliente@empresa.com                                    │
│                                                             │
│  Subject: [CoreAdapt] Relatório Semanal                     │
│                                                             │
│  Frequency: ○ Daily  ● Weekly  ○ Monthly                    │
│                                                             │
│  Day: Monday     Time: 08:00 AM                            │
│                                                             │
│  Format: ● PDF attachment  ○ Link to report                │
│                                                             │
│                              [ Schedule ]                   │
└─────────────────────────────────────────────────────────────┘
```

### 7.3 Embedding em Site/Portal

1. **File → Embed report**
2. Copie o código iframe

```html
<!-- Exemplo de Embed -->
<iframe
  width="100%"
  height="600"
  src="https://lookerstudio.google.com/embed/reporting/REPORT_ID/page/PAGE_ID"
  frameborder="0"
  style="border:0"
  allowfullscreen>
</iframe>
```

**Com parâmetro de empresa:**
```html
<iframe
  width="100%"
  height="600"
  src="https://lookerstudio.google.com/embed/reporting/REPORT_ID/page/PAGE_ID?params=%7B%22empresa_id%22:%22UUID_AQUI%22%7D"
  frameborder="0"
  style="border:0"
  allowfullscreen>
</iframe>
```

### 7.4 Portal CoreAdapt (Exemplo React)

```jsx
// components/Dashboard.jsx
import { useEffect, useState } from 'react';
import { useAuth } from '../hooks/useAuth';

export function Dashboard() {
  const { user, empresaId } = useAuth();

  const dashboardUrl = `https://lookerstudio.google.com/embed/reporting/YOUR_REPORT_ID/page/p_xyz?params=${encodeURIComponent(JSON.stringify({ empresa_id: empresaId }))}`;

  return (
    <div className="dashboard-container">
      <h1>Analytics - {user.empresaNome}</h1>

      <iframe
        src={dashboardUrl}
        width="100%"
        height="800"
        frameBorder="0"
        allowFullScreen
        title="CoreAdapt Analytics"
      />
    </div>
  );
}
```

---

## 8. Manutenção e Boas Práticas

### 8.1 Performance

**Usar Views Materializadas para dados pesados:**

```sql
-- Criar materialized view (atualiza sob demanda)
CREATE MATERIALIZED VIEW mv_analytics_diario AS
SELECT * FROM vw_analytics_diario;

-- Atualizar (agendar via cron ou Supabase Edge Function)
REFRESH MATERIALIZED VIEW mv_analytics_diario;
```

**Índices importantes:**

```sql
CREATE INDEX CONCURRENTLY idx_prospects_empresa_status
    ON corev4_prospects(empresa_id, status, created_at);

CREATE INDEX CONCURRENTLY idx_campaigns_empresa_date
    ON corev4_campaign_executions(empresa_id, executed_at);

CREATE INDEX CONCURRENTLY idx_meetings_empresa_date
    ON corev4_meetings(empresa_id, scheduled_at);
```

### 8.2 Atualização de Dados

Looker Studio atualiza automaticamente, mas você pode controlar:

1. **Data source → Edit connection**
2. **Data freshness:** Configure cache (15 min a 12h)

Para dados em tempo real, use cache de 15 minutos.

### 8.3 Versionamento

Mantenha backups dos dashboards:

1. **File → Make a copy** antes de grandes mudanças
2. Use nomenclatura: `CoreAdapt Dashboard v1.0`, `v1.1`, etc.

### 8.4 Checklist de Manutenção Mensal

- [ ] Verificar se todas as views estão funcionando
- [ ] Checar performance dos dashboards
- [ ] Atualizar filtros se houver novas empresas
- [ ] Revisar métricas com stakeholders
- [ ] Backup dos dashboards

---

## Apêndice A: Troubleshooting

### Erro: "Unable to connect to database"

**Causas possíveis:**
1. Credenciais incorretas
2. IP do Looker bloqueado
3. SSL não habilitado

**Solução:**
- Verifique credenciais no Supabase
- Habilite "Enable SSL" na conexão
- Use porta `6543` (pooler) em vez de `5432`

### Erro: "No data to display"

**Causas possíveis:**
1. View retornando vazio
2. Filtro muito restritivo
3. Período sem dados

**Solução:**
- Teste a view diretamente no Supabase SQL Editor
- Remova filtros temporariamente
- Expanda o período de datas

### Dashboard lento

**Soluções:**
1. Criar views materializadas
2. Adicionar índices nas tabelas
3. Reduzir período padrão de dados
4. Simplificar cálculos complexos

---

## Apêndice B: Templates de Campos Calculados

### Taxa de Conversão
```
taxa_conversao = (qualificados / NULLIF(prospects, 0)) * 100
```

### Variação Percentual
```
variacao_pct = ((valor_atual - valor_anterior) / NULLIF(valor_anterior, 0)) * 100
```

### Categorização de Score
```
CASE
  WHEN score >= 80 THEN "🟢 Hot"
  WHEN score >= 50 THEN "🟡 Warm"
  ELSE "🔴 Cold"
END
```

### Formatação de Telefone BR
```
CONCAT("+55 ", SUBSTR(telefone, 1, 2), " ", SUBSTR(telefone, 3, 5), "-", SUBSTR(telefone, 8, 4))
```

---

## Conclusão

Com este guia, você tem tudo para implementar dashboards profissionais no CoreAdapt usando Looker Studio — **100% grátis**.

**Tempo total estimado:** 4-6 horas para setup completo

**Próximos passos:**
1. Criar views no Supabase
2. Conectar Looker Studio
3. Montar os 3-5 dashboards principais
4. Configurar compartilhamento por cliente
5. Testar e ajustar

---

*Documento criado em 2025-12-26 para CoreAdapt*
