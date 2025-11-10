# SENTINEL — DEEP DIVE & PLANO DE IMPLEMENTAÇÃO DEFINITIVO

**Data:** 10 de Novembro de 2025
**Status:** Análise Profunda Completa
**Objetivo:** Implementar timing correto + horário comercial + lógica de resposta

---

## 📊 ESTADO ATUAL DO SISTEMA (DESCOBERTAS)

### 1. TIMING IMPLEMENTADO (Create Followup Campaign _ v4.json:95)

```javascript
const defaultTiming = [1, 25, 73, 145, 313];  // em HORAS
```

**Tradução:**
- Step 1: 1h
- Step 2: 25h (~1.04 dias)
- Step 3: 73h (~3.04 dias)
- Step 4: 145h (~6.04 dias)
- Step 5: 313h (~13.04 dias)

**Status:** ❌ INCORRETO

---

### 2. LÓGICA DE PARADA QUANDO REUNIÃO AGENDADA

**Encontrado em:** DEEP_DIVE_STUDY_COREADAPT_V4.md:1100-1107

```sql
UPDATE corev4_followup_campaigns
SET should_continue = false,
    stopped_reason = 'meeting_scheduled'
WHERE contact_id = {{ contact_id }}
  AND status = 'active';
```

**Status:** ✅ EXISTE e funciona

---

### 3. LÓGICA DE PARADA QUANDO LEAD RESPONDE

**Busquei em:**
- CoreAdapt One Flow _ v4.json ❌ Não encontrado
- CoreAdapt Main Router Flow _ v4.json ❌ Não verificado ainda
- Sentinel Flow _ v4.json ❌ Não tem (apenas executa)
- DEEP_DIVE_STUDY ⚠️ Menciona "Verifica se lead respondeu" mas não explica COMO

**Conclusão:** **PROVAVELMENTE NÃO EXISTE** ou está em lugar que ainda não identifiquei.

---

### 4. LÓGICA DE REINÍCIO DE CONTADOR

**Status:** ❌ **NÃO EXISTE**

Não encontrei:
- Colunas `last_lead_response_at` ou `current_step_restart_count` no schema
- Workflow "Detect Silent After Response"
- Lógica de reativação de campanha

---

### 5. HORÁRIO COMERCIAL

**Status:** ❌ **NÃO EXISTE**

- Não há filtro por dia da semana ou hora
- Sistema agenda e envia 24/7
- Não há função `adjustToBusinessHours()`

---

### 6. OPT-OUT AUTOMÁTICO

**Status:** ❌ **NÃO EXISTE**

- Opt-out é apenas manual (update direto no banco)
- Não há detecção automática de palavras-chave
- Commands Flow não detecta "pare", "chega", etc.

---

## 🎯 REQUISITOS CORRETOS (CONFIRMADOS)

### TIMING CORRETO:
```
Step 1: 1 hora
Step 2: 4 horas
Step 3: 1 dia (24 horas)
Step 4: 3 dias (72 horas)
Step 5: 7 dias (168 horas)
```

### HORÁRIO COMERCIAL:
```yaml
segunda_sexta: 8:00 - 18:00
sabado: 8:00 - 12:00
domingo: NÃO ENVIA
```

### CONDIÇÕES DE PARADA:
```
1. Reunião agendada (✅ JÁ EXISTE)
2. Lead diz opt-out abertamente (❌ NÃO EXISTE - precisa Commands integration)
3. Todos steps enviados (✅ JÁ EXISTE via steps_completed = total_steps)
```

### REINÍCIO DE CONTADOR:
```
Lead responde → Campanha para
Lead fica silente → Contador reinicia do MESMO step
```

---

## 🔄 FLUXO COMPLETO ATUAL (MAPEADO)

### CRIAÇÃO DE CAMPANHA

**Trigger:** Desconhecido (preciso descobrir QUANDO é criada)

**Fluxo:** Create Followup Campaign _ v4.json

