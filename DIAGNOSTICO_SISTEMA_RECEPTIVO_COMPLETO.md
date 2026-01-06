# DIAGNÓSTICO COMPLETO - SISTEMA RECEPTIVO COREADAPT

**Data:** 2026-01-06
**Status:** SISTEMA CRÍTICO - NÃO FUNCIONAL

---

## RESUMO EXECUTIVO

| Fluxo | Erros Críticos | Erros Médios | Status |
|-------|---------------|--------------|--------|
| **Main Router Flow v4** | 4 | 5 | PARCIALMENTE FUNCIONAL |
| **One Flow v4.5 AUTONOMOUS** | 3 | 5 | QUEBRADO |
| **Availability Flow v4.3** | 1 | 1 | NÃO FUNCIONA |
| **Booking Flow v4.2** | 3 | 2 | NÃO FUNCIONA |
| **Sync Flow v4** | 5 | 5 | NÃO FUNCIONA |
| **TOTAL** | **16** | **18** | **SISTEMA INOPERANTE** |

---

## ERROS CRÍTICOS POR FLUXO

### 1. MAIN ROUTER FLOW v4

#### CRÍTICO #1: Node "Batch: Should Wait?" DESCONECTADO
- **Problema:** Node existe mas não conecta a lugar nenhum
- **Impacto:** Fluxo de batch collection completamente quebrado
- **Localização:** Recebe de "Batch: Merge Actions" mas não tem saída

#### CRÍTICO #2: Campo `origin_source` NÃO EXISTE
- **Problema:** 3 nodes referenciam `$('Enrich: Message Context').item.json.origin_source`
- **Nodes afetados:** Prepare: Create Contact, Prepare: Reactivate, Prepare: Process Command
- **Impacto:** Workflows filhos recebem `origin_source: undefined`

#### CRÍTICO #3: Lógica Hardcoded em "Batch: Should Wait?"
- **Problema:** Condição `{{ true }}` - sempre verdadeira
- **Impacto:** Branch FALSE nunca executa

#### CRÍTICO #4: Merge Node Mal Configurado
- **Problema:** `numberInputs: 4` mas só recebe 3 conexões
- **Impacto:** Pode ficar aguardando 4ª entrada indefinidamente

---

### 2. ONE FLOW v4.5 (AUTONOMOUS SCHEDULING)

#### CRÍTICO #1: `Call: Booking Flow` - workflowId VAZIO
```json
"workflowId": {
  "value": "",  // ← VAZIO!
  "cachedResultName": "CoreAdapt Booking Flow | v4.1"
}
```
- **Impacto:** NUNCA executa booking quando usuário confirma slot

#### CRÍTICO #2: `Call: Availability Flow` - workflowId VAZIO
```json
"workflowId": {
  "value": "",  // ← VAZIO!
  "cachedResultName": "CoreAdapt Availability Flow | v4.3"
}
```
- **Impacto:** NUNCA busca slots quando FRANK detecta intenção de agendamento

#### CRÍTICO #3: `Call: Availability Filtered` - workflowId VAZIO
```json
"workflowId": {
  "value": "",  // ← VAZIO!
  "cachedResultName": "CoreAdapt Availability Flow | v4.3"
}
```
- **Impacto:** NUNCA processa preferências de slot (ex: "tem quinta à tarde?")

---

### 3. AVAILABILITY FLOW v4.3

#### CRÍTICO #1: Credencial Google Calendar NÃO CONFIGURADA
```json
"credentials": {
  "googleCalendarOAuth2Api": {
    "id": "CONFIGURE_ME",  // ← NÃO CONFIGURADA!
    "name": "Google Calendar Pasteur"
  }
}
```
- **Impacto:** Node FALHA 100% ao tentar buscar disponibilidade

#### CRÍTICO #2: Subworkflow Trigger DESCONECTADO
- **Problema:** Node existe mas não conecta ao fluxo
- **Status:** JÁ CORRIGIDO no v4.4_FIXED

---

### 4. BOOKING FLOW v4.2

#### CRÍTICO #1: Credencial Google Calendar NÃO CONFIGURADA
```json
"credentials": {
  "googleCalendarOAuth2Api": {
    "id": "CONFIGURE_ME",  // ← NÃO CONFIGURADA!
  }
}
```
- **Impacto:** Evento no Google Calendar NUNCA é criado

#### CRÍTICO #2: Subworkflow Trigger DESCONECTADO
- **Problema:** Node `booking-subworkflow-trigger` não conecta a nada
- **Impacto:** Quando chamado como subworkflow, dados não chegam

#### CRÍTICO #3: Type Mismatch em "Check: No Conflicts"
```json
"operator": {
  "type": "string",  // ← ERRO: deveria ser "number"
  "operation": "equals"
}
```
- **Problema:** Compara COUNT(*) (número) com "0" (string)
- **Impacto:** Comparação pode falhar

---

### 5. SYNC FLOW v4

#### CRÍTICO #1: Modelo OpenAI INVÁLIDO
```json
"model": "gpt-4.1-mini-2025-04-14"  // ← NÃO EXISTE!
```
- **Impacto:** Toda execução de AI falha com erro 404

#### CRÍTICO #2: Fluxo de Erro DESCONECTADO
- **Problema:** `Format: Error Response` não conecta a nenhuma saída
- **Impacto:** Quando há erro, workflow fica suspenso

#### CRÍTICO #3: Conflito de Categorias de Pain
- **AI Prompt:** Define ~30 categorias (response_delay, no_followup, etc.)
- **Parse:** Valida apenas 9 categorias diferentes
- **Impacto:** Parse SEMPRE rejeita como inválido

