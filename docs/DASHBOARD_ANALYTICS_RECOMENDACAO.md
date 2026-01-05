# CoreAdapt Analytics — Guia de Dashboard

**Versão:** 1.0
**Data:** 2025-12-26
**Objetivo:** Definir ferramenta e métricas para interface de analytics do cliente

---

## Resumo Executivo

Para o CoreAdapt, recomendo **Apache Superset** como solução de BI/Dashboard. É a melhor combinação de:
- Custo zero (open-source Apache Foundation)
- Facilidade de uso comparável ao Metabase
- Recursos enterprise-grade
- Comunidade ativa e suporte longo prazo
- Excelente para multi-tenancy (cada cliente vê só seus dados)

---

## Comparativo de Ferramentas

### Opções Avaliadas

| Critério | Metabase | Apache Superset | Grafana | Redash | Chartbrew |
|----------|----------|-----------------|---------|--------|-----------|
| **Custo** | $85-500/mês (cloud) | Grátis | Grátis | Grátis | $29-99/mês |
| **Self-hosted** | ✅ Grátis | ✅ Grátis | ✅ Grátis | ✅ Grátis | ✅ |
| **Facilidade** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Visualizações** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **Multi-tenant** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| **SQL Required** | Opcional | Opcional | Sim | Sim | Não |
| **Embedding** | Pro only | ✅ Nativo | ✅ Nativo | ✅ | ✅ |
| **Manutenção** | ✅ Ativa | ✅ Apache Foundation | ✅ Grafana Labs | ⚠️ Sunset | ✅ Ativa |
| **Português BR** | ✅ | ✅ | ✅ | ❌ | ❌ |

### Análise Detalhada

#### Apache Superset (RECOMENDADO)
**Prós:**
- Mantido pela Apache Foundation (garantia de longevidade)
- 60+ tipos de visualização nativos
- Row-Level Security (RLS) para multi-tenancy
- Dashboards embutíveis sem custo extra
- Semantic Layer para métricas consistentes
- Suporta 30+ bancos de dados
- Interface intuitiva, sem necessidade de SQL para usuários
- Usado por Airbnb, Twitter, Netflix, Dropbox

**Contras:**
- Setup inicial mais complexo que Metabase
- Requer Docker para deploy fácil
- Curva de aprendizado inicial para admin

**Deploy:** Docker Compose ou Kubernetes

#### Metabase
**Prós:**
- Interface mais amigável do mercado
- Perguntas em linguagem natural
- Setup em 5 minutos

**Contras:**
- Embedding custa $500/mês (Pro)
- Multi-tenant limitado na versão grátis
- Empresa menor, menos garantias

#### Grafana
**Prós:**
- Excelente para métricas em tempo real
- Alertas nativos
- Muito leve e rápido

**Contras:**
- Foco em métricas técnicas, não business
- Requer PromQL/SQL para tudo
- UX menos amigável para clientes

#### Redash
**Contras decisivos:**
- Anunciou sunset (descontinuação)
- Risco de ficar sem suporte

#### Chartbrew
**Prós:**
- No-code, muito fácil
- Preço acessível

**Contras:**
- Menos robusto para escala
- Comunidade pequena

---

## Recomendação Final: Apache Superset

### Por que Superset para CoreAdapt?

1. **Multi-tenancy nativo**: Row-Level Security permite que cada empresa cliente veja APENAS seus dados, com uma única instalação

2. **Dashboards embutíveis**: Podemos incorporar dashboards em uma interface própria CoreAdapt (portal do cliente)

3. **Custo zero**: Open-source, sem licenciamento

4. **Escalável**: Suporta desde 10 até 10.000+ usuários

5. **Métricas semânticas**: Definimos métricas uma vez, usamos em qualquer dashboard

6. **Longevidade**: Apache Foundation garante manutenção por décadas

---

## Arquitetura Proposta

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        COREADAPT ANALYTICS STACK                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐         │
│  │   PORTAL DO     │    │    SUPERSET     │    │   POSTGRESQL    │         │
│  │    CLIENTE      │◄───│   (Embedded)    │◄───│   (Supabase)    │         │
│  │  (React/Next)   │    │                 │    │                 │         │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘         │
│         │                       │                      ▲                    │
│         │                       │                      │                    │
│         ▼                       ▼                      │                    │
│  ┌─────────────────┐    ┌─────────────────┐           │                    │
│  │  Autenticação   │    │  Row-Level      │           │                    │
│  │  (Supabase Auth)│    │  Security       │───────────┘                    │
│  └─────────────────┘    │  (por empresa)  │                                │
│                         └─────────────────┘                                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Opções de Interface

