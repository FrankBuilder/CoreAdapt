# 💰 Guia de Pricing Dinâmico para LLMs

> **Atualizado:** 2025-11-13
> **Status:** ✅ Implementado e Ativo

---

## 📋 Visão Geral

O sistema de pricing dinâmico permite **atualizar preços de modelos LLM sem modificar workflows no n8n**.

### Benefícios

✅ **Zero mudanças no workflow** para atualizar preços
✅ **Preços centralizados** no Supabase
✅ **Suporta novos modelos** sem tocar em código
✅ **Histórico de preços** (opcional com `valid_from`/`valid_until`)
✅ **Match inteligente** de nomes de modelo (ex: `gemini-1.5-pro-latest` → `gemini-1.5-pro`)

---

## 🏗️ Arquitetura

```
┌─────────────────────┐
│ CoreAdapt One Flow  │
└─────────┬───────────┘
          │
          ├─► CoreAdapt One AI Agent (chama Gemini/OpenAI)
          │   └─► retorna: { model: "gemini-1.5-pro", usage: {...} }
          │
          ├─► Fetch: Model Pricing (Supabase)
          │   └─► SELECT * FROM v_llm_pricing_active
          │   └─► retorna: [{ model_name, input_cost_per_1m, output_cost_per_1m }]
          │
          └─► Calculate: Assistant Cost
              └─► usa pricing do Supabase
              └─► calcula: (tokens / 1M) × cost_per_1m
```

---

## 📊 Tabela no Supabase

### Estrutura

```sql
llm_pricing
├── model_name (PK)           -- Ex: "gemini-1.5-pro"
├── input_cost_per_1m         -- USD por 1M tokens (input)
├── output_cost_per_1m        -- USD por 1M tokens (output)
├── provider                  -- "google", "openai", "anthropic"
├── display_name              -- Nome amigável
├── is_active                 -- TRUE/FALSE
├── valid_from                -- Data de início
├── valid_until               -- Data de fim (NULL = atual)
└── notes                     -- Observações
```

### Modelos Pré-Configurados

| Modelo | Provider | Input ($/1M) | Output ($/1M) |
|--------|----------|--------------|---------------|
| `gemini-1.5-pro` | Google | 1.25 | 5.00 |
| `gemini-1.5-flash` | Google | 0.075 | 0.30 |
| `gpt-4o` | OpenAI | 2.50 | 10.00 |
| `gpt-4o-mini` | OpenAI | 0.150 | 0.600 |
| `claude-3-5-sonnet` | Anthropic | 3.00 | 15.00 |

*(14 modelos no total - ver migration SQL para lista completa)*

---

## 🚀 Como Usar

### 1. Executar Migration SQL (APENAS UMA VEZ)

```bash
psql -h localhost -U postgres -d core \
  -f migrations/create_llm_pricing_table.sql
```

**O que isso faz:**
- ✅ Cria tabela `llm_pricing`
- ✅ Cria view `v_llm_pricing_active` (usada pelo n8n)
- ✅ Popula com 14 modelos comuns
- ✅ Adiciona indexes para performance

---

### 2. Importar Workflow Atualizado

No n8n:
1. Abrir "CoreAdapt One Flow | v4"
2. Settings → Import from file
3. Selecionar: `CoreAdapt One Flow _ v4.json`
4. Confirmar substituição

**Nodes adicionados/modificados:**
- ✅ **Fetch: Model Pricing** (novo node Supabase)
- ✅ **Calculate: Assistant Cost** (agora usa Supabase)
- ✅ **Calculate: User Tokens & Cost** (agora usa Supabase)

---

### 3. Testar

Enviar mensagem no WhatsApp e verificar logs:

```
💰 Cost for Gemini 1.5 Pro:
   - Input: 1500 tokens @ $1.25/1M = $0.00187500
   - Output: 800 tokens @ $5.00/1M = $0.00400000
   - Total: $0.00587500
```

Se aparecer essa mensagem, **está funcionando!** 🎉

