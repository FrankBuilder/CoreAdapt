# 🚨 FIX: Followups Duplicados no Sentinel

**Data:** 16 de Novembro de 2025
**Status:** CRÍTICO - Requer correção imediata
**Afeta:** CoreAdapt Sentinel Flow v4

---

## 📋 PROBLEMA IDENTIFICADO

### Descrição do Bug

Quando múltiplos followups de uma mesma campanha "vencem" durante a espera do horário permitido de envio, o sistema envia todos de uma vez ao invés de enviar apenas o primeiro step pendente.

### Cenário de Reprodução

```
Timeline:
10h00 - Lead para de responder
11h00 - Followup Step 1 deveria ser enviado (1h depois)
       - MAS está fora do horário permitido (ex: após 20h)
       - Sistema reagenda para 9h do dia seguinte

Durante a noite:
15h00 - Followup Step 2 também "vence" (4h depois do primeiro)
       - Também fica pendente aguardando horário

Manhã seguinte:
09h00 - Sistema processa followups pendentes
       - ❌ BUG: Envia AMBOS Step 1 e Step 2 simultaneamente
       - ✅ ESPERADO: Deveria enviar apenas Step 1
```

### Impacto

1. **Experiência do Lead:** Recebe múltiplas mensagens seguidas (spam)
2. **Lógica de Followup:** Quebra a progressão estratégica (suave → urgente)
3. **Taxa de Resposta:** Reduz efetividade do reengajamento
4. **Reputação:** Lead pode marcar como spam ou bloquear

---

## 🔍 ANÁLISE TÉCNICA

### Query Atual (com bug)

**Arquivo:** `CoreAdapt Sentinel Flow _ v4.json` (linha 245)

```sql
SELECT
  e.id AS execution_id,
  e.campaign_id,
  e.contact_id,
  e.step,
  e.scheduled_at,
  -- ... outros campos ...
FROM corev4_followup_executions e
INNER JOIN corev4_contacts c ON c.id = e.contact_id
-- ... outros joins ...
WHERE e.executed = false
  AND e.should_send = true
  AND e.scheduled_at <= NOW()
  -- ... outras condições ...
ORDER BY e.scheduled_at ASC
LIMIT 50;
```

### Por Que Ocorre o Bug

A query atual seleciona **TODAS** as execuções pendentes (`executed = false`) que já venceram (`scheduled_at <= NOW()`), **SEM FILTRAR** por step único por campanha.

**Exemplo:**

```
campaign_id: abc-123
├─ Step 1: scheduled_at = 2025-11-15 09:00 (vencido) ✓ SELECIONADO
├─ Step 2: scheduled_at = 2025-11-15 08:00 (vencido) ✓ SELECIONADO ❌ BUG
├─ Step 3: scheduled_at = 2025-11-16 10:00 (futuro) ✗ não selecionado
```

Ambos Steps 1 e 2 passam no filtro → Ambos são processados → Ambos são enviados.

---

## ✅ SOLUÇÃO

### Estratégia de Correção

Modificar a query para selecionar **APENAS o primeiro step não executado** de cada campanha.

### Query Corrigida

```sql
SELECT DISTINCT ON (e.campaign_id)
  e.id AS execution_id,
  e.campaign_id,
  e.contact_id,
  e.company_id,
  e.step,
  e.total_steps,
  e.scheduled_at,

  c.full_name AS contact_name,
  c.phone_number,
  c.whatsapp,
  c.last_interaction_at,

  ls.total_score AS anum_score,
  CASE WHEN ls.total_score IS NULL THEN FALSE ELSE TRUE END AS has_been_analyzed,
  COALESCE(ls.qualification_stage, 'inicial') AS qualification_stage,

  co.evolution_api_url,
  co.evolution_instance,
  co.evolution_api_key,

  fs.wait_hours,
  fs.wait_minutes

FROM corev4_followup_executions e
INNER JOIN corev4_contacts c ON c.id = e.contact_id
LEFT JOIN corev4_lead_state ls ON ls.contact_id = e.contact_id
INNER JOIN corev4_companies co ON co.id = e.company_id
LEFT JOIN corev4_followup_campaigns fc ON fc.id = e.campaign_id
LEFT JOIN corev4_followup_steps fs ON fs.config_id = fc.config_id AND fs.step_number = e.step

WHERE e.executed = false
  AND e.should_send = true
  AND c.opt_out = false
  AND e.scheduled_at <= NOW()
  AND (
    c.last_interaction_at IS NULL
    OR
    c.last_interaction_at < e.scheduled_at
  )
  AND (
    ls.total_score IS NULL
    OR
    ls.total_score < 70
  )

ORDER BY e.campaign_id, e.step ASC, e.scheduled_at ASC
LIMIT 50;
```

### Diferenças Chave

1. **`SELECT DISTINCT ON (e.campaign_id)`**
   - PostgreSQL retorna apenas **1 row por campaign_id**
   - Combinado com `ORDER BY e.campaign_id, e.step ASC`
   - Garante que apenas o **step mais baixo** (não executado) é selecionado

