# ✅ SENTINEL COMPLETE SOLUTION

**Data:** 16 de Novembro de 2025
**Status:** ✅ Implementação Completa - Aguardando Deploy
**Afeta:** CoreAdapt Sentinel Flow + Scheduler Flow + Database Trigger

---

## 🎯 PROBLEMA RESOLVIDO

O sistema de followups do Sentinel tinha **3 problemas críticos**:

### ❌ Problema 1: Followups Duplicados
```
Quando múltiplos steps venciam durante espera de horário,
TODOS eram enviados simultaneamente
```
**Solução:** Query com `DISTINCT ON (campaign_id)` ✅

### ❌ Problema 2: Followups Não Cancelavam ao Agendar Reunião
```
Lead agendava reunião (objetivo atingido)
→ Mas followups pendentes continuavam sendo enviados
```
**Solução:** Node no Scheduler Flow cancela followups ✅

### ❌ Problema 3: Followups Não Reagendavam ao Lead Interagir
```
Lead respondia → last_interaction_at atualizava
→ Mas scheduled_at dos followups pendentes não mudava
→ Envios aconteciam no horário ANTIGO (errado)
```
**Solução:** Trigger SQL reagenda automaticamente ✅

---

## ✅ SOLUÇÃO IMPLEMENTADA

### PARTE 1: Cancelar Followups ao Agendar Reunião

**Arquivo:** `CoreAdapt Scheduler Flow _ v4.json`

**Node Adicionado:** `Cancel: Pending Followups`

**Lógica:**
```
Lead agenda reunião via Cal.com
→ Scheduler Flow salva reunião
→ Cancela TODOS os followups pendentes do lead
→ Marca como should_send=false, decision_reason='meeting_scheduled'
```

**Query Executada:**
```sql
UPDATE corev4_followup_executions
SET
  should_send = false,
  decision_reason = 'meeting_scheduled',
  updated_at = NOW()
WHERE contact_id = $contact_id
  AND executed = false
  AND should_send = true;
```

**Posição no Workflow:**
```
Save: Meeting Record
    ↓
Cancel: Pending Followups  ← NOVO
    ↓
Prepare: Confirmation Message
```

---

### PARTE 2: Reagendar Followups ao Lead Interagir

**Arquivo:** `queries/TRIGGER_REAGENDAR_FOLLOWUPS.sql`

**Trigger SQL:** `trigger_reagendar_followups`

**Lógica:**
```
Lead interage (envia mensagem)
→ One Flow atualiza corev4_contacts.last_interaction_at
→ TRIGGER dispara automaticamente
→ Recalcula scheduled_at de TODOS followups pendentes
→ Usa wait_hours e wait_minutes de corev4_followup_steps
```

**Função SQL:**
```sql
CREATE OR REPLACE FUNCTION reagendar_followups_on_interaction()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.last_interaction_at IS DISTINCT FROM OLD.last_interaction_at THEN

    UPDATE corev4_followup_executions e
    SET
      scheduled_at = NEW.last_interaction_at +
                     (fs.wait_hours || ' hours')::INTERVAL +
                     (fs.wait_minutes || ' minutes')::INTERVAL,
      updated_at = NOW()
    FROM corev4_followup_campaigns fc
    INNER JOIN corev4_followup_steps fs
      ON fs.config_id = fc.config_id
      AND fs.step_number = e.step
    WHERE e.contact_id = NEW.id
      AND e.campaign_id = fc.id
      AND e.executed = false
      AND e.should_send = true;

    RAISE NOTICE 'Followups reagendados para contact_id %', NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

**Exemplo de Reagendamento:**
```
10h00 - Lead para de responder (last_interaction_at = 10h00)
11h00 - Step 1 agendado (10h + 1h)
15h00 - Step 2 agendado (10h + 4h)
11h30 - Lead RESPONDE (last_interaction_at = 11h30)
        ↓ TRIGGER DISPARA
        ✓ Step 1 reagendado: 11h30 + 1h = 12h30
        ✓ Step 2 reagendado: 11h30 + 4h = 15h30
