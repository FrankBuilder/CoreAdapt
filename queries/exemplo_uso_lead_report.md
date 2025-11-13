# 🎯 Como Gerar Relatório de Lead - Guia Prático

## Opção 1: SQL Direto no Supabase (MAIS FÁCIL)

### Passo 1: Pegar o ID do Lead

Primeiro, encontre o ID do lead que você quer analisar:

```sql
-- Buscar por nome
SELECT id, full_name, whatsapp, email
FROM corev4_contacts
WHERE full_name ILIKE '%nome_do_lead%'
LIMIT 10;

-- OU buscar por WhatsApp
SELECT id, full_name, whatsapp, email
FROM corev4_contacts
WHERE whatsapp = '5585999855443@s.whatsapp.net';
```

### Passo 2: Abrir o Arquivo de Query

1. Vá até: `queries/quick_lead_report.sql`
2. Abra no editor de texto

### Passo 3: Substituir o ID

Procure por **todas** as ocorrências de `:contact_id` e substitua pelo ID real.

**Exemplo:**

```sql
-- ANTES:
WHERE c.id = :contact_id

-- DEPOIS (supondo que o ID seja 123):
WHERE c.id = 123
```

**Use Ctrl+F (ou Cmd+F no Mac) e busque por `:contact_id`**

Você vai encontrar cerca de 10 ocorrências. Substitua todas por `123` (ou o ID que você quer).

### Passo 4: Executar no Supabase

1. Copie **TODO** o conteúdo do arquivo `quick_lead_report.sql` (depois de substituir o ID)
2. Acesse seu projeto no Supabase: https://supabase.com/dashboard
3. Vá em **SQL Editor** (menu lateral)
4. Cole a query
5. Clique em **Run** (ou F5)

### Passo 5: Ver o Resultado

O resultado vai aparecer em formato de tabela. Você pode:
- Copiar para Excel
- Exportar como CSV
- Visualizar direto no navegador

---

## Opção 2: Script Bash (Para Terminal)

Se você prefere linha de comando mas não quer mexer com Node.js:

```bash
#!/bin/bash
# Script simples para gerar relatório via psql

CONTACT_ID="123"  # MUDE AQUI
DB_URL="postgresql://usuario:senha@host:5432/banco"  # MUDE AQUI

# Substitui :contact_id pelo ID real e executa
sed "s/:contact_id/$CONTACT_ID/g" queries/quick_lead_report.sql | \
  psql "$DB_URL" -f - > relatorio_lead_$CONTACT_ID.txt

echo "Relatório gerado em: relatorio_lead_$CONTACT_ID.txt"
```

**Como usar:**
1. Salve como `gerar_relatorio.sh`
2. Edite as variáveis CONTACT_ID e DB_URL
3. Execute: `bash gerar_relatorio.sh`

---

## Opção 3: Script Node.js (MAIS COMPLETO)

Se você quer os relatórios HTML bonitos e automação, use o Node.js.

### Instalação (só precisa fazer 1 vez):

```bash
cd /home/user/CoreAdapt

# Instalar a dependência do Supabase
npm install @supabase/supabase-js

# Ou se usar Yarn:
yarn add @supabase/supabase-js
```

### Configuração das Credenciais:

Você precisa das credenciais do Supabase. Pegue no dashboard:

1. Vá em: https://supabase.com/dashboard/project/SEU_PROJETO/settings/api
2. Copie:
   - **Project URL** (exemplo: `https://abcdefgh.supabase.co`)
   - **Service Role Key** (é uma chave longa, começa com `eyJ...`)

**IMPORTANTE:** A Service Role Key é SECRETA! Nunca commite no Git.

### Opção A: Variáveis de Ambiente (Recomendado)

```bash
# No terminal, antes de executar:
export SUPABASE_URL="https://seu-projeto.supabase.co"
export SUPABASE_SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Agora execute o script:
node scripts/generate_lead_report.js --contact-id=123
```

### Opção B: Arquivo .env (Mais Prático)

Crie um arquivo `.env` na raiz do projeto:

```bash
# .env
SUPABASE_URL=https://seu-projeto.supabase.co
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**IMPORTANTE:** Adicione `.env` no `.gitignore`:

```bash
echo ".env" >> .gitignore
```

Agora instale o dotenv:

```bash
npm install dotenv
```

E execute:

```bash
node -r dotenv/config scripts/generate_lead_report.js --contact-id=123
```

### Exemplos de Uso:

```bash
# Relatório em texto (console)
node scripts/generate_lead_report.js --contact-id=123

# Salvar em arquivo
node scripts/generate_lead_report.js --contact-id=123 --output=relatorio.txt

# Gerar HTML bonito
node scripts/generate_lead_report.js --contact-id=123 --format=html --output=relatorio.html

# Abrir o HTML no navegador
node scripts/generate_lead_report.js --contact-id=123 --format=html --output=relatorio.html && open relatorio.html

# Buscar por WhatsApp
node scripts/generate_lead_report.js --whatsapp="5585999855443@s.whatsapp.net"

# JSON para processar depois
node scripts/generate_lead_report.js --contact-id=123 --format=json > lead_data.json

# Histórico completo (todas as mensagens)
node scripts/generate_lead_report.js --contact-id=123 --include-full-history
```

---

## 🎨 Qual Opção Escolher?

### Use **SQL Direto** se:
- ✅ Você só quer ver os dados rapidamente
- ✅ Não precisa de relatórios formatados
- ✅ Vai copiar para Excel/Sheets
- ✅ É consulta pontual (não vai fazer toda hora)

### Use **Script Bash** se:
- ✅ Você já tem psql instalado
- ✅ Quer automatizar mas sem Node.js
- ✅ Prefere arquivos texto simples

### Use **Script Node.js** se:
- ✅ Quer relatórios HTML bonitos
- ✅ Vai gerar relatórios com frequência
- ✅ Quer diferentes formatos (texto, JSON, HTML)
- ✅ Quer automatizar o processo
- ✅ Vai integrar com outros sistemas

---

## 🚀 Fluxo Recomendado

**Para começar:**
1. Use SQL direto no Supabase
2. Teste com 2-3 leads diferentes
3. Veja se o relatório atende suas necessidades

**Se gostar:**
4. Configure o Node.js
5. Gere relatórios HTML
6. Automatize com script bash ou npm script

---

## 💡 Dica Bônus: NPM Script

Adicione no `package.json`:

```json
{
  "scripts": {
    "report": "node scripts/generate_lead_report.js",
    "report:html": "node scripts/generate_lead_report.js --format=html"
  }
}
```

Uso:

```bash
npm run report -- --contact-id=123
npm run report:html -- --contact-id=123 --output=relatorio.html
```

---

## ❓ Troubleshooting

### Erro: "Cannot find module '@supabase/supabase-js'"
```bash
npm install @supabase/supabase-js
```

### Erro: "SUPABASE_URL is not defined"
Você esqueceu de configurar as variáveis de ambiente. Veja "Configuração das Credenciais" acima.

### Erro: "Contact not found"
O ID do contato não existe ou você não tem permissão. Verifique o ID.

### Query SQL muito lenta
Use `quick_lead_report.sql` em vez de `lead_complete_report.sql`, ou limite o histórico de mensagens.

---

## 📞 Precisa de Ajuda?

1. Teste primeiro com SQL direto
2. Se der erro, me mande o erro completo
3. Se funcionar, escolha a opção que preferir
