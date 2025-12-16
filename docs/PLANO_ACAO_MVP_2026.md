# Plano de Ação — CoreAdapt 2026

**Versão:** 1.0
**Data:** 2025-12-16
**Status:** Proposta

---

## Visão do Produto

**CoreAdapt** = Sistema completo de SDR autônomo para WhatsApp Business

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        COREADAPT - SOLUÇÃO COMPLETA                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐     │
│  │ PROSPECÇÃO  │ → │  PROATIVO   │ → │  RECEPTIVO  │ → │   GESTÃO    │     │
│  │ (Formar     │   │ (Engajar    │   │ (Qualificar │   │   (CRM +    │     │
│  │  Listas)    │   │  Listas)    │   │  + Agendar) │   │  Tracking)  │     │
│  └─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘     │
│         │                │                 │                 │              │
│         ▼                ▼                 ▼                 ▼              │
│  • Google Maps     • First Touch    • CoreOne         • Chatwoot          │
│  • LinkedIn        • Opt-in/Out     • Sync (ANUM)     • HubSpot           │
│  • Concorrentes    • Nutrição       • Sentinel        • Pipedrive         │
│                    • Warmup         • Agendamento     • Notion            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Nomenclatura de Agentes

| Agente | Tipo | Função |
|--------|------|--------|
| **CoreOne** | Receptivo | Agente de conversa principal (FRANK, LIS, etc.) |
| **Sync** | Receptivo | Qualificação ANUM |
| **Sentinel** | Receptivo | Follow-up de leads parados |
| **Prospector** | Proativo | Formação de listas via APIs |
| **Hunter** | Proativo | Primeiro contato + opt-in |
| **Nurturer** | Proativo | Nutrição de leads engajados |

---

## Timeline de Implementação

```
         DEZ 2025                           JAN 2026
    ├────────────────────┤ ├─────────────────────────────────────────────┤
    16    20    25    31   05    10    15    20    25    31
    │─────│─────│─────│────│─────│─────│─────│─────│─────│
    │◄─── MVP 15 DIAS ───►│◄──────── FASE 2: COMPLETO ────────────────►│
```

---

## FASE 1: MVP (16/12 - 31/12) — 15 dias

### Objetivo
Sistema proativo básico funcionando: formar lista via Google Maps, contatar leads, processar opt-in/out.

### Entregáveis

#### Semana 1 (16-22/12): Infraestrutura + Prospecção

**Dia 1-2: Tabelas de Banco**
- [ ] Criar tabela `corev4_prospects` (leads de outbound)
- [ ] Criar tabela `corev4_outbound_campaigns` (campanhas)
- [ ] Criar tabela `corev4_campaign_executions` (execuções)
- [ ] Criar tabela `corev4_blocklist` (opt-outs)

**Dia 3-4: Prospector Flow (Google Maps)**
- [ ] Configurar conta RapidAPI + Local Business Data API
- [ ] Criar n8n flow: Prospector Flow
  - Input: Cidade + Nicho + Raio
  - Process: Chamar API → Parse resultados → Normalizar dados
  - Output: Insert em `corev4_prospects`
- [ ] Testar com 100 leads de uma cidade

**Dia 5-7: List Validation + Import**
- [ ] Criar n8n flow: List Validation Flow
  - Validar formato de telefone (55XXXXXXXXXXX)
  - Verificar duplicatas
  - Check WhatsApp via Evolution API
  - Atribuir prospect_score
- [ ] Criar n8n flow: List Import Flow (Google Sheets)
  - Para listas que cliente já tem

#### Semana 2 (23-31/12): Prospecção Ativa

**Dia 8-10: Warmup + First Touch**
- [ ] Criar tabela `corev4_warmup_status`
- [ ] Criar n8n flow: Warmup Monitor Flow (básico)
  - Controlar volume diário
  - Pausar se delivery < 90%
- [ ] Criar n8n flow: First Touch Flow
  - Enviar mensagem com botões (Evolution API)
  - Registrar envio em `corev4_campaign_executions`

