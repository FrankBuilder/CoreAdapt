# Instruções de Integração dos Flows

**Versão:** 1.0
**Data:** 2025-12-10

Este documento detalha as modificações necessárias nos flows existentes para habilitar o agendamento autônomo.

---

## Índice

1. [Visão Geral das Mudanças](#visão-geral)
2. [CoreAdapt One Flow](#one-flow)
3. [CoreAdapt Main Router Flow](#main-router)
4. [Ordem de Execução](#ordem-execução)
5. [Testes](#testes)

---

## Visão Geral das Mudanças {#visão-geral}

### Novos Flows Criados
- ✅ `CoreAdapt Availability Flow _ v4.json` - Consulta disponibilidade
- ✅ `CoreAdapt Booking Flow _ v4.json` - Cria agendamentos

### Flows a Modificar
- 🔄 `CoreAdapt One Flow _ v4.json` - Adicionar state machine
- 🔄 `CoreAdapt Main Router Flow _ v4.json` - Adicionar query de estado

### Arquivos de Suporte Criados
- ✅ `nodes/autonomous_scheduling_nodes.js` - Código JavaScript dos nodes
- ✅ `nodes/autonomous_scheduling_queries.sql` - Queries SQL

---

## CoreAdapt One Flow {#one-flow}

### Mudanças Necessárias

#### 1. Adicionar Node: "Query: Get Conversation State"

**Tipo:** `n8n-nodes-base.postgres`
**Posição:** Após receber dados do lead, ANTES de "Prepare: Chat Context"

**Query SQL:**
```sql
SELECT
    c.id AS chat_id,
    c.conversation_state,
    c.pending_offer_id,
    o.id AS offer_id,
    o.status AS offer_status,
    o.slot_1_datetime,
    o.slot_1_label,
    o.slot_2_datetime,
    o.slot_2_label,
    o.slot_3_datetime,
    o.slot_3_label,
    CASE
        WHEN o.id IS NOT NULL AND o.expires_at > NOW() AND o.status = 'pending'
        THEN true
        ELSE false
    END AS has_valid_offer
FROM corev4_chats c
LEFT JOIN corev4_pending_slot_offers o
    ON o.id = c.pending_offer_id
    AND o.status IN ('pending', 'needs_confirmation')
WHERE c.contact_id = $1
  AND c.company_id = $2
ORDER BY c.created_at DESC
LIMIT 1
```

**Parâmetros:** `[$json.contact_id, $json.company_id]`

---

#### 2. Adicionar Node: "Check: Conversation State"

**Tipo:** `n8n-nodes-base.if`
**Posição:** Após "Query: Get Conversation State"

**Condição:**
```
$json.conversation_state === 'awaiting_slot_selection' AND $json.has_valid_offer === true
```

**Saídas:**
- TRUE → "Parse: Slot Selection"
- FALSE → "Prepare: Chat Context" (fluxo normal)

---

#### 3. Adicionar Node: "Parse: Slot Selection"

**Tipo:** `n8n-nodes-base.code`
**Posição:** Saída TRUE do "Check: Conversation State"

**Código:** Ver arquivo `nodes/autonomous_scheduling_nodes.js`, função `parseSlotSelection`

---

#### 4. Adicionar Node: "Check: Selection Detected"

**Tipo:** `n8n-nodes-base.if`
**Posição:** Após "Parse: Slot Selection"

**Condição:**
```
$json.slot_selection.selection_detected === true AND $json.slot_selection.confidence >= 0.7
```

**Saídas:**
- TRUE → "HTTP: Call Booking Flow"
- FALSE → "Prepare: Chat Context" (FRANK processa normalmente)

---

#### 5. Adicionar Node: "HTTP: Call Booking Flow"

**Tipo:** `n8n-nodes-base.httpRequest`
**Posição:** Saída TRUE do "Check: Selection Detected"

**Configuração:**
```json
{
  "method": "POST",
  "url": "{{$env.N8N_WEBHOOK_URL}}/webhook/create-booking",
  "sendBody": true,
  "bodyParameters": {
    "offer_id": "={{ $json.pending_offer_id }}",
    "selected_slot": "={{ $json.slot_selection.selected_slot }}"
  }
}
```

---

#### 6. Adicionar Node: "Handle: Booking Response"

**Tipo:** `n8n-nodes-base.code`
**Posição:** Após "HTTP: Call Booking Flow"

**Código:** Ver arquivo `nodes/autonomous_scheduling_nodes.js`, função `handleBookingResponse`

---

#### 7. Adicionar Node: "Check: Should Offer Slots"

**Tipo:** `n8n-nodes-base.code`
**Posição:** Após resposta do FRANK (AI Agent), ANTES de enviar WhatsApp

**Código:** Ver arquivo `nodes/autonomous_scheduling_nodes.js`, função `checkShouldOfferSlots`

---

#### 8. Adicionar Node: "HTTP: Call Availability Flow"

**Tipo:** `n8n-nodes-base.httpRequest`
**Posição:** Se "Check: Should Offer Slots" retornar `should_offer_slots = true`

**Configuração:**
```json
{
  "method": "POST",
  "url": "{{$env.N8N_WEBHOOK_URL}}/webhook/availability-check",
  "sendBody": true,
  "bodyParameters": {
    "contact_id": "={{ $json.contact_id }}",
    "company_id": "={{ $json.company_id }}"
  }
}
```

---

#### 9. Adicionar Node: "Inject: Slots into Message"

**Tipo:** `n8n-nodes-base.code`
**Posição:** Após "HTTP: Call Availability Flow"

**Código:**
```javascript
const availResponse = $json;
const originalMessage = $('CoreAdapt One AI Agent').first().json.output || '';

if (!availResponse.success) {
  // Sem slots - manter mensagem original ou adicionar fallback
  return [{
    json: {
      final_message: originalMessage,
      conversation_state: 'normal'
    }
  }];
}

// Substituir placeholder ou anexar slots
let finalMessage = originalMessage;

// Se mensagem tem placeholder
if (finalMessage.includes('[HORARIOS]') || finalMessage.includes('{slots}')) {
  finalMessage = finalMessage
    .replace('[HORARIOS]', availResponse.offer_message)
    .replace('{slots}', availResponse.offer_message);
} else {
  // Anexar slots ao final
  finalMessage = originalMessage + '\n\n' + availResponse.offer_message;
}

return [{
  json: {
    final_message: finalMessage,
    pending_offer_id: availResponse.offer_id,
    conversation_state: 'awaiting_slot_selection'
  }
}];
```

---

### Diagrama de Conexões Atualizado

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         COREADAPT ONE FLOW (v7.0)                            │
├─────────────────────────────────────────────────────────────────────────────┤

  Entrada (do Main Router)
       │
       ▼
  ┌─────────────────────┐
  │ Query: Get          │ ◄── NOVO
  │ Conversation State  │
  └──────────┬──────────┘
             │
             ▼
  ┌─────────────────────┐
  │ Check: Conversation │ ◄── NOVO
  │ State               │
  └──────────┬──────────┘
             │
   ┌─────────┴─────────┐
   │                   │
(awaiting)          (normal)
   │                   │
   ▼                   ▼
┌──────────────┐  ┌─────────────────┐
│ Parse: Slot  │  │ Prepare: Chat   │ ◄── EXISTENTE
│ Selection    │  │ Context         │
└──────┬───────┘  └────────┬────────┘
       │                   │
       ▼                   ▼
┌──────────────┐  ┌─────────────────┐
│ Check:       │  │ Enrich: ANUM    │ ◄── EXISTENTE
│ Selection?   │  │ and Preferences │
└──────┬───────┘  └────────┬────────┘
       │                   │
  ┌────┴────┐              ▼
  │         │     ┌─────────────────┐
(yes)     (no)    │ Check: Can      │ ◄── EXISTENTE
  │         │     │ Offer Meeting   │
  │         │     └────────┬────────┘
  │         │              │
  ▼         │              ▼
┌──────────────┐ │  ┌─────────────────┐
│ HTTP: Call   │ │  │ CoreAdapt One   │ ◄── EXISTENTE
│ Booking Flow │ │  │ AI Agent        │
└──────┬───────┘ │  └────────┬────────┘
       │         │           │
       ▼         │           ▼
┌──────────────┐ │  ┌─────────────────┐
│ Handle:      │ │  │ Check: Should   │ ◄── NOVO
│ Booking Resp │ │  │ Offer Slots?    │
└──────┬───────┘ │  └────────┬────────┘
       │         │           │
       │         │    ┌──────┴──────┐
       │         │    │             │
       │         │  (yes)         (no)
       │         │    │             │
       │         │    ▼             │
       │         │ ┌──────────────┐ │
       │         │ │ HTTP: Call   │ │
       │         │ │ Availability │ │
       │         │ │ Flow         │ │
       │         │ └──────┬───────┘ │
       │         │        │         │
       │         │        ▼         │
       │         │ ┌──────────────┐ │
       │         │ │ Inject:      │ │
       │         │ │ Slots into   │ │
       │         │ │ Message      │ │
       │         │ └──────┬───────┘ │
       │         │        │         │
       │         └────────┼─────────┘
       │                  │
       │    ┌─────────────┘
       │    │
       ▼    ▼
  ┌─────────────────┐
  │ Split: Message  │ ◄── EXISTENTE
  │ into Chunks     │
  └────────┬────────┘
           │
           ▼
  ┌─────────────────┐
  │ Send: WhatsApp  │ ◄── EXISTENTE
  │ Text            │
  └─────────────────┘
```

---

## CoreAdapt Main Router Flow {#main-router}

### Mudanças Necessárias

#### 1. Adicionar Query de Estado no contexto passado para One Flow

No node que prepara os dados para chamar o One Flow, adicionar o campo `conversation_state`:

**Antes:**
```javascript
return [{
  json: {
    contact_id: contact.id,
    company_id: contact.company_id,
    message_content: messageContent,
    // ... outros campos
  }
}];
```

**Depois:**
```javascript
return [{
  json: {
    contact_id: contact.id,
    company_id: contact.company_id,
    message_content: messageContent,
    // NOVO: estado da conversa
    conversation_state: contact.conversation_state || 'normal',
    pending_offer_id: contact.pending_offer_id || null,
    // ... outros campos
  }
}];
```

---

#### 2. Atualizar Query de Busca do Contato

Adicionar JOIN com `corev4_chats` para trazer o estado:

**Query Atualizada:**
```sql
SELECT
    c.id,
    c.company_id,
    c.full_name,
    c.whatsapp,
    -- ... outros campos existentes
    -- NOVO: estado da conversa
    ch.conversation_state,
    ch.pending_offer_id
FROM corev4_contacts c
LEFT JOIN corev4_chats ch ON ch.contact_id = c.id AND ch.company_id = c.company_id
WHERE c.whatsapp = $1
  AND c.company_id = $2
  AND c.is_active = true
ORDER BY ch.created_at DESC NULLS LAST
LIMIT 1
```

---

## Ordem de Execução {#ordem-execução}

### Passo a Passo para Deploy

1. **Backup dos flows atuais**
   ```bash
   cp "CoreAdapt One Flow _ v4.json" "CoreAdapt One Flow _ v4_BEFORE_AUTONOMOUS.json"
   cp "CoreAdapt Main Router Flow _ v4.json" "CoreAdapt Main Router Flow _ v4_BEFORE_AUTONOMOUS.json"
   ```

2. **Executar migrations**
   ```bash
   psql -f migrations/create_calendar_settings_table.sql
   psql -f migrations/create_pending_slot_offers_table.sql
   psql -f migrations/add_conversation_state_column.sql
   ```

3. **Importar novos flows**
   - Importar `CoreAdapt Availability Flow _ v4.json`
   - Importar `CoreAdapt Booking Flow _ v4.json`
   - Manter desativados inicialmente

4. **Modificar Main Router Flow**
   - Adicionar query de estado conforme instruções acima

5. **Modificar One Flow**
   - Adicionar nodes conforme diagrama
   - Conectar nodes existentes aos novos

6. **Ativar novos flows**
   - Ativar Availability Flow
   - Ativar Booking Flow

7. **Testar**
   - Usar contato de teste
   - Verificar logs de cada step

---

## Testes {#testes}

### Cenário 1: Oferta de Horários

1. Simular lead qualificado (ANUM ≥55)
2. Lead pergunta sobre próximos passos
3. FRANK deve oferecer 3 horários
4. Verificar:
   - `conversation_state` = 'awaiting_slot_selection'
   - Oferta criada em `corev4_pending_slot_offers`

### Cenário 2: Seleção de Slot

1. Usar cenário 1 como base
2. Lead responde "2" ou "o segundo"
3. Verificar:
   - Booking criado em `corev4_scheduled_meetings`
   - Oferta atualizada para 'confirmed'
   - `conversation_state` = 'normal'
   - Confirmação enviada

### Cenário 3: Resposta Ambígua

1. Usar cenário 1 como base
2. Lead responde "o da tarde"
3. Verificar:
   - Parser detecta com baixa confiança
   - FRANK pede confirmação

### Cenário 4: Nenhum Slot Disponível

1. Preencher agenda com reuniões
2. Simular oferta de Mesa
3. Verificar:
   - Fallback para link Cal.com
   - Mensagem apropriada ao lead

### Cenário 5: Expiração de Oferta

1. Criar oferta
2. Aguardar 24h (ou simular)
3. Verificar:
   - Status atualizado para 'expired'
   - Nova oferta pode ser criada

---

## Checklist Final

- [ ] Migrations executadas
- [ ] Availability Flow importado e ativo
- [ ] Booking Flow importado e ativo
- [ ] Main Router atualizado com query de estado
- [ ] One Flow atualizado com novos nodes
- [ ] Credenciais configuradas
- [ ] Testes de cenário 1 passando
- [ ] Testes de cenário 2 passando
- [ ] Testes de cenário 3 passando
- [ ] Testes de cenário 4 passando
- [ ] Monitoramento configurado

---

**Próximos Passos:**
1. Aplicar modificações nos flows
2. Executar testes E2E
3. Deploy gradual (shadow mode)
4. Monitoramento por 48h
5. Rollout completo
