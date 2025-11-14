# Message Batching Implementation

## 🎯 Objetivo

Resolver o problema de múltiplas respostas da IA quando o usuário envia mensagens em rajada:

**Antes:**
```
Usuário: oi        (10:00:00)
IA: Olá! Como posso ajudar?

Usuário: tudo      (10:00:02)
IA: Tudo bem! O que você precisa?

Usuário: bem?      (10:00:03)
IA: Ótimo! Em que posso ajudar?
```

**Depois:**
```
Usuário: oi        (10:00:00)
Usuário: tudo      (10:00:02)
Usuário: bem?      (10:00:03)
[3 segundos de silêncio]
IA: Olá! Tudo bem? Como posso ajudar?
```

## 🏗️ Arquitetura

### Fluxo de Mensagens

```
┌─────────────────────────────────────────────────────────────┐
│ MAIN ROUTER FLOW                                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Webhook → Normalize → [BATCHING LOGIC] → Audio → ...       │
│                                                             │
│ [BATCHING LOGIC]:                                           │
│   1. Check Active Batch (Postgres)                          │
│   2. Batch Exists? (IF)                                     │
│      ├─ TRUE → Add Message → RETURN EMPTY                   │
│      └─ FALSE → Get Contact ID                              │
│                  ├─ TRUE → Create Batch → RETURN EMPTY      │
│                  └─ FALSE → Pass Through                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ BATCH PROCESSOR FLOW (Cron: every 2 seconds)               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Cron → Fetch Expired Batches → Combine Messages →          │
│        Mark Processed → Execute One Flow                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Nodes Implementados

#### Main Router Flow (10 nodes nativos)

1. **Batch: Check Active** (Postgres)
   - Busca batch ativo para o contato
   - Query: `SELECT * FROM corev4_chats WHERE batch_collecting = TRUE AND batch_expires_at > NOW()`

2. **Batch: Exists?** (IF)
   - Verifica se encontrou batch ativo

3. **Batch: Add Message** (Postgres)
   - Adiciona mensagem ao array `batch_messages`
   - Reseta timer: `batch_expires_at = NOW() + 3 seconds`
   - Retorna VAZIO (não processa ainda)

4. **Batch: Get Contact ID** (Postgres)
   - Busca `contact_id` pelo `whatsapp_id`

5. **Batch: Contact Exists?** (IF)
   - Verifica se contato existe

6. **Batch: Create New** (Postgres)
   - Cria novo batch com primeira mensagem
   - `batch_collecting = TRUE`
   - `batch_expires_at = NOW() + 3 seconds`
   - Retorna VAZIO (aguarda mais mensagens)

7. **Batch: Merge Actions** (Merge)
   - Une caminhos "Add" e "Create"

8. **Batch: Should Wait?** (IF)
   - Sempre retorna TRUE = aguarda
   - Não passa nada adiante

9. **Batch: Pass Non-Batchable** (Code)
   - Para novos contatos (não tem contact_id ainda)
   - Deixa passar direto

10. **Batch: Output** (Merge)
    - Merge final antes de Audio Route

#### Batch Processor Flow (7 nodes nativos)

1. **Cron Trigger** - Every 2 seconds
2. **Fetch Expired Batches** (Postgres) - `WHERE batch_expires_at < NOW()`
3. **Has Results?** (IF) - Verifica se há batches
4. **Combine Messages** (Code) - Junta mensagens em texto único
5. **Mark Processed** (Postgres) - `batch_collecting = FALSE`
6. **Execute One Flow** - Chama CoreAdapt One Flow com mensagem combinada
7. **No Batches** (NoOp) - Caminho vazio quando não há batches

## 📦 Banco de Dados

### Colunas Necessárias (migration já criada)

```sql
ALTER TABLE corev4_chats ADD COLUMN IF NOT EXISTS batch_collecting BOOLEAN DEFAULT FALSE;
ALTER TABLE corev4_chats ADD COLUMN IF NOT EXISTS batch_expires_at TIMESTAMPTZ;
ALTER TABLE corev4_chats ADD COLUMN IF NOT EXISTS batch_messages JSONB[];
```

### Estrutura do batch_messages

```json
[
  {
    "message_id": "ABC123",
    "whatsapp_id": "5511999999999@s.whatsapp.net",
    "message_content": "oi",
    "message_type": "text",
    "media_type": null,
    "has_media": false,
    "media_url": null,
    "timestamp": "2025-11-14T10:00:00.000Z"
  },
  {
    "message_id": "DEF456",
    "whatsapp_id": "5511999999999@s.whatsapp.net",
    "message_content": "tudo",
    "message_type": "text",
    "media_type": null,
    "has_media": false,
    "media_url": null,
    "timestamp": "2025-11-14T10:00:02.000Z"
  }
]
```

## 🚀 Configuração

### 1. Importar Workflows

Importe AMBOS os workflows no n8n:

```bash
# No n8n UI:
# Settings > Import from File

