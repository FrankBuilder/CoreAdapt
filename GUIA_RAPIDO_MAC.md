# 🚀 GUIA RÁPIDO - Como Gerar Relatório de Lead (MacBook)

## ✅ Método 1: Supabase SQL Editor (MAIS FÁCIL)

### Passo 1: Abrir o arquivo SQL

No seu Mac, abra o arquivo:
```
CoreAdapt/queries/quick_lead_report.sql
```

Pode abrir com:
- VS Code
- TextEdit
- Sublime Text
- Qualquer editor de texto

### Passo 2: Encontrar o ID do lead

Você precisa do **ID** do contato. Tem 2 formas:

**Opção A - Buscar no Supabase:**

1. Vá para: https://supabase.com/dashboard
2. Entre no seu projeto CoreAdapt
3. Clique em "Table Editor" (menu lateral)
4. Abra a tabela `corev4_contacts`
5. Procure o lead que você quer (busque por nome ou WhatsApp)
6. **Copie o número da coluna `id`** (exemplo: 123)

**Opção B - Buscar via SQL:**

1. Vá para: https://supabase.com/dashboard
2. Entre no seu projeto CoreAdapt
3. Clique em "SQL Editor" (menu lateral)
4. Cole isso e execute:

```sql
SELECT id, full_name, whatsapp, email, created_at
FROM corev4_contacts
ORDER BY created_at DESC
LIMIT 20;
```

5. Escolha um lead e **copie o ID**

---

### Passo 3: Substituir :contact_id no arquivo

No arquivo `quick_lead_report.sql`:

1. Pressione **Cmd + F** (buscar)
2. Busque por: `:contact_id`
3. Vai encontrar várias ocorrências (cerca de 10)
4. Pressione **Cmd + Option + F** (buscar e substituir)
5. Em "Find": `:contact_id`
6. Em "Replace": `123` (substitua 123 pelo ID real do seu lead)
7. Clique em "Replace All"

**ANTES:**
```sql
WHERE c.id = :contact_id
```

**DEPOIS:**
```sql
WHERE c.id = 123
```

---

### Passo 4: Copiar tudo

1. Pressione **Cmd + A** (selecionar tudo)
2. Pressione **Cmd + C** (copiar)

---

### Passo 5: Executar no Supabase

1. Vá para: https://supabase.com/dashboard
2. Entre no seu projeto CoreAdapt
3. Clique em "**SQL Editor**" no menu lateral
4. Clique em "**New query**" (botão verde)
5. Pressione **Cmd + V** para colar a query completa
6. Clique em "**Run**" (ou pressione Cmd + Enter)

---

### Passo 6: Ver o resultado

O relatório vai aparecer na tela em formato de tabela!

Você pode:
- ✅ Ler direto na tela
- ✅ Copiar e colar no Excel/Sheets
- ✅ Exportar como CSV (botão "Download CSV" no canto)
- ✅ Imprimir (Cmd + P)

---

## 🎨 Método 2: Gerar Relatório HTML Bonito (MacBook)

Se você quer um relatório visual e profissional:

### Passo 1: Verificar se tem Node.js instalado

Abra o Terminal e execute:

```bash
node --version
```

**Se aparecer um número (ex: v20.0.0):** ✅ Tem Node.js instalado, pule para Passo 3

**Se der erro "command not found":** ❌ Precisa instalar, vá para Passo 2

---

### Passo 2: Instalar Node.js (se necessário)

**Opção A - Via Homebrew (recomendado):**

```bash
# Instalar Homebrew (se não tiver)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Instalar Node.js
brew install node
```

**Opção B - Download direto:**

1. Vá para: https://nodejs.org
2. Baixe a versão LTS (recomendada)
3. Instale o .pkg
4. Reinicie o Terminal

---

### Passo 3: Instalar dependências

No Terminal, vá até a pasta do projeto:

```bash
cd /home/user/CoreAdapt
# OU se estiver em outro lugar:
cd ~/caminho/para/CoreAdapt

# Instalar a biblioteca do Supabase
npm install @supabase/supabase-js
```

---

### Passo 4: Pegar credenciais do Supabase

