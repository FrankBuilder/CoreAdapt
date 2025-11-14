# 🚀 Dynamic Pricing - Quick Start

> **5 minutos para configurar**

---

## 1️⃣ Executar Migration SQL

```bash
psql -h localhost -U postgres -d core \
  -f migrations/create_llm_pricing_table.sql
```

✅ Cria tabela `llm_pricing` com 14 modelos pré-configurados

---

## 2️⃣ Pegar Credenciais do Supabase

No Supabase Dashboard:
1. Settings → API
2. Copiar:
   - **Project URL** (ex: `https://jrvzexchifudbdxeqvuh.supabase.co`)
   - **anon public key**

---

## 3️⃣ Reimportar Workflow

No n8n:
1. Abrir "CoreAdapt One Flow | v4"
2. Settings → Import from file
3. Selecionar `CoreAdapt One Flow _ v4.json`
4. Confirmar substituição

---

## 4️⃣ Configurar Credenciais nos Nodes

### Node: Calculate: Assistant Cost

1. Abrir node no n8n
2. Editar linhas 4-5:

```javascript
const SUPABASE_URL = 'https://jrvzexchifudbdxeqvuh.supabase.co';  // ← SEU PROJECT URL
const SUPABASE_ANON_KEY = 'sua-anon-key-aqui';  // ← SUA ANON KEY
```

3. Salvar

### Node: Calculate: User Tokens & Cost

1. Abrir node no n8n
2. Editar linhas 4-5 (mesmas credenciais)
3. Salvar

---

## 5️⃣ Testar

1. Enviar mensagem no WhatsApp
2. Verificar logs do n8n:

```
📊 Loaded 14 pricing entries from Supabase
💰 Gemini 1.5 Pro:
   Input: 1500 @ $1.25/1M = $0.00187500
   Output: 800 @ $5.00/1M = $0.00400000
   Total: $0.00587500
```

✅ **Funcionou!**

---

## ❓ FAQ

**P: A anon key é segura de colocar no código?**
R: Sim! É pública por natureza. A segurança vem do Row Level Security (RLS) do Supabase.

**P: E se eu quiser atualizar um preço?**
R: Simples SQL:
```sql
UPDATE llm_pricing
SET input_cost_per_1m = 1.50
WHERE model_name = 'gemini-1.5-pro';
```

**P: E para adicionar um modelo novo?**
R: Simples SQL:
```sql
INSERT INTO llm_pricing VALUES
  ('gpt-5', 5.00, 20.00, 'openai', 'GPT-5', TRUE, NOW(), NULL, 'New model');
```

**P: Isso não faz muitas queries no Supabase?**
R: Faz 1 query por Calculate node (~10ms). Aceitável. Se precisar otimizar, podemos adicionar cache depois.

---

## 🎯 Pronto!

Agora você tem pricing dinâmico funcionando.

Nunca mais precisa editar workflow para atualizar preços! 🎉