**Dia 11-12: Opt-in Handler**
- [ ] Criar tabela `corev4_consent_log`
- [ ] Criar n8n flow: Opt-in Handler Flow
  - Processar resposta de botões
  - Opt-in → Marcar como engajado
  - Opt-out → Mover para blocklist
  - Texto livre → Analisar sentimento

**Dia 13-15: Handoff + Testes**
- [ ] Criar n8n flow: Handoff Flow
  - Transferir lead engajado para CoreOne
  - Passar contexto da campanha
- [ ] Modificar Main Router para detectar leads proativos
- [ ] Testes E2E completos
- [ ] Documentação de operação

### Diagrama MVP

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           MVP - 15 DIAS                                      │
├─────────────────────────────────────────────────────────────────────────────┤

                    ┌─────────────────┐
                    │  PROSPECTOR     │ ◄─── Google Maps API
                    │  FLOW           │      (Local Business Data)
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  LIST           │ ◄─── Também aceita
                    │  VALIDATION     │      Google Sheets
                    └────────┬────────┘
                             │
                             ▼
           ┌─────────────────────────────────────┐
           │  corev4_prospects (status=valid)    │
           └─────────────────┬───────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  WARMUP         │ ◄─── Controle de volume
                    │  MONITOR        │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  FIRST TOUCH    │ ──── Mensagem com botões
                    │  FLOW           │      via Evolution API
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
           ┌────────│  OPT-IN         │────────┐
           │        │  HANDLER        │        │
           │        └─────────────────┘        │
           │                                   │
           ▼                                   ▼
    ┌─────────────┐                    ┌─────────────┐
    │  BLOCKLIST  │                    │  HANDOFF    │
    │  (opt-out)  │                    │  FLOW       │
    └─────────────┘                    └──────┬──────┘
                                              │
                                              ▼
                                       ┌─────────────┐
                                       │  COREONE    │
                                       │  (FRANK)    │
                                       └─────────────┘
