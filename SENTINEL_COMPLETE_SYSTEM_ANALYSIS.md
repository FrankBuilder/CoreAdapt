# SENTINEL SYSTEM — ANÁLISE COMPLETA END-TO-END

**Data:** 10 de Novembro de 2025
**Versão:** 1.0 - Análise Definitiva
**Objetivo:** Mapear TODO o sistema de follow-up desde entrada até envio

---

## 📊 TIMING REAL CONFIGURADO NO SISTEMA

### Fonte de Verdade: `Create Followup Campaign _ v4.json` (linha 95)

```javascript
const defaultTiming = [1, 25, 73, 145, 313];  // em HORAS
```

### Tabela de Timing (Configuração Real):

| Step | Horas | Dias Aproximados | Descrição |
|------|-------|------------------|-----------|
| 1 | 1h | ~0.04 dias | Primeira tentativa (1 hora após silêncio) |
| 2 | 25h | ~1.04 dias | Segunda tentativa (~1 dia) |
| 3 | 73h | ~3.04 dias | Terceira tentativa (~3 dias) |
| 4 | 145h | ~6.04 dias | Quarta tentativa (~6 dias) |
| 5 | 313h | ~13.04 dias | Quinta tentativa (~13 dias) |

**NOTA IMPORTANTE:** O Master Document menciona timing diferente (1h, 4h, 1d, 3d, 7d), mas o timing IMPLEMENTADO NO BANCO é 1h, 25h, 73h, 145h, 313h. Este é o timing que deve ser refletido nos prompts.

---

## 🔄 JORNADA COMPLETA: ENTRADA → CAMPANHA → ENVIO

### FASE 1: ENTRADA DO LEAD

**Fluxos que disparam:**
1. **CoreAdapt One Flow** (Frank - qualificação conversacional)
2. **CoreAdapt Genesis Flow** (primeiro contato)

**Quando lead entra:**
- Lead envia mensagem pelo WhatsApp
- Evolution API recebe webhook
- n8n processa via **Main Router Flow**
- Roteado para **Core One (Frank)** para qualificação ANUM
- Dados salvos em:
  - `corev4_contacts` (informações do contato)
  - `corev4_chat_history` (mensagens)
  - `corev4_lead_state` (ANUM score, qualification_stage)

---

### FASE 2: CRIAÇÃO DA CAMPANHA DE FOLLOWUP

**Trigger:** Lead fica SILENTE (não responde)

**Quem cria?** Provavelmente disparo automático quando:
- Lead não responde por X tempo
- Ou: Manualmente via workflow "Create Followup Campaign"

**Fluxo: Create Followup Campaign _ v4.json**

#### Passo a Passo:

1. **Receive Trigger** (linha 134-140)
   - Recebe: `contact_id`, `company_id`

2. **Prepare Campaign Data** (linha 37-44)
   - Extrai: contact_id, company_id

3. **Fetch Company Config** (linha 107-129)
   ```sql
   SELECT
     c.id as config_id,
     c.total_steps,
     jsonb_object_agg(
       'step_' || s.step_number,
       (s.wait_hours + ROUND(s.wait_minutes::numeric / 60, 2))
     ) as timing_pattern
   FROM corev4_followup_configs c
   LEFT JOIN corev4_followup_steps s ON s.config_id = c.id
   WHERE c.company_id = $1 AND c.is_active = true
   ```

   **O que retorna:**
   - `config_id`: ID da configuração ativa
   - `total_steps`: Quantos steps (ex: 5)
   - `timing_pattern`: `{"step_1": 1, "step_2": 25, "step_3": 73, ...}`

4. **Insert Campaign Record** (linha 143-187)
   ```sql
   INSERT INTO corev4_followup_campaigns (
     contact_id, company_id, config_id, total_steps, status, should_continue
   ) VALUES (
     {{ contact_id }}, {{ company_id }}, {{ config_id }}, 5, 'active', true
   )
   ```

5. **Create Followup Steps** (linha 94-104) - CRÍTICO!
   ```javascript
   const defaultTiming = [1, 25, 73, 145, 313];  // HORAS

   for (let step = 1; step <= total_steps; step++) {
     const hours = timing_pattern?.[`step_${step}`] || defaultTiming[step - 1];
     const scheduledTime = new Date(now.getTime() + hours * 60 * 60 * 1000);
     const scheduled_at = scheduledTime.toISOString();

     followups.push({
       contact_id, company_id, step, scheduled_at, hours_from_now: hours
     });
   }
   ```

   **Resultado:**
   - Step 1: NOW + 1h
   - Step 2: NOW + 25h
   - Step 3: NOW + 73h
   - Step 4: NOW + 145h
   - Step 5: NOW + 313h

