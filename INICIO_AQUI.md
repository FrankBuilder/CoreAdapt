# 🎯 COMECE AQUI - Gerar Relatório de Lead

## ⚡ 5 Passos Rápidos

### ✅ PASSO 1: Encontre o ID do Lead

Abra seu navegador e vá para:
```
https://supabase.com/dashboard
```

1. Entre no projeto **CoreAdapt**
2. Clique em **"Table Editor"** (ícone de tabela no menu esquerdo)
3. Clique na tabela **`corev4_contacts`**
4. Procure o lead que você quer analisar
5. **Copie o número da coluna `id`** (exemplo: 123, 456, etc.)

💡 **DICA:** Use Cmd+F para buscar pelo nome do lead na tabela!

---

### ✅ PASSO 2: Abra o Arquivo SQL

No seu Mac, navegue até:
```
CoreAdapt/queries/quick_lead_report.sql
```

Abra com qualquer editor:
- **VS Code** (recomendado)
- TextEdit
- Sublime Text
- Atom

Você vai ver um arquivo grande com queries SQL.

---

### ✅ PASSO 3: Substitua :contact_id

No editor de texto:

1. Pressione **Cmd + Option + F** (buscar e substituir)
   - Se não funcionar, use: **Cmd + F** e depois clique em "Replace"

2. Em "Find" (Buscar), digite:
   ```
   :contact_id
   ```

3. Em "Replace" (Substituir), digite o ID que você copiou:
   ```
   123
   ```
   ☝️ Substitua 123 pelo ID real do seu lead!

4. Clique em **"Replace All"** (Substituir Todos)

Você vai ver cerca de 10 substituições acontecerem.

**ANTES:**
```sql
WHERE c.id = :contact_id
```

**DEPOIS:**
```sql
WHERE c.id = 123
```

---

### ✅ PASSO 4: Copie Todo o Arquivo

No editor de texto:

1. Pressione **Cmd + A** (selecionar tudo)
2. Pressione **Cmd + C** (copiar)

Tudo copiado! ✓

---

### ✅ PASSO 5: Execute no Supabase

Volte para o navegador:

1. Vá para: https://supabase.com/dashboard
2. Entre no projeto **CoreAdapt**
3. Clique em **"SQL Editor"** (ícone de código no menu esquerdo)
4. Clique no botão **"+ New query"** (verde, no topo)
5. Pressione **Cmd + V** (colar a query)
6. Clique em **"Run"** (ou pressione **Cmd + Enter**)

🎉 **PRONTO!** O relatório vai aparecer na tela!

---

## 📊 O Que Você Vai Ver

O relatório mostra:

```
═══════════════════════════════════════════════════════════
                 RESUMO EXECUTIVO
═══════════════════════════════════════════════════════════

Lead: João Silva (ID: 123)
WhatsApp: 5585999855443@s.whatsapp.net
Email: joao@exemplo.com

Status: 💬 CONVERSA ATIVA
Última interação: 12/11/2025 15:30 (há 2.5h)

ANUM Total: 75.5/100 - QUALIFIED ✓ QUALIFICADO
  └─ A:80.0 | N:85.0 | U:70.0 | M:67.0

Dor principal: Vendas
Campanha: active - 3/6 passos
Reuniões: 1 agendada(s) | 0 realizada(s)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[... e muito mais detalhes abaixo ...]
```

---

## 💾 Salvar o Resultado

No Supabase SQL Editor, depois de executar:

1. Clique no botão **"Download CSV"** (canto superior direito)
2. OU copie e cole no Excel/Google Sheets
3. OU tire um screenshot (Cmd + Shift + 4)

---

## 🎨 Quer um Relatório HTML Bonito?

Se você quiser um relatório visual e profissional em HTML:

### 1. Instale Node.js (se não tiver):

Abra o Terminal e execute:
```bash
# Verificar se já tem
node --version

# Se não tiver, instale via Homebrew
brew install node
```

### 2. Instale a dependência:

```bash
cd ~/caminho/para/CoreAdapt
npm install @supabase/supabase-js
```

### 3. Configure as credenciais:

Pegue suas credenciais no Supabase:
- https://supabase.com/dashboard
- Settings → API
- Copie: Project URL e service_role key

No Terminal:
```bash
export SUPABASE_URL="https://seu-projeto.supabase.co"
export SUPABASE_SERVICE_KEY="eyJhbGci..."
```

### 4. Gere o relatório HTML:

```bash
node scripts/generate_lead_report.js \
  --contact-id=123 \
  --format=html \
  --output=relatorio.html

# Abrir no navegador
open relatorio.html
```

---

## 📚 Mais Informações

- **Guia completo para Mac:** `GUIA_RAPIDO_MAC.md`
- **Documentação técnica:** `queries/README_LEAD_REPORT.md`
- **Exemplos de uso:** `queries/exemplo_uso_lead_report.md`

---

## 🆘 Problemas?

### "Não achei o arquivo quick_lead_report.sql"

No Terminal:
```bash
cd ~/caminho/para/CoreAdapt
ls -la queries/quick_lead_report.sql
```

Se não aparecer, você está na pasta errada.

### "A query deu erro no Supabase"

Verifique se:
1. Substituiu **TODOS** os `:contact_id` pelo ID real
2. O ID existe (teste com: `SELECT * FROM corev4_contacts WHERE id = 123;`)
3. Copiou o arquivo **completo** (não só uma parte)

### "O ID não existe"

Busque um ID válido:
```sql
SELECT id, full_name, whatsapp
FROM corev4_contacts
ORDER BY created_at DESC
LIMIT 10;
```

---

## ⚡ Resumo Ultra-Rápido

```
1. Pegar ID do lead no Supabase Table Editor
2. Abrir queries/quick_lead_report.sql
3. Substituir :contact_id por 123 (seu ID)
4. Copiar tudo (Cmd+A, Cmd+C)
5. Colar no Supabase SQL Editor (Cmd+V)
6. Run!
```

**Tempo total: 3 minutos** ⏱️

---

Bora testar? Me avisa se deu certo ou se travou em algum passo! 🚀
