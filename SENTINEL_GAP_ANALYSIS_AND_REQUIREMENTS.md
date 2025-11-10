# SENTINEL SYSTEM — ANÁLISE DE GAPS E REQUISITOS CORRETOS

**Data:** 10 de Novembro de 2025
**Versão:** Gap Analysis v2.0
**Status:** CRÍTICO - Sistema atual não atende requisitos

---

## 🚨 RESUMO EXECUTIVO

### Problemas Identificados:

1. ❌ **TIMING ERRADO:** Sistema usa (1h, 25h, 73h, 145h, 313h) mas deveria ser (1h, 4h, 1d, 3d, 7d)
2. ❌ **SEM HORÁRIO COMERCIAL:** Sistema envia 24/7, deveria respeitar Seg-Sex 8-18h, Sáb 8-12h
3. ❌ **SEM REINÍCIO DE CONTADOR:** Quando lead responde, contador não reinicia
4. ⚠️ **OPT-OUT INCOMPLETO:** Precisa integrar com Commands para opt-out automático

---

## 📊 ANÁLISE DETALHADA

### 1. TIMING CORRETO vs IMPLEMENTADO

#### ✅ Timing Correto (Requisito):
```
Step 1: 1 hora
Step 2: 4 horas
Step 3: 1 dia (24 horas)
Step 4: 3 dias (72 horas)
Step 5: 7 dias (168 horas)
```

#### ❌ Timing Atual (Implementado):
```
Step 1: 1 hora       ✅
Step 2: 25 horas     ❌ (deveria ser 4h)
Step 3: 73 horas     ⚠️ (deveria ser 24h)
Step 4: 145 horas    ❌ (deveria ser 72h)
Step 5: 313 horas    ❌ (deveria ser 168h)
```

**Fonte do Problema:**
```javascript
// Create Followup Campaign _ v4.json:95
const defaultTiming = [1, 25, 73, 145, 313];  // ❌ ERRADO!
```

**Correção Necessária:**
```javascript
const defaultTiming = [1, 4, 24, 72, 168];  // ✅ CORRETO!
```

---

### 2. HORÁRIO COMERCIAL

#### Requisito:
```yaml
segunda_sexta:
  horario: "8:00 - 18:00"
  dias: [1, 2, 3, 4, 5]  # Segunda = 1, Sexta = 5

sabado:
  horario: "8:00 - 12:00"
  dia: 6

domingo:
  envia: false
  dia: 0
```

#### Problema Atual:
Sistema agenda `scheduled_at` sem considerar horário comercial:
- Pode agendar para 23h (fora do horário)
- Pode agendar para domingo (não deve enviar)
- Não respeita janela de horário comercial

#### Solução Proposta:

**Opção A: Ajustar no agendamento (Create Followup Campaign)**

Quando calcular `scheduled_at`, verificar:
1. Se cai fora do horário comercial → adiar para próximo horário comercial
2. Se cai domingo → adiar para segunda 8h
3. Se cai sábado após 12h → adiar para segunda 8h

```javascript
function adjustToBusinessHours(scheduledTime) {
  const date = new Date(scheduledTime);
  const dayOfWeek = date.getDay();  // 0 = Domingo, 6 = Sábado
  const hour = date.getHours();

  // Domingo → Mover para Segunda 8h
  if (dayOfWeek === 0) {
    date.setDate(date.getDate() + 1);  // Segunda
    date.setHours(8, 0, 0, 0);
    return date;
  }

  // Sábado
  if (dayOfWeek === 6) {
    // Após 12h → Mover para Segunda 8h
    if (hour >= 12) {
      date.setDate(date.getDate() + 2);  // Segunda
      date.setHours(8, 0, 0, 0);
      return date;
    }
    // Antes das 8h → Mover para 8h
    if (hour < 8) {
      date.setHours(8, 0, 0, 0);
      return date;
    }
    // Já está OK (Sábado 8-12h)
    return date;
  }

  // Seg-Sex
  // Antes das 8h → Mover para 8h
  if (hour < 8) {
    date.setHours(8, 0, 0, 0);
    return date;
  }

  // Após 18h → Mover para próximo dia 8h
  if (hour >= 18) {
    // Se sexta → Mover para segunda
    if (dayOfWeek === 5) {
      date.setDate(date.getDate() + 3);  // Segunda
    } else {
      date.setDate(date.getDate() + 1);  // Próximo dia
    }
    date.setHours(8, 0, 0, 0);
    return date;
  }

  // Já está OK (Seg-Sex 8-18h)
  return date;
}
```

