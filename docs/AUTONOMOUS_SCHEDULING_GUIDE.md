# Guia de Implementação: Agendamento Autônomo

**Versão:** 1.0
**Data:** 2025-12-10
**Autor:** CoreAdapt Team

---

## Visão Geral

O Agendamento Autônomo permite que o agente FRANK verifique disponibilidade, ofereça horários e agende reuniões diretamente na conversa do WhatsApp, sem necessidade do lead clicar em links externos.

### Benefícios

| Aspecto | Antes (Cal.com) | Depois (Autônomo) |
|---------|-----------------|-------------------|
| Conversão | ~40% | ~65% estimado |
| Tempo para booking | 5-30 min | <2 min |
| Fricção | 4-6 clicks | 1 mensagem |
| Saída do WhatsApp | Sim | Não |
| Experiência | Fragmentada | Fluida |

---

## Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUXO DE AGENDAMENTO AUTÔNOMO             │
├─────────────────────────────────────────────────────────────┤

    Lead qualificado (ANUM ≥55)
              │
              ▼
    ┌─────────────────────┐
    │  FRANK detecta      │
    │  momento de oferta  │
    └──────────┬──────────┘
               │
               ▼
    ┌─────────────────────┐
    │  Call: Availability │◄─── CoreAdapt Availability Flow
    │  Flow               │
    └──────────┬──────────┘
               │
               ▼
    ┌─────────────────────┐
    │  FRANK oferece 3    │
    │  horários           │
    │  1️⃣ 2️⃣ 3️⃣           │
    └──────────┬──────────┘
               │
               ▼
    ┌─────────────────────┐
    │  conversation_state │
    │  = awaiting_slot    │
    └──────────┬──────────┘
               │
               ▼
    ┌─────────────────────┐
    │  Lead responde "2"  │
    └──────────┬──────────┘
               │
               ▼
    ┌─────────────────────┐
    │  Parser detecta     │
    │  seleção            │
    └──────────┬──────────┘
               │
               ▼
    ┌─────────────────────┐
    │  Call: Booking Flow │◄─── CoreAdapt Booking Flow
    └──────────┬──────────┘
               │
               ▼
    ┌─────────────────────┐
    │  Confirmação        │
    │  instantânea        │
    └─────────────────────┘
```

---

## Componentes

### 1. Tabelas de Banco de Dados

#### `corev4_calendar_settings`
Configurações de calendário por empresa.

```sql
-- Campos principais:
- company_id          -- FK para empresa
- calendar_provider   -- 'google', 'cal_com', 'outlook'
- timezone            -- 'America/Sao_Paulo'
- business_hours_*    -- Horário comercial
- meeting_duration    -- Duração padrão (45 min)
- min_notice_hours    -- Antecedência mínima (24h)
- max_days_ahead      -- Máximo futuro (14 dias)
- allowed_weekdays    -- Dias permitidos
- excluded_dates      -- Feriados/férias
- preferred_time_slots -- Horários preferidos (scoring)
```

#### `corev4_pending_slot_offers`
Ofertas de horários pendentes.

```sql
-- Campos principais:
- contact_id          -- FK para contato
- slot_1_datetime     -- Opção 1
- slot_2_datetime     -- Opção 2
- slot_3_datetime     -- Opção 3
- status              -- pending, selected, confirmed, expired
- selected_slot       -- 1, 2 ou 3
- expires_at          -- Expiração (24h)
- booking_id          -- FK após confirmação
```

#### `corev4_chats.conversation_state`
Estado da conversa para state machine.

```sql
-- Estados possíveis:
- 'normal'                  -- Padrão
- 'awaiting_slot_selection' -- Aguardando escolha
- 'confirming_slot'         -- Confirmando ambíguo
- 'booking_in_progress'     -- Criando booking
```

---

### 2. Flows n8n

#### CoreAdapt Availability Flow

**Endpoint:** `POST /webhook/availability-check`

**Input:**
```json
{
  "company_id": 1,
  "contact_id": 1001
}
```

**Output (sucesso):**
```json
{
  "success": true,
  "offer_id": 123,
  "slots": [
    {"index": 1, "datetime": "2025-12-12T14:00:00Z", "label": "Quinta, 12/dez às 14:00"},
    {"index": 2, "datetime": "2025-12-13T10:00:00Z", "label": "Sexta, 13/dez às 10:00"},
    {"index": 3, "datetime": "2025-12-16T15:00:00Z", "label": "Segunda, 16/dez às 15:00"}
  ],
  "offer_message": "Legal! Deixa eu ver a agenda...\n\n1️⃣ Quinta, 12/dez às 14:00\n2️⃣ ...",
  "conversation_state": "awaiting_slot_selection"
}
```

**Output (sem slots):**
```json
{
  "success": false,
  "error": "no_slots_available",
  "fallback_message": "Puxa, a agenda está cheia... [link Cal.com]"
}
```

#### CoreAdapt Booking Flow

**Endpoint:** `POST /webhook/create-booking`

**Input:**
```json
{
  "offer_id": 123,
  "selected_slot": 2
}
```

**Output (sucesso):**
```json
{
  "success": true,
  "booking_created": true,
  "meeting_id": 5001,
  "meeting_datetime": "2025-12-13T10:00:00Z",
  "meeting_url": "https://meet.google.com/xxx-yyy-zzz",
  "confirmation_sent": true
}
```

---

### 3. Algoritmo de Seleção de Slots

#### Critérios de Scoring

```javascript
// Score base: 100 pontos