**Processo:**
1. Receive trigger (contact_id, company_id)
2. Fetch company config + timing from `corev4_followup_configs` + `corev4_followup_steps`
3. Create campaign record in `corev4_followup_campaigns`
4. Calculate 5 scheduled_at timestamps using defaultTiming
5. Insert 5 execution records in `corev4_followup_executions`

**Output:**
- 1 campanha ativa
- 5 execuções agendadas com scheduled_at futuro

---

### EXECUÇÃO DE FOLLOWUP

**Trigger:** Cron a cada 5 minutos

**Fluxo:** CoreAdapt Sentinel Flow _ v4.json

**Query:**
```sql
SELECT * FROM v_pending_followup_executions
WHERE scheduled_at <= NOW()
  AND executed = false
  AND should_send = true
ORDER BY scheduled_at ASC
LIMIT 50
```

**View `v_pending_followup_executions` (incompleta no doc):**
```sql
SELECT fe.*, ...
FROM corev4_followup_executions fe
JOIN corev4_followup_campaigns c ON fe.campaign_id = c.id
JOIN corev4_contacts cnt ON fe.contact_id = cnt.id
WHERE fe.executed = false
  AND fe.should_send = true
  AND fe.scheduled_at <= NOW()
  AND cnt.opt_out = false
  AND c.should_continue = true
  AND c.status = 'active'
```

**Processo:**
1. Fetch pending executions
2. For each: Fetch chat history, previous followups, ANUM
3. Prepare context for AI
4. Generate message (System Message + User Prompt)
5. Send via Evolution API
6. Mark executed = true
7. Update campaign steps_completed

---

### PARADA QUANDO REUNIÃO AGENDADA

**Trigger:** Cal.com webhook → CoreAdapt Scheduler Flow

**Processo:**
1. Match contact by phone/email
2. Insert into `corev4_scheduled_meetings`
3. **UPDATE `corev4_followup_campaigns`:**
   ```sql
   UPDATE corev4_followup_campaigns
   SET should_continue = false,
       stopped_reason = 'meeting_scheduled'
   WHERE contact_id = {{ contact_id }} AND status = 'active'
   ```

---

### ❓ PARADA QUANDO LEAD RESPONDE (NÃO ENCONTRADO)

**Esperado mas NÃO existe:**
```sql
-- Deveria existir em Core One Flow ou Main Router
UPDATE corev4_followup_campaigns
SET should_continue = false,
    stopped_reason = 'lead_responded',
    last_lead_response_at = NOW()  -- coluna não existe ainda
WHERE contact_id = {{ contact_id }} AND status = 'active'
```

---

## 📋 TABELAS - SCHEMA ATUAL

### corev4_followup_campaigns
```sql
COLUNAS EXISTENTES:
- id (bigint, PK)
- contact_id (bigint, FK)
- company_id (integer)
- config_id (integer, FK)
- status (varchar) -- 'active', 'completed', 'stopped'
- pause_reason (text)  -- ??? não documentado uso
- steps_completed (integer, default: 0)
- total_steps (integer)
- last_step_sent_at (timestamptz)
- should_continue (boolean, default: true)
- stopped_reason (text)
- created_at, updated_at (timestamptz)

COLUNAS FALTANDO:
- last_lead_response_at (timestamptz)  -- ❌ NÃO EXISTE
- current_step_restart_count (integer)  -- ❌ NÃO EXISTE
```

### corev4_followup_configs
```sql
COLUNAS EXISTENTES:
- id (integer, PK)
- company_id (integer)
- total_steps (integer, default: 6)  -- será 5
- qualification_threshold (numeric, default: 70)
- disqualification_threshold (numeric, default: 30)
- is_active (boolean, default: true)
- created_at, updated_at (timestamptz)

COLUNAS FALTANDO:
- business_hours_start (time)  -- ❌ NÃO EXISTE
- business_hours_end_weekday (time)  -- ❌ NÃO EXISTE
- business_hours_end_saturday (time)  -- ❌ NÃO EXISTE
- allow_sunday (boolean)  -- ❌ NÃO EXISTE
```

