# 🔍 Análise Completa: Tabelas de Chat no CoreAdapt v4

> **Data:** 2025-11-10
> **Objetivo:** Entender função de cada tabela de chat e decidir onde implementar batch collection

---

## 📊 Resumo Executivo

| Tabela | Status | Usos | Propósito |
|--------|--------|------|-----------|
| `corev4_chat_history` | ✅ **ATIVA** | 8 ocorrências | Histórico permanente de mensagens |
| `corev4_n8n_chat_histories` | ✅ **ATIVA** | 5 ocorrências | Memory do n8n (Langchain) |
| `corev4_chats` | ❌ **MORTA** | 0 ocorrências | Session management (não implementado) |

---

## 1. `corev4_chat_history` (PRINCIPAL)

### 1.1. Schema Completo

```sql
CREATE TABLE corev4_chat_history (
  id BIGSERIAL PRIMARY KEY,
  session_id UUID NOT NULL,
  contact_id BIGINT NOT NULL,
  company_id INTEGER NOT NULL,

  -- Mensagem
  role VARCHAR,  -- 'user', 'assistant', 'system'
  message TEXT,
  message_type VARCHAR,  -- 'text', 'audio', 'image', etc

  -- Mídia
  has_media BOOLEAN DEFAULT FALSE,
  media_url TEXT,
  media_mime_type TEXT,

  -- Custos e tokens
  tokens_used INTEGER,
  cost_usd NUMERIC,
  model_used VARCHAR,

  -- Timestamps
  message_timestamp TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  FOREIGN KEY (contact_id) REFERENCES corev4_contacts(id) ON DELETE CASCADE,
  FOREIGN KEY (session_id) REFERENCES corev4_n8n_chat_histories(session_id)
);

-- Índices
CREATE INDEX idx_chat_history_contact ON corev4_chat_history(contact_id);
CREATE INDEX idx_chat_history_session ON corev4_chat_history(session_id);
CREATE INDEX idx_chat_history_timestamp ON corev4_chat_history(message_timestamp DESC);
```

### 1.2. Onde é usada?

**Commands Flow:**
```sql
-- Limpar histórico (#limpar command)
DELETE FROM corev4_chat_history WHERE contact_id = {{ contact_id }};
```

**Genesis Flow:**
```sql
-- Salvar primeira mensagem de novo contato
INSERT INTO corev4_chat_history (
  session_id, contact_id, role, message, message_type
) VALUES (...)
```

**One Flow (4 usos):**
```sql
-- 1. Salvar mensagem do lead
INSERT INTO corev4_chat_history (role = 'user', ...)

-- 2. Salvar resposta da IA
INSERT INTO corev4_chat_history (role = 'assistant', ...)

-- 3. Buscar histórico para contexto
SELECT message FROM corev4_chat_history
WHERE contact_id = X
ORDER BY message_timestamp DESC
LIMIT 20
```

**Scheduler Flow:**
```sql
-- Buscar histórico para gerar resumo da reunião
SELECT role, message, message_timestamp
FROM corev4_chat_history
WHERE contact_id = X AND company_id = Y
ORDER BY message_timestamp DESC
LIMIT 10
```

### 1.3. Função