// 1. Dia da semana (preferência)
monday: +20    // Segunda
tuesday: +30   // Terça (preferido)
wednesday: +30 // Quarta (preferido)
thursday: +30  // Quinta (preferido)
friday: +10    // Sexta

// 2. Horário (preferência)
10:00-12:00: +30 (manhã produtiva)
14:00-16:00: +30 (início tarde)
09:00-10:00: +20 (primeira hora)
16:00-18:00: +10 (final do dia)

// 3. Proximidade
daysFromNow < 3: +20
daysFromNow < 7: +10
```

#### Fluxo de Seleção

```
1. Gerar todos os slots possíveis (30min intervals)
2. Filtrar por:
   - Horário comercial
   - Dias permitidos
   - Datas não excluídas
   - Conflitos existentes
   - Antecedência mínima
3. Calcular score de cada slot
4. Ordenar por score (maior primeiro)
5. Pegar top N (configurável, default 3)
6. Reordenar cronologicamente para apresentação
```

---

### 4. Parser de Seleção

#### Padrões Reconhecidos

```javascript
const patterns = {
  // Número direto
  direct_number: /^[1-3]$/,

  // Com palavra "opção"
  with_option: /opção\s*([1-3])/i,

  // Ordinal
  ordinal: /(primeir|segund|terceir)/i,

  // Dia da semana
  day_name: /(segunda|terça|quarta|quinta|sexta|sábado)/i,

  // Referência temporal
  time_ref: /às?\s*(\d{1,2})(h|:00)?/i,

  // Posicional
  positional: /(primeir|últim|mei)/i,

  // Confirmação
  confirmation: /(pode ser|vamos de|marca|reserva)\s*(?:o\s*)?(\d|primeir|segund|terceir)/i
};
```

#### Níveis de Confiança

```javascript
// Alta confiança (≥0.9) - Booking automático
"2", "opção 2", "o segundo", "pode ser o 2"

// Média confiança (0.7-0.9) - Pedir confirmação
"terça" (se houver 1 opção na terça)
"às 14h" (se houver 1 opção às 14h)

// Baixa confiança (<0.7) - Pedir esclarecimento
"o da manhã" (ambíguo se houver 2 manhãs)
"amanhã" (pode ser qualquer horário)
```

---

## Instalação

### Passo 1: Executar Migrations

```bash
# Conectar ao Supabase e executar:

# 1. Tabela de configurações
psql -f migrations/create_calendar_settings_table.sql

# 2. Tabela de ofertas
psql -f migrations/create_pending_slot_offers_table.sql

# 3. Coluna de estado
psql -f migrations/add_conversation_state_column.sql
```

### Passo 2: Importar Flows no n8n

1. Abrir n8n
2. Importar `CoreAdapt Availability Flow _ v4.json`
3. Importar `CoreAdapt Booking Flow _ v4.json`
4. Configurar credenciais:
   - Postgres (Supabase)
   - Google Calendar API (opcional)
5. Ativar flows

### Passo 3: Configurar Calendário

```sql
-- Atualizar configurações da empresa
UPDATE corev4_calendar_settings
SET
  calendar_provider = 'google',
  calendar_id = 'primary',
  business_hours_start = '09:00',
  business_hours_end = '18:00',
  meeting_duration_minutes = 45,
  min_notice_hours = 24,
  max_days_ahead = 14,
  is_active = true
WHERE company_id = 1;
```

### Passo 4: Atualizar System Message

Usar `FRANK_SYSTEM_MESSAGE_v7.0.md` como referência para atualizar o prompt do agente.

### Passo 5: Testar

```bash
# Teste 1: Availability Flow
curl -X POST http://localhost:5678/webhook/availability-check \
  -H "Content-Type: application/json" \
  -d '{"company_id": 1, "contact_id": 1001}'

# Teste 2: Booking Flow
curl -X POST http://localhost:5678/webhook/create-booking \
  -H "Content-Type: application/json" \
  -d '{"offer_id": 1, "selected_slot": 2}'
