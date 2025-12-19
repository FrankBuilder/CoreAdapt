# CoreAdapt — Guia Técnico Completo

**Documento de referência para implementação e onboarding**

**Versão:** 2.0
**Data:** 19 de Dezembro de 2025
**Status:** Documento de Trabalho

---

## Índice

1. [Visão Geral do Sistema](#1-visão-geral-do-sistema)
2. [Fluxos Existentes (12 fluxos)](#2-fluxos-existentes)
3. [Novos Fluxos a Construir (13 itens)](#3-novos-fluxos-a-construir)
4. [Integrações e Conexões](#4-integrações-e-conexões)
5. [Banco de Dados](#5-banco-de-dados)
6. [Agendamento Autônomo (Detalhado)](#6-agendamento-autônomo)
7. [Plano de Implementação](#7-plano-de-implementação)
8. [Checklist de Validação](#8-checklist-de-validação)

---

## 1. Visão Geral do Sistema

### 1.1 O que é o CoreAdapt

CoreAdapt é uma plataforma de **SDR autônomo** que automatiza todo o ciclo de pré-venda via WhatsApp:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          COREADAPT — ARQUITETURA                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   🔍 PROATIVO (NOVO)              🤖 RECEPTIVO (EXISTE)                      │
│   ─────────────────               ────────────────────                       │
│   • Formar listas                 • Receber mensagens                        │
│   • Validar prospects             • Qualificar leads (ANUM)                  │
│   • Primeiro contato              • Responder com IA                         │
│   • Opt-in/Opt-out                • Follow-up automático                     │
│   • Nutrição                      • Agendar reuniões                         │
│                                                                              │
│                         ┌─────────────────┐                                  │
│                         │    HANDOFF      │                                  │
│                         │  (ponte entre   │                                  │
│                         │   os mundos)    │                                  │
│                         └─────────────────┘                                  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Tecnologias Utilizadas

| Tecnologia | Uso |
|------------|-----|
| **n8n** | Orquestração de workflows |
| **PostgreSQL/Supabase** | Banco de dados principal |
| **Evolution API** | Integração WhatsApp |
| **Google Gemini/OpenAI** | IA para conversação e análise |
| **Google Calendar API** | Agendamento (novo) |
| **RapidAPI** | APIs de prospecção |

### 1.3 Nomenclatura dos Agentes

| Agente | Tipo | O que faz |
|--------|------|-----------|
| **CoreOne (FRANK)** | Receptivo | Conversa principal, qualifica, responde |
| **Sync** | Receptivo | Análise ANUM após conversas |
| **Sentinel** | Receptivo | Follow-up de leads inativos |
| **Prospector** | Proativo | Forma listas via APIs |
| **Hunter** | Proativo | Primeiro contato com botões |
| **Nurturer** | Proativo | Nutrição de leads frios |

---

## 2. Fluxos Existentes

### 2.1 Mapa dos Fluxos Atuais

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     FLUXOS RECEPTIVOS EXISTENTES (12)                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                           WhatsApp (Evolution API)                           │
│                                    │                                         │
│                                    ▼                                         │
│                        ┌───────────────────────┐                            │
│                        │    MAIN ROUTER        │                            │
│                        │    (orquestrador)     │                            │
│                        └───────────┬───────────┘                            │
│                                    │                                         │
│           ┌────────────────────────┼────────────────────────┐               │
│           │                        │                        │               │
│           ▼                        ▼                        ▼               │
│   ┌───────────────┐      ┌───────────────┐      ┌───────────────┐          │
│   │    GENESIS    │      │   ONE FLOW    │      │   COMMANDS    │          │
│   │ (novo contato)│      │   (conversa)  │      │  (comandos #) │          │
│   └───────┬───────┘      └───────┬───────┘      └───────────────┘          │
│           │                      │                                          │
│           │                      ▼                                          │
│           │              ┌───────────────┐                                  │
│           │              │  SYNC FLOW    │                                  │
│           │              │    (ANUM)     │                                  │
│           │              └───────┬───────┘                                  │
│           │                      │                                          │
│           ▼                      ▼                                          │
│   ┌───────────────┐      ┌───────────────┐      ┌───────────────┐          │
│   │   FOLLOWUP    │      │   SENTINEL    │      │  SCHEDULER*   │          │
│   │   CAMPAIGN    │      │  (follow-up)  │      │  (Cal.com)    │          │
│   └───────────────┘      └───────────────┘      └───────┬───────┘          │
│                                                         │                   │
│                                                         ▼                   │
│                                                 ┌───────────────┐          │
│                                                 │   REMINDERS   │          │
│                                                 │  (lembretes)  │          │
│                                                 └───────────────┘          │
│                                                                              │
│   * Scheduler Flow será DEPRECADO e substituído pelo agendamento autônomo   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### 2.2 Detalhamento de Cada Fluxo Existente

---

#### **FLUXO 1: MAIN ROUTER FLOW**

**Arquivo:** `CoreAdapt Main Router Flow _ v4.json`
**ID n8n:** `8Yip7wZKcGEYTgoo`

**Função:** Orquestrador central. Recebe TODOS os webhooks do WhatsApp e decide para onde rotear.

**Trigger:** Webhook HTTP POST em `/core-adapt-v4`

**O que faz:**
```
1. Recebe webhook da Evolution API
2. Normaliza dados (chama Normalize Evolution)
3. Valida mensagem (não é broadcast, é do lead)
4. Deduplicação em janela de 5 segundos
5. Busca contato no banco
6. Decide destino:
   - Contato NOVO → Genesis Flow
   - Contato BLOQUEADO → Reactivate Flow
   - Comando (#listar, #limpar) → Commands Flow
   - Contato ATIVO → One Flow
```

**Integrações:**
- Evolution API (webhook)
- PostgreSQL: `corev4_message_dedup`, `corev4_contacts`, `corev4_contact_extras`
- Sub-fluxos: Normalize, Genesis, One, Commands, Reactivate

**Input exemplo:**
```json
{
  "body": {
    "data": {
      "message": { "conversation": "Olá, quero saber mais" },
      "key": { "remoteJid": "5585999001234@s.whatsapp.net", "fromMe": false },
      "pushName": "João Silva"
    },
    "instance": "minha_instancia"
  }
}
```

**Por que existe:** Centraliza toda a entrada do sistema, garantindo que mensagens sejam processadas corretamente sem duplicação.

---

#### **FLUXO 2: NORMALIZE EVOLUTION API**

**Arquivo:** `Normalize Evolution API _ v4.json`
**ID n8n:** `lO3F2ESDmnRVMaBz`

**Função:** Padroniza dados brutos da Evolution API para formato consistente.

**Trigger:** Chamado pelo Main Router

**O que faz:**
```
1. Extrai conteúdo da mensagem (texto, caption, mídia)
2. Identifica tipo (text, image, audio, video, document)
3. Normaliza WhatsApp ID
4. Extrai metadados (timestamp, nome, is_from_me)
```

**Output exemplo:**
```json
{
  "message_content": "Olá, quero saber mais",
  "message_type": "text",
  "whatsapp_id": "5585999001234@s.whatsapp.net",
  "contact_name": "João Silva",
  "is_from_me": false,
  "sender_type": "user"
}
```

**Por que existe:** Evolution API tem estrutura complexa com múltiplos formatos. Este fluxo garante consistência para os demais.

---

#### **FLUXO 3: GENESIS FLOW**

**Arquivo:** `CoreAdapt Genesis Flow _ v4.json`
**ID n8n:** `FkBpLfoPH1oHhWGa`

**Função:** Cria novo lead no sistema quando contato desconhecido envia primeira mensagem.

**Trigger:** Chamado pelo Main Router quando contato não existe

**O que faz:**
```
1. Insere em corev4_contacts (nome, whatsapp, phone)
2. Cria corev4_lead_state (qualification_stage='pre', status='ativo')
3. Cria corev4_contact_extras (preferências de resposta)
4. Salva primeira mensagem no histórico
5. Cria campanha de followup (5 steps)
6. Envia para One Flow processar
```

**Tabelas afetadas:**
- `corev4_contacts` (INSERT)
- `corev4_lead_state` (INSERT)
- `corev4_contact_extras` (INSERT)
- `corev4_followup_campaigns` (INSERT via sub-fluxo)
- `corev4_followup_executions` (INSERT via sub-fluxo)

**Por que existe:** Garante que todo novo lead seja registrado corretamente com todos os dados necessários para qualificação e follow-up.

---

#### **FLUXO 4: ONE FLOW (CoreOne/FRANK)**

**Arquivo:** `CoreAdapt One Flow _ v4.json`
**ID n8n:** `pvMsb1uQbB0E3LAF`

**Função:** Processador principal de conversas. A IA (FRANK) responde, qualifica e gerencia a conversa.

**Trigger:** Chamado pelo Main Router para contatos ativos

**O que faz:**
```
1. Busca histórico do chat (últimas 20 mensagens)
2. Prepara contexto para IA (ANUM score, pain category, histórico)
3. Chama Gemini/OpenAI para gerar resposta
4. Parseia resposta da IA
5. Executa ação:
   - RESPOND: Envia resposta via WhatsApp
   - QUALIFY: Chama Sync Flow para atualizar ANUM
   - ESCALATE: Oferece Mesa de Clareza
6. Salva mensagem no histórico
```

**IA Utilizada:**
- **Primária:** Google Gemini
- **Fallback:** OpenAI GPT-4

**Integrações:**
- Evolution API (enviar mensagem)
- PostgreSQL: `corev4_n8n_chat_histories`, `corev4_messages`
- Sync Flow (quando precisa atualizar ANUM)

**Por que existe:** É o "cérebro" do sistema receptivo. Toda conversa passa por aqui.

---

#### **FLUXO 5: SYNC FLOW (Análise ANUM)**

**Arquivo:** `CoreAdapt Sync Flow _ v4.json`
**ID n8n:** `8F6DWDbmaPCZrI18`

**Função:** Análise contínua de leads usando metodologia ANUM (Authority, Need, Urgency, Money).

**Trigger:** Chamado pelo One Flow quando IA decide analisar

**O que faz:**
```
1. Busca histórico completo do chat
2. Busca estado atual do ANUM
3. Prepara contexto para análise
4. IA especializada analisa conversa
5. Extrai scores ANUM (0-100 cada)
6. Identifica categoria de dor (pain_category)
7. Salva em corev4_anum_history
8. Atualiza corev4_lead_state
```

**Metodologia ANUM:**

| Dimensão | Escala | Significado |
|----------|--------|-------------|
| **A**uthority | 0-100 | Poder de decisão (CEO=90, Gerente=60, Técnico=30) |
| **N**eed | 0-100 | Intensidade do problema (Crítico=90, Importante=70) |
| **U**rgency | 0-100 | Timeline (≤7 dias=90, ≤30 dias=70, ≤90 dias=50) |
| **M**oney | 0-100 | Budget disponível (≥R$50k=90, R$20-50k=70) |

**Qualification Stages:**
- `pre` (score < 40): Pré-qualificado
- `partial` (40-59): Parcialmente qualificado
- `full` (≥60, sem zeros): Totalmente qualificado
- `rejected`: Descualificado

**Por que existe:** Qualificação automática baseada em conversa natural, sem formulários.

---

#### **FLUXO 6: SENTINEL FLOW**

**Arquivo:** `CoreAdapt Sentinel Flow _ v4.json`
**ID n8n:** `2JLewCzOOvJvVI2X`

**Função:** Motor de follow-ups automáticos. Reengaja leads que pararam de responder.

**Trigger:** Scheduler (cron) a cada 5 minutos

**O que faz:**
```
1. Busca followups pendentes (SQL complexa)
2. Para cada followup:
   - Verifica timing (wait_hours passou?)
   - Verifica ANUM (< 70?)
   - Verifica horário comercial (8h-20h)
   - Verifica dia útil (seg-sex)
3. Faz lock pessimista (evita duplicação)
4. IA gera mensagem personalizada
5. Envia via WhatsApp
6. Marca como enviado
```

**Estratégia de Steps:**

| Step | Timing | Objetivo |
|------|--------|----------|
| 1 | ~1h | Reengajamento suave |
| 2 | ~1 dia | Agregar valor |
| 3 | ~3 dias | Urgência sutil |
| 4 | ~6 dias | Última chance |
| 5 | ~13 dias | Despedida graciosa |

**Por que existe:** Recupera 20-35% dos leads que param de responder.

---

#### **FLUXO 7: SCHEDULER FLOW (Cal.com) — SERÁ DEPRECADO**

**Arquivo:** `CoreAdapt Scheduler Flow _ v4.json`
**ID n8n:** `6yfuYUM0kpjvqWE1`

**Função:** Processa bookings vindos do Cal.com.

**Trigger:** Webhook do Cal.com quando reunião é agendada

**O que faz:**
```
1. Recebe webhook do Cal.com
2. Faz matching de contato (email/phone)
3. Gera resumo via IA
4. Salva reunião em corev4_scheduled_meetings
5. Cancela followups pendentes
6. Envia confirmação ao lead
7. Envia alerta ao Francisco
```

**⚠️ NOTA:** Este fluxo será substituído pelo novo Availability + Booking Flow que usa Google Calendar diretamente.

---

#### **FLUXO 8: AVAILABILITY FLOW**

**Arquivo:** `CoreAdapt Availability Flow _ v4.json`

**Função:** Oferece horários disponíveis para agendamento.

**Trigger:** Webhook quando lead quer agendar

**O que faz (atual - precisa reescrever):**
```
1. Busca configurações de calendário
2. Busca reuniões existentes
3. Gera slots disponíveis com scoring
4. Oferece 3 melhores horários
5. Salva oferta em corev4_pending_slot_offers
```

**⚠️ NOTA:** Precisa ser reescrito para usar Google Calendar API (freeBusy).

---

#### **FLUXO 9: BOOKING FLOW**

**Arquivo:** `CoreAdapt Booking Flow _ v4.json`

**Função:** Confirma seleção de slot e cria reunião.

**Trigger:** Webhook quando lead escolhe horário

**O que faz (atual - precisa reescrever):**
```
1. Busca oferta de slots
2. Valida seleção (1-3)
3. Verifica conflito (double-check)
4. Cria evento no calendário
5. Salva em corev4_scheduled_meetings
6. Cancela followups
7. Envia confirmação
```

**⚠️ NOTA:** Precisa ser reescrito para usar Google Calendar API (events.insert + Meet).

---

#### **FLUXO 10: MEETING REMINDERS FLOW**

**Arquivo:** `CoreAdapt Meeting Reminders Flow _ v4.json`
**ID n8n:** `8Tc6hc3zr61weBFl`

**Função:** Envia lembretes de reunião (24h e 1h antes).

**Trigger:** Scheduler (cron) a cada hora

**O que faz:**
```
1. Busca reuniões que precisam de lembrete
2. Para cada reunião:
   - 24h antes: Envia lembrete suave
   - 1h antes: Envia lembrete urgente
3. Atualiza flags (reminder_24h_sent, reminder_1h_sent)
```

**Por que existe:** Reduz no-show de 30% para <15%.

---

#### **FLUXOS AUXILIARES (3)**

**11. Process Audio Message:** Transcreve áudios via Whisper/Google Speech

**12. Create Followup Campaign:** Cria campanha de 5 steps para novo lead

**13. Reactivate Blocked Contact:** Reativa contatos que voltaram após opt-out

---

## 3. Novos Fluxos a Construir

### 3.1 Visão Geral dos Novos Fluxos

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      NOVOS FLUXOS A IMPLEMENTAR (13)                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   PROATIVO (10 fluxos)                    AGENDAMENTO AUTÔNOMO (3)          │
│   ───────────────────                     ───────────────────────           │
│                                                                              │
│   ┌─────────────────┐                    ┌─────────────────┐                │
│   │ 1. PROSPECTOR   │                    │ 11. AVAILABILITY│                │
│   │    (Google Maps)│                    │     (Google Cal)│                │
│   └────────┬────────┘                    └────────┬────────┘                │
│            │                                      │                         │
│   ┌────────▼────────┐                    ┌────────▼────────┐                │
│   │ 2. LINKEDIN     │                    │ 12. BOOKING     │                │
│   │    PROSPECTOR   │                    │     (Google Cal)│                │
│   └────────┬────────┘                    └────────┬────────┘                │
│            │                                      │                         │
│   ┌────────▼────────┐                    ┌────────▼────────┐                │
│   │ 3. LIST IMPORT  │                    │ 13. COREONE     │                │
│   │    FLOW         │                    │     (atualizar) │                │
│   └────────┬────────┘                    └─────────────────┘                │
│            │                                                                │
│   ┌────────▼────────┐                                                       │
│   │ 4. LIST         │                                                       │
│   │    VALIDATION   │                                                       │
│   └────────┬────────┘                                                       │
│            │                                                                │
│   ┌────────▼────────┐                                                       │
│   │ 5. CAMPAIGN     │                                                       │
│   │    ORCHESTRATOR │                                                       │
│   └────────┬────────┘                                                       │
│            │                                                                │
│   ┌────────▼────────┐                                                       │
│   │ 6. WARMUP       │                                                       │
│   │    MONITOR      │                                                       │
│   └────────┬────────┘                                                       │
│            │                                                                │
│   ┌────────▼────────┐                                                       │
│   │ 7. FIRST TOUCH  │                                                       │
│   │    FLOW         │                                                       │
│   └────────┬────────┘                                                       │
│            │                                                                │
│   ┌────────▼────────┐                                                       │
│   │ 8. OPT-IN       │                                                       │
│   │    HANDLER      │                                                       │
│   └────────┬────────┘                                                       │
│            │                                                                │
│   ┌────────▼────────┐                                                       │
│   │ 9. NURTURE      │                                                       │
│   │    ENGINE       │                                                       │
│   └────────┬────────┘                                                       │
│            │                                                                │
│   ┌────────▼────────┐                                                       │
│   │ 10. HANDOFF     │────────────────────► MAIN ROUTER (existente)          │
│   │     FLOW        │                                                       │
│   └─────────────────┘                                                       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### 3.2 Detalhamento de Cada Novo Fluxo

---

#### **NOVO FLUXO 1: PROSPECTOR FLOW (Google Maps)**

**Objetivo:** Buscar empresas em APIs externas e popular `corev4_prospects`.

**Trigger:** Manual ou Cron (ex: diário)

**Base existente:** `Agente Prospect Busca Google Maps.json` (no main branch)

**O que deve fazer:**
```
1. Receber parâmetros:
   - termo_busca: "Dentistas em Fortaleza"
   - company_id: 1
   - campaign_id: (opcional)
   - limit: 500

2. Chamar RapidAPI Local Business Search:
   - Endpoint: local-business-search.p.rapidapi.com/search
   - Retorna: nome, telefone, endereço, rating, website

3. Para cada resultado:
   - Fazer scraping do site (via Scraptio)
   - Gerar resumo via IA (para prospecção)

4. Salvar em corev4_prospects:
   - status = 'new'
   - source_type = 'google_maps'
   - Normalizar telefone (55XXXXXXXXXXX)

5. Disparar List Validation Flow
```

**Integrações:**
- RapidAPI (Local Business Search)
- Scraptio (scraping de sites)
- OpenAI/Gemini (resumo)
- PostgreSQL: `corev4_prospects`

**Ajustes necessários no fluxo existente:**
- [ ] Mudar destino de Google Sheets → PostgreSQL
- [ ] Adicionar campaign_id
- [ ] Normalizar formato de telefone
- [ ] Adicionar deduplicação
- [ ] Mover API keys para credentials n8n

---

#### **NOVO FLUXO 2: LINKEDIN PROSPECTOR FLOW**

**Objetivo:** Buscar perfis no LinkedIn via Unipile API.

**Trigger:** Manual ou Cron

**O que deve fazer:**
```
1. Receber parâmetros:
   - titulo: "CEO"
   - empresa: "tecnologia"
   - localizacao: "São Paulo"
   - limit: 100

2. Chamar Unipile API:
   - Buscar perfis matching
   - Extrair: nome, cargo, empresa, email, telefone

3. Para cada resultado:
   - Enriquecer com dados adicionais

4. Salvar em corev4_prospects:
   - status = 'new'
   - source_type = 'linkedin'

5. Disparar List Validation Flow
```

**Integrações:**
- Unipile API (€5/conta/mês)
- PostgreSQL: `corev4_prospects`

**Rate limits:**
- 80-100 invitations/dia
- 100-150 messages/dia

**Implementação:** Fase 2 (janeiro)

---

#### **NOVO FLUXO 3: LIST IMPORT FLOW**

**Objetivo:** Importar listas de fontes externas (Google Sheets, CSV).

**Trigger:** Webhook ou Manual

**O que deve fazer:**
```
1. Receber fonte:
   - Google Sheets: sheet_id + range
   - CSV: upload ou URL

2. Parsear dados:
   - Mapear colunas para campos

3. Para cada linha:
   - Normalizar telefone
   - Criar registro em corev4_prospects
   - status = 'new'
   - source_type = 'import'

4. Disparar List Validation Flow
```

**Mapeamento de colunas:**
| Fonte | Campo Interno |
|-------|---------------|
| Nome | full_name |
| Telefone | phone_number |
| Email | email |
| Empresa | company_name |
| Cargo | job_title |

---

#### **NOVO FLUXO 4: LIST VALIDATION FLOW**

**Objetivo:** Validar prospects antes de prospecção ativa.

**Trigger:** Após import/prospecção

**O que deve fazer:**
```
1. Buscar prospects com status = 'new'

2. Para cada prospect:
   a) Validar formato telefone (55 + DDD + 9 dígitos)
   b) Verificar duplicata (já existe no banco?)
   c) Verificar blocklist (já fez opt-out?)
   d) Check WhatsApp ativo (Evolution API checkNumbers)
   e) Calcular prospect_score (0-100)

3. Atualizar status:
   - 'valid' se passou tudo
   - 'invalid_format' se telefone errado
   - 'duplicate' se já existe
   - 'opted_out' se está na blocklist
   - 'no_whatsapp' se não tem WhatsApp
```

**Cálculo do Prospect Score:**
```javascript
score = 0
if (rating >= 4.5) score += 20
if (reviews >= 50) score += 15
if (website) score += 15
if (email) score += 10
if (resumo_ia_qualidade) score += 20
if (cidade_capital) score += 20
// Total máximo: 100
```

---

#### **NOVO FLUXO 5: CAMPAIGN ORCHESTRATOR FLOW**

**Objetivo:** Orquestrar campanhas proativas de ponta a ponta.

**Trigger:** Manual (criar campanha)

**O que deve fazer:**
```
1. Criar campanha em corev4_outbound_campaigns:
   - name, type, status = 'draft'
   - settings (daily_limit, send_hours, warmup_days)
   - goals (target_opt_in_rate, target_meetings)

2. Vincular prospects à campanha:
   - Criar corev4_campaign_executions para cada prospect válido

3. Calcular schedule de warmup:
   - Dia 1-3: 50/dia
   - Dia 4-6: 100/dia
   - Dia 7-10: 250/dia
   - Dia 11+: 500/dia

4. Ativar campanha (status = 'active')

5. Monitorar métricas em tempo real
```

---

#### **NOVO FLUXO 6: WARMUP MONITOR FLOW**

**Objetivo:** Monitorar saúde da instância WhatsApp e ajustar volume.

**Trigger:** Cron a cada 4 horas

**O que deve fazer:**
```
1. Buscar métricas do dia:
   - sent_today
   - delivered_today
   - failed_today
   - blocked_today

2. Calcular taxas:
   - delivery_rate = delivered / sent
   - block_rate = blocked / sent

3. Decidir ação:
   - Se delivery < 90%: Reduzir volume 50%
   - Se block > 2%: Pausar envios
   - Se tudo ok por 3 dias: Aumentar 25%

4. Atualizar corev4_warmup_status

5. Enviar alerta se problema
```

---

#### **NOVO FLUXO 7: FIRST TOUCH FLOW**

**Objetivo:** Enviar primeira mensagem com botões interativos.

**Trigger:** Cron (horário comercial) ou Campaign Orchestrator

**O que deve fazer:**
```
1. Buscar próximos prospects para contatar:
   - status = 'valid'
   - campaign ativa
   - dentro do daily_limit
   - horário comercial (9-12h, 14-18h)

2. Para cada prospect:
   a) Montar mensagem personalizada
   b) Adicionar botões:
      - "✅ Quero saber mais"
      - "❌ Não tenho interesse"
   c) Enviar via Evolution API (sendButtons)
   d) Atualizar campaign_execution:
      - status = 'contacted'
      - first_touch_sent_at = NOW()

3. Respeitar rate limit (delay entre envios)
```

**Payload Evolution API (botões):**
```javascript
{
  "number": "5585999001234",
  "buttonMessage": {
    "title": "CoreConnect.AI",
    "description": "Olá João! 👋\n\nClínicas como a sua estão...",
    "buttons": [
      { "buttonId": "opt_in", "buttonText": { "displayText": "✅ Quero saber mais" }},
      { "buttonId": "opt_out", "buttonText": { "displayText": "❌ Não tenho interesse" }}
    ]
  }
}
```

---

#### **NOVO FLUXO 8: OPT-IN HANDLER FLOW**

**Objetivo:** Processar respostas aos botões (opt-in/opt-out).

**Trigger:** Webhook (resposta de botão ou texto)

**O que deve fazer:**
```
1. Identificar tipo de resposta:
   - Botão: opt_in ou opt_out
   - Texto: analisar sentimento

2. Se OPT-IN:
   - Registrar em corev4_consent_log
   - Atualizar campaign_execution.status = 'opted_in'
   - Decidir próximo passo:
     * ANUM estimado alto → Handoff imediato
     * ANUM estimado baixo → Nurture Engine

3. Se OPT-OUT:
   - Registrar em corev4_consent_log
   - Inserir em corev4_blocklist
   - Atualizar campaign_execution.status = 'opted_out'
   - Nunca mais contatar

4. Se TEXTO LIVRE:
   - Analisar sentimento (IA)
   - Positivo → Tratar como opt-in
   - Negativo → Tratar como opt-out
   - Neutro → Retry em 7 dias
```

---

#### **NOVO FLUXO 9: NURTURE ENGINE FLOW**

**Objetivo:** Executar sequências de nutrição para leads frios.

**Trigger:** Cron (diário)

**O que deve fazer:**
```
1. Buscar prospects em nutrição:
   - opted_in = true
   - handed_off = false
   - não exauriu sequência

2. Para cada prospect:
   a) Identificar próximo touch
   b) Verificar timing (delay passou?)
   c) Gerar mensagem personalizada
   d) Enviar via WhatsApp
   e) Atualizar nurture_history

3. Detectar engajamento:
   - Se responder positivamente → Handoff
   - Se pedir para parar → Opt-out
   - Se completou 5 touches sem resposta → Arquivar
```

**Sequência de Nutrição:**
| Touch | Delay | Conteúdo |
|-------|-------|----------|
| 1 | 0 | Case study relevante |
| 2 | 2 dias | Pergunta sobre dor |
| 3 | 5 dias | Social proof |
| 4 | 10 dias | Oferta de conversa |
| 5 | 15 dias | Última chance |

---

#### **NOVO FLUXO 10: HANDOFF FLOW**

**Objetivo:** Transferir lead engajado do proativo para o receptivo.

**Trigger:** Após opt-in com engajamento alto

**O que deve fazer:**
```
1. Criar/atualizar corev4_contacts:
   - Copiar dados do prospect
   - Marcar origem = 'proactive'

2. Criar corev4_chats:
   - Copiar contexto da campanha
   - Incluir histórico de touches

3. Criar corev4_lead_state:
   - ANUM estimado inicial
   - qualification_stage = 'pre'

4. Atualizar prospect:
   - converted_to_contact_id = novo contact_id
   - status = 'converted'

5. Disparar Main Router:
   - flag handoff = true
   - Passa contexto completo
```

**Contexto passado para CoreOne:**
```json
{
  "handoff_source": "proactive_campaign",
  "campaign_name": "Dentistas Fortaleza Q1",
  "touches_received": 2,
  "engagement_score": 72,
  "enrichment": {
    "rating_google": 4.8,
    "resumo_site": "Clínica com 15 anos..."
  },
  "recommended_approach": "Lead respondeu rápido, abordar direto"
}
```

---

#### **NOVO FLUXO 11: AVAILABILITY FLOW (Google Calendar)**

**Objetivo:** Consultar disponibilidade real via Google Calendar API.

**Trigger:** CoreOne detecta momento de agendar

**O que deve fazer:**
```
1. Autenticar com Google Calendar (Service Account)

2. Chamar freeBusy API:
   - timeMin: NOW() + 24h
   - timeMax: NOW() + 14 dias
   - items: [{ id: 'francisco@...' }]

3. Processar resultado:
   - Extrair horários ocupados
   - Calcular horários livres
   - Aplicar regras:
     * Horário comercial (9-18h)
     * Dias úteis (seg-sex)
     * Duração: 45 min
     * Intervalo mínimo: 30 min

4. Aplicar scoring de preferência:
   - Dias preferidos (ter-qui): +10
   - Horários preferidos (10-12h, 14-16h): +20
   - Proximidade: +pontos

5. Selecionar top 3 slots

6. Salvar oferta em corev4_pending_slot_offers

7. Retornar slots formatados para CoreOne
```

**Google Calendar API - freeBusy:**
```javascript
const response = await calendar.freebusy.query({
  requestBody: {
    timeMin: new Date().toISOString(),
    timeMax: addDays(new Date(), 14).toISOString(),
    timeZone: 'America/Sao_Paulo',
    items: [{ id: 'francisco@coreconnect.ai' }]
  }
});
```

---

#### **NOVO FLUXO 12: BOOKING FLOW (Google Calendar)**

**Objetivo:** Criar evento no Google Calendar após seleção de slot.

**Trigger:** CoreOne parseia seleção de horário

**O que deve fazer:**
```
1. Receber seleção:
   - offer_id
   - selected_slot (1, 2 ou 3)

2. Validar:
   - Oferta existe e não expirou
   - Slot ainda disponível (double-check freeBusy)

3. Criar evento via Google Calendar API:
   - summary: "Mesa de Clareza - {lead_name}"
   - start/end: horário selecionado
   - conferenceData: criar Google Meet
   - attendees: lead (se tiver email)
   - reminders: 24h e 1h

4. Salvar em corev4_scheduled_meetings:
   - meeting_url (Google Meet)
   - google_event_id

5. Cancelar followups pendentes

6. Enviar confirmação ao lead (via WhatsApp)

7. Enviar alerta ao Francisco
```

**Google Calendar API - events.insert:**
```javascript
const event = await calendar.events.insert({
  calendarId: 'francisco@coreconnect.ai',
  conferenceDataVersion: 1,
  requestBody: {
    summary: `Mesa de Clareza - ${leadName}`,
    start: { dateTime: slot.toISOString(), timeZone: 'America/Sao_Paulo' },
    end: { dateTime: addMinutes(slot, 45).toISOString(), timeZone: 'America/Sao_Paulo' },
    conferenceData: {
      createRequest: {
        requestId: `meet-${Date.now()}`,
        conferenceSolutionKey: { type: 'hangoutsMeet' }
      }
    }
  }
});
```

---

#### **NOVO FLUXO 13: COREONE ATUALIZADO (Agendamento)**

**Objetivo:** Atualizar o One Flow para suportar agendamento autônomo.

**O que mudar no One Flow existente:**

```
1. Adicionar estado de conversa:
   - 'normal': conversa padrão
   - 'awaiting_slot_selection': ofereceu horários
   - 'confirming_slot': confirmando seleção

2. Adicionar ferramenta para IA:
   - check_availability(): chama Availability Flow
   - create_booking(slot): chama Booking Flow

3. Atualizar prompt do FRANK:
   - Instruções para oferecer horários
   - Templates de mensagem
   - Como parsear seleção ("1", "terça", "primeiro")

4. Adicionar parser de seleção:
   - Regex para número direto: /^[1-3]$/
   - Regex para ordinal: /primeir|segund|terceir/
   - Match por dia: /terça|quarta|quinta/
   - Match por horário: /10h|14:30/
```

---

## 4. Integrações e Conexões

### 4.1 Mapa de Integrações

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MAPA DE INTEGRAÇÕES                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   APIS EXTERNAS                      FLUXOS QUE USAM                        │
│   ─────────────                      ───────────────                        │
│                                                                              │
│   Evolution API ──────────────────► Main Router, One Flow, Sentinel,        │
│   (WhatsApp)                         First Touch, Opt-in Handler,           │
│                                      Booking, Reminders                      │
│                                                                              │
│   Google Calendar API ────────────► Availability Flow (NOVO)                │
│   (freeBusy, events)                 Booking Flow (NOVO)                    │
│                                                                              │
│   RapidAPI ───────────────────────► Prospector Flow (NOVO)                  │
│   (Local Business Search)                                                    │
│                                                                              │
│   Unipile API ────────────────────► LinkedIn Prospector (NOVO)              │
│   (LinkedIn)                                                                 │
│                                                                              │
│   Scraptio API ───────────────────► Prospector Flow (NOVO)                  │
│   (Web scraping)                                                             │
│                                                                              │
│   Google Gemini ──────────────────► One Flow, Sync Flow, Sentinel           │
│   (IA primária)                                                              │
│                                                                              │
│   OpenAI GPT-4 ───────────────────► One Flow (fallback), Scheduler          │
│   (IA secundária)                    Prospector (resumo)                    │
│                                                                              │
│   Google Sheets ──────────────────► List Import Flow (NOVO)                 │
│   (importação)                       Prospector (atual - será removido)     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Conexões entre Fluxos

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      CONEXÕES ENTRE FLUXOS                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   PROATIVO                                                                   │
│   ────────                                                                   │
│                                                                              │
│   Prospector ──► List Validation ──► Campaign Orchestrator                  │
│       │                                      │                              │
│       │                                      ▼                              │
│   LinkedIn ────► List Validation      Warmup Monitor                        │
│       │                                      │                              │
│       │                                      ▼                              │
│   List Import ─► List Validation      First Touch ──► Opt-in Handler        │
│                                                              │              │
│                                              ┌───────────────┤              │
│                                              │               │              │
│                                              ▼               ▼              │
│                                       Nurture Engine    Handoff             │
│                                              │               │              │
│                                              └───────┬───────┘              │
│                                                      │                      │
│   ═══════════════════════════════════════════════════╪══════════════════   │
│                                                      │                      │
│   RECEPTIVO                                          ▼                      │
│   ─────────                                                                 │
│                                                                              │
│   Main Router ──► Genesis ──► One Flow ──► Sync Flow                        │
│       │              │            │             │                           │
│       │              │            │             │                           │
│       │              ▼            │             │                           │
│       │       Create Followup    │             │                           │
│       │              │            │             │                           │
│       │              ▼            │             │                           │
│       │         Sentinel ◄───────┴─────────────┘                           │
│       │                                                                      │
│       └────────────────────────────────┐                                    │
│                                        │                                    │
│                                        ▼                                    │
│                            ┌─────────────────────┐                          │
│                            │  AGENDAMENTO        │                          │
│                            │  AUTÔNOMO           │                          │
│                            │                     │                          │
│                            │  One Flow           │                          │
│                            │      │              │                          │
│                            │      ▼              │                          │
│                            │  Availability       │                          │
│                            │      │              │                          │
│                            │      ▼              │                          │
│                            │  Booking            │                          │
│                            │      │              │                          │
│                            │      ▼              │                          │
│                            │  Reminders          │                          │
│                            └─────────────────────┘                          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Banco de Dados

### 5.1 Tabelas Existentes

| Tabela | Propósito |
|--------|-----------|
| `corev4_contacts` | Contatos (WhatsApp, email, phone) |
| `corev4_lead_state` | Scores ANUM, qualification_stage |
| `corev4_contact_extras` | Preferências de resposta |
| `corev4_n8n_chat_histories` | Histórico de chat (n8n memory) |
| `corev4_anum_history` | Log de análises ANUM |
| `corev4_followup_campaigns` | Campanhas de followup |
| `corev4_followup_executions` | Execuções de followup |
| `corev4_followup_steps` | Configuração de timing |
| `corev4_scheduled_meetings` | Reuniões agendadas |
| `corev4_pending_slot_offers` | Ofertas de slots |
| `corev4_pain_categories` | Categorias de dor |
| `corev4_message_dedup` | Deduplicação |
| `corev4_calendar_settings` | Config de calendário |

### 5.2 Novas Tabelas Necessárias

```sql
-- 1. PROSPECTS (leads de outbound)
CREATE TABLE corev4_prospects (
    id BIGSERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES corev4_companies(id),

    -- Dados básicos
    full_name TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    email TEXT,
    company_name TEXT,
    job_title TEXT,

    -- Origem
    source_type TEXT NOT NULL,  -- 'google_maps', 'linkedin', 'import'
    source_reference TEXT,
    imported_at TIMESTAMPTZ DEFAULT NOW(),

    -- Validação
    validation_status TEXT DEFAULT 'new',
    -- 'new', 'valid', 'invalid_format', 'duplicate', 'opted_out', 'no_whatsapp'
    whatsapp_exists BOOLEAN,

    -- Scoring
    prospect_score INTEGER DEFAULT 0,
    tier TEXT,  -- 'A', 'B', 'C'

    -- Estado
    status TEXT DEFAULT 'new',

    -- Conversão
    converted_to_contact_id BIGINT REFERENCES corev4_contacts(id),

    -- Enriquecimento
    google_rating DECIMAL(2,1),
    google_reviews INTEGER,
    website TEXT,
    site_summary TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(phone_number, company_id)
);

-- 2. OUTBOUND CAMPAIGNS
CREATE TABLE corev4_outbound_campaigns (
    id BIGSERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES corev4_companies(id),

    campaign_code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    campaign_type TEXT NOT NULL,

    settings JSONB DEFAULT '{}'::JSONB,
    goals JSONB,

    status TEXT DEFAULT 'draft',

    scheduled_start TIMESTAMPTZ,
    actual_start TIMESTAMPTZ,

    metrics JSONB DEFAULT '{}'::JSONB,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. CAMPAIGN EXECUTIONS
CREATE TABLE corev4_campaign_executions (
    id BIGSERIAL PRIMARY KEY,
    campaign_id BIGINT REFERENCES corev4_outbound_campaigns(id),
    prospect_id BIGINT REFERENCES corev4_prospects(id),

    status TEXT DEFAULT 'pending',

    first_touch_sent_at TIMESTAMPTZ,
    first_touch_response TEXT,
    first_touch_button_clicked TEXT,

    current_nurture_step INTEGER DEFAULT 0,
    nurture_history JSONB DEFAULT '[]'::JSONB,

    handed_off_to_frank BOOLEAN DEFAULT false,
    handoff_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(campaign_id, prospect_id)
);

-- 4. CONSENT LOG (LGPD)
CREATE TABLE corev4_consent_log (
    id BIGSERIAL PRIMARY KEY,
    prospect_id BIGINT REFERENCES corev4_prospects(id),
    contact_id BIGINT REFERENCES corev4_contacts(id),

    consent_type TEXT NOT NULL,  -- 'opt_in', 'opt_out'
    consent_source TEXT NOT NULL,  -- 'button_click', 'text_message'

    message_id TEXT,
    raw_response TEXT,

    consented_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. BLOCKLIST
CREATE TABLE corev4_blocklist (
    id BIGSERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES corev4_companies(id),
    phone_number TEXT NOT NULL,
    reason TEXT NOT NULL,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(phone_number, company_id)
);

-- 6. WARMUP STATUS
CREATE TABLE corev4_warmup_status (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES corev4_companies(id),
    instance_name TEXT NOT NULL,

    warmup_phase TEXT DEFAULT 'initial',
    warmup_day INTEGER DEFAULT 1,
    current_daily_limit INTEGER DEFAULT 50,

    sent_today INTEGER DEFAULT 0,
    delivered_today INTEGER DEFAULT 0,

    metrics_history JSONB DEFAULT '[]'::JSONB,

    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(company_id, instance_name)
);

-- 7. MESSAGE TEMPLATES
CREATE TABLE corev4_message_templates (
    id TEXT PRIMARY KEY,
    company_id INTEGER REFERENCES corev4_companies(id),

    name TEXT NOT NULL,
    category TEXT,
    content_type TEXT NOT NULL,
    content JSONB NOT NULL,

    variables TEXT[],
    usage_count INTEGER DEFAULT 0,

    is_active BOOLEAN DEFAULT true,

    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 6. Agendamento Autônomo

### 6.1 Situação Atual vs Nova

| Aspecto | Atual (Cal.com) | Novo (Google Calendar) |
|---------|-----------------|------------------------|
| **Como funciona** | FRANK envia link do Cal.com | FRANK oferece 3 horários na conversa |
| **Experiência** | Lead sai do WhatsApp | Tudo no WhatsApp |
| **Disponibilidade** | Cal.com consulta | Google Calendar API (freeBusy) |
| **Criação evento** | Cal.com cria | n8n cria via Google Calendar API |
| **Google Meet** | Cal.com gera | n8n gera via conferenceData |
| **Dependência** | Cal.com (externo) | Google Calendar (próprio) |

### 6.2 Fluxo Completo do Agendamento Autônomo

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    FLUXO DE AGENDAMENTO AUTÔNOMO                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   1. DETECÇÃO DO MOMENTO                                                    │
│   ──────────────────────                                                    │
│                                                                              │
│   CoreOne detecta que é hora de agendar:                                    │
│   - ANUM Score ≥ 60                                                         │
│   - Lead perguntou sobre reunião                                            │
│   - Lead demonstrou urgência                                                │
│                                                                              │
│                              │                                               │
│                              ▼                                               │
│                                                                              │
│   2. CONSULTA DISPONIBILIDADE                                               │
│   ───────────────────────────                                               │
│                                                                              │
│   CoreOne chama tool: check_availability()                                  │
│                              │                                               │
│                              ▼                                               │
│                   ┌─────────────────────┐                                   │
│                   │  AVAILABILITY FLOW  │                                   │
│                   └──────────┬──────────┘                                   │
│                              │                                               │
│                              ▼                                               │
│                   ┌─────────────────────┐                                   │
│                   │ Google Calendar API │                                   │
│                   │     freeBusy        │                                   │
│                   └──────────┬──────────┘                                   │
│                              │                                               │
│                              ▼                                               │
│                   ┌─────────────────────┐                                   │
│                   │ Aplicar regras:     │                                   │
│                   │ • Horário comercial │                                   │
│                   │ • Dias úteis        │                                   │
│                   │ • Antecedência 24h  │                                   │
│                   │ • Preferências      │                                   │
│                   └──────────┬──────────┘                                   │
│                              │                                               │
│                              ▼                                               │
│                   ┌─────────────────────┐                                   │
│                   │ Score e selecionar  │                                   │
│                   │ top 3 slots         │                                   │
│                   └──────────┬──────────┘                                   │
│                              │                                               │
│                              ▼                                               │
│                                                                              │
│   3. OFERTA DE HORÁRIOS                                                     │
│   ─────────────────────                                                     │
│                                                                              │
│   CoreOne envia mensagem:                                                   │
│   ┌────────────────────────────────────────────────────┐                   │
│   │ Perfeito! Deixa eu ver a agenda do Francisco...   │                   │
│   │                                                    │                   │
│   │ Tenho essas opções:                               │                   │
│   │                                                    │                   │
│   │ 1️⃣ Terça (24/12) às 10:00                         │                   │
│   │ 2️⃣ Quarta (25/12) às 14:30                        │                   │
│   │ 3️⃣ Quinta (26/12) às 11:00                        │                   │
│   │                                                    │                   │
│   │ Qual funciona melhor pra você?                    │                   │
│   └────────────────────────────────────────────────────┘                   │
│                                                                              │
│   Estado da conversa: 'awaiting_slot_selection'                             │
│   Oferta salva em: corev4_pending_slot_offers (expira em 24h)              │
│                                                                              │
│                              │                                               │
│                              ▼                                               │
│                                                                              │
│   4. SELEÇÃO DO LEAD                                                        │
│   ──────────────────                                                        │
│                                                                              │
│   Lead responde: "Terça tá ótimo!" ou "1" ou "primeiro"                     │
│                              │                                               │
│                              ▼                                               │
│                   ┌─────────────────────┐                                   │
│                   │ PARSER DE SELEÇÃO   │                                   │
│                   │                     │                                   │
│                   │ • "1" → slot 1      │                                   │
│                   │ • "terça" → slot 1  │                                   │
│                   │ • "10h" → slot 1    │                                   │
│                   │ • "primeiro" → 1    │                                   │
│                   └──────────┬──────────┘                                   │
│                              │                                               │
│                              ▼                                               │
│                                                                              │
│   5. CRIAÇÃO DO BOOKING                                                     │
│   ─────────────────────                                                     │
│                                                                              │
│   CoreOne chama tool: create_booking(slot=1)                                │
│                              │                                               │
│                              ▼                                               │
│                   ┌─────────────────────┐                                   │
│                   │    BOOKING FLOW     │                                   │
│                   └──────────┬──────────┘                                   │
│                              │                                               │
│               ┌──────────────┼──────────────┐                               │
│               │              │              │                               │
│               ▼              ▼              ▼                               │
│        ┌───────────┐  ┌───────────┐  ┌───────────┐                         │
│        │ Validar   │  │ Double-   │  │ Criar     │                         │
│        │ oferta    │  │ check     │  │ evento    │                         │
│        │ existe    │  │ freeBusy  │  │ Google    │                         │
│        └───────────┘  └───────────┘  └─────┬─────┘                         │
│                                            │                                │
│                                            ▼                                │
│                              ┌─────────────────────┐                        │
│                              │ Google Calendar API │                        │
│                              │   events.insert     │                        │
│                              │   + Google Meet     │                        │
│                              └──────────┬──────────┘                        │
│                                         │                                   │
│                                         ▼                                   │
│                              ┌─────────────────────┐                        │
│                              │ Salvar em           │                        │
│                              │ scheduled_meetings  │                        │
│                              └──────────┬──────────┘                        │
│                                         │                                   │
│                                         ▼                                   │
│                              ┌─────────────────────┐                        │
│                              │ Cancelar followups  │                        │
│                              │ pendentes           │                        │
│                              └──────────┬──────────┘                        │
│                                         │                                   │
│                                         ▼                                   │
│                                                                              │
│   6. CONFIRMAÇÃO                                                            │
│   ──────────────                                                            │
│                                                                              │
│   CoreOne envia confirmação:                                                │
│   ┌────────────────────────────────────────────────────┐                   │
│   │ Pronto, agendado! ✅                               │                   │
│   │                                                    │                   │
│   │ 📅 Terça, 24/12 às 10:00                          │                   │
│   │ 📍 Google Meet: meet.google.com/abc-defg-hij      │                   │
│   │ ⏱️ Duração: 45 minutos                            │                   │
│   │                                                    │                   │
│   │ Vou te mandar um lembrete amanhã e 1h antes.      │                   │
│   │ Até lá! 👋                                         │                   │
│   └────────────────────────────────────────────────────┘                   │
│                                                                              │
│   Estado: 'normal' (volta ao normal)                                        │
│   Alerta enviado ao Francisco via WhatsApp                                  │
│                                                                              │
│                              │                                               │
│                              ▼                                               │
│                                                                              │
│   7. LEMBRETES (Meeting Reminders Flow)                                     │
│   ─────────────────────────────────────                                     │
│                                                                              │
│   T-24h: "Lembrete: amanhã às 10h temos nossa conversa..."                 │
│   T-1h:  "Sua reunião começa em 1 hora! Link: ..."                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.3 Configuração do Google Calendar API

**1. Criar Service Account no Google Cloud:**
```
1. Acessar console.cloud.google.com
2. Criar projeto (ou usar existente)
3. Habilitar Google Calendar API
4. Criar Service Account
5. Gerar chave JSON
6. Compartilhar calendário com email do Service Account
```

**2. Credenciais no n8n:**
```json
{
  "type": "service_account",
  "project_id": "coreadapt-calendar",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "calendar@coreadapt-calendar.iam.gserviceaccount.com",
  "client_id": "...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token"
}
```

**3. Scopes necessários:**
- `https://www.googleapis.com/auth/calendar`
- `https://www.googleapis.com/auth/calendar.events`

---

## 7. Plano de Implementação

### 7.1 Fase 1: MVP (17 dias)

| Dia | Tarefa | Responsável |
|-----|--------|-------------|
| 1-2 | Criar 7 tabelas novas no banco | Dev |
| 3-4 | Ajustar Prospector Flow (Google Maps → DB) | Dev |
| 5 | Criar List Validation Flow | Dev |
| 6-7 | Criar Campaign Orchestrator | Dev |
| 8 | Criar Warmup Monitor | Dev |
| 9-10 | Criar First Touch Flow (com botões) | Dev |
| 11 | Criar Opt-in Handler | Dev |
| 12 | Criar Handoff Flow | Dev |
| 13 | Configurar Google Calendar API | Dev |
| 14 | Criar Availability Flow (Google Calendar) | Dev |
| 15 | Criar Booking Flow (Google Calendar) | Dev |
| 16 | Atualizar CoreOne para agendamento | Dev |
| 17 | Testes E2E | Dev + QA |

### 7.2 Fase 2: Completo (até 31/01)

| Semana | Tarefa |
|--------|--------|
| 1 | LinkedIn Prospector (Unipile) |
| 2 | Nurture Engine Flow |
| 3 | List Cleanup Flow + CRM Sync (Chatwoot) |
| 4 | Integrações CRM (HubSpot, Pipedrive) |
| 5 | Testes, documentação, ajustes |

---

## 8. Checklist de Validação

### 8.1 Para cada novo fluxo

- [ ] Fluxo criado e importado no n8n
- [ ] Credentials configuradas
- [ ] Webhook URL documentada (se aplicável)
- [ ] Teste manual OK
- [ ] Teste com dados reais OK
- [ ] Error handling implementado
- [ ] Logs adequados
- [ ] Documentação atualizada

### 8.2 Para o agendamento autônomo

- [ ] Service Account Google criado
- [ ] Calendário compartilhado com Service Account
- [ ] Credenciais no n8n
- [ ] freeBusy funcionando
- [ ] events.insert funcionando
- [ ] Google Meet sendo criado
- [ ] Confirmação sendo enviada
- [ ] Alerta ao Francisco funcionando
- [ ] Lembretes funcionando
- [ ] Cal.com desativado

### 8.3 Para o sistema proativo

- [ ] Prospector populando banco
- [ ] Validação funcionando
- [ ] Warmup controlando volume
- [ ] First Touch com botões
- [ ] Opt-in/out sendo registrado
- [ ] Handoff transferindo corretamente
- [ ] Contexto chegando no CoreOne

---

## Conclusão

Este documento serve como referência completa para a implementação do upgrade do CoreAdapt. Qualquer dúvida, consulte as seções específicas ou peça esclarecimentos.

**Arquivos relacionados:**
- `docs/BIG_PICTURE_FLUXO_COMPLETO.md` - Visão macro
- `docs/JORNADA_LEAD_MERMAID.md` - Diagramas visuais
- `docs/COREADAPT_PROATIVO_ARCHITECTURE.md` - Arquitetura proativo
- `docs/PLANO_ACAO_MVP_2026.md` - Plano de ação

**Última atualização:** 19 de Dezembro de 2025
