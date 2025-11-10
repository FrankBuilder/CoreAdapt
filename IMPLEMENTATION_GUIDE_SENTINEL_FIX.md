# SENTINEL SYSTEM — IMPLEMENTATION GUIDE

**Data:** 10 de Novembro de 2025
**Versão:** 1.0
**Status:** Ready to Deploy

---

## RESUMO EXECUTIVO

Este guia documenta TODAS as mudanças implementadas no sistema Sentinel para corrigir timing, adicionar business hours e alinhar com survivor mode positioning.

**Problemas Corrigidos:**
1. ✅ Timing incorreto (25h, 73h, 145h, 313h → 4h, 24h, 72h, 168h)
2. ✅ Falta de business hours (agora: Mon-Fri 8-18h, Sat 8-12h)
3. ✅ Posicionamento desatualizado (agora: survivor mode, CoreAdapt R$ 997 only)

---

## ARQUIVOS MODIFICADOS

### 1. **Database Migrations** (SQL)

| Arquivo | Propósito | Status |
|---------|-----------|--------|
| `migrations/fix_followup_timing.sql` | Corrige timing na tabela corev4_followup_steps | ⚠️ **EXECUTAR NO BANCO** |
| `migrations/add_business_hours_function.sql` | Cria função adjust_to_business_hours() | ⚠️ **EXECUTAR NO BANCO** |
| `migrations/integrate_business_hours_in_recalculate.sql` | Modifica recalculate_followup_schedule() | ⚠️ **EXECUTAR NO BANCO** |
| `migrations/add_business_hours_trigger.sql` | Cria triggers automáticos | ⚠️ **EXECUTAR NO BANCO** |

**ORDEM DE EXECUÇÃO:**
```bash
# 1. Corrigir timing
psql -h <host> -U <user> -d <database> -f migrations/fix_followup_timing.sql

# 2. Criar função de business hours
psql -h <host> -U <user> -d <database> -f migrations/add_business_hours_function.sql

# 3. Integrar na função recalculate
psql -h <host> -U <user> -d <database> -f migrations/integrate_business_hours_in_recalculate.sql

# 4. Adicionar triggers
psql -h <host> -U <user> -d <database> -f migrations/add_business_hours_trigger.sql
```

### 2. **n8n Workflows** (JSON)

| Arquivo | Mudanças | Status |
|---------|----------|--------|
| `Create Followup Campaign _ v4.json` | defaultTiming: [1, 4, 24, 72, 168] | ✅ **MODIFICADO** |
| `CoreAdapt Sentinel Flow _ v4.json` | step_context timing + System Message | ✅ **MODIFICADO** |

**DEPLOY:**
- Importar workflows atualizados no n8n
- Ativar workflows
- Verificar que não há erros de syntax

### 3. **Documentação** (Markdown)

| Arquivo | Propósito | Status |
|---------|-----------|--------|
| `SENTINEL_SYSTEM_MESSAGE_v1.2.md` | System message completo atualizado | ✅ **CRIADO** |
| `SENTINEL_COMPLETE_DISCOVERY_FINAL.md` | Deep dive completo do sistema | ✅ **CRIADO** |
| `IMPLEMENTATION_GUIDE_SENTINEL_FIX.md` | Este guia | ✅ **CRIADO** |

---

## MUDANÇAS DETALHADAS

### FASE 1: TIMING

#### Antes (INCORRETO):
```javascript
const defaultTiming = [1, 25, 73, 145, 313]; // 1h, ~1d, ~3d, ~6d, ~13d
```

#### Depois (CORRETO):
```javascript
const defaultTiming = [1, 4, 24, 72, 168]; // 1h, 4h, 1d, 3d, 7d
```

**Impacto:**
- Campanhas novas: Usarão timing correto automaticamente
- Campanhas ativas: Continuarão com timing antigo ATÉ lead responder (aí recalcula)
- Banco de dados: Atualizado via SQL UPDATE

---

### FASE 2: BUSINESS HOURS

#### Função PostgreSQL:
```sql
adjust_to_business_hours(timestamp, timezone DEFAULT 'America/Fortaleza')
```

**Regras:**
- Segunda-Sexta: 08:00-18:00
- Sábado: 08:00-12:00
- Domingo: NÃO ENVIA (agenda para Segunda 08:00)

**Exemplos:**
| Input | Output | Motivo |
|-------|--------|--------|
| Sexta 19:00 | Segunda 08:00 | Fora do horário (3 dias depois) |
| Sábado 13:00 | Segunda 08:00 | Sábado só até 12h (2 dias depois) |
| Domingo 10:00 | Segunda 08:00 | Domingo não envia (1 dia depois) |
| Segunda 07:00 | Segunda 08:00 | Antes das 08h (mesmo dia) |
| Terça 15:00 | Terça 15:00 | Dentro do horário (mantém) |