```

---

### PARTE 3: Evitar Duplicatas (Já Implementado)

**Arquivo:** `CoreAdapt Sentinel Flow _ v4.json`

**Query Modificada:** `Fetch: Pending Followups`

**Lógica:**
```sql
SELECT DISTINCT ON (e.campaign_id)  ← Apenas 1 step por campanha
  ...
ORDER BY e.campaign_id, e.step ASC  ← Sempre o menor step
```

**Resultado:**
- Apenas o primeiro step não executado de cada campanha é processado
- Steps subsequentes só são enviados após anterior ser marcado como executed=true

---

## 📊 COMPORTAMENTO COMPLETO DO SISTEMA

### Cenário 1: Lead Silencioso (Flow Normal)

```
10h00 - Lead para de responder
11h00 - Step 1 enviado (1h depois)
        → Lead não responde
15h00 - Step 2 enviado (4h depois do Step 1)
        → Lead não responde
10h00 (dia seguinte) - Step 3 enviado (24h depois)
```

### Cenário 2: Lead Responde Durante Followup

```
10h00 - Lead para de responder
11h00 - Step 1 enviado
11h30 - Lead RESPONDE
        ↓ TRIGGER reagenda followups pendentes
        ✓ Step 2 agendado para 15h30 (11h30 + 4h)
        ✓ Step 3 agendado para 11h30 (dia seguinte)
15h30 - Step 2 enviado
        → Lead não responde
11h30 (dia seguinte) - Step 3 enviado
```

### Cenário 3: Lead Agenda Reunião

```
10h00 - Lead para de responder
11h00 - Step 1 enviado
12h00 - Lead AGENDA REUNIÃO
        ↓ SCHEDULER FLOW cancela followups
        ✓ Step 2: should_send = false, decision_reason = 'meeting_scheduled'
        ✓ Step 3: should_send = false, decision_reason = 'meeting_scheduled'
        ✓ Step 4: should_send = false, decision_reason = 'meeting_scheduled'
        ✓ Step 5: should_send = false, decision_reason = 'meeting_scheduled'

RESULTADO: Nenhum followup adicional é enviado
```

### Cenário 4: Múltiplos Steps Vencidos (Duplicatas Evitadas)

```
22h00 - Lead para de responder (fora do horário)
23h00 - Step 1 deveria ser enviado → Reagendado para 9h
03h00 - Step 2 deveria ser enviado → Reagendado para 9h
09h00 - Cron do Sentinel executa
        ↓ DISTINCT ON (campaign_id)
        ✓ Apenas Step 1 é selecionado (menor step)
        ✓ Step 1 enviado
        ✓ Step 1 marcado executed=true
09h05 - Próximo cron
        ✓ Agora Step 2 é o menor pendente
        ✓ Step 2 enviado