```

---

## Configuração Avançada

### Horários Preferidos

```sql
-- Customizar preferências de horário
UPDATE corev4_calendar_settings
SET preferred_time_slots = '[
  {"start": "10:00", "end": "12:00", "priority": "high"},
  {"start": "14:00", "end": "16:00", "priority": "high"},
  {"start": "09:00", "end": "10:00", "priority": "medium"},
  {"start": "16:00", "end": "18:00", "priority": "low"}
]'::JSONB
WHERE company_id = 1;
```

### Dias Preferidos

```sql
-- Customizar preferência por dia
UPDATE corev4_calendar_settings
SET preferred_weekdays = '{
  "monday": 2,
  "tuesday": 3,
  "wednesday": 3,
  "thursday": 3,
  "friday": 1
}'::JSONB
WHERE company_id = 1;
```

### Feriados/Exclusões

```sql
-- Adicionar datas excluídas
UPDATE corev4_calendar_settings
SET excluded_dates = ARRAY[
  '2025-12-25'::DATE,
  '2025-12-31'::DATE,
  '2026-01-01'::DATE
]
WHERE company_id = 1;
```

### Templates Customizados

```sql
-- Customizar mensagem de oferta
UPDATE corev4_calendar_settings
SET slot_offer_template = 'Olha só os horários disponíveis:

{slots}

Qual você prefere?'
WHERE company_id = 1;

-- Customizar confirmação
UPDATE corev4_calendar_settings
SET booking_confirmation_template = 'Agendado!

Data: {date}
Hora: {time}
Link: {meeting_url}

Te vejo lá!'
WHERE company_id = 1;
```

---

## Monitoramento

### Queries Úteis

```sql
-- Ofertas pendentes (últimas 24h)
SELECT
  o.id,
  c.full_name,
  o.status,
  o.offered_at,
  o.expires_at,
  o.selected_slot
FROM corev4_pending_slot_offers o
JOIN corev4_contacts c ON o.contact_id = c.id
WHERE o.offered_at > NOW() - INTERVAL '24 hours'
ORDER BY o.offered_at DESC;

-- Taxa de conversão
SELECT
  status,
  COUNT(*) as total,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) as percentage
FROM corev4_pending_slot_offers
WHERE offered_at > NOW() - INTERVAL '7 days'
GROUP BY status;

-- Tempo médio de seleção
SELECT
  ROUND(AVG(EXTRACT(EPOCH FROM (selected_at - offered_at)) / 60), 2) as avg_minutes
FROM corev4_pending_slot_offers
WHERE status = 'confirmed'
  AND selected_at IS NOT NULL;

-- Slots mais escolhidos
SELECT
  selected_slot,
  COUNT(*) as times_selected
FROM corev4_pending_slot_offers
WHERE selected_slot IS NOT NULL
GROUP BY selected_slot
ORDER BY times_selected DESC;
```

### Alertas Recomendados

1. **Ofertas expirando:** Se >20% expira sem seleção
2. **Erros de booking:** Se taxa de erro >5%
3. **Fallback para Cal.com:** Se >10% precisa de fallback
4. **Tempo de seleção:** Se média >10min

---

## Troubleshooting

### Problema: Sem slots disponíveis

**Causa:** Agenda cheia ou configuração restritiva

**Solução:**
```sql
-- Verificar configuração
SELECT * FROM corev4_calendar_settings WHERE company_id = 1;

-- Expandir range
UPDATE corev4_calendar_settings
SET max_days_ahead = 21
WHERE company_id = 1;

-- Verificar reuniões existentes
SELECT meeting_date, meeting_end_date
FROM corev4_scheduled_meetings
WHERE status IN ('scheduled', 'confirmed')
  AND meeting_date > NOW()
ORDER BY meeting_date;
```

### Problema: Parser não reconhece seleção

**Causa:** Formato inesperado da resposta

**Solução:**
- Verificar `last_parsing_result` na oferta
- Adicionar padrão ao parser
- Pedir confirmação explícita

### Problema: Conflito de agendamento

**Causa:** Race condition entre seleção e booking

**Solução:**
- Double-check implementado no Booking Flow
- Retry automático com novos slots
- Log detalhado para análise

---

## Roadmap

### Fase 1 (Atual)
- [x] Migrations de banco
- [x] Availability Flow
- [x] Booking Flow
- [x] System Message v7.0
- [x] Documentação

### Fase 2 (Próxima)
- [ ] Integração real com Google Calendar API
- [ ] Atualização do One Flow
- [ ] Atualização do Main Router
- [ ] Testes E2E
- [ ] Deploy gradual

### Fase 3 (Futuro)
- [ ] Suporte a reagendamento
- [ ] Cancelamento via WhatsApp
- [ ] Múltiplos tipos de reunião
- [ ] Integração com Outlook
- [ ] Analytics avançado

---

## Suporte

Para dúvidas ou problemas:
1. Verificar logs do n8n
2. Consultar queries de monitoramento
3. Revisar esta documentação
4. Contatar equipe de desenvolvimento

---

**Última atualização:** 2025-12-10