**Opção B: Filtrar na execução (Sentinel Flow)**

Adicionar verificação antes de enviar:
```sql
-- View v_pending_followup_executions
-- Adicionar filtro:
AND EXTRACT(DOW FROM fe.scheduled_at) BETWEEN 1 AND 6  -- Não domingo
AND (
  -- Segunda a Sexta: 8h-18h
  (EXTRACT(DOW FROM fe.scheduled_at) BETWEEN 1 AND 5
   AND EXTRACT(HOUR FROM fe.scheduled_at) BETWEEN 8 AND 17)
  OR
  -- Sábado: 8h-12h
  (EXTRACT(DOW FROM fe.scheduled_at) = 6
   AND EXTRACT(HOUR FROM fe.scheduled_at) BETWEEN 8 AND 11)
)
```

**Recomendação:** **Opção A + B (defesa em profundidade)**
- Opção A: Já agenda no horário correto
- Opção B: Filtro de segurança na execução

---

### 3. REINÍCIO DE CONTADOR

#### Requisito:
```
Se lead responde:
1. Marca campanha: last_lead_response_at = NOW()
2. REINICIA contador daquele step
3. Se lead ficar silente novamente, começa contagem do MESMO step

Exemplo:
- Step 2 agendado para 4h
- Faltam 30min (3h30 já passaram)
- Lead responde
- Marca: last_lead_response_at = NOW()
- Se lead ficar silente de novo:
  → Contador começa novamente: NOW() + 4h (não 30min restantes!)
```

#### Problema Atual:
Sistema NÃO reinicia contador. Uma vez agendado, mantém `scheduled_at` original.

#### Solução Proposta:

**Adicionar coluna em `corev4_followup_campaigns`:**
```sql
ALTER TABLE corev4_followup_campaigns
ADD COLUMN last_lead_response_at TIMESTAMPTZ,
ADD COLUMN current_step_restart_count INTEGER DEFAULT 0;
```

**Workflow: Quando lead responde (Core One Flow)**
```javascript
// Após salvar mensagem do lead em chat_history:

// 1. Atualizar campanha
UPDATE corev4_followup_campaigns
SET
  last_lead_response_at = NOW(),
  should_continue = false,  -- Para campanha
  stopped_reason = 'lead_responded'
WHERE contact_id = {{ contact_id }}
  AND status = 'active';

// 2. Marcar execuções futuras como canceladas
UPDATE corev4_followup_executions
SET
  executed = true,
  decision_reason = 'cancelled_lead_responded'
WHERE campaign_id = {{ campaign_id }}
  AND executed = false;
```

**Workflow: Quando lead fica silente NOVAMENTE**