### corev4_followup_steps
```sql
COLUNAS EXISTENTES:
- id (integer, PK)
- config_id (integer, FK)
- step_number (integer)
- wait_hours (integer)
- wait_minutes (integer, default: 0)
- created_at, updated_at (timestamptz)

DADOS ATUAIS (provavelmente):
Step 1: wait_hours = 1
Step 2: wait_hours = 25  ❌ ERRADO
Step 3: wait_hours = 73  ❌ ERRADO
Step 4: wait_hours = 145  ❌ ERRADO
Step 5: wait_hours = 313  ❌ ERRADO
```

---

## 🚀 PLANO DE IMPLEMENTAÇÃO (4 FASES REVISADO)

### FASE 1: CORREÇÃO DE TIMING ⚠️ CRÍTICA
**Tempo:** 1 hora
**Prioridade:** 🔴 URGENTE

**Arquivos a alterar:**
1. `Create Followup Campaign _ v4.json:95`
   ```javascript
   const defaultTiming = [1, 4, 24, 72, 168];  // CORRETO
   ```

2. Banco de dados:
   ```sql
   UPDATE corev4_followup_steps
   SET wait_hours = CASE step_number
     WHEN 1 THEN 1
     WHEN 2 THEN 4
     WHEN 3 THEN 24
     WHEN 4 THEN 72
     WHEN 5 THEN 168
   END,
   wait_minutes = 0
   WHERE config_id IN (
     SELECT id FROM corev4_followup_configs WHERE is_active = true
   );
   ```

3. `CoreAdapt Sentinel Flow _ v4.json:328` (System Message)
   ```
   STEP 1 (~1h)
   STEP 2 (~4h)   ← CORRIGIDO
   STEP 3 (~1d)   ← CORRIGIDO
   STEP 4 (~3d)   ← CORRIGIDO
   STEP 5 (~7d)   ← CORRIGIDO
   ```

4. `CoreAdapt Sentinel Flow _ v4.json:74` (step_context no código JS)
   ```javascript
   if (step === 2) {
     step_context = 'STEP 2 de 5: AGREGAR VALOR (~4 horas)';  // CORRIGIDO
   }
   // ... etc
   ```

**Teste:**
- Criar nova campanha
- Verificar scheduled_at das 5 execuções
- Confirmar: 1h, 4h, 1d, 3d, 7d

---

### FASE 2: HORÁRIO COMERCIAL ⚠️ ALTA
**Tempo:** 4 horas
**Prioridade:** 🟠 ALTA

**Arquivos a criar/alterar:**

1. **Função `adjustToBusinessHours()` em Create Followup Campaign**

Adicionar após linha 95:
```javascript
function adjustToBusinessHours(scheduledTime) {
  const date = new Date(scheduledTime);
  const dayOfWeek = date.getDay();  // 0=Dom, 6=Sáb
  const hour = date.getHours();

  // Domingo → Segunda 8h
  if (dayOfWeek === 0) {
    date.setDate(date.getDate() + 1);
    date.setHours(8, 0, 0, 0);
    return date;
  }

  // Sábado
  if (dayOfWeek === 6) {
    if (hour >= 12) {
      date.setDate(date.getDate() + 2);  // Segunda
      date.setHours(8, 0, 0, 0);
    } else if (hour < 8) {
      date.setHours(8, 0, 0, 0);
    }
    return date;
  }

  // Seg-Sex
  if (hour < 8) {
    date.setHours(8, 0, 0, 0);
  } else if (hour >= 18) {
    if (dayOfWeek === 5) {  // Sexta
      date.setDate(date.getDate() + 3);  // Segunda
    } else {
      date.setDate(date.getDate() + 1);
    }
    date.setHours(8, 0, 0, 0);
  }

  return date;
}

// Usar na linha 101:
const scheduledTime = new Date(now.getTime() + hours * 60 * 60 * 1000);
const scheduled_at = adjustToBusinessHours(scheduledTime).toISOString();
```

