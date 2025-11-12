# 📊 Sistema de Relatórios de Lead - CoreAdapt v4

## Visão Geral

Este sistema fornece uma análise completa e detalhada de qualquer lead no sistema CoreAdapt v4, incluindo:

- ✅ **Score ANUM completo** (Authority, Need, Urgency, Money)
- 📧 **Status da campanha de follow-up** (passos executados, agendados, cancelados)
- 📅 **Reuniões agendadas/realizadas** (com ANUM no momento do agendamento)
- 💬 **Histórico completo de mensagens** (com tokens e custos)
- 📈 **Métricas de engajamento** (total de mensagens, reengajamentos, etc.)
- ⏱️ **Timeline de eventos** (primeira mensagem, análises, follow-ups, reuniões)
- 🔄 **Análise de reengajamento** (gaps de silêncio, respostas após follow-ups)

---

## 🚀 Como Usar

### Opção 1: Script Node.js (Recomendado)

O script Node.js gera relatórios formatados em texto, JSON ou HTML.

#### Instalação

```bash
# Certifique-se de ter as dependências instaladas
npm install @supabase/supabase-js

# Configure as variáveis de ambiente
export SUPABASE_URL="https://seu-projeto.supabase.co"
export SUPABASE_SERVICE_KEY="sua-service-key"
```

#### Uso Básico

```bash
# Por ID do contato
node scripts/generate_lead_report.js --contact-id=123

# Por número de WhatsApp
node scripts/generate_lead_report.js --whatsapp="5585999855443@s.whatsapp.net"
```

#### Opções Avançadas

```bash
# Gerar relatório em JSON
node scripts/generate_lead_report.js --contact-id=123 --format=json

# Gerar relatório em HTML
node scripts/generate_lead_report.js --contact-id=123 --format=html --output=report.html

# Incluir histórico completo de mensagens (pode ser grande!)
node scripts/generate_lead_report.js --contact-id=123 --include-full-history

# Salvar em arquivo
node scripts/generate_lead_report.js --contact-id=123 --output=relatorio_lead_123.txt
```

#### Parâmetros Disponíveis

| Parâmetro | Descrição | Exemplo |
|-----------|-----------|---------|
| `--contact-id` | ID do contato no banco | `--contact-id=123` |
| `--whatsapp` | Número do WhatsApp | `--whatsapp="5585999855443@s.whatsapp.net"` |
| `--format` | Formato de saída (text, json, html) | `--format=html` |
| `--output` | Arquivo de saída | `--output=report.html` |
| `--include-full-history` | Incluir histórico completo | `--include-full-history` |

---

### Opção 2: SQL Direto

Você pode executar as queries SQL diretamente no Supabase SQL Editor ou em qualquer cliente PostgreSQL.

#### Query Rápida - Informações Essenciais

```sql
-- Substitua o valor :contact_id pelo ID desejado
WITH contact_data AS (
    SELECT
        c.id,
        c.full_name,
        c.whatsapp,
        c.email,
        c.opt_out,
        c.is_active,
        c.last_interaction_at,

        -- ANUM
        ls.total_score AS anum_total,
        ls.authority_score,
        ls.need_score,
        ls.urgency_score,
        ls.money_score,
        ls.qualification_stage,
        ls.is_qualified,

        -- Campaign
        fc.status AS campaign_status,
        fc.steps_completed,
        fc.total_steps,

        -- Meetings
        COUNT(DISTINCT sm.id) AS total_meetings,
        COUNT(DISTINCT sm.id) FILTER (WHERE sm.meeting_completed = true) AS completed_meetings

    FROM corev4_contacts c
    LEFT JOIN corev4_lead_state ls ON c.id = ls.contact_id
    LEFT JOIN corev4_followup_campaigns fc ON c.id = fc.contact_id
    LEFT JOIN corev4_scheduled_meetings sm ON c.id = sm.contact_id
    WHERE c.id = :contact_id  -- SUBSTITUA AQUI
    GROUP BY c.id, ls.total_score, ls.authority_score, ls.need_score,
             ls.urgency_score, ls.money_score, ls.qualification_stage,
             ls.is_qualified, fc.status, fc.steps_completed, fc.total_steps
)
SELECT * FROM contact_data;
```