Criar trigger automático (ou cron job):
```sql
-- Detecta leads que responderam mas ficaram silentes novamente
SELECT
  c.id as contact_id,
  c.company_id,
  fc.id as campaign_id,
  fc.steps_completed + 1 as next_step,
  EXTRACT(EPOCH FROM (NOW() - ch.created_at)) / 3600 as hours_silent
FROM corev4_contacts c
JOIN corev4_followup_campaigns fc ON c.id = fc.contact_id
JOIN LATERAL (
  SELECT created_at
  FROM corev4_chat_history
  WHERE contact_id = c.id AND role = 'human'
  ORDER BY created_at DESC
  LIMIT 1
) ch ON true
WHERE fc.stopped_reason = 'lead_responded'
  AND fc.steps_completed < fc.total_steps
  AND EXTRACT(EPOCH FROM (NOW() - ch.created_at)) > 3600  -- Silente por 1h+
  AND NOT EXISTS (
    SELECT 1 FROM corev4_followup_executions
    WHERE campaign_id = fc.id AND executed = false
  );

-- Para cada lead encontrado:
-- 1. Reativar campanha
UPDATE corev4_followup_campaigns
SET
  should_continue = true,
  stopped_reason = NULL,
  status = 'active',
  current_step_restart_count = current_step_restart_count + 1
WHERE id = {{ campaign_id }};

-- 2. Criar nova execução para o PRÓXIMO step
INSERT INTO corev4_followup_executions (
  campaign_id, contact_id, company_id,
  step, total_steps, scheduled_at
) VALUES (
  {{ campaign_id }},
  {{ contact_id }},
  {{ company_id }},
  {{ next_step }},
  {{ total_steps }},
  {{ NOW() + interval based on next_step }}  -- Reinicia contador!
);
```

**Timing para reinício:**
```javascript
const defaultTiming = [1, 4, 24, 72, 168];  // horas
const nextStepIndex = next_step - 1;
const hoursToWait = defaultTiming[nextStepIndex];
const scheduled_at = adjustToBusinessHours(new Date(Date.now() + hoursToWait * 3600000));
```

---

### 4. OPT-OUT VIA COMMANDS

#### Requisito:
```
Lead diz: "não quero mais receber mensagens" / "pare" / "chega"
→ Sistema detecta via Commands
→ Marca opt_out = true
→ Para campanha imediatamente
```

#### Problema Atual:
Opt-out é manual (banco de dados). Não detecta automaticamente.

#### Solução Proposta:

**No Commands Flow:**

Adicionar detecção de opt-out:
```javascript
// Após classificar intenção do lead
if (intent === 'opt_out') {
  // 1. Marcar contato como opt-out
  await db.query(`
    UPDATE corev4_contacts
    SET opt_out = true, opt_out_at = NOW()
    WHERE id = $1
  `, [contact_id]);

  // 2. Parar campanha ativa
  await db.query(`
    UPDATE corev4_followup_campaigns
    SET
      should_continue = false,
      stopped_reason = 'opt_out',
      status = 'stopped'
    WHERE contact_id = $1 AND status = 'active'
  `, [contact_id]);

  // 3. Cancelar execuções futuras
  await db.query(`
    UPDATE corev4_followup_executions
    SET executed = true, decision_reason = 'cancelled_opt_out'
    WHERE contact_id = $1 AND executed = false
  `, [contact_id]);

  // 4. Enviar mensagem de confirmação
  return "Entendido! Você não receberá mais mensagens automáticas. Se mudar de ideia, é só me chamar. 👍";
}
```

**Palavras-chave para opt-out:**
```javascript
const optOutKeywords = [
  'pare', 'para', 'chega', 'para de mandar', 'não quero mais',
  'cancelar', 'desistir', 'sair', 'remover', 'excluir',
  'unsubscribe', 'opt out', 'stop'
];

function detectOptOut(message) {
  const normalizedMessage = message.toLowerCase().trim();
  return optOutKeywords.some(keyword => normalizedMessage.includes(keyword));
}
```

---

## 🔄 CONDIÇÕES DE PARADA (ATUALIZADO)

```yaml
1_reuniao_agendada:
  trigger: "INSERT em corev4_meetings com status = 'confirmed'"
  acao:
    - "UPDATE corev4_followup_campaigns SET should_continue = false, stopped_reason = 'meeting_scheduled'"
    - "UPDATE corev4_followup_executions SET executed = true, decision_reason = 'cancelled_meeting'"

2_opt_out:
  trigger: "Lead diz palavra-chave opt-out OU admin marca manual"
  acao:
    - "UPDATE corev4_contacts SET opt_out = true"
    - "UPDATE corev4_followup_campaigns SET should_continue = false, stopped_reason = 'opt_out'"
    - "UPDATE corev4_followup_executions SET executed = true, decision_reason = 'cancelled_opt_out'"

3_todos_steps_enviados:
  trigger: "steps_completed = total_steps"
  acao:
    - "UPDATE corev4_followup_campaigns SET status = 'completed', should_continue = false"

4_lead_responde:
  trigger: "Mensagem do lead em corev4_chat_history"
  acao:
    - "UPDATE corev4_followup_campaigns SET should_continue = false, stopped_reason = 'lead_responded', last_lead_response_at = NOW()"
    - "UPDATE corev4_followup_executions SET executed = true, decision_reason = 'cancelled_lead_responded'"
  nota: "Reinicia contador se lead ficar silente novamente"
```

