# CoreAdapt Secretary Mode - Deep Dive Analysis & Implementation Plan

**Data:** 12 de Novembro de 2025
**Versão:** 1.0
**Autor:** Claude Code Analysis

---

## 📋 Índice

1. [Resumo Executivo](#resumo-executivo)
2. [Análise da Cal.com API](#análise-da-calcom-api)
3. [Arquitetura Atual do CoreAdapt](#arquitetura-atual-do-coreadapt)
4. [Arquitetura Proposta: Secretary Mode](#arquitetura-proposta-secretary-mode)
5. [Plano de Implementação Detalhado](#plano-de-implementação-detalhado)
6. [Considerações Técnicas](#considerações-técnicas)
7. [Riscos e Mitigações](#riscos-e-mitigações)
8. [Cronograma e Estimativas](#cronograma-e-estimativas)

---

## 🎯 Resumo Executivo

### Demanda do Cliente

O cliente (advogado) solicitou uma funcionalidade onde o CoreAdapt atue como **secretária particular**, permitindo:

1. **Enviar mensagens via WhatsApp** pedindo para agendar reuniões com terceiros
2. **Escolher tipo de reunião**: presencial ou online
3. **Checagem automática de disponibilidade** na agenda (via Cal.com)
4. **Agendamento proativo**: sistema confirma com o "patrão" e executa o agendamento
5. **Envio de convite automático** para o terceiro agendado (com link se for online)

### Resposta Direta

✅ **SIM, É TOTALMENTE VIÁVEL**

A Cal.com API v2 suporta TODAS as funcionalidades necessárias:

- ✅ **GET /v2/slots** - Checar disponibilidade
- ✅ **POST /v2/bookings** - Criar agendamentos programaticamente
- ✅ **Agendar para terceiros** - Campo `attendee` com nome, email, telefone
- ✅ **Metadados customizados** - Para distinguir "agendamentos de secretária"
- ✅ **Webhooks** - Já integrados no CoreAdapt

### Recomendação Arquitetural

**IMPLEMENTAR COMO MÓDULO OPCIONAL DENTRO DO COREADAPT**

Motivos:
1. Aproveita toda infraestrutura existente (multi-tenancy, Evolution API, n8n)
2. Permite comercializar como feature premium
3. Mantém a identidade core do produto
4. Habilita coexistência: mesma empresa pode usar qualificação de leads E secretária

---

## 🔌 Análise da Cal.com API

### Endpoint 1: Verificar Disponibilidade

```http
GET https://api.cal.com/v2/slots/available
```

**Parâmetros Necessários:**

| Parâmetro | Tipo | Obrigatório | Descrição |
|-----------|------|-------------|-----------|
| `eventTypeId` | integer | Sim | ID do tipo de evento (reunião) |
| `startTime` | ISO 8601 | Sim | Início da janela de busca (UTC) |
| `endTime` | ISO 8601 | Sim | Fim da janela de busca (UTC) |
| `timeZone` | string | Não | Timezone (default: UTC) |
| `duration` | integer | Não | Duração em minutos |

**Resposta Esperada:**

```json
{
  "status": "success",
  "data": {
    "slots": {
      "2025-11-13": [
        "2025-11-13T09:00:00Z",
        "2025-11-13T10:00:00Z",
        "2025-11-13T11:00:00Z"
      ],
      "2025-11-14": [
        "2025-11-14T14:00:00Z",
        "2025-11-14T15:00:00Z"
      ]
    }
  }
}
```

### Endpoint 2: Criar Agendamento

```http
POST https://api.cal.com/v2/bookings
Headers:
  Content-Type: application/json
  cal-api-version: 2024-08-13
  Authorization: Bearer {API_KEY}
```

**Request Body:**

```json
{
  "eventTypeId": 123,
  "start": "2025-11-13T09:00:00Z",
  "attendee": {
    "name": "João Silva",
    "email": "[email protected]",
    "timeZone": "America/Sao_Paulo",
    "phoneNumber": "+5585999999999",
    "language": "pt"
  },
  "guests": ["[email protected]"],
  "location": {
    "type": "address",
    "value": "Rua Exemplo, 123"
  },
  "metadata": {
    "scheduled_by": "secretary_mode",
    "requested_by_user_id": "uuid-do-usuario",
    "meeting_purpose": "consultoria juridica"
  },
  "lengthInMinutes": 60
}
```

**Response:**

```json
{
  "status": "success",
  "data": {
    "id": 789,
    "uid": "booking-uid-abc123",
    "eventTypeId": 123,
    "title": "Reunião com João Silva",
    "startTime": "2025-11-13T09:00:00Z",
    "endTime": "2025-11-13T10:00:00Z",
    "attendees": [
      {
        "name": "João Silva",
        "email": "[email protected]",
        "timeZone": "America/Sao_Paulo"
      }
    ],
    "location": "Rua Exemplo, 123",
    "metadata": {
      "scheduled_by": "secretary_mode"
    },
    "bookingUrl": "https://cal.com/advogado/meeting?bookingUid=abc123"
  }
}
```

### ✅ Confirmação: TODAS as funcionalidades necessárias estão disponíveis

- ✅ Buscar disponibilidade por período
- ✅ Criar agendamento para terceiros
- ✅ Suportar campos customizados (metadata)
- ✅ Enviar email automático para attendee
- ✅ Gerar link de reunião online
- ✅ Especificar localização presencial

---

## 🏗️ Arquitetura Atual do CoreAdapt

### Fluxo Principal de Mensagens

```
WhatsApp → Evolution API → n8n Webhook → Normalize → Router
                                                       ├─ NEW CONTACT → Genesis Flow
                                                       ├─ BLOCKED → Reactivate Flow
                                                       ├─ COMMAND (#) → Commands Flow
                                                       └─ ACTIVE CHAT → CoreAdapt One Flow
```

### Tabelas Críticas no Banco de Dados

#### 1. `corev4_contacts`
```sql
id (PK)
company_id (FK → corev4_companies)
full_name
whatsapp (UNIQUE com company_id)
phone_number
email
opt_out (boolean)
is_active (boolean)
origin_source
last_interaction_at
```

**Observação:** NÃO há conceito de "roles" ou "authorized users"

#### 2. `corev4_companies`
```sql
id (PK)
name
slug
bot_name (default: 'Frank')
system_prompt (text) -- Customizável por tenant!
llm_model
features (jsonb) -- Feature flags!
evolution_api_url
evolution_instance
evolution_api_key
```

**CRUCIAL:** Já existe campo `features` (JSONB) para feature flags por tenant!

#### 3. `corev4_scheduled_meetings`
```sql
id (PK)
contact_id (FK → corev4_contacts)
company_id (FK → corev4_companies)
meeting_date
meeting_end_date
meeting_duration_minutes
meeting_type ('mesa_clareza', etc)
cal_booking_uid (UNIQUE)
cal_event_type_id
cal_meeting_url
cal_attendee_email
cal_attendee_name
status ('scheduled', 'completed', 'cancelled')
conversation_summary (text)
anum_score_at_booking
reminder_24h_sent
reminder_1h_sent
```

**Observação:** Tabela assume que `contact_id` É o agendado (lead). Precisaremos adaptação.

#### 4. `corev4_lead_state`
```sql
contact_id (PK, FK)
company_id
authority_score (0-25)
need_score (0-25)
urgency_score (0-25)
money_score (0-25)
total_score (0-100)
qualification_stage
is_qualified
```

**Observação:** Usado apenas para leads, não se aplica a "authorized users"

### Scheduler Flow Atual

**Arquivo:** `CoreAdapt Scheduler Flow _ v4.json`

**Trigger:** Webhook do Cal.com (POST `/cal-booking`)

**Fluxo:**
1. ✅ Recebe webhook `BOOKING_CREATED`
2. ✅ Parse dos dados do Cal.com
3. ✅ Match contact por email/phone
4. ✅ Busca histórico de conversa (últimas 10 mensagens)
5. ✅ Gera summary com AI (GPT-4o-mini)
6. ✅ Salva em `corev4_scheduled_meetings`
7. ✅ Envia confirmação para o lead (WhatsApp)
8. ✅ Envia alerta para Francisco Pasteur: `5585999855443` (hardcoded!)
9. ✅ Para campanhas de follow-up ativas

**Limitação:** Sistema só REAGE a agendamentos, não cria proativamente.

### CoreAdapt One Flow (AI Agent)

**Arquivo:** `CoreAdapt One Flow _ v4.json`

**Principais Componentes:**
- ✅ Langchain Agent com tools
- ✅ Session management (UUID por contato)
- ✅ Memória: 20 últimas mensagens
- ✅ Tools disponíveis:
  - Analyze ANUM
  - Book Meeting (compartilha link Cal.com)
  - Update Contact Info
- ✅ Suporte a áudio (TTS), texto, imagens
- ✅ System prompt customizável via `corev4_companies.system_prompt`

**Tool "Book Meeting" Atual:**
```javascript
// Apenas compartilha link Cal.com
// Lead clica e agenda manualmente
const calLink = "https://cal.com/francisco/mesa-clareza";
return `Aqui está o link: ${calLink}`;
```

**Necessidade:** Criar nova tool que CRIA agendamentos via API.

---

## 🚀 Arquitetura Proposta: Secretary Mode

### Conceito: Módulo Híbrido Opcional

```
CoreAdapt v4
├── Core (sempre ativo)
│   ├── Qualificação ANUM (leads públicos)
│   ├── Follow-ups automatizados
│   └── Agendamento passivo (lead recebe link)
│
└── Secretary Mode (opcional via feature flag)
    ├── Authorized Users (usuários internos)
    ├── Agendamento proativo (secretária agenda)
    ├── Gestão de terceiros
    └── Checagem de disponibilidade
```

### Diferenciação por Remetente

```
Mensagem recebida via WhatsApp
    ↓
[Router] Busca sender em corev4_authorized_users
    ↓                                    ↓
   ENCONTRADO                         NÃO ENCONTRADO
   (é authorized user)                (é lead público)
    ↓                                    ↓
[Secretary Flow]                    [One Flow - Qualificação]
   AI = Assistente Executiva           AI = Consultor ANUM
   Tools = schedule, check_calendar    Tools = analyze_anum, share_link
```

### Novos Schemas de Banco de Dados

#### Tabela: `corev4_authorized_users`

```sql
CREATE TABLE corev4_authorized_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id INTEGER NOT NULL REFERENCES corev4_companies(id) ON DELETE CASCADE,
  whatsapp_id VARCHAR(50) NOT NULL, -- Ex: 5585999855443@s.whatsapp.net
  full_name VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL DEFAULT 'owner', -- 'owner', 'manager', 'assistant'
  permissions JSONB NOT NULL DEFAULT '{}', -- {"schedule_meetings": true, "cancel_meetings": true}
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT unique_whatsapp_company_auth UNIQUE(whatsapp_id, company_id)
);

CREATE INDEX idx_authorized_users_whatsapp ON corev4_authorized_users(whatsapp_id);
CREATE INDEX idx_authorized_users_company ON corev4_authorized_users(company_id);
CREATE INDEX idx_authorized_users_active ON corev4_authorized_users(is_active) WHERE is_active = true;
```

**Exemplo de Registro:**

```json
{
  "id": "uuid-123",
  "company_id": 1,
  "whatsapp_id": "5585999855443@s.whatsapp.net",
  "full_name": "Francisco Pasteur",
  "role": "owner",
  "permissions": {
    "schedule_meetings": true,
    "cancel_meetings": true,
    "check_calendar": true,
    "manage_third_parties": true
  },
  "is_active": true
}
```

#### Tabela: `corev4_secretary_appointments`

```sql
CREATE TABLE corev4_secretary_appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id INTEGER NOT NULL REFERENCES corev4_companies(id),

  -- Quem solicitou o agendamento
  requested_by_user_id UUID NOT NULL REFERENCES corev4_authorized_users(id),

  -- Dados do terceiro (attendee)
  attendee_name VARCHAR(255) NOT NULL,
  attendee_phone VARCHAR(50),
  attendee_email VARCHAR(255),
  attendee_whatsapp VARCHAR(50), -- Para enviar link pelo WhatsApp

  -- Tipo de reunião
  meeting_type VARCHAR(50) NOT NULL, -- 'online', 'presencial'
  location TEXT, -- Se presencial, endereço

  -- Dados do Cal.com
  cal_booking_uid VARCHAR(255) UNIQUE,
  cal_event_type_id INTEGER,
  cal_meeting_url TEXT, -- Se online

  -- Data/hora
  meeting_date TIMESTAMPTZ NOT NULL,
  meeting_end_date TIMESTAMPTZ NOT NULL,
  meeting_duration_minutes INTEGER NOT NULL,
  meeting_timezone VARCHAR(100) NOT NULL DEFAULT 'America/Sao_Paulo',

  -- Status
  status VARCHAR(50) NOT NULL DEFAULT 'pending', -- 'pending', 'confirmed', 'cancelled', 'completed'
  confirmation_sent BOOLEAN DEFAULT false,
  confirmation_sent_at TIMESTAMPTZ,

  -- Metadata
  request_message TEXT, -- Mensagem original do user
  ai_conversation JSONB, -- Histórico da conversa com a AI

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_secretary_appointments_company ON corev4_secretary_appointments(company_id);
CREATE INDEX idx_secretary_appointments_requested_by ON corev4_secretary_appointments(requested_by_user_id);
CREATE INDEX idx_secretary_appointments_meeting_date ON corev4_secretary_appointments(meeting_date);
CREATE INDEX idx_secretary_appointments_status ON corev4_secretary_appointments(status);
CREATE INDEX idx_secretary_appointments_cal_uid ON corev4_secretary_appointments(cal_booking_uid);
```

**Exemplo de Registro:**

```json
{
  "id": "uuid-456",
  "company_id": 1,
  "requested_by_user_id": "uuid-123",
  "attendee_name": "João da Silva",
  "attendee_phone": "5585988887777",
  "attendee_email": "[email protected]",
  "attendee_whatsapp": "5585988887777@s.whatsapp.net",
  "meeting_type": "online",
  "location": null,
  "cal_booking_uid": "booking-abc123",
  "cal_event_type_id": 789,
  "cal_meeting_url": "https://meet.google.com/xyz-abc-def",
  "meeting_date": "2025-11-15T14:00:00Z",
  "meeting_end_date": "2025-11-15T15:00:00Z",
  "meeting_duration_minutes": 60,
  "status": "confirmed",
  "request_message": "agenda reunião com João Silva amanhã 14h",
  "ai_conversation": [
    {"role": "user", "message": "agenda reunião com João Silva amanhã 14h"},
    {"role": "assistant", "message": "Verificando disponibilidade..."},
    {"role": "assistant", "message": "Disponível! Confirma agendamento?"},
    {"role": "user", "message": "confirma"}
  ]
}
```

### Feature Flag em `corev4_companies`

**Adicionar ao campo `features` (JSONB):**

```json
{
  "secretary_mode_enabled": true,
  "secretary_config": {
    "cal_api_key": "cal_live_xxxxx",
    "default_event_type_id": 123,
    "auto_confirm_bookings": false,
    "require_attendee_email": true,
    "presencial_locations": [
      "Escritório - Av. Beira Mar, 3000",
      "Sala de Reunião - Shopping Iguatemi"
    ]
  }
}
```

### Novo Flow: CoreAdapt Secretary Flow

**Arquivo:** `CoreAdapt Secretary Flow _ v4.json`

**Trigger:** Chamado pelo Router quando sender é authorized user

**Nodes Principais:**

1. **Prepare: Secretary Context**
   - Busca dados do authorized user
   - Busca configurações de secretary_mode
   - Prepara contexto para AI

2. **AI Agent: Secretary Assistant**
   - Model: GPT-4o-mini
   - System Prompt: Assistente executiva
   - Tools disponíveis:
     - `check_calendar_availability`
     - `create_meeting`
     - `cancel_meeting`
     - `list_upcoming_meetings`
     - `reschedule_meeting`

3. **Tool: Check Calendar Availability**
   ```javascript
   // Inputs: start_date, end_date, duration_minutes
   // Chama: GET /v2/slots/available
   // Output: Lista de slots disponíveis formatados
   ```

4. **Tool: Create Meeting**
   ```javascript
   // Inputs: attendee_name, attendee_contact, meeting_type, selected_slot
   // Valida dados
   // Chama: POST /v2/bookings
   // Salva em corev4_secretary_appointments
   // Envia confirmação para attendee (WhatsApp ou email)
   // Output: Confirmação formatada
   ```

5. **Save: Chat History**
   - Salva conversa em `corev4_chat_history`
   - Distingue role: 'user' vs 'assistant'

6. **Send: WhatsApp Response**
   - Envia resposta via Evolution API

### System Prompt para Secretary Mode

```markdown
# IDENTIDADE

Você é a Assistente Executiva Pessoal de {owner_name}.

# MISSÃO

Gerenciar a agenda e facilitar o agendamento de reuniões com terceiros.

# CAPACIDADES

Você pode:
1. Verificar disponibilidade na agenda
2. Agendar reuniões (presenciais ou online)
3. Cancelar/remarcar compromissos
4. Enviar convites automáticos para terceiros
5. Confirmar detalhes antes de finalizar

# PROTOCOLO DE AGENDAMENTO

## Passo 1: Entender a Solicitação
- Nome completo do terceiro
- Tipo de reunião: presencial ou online?
- Data/horário preferido ou "próxima disponibilidade"
- Duração estimada (padrão: 60 minutos)

## Passo 2: Verificar Disponibilidade
- Use a tool `check_calendar_availability`
- Apresente 3 opções de horários
- Se solicitado horário específico não disponível, sugira alternativas

## Passo 3: Confirmar Dados
- Recapitule: nome, data, hora, tipo
- Se presencial: confirme localização
- Se online: informe que link será enviado

## Passo 4: Executar Agendamento
- Use a tool `create_meeting`
- Confirme execução bem-sucedida
- Informe próximos passos (convite enviado para terceiro)

# TOM E ESTILO

- Profissional mas calorosa
- Eficiente e proativa
- Sempre confirma antes de executar ações
- Usa emojis com moderação (📅 🕒 ✅)

# EXEMPLOS

User: "Agenda reunião com Dr. João Silva amanhã 14h"
Assistant: "Verificando disponibilidade para amanhã às 14h... ✓

Horários disponíveis:
📅 13/11 às 14:00 - 15:00 ✅ (solicitado)
📅 13/11 às 15:00 - 16:00
📅 13/11 às 16:00 - 17:00

Preciso de mais informações:
1. Reunião presencial ou online?
2. Email ou WhatsApp do Dr. João Silva para enviar o convite?"

User: "Online, email [email protected]"
Assistant: "Perfeito! Recapitulando:
👤 Dr. João Silva
📧 [email protected]
📅 Amanhã (13/11) às 14:00
🕒 Duração: 1 hora
💻 Reunião online

Confirma o agendamento?"

User: "confirma"
Assistant: "✅ Reunião agendada com sucesso!

📧 Convite enviado para [email protected] com link da reunião
🔗 Link também disponível para você: [meeting_url]

Quer que eu envie algum lembrete adicional?"
```

---

## 📝 Plano de Implementação Detalhado

### Fase 1: Preparação do Banco de Dados (2-3 horas)

#### Task 1.1: Criar Tabelas
```sql
-- Script: migrations/001_create_secretary_tables.sql

-- Authorized Users
CREATE TABLE corev4_authorized_users (
  -- [schema completo acima]
);

-- Secretary Appointments
CREATE TABLE corev4_secretary_appointments (
  -- [schema completo acima]
);

-- Triggers para updated_at
CREATE TRIGGER update_authorized_users_updated_at
  BEFORE UPDATE ON corev4_authorized_users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_secretary_appointments_updated_at
  BEFORE UPDATE ON corev4_secretary_appointments
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

#### Task 1.2: Seed Data para Testes
```sql
-- Adicionar Francisco como authorized user
INSERT INTO corev4_authorized_users (
  company_id,
  whatsapp_id,
  full_name,
  role,
  permissions
) VALUES (
  1, -- company_id do Francisco
  '5585999855443@s.whatsapp.net',
  'Francisco Pasteur',
  'owner',
  '{"schedule_meetings": true, "cancel_meetings": true, "check_calendar": true}'::jsonb
);

-- Habilitar secretary_mode para a empresa
UPDATE corev4_companies
SET features = jsonb_set(
  COALESCE(features, '{}'::jsonb),
  '{secretary_mode_enabled}',
  'true'
)
WHERE id = 1;

-- Adicionar config de secretary
UPDATE corev4_companies
SET features = jsonb_set(
  features,
  '{secretary_config}',
  '{
    "cal_api_key": "PLACEHOLDER",
    "default_event_type_id": 123,
    "auto_confirm_bookings": false,
    "require_attendee_email": true
  }'::jsonb
)
WHERE id = 1;
```

#### Task 1.3: Criar Views para Analytics
```sql
-- View: Agendamentos de secretária ativos
CREATE VIEW v_active_secretary_appointments AS
SELECT
  sa.*,
  au.full_name as requested_by_name,
  au.role as requester_role,
  EXTRACT(EPOCH FROM (sa.meeting_date - NOW())) / 3600 AS hours_until_meeting
FROM corev4_secretary_appointments sa
JOIN corev4_authorized_users au ON au.id = sa.requested_by_user_id
WHERE sa.status IN ('pending', 'confirmed')
  AND sa.meeting_date > NOW()
ORDER BY sa.meeting_date;
```

---

### Fase 2: Modificação do Router (3-4 horas)

#### Task 2.1: Adicionar Lookup de Authorized Users

**Arquivo:** `CoreAdapt Main Router Flow _ v4.json`

**Novo Node:** `Fetch: Check Authorized User` (após "Enrich: Message Context")

```json
{
  "name": "Fetch: Check Authorized User",
  "type": "n8n-nodes-base.postgres",
  "parameters": {
    "operation": "executeQuery",
    "query": "SELECT id, company_id, full_name, role, permissions, is_active FROM corev4_authorized_users WHERE whatsapp_id = $1 AND company_id = $2 AND is_active = true LIMIT 1",
    "options": {
      "queryReplacement": "={{ [$json.whatsapp_id, $json.company_id] }}"
    }
  }
}
```

#### Task 2.2: Modificar Switch Node "Route: Contact Status"

**Adicionar nova rota ANTES das existentes:**

```javascript
// Nova condição com prioridade máxima
{
  "conditions": [
    {
      "leftValue": "={{ $('Fetch: Check Authorized User').item.json.id }}",
      "operator": "exists"
    },
    {
      "leftValue": "={{ $('Fetch: Company Features').item.json.features.secretary_mode_enabled }}",
      "operator": "equals",
      "rightValue": true
    }
  ],
  "combinator": "and",
  "outputKey": "authorized_user_secretary"
}
```

**Fluxo completo atualizado:**

```
Route: Contact Status →
  ├─ authorized_user_secretary → [Secretary Flow] 🆕
  ├─ new_contact → Genesis Flow
  ├─ blocked_contact → Reactivate Flow
  ├─ command → Commands Flow
  └─ active_chat → One Flow
```

#### Task 2.3: Adicionar Fetch de Features

**Novo Node:** `Fetch: Company Features`

```json
{
  "name": "Fetch: Company Features",
  "type": "n8n-nodes-base.postgres",
  "parameters": {
    "operation": "executeQuery",
    "query": "SELECT features FROM corev4_companies WHERE id = $1",
    "options": {
      "queryReplacement": "={{ [$json.company_id] }}"
    }
  }
}
```

---

### Fase 3: Criar Secretary Flow (8-10 horas)

#### Task 3.1: Flow Base

**Arquivo:** `CoreAdapt Secretary Flow _ v4.json`

**Estrutura:**

```
Workflow Trigger
    ↓
[Prepare: Secretary Context]
    ↓
[Fetch: User Profile & Permissions]
    ↓
[Fetch: Company Secretary Config]
    ↓
[AI Agent: Secretary Assistant]
    ├─ Tool: check_calendar_availability
    ├─ Tool: create_meeting
    ├─ Tool: cancel_meeting
    ├─ Tool: list_upcoming_meetings
    └─ Tool: reschedule_meeting
    ↓
[Save: Chat History]
    ↓
[Send: WhatsApp Response]
```

#### Task 3.2: Implementar Tool "check_calendar_availability"

**Node:** `Function: Check Calendar`

```javascript
// INPUT: start_date, end_date, duration_minutes (optional)
const startDate = $json.start_date; // ISO 8601
const endDate = $json.end_date;
const duration = $json.duration_minutes || 60;

// Buscar config da empresa
const companyConfig = $('Fetch: Company Secretary Config').first().json;
const calApiKey = companyConfig.features.secretary_config.cal_api_key;
const eventTypeId = companyConfig.features.secretary_config.default_event_type_id;

// Fazer request para Cal.com API
const url = `https://api.cal.com/v2/slots/available?eventTypeId=${eventTypeId}&startTime=${startDate}&endTime=${endDate}&duration=${duration}&timeZone=America/Sao_Paulo`;

return [{
  json: {
    url: url,
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${calApiKey}`,
      'cal-api-version': '2024-08-13'
    }
  }
}];
```

**Node Seguinte:** `HTTP Request: Cal.com Get Slots`

**Node Final:** `Format: Slots for AI`

```javascript
const slotsData = $input.first().json.data.slots;

// Formatar para o AI entender
const formatted = [];
for (const [date, times] of Object.entries(slotsData)) {
  times.forEach(time => {
    const dateObj = new Date(time);
    const formatter = new Intl.DateTimeFormat('pt-BR', {
      timeZone: 'America/Sao_Paulo',
      weekday: 'short',
      day: '2-digit',
      month: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    });

    formatted.push({
      iso: time,
      readable: formatter.format(dateObj),
      date: date
    });
  });
}

return [{
  json: {
    available_slots: formatted,
    total_slots: formatted.length
  }
}];
```

#### Task 3.3: Implementar Tool "create_meeting"

**Node:** `Function: Validate Meeting Data`

```javascript
// INPUT: attendee_name, attendee_contact, meeting_type, selected_slot, duration
const data = $json;

// Validações
if (!data.attendee_name || data.attendee_name.length < 3) {
  throw new Error('Nome do participante inválido');
}

if (!data.attendee_contact) {
  throw new Error('Contato do participante obrigatório');
}

if (!['online', 'presencial'].includes(data.meeting_type)) {
  throw new Error('Tipo de reunião deve ser "online" ou "presencial"');
}

// Extrair email/phone do contato
let attendee_email = null;
let attendee_phone = null;

if (data.attendee_contact.includes('@')) {
  attendee_email = data.attendee_contact;
} else {
  // Limpar e formatar telefone
  attendee_phone = data.attendee_contact.replace(/\D/g, '');
  if (!attendee_phone.startsWith('55')) {
    attendee_phone = '55' + attendee_phone;
  }
}

// Se tipo presencial, validar localização
let location = null;
if (data.meeting_type === 'presencial') {
  const companyConfig = $('Fetch: Company Secretary Config').first().json;
  const locations = companyConfig.features.secretary_config.presencial_locations || [];

  if (data.location) {
    location = data.location;
  } else if (locations.length > 0) {
    location = locations[0]; // Default
  } else {
    throw new Error('Localização obrigatória para reunião presencial');
  }
}

return [{
  json: {
    validated_data: {
      attendee_name: data.attendee_name,
      attendee_email: attendee_email,
      attendee_phone: attendee_phone,
      meeting_type: data.meeting_type,
      selected_slot: data.selected_slot,
      duration: data.duration || 60,
      location: location
    }
  }
}];
```

**Node:** `HTTP Request: Cal.com Create Booking`

```json
{
  "method": "POST",
  "url": "https://api.cal.com/v2/bookings",
  "headers": {
    "Authorization": "Bearer {{ $('Fetch: Company Secretary Config').first().json.features.secretary_config.cal_api_key }}",
    "Content-Type": "application/json",
    "cal-api-version": "2024-08-13"
  },
  "body": {
    "eventTypeId": "={{ $('Fetch: Company Secretary Config').first().json.features.secretary_config.default_event_type_id }}",
    "start": "={{ $('Function: Validate Meeting Data').first().json.validated_data.selected_slot }}",
    "lengthInMinutes": "={{ $('Function: Validate Meeting Data').first().json.validated_data.duration }}",
    "attendee": {
      "name": "={{ $('Function: Validate Meeting Data').first().json.validated_data.attendee_name }}",
      "email": "={{ $('Function: Validate Meeting Data').first().json.validated_data.attendee_email }}",
      "phoneNumber": "={{ '+' + $('Function: Validate Meeting Data').first().json.validated_data.attendee_phone }}",
      "timeZone": "America/Sao_Paulo",
      "language": "pt"
    },
    "location": "={{ $('Function: Validate Meeting Data').first().json.validated_data.meeting_type === 'presencial' ? {'type': 'address', 'value': $('Function: Validate Meeting Data').first().json.validated_data.location} : {'type': 'integrations:google:meet'} }}",
    "metadata": {
      "scheduled_by": "secretary_mode",
      "requested_by_user_id": "={{ $('Prepare: Secretary Context').first().json.authorized_user_id }}",
      "meeting_type": "={{ $('Function: Validate Meeting Data').first().json.validated_data.meeting_type }}"
    }
  }
}
```

**Node:** `Save: Secretary Appointment Record`

```javascript
// Salvar em corev4_secretary_appointments
const calResponse = $('HTTP Request: Cal.com Create Booking').first().json.data;
const validatedData = $('Function: Validate Meeting Data').first().json.validated_data;
const context = $('Prepare: Secretary Context').first().json;

const insert = {
  company_id: context.company_id,
  requested_by_user_id: context.authorized_user_id,
  attendee_name: validatedData.attendee_name,
  attendee_email: validatedData.attendee_email,
  attendee_phone: validatedData.attendee_phone,
  attendee_whatsapp: validatedData.attendee_phone ? `${validatedData.attendee_phone}@s.whatsapp.net` : null,
  meeting_type: validatedData.meeting_type,
  location: validatedData.location,
  cal_booking_uid: calResponse.uid,
  cal_event_type_id: calResponse.eventTypeId,
  cal_meeting_url: calResponse.bookingUrl || calResponse.location,
  meeting_date: calResponse.startTime,
  meeting_end_date: calResponse.endTime,
  meeting_duration_minutes: validatedData.duration,
  status: 'confirmed',
  request_message: context.original_message,
  ai_conversation: context.chat_history
};

// INSERT via Supabase node...
```

**Node:** `Send: Confirmation to Attendee`

```javascript
// Se attendee tem WhatsApp, enviar via Evolution API
if (validatedData.attendee_phone) {
  const meetingDate = new Date(calResponse.startTime);
  const formatter = new Intl.DateTimeFormat('pt-BR', {
    timeZone: 'America/Sao_Paulo',
    weekday: 'long',
    day: '2-digit',
    month: 'long',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });

  const message = `Olá ${validatedData.attendee_name}!

Você tem uma reunião agendada com ${context.owner_name}:

📅 ${formatter.format(meetingDate)}
${validatedData.meeting_type === 'online' ? '💻 Reunião Online' : '📍 Reunião Presencial'}
${validatedData.meeting_type === 'presencial' ? `\nLocal: ${validatedData.location}` : ''}
${validatedData.meeting_type === 'online' ? `\n🔗 Link: ${calResponse.bookingUrl}` : ''}

Enviaremos lembretes antes da reunião.

Atenciosamente,
Assistente de ${context.owner_name}`;

  // Enviar via HTTP Request para Evolution API...
}
```

#### Task 3.4: System Prompt Customizado

**Node:** `Prepare: Secretary System Prompt`

```javascript
const user = $('Fetch: User Profile & Permissions').first().json;
const config = $('Fetch: Company Secretary Config').first().json;

const systemPrompt = `# IDENTIDADE

Você é a Assistente Executiva Pessoal de ${user.full_name}.

# MISSÃO

Gerenciar a agenda e facilitar o agendamento de reuniões com terceiros de forma proativa e eficiente.

# CAPACIDADES DISPONÍVEIS

Você pode:
1. ✅ check_calendar_availability - Verificar horários disponíveis na agenda
2. ✅ create_meeting - Criar novos agendamentos
3. ✅ cancel_meeting - Cancelar reuniões existentes
4. ✅ list_upcoming_meetings - Listar próximos compromissos
5. ✅ reschedule_meeting - Remarcar reuniões

# PROTOCOLO DE AGENDAMENTO

## Etapa 1: Coleta de Informações
Pergunte sempre:
- Nome completo do terceiro
- Email OU WhatsApp para envio do convite
- Tipo de reunião: presencial ou online?
- Data/horário preferido (ou "próximo disponível")
- Duração estimada (padrão: 60 minutos)

## Etapa 2: Verificar Disponibilidade
- Use check_calendar_availability com as datas solicitadas
- Apresente sempre 3 opções de horários
- Se horário específico não disponível, sugira alternativas próximas

## Etapa 3: Confirmar Dados
Antes de executar, recapitule:
- ✓ Nome do participante
- ✓ Data e hora
- ✓ Tipo (online/presencial)
- ✓ Se presencial: confirme localização
- ✓ Se online: informe que link será enviado automaticamente

Aguarde confirmação explícita ("confirma", "ok", "pode agendar")

## Etapa 4: Executar e Notificar
- Use create_meeting com todos os dados
- Confirme sucesso da operação
- Informe que convite foi enviado para o terceiro

# CONTEXTO ESPECÍFICO

${config.features.secretary_config.presencial_locations ? `Localizações disponíveis para reuniões presenciais:\n${config.features.secretary_config.presencial_locations.map((l, i) => `${i+1}. ${l}`).join('\n')}` : ''}

${config.features.secretary_config.auto_confirm_bookings ? 'IMPORTANTE: Agendamentos são automáticos após você coletar as informações. Sempre confirme antes de executar.' : ''}

# TOM E ESTILO

- Profissional mas acessível
- Eficiente e proativa
- SEMPRE confirma antes de executar ações definitivas
- Use emojis com moderação para melhor UX
- Linguagem clara e objetiva

# TRATAMENTO DE ERROS

Se algo der errado:
1. Explique o problema de forma clara
2. Ofereça alternativas
3. Peça informações faltantes
4. Nunca deixe o usuário sem resposta

# EXEMPLO DE INTERAÇÃO

User: "Agenda reunião com Dr. João Silva amanhã 14h"
Assistant: *usa check_calendar_availability para verificar disponibilidade*
"Verificando agenda para amanhã às 14h... ✓

Horários disponíveis:
📅 Quarta, 13/11 às 14:00 - 15:00 ✅ (solicitado)
📅 Quarta, 13/11 às 15:00 - 16:00
📅 Quarta, 13/11 às 16:00 - 17:00

Para prosseguir, preciso de:
1️⃣ Tipo de reunião: presencial ou online?
2️⃣ Contato do Dr. João (email ou WhatsApp) para envio do convite"
`;

return [{json: {system_prompt: systemPrompt}}];
```

---

### Fase 4: Testes e Validação (4-5 horas)

#### Task 4.1: Testes Unitários de Tools

**Checklist:**
- [ ] check_calendar_availability retorna slots corretamente
- [ ] create_meeting valida todos os campos obrigatórios
- [ ] create_meeting falha apropriadamente com dados inválidos
- [ ] Formatação de datas está correta (timezone BR)
- [ ] WhatsApp numbers são formatados corretamente

#### Task 4.2: Testes de Integração

**Cenários:**
1. ✅ Authorized user envia mensagem → Roteado para Secretary Flow
2. ✅ Lead normal envia mensagem → Roteado para One Flow (qualificação)
3. ✅ Secretary Flow busca disponibilidade com sucesso
4. ✅ Secretary Flow cria agendamento online com sucesso
5. ✅ Secretary Flow cria agendamento presencial com sucesso
6. ✅ Terceiro recebe confirmação por WhatsApp
7. ✅ Registro salvo corretamente em `corev4_secretary_appointments`
8. ✅ Feature desabilitada → authorized user tratado como lead

#### Task 4.3: Testes End-to-End

**Conversas Completas:**

```
Test 1: Agendamento Online Bem-Sucedido
User: "agenda reunião online com Maria Santos amanhã 10h"
Expected: AI verifica disponibilidade → pede email → confirma dados → executa → sucesso

Test 2: Horário Indisponível
User: "agenda reunião com Pedro hoje 8h"
Expected: AI verifica → horário indisponível → sugere 3 alternativas → user escolhe

Test 3: Agendamento Presencial
User: "agenda presencial com Ana amanhã"
Expected: AI pergunta horário → verifica → pergunta localização → confirma → executa

Test 4: Dados Incompletos
User: "agenda reunião"
Expected: AI pede todos os dados necessários passo a passo
```

---

### Fase 5: Documentação e Deploy (2-3 horas)

#### Task 5.1: Documentação Técnica

Criar arquivo: `SECRETARY_MODE_GUIDE.md`

**Conteúdo:**
- Como habilitar secretary mode para um tenant
- Como adicionar authorized users
- Como configurar Cal.com API key
- Estrutura das tabelas
- Fluxo de dados completo
- Troubleshooting comum

#### Task 5.2: Documentação de Usuário

Criar arquivo: `SECRETARY_MODE_USER_MANUAL.md`

**Conteúdo:**
- Como usar a secretária via WhatsApp
- Exemplos de comandos
- Tipos de reuniões suportadas
- Como cancelar/remarcar
- FAQ

#### Task 5.3: Deploy Checklist

- [ ] Backup do banco de dados antes de migrations
- [ ] Executar migrations em staging primeiro
- [ ] Testar em staging com dados reais
- [ ] Adicionar monitoring/logs específicos
- [ ] Configurar alertas para erros Cal.com API
- [ ] Deploy em produção (fora de horário de pico)
- [ ] Monitorar primeira semana de uso

---

## ⚠️ Riscos e Mitigações

### Risco 1: Cal.com API Rate Limits

**Descrição:** Cal.com pode ter limites de requisições por minuto

**Probabilidade:** Média
**Impacto:** Alto

**Mitigação:**
- Implementar caching de slots disponíveis (5 minutos)
- Adicionar retry logic com exponential backoff
- Monitorar uso via logs
- Documentar limites na Cal.com API

### Risco 2: Conflito de Conceitos (Lead vs Authorized User)

**Descrição:** Confusão na base entre quem é lead e quem é usuário interno

**Probabilidade:** Baixa
**Impacto:** Alto

**Mitigação:**
- Tabelas completamente separadas
- Router com lógica clara de prioridade (authorized user primeiro)
- Testes extensivos de roteamento
- Logs detalhados de routing decisions

### Risco 3: Terceiros Não Recebem Convites

**Descrição:** Evolution API falha ao enviar WhatsApp ou email Cal.com não entrega

**Probabilidade:** Média
**Impacto:** Alto

**Mitigação:**
- Implementar sistema de retry (3 tentativas)
- Salvar status de envio em `corev4_secretary_appointments`
- Alertar authorized user se envio falhar
- Fallback: enviar link manual se automático falhar

### Risco 4: AI Cria Agendamento Sem Confirmar

**Descrição:** GPT-4o-mini executa tool sem esperar confirmação do user

**Probabilidade:** Baixa
**Impacto:** Médio

**Mitigação:**
- System prompt EXPLÍCITO sobre sempre confirmar
- Adicionar validação no tool: checar se mensagem anterior era confirmação
- Implementar "undo" para agendamentos (cancelamento rápido)
- Logs de todas as execuções

### Risco 5: Custos Cal.com Aumentam

**Descrição:** Criar agendamentos programaticamente pode ter custo diferente

**Probabilidade:** Baixa
**Impacto:** Médio

**Mitigação:**
- Verificar plano Cal.com antes de implementar
- Monitorar quantidade de agendamentos/mês
- Adicionar limite configurável por empresa
- Documentar custos na proposta comercial

---

## 📊 Cronograma e Estimativas

### Resumo por Fase

| Fase | Duração | Complexidade | Dependências |
|------|---------|--------------|--------------|
| 1. Banco de Dados | 2-3h | Baixa | Nenhuma |
| 2. Router | 3-4h | Média | Fase 1 |
| 3. Secretary Flow | 8-10h | Alta | Fases 1 e 2 |
| 4. Testes | 4-5h | Média | Fase 3 |
| 5. Documentação/Deploy | 2-3h | Baixa | Todas |
| **TOTAL** | **19-25h** | - | - |

### Timeline Sugerido (1 semana)

**Dia 1 (Segunda):**
- Manhã: Fase 1 completa (banco de dados)
- Tarde: Iniciar Fase 2 (router modifications)

**Dia 2 (Terça):**
- Manhã: Concluir Fase 2
- Tarde: Iniciar Fase 3 (secretary flow base structure)

**Dia 3 (Quarta):**
- Dia inteiro: Fase 3 - Implementar tools principais

**Dia 4 (Quinta):**
- Manhã: Concluir Fase 3
- Tarde: Iniciar Fase 4 (testes unitários)

**Dia 5 (Sexta):**
- Manhã: Concluir testes + correções
- Tarde: Fase 5 (documentação) + deploy staging

**Fim de Semana:**
- Monitorar staging

**Dia 6 (Segunda seguinte):**
- Deploy produção (horário baixo movimento)
- Monitoramento intensivo

---

## 💡 Considerações Técnicas

### Performance

**Otimizações Recomendadas:**

1. **Caching de Slots Disponíveis:**
   ```javascript
   // Cache slots por 5 minutos
   const cacheKey = `calendar_slots_${eventTypeId}_${startDate}_${endDate}`;
   const cached = await redis.get(cacheKey);
   if (cached) return JSON.parse(cached);

   const slots = await calcomAPI.getSlots(...);
   await redis.set(cacheKey, JSON.stringify(slots), 'EX', 300);
   ```

2. **Índices no Banco:**
   - ✅ Já incluídos no schema
   - `idx_authorized_users_whatsapp` (para lookup rápido)
   - `idx_secretary_appointments_meeting_date` (para queries de agenda)

3. **Async Processing:**
   - Envio de WhatsApp para terceiro pode ser async (background job)
   - Não bloquear resposta ao authorized user

### Segurança

**Pontos de Atenção:**

1. **API Keys:**
   - Cal.com API key armazenada em `corev4_companies.features` (JSONB)
   - ⚠️ **CRÍTICO:** Habilitar RLS (Row Level Security) em `corev4_companies`
   - Nunca expor API keys em logs

2. **Permissions:**
   - Checar `permissions` JSONB antes de executar cada action
   - Exemplo: Se `schedule_meetings: false`, negar tool execution

3. **Rate Limiting:**
   - Implementar limite de agendamentos por usuário/dia
   - Prevenir spam ou uso abusivo

4. **Data Validation:**
   - Sempre validar dados antes de chamar Cal.com API
   - Sanitize user input (nomes, emails, etc.)

### Escalabilidade

**Preparado Para:**

- ✅ Múltiplos tenants (multi-tenancy já existe)
- ✅ Múltiplos authorized users por empresa
- ✅ Centenas de agendamentos/dia por empresa
- ✅ Diferentes tipos de reuniões (online/presencial)

**Limitações:**

- ❌ Não suporta múltiplos calendários (apenas 1 eventTypeId por empresa)
  - **Solução futura:** Array de `event_types` em secretary_config

- ❌ Não suporta recorrências (reuniões semanais, etc.)
  - **Solução futura:** Adicionar tool `create_recurring_meeting`

---

## 🎯 Próximos Passos (Pós-MVP)

### Features Futuras

1. **Cancelamento e Remarcação:**
   - Tools: `cancel_meeting`, `reschedule_meeting`
   - UI para authorized user ver agenda completa

2. **Múltiplos Calendários:**
   - Permitir escolher entre "Consultoria", "Mesa de Clareza", etc.
   - AI pergunta tipo de reunião primeiro

3. **Reuniões Internas:**
   - Agendar reunião entre dois authorized users
   - Checa disponibilidade de ambos

4. **Integração com CRM:**
   - Criar lead no CRM quando agenda reunião com terceiro
   - Sincronizar status do agendamento

5. **Analytics Dashboard:**
   - Quantidade de agendamentos via secretária
   - Taxa de conversão (agendado → realizado)
   - Usuários mais ativos

6. **Voice Messages:**
   - Suporte a áudio para solicitações
   - Transcribe via Whisper → processa normalmente

---

## ✅ Conclusão

### Viabilidade: CONFIRMADA

✅ **A Cal.com API v2 suporta TODAS as funcionalidades necessárias**
✅ **A arquitetura do CoreAdapt permite implementação modular**
✅ **Multi-tenancy já existe e será preservado**
✅ **Estimativa: 19-25 horas de desenvolvimento (1 semana)**

### Recomendação Final

**IMPLEMENTAR COMO MÓDULO OPCIONAL DO COREADAPT**

**Motivos:**
1. Aproveita 100% da infraestrutura existente
2. Mantém a identidade do produto
3. Permite coexistência de funcionalidades
4. Comercialização como feature premium
5. Não quebra nada existente (feature flag)

### Próxima Ação

**Para o cliente (advogado):**
- Obter Cal.com API key (Settings > Security)
- Identificar eventTypeId desejado
- Definir localizações para reuniões presenciais

**Para desenvolvimento:**
- Aprovação deste plano
- Confirmação de timeline (1 semana)
- Criar branch `feature/secretary-mode`
- Iniciar Fase 1 (banco de dados)

---

## 📚 Referências

- [Cal.com API v2 Documentation](https://cal.com/docs/api-reference/v2)
- [Cal.com Bookings Endpoint](https://cal.com/docs/api-reference/v2/bookings/create-a-booking)
- [Cal.com Slots Endpoint](https://cal.com/docs/api-reference/v2/slots/get-available-time-slots-for-an-event-type)
- CoreAdapt v4 Architecture (arquivo: `DEEP_DIVE_STUDY_COREADAPT_V4.md`)

---

**Documento criado por:** Claude Code Analysis
**Data:** 12 de Novembro de 2025
**Versão:** 1.0 - Final