#### Opção A: Superset Standalone
- Cliente acessa Superset diretamente
- Menos trabalho de desenvolvimento
- Interface Superset padrão
- **Tempo:** 1-2 dias

#### Opção B: Superset Embedded (RECOMENDADO)
- Portal próprio CoreAdapt
- Dashboards embutidos via iframe/SDK
- Experiência de marca própria
- Login unificado com Supabase
- **Tempo:** 3-5 dias

#### Opção C: Portal Custom + API Superset
- Interface 100% customizada
- Usa API do Superset para dados
- Maior controle, mais trabalho
- **Tempo:** 2-3 semanas

---

## Métricas e KPIs do CoreAdapt

### Dashboard 1: Visão Geral (Executive Summary)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  COREADAPT ANALYTICS                             📅 Últimos 30 dias  ▼     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │     523      │  │     127      │  │      47      │  │      23      │    │
│  │   Prospects  │  │   Engajados  │  │ Qualificados │  │  Agendados   │    │
│  │   +12% ▲     │  │   +8% ▲      │  │   +15% ▲     │  │   +22% ▲     │    │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                                              │
│  ┌────────────────────────────────────┐  ┌──────────────────────────────┐  │
│  │         FUNIL DE CONVERSÃO         │  │      AGENDAMENTOS/SEMANA     │  │
│  │                                    │  │                              │  │
│  │  Prospects    ████████████ 523     │  │    8 ┤      ┌──┐             │  │
│  │  Contatados   ████████     312     │  │    6 ┤   ┌──┤  ├──┐         │  │
│  │  Engajados    █████        127     │  │    4 ┤┌──┤  │  │  ├──┐      │  │
│  │  Qualificados ██            47     │  │    2 ┤│  │  │  │  │  │      │  │
│  │  Agendados    █             23     │  │    0 ┴┴──┴──┴──┴──┴──┴──    │  │
│  │                                    │  │      S1  S2  S3  S4  S5     │  │
│  └────────────────────────────────────┘  └──────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Métricas:**
| Métrica | Descrição | Fonte |
|---------|-----------|-------|
| Total Prospects | Leads formados/importados | `corev4_prospects` |
| Taxa de Contato | % prospects que receberam first touch | `corev4_campaign_executions` |
| Taxa de Engajamento | % que responderam positivamente | `corev4_message_history` |
| Qualificados | Leads que passaram ANUM | `corev4_leads.qualification_status` |
| Agendados | Reuniões marcadas | `corev4_meetings` |
| No-show Rate | % que não compareceu | `corev4_meetings` |
| Tempo Médio Funil | Dias do primeiro contato ao agendamento | Calculado |

### Dashboard 2: Prospecção Ativa

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  PROSPECÇÃO ATIVA                                📅 Últimos 7 dias  ▼      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  CAMPANHAS ATIVAS                                                      │  │
│  ├───────────────────────────────────────────────────────────────────────┤  │
│  │  Nome              │ Status  │ Enviados │ Entrega │ Engaj. │ Opt-out  │  │
│  ├───────────────────────────────────────────────────────────────────────┤  │
│  │  Dentistas SP      │ 🟢 Ativa│    250   │  97.2%  │ 18.4%  │   1.2%   │  │
│  │  Advogados RJ      │ 🟢 Ativa│    180   │  95.8%  │ 22.1%  │   0.8%   │  │
│  │  Contadores MG     │ 🟡 Warmup│    45   │  98.0%  │ 15.6%  │   2.0%   │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌──────────────────────────┐  ┌──────────────────────────────────────────┐ │
│  │    STATUS WARMUP         │  │         DISTRIBUIÇÃO DE RESPOSTAS        │ │
│  │                          │  │                                          │ │
│  │  Capacidade: 450/dia     │  │  Opt-in    ████████████████    62%       │ │
│  │  Dia atual: 12/14        │  │  Opt-out   ██                   8%       │ │
│  │  ████████████░░ 85%      │  │  Ignorado  ████████            30%       │ │
│  │                          │  │                                          │ │
│  └──────────────────────────┘  └──────────────────────────────────────────┘ │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  MELHORES HORÁRIOS DE RESPOSTA                                         │  │
│  │                                                                         │  │
│  │  Hora    │ 06 │ 07 │ 08 │ 09 │ 10 │ 11 │ 12 │ 13 │ 14 │ 15 │ 16 │ 17 │  │
│  │  Resp(%) │  2 │  5 │ 12 │ 18 │ 15 │ 10 │  8 │  6 │  8 │ 10 │  4 │  2 │  │
│  │          │  ░ │  █ │ ██ │███ │ ██ │ ██ │  █ │  █ │  █ │ ██ │  ░ │  ░ │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Métricas:**
| Métrica | Descrição | Alerta |
|---------|-----------|--------|
| Taxa de Entrega | % msgs entregues | < 90% = problema |
| Taxa de Engajamento | % opt-in | < 10% = revisar mensagem |
| Taxa de Opt-out | % que saíram | > 5% = problema sério |
| Capacidade Warmup | Msgs/dia permitidas | Meta: 1000 em 14 dias |
| Melhor Horário | Hora com mais respostas | Otimizar envios |