---

## 📋 TABELAS DO BANCO - ALTERAÇÕES NECESSÁRIAS

### corev4_followup_campaigns (ADD COLUMNS)
```sql
ALTER TABLE corev4_followup_campaigns
ADD COLUMN IF NOT EXISTS last_lead_response_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS current_step_restart_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS business_hours_only BOOLEAN DEFAULT true;
```

### corev4_followup_configs (ADD COLUMNS)
```sql
ALTER TABLE corev4_followup_configs
ADD COLUMN IF NOT EXISTS business_hours_start TIME DEFAULT '08:00:00',
ADD COLUMN IF NOT EXISTS business_hours_end_weekday TIME DEFAULT '18:00:00',
ADD COLUMN IF NOT EXISTS business_hours_end_saturday TIME DEFAULT '12:00:00',
ADD COLUMN IF NOT EXISTS allow_sunday BOOLEAN DEFAULT false;
```

### corev4_followup_steps (UPDATE DATA)
```sql
-- Corrigir timing
UPDATE corev4_followup_steps
SET wait_hours = CASE step_number
  WHEN 1 THEN 1
  WHEN 2 THEN 4
  WHEN 3 THEN 24
  WHEN 4 THEN 72
  WHEN 5 THEN 168
END,
wait_minutes = 0
WHERE config_id IN (SELECT id FROM corev4_followup_configs WHERE is_active = true);
```

---

## 🎯 PLANO DE IMPLEMENTAÇÃO

### FASE 1: CORREÇÃO DE TIMING (URGENTE)

**Prioridade:** 🔴 CRÍTICA
**Tempo Estimado:** 2 horas

**Tarefas:**
1. ✅ Atualizar `defaultTiming` em `Create Followup Campaign _ v4.json`
   ```javascript
   const defaultTiming = [1, 4, 24, 72, 168];  // Correto
   ```

2. ✅ Atualizar dados em `corev4_followup_steps`
   ```sql
   UPDATE corev4_followup_steps SET wait_hours = ...
   ```

3. ✅ Atualizar System Message (Sentinel v1.1 → v1.2)
   ```
   STEP 1 (~1h)
   STEP 2 (~4h)   ← ATUALIZADO
   STEP 3 (~1d)   ← ATUALIZADO
   STEP 4 (~3d)   ← ATUALIZADO
   STEP 5 (~7d)   ← ATUALIZADO
   ```

4. ✅ Testar criação de campanha com novo timing

---

### FASE 2: HORÁRIO COMERCIAL (ALTA PRIORIDADE)

**Prioridade:** 🟠 ALTA
**Tempo Estimado:** 4 horas

**Tarefas:**
1. ✅ Adicionar função `adjustToBusinessHours()` em `Create Followup Campaign`
2. ✅ Adicionar colunas de config em `corev4_followup_configs`
3. ✅ Atualizar view `v_pending_followup_executions` com filtro de horário
4. ✅ Testar agendamento em diferentes horários (sexta 19h, sábado 14h, domingo, etc)

---

### FASE 3: REINÍCIO DE CONTADOR (MÉDIA PRIORIDADE)

**Prioridade:** 🟡 MÉDIA
**Tempo Estimado:** 6 horas