#### Queries por Seção

As queries completas estão disponíveis em `queries/lead_complete_report.sql`, organizadas por seção:

1. **Informações Básicas e ANUM** - Dados do contato e score de qualificação
2. **Campanha de Follow-up** - Status geral da campanha
3. **Detalhamento de Follow-ups** - Cada passo individualmente
4. **Reuniões** - Meetings agendados e realizados
5. **Estatísticas de Engajamento** - Métricas de mensagens
6. **Timeline de Eventos** - Cronologia completa
7. **Histórico de Mensagens** - Últimas 20 ou completo

**Como usar:**

1. Abra o arquivo `queries/lead_complete_report.sql`
2. Substitua `:contact_id` pelo ID desejado em todas as queries
3. Execute cada seção separadamente no Supabase SQL Editor
4. Copie os resultados para análise

---

## 📋 Exemplo de Relatório (Formato Texto)

```
═══════════════════════════════════════════════════════════════════════
                    RELATÓRIO COMPLETO DO LEAD
═══════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────────┐
│  IDENTIFICAÇÃO DO LEAD                                              │
└─────────────────────────────────────────────────────────────────────┘

ID: 123
Nome: João Silva
WhatsApp: 5585999855443@s.whatsapp.net
Telefone: +55 85 99985-5443
Email: joao@exemplo.com
Empresa: Empresa XYZ

┌─────────────────────────────────────────────────────────────────────┐
│  STATUS ATUAL                                                       │
└─────────────────────────────────────────────────────────────────────┘

Status Geral: 💬 CONVERSA ATIVA
Status Lead State: ativo
Última Interação: 12/11/2025 15:30 (há 2.5 horas)

┌─────────────────────────────────────────────────────────────────────┐
│  SCORE ANUM (QUALIFICAÇÃO)                                          │
└─────────────────────────────────────────────────────────────────────┘

ANUM TOTAL: 75.5/100
  └─ Authority (Autoridade): 80.0/100
  └─ Need (Necessidade): 85.0/100
  └─ Urgency (Urgência): 70.0/100
  └─ Money (Dinheiro): 67.0/100

Estágio de Qualificação: QUALIFIED
✓ QUALIFICADO
Analisado 3 vez(es)
Última Análise: 11/11/2025 14:20

Categoria de Dor: Vendas
Detalhes: Dificuldade em converter leads em clientes pagantes

[... continua com mais seções ...]
```

---

## 🎨 Formato HTML

O formato HTML gera um relatório visual bonito e profissional com:

- 🎨 Design moderno com gradientes
- 📊 Cards visuais para estatísticas
- 📈 Gráficos de progresso
- 🔵 Timeline visual de eventos
- 💬 Mensagens estilizadas por tipo (lead vs bot)
- 📱 Responsivo (funciona em mobile)

**Exemplo de uso:**

```bash
node scripts/generate_lead_report.js \
  --contact-id=123 \
  --format=html \
  --output=relatorio_lead_123.html

# Abra o arquivo HTML no navegador
open relatorio_lead_123.html
```

---

## 📊 Estrutura de Dados

### Tabelas Envolvidas

O relatório extrai dados de:

- `corev4_contacts` - Dados básicos do contato
- `corev4_lead_state` - Score ANUM e qualificação
- `corev4_contact_extras` - Preferências e métricas
- `corev4_followup_campaigns` - Campanha de follow-up
- `corev4_followup_executions` - Passos individuais
- `corev4_scheduled_meetings` - Reuniões Cal.com
- `corev4_chat_history` - Histórico de mensagens
- `corev4_companies` - Dados da empresa
- `corev4_pain_categories` - Categorias de dor

### Relacionamentos