1. CoreAdapt Main Router Flow _ v4.json
2. Batch Processor Flow _ v4_NATIVE.json
```

### 2. Ativar Batch Processor

O Batch Processor tem um cron que roda a cada 2 segundos:

```
Settings > Active: TRUE
```

### 3. Verificar Credenciais

Ambos os workflows usam:
- **Postgres Core** (ID: HCvX4Ypw2MiRDsdm)

Certifique-se de que a credencial existe.

## 🧪 Como Testar

### Teste 1: Mensagens Rápidas (Batch Esperado)

1. Envie 3 mensagens rápidas (< 3 segundos entre cada):
   ```
   oi
   tudo
   bem?
   ```

2. **Resultado Esperado:**
   - Main Router: 3 execuções (todas retornam VAZIO)
   - Batch Processor: 1 execução após 3 segundos
   - One Flow: 1 execução com mensagem combinada "oi\ntudo\nbem?"
   - WhatsApp: 1 resposta da IA

3. **Logs Esperados:**

   Main Router (primeira mensagem):
   ```
   🆕 Batch 123: Started for contact 456 (3s)
   ```

   Main Router (segunda mensagem):
   ```
   ✅ Batch 123: Added message 2/3s
   ```

   Main Router (terceira mensagem):
   ```
   ✅ Batch 123: Added message 3/3s
   ```

   Batch Processor (após 3s):
   ```
   📦 Processing batch 123: 3 messages
   ```

### Teste 2: Mensagens Lentas (Sem Batch)

1. Envie mensagens com > 3 segundos de intervalo:
   ```
   oi
   [aguarda 4 segundos]
   tudo
   [aguarda 4 segundos]
   bem?
   ```

2. **Resultado Esperado:**
   - Main Router: 3 execuções (todas retornam VAZIO)
   - Batch Processor: 3 execuções (uma para cada batch)
   - One Flow: 3 execuções separadas
   - WhatsApp: 3 respostas da IA

### Teste 3: Novo Contato (Bypass do Batch)

1. Envie mensagem de número novo (não cadastrado):
   ```
   oi
   ```

2. **Resultado Esperado:**
   - Main Router: Passa direto (não tenta batch)
   - Genesis Flow: Cria contato
   - One Flow: Processa normalmente
   - WhatsApp: 1 resposta

## 🔍 Diagnóstico

### SQL: Verificar Estado dos Batches

```sql
-- Ver batches ativos
SELECT
  id,
  contact_id,
  batch_collecting,
  batch_expires_at,
  EXTRACT(EPOCH FROM (batch_expires_at - NOW())) as seconds_remaining,
  array_length(batch_messages, 1) as num_messages
FROM corev4_chats
WHERE batch_collecting = TRUE;

-- Ver últimas mensagens em batch
SELECT
  c.id,
  ct.whatsapp,
  c.batch_messages
