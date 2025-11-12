# 📊 Looker Studio + Supabase - Guia Completo (100% GRÁTIS)

## 🎯 Por que Looker Studio é a Melhor Opção

### Vantagens:
- ✅ **100% GRATUITO** (sem limites, sem custos escondidos)
- ✅ **Interface visual** (drag-and-drop, sem código)
- ✅ **Dashboards lindos** (templates profissionais)
- ✅ **Compartilhamento fácil** (como Google Docs)
- ✅ **Colaboração** (múltiplos editores)
- ✅ **Mobile-friendly** (responsivo)
- ✅ **Exporta PDF** (apresentações)
- ✅ **Filtros interativos** (usuário pode filtrar)
- ✅ **Atualização automática** (se configurar certo)

### Desvantagens:
- ❌ Não conecta direto em PostgreSQL/Supabase (precisa de intermediário)
- ❌ Connectors pagos são caros ($99/mês Supermetrics)

---

## 🔌 Opções de Conexão

### Comparação Rápida:

| Opção | Custo | Facilidade | Atualização | Recomendação |
|-------|-------|------------|-------------|--------------|
| **Google Sheets** | 💰 Grátis | ⭐⭐⭐⭐⭐ | Manual/Script | ⭐ **Melhor para começar** |
| **Apps Script + Sheets** | 💰 Grátis | ⭐⭐⭐⭐ | Automática | ⭐ **Melhor solução grátis** |
| **Supermetrics** | 💰 $99/mês | ⭐⭐⭐⭐⭐ | Tempo Real | Caro demais |
| **Cloud SQL Proxy** | 💰 Grátis | ⭐⭐ | Tempo Real | Técnico |
| **Zapier/Make** | 💰 $20-99/mês | ⭐⭐⭐⭐ | Agendada | Alternativa |

---

## 🚀 Método 1: Google Sheets + Manual (Mais Fácil)

### Passo 1: Exportar Dados do Supabase

**No Supabase SQL Editor:**

```sql
-- Query para exportar dados de leads
SELECT
    c.id,
    c.full_name,
    c.email,
    c.whatsapp,
    c.created_at,
    c.opt_out,
    c.is_active,
    c.origin_source,
    c.utm_source,
    c.utm_medium,
    c.utm_campaign,
    ls.total_score AS anum_total,
    ls.authority_score,
    ls.need_score,
    ls.urgency_score,
    ls.money_score,
    ls.qualification_stage,
    ls.is_qualified,
    pc.category_label_pt AS pain_category,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM corev4_scheduled_meetings sm
            WHERE sm.contact_id = c.id
            AND sm.meeting_date > NOW()
        ) THEN 'Sim'
        ELSE 'Não'
    END AS tem_reuniao_agendada
FROM corev4_contacts c
LEFT JOIN corev4_lead_state ls ON c.id = ls.contact_id
LEFT JOIN corev4_pain_categories pc ON ls.main_pain_category_id = pc.id
ORDER BY c.created_at DESC;
```

**Execute → Download CSV**

### Passo 2: Importar para Google Sheets

1. Abra Google Sheets: https://sheets.google.com
2. Criar nova planilha
3. Arquivo → Importar → Upload → Escolha o CSV
4. Importar dados

### Passo 3: Conectar Looker Studio

1. Vá para: https://lookerstudio.google.com
2. Criar → Fonte de Dados
3. Escolha: **Google Sheets**
4. Selecione sua planilha
5. Adicionar

### Passo 4: Criar Dashboard

1. Criar → Relatório
2. Escolha a fonte de dados
3. Arraste e solte componentes:
   - **Scorecard** (KPIs)
   - **Time Series Chart** (gráficos de linha)
   - **Pie Chart** (pizza)
   - **Bar Chart** (barras)
   - **Table** (tabela)
4. Personalize cores, fontes, etc.
5. Compartilhe!

**Atualização:** Manual (re-exportar e importar quando quiser atualizar)

---

## ⚡ Método 2: Apps Script + Automação (MELHOR GRÁTIS!)

### Vantagem:
- ✅ Atualização automática (a cada hora, dia, etc.)
- ✅ 100% gratuito
- ✅ Não precisa re-exportar manualmente

### Passo 1: Criar Google Sheet

1. Abra: https://sheets.google.com
2. Criar nova planilha
3. Nomear: "CoreAdapt - Dados Leads"

### Passo 2: Configurar Apps Script

1. Na planilha: **Extensões → Apps Script**
2. Cole o código abaixo:

```javascript
// ============================================================================
// APPS SCRIPT - Sync Supabase para Google Sheets
// ============================================================================

// CONFIGURAÇÃO - EDITE AQUI!
const SUPABASE_URL = 'https://seu-projeto.supabase.co';
const SUPABASE_KEY = 'sua-service-key-aqui'; // ⚠️ Use service_role key!

// Nome da aba onde os dados serão salvos
const SHEET_NAME = 'Leads';

// ============================================================================
// FUNÇÃO PRINCIPAL
// ============================================================================

function syncSupabaseData() {
  const sheet = getOrCreateSheet(SHEET_NAME);

  // Query SQL para buscar dados
  const query = `
    SELECT
      c.id,
      c.full_name,
      c.email,
      c.whatsapp,
      c.created_at,
      c.opt_out,
      c.is_active,
      c.origin_source,
      c.utm_source,
      c.utm_medium,
      c.utm_campaign,
      ls.total_score AS anum_total,
      ls.authority_score,
      ls.need_score,
      ls.urgency_score,
      ls.money_score,
      ls.qualification_stage,
      ls.is_qualified,
      pc.category_label_pt AS pain_category,
      c.last_interaction_at
    FROM corev4_contacts c
    LEFT JOIN corev4_lead_state ls ON c.id = ls.contact_id
    LEFT JOIN corev4_pain_categories pc ON ls.main_pain_category_id = pc.id
    ORDER BY c.created_at DESC
  `;

  // Executar query no Supabase
  const data = executeSupabaseQuery(query);

  if (!data || data.length === 0) {
    Logger.log('Nenhum dado retornado');
    return;
  }

  // Limpar planilha
  sheet.clear();

  // Headers (primeira linha)
  const headers = Object.keys(data[0]);
  sheet.appendRow(headers);

  // Dados
  data.forEach(row => {
    const values = headers.map(header => row[header] || '');
    sheet.appendRow(values);
  });

  // Formatar
  sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold');
  sheet.setFrozenRows(1);

  Logger.log(`✓ Sincronizado ${data.length} registros`);
}

// ============================================================================
// FUNÇÕES AUXILIARES
// ============================================================================

function executeSupabaseQuery(query) {
  const url = `${SUPABASE_URL}/rest/v1/rpc/execute_sql`;

  const options = {
    method: 'post',
    headers: {
      'apikey': SUPABASE_KEY,
      'Authorization': `Bearer ${SUPABASE_KEY}`,
      'Content-Type': 'application/json'
    },
    payload: JSON.stringify({ query: query }),
    muteHttpExceptions: true
  };

  try {
    const response = UrlFetchApp.fetch(url, options);
    const result = JSON.parse(response.getContentText());
    return result;
  } catch (error) {
    Logger.log('Erro ao executar query: ' + error);
    return null;
  }
}

function getOrCreateSheet(sheetName) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName(sheetName);

  if (!sheet) {
    sheet = ss.insertSheet(sheetName);
  }

  return sheet;
}

// ============================================================================
// AGENDAR EXECUÇÃO AUTOMÁTICA
// ============================================================================

function createTrigger() {
  // Remove triggers antigos
  const triggers = ScriptApp.getProjectTriggers();
  triggers.forEach(trigger => ScriptApp.deleteTrigger(trigger));

  // Criar trigger para executar a cada 1 hora
  ScriptApp.newTrigger('syncSupabaseData')
    .timeBased()
    .everyHours(1)
    .create();

  Logger.log('✓ Trigger criado - sincronização a cada 1 hora');
}

// ============================================================================
// MENU CUSTOMIZADO
// ============================================================================

function onOpen() {
  const ui = SpreadsheetApp.getUi();
  ui.createMenu('CoreAdapt')
    .addItem('🔄 Sincronizar Agora', 'syncSupabaseData')
    .addItem('⏰ Ativar Sincronização Automática', 'createTrigger')
    .addToUi();
}
```

### Passo 3: Configurar Credenciais

No código acima, edite:

```javascript
const SUPABASE_URL = 'https://seu-projeto.supabase.co'; // Sua URL
const SUPABASE_KEY = 'sua-service-key';                  // Sua chave
```

### Passo 4: Executar Primeira Vez

1. No Apps Script: **Executar → syncSupabaseData**
2. Autorize o script (Google vai pedir permissão)
3. Aguarde alguns segundos
4. Volte para a planilha → Dados aparecerão!

### Passo 5: Ativar Sincronização Automática

1. Na planilha: Menu **CoreAdapt → ⏰ Ativar Sincronização Automática**
2. Pronto! Agora atualiza sozinho a cada 1 hora

### Passo 6: Conectar no Looker Studio

Agora conecte normalmente:
1. Looker Studio → Adicionar Fonte de Dados → Google Sheets
2. Escolha a planilha "CoreAdapt - Dados Leads"
3. Criar dashboard!

**Atualização:** Automática a cada 1 hora! 🎉

---

## 🎨 Método 3: Múltiplas Abas para KPIs Diferentes

Crie múltiplas queries para diferentes necessidades:

### Aba 1: "Leads" (Dados Principais)
```javascript
const query = `
  SELECT c.id, c.full_name, c.email, ls.total_score...
  FROM corev4_contacts c...
`;
```

### Aba 2: "Follow-ups" (Performance)
```javascript
const query = `
  SELECT
    fe.step,
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE executed) as executados,
    ROUND(AVG(anum_at_execution), 1) as anum_medio
  FROM corev4_followup_executions fe
  GROUP BY fe.step
  ORDER BY fe.step