```
corev4_contacts (1)
    ├── corev4_lead_state (1:1) - ANUM scores
    ├── corev4_contact_extras (1:1) - Preferências
    ├── corev4_followup_campaigns (1:N)
    │   └── corev4_followup_executions (1:N)
    ├── corev4_scheduled_meetings (1:N)
    └── corev4_chat_history (1:N)
```

---

## 🔍 Insights Gerados

### 1. Score ANUM Detalhado

- **Authority**: Poder de decisão (C-level, gerente, etc.)
- **Need**: Necessidade do serviço
- **Urgency**: Urgência da solução
- **Money**: Capacidade financeira

**Thresholds:**
- `< 30`: Pre-qualified (não vale a pena investir muito tempo)
- `30-70`: Developing (continuar nutrindo)
- `≥ 70`: Qualified (priorizar para conversão)

### 2. Status de Follow-ups

Para cada passo da campanha:

- ✓ **Enviado**: Follow-up foi enviado com sucesso
- ⏰ **Agendado**: Aguardando horário de envio
- ⊗ **Cancelado**: Não será enviado (lead respondeu, opt-out, etc.)
- ⚠ **Atrasado**: Deveria ter sido enviado mas ainda não foi

### 3. Análise de Reengajamento

**Reengajamento** = Gap de >48h de silêncio seguido de nova mensagem do lead

Indica:
- Lead voltou a pensar no problema
- Pode ter sido impactado por follow-up
- Momento de oportunidade para conversão

### 4. Métricas de Engajamento

- Total de mensagens (lead + bot)
- Taxa de resposta
- Tipos de mídia enviados (áudio, imagem, vídeo)
- Tokens consumidos e custos
- Períodos de silêncio

---

## 💡 Casos de Uso

### 1. Preparação para Reunião

Antes de uma reunião com o lead, gere o relatório HTML para:

- Revisar histórico de conversas
- Entender principais dores
- Ver score ANUM atual
- Preparar abordagem personalizada

```bash
node scripts/generate_lead_report.js \
  --contact-id=123 \
  --format=html \
  --output=prep_reuniao_joao.html
```

### 2. Análise de Lead Frio

Para entender por que um lead parou de responder:

```bash
node scripts/generate_lead_report.js \
  --contact-id=456 \
  --include-full-history
```

Analise:
- Quando foi a última interação
- Quantos follow-ups foram enviados
- Se houve reengajamentos anteriores
- Maior período de silêncio

### 3. Relatório para Cliente/Gestor

Gere um relatório visual em HTML para mostrar ao gestor comercial:

```bash
node scripts/generate_lead_report.js \
  --contact-id=789 \
  --format=html \
  --output=relatorio_lead_premium.html
```

### 4. Debug de Campanha

Se um follow-up não está sendo enviado:

```sql
-- Use a query de detalhamento de follow-ups
-- Veja o campo 'decision_reason' para entender o motivo
```

### 5. Análise de Custos

Para entender custos de IA por lead:

```bash
node scripts/generate_lead_report.js \
  --contact-id=999 \
  --format=json | jq '.stats.total_cost'
```

---

## 🎯 Sugestões de Enriquecimento

### Dados Adicionais que Podem Ser Incluídos

1. **Score ANUM ao Longo do Tempo**
   - Gráfico de evolução do score
   - Identificar se está melhorando ou piorando

2. **Comparação com Média**
   - Score médio de leads similares
   - Percentil do lead no funil

3. **Predição de Conversão**
   - Machine learning para prever probabilidade de fechar
   - Baseado em padrões de leads anteriores

4. **Sentimento das Mensagens**
   - Análise de sentimento positivo/negativo/neutro
   - Identificar frustração ou entusiasmo

5. **Próximas Ações Sugeridas**
   - IA sugere melhor abordagem
   - Baseado no histórico e score atual

6. **Integração com CRM**
   - Dados de oportunidades no Pipedrive/HubSpot
   - Sincronização bidirecional

7. **Histórico de Mudanças de Status**
   - Quando o lead foi de "developing" para "qualified"
   - Gatilhos que causaram a mudança

---

