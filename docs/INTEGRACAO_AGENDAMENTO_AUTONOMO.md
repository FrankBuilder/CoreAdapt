# Integracao do Agendamento Autonomo no CoreAdapt One Flow

## Visao Geral da Arquitetura

```
                                    +------------------+
                                    | Slot Parser Flow |
                                    | (nova)           |
                                    +--------+---------+
                                             ^
                                             | HTTP POST
+----------------+     +------------------+  |  +-----------------+
| Main Router    | --> | One Flow         +--+->| Availability    |
| (webhook)      |     | (modificado)     |     | Flow (existente)|
+----------------+     +------------------+     +-----------------+
                                |                       |
                                v                       v
                       +------------------+     +-----------------+
                       | AI Agent (FRANK) |     | Booking Flow    |
                       +------------------+     | (existente)     |
                                               +-----------------+
```

## Fluxos Envolvidos

| Fluxo | Endpoint | Funcao |
|-------|----------|--------|
| **Slot Parser** (novo) | `/webhook/parse-slot-selection` | Interpreta resposta do lead |
| **Availability** (existente) | `/webhook/availability-check` | Gera slots disponiveis |
| **Booking** (existente) | `/webhook/create-booking` | Cria reuniao |
| **One Flow** (modificar) | - | Orquestra tudo |

---

## Passo 1: Executar Migracoes

Execute no Supabase SQL Editor:

```sql
-- 1. Migracoes ja executadas (verificar se existem):
--    - corev4_calendar_settings
--    - corev4_pending_slot_offers

-- 2. Nova migracao necessaria:
-- Arquivo: migrations/EXECUTAR_CONVERSATION_STATE.sql
```

---

## Passo 2: Importar Novos Fluxos no n8n

1. Importar `CoreAdapt Slot Parser Flow _ v4.json`
2. Verificar se `CoreAdapt Availability Flow _ v4.json` esta importado
3. Verificar se `CoreAdapt Booking Flow _ v4.json` esta importado

---

## Passo 3: Modificacoes no One Flow

### 3.1 Adicionar Node: Fetch Conversation State

**Posicao:** Logo apos "Prepare: Chat Context"

**Tipo:** Postgres (executeQuery)

```sql
-- Buscar estado da conversa e oferta pendente
SELECT
  c.conversation_state,
  c.pending_offer_id,
  c.state_data,
  o.id AS offer_id,
  o.status AS offer_status,
  CASE
    WHEN o.id IS NOT NULL AND o.expires_at > NOW() AND o.status IN ('pending', 'needs_confirmation')
    THEN true ELSE false
  END AS has_valid_offer
FROM corev4_chats c
LEFT JOIN corev4_pending_slot_offers o ON o.id = c.pending_offer_id
WHERE c.contact_id = $1 AND c.company_id = $2
ORDER BY c.created_at DESC
LIMIT 1
```

**Query Replacement:**
```javascript
={{ [$json.contact_id, $json.company_id] }}
```

### 3.2 Adicionar Node: Route by Conversation State

**Posicao:** Apos "Fetch Conversation State"

**Tipo:** Switch

**Condicoes:**

| Saida | Condicao | Valor |
|-------|----------|-------|
| 0 | conversation_state equals | `awaiting_slot_selection` |
| 1 | conversation_state equals | `confirming_slot` |
| 2 | default | (todos os outros) |

### 3.3 Adicionar Node: Call Slot Parser

**Posicao:** Saida 0 e 1 do Switch acima

**Tipo:** HTTP Request

```
Method: POST
URL: {{ $env.N8N_WEBHOOK_URL }}/webhook/parse-slot-selection
```

**Body:**
```json
{
  "contact_id": "{{ $json.contact_id }}",
  "company_id": "{{ $json.company_id }}",
  "message": "{{ $json.message_content }}"
}
```

### 3.4 Adicionar Node: Handle Parser Response

**Tipo:** Switch

**Condicoes baseadas em `action`:**

| Saida | Condicao | Acao |
|-------|----------|------|
| 0 | action = `booking_created` | Fim (booking feito) |
| 1 | action = `needs_confirmation` | Enviar mensagem de confirmacao |
| 2 | action = `needs_clarification` | Enviar mensagem de esclarecimento |
| 3 | action = `refusal` | Enviar resposta de recusa |
| 4 | action = `no_pending_offer` | Continuar para AI Agent |

### 3.5 Modificar Node: Inject Cal.com Link (SUBSTITUIR)

**ANTES:**
O node atual injeta link estatico do Cal.com na resposta do AI.

**DEPOIS:**
Criar logica para detectar quando AI quer agendar e chamar Availability Flow.

**Novo Node: Detect Scheduling Intent**

**Tipo:** Code

