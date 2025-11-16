# 🚨 ANÁLISE COMPLETA: Edge Cases do Sentinel

**Você está certo. Minha correção anterior é INCOMPLETA.**

---

## ❌ PROBLEMAS IDENTIFICADOS

### Problema 1: Steps Subsequentes Não São Reagendados ✅ RESOLVIDO PARCIALMENTE

**Minha correção:**
- Query usa `DISTINCT ON (campaign_id)` + `ORDER BY step ASC`
- Apenas o **menor step não executado** é selecionado

**Como funciona:**
```
Execução 1 (9h):
- Step 1: executed=false, step=1 → SELECIONADO ✓
- Step 2: executed=false, step=2 → IGNORADO (step > 1)
→ Envia Step 1
→ Marca Step 1 como executed=true

Execução 2 (9h05, próximo cron):
- Step 1: executed=true → NÃO passa no WHERE
- Step 2: executed=false, step=2 → AGORA É O MENOR → SELECIONADO ✓
→ Envia Step 2
```

**Conclusão:** Steps subsequentes **não precisam ser reagendados**. Eles já estão na tabela com `executed=false`. O cron simplesmente seleciona o próximo step menor após marcar o anterior como executado.

---

### Problema 2: Interação Durante a Espera ❌ NÃO RESOLVIDO

**Cenário:**
```
10h00 - Lead para de responder (last_interaction_at = 10h00)
11h00 - Step 1 agendado (scheduled_at = 11h, executed=false)
15h00 - Step 2 agendado (scheduled_at = 15h, executed=false)
11h30 - Lead RESPONDE (last_interaction_at = 11h30) ← INTERAÇÃO
```

**Query atual verifica:**
```sql
WHERE c.last_interaction_at < e.scheduled_at
```

**Resultado:**
- Step 1: `11h < 11h30` → NÃO envia ✓ (correto)
- Step 2: `15h > 11h30` → AINDA ENVIA! ❌ (ERRADO!)

**PROBLEMA:** Quando o lead responde, todos os followups pendentes deveriam ser cancelados, mas não há lógica para isso!

---

### Problema 3: Interação Logo Após Envio ❌ NÃO RESOLVIDO

**Cenário:**
```
09h00 - Sentinel envia Step 1
09h05 - Lead responde (last_interaction_at = 09h05)
       - Step 2 ainda está com scheduled_at = 13h (4h depois)
```

**Pergunta:** Step 2 deveria ser cancelado ou continuar?

**Lógica esperada:**
- Se lead **respondeu depois do followup**, significa que o followup funcionou
- Todos os steps seguintes deveriam ser cancelados
- Lead volta para fluxo normal do Frank (CoreAdapt One)

**PROBLEMA:** Não há lógica que cancela steps pendentes quando lead responde!

---

### Problema 4: Interação Fora do Horário ❌ NÃO RESOLVIDO

**Cenário:**
```
22h00 - Lead responde (last_interaction_at = 22h00)
       - Fora do horário de envio
       - Followups ainda estão pendentes para 9h do dia seguinte
```

**Pergunta:** Followups deveriam ser cancelados ou enviados às 9h mesmo assim?

**Lógica esperada:**
- Lead respondeu = reengajamento funcionou
- Cancelar todos os followups pendentes
- Mas como o fluxo One Flow vai processar a mensagem se foi fora do horário?

**PROBLEMA:** Falta integração entre Sentinel e One Flow para cancelar followups!

---

### Problema 5: Score ANUM ≥70 Durante Followup ❌ PARCIALMENTE RESOLVIDO

**Query atual tem:**
```sql
WHERE (
  ls.total_score IS NULL
  OR
  ls.total_score < 70
)
```

**Cenário:**
```
Step 1 enviado → Lead responde → ANUM atualizado para score=85
Step 2 ainda pendente
```

**Resultado:** Step 2 **não será enviado** porque `score ≥ 70` ✓

**MAS:** O step fica "pendurado" na tabela com `executed=false` para sempre. Deveria ser marcado como `should_send=false` ou `decision_reason='qualified'`.

---

## ✅ SOLUÇÃO COMPLETA NECESSÁRIA

### Falta Implementar:

#### 1. **Trigger ou Workflow de Cancelamento**

**Criar lógica que:**
- Quando `last_interaction_at` é atualizado em `corev4_contacts`
- Cancela todos os followups pendentes desse contato:

```sql
UPDATE corev4_followup_executions
SET should_send = false,
    decision_reason = 'lead_responded'
WHERE contact_id = $1
  AND executed = false
  AND should_send = true;
```

**Onde implementar:**
- **Opção 1:** Trigger no Postgres (quando `corev4_contacts.last_interaction_at` muda)
- **Opção 2:** Node no One Flow (após salvar mensagem do lead)
- **Opção 3:** Node no Main Router (antes de chamar One Flow)

#### 2. **Atualizar Lógica do Sentinel**

**Adicionar condição extra na query:**
```sql
WHERE e.executed = false
  AND e.should_send = true
  -- ... outras condições ...
  AND (
    -- Se lead respondeu DEPOIS que followup foi agendado, não envia
    c.last_interaction_at IS NULL
    OR
    c.last_interaction_at < (
      -- Pega o horário da ÚLTIMA mensagem DO SENTINEL para este contato
      SELECT MAX(sent_at)
      FROM corev4_followup_executions
      WHERE contact_id = c.id AND executed = true
    )
  )
```

Mas isso é complexo e pode ter problemas de performance.

#### 3. **Limpeza de Steps "Pendurados"**

**Job separado que marca como não enviar:**
```sql
UPDATE corev4_followup_executions
SET should_send = false,
    decision_reason = 'qualified_during_campaign'
WHERE contact_id IN (
  SELECT contact_id
  FROM corev4_lead_state
  WHERE total_score >= 70
)
AND executed = false
AND should_send = true;
```

---

## 🎯 RECOMENDAÇÃO IMEDIATA

**Você precisa me dizer qual comportamento DESEJA:**

### Cenário A: Lead Responde Durante Followup

**Opção 1 - CANCELAR TUDO (recomendado):**
- Lead respondeu = voltou para fluxo normal
- Cancela todos os steps pendentes
- Frank (One Flow) assume a conversa

**Opção 2 - CONTINUAR FOLLOWUP:**
- Apenas steps com `scheduled_at < last_interaction_at` são cancelados
- Steps futuros continuam agendados
- Útil se quiser "lembrete" mesmo que lead tenha respondido

### Cenário B: Lead Atinge Score ≥70

**Opção 1 - CANCELAR FOLLOWUP (recomendado):**
- Lead qualificado = não precisa mais de followup
- Marcar steps como `should_send=false`

**Opção 2 - CONTINUAR ATÉ AGENDAR:**
- Followup continua até lead agendar reunião
- Mais agressivo

---

**Me diga qual comportamento você quer e eu implemento a solução COMPLETA.**

Enquanto isso, minha correção atual **resolve o problema dos duplicados**, mas deixa essas lacunas que você identificou corretamente.