2. **`ORDER BY e.campaign_id, e.step ASC, e.scheduled_at ASC`**
   - Primeiro agrupa por campanha
   - Depois ordena por step (1, 2, 3...)
   - `DISTINCT ON` pega o primeiro = menor step pendente

### Resultado Esperado

```
campaign_id: abc-123
├─ Step 1: scheduled_at = 2025-11-15 09:00 ✓ SELECIONADO
├─ Step 2: scheduled_at = 2025-11-15 08:00 ✗ IGNORADO (step > 1)
├─ Step 3: scheduled_at = 2025-11-16 10:00 ✗ IGNORADO (step > 1)

Resultado: Apenas Step 1 é processado e enviado
```

Após Step 1 ser marcado como `executed = true`:
- Próxima execução do cron: Step 2 será selecionado (agora é o menor pendente)

---

## 🔧 IMPLEMENTAÇÃO

### 1. Backup Atual

```bash
cp "CoreAdapt Sentinel Flow _ v4.json" "CoreAdapt Sentinel Flow _ v4_BEFORE_DISTINCT_FIX.json"
```

### 2. Aplicar Correção

Executar script: `scripts/fix_sentinel_followup_duplicados.py`

### 3. Testar

#### Teste 1: Query de Diagnóstico

```bash
# Executar queries/DIAGNOSTICO_FOLLOWUP_DUPLICADOS.sql
# Seção 2: Verificar se há campanhas com múltiplos steps pendentes
```

#### Teste 2: Comparar Resultados

```sql
-- Ver diferença entre query antiga e nova
-- Seção 7 do arquivo de diagnóstico
```

#### Teste 3: Validação em Produção

1. Importar workflow atualizado
2. Criar campanha de teste com 2 steps rápidos (1min e 2min)
3. Deixar ambos vencerem fora do horário
4. Verificar que apenas 1 mensagem é enviada quando horário libera

---

## 📊 QUERIES DE VALIDAÇÃO

### Antes da Correção

```sql
-- Quantas campanhas têm múltiplos steps pendentes?
SELECT COUNT(DISTINCT campaign_id) as campanhas_com_problema
FROM (
    SELECT campaign_id, COUNT(*) as steps_pendentes
    FROM corev4_followup_executions
    WHERE executed = false
      AND should_send = true
      AND scheduled_at <= NOW()
    GROUP BY campaign_id
    HAVING COUNT(*) > 1
) subquery;
```

### Depois da Correção

```sql
-- Simular quantos followups seriam enviados
-- ANTES: Pode retornar múltiplos por campanha
-- DEPOIS: Retorna no máximo 1 por campanha

SELECT COUNT(*) as total_envios
FROM (
    SELECT DISTINCT ON (e.campaign_id) e.id
    FROM corev4_followup_executions e
    WHERE e.executed = false
      AND e.should_send = true
      AND e.scheduled_at <= NOW()
    ORDER BY e.campaign_id, e.step ASC
) subquery;
```

---

## 🎯 CHECKLIST DE IMPLEMENTAÇÃO

- [ ] Executar queries de diagnóstico (seção 2 e 4)
- [ ] Confirmar que há campanhas com múltiplos steps pendentes
- [ ] Fazer backup do workflow atual
- [ ] Aplicar correção via script Python
- [ ] Validar JSON do workflow (syntax check)
- [ ] Testar query corrigida no Supabase diretamente
- [ ] Importar workflow atualizado no n8n
- [ ] Criar teste com campanha controlada
- [ ] Monitorar logs nas primeiras 24h
- [ ] Confirmar que apenas 1 step por campanha é enviado

---

## 📝 NOTAS TÉCNICAS

### Por Que Não Usar `MIN(step)`?

```sql
-- Alternativa NÃO recomendada:
SELECT MIN(step) as primeiro_step
FROM corev4_followup_executions
WHERE executed = false
GROUP BY campaign_id
```

**Problema:** Precisamos retornar **todas as colunas** (contact_name, phone, etc), não apenas o step mínimo. `MIN()` requer agregação, mas `DISTINCT ON` permite retornar a row completa.

### Por Que `DISTINCT ON` é Melhor?

- **Performance:** Mais rápido que subquery com `MIN()`
- **Legibilidade:** Mais claro qual row será selecionada
- **PostgreSQL Native:** Aproveita otimização do Postgres

### Edge Cases Considerados

1. **Campanha com apenas 1 step pendente:** Funciona normal
2. **Múltiplas campanhas diferentes:** Cada uma retorna 1 step
3. **Step 1 executado, Step 2 pendente:** Step 2 será selecionado
4. **Todos steps executados:** Nenhum retornado (correto)

---

## 🚀 PRÓXIMOS PASSOS

1. **Imediato:** Aplicar correção
2. **Curto Prazo:** Monitorar métricas de followup (taxa de resposta)
3. **Médio Prazo:** Considerar adicionar field `next_step_scheduled_at` em `corev4_followup_campaigns` para tracking
4. **Longo Prazo:** Implementar dashboard de health check do Sentinel

---

**FIM DO DOCUMENTO**