**Integração:**
1. `recalculate_followup_schedule()`: Ajusta quando lead responde
2. Trigger `adjust_business_hours_on_insert`: Ajusta quando campanha é criada
3. Trigger `adjust_business_hours_on_update`: Ajusta se scheduled_at for modificado

**Impacto:**
- Todas novas campanhas: Business hours automático
- Recálculos: Business hours automático
- Edições manuais: Business hours automático

---

### FASE 3: POSITIONING

#### Antes:
```
Differential vs R$ 199 DIY:
- They: DIY (20-40h setup, 5-10h/week maintenance)
- Us: Done-for-you (7 days ready, 0h/week)
```

#### Depois (Survivor Mode):
```
CoreAdapt = Done-For-You:
- 7 days from payment to GO-LIVE
- Francisco implements everything (zero technical work for client)
- 0 hours/week maintenance (we handle everything)
- Stops wasting 10-30h/week on manual qualification
```

**Mudanças:**
- ❌ Removido: Comparações com R$ 199 DIY
- ✅ Adicionado: Foco em CoreAdapt R$ 997 done-for-you
- ✅ Atualizado: System Message com survivor mode
- ✅ Atualizado: step_context com timings corretos

---

## TESTES RECOMENDADOS

### 1. Teste de Timing no Banco

```sql
-- Verificar se timing foi atualizado
SELECT step_number, wait_hours, wait_minutes,
       (wait_hours + ROUND(wait_minutes::numeric / 60, 2)) as total_hours
FROM corev4_followup_steps
ORDER BY step_number;

-- Resultado esperado:
-- 1 | 1   | 0 | 1
-- 2 | 4   | 0 | 4
-- 3 | 24  | 0 | 24
-- 4 | 72  | 0 | 72
-- 5 | 168 | 0 | 168
```

### 2. Teste de Business Hours Function

```sql
-- Teste 1: Domingo 10:00 → Segunda 08:00
SELECT adjust_to_business_hours('2025-11-16 10:00:00-03'::TIMESTAMPTZ);
-- Esperado: 2025-11-17 08:00:00-03

-- Teste 2: Sexta 19:00 → Segunda 08:00
SELECT adjust_to_business_hours('2025-11-14 19:00:00-03'::TIMESTAMPTZ);
-- Esperado: 2025-11-17 08:00:00-03

-- Teste 3: Terça 15:00 → Terça 15:00 (mantém)
SELECT adjust_to_business_hours('2025-11-11 15:00:00-03'::TIMESTAMPTZ);
-- Esperado: 2025-11-11 15:00:00-03
```

### 3. Teste de Trigger

```sql
-- Criar execution de teste agendada para Domingo
INSERT INTO corev4_followup_executions (
  campaign_id, contact_id, company_id,
  step, total_steps, scheduled_at
)
VALUES (
  <campaign_id_valido>,
  <contact_id_valido>,
  1,
  1,
  5,
  '2025-11-16 10:00:00-03'::TIMESTAMPTZ -- Domingo
)
RETURNING id, scheduled_at;

-- Verificar se foi ajustado para Segunda 08:00
-- Depois deletar: DELETE FROM corev4_followup_executions WHERE id = <id_teste>;
```

### 4. Teste End-to-End

**Cenário:** Criar nova campanha e verificar timing + business hours

1. Chamar workflow `Create Followup Campaign`
2. Passar `contact_id` e `company_id`
3. Verificar no banco:
```sql
SELECT step, scheduled_at
FROM corev4_followup_executions
WHERE contact_id = <contact_id>
ORDER BY step;
```

**Resultado esperado:**
- Step 1: NOW + 1h (ajustado para business hours)
- Step 2: NOW + 4h (ajustado para business hours)
- Step 3: NOW + 24h (ajustado para business hours)
- Step 4: NOW + 72h (ajustado para business hours)
- Step 5: NOW + 168h (ajustado para business hours)

**Exemplo:** Se NOW = Segunda 15:00
- Step 1: Segunda 16:00 ✅
- Step 2: Terça 08:00 ✅ (Segunda 19:00 ajustado)
- Step 3: Terça 15:00 ✅
- Step 4: Quinta 15:00 ✅
- Step 5: Segunda (próxima) 15:00 ✅

### 5. Teste de Recálculo (Counter Restart)

**Cenário:** Lead responde → contador reinicia