**Tarefas:**
1. ✅ Adicionar colunas em `corev4_followup_campaigns`
2. ✅ Criar workflow "Detect Silent Leads After Response"
3. ✅ Adicionar lógica de parada em `Core One Flow` quando lead responde
4. ✅ Adicionar lógica de reativação quando lead fica silente novamente
5. ✅ Testar fluxo completo: resposta → parada → silêncio → reinício

---

### FASE 4: OPT-OUT AUTOMÁTICO (MÉDIA PRIORIDADE)

**Prioridade:** 🟡 MÉDIA
**Tempo Estimado:** 3 horas

**Tarefas:**
1. ✅ Adicionar detecção de opt-out no Commands Flow
2. ✅ Adicionar lista de palavras-chave
3. ✅ Integrar com atualização de campanha/execuções
4. ✅ Testar opt-out via mensagem

---

## 📄 ARQUIVOS A ATUALIZAR

```yaml
1_create_followup_campaign:
  arquivo: "Create Followup Campaign _ v4.json"
  linha: 95
  mudanca: "defaultTiming = [1, 4, 24, 72, 168]"
  funcao_nova: "adjustToBusinessHours()"

2_sentinel_flow:
  arquivo: "CoreAdapt Sentinel Flow _ v4.json"
  linha: 328
  mudanca: "Atualizar System Message com timing correto"

3_sentinel_system_message:
  arquivo: "SENTINEL_SYSTEM_MESSAGE_v1.2.md"
  mudancas:
    - "STEP 2: ~4h (não ~1d)"
    - "STEP 3: ~1d (não ~3d)"
    - "STEP 4: ~3d (não ~6d)"
    - "STEP 5: ~7d (não ~13d)"

4_banco_dados:
  tabelas_alterar:
    - "corev4_followup_campaigns (ADD COLUMNS)"
    - "corev4_followup_configs (ADD COLUMNS)"
    - "corev4_followup_steps (UPDATE DATA)"
  views_alterar:
    - "v_pending_followup_executions (ADD FILTRO)"

5_core_one_flow:
  arquivo: "CoreAdapt One Flow _ v4.json"
  mudanca_nova: "Adicionar lógica para parar campanha quando lead responde"

6_commands_flow:
  arquivo: "CoreAdapt Commands Flow _ v4.json"
  mudanca_nova: "Adicionar detecção de opt-out"

7_novo_workflow:
  nome: "Detect Silent Leads After Response"
  trigger: "Cron a cada 10 minutos"
  funcao: "Reativa campanha quando lead fica silente após responder"
```

---

## ✅ CHECKLIST DE VALIDAÇÃO

Após implementação, testar:

- [ ] **Timing correto:** Campanha cria execuções em 1h, 4h, 1d, 3d, 7d
- [ ] **Horário comercial - Domingo:** Agendamento para domingo move para segunda 8h
- [ ] **Horário comercial - Sábado 14h:** Move para segunda 8h
- [ ] **Horário comercial - Sexta 19h:** Move para segunda 8h
- [ ] **Horário comercial - Terça 6h:** Move para Terça 8h
- [ ] **Reinício contador:** Lead responde → campanha para → lead silente → campanha reinicia
- [ ] **Opt-out manual:** Admin marca opt_out → campanha para
- [ ] **Opt-out automático:** Lead diz "pare" → sistema detecta → marca opt_out → campanha para
- [ ] **Reunião agendada:** Meeting confirmed → campanha para
- [ ] **Todos steps enviados:** Step 5 enviado → campanha completa

---

## 🚀 PRÓXIMOS PASSOS IMEDIATOS

**Você quer que eu:**

**A)** Implementar FASE 1 (Correção de Timing) AGORA?
  - Atualizar Create Followup Campaign JSON
  - Atualizar Sentinel System Message v1.2
  - Script SQL para corrigir banco

**B)** Criar todos os arquivos de implementação (JSON, SQL, funções)?

**C)** Priorizar diferente (qual fase primeiro)?

**D)** Revisar algo antes de implementar?

Me diz e eu prossigo com a implementação!

---

**END OF GAP ANALYSIS**
