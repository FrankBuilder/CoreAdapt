# Plano de Implementação CoreAdapt Proativo

**Data:** 2026-01-05
**Objetivo:** Colocar o sistema de pé de forma ordenada e eficiente

---

## Visão Geral da Arquitetura

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        COREADAPT - ARQUITETURA 2026                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ENTRADA DE LEADS                                                           │
│  ───────────────                                                            │
│                                                                              │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                   │
│  │ Google Maps │     │  LinkedIn   │     │  WhatsApp   │                   │
│  │   (API)     │     │  (Unipile)  │     │  (Inbound)  │                   │
│  └──────┬──────┘     └──────┬──────┘     └──────┬──────┘                   │
│         │                   │                   │                          │
│         ▼                   ▼                   ▼                          │
│  ┌─────────────────────────────────┐     ┌─────────────┐                   │
│  │       corev4_prospects          │     │ corev4_     │                   │
│  │       (leads outbound)          │     │ contacts    │                   │
│  └──────────────┬──────────────────┘     └──────┬──────┘                   │
│                 │                               │                          │
│                 ▼                               │                          │
│  ┌─────────────────────────────────┐            │                          │
│  │     VALIDAÇÃO & WARMUP          │            │                          │
│  │  • Verifica WhatsApp            │            │                          │
│  │  • Limpa duplicados             │            │                          │
│  │  • Controla volume diário       │            │                          │
│  └──────────────┬──────────────────┘            │                          │
│                 │                               │                          │
│                 ▼                               │                          │
│  ┌─────────────────────────────────┐            │                          │
│  │     FIRST TOUCH (Opt-in)        │            │                          │
│  │  • Envia mensagem inicial       │            │                          │
│  │  • Botões interativos           │            │                          │
│  │  • Registra consentimento       │            │                          │
│  └──────────────┬──────────────────┘            │                          │
│                 │                               │                          │
│         ┌───────┴───────┐                       │                          │
│         ▼               ▼                       │                          │
│    [Opt-in]        [Opt-out]                    │                          │
│         │               │                       │                          │
│         │               ▼                       │                          │
│         │        ┌─────────────┐                │                          │
│         │        │  Blocklist  │                │                          │
│         │        └─────────────┘                │                          │
│         │                                       │                          │
│         ▼                                       │                          │
│  ┌─────────────────────────────────┐            │                          │
│  │     HANDOFF → FRANK             │◀───────────┘                          │
│  │  • Converte prospect → contact  │                                       │
│  │  • Inicia conversa com FRANK    │                                       │
│  └──────────────┬──────────────────┘                                       │
│                 │                                                          │
│                 ▼                                                          │
│  ┌─────────────────────────────────┐                                       │
│  │     FRANK (CoreOne)             │                                       │
│  │  • Qualifica (ANUM)             │                                       │
│  │  • Conversa natural             │                                       │
│  │  • Identifica momento           │                                       │
│  └──────────────┬──────────────────┘                                       │
│                 │                                                          │
│                 ▼                                                          │
│  ┌─────────────────────────────────┐                                       │
│  │     AGENDAMENTO AUTÔNOMO        │                                       │
│  │  • Consulta Google Calendar     │                                       │
│  │  • Oferece 3 horários           │                                       │
│  │  • Cria evento + Meet           │                                       │
│  └─────────────────────────────────┘                                       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Ordem de Implementação

### FASE 0: Fundação (Hoje)
**Objetivo:** Garantir que a base está sólida

| # | Tarefa | Comando/Ação | Status |
|---|--------|--------------|--------|
| 0.1 | Rodar migração dos campos faltantes | `migrations/alter_prospects_add_fields.sql` | ⬜ |
| 0.2 | Rodar migração calendar_settings | `migrations/create_calendar_settings_table.sql` | ⬜ |
| 0.3 | Rodar migração pending_slot_offers | `migrations/create_pending_slot_offers_table.sql` | ⬜ |
| 0.4 | Verificar Evolution API funcionando | Testar envio de mensagem | ⬜ |
| 0.5 | Verificar n8n funcionando | Acessar interface | ⬜ |

---

### FASE 1: Prospecção (Dias 1-3)
**Objetivo:** Conseguir formar listas de prospects