1. Lead tem campanha ativa com executions pendentes
2. Lead envia mensagem (Main Router executa recalculate_followup_schedule)
3. Verificar:
```sql
SELECT contact_id, last_interaction_at
FROM corev4_contacts
WHERE id = <contact_id>;

SELECT step, scheduled_at
FROM corev4_followup_executions
WHERE contact_id = <contact_id>
  AND executed = false
ORDER BY step;
```

**Resultado esperado:**
- `last_interaction_at` atualizado para NOW
- Todos `scheduled_at` recalculados para NOW + timing (com business hours)

---

## ROLLBACK PLAN

Caso precise reverter as mudanças:

### 1. Reverter Timing no Banco

```sql
-- Voltar para timing antigo (NÃO RECOMENDADO)
UPDATE corev4_followup_steps SET wait_hours = 1, wait_minutes = 0 WHERE step_number = 1;
UPDATE corev4_followup_steps SET wait_hours = 25, wait_minutes = 0 WHERE step_number = 2;
UPDATE corev4_followup_steps SET wait_hours = 73, wait_minutes = 0 WHERE step_number = 3;
UPDATE corev4_followup_steps SET wait_hours = 145, wait_minutes = 0 WHERE step_number = 4;
UPDATE corev4_followup_steps SET wait_hours = 313, wait_minutes = 0 WHERE step_number = 5;
```

### 2. Desabilitar Business Hours

```sql
-- Remover triggers (business hours continua ativo via recalculate, mas novas campanhas não ajustam)
DROP TRIGGER IF EXISTS adjust_business_hours_on_insert ON corev4_followup_executions;
DROP TRIGGER IF EXISTS adjust_business_hours_on_update ON corev4_followup_executions;

-- Para desabilitar completamente:
-- Reverter recalculate_followup_schedule para versão anterior (sem adjust_to_business_hours)
```

### 3. Reverter Workflows

- Re-importar versões antigas dos JSONs do git history
- Ativar workflows antigos

---

## MONITORING

Após deploy, monitorar:

### 1. Logs do Sentinel Flow

- Verificar se executions estão sendo enviadas
- Verificar scheduled_at das próximas executions
- Conferir se business hours está sendo respeitado

### 2. Campanhas Ativas

```sql
-- Campanhas ativas
SELECT COUNT(*) as total_active
FROM corev4_followup_campaigns
WHERE status = 'active' AND should_continue = true;

-- Próximas executions agendadas
SELECT
  step,
  COUNT(*) as total,
  MIN(scheduled_at) as proxima,
  MAX(scheduled_at) as ultima
FROM corev4_followup_executions
WHERE executed = false AND should_send = true
GROUP BY step
ORDER BY step;
```

### 3. Taxa de Re-engajamento

```sql
-- Leads que responderam após followup
SELECT
  DATE(stopped_at) as data,
  COUNT(*) as total_stopped,
  SUM(CASE WHEN stopped_reason = 'lead_responded' THEN 1 ELSE 0 END) as leads_reengaged,
  ROUND(100.0 * SUM(CASE WHEN stopped_reason = 'lead_responded' THEN 1 ELSE 0 END) / COUNT(*), 2) as taxa_pct
FROM corev4_followup_campaigns
WHERE status = 'stopped' AND stopped_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(stopped_at)
ORDER BY data DESC;
```

---

## CHECKLIST DE DEPLOY

- [ ] 1. Executar migrations SQL no banco (ordem correta)
- [ ] 2. Verificar resultados dos testes SQL
- [ ] 3. Importar workflows atualizados no n8n
- [ ] 4. Ativar workflows (Create Followup Campaign + Sentinel Flow)
- [ ] 5. Criar campanha de teste end-to-end
- [ ] 6. Verificar scheduled_at das executions de teste
- [ ] 7. Simular resposta de lead (testar recalculate)
- [ ] 8. Monitorar logs por 24-48h
- [ ] 9. Verificar taxa de re-engajamento após 1 semana
- [ ] 10. Ajustar mensagens se necessário (v1.3)

---

## SUPORTE

**Documentação Completa:**
- `SENTINEL_COMPLETE_DISCOVERY_FINAL.md` — Deep dive técnico
- `SENTINEL_SYSTEM_MESSAGE_v1.2.md` — System message completo
- `CoreConnect_AI_Master_Positioning_Document_2025.md` — Fonte de verdade

**Contato:**
- Francisco Pasteur (founder)
- CoreConnect.AI team

---

**Fim do Implementation Guide**

**Status:** ✅ Ready to Deploy
**Data:** 10 de Novembro de 2025