### Dashboard 3: Qualificação (CoreOne/Sync)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  QUALIFICAÇÃO & CONVERSAS                        📅 Últimos 30 dias  ▼     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │     4.2      │  │      12      │  │     78%      │  │     3.2h     │    │
│  │   NPS Médio  │  │ Msgs/Qualif. │  │ Taxa Qualif. │  │ Tempo Médio  │    │
│  │   ⭐⭐⭐⭐     │  │              │  │              │  │              │    │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  SCORE ANUM - ÚLTIMOS LEADS                                            │  │
│  ├───────────────────────────────────────────────────────────────────────┤  │
│  │  Lead           │ Authority │ Need │ Urgency │ Money │ Score │ Status │  │
│  ├───────────────────────────────────────────────────────────────────────┤  │
│  │  João Silva     │    ✅     │  ✅  │   ✅    │  ✅   │ 100%  │ 🟢 Hot  │  │
│  │  Maria Santos   │    ✅     │  ✅  │   ⚠️    │  ✅   │  75%  │ 🟡 Warm │  │
│  │  Pedro Costa    │    ⚠️     │  ✅  │   ❌    │  ⚠️   │  40%  │ 🔴 Cold │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌────────────────────────────────┐  ┌────────────────────────────────────┐ │
│  │    RAZÕES DE DESQUALIFICAÇÃO   │  │      OBJEÇÕES MAIS COMUNS          │ │
│  │                                │  │                                    │ │
│  │  Sem orçamento      ████  35%  │  │  "Estou sem tempo"     ████  28%   │ │
│  │  Não é decisor      ███   25%  │  │  "Já uso outro"        ███   22%   │ │
│  │  Timing errado      ██    18%  │  │  "Preciso pensar"      ███   20%   │ │
│  │  Sem necessidade    ██    15%  │  │  "Quanto custa?"       ██    18%   │ │
│  │  Outros             █      7%  │  │  "Mande material"      █     12%   │ │
│  │                                │  │                                    │ │
│  └────────────────────────────────┘  └────────────────────────────────────┘ │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Métricas:**
| Métrica | Descrição | Fonte |
|---------|-----------|-------|
| NPS da Conversa | Satisfação do lead com atendimento | Pesquisa pós-conversa |
| Msgs por Qualificação | Quantas msgs até completar ANUM | `corev4_message_history` |
| Taxa de Qualificação | % leads que passam critérios | `corev4_qualification_results` |
| Score ANUM | Pontuação por critério | `corev4_qualification_results` |
| Tempo até Qualificação | Duração da conversa | Timestamps |
| Top Objeções | Principais resistências | NLP analysis |