**Histórico permanente e auditável** de todas as mensagens trocadas:
- ✅ Armazena TODAS as mensagens (lead + IA)
- ✅ Rastreia custos (tokens, $)
- ✅ Suporta mídia (áudio, imagem)
- ✅ Usado para gerar relatórios e resumos
- ✅ **NUNCA é apagada** (exceto comando #limpar)

---

## 2. `corev4_n8n_chat_histories` (LANGCHAIN MEMORY)

### 2.1. Schema Completo

```sql
CREATE TABLE corev4_n8n_chat_histories (
  id BIGSERIAL PRIMARY KEY,
  session_id TEXT NOT NULL,  -- UUID como TEXT
  contact_id BIGINT,
  company_id INTEGER,

  -- Mensagem em formato JSON
  message JSONB,  -- {"type": "human|ai", "content": "texto"}

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_n8n_chat_session ON corev4_n8n_chat_histories(session_id);
CREATE INDEX idx_n8n_chat_contact ON corev4_n8n_chat_histories(contact_id);
```

### 2.2. Onde é usada?

**Commands Flow:**
```sql
-- Limpar memory do n8n (#limpar command)
DELETE FROM corev4_n8n_chat_histories WHERE contact_id = {{ contact_id }};
```

**One Flow:**
```sql
-- n8n AI Agent usa automaticamente
-- Via node "AI Agent" com "Chat Memory (Postgres)"
```

**Sentinel Flow:**
```sql
-- Buscar contexto para follow-up
SELECT
  message->>'type' AS role,
  message->>'content' AS message
FROM corev4_n8n_chat_histories
WHERE session_id = X
ORDER BY created_at DESC
LIMIT 30
```

**Sync Flow:**
```sql
-- Buscar mensagens para análise ANUM
SELECT
  message->>'type' as role,
  message->>'content' as message_content
FROM corev4_n8n_chat_histories
WHERE session_id = X
ORDER BY id DESC
LIMIT 20
```

### 2.3. Função

**Memory temporária do AI Agent (Langchain)**:
- ✅ Armazena contexto da conversa em **formato n8n**
- ✅ Usado pelo AI Agent para **lembrar** da conversa
- ✅ Formato JSONB: `{"type": "human", "content": "texto"}`
- ✅ Limitado (últimas 20-30 mensagens)
- ⚠️ Pode ser apagado para "resetar" conversa

---

## 3. `corev4_chats` (MORTA - NÃO USADA)

### 3.1. Schema Completo

```sql
CREATE TABLE corev4_chats (
  id BIGSERIAL PRIMARY KEY,
  contact_id BIGINT NOT NULL,
  company_id INTEGER NOT NULL,

  -- Session management
  conversation_open BOOLEAN DEFAULT TRUE,
  agent_alias TEXT,
  closed_reason TEXT,

  -- Timestamps
  last_message_ts BIGINT,  -- Unix timestamp
  last_lead_message_ts BIGINT,
  last_agent_message_ts BIGINT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Batch collection (JÁ EXISTE!)
  batch_collecting BOOLEAN DEFAULT FALSE,
  batch_expires_at TIMESTAMPTZ,

  CONSTRAINT unique_contact_chat UNIQUE (contact_id, company_id)
);

-- Índices
CREATE INDEX idx_chats_batch ON corev4_chats(batch_collecting)
  WHERE batch_collecting = TRUE;
CREATE INDEX idx_chats_conversation_open ON corev4_chats(conversation_open)
  WHERE conversation_open = TRUE;
```

### 3.2. Onde é usada?

**❌ NENHUM WORKFLOW USA ESTA TABELA**

### 3.3. Função (PLANEJADA mas não implementada)

**Session/Conversation State Management**:
- 💡 Gerenciar estado da conversa (aberta/fechada)
- 💡 Rastrear última mensagem
- 💡 Batch collection (campos já existem!)
- 💡 Agent assignment

**Por que não foi implementada?**

Provavelmente:
1. Criaram a tabela pensando no futuro
2. Implementaram `corev4_chat_history` antes
3. `corev4_chat_history` resolveu o problema
4. `corev4_chats` ficou obsoleta antes de ser usada

---

## 🎯 COMPARAÇÃO DIRETA

| Característica | `chat_history` | `n8n_chat_histories` | `chats` |
|----------------|----------------|----------------------|---------|
| **Formato** | Colunas separadas | JSONB | Colunas |
| **Propósito** | Histórico permanente | Memory AI | Session state |
| **Usado por** | Sistema todo | AI Agent | Ninguém ❌ |
| **Apagável?** | Raramente (#limpar) | Sim (reset) | N/A |
| **Mídia** | ✅ Suporta | ❌ Só texto | N/A |
| **Custos** | ✅ Rastreia | ❌ Não | N/A |
| **Batch fields** | ❌ Não tem | ❌ Não tem | ✅ TEM! |

---

## 💡 DESCOBERTA IMPORTANTE

### Por que `corev4_chats` tem campos de batch?

```sql
-- Campos que JÁ existem:
batch_collecting BOOLEAN DEFAULT FALSE
batch_expires_at TIMESTAMPTZ
```

**HIPÓTESE:**
Alguém já planejou implementar batch collection! Por isso criou esses campos. Mas nunca implementou.

### Por que `corev4_chat_history` substituiu `corev4_chats`?

**PROVÁVEL CRONOLOGIA:**

1. **V1:** Criaram `corev4_chats` para gerenciar sessões
2. **V2:** Perceberam que precisavam armazenar histórico detalhado
3. **V3:** Criaram `corev4_chat_history` com mais campos (mídia, custos)
4. **V4:** `corev4_chat_history` virou a principal, `corev4_chats` ficou abandonada

---

## 🎯 DECISÃO: Onde Implementar Batch Collection?

### Opção A: `corev4_chats` ⭐⭐⭐⭐⭐ (RECOMENDADO)

**VANTAGENS:**
- ✅ Campos `batch_collecting` e `batch_expires_at` **JÁ EXISTEM**
- ✅ Propósito original era session management (batch faz sentido!)
- ✅ Tabela vazia (sem migração de dados)
- ✅ Dar propósito à tabela (ressuscitar!)
- ✅ Índice `idx_chats_batch` já existe
- ✅ UNIQUE (contact_id, company_id) perfeito para batch

**DESVANTAGENS:**
- ⚠️ Precisa começar a popular (UPSERT)
- ⚠️ Mais um campo: `batch_messages JSONB[]`

**IMPLEMENTAÇÃO:**
```sql
-- Adicionar apenas 1 campo:
ALTER TABLE corev4_chats
ADD COLUMN batch_messages JSONB[] DEFAULT '{}';

-- Usar UPSERT:
INSERT INTO corev4_chats (contact_id, company_id, batch_collecting, batch_expires_at, batch_messages)
VALUES (X, Y, TRUE, NOW() + INTERVAL '3s', ARRAY[message])
ON CONFLICT (contact_id, company_id) DO UPDATE
SET batch_messages = array_append(batch_messages, message),
    batch_expires_at = NOW() + INTERVAL '3s';
```

---

### Opção B: `corev4_chat_history` ⭐⭐

**VANTAGENS:**
- ✅ Tabela já é muito usada
- ✅ Já tem dados

**DESVANTAGENS:**
- ❌ Propósito é HISTÓRICO, não session state
- ❌ Precisa adicionar campos de batch (poluir tabela)
- ❌ Mistura responsabilidades
- ❌ Não tem UNIQUE (contact_id) - dificulta batch

---

### Opção C: Nova tabela `corev4_message_batches` ⭐

**VANTAGENS:**
- ✅ Separação clara

**DESVANTAGENS:**
- ❌ **FOI ASSIM QUE `corev4_chats` MORREU!**
- ❌ Mais uma tabela
- ❌ Redundância

---

## ✅ RECOMENDAÇÃO FINAL

### **USAR `corev4_chats` E RESSUSCITÁ-LA!**

**Por quê?**

1. **Campos já existem** (80% pronto)
2. **Propósito original** era exatamente isso (session management)
3. **Evita criar nova tabela** (lição aprendida)
4. **Dar função à tabela abandonada** (melhor que deixar morta)
5. **Arquitetura limpa** (cada tabela com sua responsabilidade)

**Arquitetura Final:**

```
corev4_chat_history        → Histórico permanente (auditoria, custos)
corev4_n8n_chat_histories  → Memory do AI Agent (contexto temporário)
corev4_chats               → Session state + Batch collection ✅
```

**3 tabelas, 3 propósitos distintos e complementares!**

---

## 📝 Próximos Passos

1. ✅ Migration: `ALTER TABLE corev4_chats ADD COLUMN batch_messages JSONB[]`
2. ✅ Node batch collection (usar UPSERT em `corev4_chats`)
3. ✅ Cron processor (buscar batches expirados em `corev4_chats`)
4. ✅ Integrar com One Flow

**Status:** Código já foi criado! Só ajustar para usar `corev4_chats` (já está pronto!)

---

**Conclusão:** A tabela perfeita para batch collection já existe, só estava esperando ser usada! 🎉