2. **Adicionar filtro na view v_pending_followup_executions**

```sql
-- Adicionar no WHERE:
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

**Teste:**
- Criar campanha sexta 19h → Step 1 deve ser segunda 8h
- Criar campanha sábado 14h → Step 1 deve ser segunda 8h
- Criar campanha domingo → Step 1 deve ser segunda 8h

---

### FASE 3: PARADA/REINÍCIO QUANDO LEAD RESPONDE ⚠️ MÉDIA
**Tempo:** 6 horas
**Prioridade:** 🟡 MÉDIA

**Arquivos a criar/alterar:**

1. **Migrations SQL:**
```sql
-- 001_add_response_tracking.sql
ALTER TABLE corev4_followup_campaigns
ADD COLUMN IF NOT EXISTS last_lead_response_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS current_step_restart_count INTEGER DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_campaigns_response_tracking
ON corev4_followup_campaigns(contact_id, last_lead_response_at)
WHERE stopped_reason = 'lead_responded';
```

2. **Core One Flow ou Main Router Flow** (preciso identificar onde)

Adicionar após salvar mensagem do lead em chat_history:

```javascript
// Parar campanha ativa quando lead responde
await db.query(`
  UPDATE corev4_followup_campaigns
  SET
    should_continue = false,
    stopped_reason = 'lead_responded',
    last_lead_response_at = NOW()
  WHERE contact_id = $1
    AND status = 'active'
    AND should_continue = true
`, [contact_id]);

// Cancelar execuções futuras
await db.query(`
  UPDATE corev4_followup_executions
  SET
    executed = true,
    decision_reason = 'cancelled_lead_responded'
  WHERE campaign_id IN (
    SELECT id FROM corev4_followup_campaigns
    WHERE contact_id = $1 AND stopped_reason = 'lead_responded'
  )
  AND executed = false
`, [contact_id]);
```

3. **Novo Workflow: Detect Silent After Response**

Trigger: Cron a cada 10 minutos

Query:
```sql
-- Detecta leads que responderam mas ficaram silentes novamente
SELECT
  c.id as contact_id,
  c.company_id,
  fc.id as campaign_id,
  fc.steps_completed,
  fc.total_steps,
  EXTRACT(EPOCH FROM (NOW() - ch.created_at)) / 3600 as hours_silent
FROM corev4_contacts c
JOIN corev4_followup_campaigns fc ON c.id = fc.contact_id
JOIN LATERAL (
  SELECT created_at, role
  FROM corev4_chat_history
  WHERE contact_id = c.id
  ORDER BY created_at DESC
  LIMIT 1
) ch ON true
WHERE fc.stopped_reason = 'lead_responded'
  AND fc.steps_completed < fc.total_steps
  AND ch.role = 'human'  -- Última mensagem foi do lead
  AND EXTRACT(EPOCH FROM (NOW() - ch.created_at)) > 3600  -- Silente por 1h+
  AND fc.status != 'completed'
  AND c.opt_out = false;
```

Para cada lead encontrado:
```javascript
// Determinar próximo step
const nextStep = steps_completed + 1;
const timingHours = [1, 4, 24, 72, 168];
const hoursToWait = timingHours[nextStep - 1];

// Calcular scheduled_at com business hours
const scheduledTime = new Date(Date.now() + hoursToWait * 3600000);
const scheduled_at = adjustToBusinessHours(scheduledTime).toISOString();

// Reativar campanha
await db.query(`
  UPDATE corev4_followup_campaigns
  SET
    should_continue = true,
    stopped_reason = NULL,
    status = 'active',
    current_step_restart_count = current_step_restart_count + 1
  WHERE id = $1
`, [campaign_id]);