```javascript
const aiOutput = $('CoreAdapt One AI Agent').item.json.output || '';
const lowerOutput = aiOutput.toLowerCase();

// Detectar se AI esta tentando oferecer reuniao
const schedulingPatterns = [
  'agendar',
  'agenda',
  'horario',
  'horário',
  'reuniao',
  'reunião',
  'mesa de clareza',
  'conversa',
  'call',
  'meeting',
  'disponivel',
  'disponível',
  'quando voce pode',
  'quando você pode'
];

const hasSchedulingIntent = schedulingPatterns.some(p => lowerOutput.includes(p));

// Verificar se tem link do Cal.com (injecao antiga)
const hasCalLink = aiOutput.includes('cal.com');

return [{
  json: {
    original_output: aiOutput,
    has_scheduling_intent: hasSchedulingIntent,
    has_cal_link: hasCalLink,
    should_offer_dynamic_slots: hasSchedulingIntent && !hasCalLink,
    contact_id: $('Prepare: Chat Context').item.json.contact_id,
    company_id: $('Prepare: Chat Context').item.json.company_id
  }
}];
```

### 3.6 Adicionar Node: Call Availability Flow

**Condicao:** Quando `should_offer_dynamic_slots = true`

**Tipo:** HTTP Request

```
Method: POST
URL: {{ $env.N8N_WEBHOOK_URL }}/webhook/availability-check
```

**Body:**
```json
{
  "contact_id": "{{ $json.contact_id }}",
  "company_id": "{{ $json.company_id }}"
}
```

### 3.7 Adicionar Node: Inject Dynamic Slots

**Tipo:** Code

```javascript
const availabilityResult = $input.first().json;
const originalOutput = $('Detect Scheduling Intent').first().json.original_output;

if (availabilityResult.success && availabilityResult.slots_found > 0) {
  // Substituir output do AI pela mensagem com slots dinamicos
  return [{
    json: {
      ai_message: availabilityResult.offer_message,
      original_ai_message: originalOutput,
      slots_offered: true,
      offer_id: availabilityResult.offer_id,
      slots: availabilityResult.slots
    }
  }];
} else {
  // Fallback: manter output original com link do Cal.com
  const fallbackMessage = originalOutput.includes('cal.com')
    ? originalOutput
    : originalOutput + '\n\nVoce pode agendar pelo link: https://cal.com/francisco-pasteur-coreadapt/mesa-de-clareza-45min';

  return [{
    json: {
      ai_message: fallbackMessage,
      slots_offered: false
    }
  }];
}
```

---

## Fluxo Completo Modificado

```
[Webhook] --> [Prepare Context] --> [Fetch Conversation State]
                                           |
                                    [Route by State]
                                    /      |       \
                                   /       |        \
              awaiting_slot    confirming  |    normal
                    |              |       |        |
              [Call Parser]    [Call Parser]       |
                    |              |               |
              [Handle Response]----+               |
              /    |    |    \                     |
         booking confirm clarify refusal          |
            |      |      |       |               |
           END   [Send] [Send]  [Send]            |
                   |      |       |               |
                   +------+-------+               |
                          |                       |
                    [Continue to AI?]             |
                          |                       |
                          +-----------------------+
                                    |
                              [AI Agent]
                                    |
                          [Detect Scheduling Intent]
                                    |
                          [should_offer_dynamic_slots?]
                              /           \
                            Yes            No
                             |              |
                    [Call Availability]     |
                             |              |
                    [Inject Dynamic]   [Keep Original]
                             |              |
                             +------+-------+
                                    |
                              [Save Response]
                                    |
                              [Send WhatsApp]
```

---

## Estados da Conversa

| Estado | Significado | Proximo Passo |
|--------|-------------|---------------|
| `normal` | Conversa padrao | Rotear para AI |
| `awaiting_slot_selection` | Slots oferecidos, aguardando escolha | Parsear resposta |
| `confirming_slot` | Selecao ambigua, aguardando confirmacao | Parsear confirmacao |
| `booking_in_progress` | Criando booking | Aguardar |
| `awaiting_reschedule` | Erro no slot, aguardando nova escolha | Parsear nova escolha |

---

## Teste do Fluxo

### Cenario 1: Lead Qualificado Recebe Oferta

1. Lead com ANUM >= 55 manda mensagem
2. AI detecta momento de oferecer reuniao
3. Availability Flow gera 3 slots
4. Mensagem com slots e enviada
5. Estado muda para `awaiting_slot_selection`

### Cenario 2: Lead Seleciona Slot

1. Lead responde "1" ou "primeiro"
2. Parser detecta selecao com alta confianca
3. Booking Flow cria reuniao
4. Confirmacao e enviada
5. Estado volta para `normal`

### Cenario 3: Selecao Ambigua

1. Lead responde "amanha de tarde"
2. Parser encontra match com confianca < 0.8
3. Mensagem de confirmacao enviada
4. Estado muda para `confirming_slot`

### Cenario 4: Lead Recusa

1. Lead responde "nenhum desses" ou "outro dia"
2. Parser detecta recusa
3. Oferta cancelada
4. Mensagem com alternativa (link) enviada
5. Estado volta para `normal`

---

## Checklist de Implementacao

- [ ] Executar `EXECUTAR_CONVERSATION_STATE.sql`
- [ ] Importar `CoreAdapt Slot Parser Flow _ v4.json`
- [ ] Ativar Slot Parser Flow
- [ ] Ativar Availability Flow
- [ ] Ativar Booking Flow
- [ ] Modificar One Flow conforme passos 3.1 a 3.7
- [ ] Testar cenarios 1-4
- [ ] Monitorar logs de erros
- [ ] Verificar metricas em `corev4_pending_slot_offers`