### Dashboard 4: Agendamento

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  AGENDAMENTOS                                    📅 Últimos 30 dias  ▼     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │      23      │  │     87%      │  │     92%      │  │     2.1      │    │
│  │  Agendados   │  │ Confirmados  │  │ Compareceram │  │ Tentativas   │    │
│  │   este mês   │  │              │  │  (no-show 8%)│  │  por agenda  │    │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  PRÓXIMAS REUNIÕES                                                      │  │
│  ├───────────────────────────────────────────────────────────────────────┤  │
│  │  Data/Hora       │ Lead           │ Empresa      │ Status    │ Link   │  │
│  ├───────────────────────────────────────────────────────────────────────┤  │
│  │  27/12 10:00     │ João Silva     │ TechCorp     │ ✅ Confirm│ 🔗 Meet│  │
│  │  27/12 14:30     │ Maria Santos   │ DigitalMKT   │ ⏳ Pendente│ 🔗 Meet│  │
│  │  28/12 11:00     │ Pedro Costa    │ ConsultPro   │ ✅ Confirm│ 🔗 Meet│  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌────────────────────────────────┐  ┌────────────────────────────────────┐ │
│  │    DISTRIBUIÇÃO POR DIA        │  │      PREFERÊNCIA DE HORÁRIO        │ │
│  │                                │  │                                    │ │
│  │  Seg  ████████████     32%     │  │  Manhã (9-12)    ████████   45%    │ │
│  │  Ter  ██████████       28%     │  │  Tarde (14-17)   ██████     35%    │ │
│  │  Qua  ███████          20%     │  │  Final tarde     ████       20%    │ │
│  │  Qui  █████            14%     │  │                                    │ │
│  │  Sex  ██                6%     │  │                                    │ │
│  │                                │  │                                    │ │
│  └────────────────────────────────┘  └────────────────────────────────────┘ │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Métricas:**
| Métrica | Descrição | Meta |
|---------|-----------|------|
| Total Agendados | Reuniões marcadas | +20%/mês |
| Taxa Confirmação | % que confirmou lembrete | > 85% |
| Taxa Comparecimento | % que entrou na reunião | > 90% |
| No-show Rate | % ausências | < 10% |
| Tentativas por Agenda | Quantas ofertas até agendar | < 3 |
| Dia Preferido | Dia com mais agendamentos | Para otimizar disponibilidade |

### Dashboard 5: ROI e Resultado

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  ROI & RESULTADO                                 📅 Últimos 90 dias  ▼     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   R$ 127     │  │   R$ 412     │  │    23.4x     │  │  R$ 180k     │    │
│  │  Custo/Lead  │  │ Custo/Reunião│  │    ROI       │  │ Receita Est. │    │
│  │  Qualificado │  │  Agendada    │  │              │  │ (fechamentos)│    │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  EVOLUÇÃO MENSAL                                                        │  │
│  │                                                                         │  │
│  │  60 ┤                                              ┌──┐                 │  │
│  │  50 ┤                                    ┌──┐      │  │                 │  │
│  │  40 ┤                          ┌──┐      │  │      │  │                 │  │
│  │  30 ┤              ┌──┐        │  │      │  │      │  │                 │  │
│  │  20 ┤    ┌──┐      │  │        │  │      │  │      │  │                 │  │
│  │  10 ┤    │  │      │  │        │  │      │  │      │  │                 │  │
│  │   0 ┴────┴──┴──────┴──┴────────┴──┴──────┴──┴──────┴──┴──               │  │
│  │        Out          Nov          Dez          Jan                       │  │
│  │                                                                         │  │
│  │  ■ Prospects  ■ Qualificados  ■ Agendados                              │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  COMPARATIVO: ANTES vs DEPOIS                                          │  │
│  ├───────────────────────────────────────────────────────────────────────┤  │
│  │  Métrica              │  SDR Manual  │  CoreAdapt  │  Melhoria         │  │
│  ├───────────────────────────────────────────────────────────────────────┤  │
│  │  Contatos/dia         │      60      │     450     │   +650%           │  │
│  │  Tempo resposta       │    4.2h      │    12min    │   -95%            │  │
│  │  Custo/reunião        │  R$ 1.200    │   R$ 412    │   -66%            │  │
│  │  Reuniões/mês         │      8       │      23     │   +187%           │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Métricas:**
| Métrica | Cálculo | Fonte |
|---------|---------|-------|
| Custo por Lead Qualificado | Investimento CoreAdapt ÷ Leads qualificados | Calculado |
| Custo por Reunião | Investimento ÷ Reuniões agendadas | Calculado |
| ROI | (Receita gerada - Custo) ÷ Custo | Input manual de fechamentos |
| Receita Estimada | Reuniões × Taxa fechamento × Ticket médio | Calculado |

---

## Tabelas de Suporte para Analytics

### Views SQL para Superset

