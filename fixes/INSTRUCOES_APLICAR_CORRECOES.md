# Instruções para Aplicar Correções - One Flow v4.5.1

**Data:** 2026-01-06
**Problema:** FRANK promete ver agenda mas não entrega horários
**Causa:** `should_fetch_slots` era false quando ANUM < 55

---

## Resumo do Problema

Quando FRANK dizia "deixa eu ver a agenda...", o sistema verificava:
```
should_fetch_slots = hasIntent AND (can_offer_meeting OR frankInventedSlots)
```

Como `can_offer_meeting` era false (ANUM 41.25 < 55) e FRANK não inventou slots,
`should_fetch_slots` ficava false e nenhum horário era buscado.

---

## Correções Necessárias

### Correção 1: Node "Detect: Scheduling Intent"

1. Abra o **n8n**
2. Vá em **CoreAdapt One Flow | v4.5 (Autonomous Scheduling)**
3. Encontre o node **"Detect: Scheduling Intent"** (posição aproximada: X=320, Y=320)
4. Clique no node para editar
5. **SUBSTITUA** todo o código JavaScript pelo conteúdo do arquivo:
   `/home/user/CoreAdapt/fixes/FIX_DETECT_SCHEDULING_INTENT.js`
6. Salve o node

**Mudança principal:**
```javascript
// ANTES (bugado):
const shouldFetchSlots = hasIntent && (canOffer.can_offer_meeting || frankInventedSlots);

// DEPOIS (corrigido):
const frankPromisedToCheck = /verificando|deixa eu ver|vou ver|vou checar|estou verificando|vou verificar/i.test(aiOutput);
const shouldFetchSlots = hasIntent && (canOffer.can_offer_meeting || frankInventedSlots || frankPromisedToCheck);
```

---

### Correção 2: Node "Inject: Dynamic Slots"

1. No mesmo workflow, encontre o node **"Inject: Dynamic Slots"** (posição aproximada: X=992, Y=224)
2. Clique no node para editar
3. **SUBSTITUA** todo o código JavaScript pelo conteúdo do arquivo:
   `/home/user/CoreAdapt/fixes/FIX_INJECT_DYNAMIC_SLOTS.js`
4. Salve o node

**Mudança principal:** Agora trata o cenário onde FRANK prometeu ver agenda mas ANUM < 55,
gerando uma pergunta de qualificação ao invés de travar.

---

## Comportamento Após Correção

### Cenário 1: ANUM >= 55 + Slots Disponíveis
- ✅ Mostra os 3 horários disponíveis

### Cenário 2: ANUM >= 55 + Sem Slots
- ✅ Mostra mensagem de fallback com WhatsApp do Pasteur

### Cenário 3: ANUM < 55 + FRANK Prometeu Ver Agenda
- ✅ Faz pergunta de qualificação adicional (autoridade, dor, timing)
- ✅ Não trava o fluxo

### Cenário 4: FRANK Inventou Slots
- ✅ Remove slots inventados
- ✅ Mostra fallback com WhatsApp

---

## Teste Após Aplicar

1. Ative o workflow se necessário
2. Envie uma mensagem de teste simulando um lead
3. Verifique se quando FRANK diz "deixa eu ver a agenda":
   - Se ANUM >= 55: Mostra horários OU fallback
   - Se ANUM < 55: Faz pergunta de qualificação

---

## Arquivos de Correção

- `FIX_DETECT_SCHEDULING_INTENT.js` - Código corrigido do node Detect
- `FIX_INJECT_DYNAMIC_SLOTS.js` - Código corrigido do node Inject
- `INSTRUCOES_APLICAR_CORRECOES.md` - Este arquivo

---

**Versão:** 4.5.1
**Autor:** CoreAdapt Team