#### CRÍTICO #4: Mismatch session_id vs contact_id
- **Input:** Recebe `contact_id`
- **Query:** Busca por `session_id`
- **Impacto:** Query retorna 0 mensagens

#### CRÍTICO #5: Referência a Campo Inexistente
- **Problema:** `$('Insert: ANUM History Record').first().json.id` pode não existir
- **Impacto:** UPDATE com valor null, corrompendo dados

---

## ERROS MÉDIOS (RESUMO)

### Main Router
1. Referência frágil a estrutura profunda (`body.data.message.base64`)
2. Code node com lógica frágil em "Prepare: Frank Chat"
3. Inconsistência de naming (message_id vs messageId)
4. PostgreSQL JOIN problemático
5. Supabase query pode retornar vazio

### One Flow
1. Route: Should Fetch Slots - branch FALSE vai para lugar errado
2. Parse: Slot Selection pode falhar por referência ausente
3. Detect: Scheduling Intent remove horários legítimos
4. Estados de conversa não sincronizados
5. Inject: Dynamic Slots tem fallback incompleto

### Availability Flow
1. CROSS JOIN perigoso na query

### Booking Flow
1. Referência potencial fora de contexto
2. WhatsApp do Francisco hardcoded (5585999855443)

### Sync Flow
1. Espaço em branco na coluna
2. Deltas calculados sem validar NULL
3. Temperatura 0.7 muito alta
4. Validação incompleta de contact_id
5. Falta tratamento de NULL nos deltas

---

## NODES DESCONECTADOS (TOTAL: 6)

| Fluxo | Node | Status |
|-------|------|--------|
| Main Router | Batch: Should Wait? | DESCONECTADO |
| One Flow | Branch FALSE de Route: Should Fetch Slots | MAL CONECTADO |
| Availability Flow | Subworkflow Trigger | CORRIGIDO em v4.4 |
| Booking Flow | Subworkflow Trigger | DESCONECTADO |
| Sync Flow | Format: Error Response | DESCONECTADO |

---

## CREDENCIAIS - STATUS

| Credencial | Onde é usada | Status |
|-----------|--------------|--------|
| Postgres Core (HCvX4Ypw2MiRDsdm) | 20+ nodes | ✅ OK |
| OpenAI FRANK | AI Agent, TTS | ✅ OK |
| Google Calendar OAuth2 | Availability, Booking | ❌ NÃO CONFIGURADA |
| Evolution API | Envio WhatsApp | ✅ OK |
| Supabase | Contatos, Chat | ✅ OK |

---

## FUNÇÕES SQL CRÍTICAS

| Função | Usada em | Status |
|--------|----------|--------|
| `update_conversation_state` | One Flow, Availability | ⚠️ VERIFICAR |
| `reset_conversation_state` | One Flow, Booking | ⚠️ VERIFICAR |
| `cancel_previous_slot_offers` | Availability | ⚠️ VERIFICAR |
| `get_or_create_session_uuid` | One Flow | ⚠️ VERIFICAR |

---

## PLANO DE CORREÇÃO (PRIORIDADE)

### FASE 1 - CRÍTICO (Fazer AGORA)

1. **Configurar credencial Google Calendar**
   - Criar OAuth2 no n8n
   - Autorizar com conta do Pasteur
   - Atualizar ID em Availability e Booking Flow

2. **Corrigir workflowIds vazios no One Flow**
   - Call: Availability Flow
   - Call: Availability Filtered
   - Call: Booking Flow

3. **Conectar Subworkflow Trigger no Booking Flow**

4. **Corrigir modelo OpenAI no Sync Flow**
   - Trocar "gpt-4.1-mini-2025-04-14" para "gpt-4o-mini"

5. **Conectar Format: Error Response no Sync Flow**

### FASE 2 - IMPORTANTE (Esta semana)

6. Corrigir type mismatch no Booking Flow
7. Corrigir conflito de categorias no Sync Flow
8. Corrigir mismatch session_id no Sync Flow
9. Conectar "Batch: Should Wait?" no Main Router
10. Adicionar campo `origin_source` no Main Router

### FASE 3 - MELHORIAS (Próxima semana)

11. Refatorar Parse: Slot Selection
12. Revisar regex em Detect: Scheduling Intent
13. Adicionar tratamento de NULL nos deltas
14. Melhorar logging em todos os fluxos
15. Documentar fluxos

---

## ARQUIVOS CORRIGIDOS DISPONÍVEIS

| Arquivo | Status | Correções |
|---------|--------|-----------|
| CoreAdapt One Flow _ v4.5.1_FIXED.json | ✅ CRIADO | Detect + Inject |
| CoreAdapt Availability Flow _ v4.4_FIXED.json | ✅ CRIADO | Subworkflow Trigger |
| CoreAdapt Booking Flow _ v4.3_FIXED.json | ❌ PENDENTE | - |
| CoreAdapt Sync Flow _ v4.1_FIXED.json | ❌ PENDENTE | - |
| CoreAdapt Main Router Flow _ v4.1_FIXED.json | ❌ PENDENTE | - |

---

## CONCLUSÃO

O sistema receptivo do CoreAdapt está **INOPERANTE** devido a múltiplos erros críticos em cascata:

1. **FRANK promete agendar** → mas workflowId do Availability está vazio → **NÃO BUSCA SLOTS**
2. **Se buscasse slots** → credencial Google Calendar não configurada → **FALHA**
3. **Se configurasse GCal** → Subworkflow Trigger desconectado → **DADOS NÃO CHEGAM**
4. **Se chegassem dados** → Booking Flow também com problemas → **EVENTO NÃO É CRIADO**

**O sistema precisa de correção completa antes de voltar a funcionar.**

---

*Relatório gerado automaticamente - 2026-01-06*