```sql
-- View: Funil Completo
CREATE OR REPLACE VIEW vw_analytics_funnel AS
SELECT
    e.id as empresa_id,
    e.name as empresa_nome,
    DATE_TRUNC('day', p.created_at) as data,
    COUNT(DISTINCT p.id) as total_prospects,
    COUNT(DISTINCT CASE WHEN p.status IN ('contacted', 'engaged', 'qualified', 'converted') THEN p.id END) as contatados,
    COUNT(DISTINCT CASE WHEN p.status IN ('engaged', 'qualified', 'converted') THEN p.id END) as engajados,
    COUNT(DISTINCT CASE WHEN p.status IN ('qualified', 'converted') THEN p.id END) as qualificados,
    COUNT(DISTINCT CASE WHEN p.status = 'converted' THEN p.id END) as agendados
FROM corev4_prospects p
JOIN corev4_empresas e ON p.empresa_id = e.id
GROUP BY e.id, e.name, DATE_TRUNC('day', p.created_at);

-- View: Métricas de Campanha
CREATE OR REPLACE VIEW vw_analytics_campaigns AS
SELECT
    c.id as campaign_id,
    c.name as campaign_name,
    c.empresa_id,
    COUNT(ce.id) as total_envios,
    SUM(CASE WHEN ce.delivery_status = 'delivered' THEN 1 ELSE 0 END) as entregues,
    SUM(CASE WHEN ce.response_type = 'opt_in' THEN 1 ELSE 0 END) as opt_ins,
    SUM(CASE WHEN ce.response_type = 'opt_out' THEN 1 ELSE 0 END) as opt_outs,
    ROUND(100.0 * SUM(CASE WHEN ce.delivery_status = 'delivered' THEN 1 ELSE 0 END) / NULLIF(COUNT(ce.id), 0), 2) as taxa_entrega,
    ROUND(100.0 * SUM(CASE WHEN ce.response_type = 'opt_in' THEN 1 ELSE 0 END) / NULLIF(COUNT(ce.id), 0), 2) as taxa_engajamento
FROM corev4_outbound_campaigns c
LEFT JOIN corev4_campaign_executions ce ON c.id = ce.campaign_id
GROUP BY c.id, c.name, c.empresa_id;

-- View: Métricas de Agendamento
CREATE OR REPLACE VIEW vw_analytics_meetings AS
SELECT
    m.empresa_id,
    DATE_TRUNC('week', m.scheduled_at) as semana,
    COUNT(*) as total_agendados,
    SUM(CASE WHEN m.confirmed = true THEN 1 ELSE 0 END) as confirmados,
    SUM(CASE WHEN m.attended = true THEN 1 ELSE 0 END) as compareceram,
    SUM(CASE WHEN m.attended = false AND m.scheduled_at < NOW() THEN 1 ELSE 0 END) as no_shows,
    ROUND(100.0 * SUM(CASE WHEN m.attended = true THEN 1 ELSE 0 END) /
          NULLIF(SUM(CASE WHEN m.scheduled_at < NOW() THEN 1 ELSE 0 END), 0), 2) as taxa_comparecimento
FROM corev4_meetings m
GROUP BY m.empresa_id, DATE_TRUNC('week', m.scheduled_at);

-- View: Qualificação ANUM
CREATE OR REPLACE VIEW vw_analytics_anum AS
SELECT
    l.empresa_id,
    DATE_TRUNC('month', qr.created_at) as mes,
    AVG(qr.authority_score) as avg_authority,
    AVG(qr.need_score) as avg_need,
    AVG(qr.urgency_score) as avg_urgency,
    AVG(qr.money_score) as avg_money,
    AVG(qr.total_score) as avg_total_score,
    COUNT(*) as total_qualificados
FROM corev4_qualification_results qr
JOIN corev4_leads l ON qr.lead_id = l.id
GROUP BY l.empresa_id, DATE_TRUNC('month', qr.created_at);
```

### Tabela Auxiliar: Métricas Diárias (Materializada)

```sql
-- Tabela para performance (atualizada por cron)
CREATE TABLE corev4_daily_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    empresa_id UUID NOT NULL,
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

-- Index para queries
CREATE INDEX idx_daily_metrics_empresa_date ON corev4_daily_metrics(empresa_id, date DESC);
```

---

## Implementação Step-by-Step

### Fase 1: Setup Superset (1 dia)