```

---

## FASE 2: Sistema Completo (01/01 - 31/01) — 30 dias

### Semana 3-4 (01-15/01): LinkedIn + Nutrição

**LinkedIn via Unipile:**
- [ ] Configurar conta Unipile (€5/conta/mês)
- [ ] Criar n8n flow: LinkedIn Prospector Flow
  - Buscar perfis por título/empresa
  - Extrair dados de contato
  - Enriquecer prospects existentes
- [ ] Implementar rate limits (80-100 invites/dia)

**Nurture Engine:**
- [ ] Criar tabela `corev4_message_templates`
- [ ] Criar n8n flow: Nurture Engine Flow
  - Sequência de 5 touches
  - Cadência configurável
  - Exit automático se responder
- [ ] Criar templates padrão de nutrição

### Semana 5-6 (16-25/01): Integrações CRM

**Chatwoot (CRM Nativo):**
- [ ] Deploy Chatwoot (self-hosted ou cloud)
- [ ] Integrar via API
- [ ] Sincronizar leads e conversas

**CRMs de Mercado (top 5):**
- [ ] HubSpot integration
- [ ] Pipedrive integration
- [ ] RD Station integration
- [ ] Salesforce integration (básico)
- [ ] Notion Kanban integration

### Semana 7 (26-31/01): Polimento + Docs

**Google Calendar Direto:**
- [ ] Implementar integração real (substituir Cal.com)
- [ ] Atualizar Availability Flow
- [ ] Atualizar Booking Flow

**Documentação + Playbooks:**
- [ ] Playbook de implantação (7-10 dias)
- [ ] Templates de campanha por vertical
- [ ] Scripts de configuração automática
- [ ] Treinamento

---

## APIs e Custos

### Prospecção

| API | Uso | Custo Estimado |
|-----|-----|----------------|
| **Local Business Data** (RapidAPI) | Google Maps | $50-100/mês (1000 req) |
| **Unipile** | LinkedIn | €5/conta/mês |

**Links:**
- Local Business Data: https://rapidapi.com/letscrape-6bRBa3QguO5/api/local-business-data
- Unipile: https://www.unipile.com/communication-api/messaging-api/linkedin-api/

### Unipile - Detalhes

Funcionalidades:
- Buscar perfis por título/empresa/localização
- Enviar connection requests com mensagem
- Sync inbox de mensagens
- Data enrichment (email, telefone)

Limites recomendados:
- 80-100 invitations/dia
- 100-150 messages/dia
- Funciona com LinkedIn Classic, Premium, Recruiter, Sales Navigator

### Local Business Data - Detalhes

Funcionalidades:
- Buscar negócios por localização + keyword
- Retorna: nome, endereço, telefone, website, rating, reviews
- Pode filtrar por raio, tipo de negócio

Exemplo de query:
```
GET /search?query=dentistas&lat=-23.5505&lng=-46.6333&limit=100&zoom=13
```

---

## Fluxos n8n - Resumo Final

### Novos (MVP - 6 fluxos)
| # | Flow | Trigger |
|---|------|---------|
| 1 | **Prospector Flow** | Manual/Cron |
| 2 | **List Import Flow** | Webhook/Manual |
| 3 | **List Validation Flow** | Após import |
| 4 | **Warmup Monitor Flow** | Cron (4h) |
| 5 | **First Touch Flow** | Cron/Manual |
| 6 | **Opt-in Handler Flow** | Webhook (resposta) |
| 7 | **Handoff Flow** | Após opt-in |

### Novos (Fase 2 - 4 fluxos)
| # | Flow | Trigger |
|---|------|---------|
| 8 | **LinkedIn Prospector Flow** | Manual/Cron |
| 9 | **Nurture Engine Flow** | Cron |
| 10 | **CRM Sync Flow** | Cron/Webhook |
| 11 | **List Cleanup Flow** | Cron semanal |

### Existentes (mantidos)
- Main Router Flow
- Genesis Flow
- One Flow (CoreOne)
- Sync Flow
- Sentinel Flow
- Scheduler Flow (→ deprecar após Google Calendar)
- Availability Flow
- Booking Flow
- Meeting Reminders Flow

---

## Tabelas de Banco - Resumo

### MVP (4 tabelas)
```sql
corev4_prospects          -- Leads de outbound
corev4_outbound_campaigns -- Campanhas
corev4_campaign_executions-- Execuções
corev4_blocklist          -- Opt-outs
```

### Fase 2 (3 tabelas adicionais)
```sql
corev4_consent_log        -- Registro LGPD
corev4_warmup_status      -- Status de aquecimento
corev4_message_templates  -- Templates de mensagem
```

---

## Checklist de Implantação (7-10 dias por cliente)

### Dia 1-2: Discovery
- [ ] Entender negócio do cliente
- [ ] Definir ICP (Ideal Customer Profile)
- [ ] Definir estratégia de formação de lista
- [ ] Coletar lista existente (se houver)

### Dia 3-4: Setup Técnico
- [ ] Criar empresa no banco
- [ ] Configurar Evolution API
- [ ] Configurar credenciais de APIs (RapidAPI, etc.)
- [ ] Importar/formar lista inicial

### Dia 5-6: Configuração de Agentes
- [ ] Programar CoreOne (tom, persona, qualificação)
- [ ] Programar Sync (critérios ANUM específicos)
- [ ] Programar Sentinel (cadência, mensagens)
- [ ] Criar templates de First Touch

### Dia 7-8: Warmup
- [ ] Iniciar warmup da instância
- [ ] Monitorar taxas
- [ ] Ajustar se necessário

### Dia 9-10: Go Live
- [ ] Ativar prospecção
- [ ] Monitorar primeiros contatos
- [ ] Ajustes finos
- [ ] Handover para operação

---

## Próximos Passos Imediatos

**Hoje (16/12):**
1. Criar migrations das 4 tabelas do MVP
2. Configurar RapidAPI + Local Business Data
3. Criar Prospector Flow (estrutura básica)

**Amanhã (17/12):**
1. Testar API com query real
2. Criar List Validation Flow
3. Testar fluxo completo de prospecção → validação

**Esta semana:**
1. First Touch Flow com botões
2. Opt-in Handler
3. Handoff para CoreOne

---

**Próximo passo:** Aprovar este plano e iniciar implementação do MVP.