## 🔧 Customização

### Modificar Queries

Edite `queries/lead_complete_report.sql` para:

- Adicionar novos campos
- Criar novos cálculos
- Incluir dados de outras tabelas

### Modificar Formatação

Edite `scripts/generate_lead_report.js`:

- **Função `formatTextReport()`**: Altera formato texto
- **Função `formatHTMLReport()`**: Altera HTML/CSS
- **Função `formatJSONReport()`**: Altera estrutura JSON

### Adicionar Novos Formatos

Crie novas funções de formatação:

```javascript
function formatMarkdownReport(data) {
    // Gera relatório em Markdown
}

function formatPDFReport(data) {
    // Gera PDF usando biblioteca como pdfkit
}
```

---

## 📌 Notas Importantes

### Performance

- ⚡ Queries otimizadas com índices
- ⚠️ Histórico completo pode ser lento em leads com muitas mensagens
- 💡 Use `--include-full-history` apenas quando necessário

### Segurança

- 🔒 Nunca compartilhe relatórios contendo dados sensíveis
- 🔑 Use variáveis de ambiente para credenciais
- 🚫 Não commite arquivos de relatório no Git

### Limitações

- 📊 Não inclui dados de outras empresas (multi-tenancy)
- 🔄 Não atualiza em tempo real (snapshot)
- 💾 Histórico muito grande pode causar timeout

---

## 🐛 Troubleshooting

### Erro: "Contact not found"

- Verifique se o ID está correto
- Verifique se você tem permissão para acessar esse contato
- Verifique se está usando o company_id correto

### Erro: "Supabase connection failed"

- Verifique `SUPABASE_URL` e `SUPABASE_SERVICE_KEY`
- Verifique conexão de rede
- Verifique se o service key tem permissões adequadas

### Relatório incompleto

- Algumas seções podem estar vazias se não houver dados
- Exemplo: "Nenhuma campanha iniciada" se o lead não tem follow-ups

### Query muito lenta

- Reduza o histórico de mensagens
- Execute queries por seção separadamente
- Verifique índices no banco

---

## 📚 Exemplos Práticos

### Exemplo 1: Lead Qualificado com Reunião

```bash
node scripts/generate_lead_report.js --contact-id=100 --format=html --output=lead_100.html
```

**Resultado esperado:**
- ANUM ≥ 70
- Campanha de follow-up parada (motivo: meeting_scheduled)
- Reunião agendada visível
- Histórico mostrando progressão da conversa

### Exemplo 2: Lead Frio (Não Responde)

```bash
node scripts/generate_lead_report.js --contact-id=200
```

**Análise:**
- Verificar última mensagem do lead (há quanto tempo)
- Ver se follow-ups estão sendo enviados
- Identificar se lead está em opt-out
- Verificar se campanha foi pausada

### Exemplo 3: Análise de Custo por Lead

```bash
# Gera JSON e extrai custo total
node scripts/generate_lead_report.js --contact-id=300 --format=json | \
  jq '{
    name: .contact.full_name,
    total_messages: .stats.total_messages,
    total_cost: .stats.total_cost,
    cost_per_message: (.stats.total_cost / .stats.total_messages)
  }'
```

**Output:**
```json
{
  "name": "Maria Santos",
  "total_messages": 45,
  "total_cost": 0.0234,
  "cost_per_message": 0.00052
}
```

---

## 🤝 Contribuindo

Para melhorar o sistema de relatórios:

1. Identifique novos insights úteis
2. Adicione queries em `lead_complete_report.sql`
3. Atualize funções de formatação em `generate_lead_report.js`
4. Documente mudanças neste README

---

## 📞 Suporte

Para dúvidas ou problemas:

1. Verifique este README
2. Consulte `DEEP_DIVE_STUDY_COREADAPT_V4.md` para entender o schema
3. Abra uma issue no repositório
4. Contate o time de desenvolvimento

---

**Última atualização:** 12/11/2025
**Versão:** 1.0.0
**Compatibilidade:** CoreAdapt v4