```bash
# 1. Clone Superset
git clone https://github.com/apache/superset.git
cd superset

# 2. Configure docker-compose para produção
cp docker-compose-non-dev.yml docker-compose.yml

# 3. Configure variáveis de ambiente
cat > docker/.env-local << EOF
SUPERSET_SECRET_KEY=$(openssl rand -base64 42)
DATABASE_HOST=seu-host-supabase.supabase.co
DATABASE_PORT=5432
DATABASE_DB=postgres
DATABASE_USER=postgres
DATABASE_PASSWORD=sua-senha
EOF

# 4. Start
docker-compose up -d
```

### Fase 2: Configurar Multi-tenancy (1 dia)

```python
# superset_config.py - Row Level Security

# Função que retorna o empresa_id do usuário logado
def get_user_empresa_id():
    from flask import g
    return getattr(g, 'user', {}).empresa_id

# Aplicar RLS em todas as tabelas
RLS_POLICIES = {
    "corev4_prospects": "empresa_id = {{ current_user_empresa_id() }}",
    "corev4_leads": "empresa_id = {{ current_user_empresa_id() }}",
    "corev4_meetings": "empresa_id = {{ current_user_empresa_id() }}",
    # ... outras tabelas
}
```

### Fase 3: Criar Dashboards (1-2 dias)

1. Conectar Supabase como Database
2. Criar Datasets a partir das Views
3. Montar charts e dashboards
4. Configurar filtros globais (período, campanha)
5. Testar com dados reais

### Fase 4: Embedding (1 dia)

```javascript
// Portal CoreAdapt - Embed Superset
import { embedDashboard } from "@superset-ui/embedded-sdk";

const embedSupersetDashboard = async (dashboardId, containerId) => {
  const response = await fetch('/api/superset/guest-token', {
    method: 'POST',
    body: JSON.stringify({ dashboard_id: dashboardId })
  });
  const { token } = await response.json();

  embedDashboard({
    id: dashboardId,
    supersetDomain: "https://analytics.coreadapt.com",
    mountPoint: document.getElementById(containerId),
    fetchGuestToken: () => token,
    dashboardUiConfig: {
      hideTitle: true,
      hideChartControls: false,
      filters: {
        expanded: false,
      }
    }
  });
};
```

---

## Alertas Automatizados

### Configurar no Superset

| Alerta | Condição | Ação |
|--------|----------|------|
| Taxa Entrega Baixa | delivery_rate < 90% | Email + Slack |
| Opt-out Alto | opt_out_rate > 5% | Email imediato |
| No-show Alto | no_show_rate > 20% | Email |
| Warmup Parado | dias_sem_envio > 2 | Email |
| Gargalo Qualificação | qualified_rate < 30% | Revisão semanal |

---

## Custo Total de Operação

| Item | Custo/mês |
|------|-----------|
| Superset (self-hosted) | R$ 0 |
| VPS para Superset (4GB RAM) | ~R$ 80-150 |
| Supabase (já existe) | R$ 0 adicional |
| **Total** | **R$ 80-150/mês** |

Comparativo:
- Metabase Cloud: $500/mês = ~R$ 2.500/mês
- Economia: **R$ 2.350/mês ou R$ 28.000/ano**

---

## Alternativa Simplificada: Metabase Self-Hosted

Se preferir Metabase pela interface mais simples:

```bash
# Deploy Metabase grátis (self-hosted)
docker run -d -p 3000:3000 \
  -e "MB_DB_TYPE=postgres" \
  -e "MB_DB_DBNAME=metabase" \
  -e "MB_DB_PORT=5432" \
  -e "MB_DB_USER=postgres" \
  -e "MB_DB_PASS=senha" \
  -e "MB_DB_HOST=host" \
  metabase/metabase
```

**Limitações do Metabase grátis:**
- Sem embedding nativo (precisa de iframe manual)
- RLS mais limitado
- Sem SSO

---

## Conclusão

**Recomendação final: Apache Superset**

Razões:
1. **Zero custo de licença** vs R$ 2.500/mês do Metabase Cloud
2. **Multi-tenant robusto** com Row-Level Security nativo
3. **Embedding grátis** para portal do cliente
4. **Longevidade garantida** pela Apache Foundation
5. **Visualizações ricas** (60+ tipos de charts)
6. **Comunidade ativa** (50k+ stars no GitHub)

O investimento de 3-5 dias para setup resulta em economia de R$ 28k+/ano e uma solução enterprise-grade para os clientes CoreAdapt.

---

**Próximo passo:** Aprovar esta recomendação e iniciar setup do Superset.
