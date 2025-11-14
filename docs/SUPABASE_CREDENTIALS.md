# Credenciais Supabase - CoreAdapt Production

## Informações de Conexão

**Supabase Project URL:**
```
https://uosauvyafotuhktpjjkm.supabase.co
```

**Supabase Anon Key:**
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVvc2F1dnlhZm90dWhrdHBqamttIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjU0MDgxODcsImV4cCI6MjA0MDk4NDE4N30.3UzrMj0gw1aY8fcJw9649LjIKryLTNgmDNd9EuIpOx8
```

## Configuração nos Workflows

### Nodes que usam Supabase

1. **Calculate: User Tokens & Cost** (CoreAdapt One Flow)
   - Busca pricing de modelos LLM
   - Calcula custo de tokens do usuário

2. **Calculate: Assistant Cost** (CoreAdapt One Flow)
   - Busca pricing de modelos LLM
   - Calcula custo de tokens da IA

### Configuração Automática

As credenciais já estão configuradas nos workflows. Para reconfigurar:

```bash
python3 scripts/config_supabase_credentials.py
```

O script substitui automaticamente nos nodes:
```javascript
const SUPABASE_URL = 'https://uosauvyafotuhktpjjkm.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

## Tabelas Utilizadas

### `v_llm_pricing_active`

View com pricing ativo dos modelos LLM:

```sql
SELECT * FROM v_llm_pricing_active;
```

**Colunas:**
- `model_name` - Nome do modelo (ex: "gemini-1.5-pro")
- `input_cost_per_1m` - Custo por 1M tokens de input
- `output_cost_per_1m` - Custo por 1M tokens de output
- `provider` - Provedor (ex: "google", "openai")
- `display_name` - Nome para exibição
- `is_active` - Se está ativo

## Segurança

**IMPORTANTE:**
- Anon Key é PÚBLICA (pode estar em código frontend)
- Usa Row Level Security (RLS) do Supabase
- Permissões controladas no nível de tabela/view
- Não expõe dados sensíveis

## Troubleshooting

### Erro: Failed to fetch pricing

**Causa:** Credenciais incorretas ou view não existe

**Verificação:**
```bash
curl -X GET \
  'https://uosauvyafotuhktpjjkm.supabase.co/rest/v1/v_llm_pricing_active?select=*' \
  -H 'apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...' \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
```

**Resposta esperada:**
```json
[
  {
    "model_name": "gemini-1.5-pro",
    "input_cost_per_1m": 1.25,
    "output_cost_per_1m": 5.00,
    "provider": "google",
    "display_name": "Gemini 1.5 Pro",
    "is_active": true
  },
  ...
]
```

### Erro: Model not in pricing table

**Causa:** Modelo não cadastrado na tabela `llm_pricing`

**Solução:**
```sql
INSERT INTO llm_pricing (
  model_name,
  input_cost_per_1m,
  output_cost_per_1m,
  provider,
  display_name
) VALUES (
  'novo-modelo',
  0.50,
  1.50,
  'provider',
  'Novo Modelo Display'
);
```

## Referências

- **Migration inicial:** `migrations/create_llm_pricing_table.sql`
- **Script de config:** `scripts/config_supabase_credentials.py`
- **Documentação:** `docs/DYNAMIC_PRICING_GUIDE.md`

---

**Última atualização:** 2025-11-14
**Commit:** `fb3998b`