6. **Loop Over Steps + Insert Execution Records** (linha 189-234)
   ```sql
   INSERT INTO corev4_followup_executions (
     campaign_id, contact_id, company_id, step, total_steps, scheduled_at
   ) VALUES (
     {{ campaign_id }}, {{ contact_id }}, {{ company_id }}, 1, 5, '2025-11-10 13:00:00'
   ), (
     {{ campaign_id }}, {{ contact_id }}, {{ company_id }}, 2, 5, '2025-11-11 14:00:00'
   ), ...
   ```

**Output Final:**
- 1 registro em `corev4_followup_campaigns` (status: active)
- 5 registros em `corev4_followup_executions` (1 por step, com scheduled_at futuro)

---

### FASE 3: EXECUÇÃO DOS FOLLOWUPS (CRON JOB)

**Fluxo: CoreAdapt Sentinel Flow _ v4.json**

**Trigger:** Cron a cada 5 minutos

#### Passo a Passo:

1. **Cron Trigger** (executa a cada 5min)

2. **Fetch Pending Executions** (busca follow-ups prontos para enviar)
   ```sql
   SELECT * FROM v_pending_followup_executions
   WHERE scheduled_at <= NOW()
     AND executed = false
     AND should_send = true
   ORDER BY scheduled_at ASC
   LIMIT 50
   ```

   **View `v_pending_followup_executions` inclui:**
   - Verifica se campanha está ativa (`should_continue = true`)
   - Verifica se contato não deu opt-out
   - Verifica se não tem reunião agendada
   - Filtra apenas execuções não enviadas (`executed = false`)

3. **Loop Over Followups** (para cada execução pendente):

4. **Fetch Chat History** (busca histórico da conversa)
   ```sql
   SELECT role, message, created_at
   FROM corev4_chat_history
   WHERE contact_id = {{ contact_id }}
   ORDER BY created_at DESC
   LIMIT 50
   ```

5. **Fetch Previous Followups** (busca follow-ups já enviados)
   ```sql
   SELECT step, generated_message, sent_at
   FROM corev4_followup_executions
   WHERE campaign_id = {{ campaign_id }}
     AND executed = true
   ORDER BY step ASC
   ```

6. **Prepare Followup Context** (linha 74 do Sentinel Flow)
   ```javascript
   const step_context = {
     1: 'STEP 1 de 5: REENGAJAMENTO SUAVE (~1 hora)',
     2: 'STEP 2 de 5: AGREGAR VALOR (~1 dia)',
     3: 'STEP 3 de 5: URGÊNCIA SUTIL (~3 dias)',
     4: 'STEP 4 de 5: ÚLTIMA CHANCE (~6 dias)',
     5: 'STEP 5 de 5: DESPEDIDA (~13 dias)'
   };

   return {
     contact_name, anum_score, qualification_stage, lead_responded,
     step_context, recent_messages, followup_history, ...
   };
   ```

7. **CoreAdapt Sentinel AI Agent** (linha 322-329)

   **System Message:**
   ```
   You are COREADAPT SENTINEL™...
   STEP 1 (~1h): Soft re-engagement
   STEP 2 (~1d): Add value
   STEP 3 (~3d): Subtle urgency
   STEP 4 (~6d): Last chance
   STEP 5 (~13d): Graceful goodbye
   ```

   **User Message (Prompt Dinâmico):**
   ```
   # CONTEXT
   ## STEP STRATEGY: {{ step_context }}
   ## LEAD INFO: Name, ANUM Score, Stage, Responded before
   ## RECENT CONVERSATION: {{ recent_messages }}
   ## PREVIOUS FOLLOW-UPS SENT: {{ followup_history }}

   # TASK
   Generate ONE follow-up message...
   ```

   **IA Gera:** Mensagem personalizada em português (2-4 linhas)

8. **Send Message via Evolution API**
   ```
   POST https://evolution-api.com/message/sendText
   {
     "number": "{{ phone_number }}",
     "text": "{{ generated_message }}"
   }
   ```