```

---

## 📂 ARQUIVOS CRIADOS/MODIFICADOS

### ✅ Workflows Modificados:
- `CoreAdapt Sentinel Flow _ v4.json` (query DISTINCT ON)
- `CoreAdapt Scheduler Flow _ v4.json` (node Cancel Followups)

### 📋 Backups:
- `CoreAdapt Sentinel Flow _ v4_BEFORE_DISTINCT_FIX.json`
- `CoreAdapt Scheduler Flow _ v4_BEFORE_FOLLOWUP_CANCEL.json`

### 📊 SQL/Queries:
- `queries/TRIGGER_REAGENDAR_FOLLOWUPS.sql` (trigger para Supabase)
- `queries/INVESTIGATE_GOAL_EXECUTE_SEPARATELY.sql` (investigação)
- `queries/DIAGNOSTICO_FOLLOWUP_DUPLICADOS.sql` (diagnóstico)

### 📖 Documentação:
- `docs/SENTINEL_COMPLETE_SOLUTION.md` (este documento)
- `docs/SENTINEL_FOLLOWUP_DUPLICADOS_FIX.md` (análise técnica)
- `docs/SENTINEL_EDGE_CASES_ANALYSIS.md` (edge cases)

### 🔧 Scripts:
- `scripts/fix_sentinel_complete_solution.py` (implementação)
- `scripts/fix_sentinel_followup_duplicados.py` (fix duplicatas)

---

## 🚀 DEPLOY - CHECKLIST

### Passo 1: Importar Workflows Atualizados

- [ ] **Scheduler Flow:** Importar `CoreAdapt Scheduler Flow _ v4.json`
  - Verificar node "Cancel: Pending Followups" existe
  - Verificar conexão: Save Meeting → Cancel Followups
  - Ativar workflow

- [ ] **Sentinel Flow:** Importar `CoreAdapt Sentinel Flow _ v4.json`
  - Verificar query tem `DISTINCT ON (e.campaign_id)`
  - Verificar `ORDER BY e.campaign_id, e.step ASC`
  - Ativar workflow

### Passo 2: Executar Trigger no Supabase

- [ ] Abrir Supabase SQL Editor
- [ ] Executar conteúdo de `queries/TRIGGER_REAGENDAR_FOLLOWUPS.sql`
- [ ] Verificar que trigger foi criado:
```sql
SELECT trigger_name, event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'trigger_reagendar_followups';
```
- [ ] Resultado esperado: 1 linha retornada

### Passo 3: Testes de Validação

#### Teste 1: Cancelamento ao Agendar Reunião

```sql
-- 1. Criar followup campaign de teste
INSERT INTO corev4_followup_campaigns (contact_id, company_id, config_id, status)
VALUES ($contact_id, 1, 1, 'active')
RETURNING id;

-- 2. Criar executions pendentes
INSERT INTO corev4_followup_executions
  (campaign_id, contact_id, company_id, step, total_steps, scheduled_at, executed, should_send)
VALUES
  ($campaign_id, $contact_id, 1, 1, 5, NOW() + INTERVAL '1 hour', false, true),
  ($campaign_id, $contact_id, 1, 2, 5, NOW() + INTERVAL '4 hours', false, true);

-- 3. Agendar reunião via Cal.com (Scheduler Flow vai processar)

-- 4. Verificar que followups foram cancelados
SELECT step, should_send, decision_reason
FROM corev4_followup_executions
WHERE campaign_id = $campaign_id;

-- Resultado esperado:
-- step | should_send | decision_reason
-- -----+-------------+------------------
--   1  | false       | meeting_scheduled
--   2  | false       | meeting_scheduled
```

#### Teste 2: Reagendamento ao Interagir

```sql
-- 1. Criar followup pendente com scheduled_at fixo
INSERT INTO corev4_followup_executions
  (campaign_id, contact_id, company_id, step, total_steps, scheduled_at, executed, should_send)
VALUES
  ($campaign_id, $contact_id, 1, 2, 5, '2025-11-16 15:00:00', false, true);

-- 2. Atualizar last_interaction_at (simular lead respondendo)
UPDATE corev4_contacts
SET last_interaction_at = '2025-11-16 11:30:00'
WHERE id = $contact_id;

-- 3. Verificar que scheduled_at foi recalculado
SELECT step, scheduled_at
FROM corev4_followup_executions
WHERE campaign_id = $campaign_id AND step = 2;

-- Resultado esperado:
-- step | scheduled_at
-- -----+-----------------
--   2  | 2025-11-16 15:30:00  (11:30 + 4h)
```

#### Teste 3: Evitar Duplicatas

```sql
-- 1. Criar múltiplos steps vencidos
INSERT INTO corev4_followup_executions
  (campaign_id, contact_id, company_id, step, total_steps, scheduled_at, executed, should_send)
VALUES
  ($campaign_id, $contact_id, 1, 1, 5, NOW() - INTERVAL '2 hours', false, true),
  ($campaign_id, $contact_id, 1, 2, 5, NOW() - INTERVAL '1 hour', false, true);