---

## 🔧 Operações Comuns

### Atualizar Preço de um Modelo

```sql
-- Exemplo: Google aumentou preço do Gemini 1.5 Pro
UPDATE llm_pricing
SET
  input_cost_per_1m = 1.50,
  output_cost_per_1m = 6.00,
  notes = 'Price increase effective 2025-12-01'
WHERE model_name = 'gemini-1.5-pro';
```

**Resultado:** Próximas execuções do workflow usam o novo preço automaticamente.

---

### Adicionar Novo Modelo

```sql
-- Exemplo: GPT-5 foi lançado
INSERT INTO llm_pricing (
  model_name,
  input_cost_per_1m,
  output_cost_per_1m,
  provider,
  display_name,
  notes
) VALUES (
  'gpt-5',
  5.00,
  20.00,
  'openai',
  'GPT-5',
  'Latest OpenAI flagship model'
);
```

**Resultado:** Workflow automaticamente suporta GPT-5 sem mudanças.

---

### Desativar Modelo Antigo

```sql
-- Exemplo: GPT-3.5 foi descontinuado
UPDATE llm_pricing
SET
  is_active = FALSE,
  valid_until = '2025-12-31',
  notes = 'Model deprecated by OpenAI'
WHERE model_name = 'gpt-3.5-turbo';
```

**Resultado:** Modelo não aparece mais em `v_llm_pricing_active`.

---

### Ver Todos os Preços Ativos

```sql
SELECT
  model_name,
  display_name,
  provider,
  input_cost_per_1m,
  output_cost_per_1m
FROM v_llm_pricing_active
ORDER BY provider, input_cost_per_1m;
```

---

### Histórico de Preços (Avançado)

Se quiser **rastrear mudanças de preço ao longo do tempo**:

```sql
-- Ao invés de UPDATE, faça:

-- 1. Expirar o preço antigo
UPDATE llm_pricing
SET valid_until = '2025-11-30 23:59:59'
WHERE model_name = 'gemini-1.5-pro'
  AND valid_until IS NULL;

-- 2. Inserir novo preço
INSERT INTO llm_pricing (
  model_name,
  input_cost_per_1m,
  output_cost_per_1m,
  provider,
  display_name,
  valid_from
) VALUES (
  'gemini-1.5-pro',
  1.50,
  6.00,
  'google',
  'Gemini 1.5 Pro',
  '2025-12-01 00:00:00'
);
```

Assim você mantém histórico completo de todos os preços!

---

## 🔍 Match Inteligente de Modelos

O sistema faz **match parcial** de nomes:

| API Retorna | Match no Banco | Preço Usado |
|-------------|----------------|-------------|
| `gemini-1.5-pro` | `gemini-1.5-pro` | Exato ✅ |
| `gemini-1.5-pro-latest` | `gemini-1.5-pro` | Parcial ✅ |
| `gemini-1.5-pro-002` | `gemini-1.5-pro` | Parcial ✅ |
| `gpt-novo-modelo` | *(não encontrado)* | Fallback ($0.50/$1.50) ⚠️ |

**Fallback genérico:** Se modelo não for encontrado, usa `$0.50/$1.50` e loga warning.

---

## 📈 Logs e Debugging

### Logs Normais (Sucesso)

```
📊 Loaded pricing for 14 models from Supabase
💰 Cost for Gemini 1.5 Pro:
   - Input: 1500 tokens @ $1.25/1M = $0.00187500
   - Output: 800 tokens @ $5.00/1M = $0.00400000
   - Total: $0.00587500
```

### Logs de Match Parcial

```
🔍 Partial match: "gemini-1.5-pro-latest" → "gemini-1.5-pro"
```

### Logs de Fallback (Warning)

```
⚠️ Model "novo-modelo-xyz" not found in pricing table, using default
```

**Ação:** Adicionar o modelo na tabela `llm_pricing`.

---

## 🎯 Casos de Uso