1. Vá para: https://supabase.com/dashboard
2. Entre no seu projeto CoreAdapt
3. Clique em "**Settings**" (engrenagem) no menu lateral
4. Clique em "**API**"
5. Copie:
   - **Project URL** (exemplo: `https://abcxyz123.supabase.co`)
   - **service_role key** (é uma chave longa que começa com `eyJ...`)
     - ⚠️ **Não** use a `anon key`, tem que ser a **service_role**!

---

### Passo 5: Configurar as credenciais

No Terminal:

```bash
export SUPABASE_URL="https://seu-projeto.supabase.co"
export SUPABASE_SERVICE_KEY="eyJhbGciOiJI..."

# Substitua pelos valores reais copiados acima!
```

**DICA:** Crie um arquivo para não ter que digitar toda vez:

```bash
# Crie um arquivo com as credenciais
cat > ~/.coreadapt_env << 'EOF'
export SUPABASE_URL="https://seu-projeto.supabase.co"
export SUPABASE_SERVICE_KEY="eyJhbGciOiJI..."
EOF

# Toda vez que for usar, execute:
source ~/.coreadapt_env
```

---

### Passo 6: Gerar o relatório HTML

```bash
# Certifique-se de estar na pasta do projeto
cd /caminho/para/CoreAdapt

# Gerar relatório HTML
node scripts/generate_lead_report.js \
  --contact-id=123 \
  --format=html \
  --output=relatorio_lead_123.html

# Substitua 123 pelo ID real do lead!
```

---

### Passo 7: Abrir o relatório HTML

```bash
# Abrir no navegador padrão
open relatorio_lead_123.html
```

OU simplesmente dê duplo-clique no arquivo `relatorio_lead_123.html` no Finder!

---

## 📊 Exemplos de Comandos Úteis

### Relatório simples no terminal (texto):
```bash
node scripts/generate_lead_report.js --contact-id=123
```

### Salvar em arquivo texto:
```bash
node scripts/generate_lead_report.js \
  --contact-id=123 \
  --output=relatorio.txt
```

### Gerar JSON (para processar depois):
```bash
node scripts/generate_lead_report.js \
  --contact-id=123 \
  --format=json \
  --output=lead_data.json
```

### Histórico completo de mensagens:
```bash
node scripts/generate_lead_report.js \
  --contact-id=123 \
  --include-full-history \
  --format=html \
  --output=relatorio_completo.html
```

### Buscar por WhatsApp em vez de ID:
```bash
node scripts/generate_lead_report.js \
  --whatsapp="5585999855443@s.whatsapp.net" \
  --format=html \
  --output=relatorio.html
```

---

## 🆘 Problemas Comuns

### Erro: "Cannot find module '@supabase/supabase-js'"

```bash
npm install @supabase/supabase-js
```

### Erro: "SUPABASE_URL is not defined"

Você esqueceu de configurar as variáveis de ambiente:

```bash
export SUPABASE_URL="sua-url"
export SUPABASE_SERVICE_KEY="sua-chave"
```

### Erro: "Contact not found"

O ID não existe. Verifique se digitou corretamente.

### Erro: "command not found: node"

Node.js não está instalado. Veja "Passo 2: Instalar Node.js" acima.

### Query SQL muito lenta

Use `quick_lead_report.sql` em vez de `lead_complete_report.sql`.

---

## 💡 Qual método usar?

### Use **Supabase SQL Editor** se:
- ✅ Quer testar rapidamente
- ✅ Não quer instalar nada
- ✅ Consulta pontual

### Use **Script Node.js** se:
- ✅ Quer relatórios HTML bonitos
- ✅ Vai gerar relatórios com frequência
- ✅ Quer preparar apresentações

---

## 🎯 Recomendação

**Para sua primeira vez:**

1. Use o **Método 1** (Supabase SQL Editor)
2. Teste com 1 ou 2 leads
3. Veja se atende sua necessidade

**Se gostar do resultado:**

4. Configure o **Método 2** (Node.js)
5. Gere relatórios HTML bonitos
6. Use para preparar reuniões

---

## 📱 Precisa de ajuda?

Se tiver qualquer dúvida:
1. Me mande o erro completo que aparece
2. Me diga qual método está tentando usar
3. Me diga em que passo travou