#### 1.1 Prospector Flow (Google Maps)
**Você já tem:** `Agente Prospect Busca Google Maps.json`

**Ajustes necessários:**
- [ ] Salvar em `corev4_prospects` (não Google Sheets)
- [ ] Preencher todos os novos campos (endereço, cidade, etc)
- [ ] Adicionar deduplicação por telefone
- [ ] Vincular a uma campanha

**Input:**
```json
{
  "search_query": "dentistas em Fortaleza",
  "company_id": 1,
  "campaign_id": 1,
  "max_results": 50
}
```

**Output esperado:** Prospects no banco com status `new`

#### 1.2 List Cleaner Flow (Novo)
**Objetivo:** Validar e limpar a lista

**Passos:**
1. Buscar prospects com status `new`
2. Normalizar telefone (formato E.164)
3. Verificar se tem WhatsApp (Evolution API `checkNumber`)
4. Verificar se não está na blocklist
5. Verificar se não é duplicado
6. Atualizar `validation_status`

**Output:** Prospects com status `valid` ou `invalid`

---

### FASE 2: Warmup & Envio (Dias 4-6)
**Objetivo:** Enviar first touch de forma segura

#### 2.1 Warmup Controller Flow (Novo)
**Objetivo:** Controlar volume diário

**Lógica:**
```
Dia 1-3:   50 mensagens/dia
Dia 4-7:   100 mensagens/dia
Dia 8-10:  250 mensagens/dia
Dia 11-14: 500 mensagens/dia
Dia 15+:   1000 mensagens/dia
```

**Tabela:** `corev4_warmup_status`

#### 2.2 First Touch Flow (Novo)
**Objetivo:** Enviar mensagem inicial com opt-in

**Mensagem com botões:**
```
Olá {nome}! 👋

Vi que você tem uma {tipo_negocio} em {cidade}.

Sou da CoreConnect e ajudamos {tipo_negocio}s a automatizar
o atendimento no WhatsApp.

Posso te mostrar como funciona em 2 minutos?

[✅ Quero ver] [❌ Não, obrigado]
```

**Evolution API - Botões:**
```json
{
  "number": "5511999999999",
  "options": {
    "delay": 1200,
    "presence": "composing"
  },
  "buttonMessage": {
    "title": "CoreConnect",
    "description": "Automação de WhatsApp",
    "footerText": "Responda para saber mais",
    "buttons": [
      {"buttonText": {"displayText": "✅ Quero ver"}, "buttonId": "opt_in"},
      {"buttonText": {"displayText": "❌ Não, obrigado"}, "buttonId": "opt_out"}
    ]
  }
}
```

#### 2.3 Opt-in Handler Flow (Novo)
**Objetivo:** Processar resposta do first touch

**Se opt-in:**
1. Registrar em `corev4_consent_log`
2. Criar `corev4_contact` a partir do prospect
3. Atualizar prospect: `status = 'converted'`
4. Iniciar conversa com FRANK

**Se opt-out:**
1. Registrar em `corev4_consent_log`
2. Adicionar à `corev4_blocklist`
3. Atualizar prospect: `status = 'opted_out'`

---

### FASE 3: Integração com FRANK (Dias 7-9)
**Objetivo:** Conectar prospecção ao sistema atual

#### 3.1 Handoff Flow (Novo)
**Objetivo:** Converter prospect em contact e iniciar FRANK

**Passos:**
1. Receber evento de opt-in
2. Criar registro em `corev4_contacts` com `origin = 'outbound'`
3. Copiar dados do prospect
4. Criar `corev4_lead_state` inicial
5. Enviar primeira mensagem do FRANK
6. Criar campanha de follow-up

#### 3.2 Ajustar Main Router
**Objetivo:** FRANK precisa identificar se lead veio de outbound

**Lógica adicional:**
- Se `contact.origin = 'outbound'`: usar prompt específico
- Contexto: "Este lead veio de prospecção ativa sobre {business_type}"

---

### FASE 4: Agendamento Autônomo (Dias 10-12)
**Objetivo:** FRANK agenda diretamente no Google Calendar

