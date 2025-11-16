# ✅ SENTINEL FIX: Followups Duplicados - CORRIGIDO

**Data:** 16 de Novembro de 2025
**Status:** ✅ Correção Aplicada - Aguardando Validação

---

## 🎯 PROBLEMA IDENTIFICADO

Você relatou que o Sentinel estava enviando múltiplos followups simultaneamente quando:

1. Um followup de **1h** vence fora do horário permitido (ex: 22h)
2. É reagendado para o próximo horário (ex: 9h)
3. Durante a espera, o followup de **4h** TAMBÉM vence
4. Quando chega 9h, **ambos são enviados juntos** ❌

**Comportamento Esperado:** Enviar apenas o followup de 1h, depois aguardar para enviar o de 4h.

---

## ✅ SOLUÇÃO APLICADA

### Query ANTES (com bug):

```sql
SELECT ...
FROM corev4_followup_executions e
WHERE e.executed = false
  AND e.should_send = true
  AND e.scheduled_at <= NOW()
ORDER BY e.scheduled_at ASC
```

**Problema:** Seleciona TODOS os steps vencidos de TODAS as campanhas.

### Query DEPOIS (corrigida):

```sql
SELECT DISTINCT ON (e.campaign_id)  -- ← ADICIONADO
  ...
FROM corev4_followup_executions e
WHERE e.executed = false
  AND e.should_send = true
  AND e.scheduled_at <= NOW()
ORDER BY e.campaign_id, e.step ASC, e.scheduled_at ASC  -- ← MODIFICADO
```

**Solução:** `DISTINCT ON (campaign_id)` garante que apenas **1 step por campanha** seja retornado. O `ORDER BY step ASC` garante que seja sempre o **menor step** (primeiro não executado).

---

## 📂 ARQUIVOS CRIADOS/MODIFICADOS

### ✅ Corrigidos:
- `CoreAdapt Sentinel Flow _ v4.json` (query do node "Fetch: Pending Followups" atualizada)

### 📋 Backups:
- `CoreAdapt Sentinel Flow _ v4_BEFORE_DISTINCT_FIX.json` (backup antes da correção)

### 📊 Diagnóstico:
- `queries/DIAGNOSTICO_FOLLOWUP_DUPLICADOS.sql` (queries completas de análise)
- `queries/EXECUTE_DIAGNOSTICO_FOLLOWUP.sql` (queries simplificadas para você executar)

### 📖 Documentação:
- `docs/SENTINEL_FOLLOWUP_DUPLICADOS_FIX.md` (análise técnica completa)
- `scripts/fix_sentinel_followup_duplicados.py` (script de correção aplicado)

---

## 🔍 VALIDAÇÃO NECESSÁRIA

### Passo 1: Execute Queries de Diagnóstico

Abra o arquivo:
```
queries/EXECUTE_DIAGNOSTICO_FOLLOWUP.sql
```

Execute cada query no Supabase SQL Editor e me envie os resultados:

**QUERY 1:** Verificar se há campanhas com múltiplos steps pendentes
**QUERY 2:** Comparar quantos followups seriam enviados (ANTES vs DEPOIS)
**QUERY 3:** Ver exemplo de campanha problemática
**QUERY 4:** Simular o que a query corrigida retorna
**QUERY 5:** Validar estrutura da tabela

### Passo 2: Importar Workflow Atualizado

1. Abra n8n
2. Vá em Workflows → "CoreAdapt Sentinel Flow | v4"
3. Importe o arquivo atualizado: `CoreAdapt Sentinel Flow _ v4.json`
4. Ative o workflow

### Passo 3: Teste Controlado (Opcional)

Se quiser testar antes de colocar em produção:

1. Crie uma campanha de followup com steps rápidos:
   - Step 1: 1 minuto
   - Step 2: 2 minutos
2. Configure horário de envio restrito (ex: apenas 14h-15h)
3. Inicie a campanha às 16h (fora do horário)
4. Aguarde ambos os steps vencerem
5. Quando chegar 14h do dia seguinte, verifique que:
   - ✅ Apenas Step 1 é enviado
   - ✅ Step 2 NÃO é enviado junto
   - ✅ Step 2 é enviado depois (após Step 1 ser marcado como executado)

---

## 🎯 COMPORTAMENTO ESPERADO APÓS CORREÇÃO

### Cenário Típico:

```
10h00 - Lead para de responder
11h00 - Step 1 deveria ser enviado (1h depois)
       - Fora do horário → Reagendado para 9h dia seguinte

Durante a noite:
15h00 - Step 2 também vence (4h depois)
       - Também pendente, aguardando horário

Dia seguinte:
09h00 - Cron do Sentinel executa
       - ✅ Query CORRIGIDA seleciona apenas Step 1 (menor step pendente)
       - ✅ Envia Step 1
       - ✅ Marca Step 1 como executed = true

09h05 - Próxima execução do cron
       - ✅ Query seleciona Step 2 (agora é o menor pendente)
       - ✅ Envia Step 2
```

**Resultado:** Steps enviados **progressivamente**, não simultaneamente.

---

## ⚠️ IMPORTANTE: Dados do Banco

Para confirmar que a correção está funcionando corretamente, **preciso que você execute as queries de diagnóstico** no Supabase e me envie os resultados.

Sem os dados do banco, não consigo:
- Confirmar se há campanhas com o problema ativo agora
- Verificar se a query corrigida está funcionando
- Validar que o schema está correto

---

## 📋 CHECKLIST

- [x] Problema identificado e documentado
- [x] Solução técnica desenvolvida
- [x] Query corrigida aplicada no workflow
- [x] Backup criado antes da modificação
- [x] JSON validado (syntax check OK)
- [x] Documentação técnica completa criada
- [x] Queries de diagnóstico prontas
- [ ] **Validação no banco (AGUARDANDO VOCÊ)**
- [ ] Importação do workflow no n8n
- [ ] Teste em produção
- [ ] Monitoramento 24h

---

## 🚀 PRÓXIMO PASSO

**Por favor, execute as queries do arquivo:**

```
queries/EXECUTE_DIAGNOSTICO_FOLLOWUP.sql
```

**E me envie os resultados aqui.** Vou analisar e confirmar se:
1. A correção está funcionando corretamente
2. Há campanhas com o problema ativo no momento
3. Precisamos fazer algum ajuste adicional

---

**Após validarmos os dados do banco, você pode importar o workflow atualizado no n8n com segurança.**