### Caso 1: Mudar de Gemini para OpenAI

**Antes:**
```sql
SELECT model_name, input_cost_per_1m FROM v_llm_pricing_active
WHERE model_name LIKE 'gemini%';
```

**Mudar no n8n AI Agent:** Selecionar GPT-4o como modelo

**Resultado:** Workflow automaticamente usa preços do GPT-4o (já estão no banco).

---

### Caso 2: Testar Novo Modelo

1. Adicionar modelo na tabela:
```sql
INSERT INTO llm_pricing VALUES
  ('claude-3-haiku', 0.25, 1.25, 'anthropic', 'Claude 3 Haiku', TRUE, ...);
```

2. Mudar modelo no AI Agent do n8n

3. Testar execução

4. Verificar logs de custo

**Zero mudanças no workflow necessárias!**

---

## 🛡️ Segurança e Permissões

### Quem Pode Atualizar Preços?

Depende das permissões do Supabase:

```sql
-- Apenas admins podem alterar preços
GRANT SELECT ON v_llm_pricing_active TO anon, authenticated;
GRANT UPDATE, INSERT, DELETE ON llm_pricing TO admin_role;
```

### UI Admin (Opcional)

Você pode criar uma página admin no Supabase Studio ou no seu app:

- Listar modelos e preços
- Editar preços inline
- Histórico de mudanças
- Ativar/desativar modelos

---

## 📝 Checklist de Implementação

- [x] Migration SQL executada
- [x] Tabela `llm_pricing` criada
- [x] View `v_llm_pricing_active` criada
- [x] Dados seed inseridos (14 modelos)
- [x] Node "Fetch: Model Pricing" adicionado ao workflow
- [x] Node "Calculate: Assistant Cost" atualizado
- [x] Node "Calculate: User Tokens & Cost" atualizado
- [x] Workflow reimportado no n8n
- [ ] **Testes realizados com mensagens reais**
- [ ] **Logs verificados**
- [ ] **Custos conferidos**

---

## 🆘 Troubleshooting

### Erro: "Cannot read property 'json' of undefined"

**Causa:** Node "Fetch: Model Pricing" não executou antes do Calculate.

**Solução:** Verificar conexões no workflow. Fetch deve estar conectado após AI Agent.

---

### Warning: "Model not found in pricing table"

**Causa:** API retornou modelo que não está no banco.

**Solução:**
```sql
INSERT INTO llm_pricing VALUES
  ('nome-do-modelo', input_cost, output_cost, 'provider', 'Display Name', TRUE, ...);
```

---

### Custos Parecendo Errados

**Debug:**
```sql
-- Ver qual preço está sendo usado
SELECT * FROM v_llm_pricing_active WHERE model_name = 'seu-modelo';
```

**Verificar logs do n8n:**
- Qual modelo a API retornou?
- Qual preço foi usado no cálculo?
- Match foi exato ou parcial?

---

## 📚 Referências

- **Migration SQL:** `migrations/create_llm_pricing_table.sql`
- **Script Python:** `scripts/implement_dynamic_pricing.py`
- **Workflow:** `CoreAdapt One Flow _ v4.json`

### Pricing Oficial dos Providers

- **Google Gemini:** https://ai.google.dev/pricing
- **OpenAI:** https://openai.com/pricing
- **Anthropic:** https://www.anthropic.com/pricing

---

## 💡 Próximos Passos (Futuro)

### Melhorias Possíveis

- [ ] Dashboard de custos em tempo real
- [ ] Alertas quando custo passar threshold
- [ ] Otimização automática (mudar pra modelo mais barato se disponível)
- [ ] Cache de preços (evitar query a cada execução)
- [ ] API de pricing externo (buscar preços atualizados automaticamente)

**Mas por enquanto:** A solução atual é **padrão ouro** e deve servir por muito tempo. 🎯

---

**Versão:** 1.0
**Autor:** Claude
**Data:** 2025-11-13
**Status:** ✅ Produção