`;
```

### Aba 3: "Reuniões" (Meetings)
```javascript
const query = `
  SELECT
    sm.id,
    c.full_name,
    sm.meeting_date,
    sm.status,
    sm.anum_score_at_booking
  FROM corev4_scheduled_meetings sm
  JOIN corev4_contacts c ON sm.contact_id = c.id
  ORDER BY sm.meeting_date DESC
`;
```

Crie uma função para cada aba:
```javascript
function syncLeads() { /* ... */ }
function syncFollowups() { /* ... */ }
function syncMeetings() { /* ... */ }

function syncAll() {
  syncLeads();
  syncFollowups();
  syncMeetings();
}
```

---

## 📊 Templates de Dashboard no Looker Studio

### Template 1: Visão Executiva

**Componentes:**
1. **Scorecards** (topo):
   - Total de Leads
   - ANUM Médio
   - Taxa de Qualificação
   - Reuniões Agendadas

2. **Time Series** (linha):
   - Leads por Mês

3. **Pie Charts**:
   - Leads por Estágio ANUM
   - Origem de Leads (UTM)

4. **Table** (tabela):
   - Top 10 Leads por Score

### Template 2: Performance de Follow-ups

**Componentes:**
1. **Bar Chart**:
   - Follow-ups por Passo

2. **Line Chart**:
   - Taxa de Execução ao Longo do Tempo

3. **Pie Chart**:
   - Razões de Parada

### Template 3: Análise Financeira

**Componentes:**
1. **Scorecards**:
   - Custo Total (USD)
   - Custo por Lead

2. **Scatter Chart**:
   - Custo vs ANUM Score

3. **Table**:
   - Leads Mais Caros

---

## 💡 Dicas Importantes

### 1. Segurança

⚠️ **IMPORTANTE:** A `SUPABASE_KEY` fica visível no código do Apps Script!

**Solução:**
- Use uma chave READ-ONLY (crie no Supabase)
- Ou use PropertiesService:

```javascript
// Configurar 1 vez:
PropertiesService.getScriptProperties().setProperty('SUPABASE_KEY', 'sua-chave');

// Usar:
const SUPABASE_KEY = PropertiesService.getScriptProperties().getProperty('SUPABASE_KEY');
```

### 2. Performance

- Limite queries a dados relevantes (últimos 6 meses, etc.)
- Use `WHERE created_at > NOW() - INTERVAL '6 months'`
- Não puxe TODO o histórico de mensagens (pode ter milhões)

### 3. Agendamento

Apps Script tem limites:
- Máximo 30 execuções/hora
- Máximo 6 minutos por execução
- Para queries muito grandes, considere dividir em múltiplas abas

### 4. Looker Studio Tips

**Filtros Interativos:**
- Adicione filtros de data
- Filtros por estágio ANUM
- Filtros por origem (UTM)

**Campos Calculados:**
No Looker Studio, você pode criar campos calculados:
```
CASE
  WHEN anum_total >= 70 THEN "Qualified"
  WHEN anum_total >= 30 THEN "Developing"
  ELSE "Pre-qualified"
END
```

**Drill-down:**
- Clique em um lead no gráfico → Abre detalhes

---

## 🎯 Comparação Final: Looker Studio vs Outros

| Critério | Looker Studio | Superset | Grafana | Metabase |
|----------|---------------|----------|---------|----------|
| **Custo** | 💰 **GRÁTIS** | $5-20/mês | $0-50/mês | $85/mês |
| **Facilidade** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Visual** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Conexão Supabase** | ❌ (precisa intermediário) | ✅ Direto | ✅ Direto | ✅ Direto |
| **Tempo Real** | ⚠️ Depende | ✅ Sim | ✅ Sim | ✅ Sim |
| **Compartilhamento** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Mobile** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |

**Veredicto:**
- **Use Looker Studio** se: Quer grátis, visual lindo, e não liga para atualização manual/agendada
- **Use Superset** se: Precisa de conexão direta e tempo real ($5/mês)
- **Use Grafana** se: Quer alertas e monitoramento em tempo real

---

## 🚀 Próximos Passos

1. **Testar método manual primeiro:**
   - Exportar CSV
   - Importar no Sheets
   - Criar dashboard básico no Looker Studio
   - Ver se gosta da interface

2. **Se gostar, automatizar:**
   - Configurar Apps Script
   - Agendar sincronização automática
   - Refinar dashboard

3. **Expandir:**
   - Criar múltiplas abas (Leads, Follow-ups, Reuniões)
   - Adicionar mais KPIs
   - Compartilhar com equipe

---

## 📚 Links Úteis

- **Looker Studio:** https://lookerstudio.google.com
- **Apps Script Docs:** https://developers.google.com/apps-script
- **Looker Studio Gallery:** https://lookerstudio.google.com/gallery (templates gratuitos)
- **Comunidade Looker Studio:** https://support.google.com/looker-studio/community

---

**Próximo:** Vou criar queries SQL otimizadas para Looker Studio (formato mais simples, sem UNION complexo).