-- 2. Executar query do Sentinel
SELECT DISTINCT ON (e.campaign_id)
  e.step, e.scheduled_at
FROM corev4_followup_executions e
WHERE e.campaign_id = $campaign_id
  AND e.executed = false
  AND e.should_send = true
ORDER BY e.campaign_id, e.step ASC;

-- Resultado esperado:
-- step | scheduled_at
-- -----+-----------------
--   1  | <timestamp>  (apenas step 1, não step 2)
```

---

## 🎯 REGRAS DE NEGÓCIO IMPLEMENTADAS

### ✅ REGRA 1: Objetivo do Tenant
**Objetivo CoreConnect (Frank):** Agendar reunião (Mesa de Clareza)

**Implementação:**
- Quando reunião é agendada → Todos followups pendentes são cancelados
- Campo `decision_reason = 'meeting_scheduled'`

### ✅ REGRA 2: Reagendamento ao Interagir
**Se lead responde:** Followups pendentes são reagendados

**Implementação:**
- Trigger monitora `last_interaction_at`
- Recalcula `scheduled_at` usando timings de `corev4_followup_steps`
- Apenas afeta followups com `executed=false` e `should_send=true`

### ✅ REGRA 3: Timings Configuráveis
**Timings atuais (config_id=1):**
- Step 1: 1 hora
- Step 2: 4 horas
- Step 3: 24 horas (1 dia)
- Step 4: 72 horas (3 dias)
- Step 5: 168 horas (7 dias)

**Implementação:**
- Timings lidos de `corev4_followup_steps.wait_hours` e `wait_minutes`
- Fácil ajustar sem código (apenas UPDATE na tabela)

### ✅ REGRA 4: Apenas 1 Step Por Vez
**Evitar spam:** Enviar apenas 1 step por campanha em cada cron execution

**Implementação:**
- Query usa `DISTINCT ON (campaign_id)`
- `ORDER BY step ASC` garante menor step primeiro
- Steps subsequentes só processam após anterior ser executado

---

## 🔍 MONITORAMENTO

### Queries Úteis para Monitorar

**Ver followups cancelados por reunião:**
```sql
SELECT
  contact_id,
  step,
  decision_reason,
  updated_at
FROM corev4_followup_executions
WHERE decision_reason = 'meeting_scheduled'
ORDER BY updated_at DESC
LIMIT 20;
```

**Ver reagendamentos recentes:**
```sql
SELECT
  contact_id,
  step,
  scheduled_at,
  updated_at
FROM corev4_followup_executions
WHERE executed = false
  AND updated_at > NOW() - INTERVAL '1 hour'
ORDER BY updated_at DESC;
```

**Ver campanhas com múltiplos steps pendentes (possível duplicata):**
```sql
SELECT
  campaign_id,
  COUNT(*) as steps_pendentes
FROM corev4_followup_executions
WHERE executed = false
  AND should_send = true
  AND scheduled_at <= NOW()
GROUP BY campaign_id
HAVING COUNT(*) > 1;
```

---

## ✅ CONCLUSÃO

**Status:** Sistema completo e pronto para deploy

**Problemas Resolvidos:**
- ✅ Duplicatas de followups
- ✅ Followups continuando após reunião agendada
- ✅ Followups não reagendando ao lead interagir

**Próximos Passos:**
1. Importar workflows atualizados
2. Executar trigger SQL no Supabase
3. Testar com dados reais
4. Monitorar nas primeiras 24h

**Comportamento Esperado:**
- Lead silencioso: Recebe followups progressivos (1h, 4h, 1d, 3d, 7d)
- Lead responde: Followups reagendam automaticamente
- Lead agenda reunião: Followups param completamente
- Múltiplos steps vencidos: Apenas 1 por vez é enviado

---

**FIM DA DOCUMENTAÇÃO**