9. **Update: Mark as Sent**
   ```sql
   UPDATE corev4_followup_executions
   SET
     executed = true,
     sent_at = NOW(),
     generated_message = $1,
     decision_reason = 'sent'
   WHERE id = {{ execution_id }}
   ```

10. **Update: Campaign Status**
    ```sql
    UPDATE corev4_followup_campaigns
    SET
      steps_completed = {{ step }},
      last_step_sent_at = NOW(),
      should_continue = CASE
        WHEN {{ step }} >= total_steps THEN false
        ELSE true
      END,
      status = CASE
        WHEN {{ step }} >= total_steps THEN 'completed'
        ELSE 'active'
      END
    WHERE id = {{ campaign_id }}
    ```

---

## 🛑 CONDIÇÕES DE PARADA

**Campanha para de enviar follow-ups quando:**

1. **Lead responde** → `should_continue = false`, `stopped_reason = 'lead_responded'`
2. **Reunião agendada** → `should_continue = false`, `stopped_reason = 'meeting_scheduled'`
3. **Lead deu opt-out** → Execuções não aparecem na view (filtro: `opt_out = false`)
4. **Todos steps completados** → `status = 'completed'`, `should_continue = false`
5. **Lead bloqueou número** → (precisa checar se Evolution API retorna erro)

---

## 📋 SCHEMA BANCO DE DADOS (TABELAS RELEVANTES)

### corev4_followup_configs
```sql
CREATE TABLE corev4_followup_configs (
  id SERIAL PRIMARY KEY,
  company_id INTEGER REFERENCES corev4_companies(id),
  total_steps INTEGER DEFAULT 5,
  qualification_threshold INTEGER DEFAULT 60,
  disqualification_threshold INTEGER DEFAULT 30,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
)
```

### corev4_followup_steps
```sql
CREATE TABLE corev4_followup_steps (
  id SERIAL PRIMARY KEY,
  config_id INTEGER REFERENCES corev4_followup_configs(id),
  step_number INTEGER,
  wait_hours INTEGER,
  wait_minutes INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
)
```

**Dados Típicos:**
```sql
INSERT INTO corev4_followup_steps (config_id, step_number, wait_hours, wait_minutes)
VALUES
  (1, 1, 1, 0),    -- 1 hora
  (1, 2, 25, 0),   -- 25 horas (~1 dia)
  (1, 3, 73, 0),   -- 73 horas (~3 dias)
  (1, 4, 145, 0),  -- 145 horas (~6 dias)
  (1, 5, 313, 0)   -- 313 horas (~13 dias)
```

### corev4_followup_campaigns
```sql
CREATE TABLE corev4_followup_campaigns (
  id SERIAL PRIMARY KEY,
  contact_id INTEGER REFERENCES corev4_contacts(id),
  company_id INTEGER REFERENCES corev4_companies(id),
  config_id INTEGER REFERENCES corev4_followup_configs(id),
  total_steps INTEGER DEFAULT 5,
  steps_completed INTEGER DEFAULT 0,
  status VARCHAR(50) DEFAULT 'active', -- 'active', 'completed', 'stopped'
  should_continue BOOLEAN DEFAULT true,
  stopped_reason VARCHAR(100), -- 'lead_responded', 'meeting_scheduled', 'opt_out'
  last_step_sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
)
```

### corev4_followup_executions
```sql
CREATE TABLE corev4_followup_executions (
  id SERIAL PRIMARY KEY,
  campaign_id INTEGER REFERENCES corev4_followup_campaigns(id),
  contact_id INTEGER REFERENCES corev4_contacts(id),
  company_id INTEGER REFERENCES corev4_companies(id),
  step INTEGER,
  total_steps INTEGER,
  scheduled_at TIMESTAMPTZ,  -- Quando deve ser enviado
  executed BOOLEAN DEFAULT false,
  sent_at TIMESTAMPTZ,
  generated_message TEXT,
  generation_context JSONB,
  decision_reason VARCHAR(100),  -- 'sent', 'skipped', 'lead_responded', etc
  created_at TIMESTAMPTZ DEFAULT NOW()
)
```

