# 🔧 CoreAdapt v4 - Guia do Desenvolvedor
## Database Developer Guide

Este guia fornece queries práticas, padrões de uso e exemplos para trabalhar com o banco de dados CoreAdapt v4.

---

## 📋 ÍNDICE

1. [Queries Comuns](#queries-comuns)
2. [Padrões de Uso](#padrões-de-uso)
3. [Segurança e RLS](#segurança-e-rls)
4. [Performance Tips](#performance-tips)
5. [Exemplos de Fluxos](#exemplos-de-fluxos)
6. [Troubleshooting](#troubleshooting)

---

## 🔍 QUERIES COMUNS

### Gestão de Contatos

#### Criar novo contato
```sql
INSERT INTO corev4_contacts (
  company_id,
  full_name,
  whatsapp,
  phone_number,
  email,
  origin_source,
  utm_source,
  utm_medium,
  utm_campaign
) VALUES (
  1,
  'João Silva',
  '5511999999999',
  '11999999999',
  'joao@example.com',
  'whatsapp',
  'google',
  'cpc',
  'lead_gen_2024'
) RETURNING id;
```

#### Buscar contato por WhatsApp
```sql
SELECT *
FROM corev4_contacts
WHERE whatsapp = '5511999999999'
  AND company_id = 1
  AND is_active = true
  AND opt_out = false;
```

#### Atualizar última interação
```sql
UPDATE corev4_contacts
SET last_interaction_at = NOW()
WHERE id = 123;
```

#### Listar contatos ativos com tempo desde última interação
```sql
SELECT
  id,
  full_name,
  whatsapp,
  last_interaction_at,
  EXTRACT(epoch FROM (NOW() - last_interaction_at))/3600 AS hours_since_interaction
FROM corev4_contacts
WHERE company_id = 1
  AND is_active = true
  AND opt_out = false
ORDER BY last_interaction_at DESC;
```

---

### Conversas e Chat

#### Criar ou recuperar chat
```sql
INSERT INTO corev4_chats (
  company_id,
  contact_id,
  conversation_open,
  last_message_ts
)
VALUES (1, 123, true, EXTRACT(epoch FROM NOW())::bigint)
ON CONFLICT (contact_id, company_id)
DO UPDATE SET
  last_message_ts = EXCLUDED.last_message_ts,
  conversation_open = true
RETURNING id;
```

#### Adicionar mensagem ao histórico
```sql
INSERT INTO corev4_chat_history (
  session_id,
  contact_id,
  company_id,
  role,
  message,
  message_type,
  tokens_used,
  cost_usd,
  model_used,
  message_timestamp
) VALUES (
  'uuid-aqui',
  123,
  1,
  'human', -- ou 'ai'
  'Olá, gostaria de saber mais sobre o produto',
  'text',
  NULL,
  NULL,
  NULL,
  NOW()
);
```

#### Recuperar histórico de conversa
```sql
SELECT
  id,
  role,
  message,
  message_type,
  message_timestamp,
  has_media
FROM corev4_chat_history
WHERE contact_id = 123
  AND company_id = 1
ORDER BY message_timestamp ASC
LIMIT 50;
```

#### Fechar conversa
```sql
UPDATE corev4_chats
SET
  conversation_open = false,
  closed_reason = 'timeout'
WHERE contact_id = 123
  AND company_id = 1;
```

---

### Qualificação ANUM

#### Criar/Atualizar Lead State
```sql
INSERT INTO corev4_lead_state (
  company_id,
  contact_id,
  authority_score,
  need_score,
  urgency_score,
  money_score,
  total_score,
  qualification_stage,
  is_qualified,
  status,
  analysis_count,
  last_analyzed_at,
  analyzed_at
)
VALUES (
  1,
  123,
  75,
  80,
  60,
  70,
  71.25, -- (75+80+60+70)/4
  'qualified',
  true,
  'active',
  1,
  NOW(),
  NOW()
)
ON CONFLICT (contact_id, company_id)
DO UPDATE SET
  authority_score = EXCLUDED.authority_score,
  need_score = EXCLUDED.need_score,
  urgency_score = EXCLUDED.urgency_score,
  money_score = EXCLUDED.money_score,
  total_score = EXCLUDED.total_score,
  qualification_stage = EXCLUDED.qualification_stage,
  is_qualified = EXCLUDED.is_qualified,
  analysis_count = corev4_lead_state.analysis_count + 1,
  last_analyzed_at = NOW(),
  updated_at = NOW();
```

#### Registrar análise no histórico
```sql
INSERT INTO corev4_anum_history (
  company_id,
  contact_id,
  authority_score,
  authority_reasoning,
  need_score,
  need_reasoning,
  urgency_score,
  urgency_reasoning,
  money_score,
  money_reasoning,
  total_score,
  qualification_stage,
  analysis_context,
  analyzed_at
) VALUES (
  1,
  123,
  75,
  'Tomador de decisão, CEO da empresa',
  80,
  'Problema crítico identificado no processo de vendas',
  60,
  'Precisa resolver nos próximos 3 meses',
  70,
  'Budget disponível confirmado',
  71.25,
  'qualified',
  '{"messages_analyzed": 10, "keywords_found": ["budget", "urgente", "decisor"]}'::jsonb,
  NOW()
);
```

#### Buscar leads qualificados para ofertar reunião
```sql
SELECT
  c.id,
  c.full_name,
  c.whatsapp,
  ls.total_score,
  ls.qualification_stage,
  ls.main_pain_category_id
FROM corev4_contacts c
INNER JOIN corev4_lead_state ls ON c.id = ls.contact_id
WHERE c.company_id = 1
  AND c.is_active = true
  AND c.opt_out = false
  AND ls.total_score >= 70
  AND ls.is_qualified = true
  AND NOT EXISTS (
    SELECT 1
    FROM corev4_scheduled_meetings sm
    WHERE sm.contact_id = c.id
      AND sm.status IN ('scheduled', 'confirmed')
  )
ORDER BY ls.total_score DESC;
```

---

### Follow-up e Campanhas

#### Criar nova campanha de follow-up
```sql
-- 1. Buscar config ativa da empresa
SELECT id, total_steps
FROM corev4_followup_configs
WHERE company_id = 1
  AND is_active = true
LIMIT 1;

-- 2. Criar campanha
INSERT INTO corev4_followup_campaigns (
  contact_id,
  company_id,
  config_id,
  status,
  steps_completed,
  total_steps,
  should_continue
)
VALUES (123, 1, 1, 'active', 0, 5, true)
RETURNING id;

-- 3. Criar execuções (steps)
WITH steps AS (
  SELECT
    step_number,
    wait_hours,
    wait_minutes
  FROM corev4_followup_steps
  WHERE config_id = 1
  ORDER BY step_number
)
INSERT INTO corev4_followup_executions (
  campaign_id,
  contact_id,
  company_id,
  step,
  total_steps,
  scheduled_at,
  executed,
  should_send
)
SELECT
  999, -- campaign_id criado acima
  123,
  1,
  step_number,
  5,
  NOW() + (wait_hours || ' hours')::interval + (wait_minutes || ' minutes')::interval,
  false,
  true
FROM steps;
```

#### Buscar execuções pendentes para envio
```sql
SELECT
  fe.id,
  fe.contact_id,
  fe.step,
  fe.scheduled_at,
  c.full_name,
  c.whatsapp,
  co.evolution_api_url,
  co.evolution_instance,
  co.evolution_api_key
FROM corev4_followup_executions fe
INNER JOIN corev4_contacts c ON fe.contact_id = c.id
INNER JOIN corev4_companies co ON fe.company_id = co.id
INNER JOIN corev4_followup_campaigns fc ON fe.campaign_id = fc.id
WHERE fe.executed = false
  AND fe.should_send = true
  AND fe.scheduled_at <= NOW()
  AND c.opt_out = false
  AND fc.should_continue = true
  AND NOT EXISTS (
    -- Verificar se não tem reunião agendada
    SELECT 1
    FROM corev4_scheduled_meetings sm
    WHERE sm.contact_id = c.id
      AND sm.status IN ('scheduled', 'confirmed')
      AND sm.meeting_date > NOW()
  )
  AND NOT EXISTS (
    -- Verificar se lead não respondeu após agendamento
    SELECT 1
    FROM corev4_chat_history ch
    WHERE ch.contact_id = c.id
      AND ch.role = 'human'
      AND ch.message_timestamp >= fe.scheduled_at
  )
ORDER BY fe.scheduled_at ASC
LIMIT 10;
```

#### Marcar execução como enviada
```sql
UPDATE corev4_followup_executions
SET
  executed = true,
  sent_at = NOW(),
  generated_message = 'Mensagem enviada aqui',
  evolution_message_id = 'msg_123',
  updated_at = NOW()
WHERE id = 456;

-- Atualizar campanha
UPDATE corev4_followup_campaigns
SET
  steps_completed = steps_completed + 1,
  last_step_sent_at = NOW(),
  updated_at = NOW()
WHERE id = 999;
```

#### Pausar campanha (lead respondeu)
```sql
-- Usar a função para recalcular agendamentos
SELECT recalculate_followup_schedule(
  p_contact_id := 123,
  p_interaction_timestamp := NOW()
);

-- Ou manualmente:
UPDATE corev4_followup_executions
SET
  scheduled_at = scheduled_at + INTERVAL '48 hours',
  updated_at = NOW()
WHERE contact_id = 123
  AND executed = false
  AND should_send = true;
```

#### Parar campanha (meta atingida - reunião agendada)
```sql
UPDATE corev4_followup_campaigns
SET
  should_continue = false,
  stopped_reason = 'meeting_scheduled',
  status = 'stopped',
  updated_at = NOW()
WHERE contact_id = 123
  AND company_id = 1
  AND status = 'active';
```

---

### Reuniões e Agendamentos

#### Registrar reunião agendada (webhook Cal.com)
```sql
INSERT INTO corev4_scheduled_meetings (
  contact_id,
  company_id,
  meeting_date,
  meeting_end_date,
  meeting_duration_minutes,
  meeting_type,
  meeting_timezone,
  cal_booking_uid,
  cal_event_type_id,
  cal_event_title,
  cal_attendee_email,
  cal_attendee_name,
  cal_meeting_url,
  status,
  anum_score_at_booking,
  authority_score,
  need_score,
  urgency_score,
  money_score,
  qualification_stage
)
SELECT
  123,
  1,
  '2024-11-15 10:00:00-03'::timestamptz,
  '2024-11-15 11:00:00-03'::timestamptz,
  60,
  'discovery',
  'America/Sao_Paulo',
  'cal_booking_123',
  1001,
  'Mesa de Clareza',
  'joao@example.com',
  'João Silva',
  'https://meet.google.com/abc-def-ghi',
  'scheduled',
  ls.total_score,
  ls.authority_score,
  ls.need_score,
  ls.urgency_score,
  ls.money_score,
  ls.qualification_stage
FROM corev4_lead_state ls
WHERE ls.contact_id = 123
  AND ls.company_id = 1;
```

#### Buscar reuniões que precisam de lembrete
```sql
-- View já pronta
SELECT *
FROM v_meetings_needing_reminders
ORDER BY hours_until_meeting ASC;

-- Ou query manual:
SELECT
  sm.id,
  sm.contact_id,
  sm.meeting_date,
  c.full_name,
  c.whatsapp,
  CASE
    WHEN sm.meeting_date - INTERVAL '24 hours' <= NOW()
      AND sm.reminder_24h_sent = false THEN '24h'
    WHEN sm.meeting_date - INTERVAL '1 hour' <= NOW()
      AND sm.reminder_1h_sent = false THEN '1h'
  END AS reminder_type
FROM corev4_scheduled_meetings sm
INNER JOIN corev4_contacts c ON sm.contact_id = c.id
WHERE sm.status = 'scheduled'
  AND sm.meeting_date > NOW()
  AND (
    (sm.meeting_date - INTERVAL '24 hours' <= NOW() AND sm.reminder_24h_sent = false)
    OR (sm.meeting_date - INTERVAL '1 hour' <= NOW() AND sm.reminder_1h_sent = false)
  );
```

#### Marcar lembrete como enviado
```sql
UPDATE corev4_scheduled_meetings
SET
  reminder_24h_sent = true,
  reminder_24h_sent_at = NOW(),
  reminder_24h_delivery_status = 'sent',
  updated_at = NOW()
WHERE id = 789;
```

#### Marcar reunião como concluída
```sql
UPDATE corev4_scheduled_meetings
SET
  meeting_completed = true,
  meeting_completed_at = NOW(),
  meeting_notes = 'Reunião produtiva, lead interessado',
  meeting_outcome = 'qualified',
  next_action = 'send_proposal',
  status = 'completed',
  updated_at = NOW()
WHERE id = 789;
```

---

## 🎨 PADRÕES DE USO

### Padrão Multi-tenant

**Sempre** filtrar por `company_id` em todas as queries:

```sql
-- ❌ ERRADO
SELECT * FROM corev4_contacts WHERE whatsapp = '5511999999999';

-- ✅ CORRETO
SELECT * FROM corev4_contacts
WHERE whatsapp = '5511999999999'
  AND company_id = 1;
```

### Padrão de Soft Delete

Use `is_active` e `opt_out` ao invés de DELETE:

```sql
-- ❌ EVITAR
DELETE FROM corev4_contacts WHERE id = 123;

-- ✅ RECOMENDADO
UPDATE corev4_contacts
SET
  is_active = false,
  updated_at = NOW()
WHERE id = 123;

-- Para opt-out
UPDATE corev4_contacts
SET
  opt_out = true,
  updated_at = NOW()
WHERE id = 123;
```

### Padrão de Auditoria

Use `created_at` e `updated_at` (atualizado automaticamente por trigger):

```sql
-- updated_at é atualizado automaticamente
UPDATE corev4_contacts
SET full_name = 'Novo Nome'
WHERE id = 123;
-- updated_at será NOW() automaticamente
```

### Padrão de Session UUID

Para chat, sempre obter ou criar UUID:

```sql
SELECT get_or_create_session_uuid(
  p_contact_id := 123,
  p_company_id := 1
);
```

---

## 🔒 SEGURANÇA E RLS

### Configurar contexto da empresa

Antes de fazer queries, sempre setar o company_id:

```sql
-- No PostgreSQL
SET app.current_company_id = '1';

-- No Supabase (client-side)
-- Feito automaticamente via RLS policies
```

### Verificar RLS habilitado

```sql
SELECT
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename LIKE 'corev4_%';
```

### Listar policies

```sql
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename LIKE 'corev4_%';
```

---

## ⚡ PERFORMANCE TIPS

### Use índices apropriados

```sql
-- Busca por WhatsApp (já tem índice)
SELECT * FROM corev4_contacts
WHERE whatsapp = '5511999999999'
  AND company_id = 1;

-- Busca por nome (usa índice GIN trigram)
SELECT * FROM corev4_contacts
WHERE full_name ILIKE '%silva%'
  AND company_id = 1;
```

### Evite SELECT *

```sql
-- ❌ EVITAR
SELECT * FROM corev4_scheduled_meetings;

-- ✅ MELHOR
SELECT
  id,
  contact_id,
  meeting_date,
  status
FROM corev4_scheduled_meetings;
```

### Use LIMIT em listagens

```sql
SELECT *
FROM corev4_chat_history
WHERE contact_id = 123
ORDER BY message_timestamp DESC
LIMIT 50; -- Sempre limitar
```

### Use Views otimizadas

```sql
-- Ao invés de JOIN complexo, use view
SELECT * FROM v_active_campaigns
WHERE company_id = 1;
```

### Batch updates

```sql
-- Para múltiplas atualizações
UPDATE corev4_followup_executions
SET should_send = false
WHERE contact_id IN (123, 456, 789)
  AND executed = false;
```

---

## 📊 EXEMPLOS DE FLUXOS

### Fluxo Completo: Lead Novo até Reunião

```sql
-- 1. Criar contato
INSERT INTO corev4_contacts (company_id, full_name, whatsapp, origin_source)
VALUES (1, 'Maria Santos', '5511988887777', 'whatsapp')
RETURNING id; -- 999

-- 2. Criar chat
INSERT INTO corev4_chats (company_id, contact_id, conversation_open)
VALUES (1, 999, true);

-- 3. Primeira mensagem
INSERT INTO corev4_chat_history (
  session_id,
  contact_id,
  company_id,
  role,
  message,
  message_type,
  message_timestamp
) VALUES (
  (SELECT get_or_create_session_uuid(999, 1)),
  999,
  1,
  'human',
  'Oi, quero saber sobre seus serviços',
  'text',
  NOW()
);

-- 4. Após algumas mensagens, analisar ANUM
INSERT INTO corev4_lead_state (
  company_id, contact_id,
  authority_score, need_score, urgency_score, money_score,
  total_score, qualification_stage, is_qualified, status
) VALUES (
  1, 999,
  80, 85, 75, 80,
  80, 'highly_qualified', true, 'active'
);

-- 5. Score alto - ofertar reunião
INSERT INTO corev4_meeting_offers (
  contact_id, company_id,
  offer_type, offer_message, offered_at
) VALUES (
  999, 1,
  'proactive',
  'Gostaria de agendar uma Mesa de Clareza?',
  NOW()
);

-- 6. Lead aceita - reunião agendada
INSERT INTO corev4_scheduled_meetings (
  contact_id, company_id,
  meeting_date, meeting_type, status
) VALUES (
  999, 1,
  NOW() + INTERVAL '2 days',
  'discovery',
  'scheduled'
);

-- 7. Parar follow-ups automáticos (se existirem)
UPDATE corev4_followup_campaigns
SET should_continue = false, stopped_reason = 'meeting_scheduled'
WHERE contact_id = 999;
```

### Fluxo: Lead com Score Baixo → Follow-up

```sql
-- 1. ANUM Score baixo (< 50)
INSERT INTO corev4_lead_state (...)
VALUES (..., total_score = 35, is_qualified = false, ...);

-- 2. Criar campanha de follow-up
INSERT INTO corev4_followup_campaigns (
  contact_id, company_id, config_id,
  status, total_steps, should_continue
) VALUES (999, 1, 1, 'active', 5, true)
RETURNING id; -- 888

-- 3. Criar execuções
INSERT INTO corev4_followup_executions (...)
SELECT ... FROM corev4_followup_steps WHERE config_id = 1;

-- 4. Scheduler envia step 1 (agendado para +24h)
-- 5. Scheduler envia step 2 (agendado para +72h)
-- ...

-- 6. Lead responde → recalcular
SELECT recalculate_followup_schedule(999, NOW());

-- 7. Nova análise ANUM → score subiu
UPDATE corev4_lead_state
SET total_score = 65, is_qualified = true
WHERE contact_id = 999;

-- 8. Score suficiente → ofertar reunião
```

---

## 🔧 TROUBLESHOOTING

### Lead não está recebendo follow-up

```sql
-- Debug: verificar status da campanha
SELECT
  fc.id,
  fc.status,
  fc.should_continue,
  fc.stopped_reason,
  fc.steps_completed,
  fc.total_steps,
  c.opt_out,
  EXISTS(
    SELECT 1 FROM corev4_scheduled_meetings sm
    WHERE sm.contact_id = fc.contact_id
      AND sm.status IN ('scheduled', 'confirmed')
  ) AS has_meeting
FROM corev4_followup_campaigns fc
INNER JOIN corev4_contacts c ON fc.contact_id = c.id
WHERE fc.contact_id = 123;

-- Debug: verificar execuções pendentes
SELECT
  id,
  step,
  scheduled_at,
  executed,
  should_send,
  decision_reason
FROM corev4_followup_executions
WHERE contact_id = 123
  AND executed = false
ORDER BY scheduled_at;
```

### Duplicação de mensagens

```sql
-- Verificar dedup table
SELECT *
FROM corev4_message_dedup
WHERE contact_id = 123
  AND company_id = 1
ORDER BY created_at DESC;

-- Limpar mensagens antigas (> 24h)
DELETE FROM corev4_message_dedup
WHERE created_at < NOW() - INTERVAL '24 hours';
```

### Performance lenta em queries

```sql
-- Verificar query plan
EXPLAIN ANALYZE
SELECT * FROM corev4_contacts
WHERE company_id = 1
  AND is_active = true;

-- Verificar índices usados
SELECT
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'corev4_contacts';

-- Ver estatísticas de uso de índices
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND tablename LIKE 'corev4_%'
ORDER BY idx_scan DESC;
```

### Verificar integridade referencial

```sql
-- Contatos órfãos (sem empresa)
SELECT c.id, c.full_name, c.company_id
FROM corev4_contacts c
LEFT JOIN corev4_companies co ON c.company_id = co.id
WHERE co.id IS NULL;

-- Lead states sem contato
SELECT ls.id, ls.contact_id
FROM corev4_lead_state ls
LEFT JOIN corev4_contacts c ON ls.contact_id = c.id
WHERE c.id IS NULL;
```

---

## 📈 QUERIES DE ANALYTICS

### Dashboard de Leads

```sql
SELECT
  COUNT(*) AS total_leads,
  COUNT(*) FILTER (WHERE is_active = true) AS active,
  COUNT(*) FILTER (WHERE opt_out = true) AS opted_out,
  COUNT(DISTINCT CASE WHEN last_interaction_at >= NOW() - INTERVAL '7 days'
    THEN id END) AS active_7d
FROM corev4_contacts
WHERE company_id = 1;
```

### Funil de Qualificação

```sql
SELECT
  COUNT(*) AS total_analyzed,
  COUNT(*) FILTER (WHERE total_score >= 70) AS highly_qualified,
  COUNT(*) FILTER (WHERE total_score >= 50 AND total_score < 70) AS qualified,
  COUNT(*) FILTER (WHERE total_score >= 30 AND total_score < 50) AS developing,
  COUNT(*) FILTER (WHERE total_score < 30) AS low_fit,
  ROUND(AVG(total_score), 2) AS avg_score
FROM corev4_lead_state
WHERE company_id = 1;
```

### Taxa de Conversão para Reunião

```sql
SELECT
  COUNT(DISTINCT c.id) AS total_leads,
  COUNT(DISTINCT sm.contact_id) AS leads_with_meeting,
  ROUND(
    100.0 * COUNT(DISTINCT sm.contact_id) / COUNT(DISTINCT c.id),
    2
  ) AS conversion_rate
FROM corev4_contacts c
LEFT JOIN corev4_scheduled_meetings sm ON c.id = sm.contact_id
WHERE c.company_id = 1
  AND c.created_at >= NOW() - INTERVAL '30 days';
```

### Performance de Follow-up

```sql
SELECT
  COUNT(*) AS total_campaigns,
  COUNT(*) FILTER (WHERE status = 'active') AS active,
  COUNT(*) FILTER (WHERE status = 'completed') AS completed,
  COUNT(*) FILTER (WHERE stopped_reason = 'meeting_scheduled') AS converted,
  ROUND(AVG(steps_completed), 2) AS avg_steps_sent
FROM corev4_followup_campaigns
WHERE company_id = 1;
```

---

## 🎯 CHECKLIST DE BOAS PRÁTICAS

- [ ] Sempre filtrar por `company_id` (multi-tenancy)
- [ ] Usar soft delete (`is_active`, `opt_out`) ao invés de DELETE
- [ ] Verificar `opt_out = false` antes de enviar mensagens
- [ ] Usar `LIMIT` em queries de listagem
- [ ] Preferir views otimizadas quando disponíveis
- [ ] Usar índices apropriados (verificar EXPLAIN ANALYZE)
- [ ] Sempre usar transactions para operações multi-step
- [ ] Validar dados antes de INSERT/UPDATE
- [ ] Logar erros em `corev4_execution_logs`
- [ ] Manter `last_interaction_at` atualizado

---

## 📚 RECURSOS ADICIONAIS

- **DATABASE_DEEP_DIVE_ANALYSIS.md**: Análise detalhada de cada tabela
- **DATABASE_RECOMMENDATIONS.md**: Recomendações de otimização
- **DATABASE_EXECUTIVE_SUMMARY.md**: Visão executiva

---

**Última atualização**: 2025-11-10
**Versão**: 1.0