FROM corev4_chats c
JOIN corev4_contacts ct ON c.contact_id = ct.id
WHERE c.batch_messages IS NOT NULL
ORDER BY c.updated_at DESC
LIMIT 5;
```

### Script: Diagnóstico Completo

```bash
psql -h localhost -U postgres -d core -f scripts/diagnostico_batching.sql
```

## 🐛 Troubleshooting

### Problema: Múltiplas respostas ainda acontecem

**Causa:** Batch Processor não está ativo

**Solução:**
```
n8n UI > Batch Processor Flow > Active: TRUE
```

### Problema: Nenhuma resposta após mensagens

**Causa:** Batch criado mas processor não rodou

**Solução:**
1. Verificar se cron está ativo (logs devem mostrar execuções a cada 2s)
2. Verificar se `batch_expires_at` é menor que NOW():
   ```sql
   SELECT NOW(), batch_expires_at
   FROM corev4_chats
   WHERE batch_collecting = TRUE;
   ```

### Problema: Erro "relation corev4_chats does not have column batch_messages"

**Causa:** Migration não foi executada

**Solução:**
```bash
psql -h localhost -U postgres -d core -f migrations/add_batch_messages_column.sql
```

### Problema: Batch Processor executa mas não combina mensagens

**Causa:** Query não encontra batches expirados

**Solução:**
Verificar query no node "Fetch: Expired Batches":
```sql
SELECT
  id as chat_id,
  contact_id,
  batch_messages
FROM corev4_chats
WHERE batch_collecting = TRUE
  AND batch_expires_at < NOW()
LIMIT 10;
```

## 📊 Configurações

### Timeout de Batch (Padrão: 3 segundos)

Para alterar o tempo de espera:

**Main Router Flow:**
- Nodes "Batch: Add Message" e "Batch: Create New"
- Alterar: `INTERVAL '3 seconds'` → `INTERVAL '5 seconds'`

**Batch Processor Flow:**
- Não precisa alterar (sempre processa batches expirados)

### Frequência do Processor (Padrão: 2 segundos)

Para alterar frequência:

**Batch Processor Flow:**
- Node "Cron Trigger"
- Alterar: `Every 2 seconds` → `Every 5 seconds`

**Recomendação:** Manter < timeout para garantir processamento rápido

## 🎓 Diferença da Implementação Anterior

### ❌ Implementação Quebrada (antes)

```javascript
// Code node com $executeQuery (NÃO EXISTE!)
const batchResult = await $executeQuery('postgres', query, params);
```

**Erro:** `$executeQuery is not defined`

### ✅ Implementação Correta (agora)

```
Postgres Node → IF Node → Postgres Node → ...
```

**Vantagem:** Usa nodes nativos do n8n, sem APIs não documentadas

## 📝 Arquivos Relacionados

```
CoreAdapt/
├── Batch Processor Flow _ v4_NATIVE.json           # Workflow processor
├── CoreAdapt Main Router Flow _ v4.json            # Workflow principal (modificado)
├── migrations/
│   └── add_batch_messages_column.sql               # Migration do DB
├── scripts/
│   ├── implement_batching_native_nodes.py          # Gerador de nodes
│   ├── integrate_batching_to_main_router.py        # Script de integração
│   └── diagnostico_batching.sql                    # Diagnóstico SQL
└── docs/
    └── BATCHING_IMPLEMENTATION.md                  # Este documento
```

## 🎯 Próximos Passos

1. ✅ Importar workflows no n8n
2. ✅ Ativar Batch Processor Flow
3. ✅ Testar com 3 mensagens rápidas
4. ✅ Verificar logs
5. ✅ Confirmar 1 resposta combinada

---

**Desenvolvido em:** 2025-11-14
**Commit:** `005c781`
**Branch:** `claude/coreadadapt-flows-schema-analysis-01VJvTi6xKNKSWUxV2JCdjkj`