### View: v_pending_followup_executions
```sql
CREATE VIEW v_pending_followup_executions AS
SELECT
  fe.id, fe.campaign_id, fe.contact_id, fe.company_id,
  fe.step, fe.total_steps, fe.scheduled_at,
  fc.should_continue, fc.status as campaign_status,
  cnt.opt_out, cnt.phone_number, cnt.name as contact_name,
  ls.anum_score, ls.qualification_stage,
  (EXISTS (SELECT 1 FROM corev4_meetings WHERE contact_id = fe.contact_id AND status = 'confirmed')) as has_meeting
FROM corev4_followup_executions fe
JOIN corev4_followup_campaigns fc ON fe.campaign_id = fc.id
JOIN corev4_contacts cnt ON fe.contact_id = cnt.id
LEFT JOIN corev4_lead_state ls ON fe.contact_id = ls.contact_id
WHERE fe.executed = false
  AND fe.scheduled_at <= NOW()
  AND fc.should_continue = true
  AND fc.status = 'active'
  AND cnt.opt_out = false
  AND NOT EXISTS (SELECT 1 FROM corev4_meetings WHERE contact_id = fe.contact_id AND status = 'confirmed')
ORDER BY fe.scheduled_at ASC
```

---

## ⚙️ CONFIGURAÇÃO ATUAL VS MASTER DOC

| Item | Master Doc | Sistema Implementado | Status |
|------|-----------|----------------------|--------|
| Step 1 timing | 1h | 1h (defaultTiming[0]) | ✅ Alinhado |
| Step 2 timing | 4h | 25h (~1d) | ❌ DESALINHADO |
| Step 3 timing | 1d | 73h (~3d) | ⚠️ Próximo |
| Step 4 timing | 3d | 145h (~6d) | ❌ DESALINHADO |
| Step 5 timing | 7d | 313h (~13d) | ❌ DESALINHADO |
| Total steps | 5 | 5 | ✅ Alinhado |

**CONCLUSÃO:** O sistema está configurado com timing diferente do Master Doc. Timing implementado: **1h, ~1d, ~3d, ~6d, ~13d**.

---

## ✅ AJUSTES NECESSÁRIOS NOS PROMPTS

### System Message (Sentinel v1.0) - Atual:
```
STEP 1 (~1h): Soft re-engagement
STEP 2 (~1d): Add value
STEP 3 (~3d): Subtle urgency
STEP 4 (~6d): Last chance
STEP 5 (~13d): Graceful goodbye
```

**Status:** ✅ **JÁ ESTÁ CORRETO!** Reflete exatamente o timing configurado no banco.

### User Message (Prompt Dinâmico) - Atual:
```javascript
// step_context (Create Followup Campaign não define, mas Sentinel Flow sim)
STEP 1: "~1 hora de inatividade"
STEP 2: "~1 dia"
STEP 3: "~3 dias"
STEP 4: "~6 dias"
STEP 5: "~13 dias"
```

**Status:** ✅ **JÁ ESTÁ CORRETO!**

---

## 🎯 CONCLUSÃO FINAL

### O QUE DESCOBRIMOS:

1. **Timing Real:** 1h, 25h, 73h, 145h, 313h (configurado em `defaultTiming` do Create Followup Campaign)

2. **Timing nos Prompts:** System Message e User Message **JÁ ESTÃO ALINHADOS** com o timing real (~1h, ~1d, ~3d, ~6d, ~13d)

3. **Master Doc vs Realidade:** Master Doc menciona timing diferente (1h, 4h, 1d, 3d, 7d), mas isso **NÃO é o que está implementado no código**

4. **Fonte de Verdade:** `Create Followup Campaign _ v4.json` linha 95 (`defaultTiming = [1, 25, 73, 145, 313]`)

### AJUSTES NECESSÁRIOS:

❌ **NÃO é necessário alterar System Message ou User Message** - eles já refletem o timing correto!

✅ **Ajustes recomendados:**

1. **Adicionar no System Message:**
   - Seção "WHEN SENTINEL ACTIVATES" (triggers de ativação)
   - Seção "WHEN TO STOP" (lógica de parada)
   - ROI calculation específico no STEP 2 (R$ 5k recuperado - R$ 997 = +R$ 4k/mês)
   - Explicitar "DON'T repeat ignored questions" no FORBIDDEN

2. **Atualizar Master Document:**
   - Corrigir timing documentado para refletir realidade (1h, ~1d, ~3d, ~6d, ~13d)
   - Ou: Atualizar banco de dados para refletir Master Doc (se preferir timing mais agressivo)

---

**END OF COMPLETE SYSTEM ANALYSIS**

**Próximo Passo:** Criar Sentinel v1.1 com melhorias (triggers, stop logic, ROI calculation) mantendo timing atual.