// Criar nova execução
await db.query(`
  INSERT INTO corev4_followup_executions (
    campaign_id, contact_id, company_id, step, total_steps, scheduled_at
  ) VALUES ($1, $2, $3, $4, $5, $6)
`, [campaign_id, contact_id, company_id, nextStep, total_steps, scheduled_at]);
```

**Teste:**
- Lead responde → Campanha para
- Lead fica silente 1h → Sistema reativa + agenda próximo step
- Verificar scheduled_at respeit horário comercial

---

### FASE 4: OPT-OUT AUTOMÁTICO ⚠️ MÉDIA
**Tempo:** 3 horas
**Prioridade:** 🟡 MÉDIA

**Arquivo:** CoreAdapt Commands Flow _ v4.json

Adicionar node de detecção após classificar intenção:

```javascript
// Lista de keywords opt-out
const optOutKeywords = [
  'pare', 'para', 'chega', 'para de mandar', 'não quero mais',
  'cancelar', 'desistir', 'sair', 'remover', 'excluir',
  'unsubscribe', 'opt out', 'stop', 'basta', 'cansei'
];

const message = $json.message.toLowerCase().trim();
const isOptOut = optOutKeywords.some(kw => message.includes(kw));

if (isOptOut) {
  // 1. Marcar contato
  await db.query(`
    UPDATE corev4_contacts
    SET opt_out = true, opt_out_at = NOW()
    WHERE id = $1
  `, [contact_id]);

  // 2. Parar campanha
  await db.query(`
    UPDATE corev4_followup_campaigns
    SET should_continue = false, stopped_reason = 'opt_out', status = 'stopped'
    WHERE contact_id = $1 AND status = 'active'
  `, [contact_id]);

  // 3. Cancelar execuções
  await db.query(`
    UPDATE corev4_followup_executions
    SET executed = true, decision_reason = 'cancelled_opt_out'
    WHERE contact_id = $1 AND executed = false
  `, [contact_id]);

  // 4. Responder confirmação
  return "Entendido! Você não receberá mais mensagens automáticas. Se mudar de ideia, é só me chamar. 👍";
}
```

**Teste:**
- Lead envia "pare" → opt_out = true, campanha para
- Lead envia "não quero mais" → mesmo comportamento

---

## ✅ CHECKLIST DE VALIDAÇÃO FINAL

Após implementação completa:

**Timing:**
- [ ] defaultTiming = [1, 4, 24, 72, 168] em Create Followup Campaign
- [ ] corev4_followup_steps atualizado com timing correto
- [ ] System Message atualizado (~4h, ~1d, ~3d, ~7d)
- [ ] step_context atualizado no código JS

**Horário Comercial:**
- [ ] adjustToBusinessHours() implementado
- [ ] View filtrada por dia/hora
- [ ] Teste: Sexta 19h → Segunda 8h
- [ ] Teste: Sábado 14h → Segunda 8h
- [ ] Teste: Domingo → Segunda 8h

**Parada/Reinício:**
- [ ] Colunas adicionadas no banco
- [ ] Core One para campanha quando lead responde
- [ ] Workflow Detect Silent criado
- [ ] Teste: Responde → Para → Silente → Reinicia

**Opt-out:**
- [ ] Commands detecta keywords
- [ ] Marca opt_out + para campanha
- [ ] Teste: "pare" funciona

---

## 🔍 PRÓXIMAS AÇÕES IMEDIATAS

**Você quer que eu:**

**A)** Começar **FASE 1 (Timing)** agora?
  - Atualizar Create Followup Campaign JSON
  - Gerar SQL para atualizar banco
  - Atualizar Sentinel System Message
  - Atualizar step_context no Sentinel Flow

**B)** Primeiro **IDENTIFICAR onde Core One salva mensagem do lead** para implementar FASE 3?

**C)** Implementar **todas as 4 fases** de uma vez com todos arquivos?

**D)** Outra prioridade?

Me diz e eu prossigo! 🚀