#### 4.1 Configurar Google Calendar API
1. Criar projeto no Google Cloud
2. Habilitar Calendar API
3. Criar Service Account
4. Compartilhar calendário com Service Account
5. Salvar credenciais em `corev4_calendar_settings`

#### 4.2 Slot Finder Flow (Novo)
**Objetivo:** Encontrar horários disponíveis

**Passos:**
1. Chamar `freeBusy` do Google Calendar
2. Filtrar por horário comercial
3. Aplicar regras de buffer
4. Calcular score de cada slot
5. Retornar top 3 slots

#### 4.3 Slot Offer Flow (Novo)
**Objetivo:** Oferecer horários ao lead

**Mensagem:**
```
Legal! Deixa eu ver a agenda do Francisco...

Temos essas opções:
1️⃣ Terça, 07/01 às 10:00
2️⃣ Quarta, 08/01 às 14:00
3️⃣ Quinta, 09/01 às 11:00

Qual funciona melhor? (responde 1, 2 ou 3)
```

#### 4.4 Booking Creator Flow (Novo)
**Objetivo:** Criar evento no Google Calendar

**Passos:**
1. Parsear resposta do lead
2. Verificar slot ainda disponível
3. Criar evento via `events.insert`
4. Gerar link do Google Meet
5. Salvar em `corev4_scheduled_meetings`
6. Enviar confirmação ao lead

---

### FASE 5: Analytics & Dashboard (Dias 13-15)
**Objetivo:** Visualizar performance

#### 5.1 Configurar Looker Studio
- Conectar ao Supabase
- Criar views de analytics
- Montar dashboards

#### 5.2 Métricas a Acompanhar
- Taxa de entrega
- Taxa de opt-in
- Taxa de qualificação
- Taxa de agendamento
- Taxa de comparecimento

---

## Checklist de Execução

### Hoje (05/01)
```
[ ] Rodar: migrations/alter_prospects_add_fields.sql
[ ] Rodar: migrations/create_calendar_settings_table.sql
[ ] Rodar: migrations/create_pending_slot_offers_table.sql
[ ] Testar Evolution API (enviar msg de teste)
[ ] Verificar n8n está rodando
```

### Amanhã (06/01)
```
[ ] Ajustar Prospector Flow para salvar no banco
[ ] Testar busca no Google Maps
[ ] Criar List Cleaner Flow
```

### Depois de Amanhã (07/01)
```
[ ] Criar Warmup Controller Flow
[ ] Criar First Touch Flow
[ ] Testar envio com botões
```

---

## Fluxos Existentes vs Novos

### Existentes (Ajustar)
| Fluxo | Arquivo | Ajuste Necessário |
|-------|---------|-------------------|
| Prospector | `Agente Prospect Busca Google Maps.json` | Salvar em DB |
| Main Router | existente | Identificar origem outbound |
| FRANK | existente | Prompt para outbound |

### Novos (Criar)
| Fluxo | Prioridade | Complexidade |
|-------|------------|--------------|
| List Cleaner | Alta | Baixa |
| Warmup Controller | Alta | Média |
| First Touch | Alta | Média |
| Opt-in Handler | Alta | Baixa |
| Handoff | Alta | Média |
| Slot Finder | Média | Alta |
| Slot Offer | Média | Média |
| Booking Creator | Média | Alta |

---

## APIs Necessárias

| API | Uso | Status |
|-----|-----|--------|
| Evolution API | WhatsApp | ✅ Configurada |
| Google Maps (RapidAPI) | Prospecção | ⬜ Verificar |
| Unipile | LinkedIn | ⬜ Configurar |
| Google Calendar | Agendamento | ⬜ Configurar |
| Scraptio | Enriquecimento | ⬜ Verificar |

---

## Próximo Passo Imediato

**1. Rodar as migrações:**

```sql
-- No Supabase SQL Editor, executar em ordem:

-- 1. Campos faltantes no prospects
-- (conteúdo de migrations/alter_prospects_add_fields.sql)

-- 2. Calendar settings
-- (conteúdo de migrations/create_calendar_settings_table.sql)

-- 3. Pending slot offers
-- (conteúdo de migrations/create_pending_slot_offers_table.sql)
```

**2. Me dizer qual fluxo você quer começar primeiro.**

---

*Documento criado em 2026-01-05*
