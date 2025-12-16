# CoreAdapt Proativo — Arquitetura Completa

**Versão:** 1.0 (Proposta)
**Data:** 2025-12-15
**Status:** Aguardando Aprovação

---

## Índice

1. [Visão Geral](#visão-geral)
2. [Arquitetura Unificada CoreAdapt](#arquitetura-unificada)
3. [Padrões Gold-Standard de Outbound](#gold-standard)
4. [Fluxos Propostos](#fluxos-propostos)
5. [Integração Google Calendar Direta](#google-calendar)
6. [Mensagens Interativas (Botões)](#botões)
7. [Tabelas de Banco de Dados](#banco-dados)
8. [Cronograma de Implementação](#cronograma)

---

## 1. Visão Geral {#visão-geral}

### O que é CoreAdapt Proativo?

| Aspecto | CoreAdapt Receptivo (Atual) | CoreAdapt Proativo (Novo) |
|---------|----------------------------|---------------------------|
| **Iniciador** | Lead inicia conversa | Sistema inicia conversa |
| **Fonte de leads** | Tráfego pago, orgânico | Listas (Sheets, CRM, CSV) |
| **Primeiro contato** | Mensagem do lead | Mensagem com botões |
| **Opt-in** | Implícito (lead veio) | Explícito (botão de aceite) |
| **Objetivo** | Qualificar → Agendar | Engajar → Qualificar → Agendar |
| **Compliance** | Simples | LGPD rigoroso |

### Benefícios Esperados

- **Reativação de base fria:** 15-25% de engajamento
- **Custo por lead qualificado:** -60% vs SDR humano
- **Velocidade:** 1000+ contatos/dia vs 50/dia (SDR)
- **Consistência:** 100% seguem script, sem variação

---

## 2. Arquitetura Unificada CoreAdapt {#arquitetura-unificada}

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           COREADAPT UNIFIED PLATFORM                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────┐    ┌─────────────────────────────┐         │
│  │    RECEPTIVO (Inbound)      │    │    PROATIVO (Outbound)      │         │
│  │                             │    │                             │         │
│  │  • Lead inicia conversa     │    │  • Sistema inicia conversa  │         │
│  │  • Qualificação ANUM        │    │  • Opt-in com botões        │         │
│  │  • Agendamento autônomo     │    │  • Nutrição por campanha    │         │
│  │  • Follow-up (Sentinel)     │    │  • Qualificação progressiva │         │
│  │                             │    │                             │         │
│  └─────────────┬───────────────┘    └─────────────┬───────────────┘         │
│                │                                  │                          │
│                └──────────────┬───────────────────┘                          │
│                               │                                              │
│                               ▼                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                        CORE COMPARTILHADO                            │    │
│  │                                                                      │    │
│  │  • FRANK (Agente de Conversa)                                       │    │
│  │  • Sync Flow (ANUM Scoring)                                         │    │
│  │  • Google Calendar Integration (Agendamento)                        │    │
│  │  • Evolution API (WhatsApp)                                         │    │
│  │  • Database (Supabase)                                              │    │
│  │                                                                      │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Separação de Responsabilidades

| Componente | Receptivo | Proativo | Compartilhado |
|------------|-----------|----------|---------------|
| Main Router | ✅ | | |
| Genesis Flow | ✅ | | |
| One Flow (FRANK) | | | ✅ |
| Sync Flow (ANUM) | | | ✅ |
| Sentinel Flow | ✅ | | |
| **Campaign Orchestrator** | | ✅ | |
| **List Manager** | | ✅ | |
| **Warmup Engine** | | ✅ | |
| **Opt-in Handler** | | ✅ | |
| **Nurture Engine** | | ✅ | |
| Availability Flow | | | ✅ |
| Booking Flow | | | ✅ |
| Meeting Reminders | | | ✅ |

---

## 3. Padrões Gold-Standard de Outbound {#gold-standard}

### 3.1 Ciclo de Vida de Lista

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                    CICLO DE VIDA DE LISTA (GOLD STANDARD)                    │
├──────────────────────────────────────────────────────────────────────────────┤

  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
  │  IMPORTAR   │ ───► │  VALIDAR    │ ───► │  AQUECER    │ ───► │  PROSPECTAR │
  │  (Import)   │      │  (Validate) │      │  (Warm-up)  │      │  (Prospect) │
  └─────────────┘      └─────────────┘      └─────────────┘      └─────────────┘
        │                    │                    │                    │
        ▼                    ▼                    ▼                    ▼
  • Google Sheets      • Números válidos    • HSM template       • Mensagem c/
  • CSV upload         • Duplicatas         • Gradual ramp-up      botões
  • API CRM            • Opt-out prévio     • 50→100→500/dia     • Opt-in/out
  • Manual entry       • Formato correto    • Monitor delivery   • Nurture flow

                                                                       │
       ┌───────────────────────────────────────────────────────────────┘
       │
       ▼
  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
  │   NUTRIR    │ ───► │  QUALIFICAR │ ───► │  CONVERTER  │
  │  (Nurture)  │      │  (Qualify)  │      │  (Convert)  │
  └─────────────┘      └─────────────┘      └─────────────┘
        │                    │                    │
        ▼                    ▼                    ▼
  • Conteúdo valor     • ANUM scoring        • Agendamento
  • Cadência definida  • Pain discovery        autônomo
  • Multi-touchpoint   • Budget/Authority   • Mesa de Clareza
  • Exit automático    • Handoff p/ FRANK   • Close

                              │
                              ▼
                    ┌─────────────────────┐
                    │      LIMPAR         │
                    │     (Cleanup)       │
                    └─────────────────────┘
                              │
                              ▼
                    • Opt-outs removidos
                    • Bounces excluídos
                    • Inativos arquivados
                    • Lista pronta p/ próximo ciclo
```

### 3.2 Métricas de Referência (Benchmarks)

| Métrica | Benchmark Ruim | Benchmark Médio | Benchmark Bom | Gold Standard |
|---------|----------------|-----------------|---------------|---------------|
| **Taxa de entrega** | <80% | 80-90% | 90-95% | >95% |
| **Taxa de leitura** | <20% | 20-40% | 40-60% | >60% |
| **Taxa de resposta** | <5% | 5-10% | 10-20% | >20% |
| **Taxa de opt-out** | >10% | 5-10% | 2-5% | <2% |
| **Taxa de conversão** | <1% | 1-3% | 3-5% | >5% |

### 3.3 Regras de Compliance (LGPD/GDPR)

| Requisito | Implementação |
|-----------|---------------|
| **Consentimento prévio** | Botão de opt-in obrigatório antes de nutrição |
| **Opt-out fácil** | Botão "Não tenho interesse" em TODA mensagem |
| **Registro de consentimento** | Timestamp + IP + device de cada opt-in/out |
| **Direito ao esquecimento** | Comando #apagar para remover todos os dados |
| **Transparência** | Identificar claramente quem está enviando |

---

## 4. Fluxos Propostos {#fluxos-propostos}

### 4.1 Mapa Completo de Fluxos

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        FLUXOS COREADAPT PROATIVO (10)                        │
├─────────────────────────────────────────────────────────────────────────────┤

GESTÃO DE LISTAS (3 fluxos)
├── 1. List Import Flow .............. Importa listas do Google Sheets/CSV
├── 2. List Validation Flow .......... Valida números, remove duplicatas
└── 3. List Cleanup Flow ............. Remove opt-outs, bounces, inativos

AQUECIMENTO (2 fluxos)
├── 4. Warmup Scheduler Flow ......... Agenda envios graduais (ramp-up)
└── 5. Warmup Monitor Flow ........... Monitora taxas e ajusta volume

PROSPECÇÃO (3 fluxos)
├── 6. Campaign Orchestrator Flow .... Orquestra campanhas proativas
├── 7. First Touch Flow .............. Envia mensagem inicial c/ botões
└── 8. Opt-in Handler Flow ........... Processa respostas de botões

NUTRIÇÃO (2 fluxos)
├── 9. Nurture Engine Flow ........... Executa sequências de nutrição
└── 10. Handoff Flow ................. Transfere para FRANK quando engajado

COMPARTILHADOS (já existem)
├── One Flow (FRANK) ................. Conversa qualificatória
├── Sync Flow ....................... ANUM scoring
├── Availability Flow ............... Consulta agenda
└── Booking Flow .................... Cria agendamento
```

### 4.2 Detalhamento de Cada Fluxo

---

#### **FLUXO 1: List Import Flow**

**Função:** Importar leads de fontes externas para o sistema

**Triggers:**
- Webhook (API externa)
- Cron (sync periódico com Sheets)
- Manual (upload de CSV)

**Fontes Suportadas:**
- Google Sheets (via API)
- Google Docs (estruturado)
- CSV upload
- API de CRM (futura)

**Processo:**
```
Google Sheets/CSV
      │
      ▼
┌─────────────────┐
│ Parse: Extract  │
│ Rows            │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Transform:      │
│ Normalize Data  │
│ • Phone format  │
│ • Name cleanup  │
│ • Source tag    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Load: Insert    │
│ corev4_prospects│
│ (status=new)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Trigger: List   │
│ Validation Flow │
└─────────────────┘
```

**Campos Mapeados:**
| Google Sheets | Campo Interno | Obrigatório |
|---------------|---------------|-------------|
| Nome | full_name | ✅ |
| Telefone | phone_number | ✅ |
| Email | email | ❌ |
| Empresa | company_name | ❌ |
| Cargo | job_title | ❌ |
| Origem | source_tag | ✅ (auto) |
| Notas | notes | ❌ |

---

#### **FLUXO 2: List Validation Flow**

**Função:** Validar e limpar lista antes de prospecção

**Triggers:**
- Após List Import Flow
- Cron diário (revalidação)
- Manual

**Validações:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PIPELINE DE VALIDAÇÃO                                │
├─────────────────────────────────────────────────────────────────────────────┤

  ┌───────────────┐
  │ 1. FORMAT     │ • Telefone: 13 dígitos (5511999999999)
  │    CHECK      │ • Nome: Mínimo 2 caracteres
  │               │ • Email: Regex válido (se presente)
  └───────┬───────┘
          │
          ▼
  ┌───────────────┐
  │ 2. DUPLICATE  │ • Mesmo telefone já existe?
  │    CHECK      │ • Mesmo email já existe?
  │               │ • Merge ou skip
  └───────┬───────┘
          │
          ▼
  ┌───────────────┐
  │ 3. OPT-OUT    │ • Está em lista de opt-out global?
  │    CHECK      │ • Já fez opt-out em outra campanha?
  │               │ • Blocklist do WhatsApp?
  └───────┬───────┘
          │
          ▼
  ┌───────────────┐
  │ 4. WHATSAPP   │ • Número existe no WhatsApp?
  │    CHECK      │ • (Via Evolution API checkNumbers)
  │               │ • Profile picture disponível?
  └───────┬───────┘
          │
          ▼
  ┌───────────────┐
  │ 5. SCORE      │ • Calcular prospect_score (0-100)
  │    ASSIGN     │ • Priorizar por potencial
  │               │ • Categorizar tier (A/B/C)
  └───────────────┘
```

**Status Resultantes:**
| Status | Descrição | Ação |
|--------|-----------|------|
| `valid` | Passou todas validações | Pode prospectar |
| `invalid_format` | Formato incorreto | Corrigir ou excluir |
| `duplicate` | Já existe no sistema | Merge ou skip |
| `opted_out` | Já fez opt-out antes | Não contatar |
| `no_whatsapp` | Número não tem WhatsApp | Excluir |
| `pending_validation` | Aguardando check WhatsApp | Retry |

---

#### **FLUXO 3: List Cleanup Flow**

**Função:** Manter higiene das listas (executar periodicamente)

**Triggers:**
- Cron semanal
- Manual
- Após campanha finalizar

**Ações:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CLEANUP ACTIONS                                    │
├─────────────────────────────────────────────────────────────────────────────┤

1. REMOVE OPT-OUTS
   • Mover para tabela de blocklist
   • Registrar motivo e data
   • Nunca mais contatar

2. ARCHIVE BOUNCES
   • Números que não entregaram 3x
   • Marcar como `delivery_failed`
   • Revisar manualmente se necessário

3. ARCHIVE INACTIVE
   • Sem interação há 90+ dias
   • Mover para `cold_archive`
   • Pode reativar em 6 meses

4. UPDATE SCORES
   • Recalcular prospect_score
   • Baseado em engajamento recente
   • Repriorizar tiers

5. GENERATE REPORT
   • Total removidos por categoria
   • Taxa de limpeza
   • Qualidade da lista restante
```

---

#### **FLUXO 4: Warmup Scheduler Flow**

**Função:** Aquecer número/instância antes de volume alto

**Por que aquecer?**
- WhatsApp monitora comportamento
- Envios em massa = risco de ban
- Ramp-up gradual = confiança

**Estratégia de Warmup:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        WARMUP SCHEDULE (14 DIAS)                             │
├─────────────────────────────────────────────────────────────────────────────┤

DIA 1-3:   50 mensagens/dia  ████░░░░░░░░░░░░░░░░
DIA 4-5:   100 mensagens/dia ████████░░░░░░░░░░░░
DIA 6-7:   200 mensagens/dia ████████████░░░░░░░░
DIA 8-10:  350 mensagens/dia ████████████████░░░░
DIA 11-12: 500 mensagens/dia ████████████████████
DIA 13-14: 750 mensagens/dia ████████████████████████████
DIA 15+:   1000 mensagens/dia (máximo sustentável)

REGRAS:
• Nunca aumentar >50% de um dia pro outro
• Se taxa de entrega cair <90%, reduzir 50%
• Pausar se receber warning do WhatsApp
• Distribuir envios ao longo do dia (não burst)
```

**Métricas Monitoradas:**
| Métrica | Threshold Verde | Threshold Amarelo | Threshold Vermelho |
|---------|-----------------|-------------------|-------------------|
| Taxa de entrega | >95% | 90-95% | <90% |
| Taxa de bloqueio | <0.5% | 0.5-2% | >2% |
| Taxa de report | <0.1% | 0.1-0.5% | >0.5% |

---

#### **FLUXO 5: Warmup Monitor Flow**

**Função:** Monitorar saúde do número e ajustar volume

**Triggers:**
- Cron a cada 4 horas
- Após cada batch de envios
- Alerta de erro

**Dashboard de Saúde:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       INSTANCE HEALTH DASHBOARD                              │
├─────────────────────────────────────────────────────────────────────────────┤

Instance: francisco-pasteur-coreadapt
Status: 🟢 HEALTHY

┌──────────────────┬──────────────────┬──────────────────┐
│   DELIVERY RATE  │   RESPONSE RATE  │   OPT-OUT RATE   │
│      96.5%       │      18.3%       │      1.2%        │
│   🟢 Excellent   │   🟢 Good        │   🟢 Normal      │
└──────────────────┴──────────────────┴──────────────────┘

Volume Today: 342 / 500 (daily limit)
Volume This Week: 1,847 / 3,500

Recommendations:
✅ Continue at current pace
✅ Ready to increase to 600/day tomorrow
```

**Ações Automáticas:**
| Condição | Ação |
|----------|------|
| Delivery <90% | Reduzir volume 50%, alertar admin |
| Bloqueios >2% | Pausar envios, investigar |
| Reports >0.5% | Pausar imediatamente, revisar mensagem |
| Tudo verde por 3 dias | Aumentar volume 25% |

---

#### **FLUXO 6: Campaign Orchestrator Flow**

**Função:** Orquestrar campanhas proativas de ponta a ponta

**Estrutura de Campanha:**
```json
{
  "campaign_id": "camp_2025_q1_reativacao",
  "name": "Reativação Q1 2025",
  "type": "proactive_outbound",
  "status": "active",

  "list": {
    "source": "google_sheets",
    "sheet_id": "1abc...",
    "total_contacts": 2500,
    "validated": 2100,
    "pending": 400
  },

  "schedule": {
    "start_date": "2025-01-15",
    "end_date": "2025-02-15",
    "daily_limit": 500,
    "send_hours": ["09:00-12:00", "14:00-18:00"],
    "send_days": ["mon", "tue", "wed", "thu", "fri"]
  },

  "first_touch": {
    "message_template": "first_touch_v1",
    "buttons": ["Quero saber mais", "Não tenho interesse"]
  },

  "nurture_sequence": [
    {"step": 1, "delay_hours": 24, "template": "value_case_study"},
    {"step": 2, "delay_hours": 72, "template": "pain_point_deep"},
    {"step": 3, "delay_hours": 168, "template": "offer_mesa"}
  ],

  "goals": {
    "target_opt_in_rate": 0.15,
    "target_qualified_rate": 0.05,
    "target_meetings": 50
  }
}
```

---

#### **FLUXO 7: First Touch Flow**

**Função:** Enviar primeira mensagem com botões interativos

**Mensagem Inicial (Exemplo):**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        PRIMEIRA MENSAGEM (HSM)                               │
├─────────────────────────────────────────────────────────────────────────────┤

Olá {{nome}}! 👋

Sou Frank da CoreConnect.AI.

Empresas como a sua estão economizando 70% do tempo
que gastavam qualificando leads manualmente.

Posso te mostrar como funciona em 2 minutos?

┌─────────────────────────────────────────┐
│  ✅ Quero saber mais                    │
├─────────────────────────────────────────┤
│  ❌ Não tenho interesse                 │
└─────────────────────────────────────────┘
```

**Implementação via Evolution API:**
```javascript
// Enviar mensagem com botões (Quick Reply)
const payload = {
  number: "5511999999999",
  options: {
    delay: 1200,
    presence: "composing"
  },
  buttonMessage: {
    title: "CoreConnect.AI",
    description: "Olá {{nome}}! 👋\n\nSou Frank da CoreConnect.AI...",
    buttons: [
      { buttonId: "opt_in", buttonText: { displayText: "✅ Quero saber mais" }},
      { buttonId: "opt_out", buttonText: { displayText: "❌ Não tenho interesse" }}
    ]
  }
};

// POST {{evolution_api_url}}/message/sendButtons/{{instance}}
```

---

#### **FLUXO 8: Opt-in Handler Flow**

**Função:** Processar respostas aos botões

**Estados Possíveis:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ESTADOS DE RESPOSTA                                   │
├─────────────────────────────────────────────────────────────────────────────┤

RESPOSTA           │ AÇÃO                          │ PRÓXIMO PASSO
───────────────────┼───────────────────────────────┼─────────────────────
"opt_in" (botão)   │ Registrar consentimento       │ Nurture Sequence
                   │ Atualizar status = opted_in   │ ou Handoff p/ FRANK
───────────────────┼───────────────────────────────┼─────────────────────
"opt_out" (botão)  │ Registrar opt-out             │ Nunca mais contatar
                   │ Atualizar status = opted_out  │ Mover p/ blocklist
───────────────────┼───────────────────────────────┼─────────────────────
Texto livre        │ Analisar intenção             │ Depende do conteúdo:
                   │ (positivo/negativo/neutro)    │ • Positivo → Handoff
                   │                               │ • Negativo → Opt-out
                   │                               │ • Neutro → Retry
───────────────────┼───────────────────────────────┼─────────────────────
Sem resposta (48h) │ Marcar como no_response       │ 1 retry depois de 7d
                   │                               │ Se 2x sem resposta →
                   │                               │ Arquivar
```

**Registro de Consentimento (LGPD):**
```sql
INSERT INTO corev4_consent_log (
  contact_id,
  consent_type,      -- 'opt_in' ou 'opt_out'
  consent_source,    -- 'button_click', 'text_message', 'manual'
  campaign_id,
  message_id,        -- ID da mensagem que gerou
  timestamp,
  ip_address,        -- Se disponível
  device_info        -- Se disponível
) VALUES (...);
```

---

#### **FLUXO 9: Nurture Engine Flow**

**Função:** Executar sequências de nutrição após opt-in

**Diferença de Sentinel:**
| Aspecto | Sentinel (Receptivo) | Nurture Engine (Proativo) |
|---------|---------------------|---------------------------|
| Trigger | Lead parou de responder | Lead fez opt-in |
| Objetivo | Reengajar | Educar e qualificar |
| Tom | Recuperação | Valor primeiro |
| Personalização | Por ANUM | Por estágio da jornada |
| Exit | Resposta ou exaustão | Qualificado ou opt-out |

**Sequência de Nutrição Típica:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     SEQUÊNCIA DE NUTRIÇÃO (5 TOUCHES)                        │
├─────────────────────────────────────────────────────────────────────────────┤

TOUCH 1: Welcome + Quick Value (T+0)
├── "Ótimo que você quer saber mais! Aqui está um caso..."
├── Enviar: Link de case study ou vídeo curto
└── Botão: "Me conta seu cenário" / "Depois vejo"

TOUCH 2: Pain Discovery (T+24h)
├── "Empresas como [similar] tinham o mesmo problema..."
├── Pergunta aberta: "Como você lida com [pain point] hoje?"
└── Se responder → Handoff para FRANK

TOUCH 3: Social Proof (T+72h)
├── "Olha o que [cliente] conseguiu em 30 dias..."
├── Números específicos: "70% menos tempo, 40% mais conversão"
└── Botão: "Quero ver meu ROI" / "Ainda não"

TOUCH 4: Direct Offer (T+168h, 1 semana)
├── "Temos uma Mesa de Clareza gratuita..."
├── Apresentar valor: 45min, sem compromisso, com fundador
└── Oferecer horários (se ANUM estimado ≥40)

TOUCH 5: Last Chance (T+336h, 2 semanas)
├── "Última mensagem sobre isso..."
├── Resumo do valor + garantia
├── Botão: "Quero agendar" / "Não agora, talvez depois"
└── Se "talvez depois" → Mover para cold_nurture (3 meses)
```

---

#### **FLUXO 10: Handoff Flow**

**Função:** Transferir lead engajado para FRANK qualificar

**Critérios de Handoff:**
| Trigger | Confiança | Ação |
|---------|-----------|------|
| Resposta positiva + pergunta | Alta | Handoff imediato |
| Clicou "Quero saber mais" 2x | Alta | Handoff imediato |
| Respondeu texto livre positivo | Média | Handoff com contexto |
| Pediu para falar com humano | Alta | Handoff + alert |
| ANUM estimado ≥50 | Média | Handoff sugerido |

**Contexto Passado para FRANK:**
```json
{
  "handoff_source": "nurture_engine",
  "campaign_id": "camp_2025_q1_reativacao",
  "touches_received": 3,
  "last_touch_template": "pain_discovery",
  "engagement_score": 72,
  "estimated_anum": {
    "authority": 60,  // Inferido do cargo
    "need": 70,       // Respondeu sobre pain
    "urgency": 40,    // Não mencionou timeline
    "money": 50       // Empresa médio porte
  },
  "conversation_summary": "Lead mostrou interesse após case study. Perguntou sobre integração com CRM. Empresa de 50 funcionários, cargo: Diretor Comercial.",
  "recommended_approach": "Aprofundar em Need e Urgency. Já tem Authority alta."
}
```

---

## 5. Integração Google Calendar Direta {#google-calendar}

### 5.1 Remoção do Cal.com

**Por que remover Cal.com?**
- Dependência de serviço externo
- Custo adicional
- Menor controle sobre experiência
- Dados em plataforma terceira

**Nova Arquitetura:**
```
ANTES (Cal.com):
Lead ─► Link Cal.com ─► Interface Cal ─► Webhook ─► Sistema

DEPOIS (Google Calendar Direto):
Lead ─► FRANK oferece horários ─► Lead escolhe ─► API Google ─► Confirmação
        (tudo no WhatsApp)
```

### 5.2 Implementação Google Calendar API

**Autenticação:**
```javascript
// Service Account (servidor para servidor)
const { google } = require('googleapis');

const auth = new google.auth.GoogleAuth({
  keyFile: 'service-account.json',
  scopes: ['https://www.googleapis.com/auth/calendar']
});

const calendar = google.calendar({ version: 'v3', auth });
```

**Consultar Disponibilidade:**
```javascript
// Buscar horários ocupados
const response = await calendar.freebusy.query({
  requestBody: {
    timeMin: new Date().toISOString(),
    timeMax: addDays(new Date(), 14).toISOString(),
    timeZone: 'America/Sao_Paulo',
    items: [{ id: 'francisco@coreconnect.ai' }]
  }
});

const busySlots = response.data.calendars['francisco@coreconnect.ai'].busy;
```

**Criar Evento:**
```javascript
// Criar reunião no Google Calendar
const event = await calendar.events.insert({
  calendarId: 'francisco@coreconnect.ai',
  conferenceDataVersion: 1,
  requestBody: {
    summary: `Mesa de Clareza - ${leadName}`,
    description: `Lead: ${leadName}\nWhatsApp: ${phone}\nANUM: ${anumScore}`,
    start: {
      dateTime: selectedSlot.toISOString(),
      timeZone: 'America/Sao_Paulo'
    },
    end: {
      dateTime: addMinutes(selectedSlot, 45).toISOString(),
      timeZone: 'America/Sao_Paulo'
    },
    attendees: [
      { email: 'francisco@coreconnect.ai' },
      { email: leadEmail } // Se tiver
    ],
    conferenceData: {
      createRequest: {
        requestId: `meet-${Date.now()}`,
        conferenceSolutionKey: { type: 'hangoutsMeet' }
      }
    },
    reminders: {
      useDefault: false,
      overrides: [
        { method: 'popup', minutes: 60 },
        { method: 'popup', minutes: 1440 } // 24h
      ]
    }
  }
});

const meetingUrl = event.data.conferenceData.entryPoints[0].uri;
// https://meet.google.com/xxx-yyyy-zzz
```

### 5.3 Mudanças Necessárias

| Componente | Mudança |
|------------|---------|
| `corev4_calendar_settings` | Adicionar campos Google OAuth |
| `Availability Flow` | Usar Google Calendar API ao invés de query local |
| `Booking Flow` | Criar evento via API ao invés de apenas salvar |
| `Scheduler Flow` | Deprecar (não mais necessário) |

---

## 6. Mensagens Interativas (Botões) {#botões}

### 6.1 Tipos de Mensagens Interativas (Evolution API)

| Tipo | Uso | Limite |
|------|-----|--------|
| **Quick Reply Buttons** | Opt-in/out, escolhas simples | 3 botões |
| **Call-to-Action Buttons** | Ligar, abrir URL | 2 botões |
| **List Message** | Menu de opções | 10 seções, 10 itens/seção |
| **Template Message (HSM)** | Primeira mensagem proativa | Precisa aprovação Meta |

### 6.2 Implementação via Evolution API

**Quick Reply Buttons:**
```javascript
// POST {{evolution_api_url}}/message/sendButtons/{{instance}}
{
  "number": "5511999999999",
  "buttonMessage": {
    "title": "Título (opcional)",
    "description": "Texto principal da mensagem...",
    "footerText": "Rodapé (opcional)",
    "buttons": [
      { "buttonId": "btn_1", "buttonText": { "displayText": "Opção 1" }},
      { "buttonId": "btn_2", "buttonText": { "displayText": "Opção 2" }},
      { "buttonId": "btn_3", "buttonText": { "displayText": "Opção 3" }}
    ]
  }
}
```

**List Message:**
```javascript
// POST {{evolution_api_url}}/message/sendList/{{instance}}
{
  "number": "5511999999999",
  "listMessage": {
    "title": "Escolha uma opção",
    "description": "Toque no botão abaixo para ver as opções",
    "buttonText": "Ver opções",
    "footerText": "CoreConnect.AI",
    "sections": [
      {
        "title": "Horários Disponíveis",
        "rows": [
          { "rowId": "slot_1", "title": "Terça, 10/dez às 14:00", "description": "45 minutos" },
          { "rowId": "slot_2", "title": "Quarta, 11/dez às 10:00", "description": "45 minutos" },
          { "rowId": "slot_3", "title": "Quinta, 12/dez às 15:00", "description": "45 minutos" }
        ]
      }
    ]
  }
}
```

### 6.3 Recebendo Respostas de Botões

**Webhook Payload (Button Response):**
```json
{
  "event": "messages.upsert",
  "data": {
    "key": {
      "remoteJid": "5511999999999@s.whatsapp.net",
      "fromMe": false
    },
    "message": {
      "buttonsResponseMessage": {
        "selectedButtonId": "btn_1",
        "selectedDisplayText": "Opção 1"
      }
    }
  }
}
```

**Webhook Payload (List Response):**
```json
{
  "event": "messages.upsert",
  "data": {
    "key": {
      "remoteJid": "5511999999999@s.whatsapp.net",
      "fromMe": false
    },
    "message": {
      "listResponseMessage": {
        "singleSelectReply": {
          "selectedRowId": "slot_1"
        }
      }
    }
  }
}
```

---

## 7. Tabelas de Banco de Dados {#banco-dados}

### 7.1 Novas Tabelas Necessárias

```sql
-- 1. PROSPECTS (Leads de Outbound)
CREATE TABLE corev4_prospects (
    id BIGSERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES corev4_companies(id),

    -- Dados básicos
    full_name TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    email TEXT,
    company_name TEXT,
    job_title TEXT,

    -- Origem
    source_type TEXT NOT NULL, -- 'google_sheets', 'csv', 'api', 'manual'
    source_reference TEXT,      -- ID da planilha, nome do arquivo, etc.
    source_row_id TEXT,         -- Referência à linha original
    imported_at TIMESTAMPTZ DEFAULT NOW(),

    -- Validação
    validation_status TEXT DEFAULT 'pending',
    -- 'pending', 'valid', 'invalid_format', 'duplicate', 'no_whatsapp', 'opted_out'
    validated_at TIMESTAMPTZ,
    validation_errors JSONB,
    whatsapp_exists BOOLEAN,

    -- Scoring
    prospect_score INTEGER DEFAULT 0, -- 0-100
    tier TEXT, -- 'A', 'B', 'C'

    -- Estado
    status TEXT DEFAULT 'new',
    -- 'new', 'warming', 'ready', 'contacted', 'engaged', 'qualified', 'converted', 'opted_out', 'archived'

    -- Conversão
    converted_to_contact_id BIGINT REFERENCES corev4_contacts(id),
    converted_at TIMESTAMPTZ,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(phone_number, company_id)
);

-- 2. CAMPAIGNS (Campanhas Proativas)
CREATE TABLE corev4_outbound_campaigns (
    id BIGSERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES corev4_companies(id),

    -- Identificação
    campaign_code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,

    -- Tipo
    campaign_type TEXT NOT NULL, -- 'reactivation', 'cold_outreach', 'event_promo', 'seasonal'

    -- Lista
    list_source TEXT, -- 'google_sheets', 'csv', 'segment'
    list_source_id TEXT,
    total_prospects INTEGER DEFAULT 0,
    valid_prospects INTEGER DEFAULT 0,

    -- Configurações
    settings JSONB DEFAULT '{}'::JSONB,
    -- {
    --   "daily_limit": 500,
    --   "send_hours": ["09:00-12:00", "14:00-18:00"],
    --   "send_days": ["mon","tue","wed","thu","fri"],
    --   "warmup_days": 7
    -- }

    -- Templates
    first_touch_template_id TEXT,
    nurture_sequence JSONB, -- Array de steps

    -- Metas
    goals JSONB,
    -- { "target_opt_in_rate": 0.15, "target_meetings": 50 }

    -- Status
    status TEXT DEFAULT 'draft',
    -- 'draft', 'scheduled', 'warming', 'active', 'paused', 'completed', 'cancelled'

    -- Datas
    scheduled_start TIMESTAMPTZ,
    actual_start TIMESTAMPTZ,
    scheduled_end TIMESTAMPTZ,
    actual_end TIMESTAMPTZ,

    -- Métricas (atualizadas em tempo real)
    metrics JSONB DEFAULT '{}'::JSONB,
    -- { "sent": 1000, "delivered": 950, "read": 600, "responded": 150, "opted_in": 120, "opted_out": 30, "qualified": 25, "meetings": 10 }

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. CAMPAIGN EXECUTIONS (Execuções de Campanha)
CREATE TABLE corev4_campaign_executions (
    id BIGSERIAL PRIMARY KEY,
    campaign_id BIGINT REFERENCES corev4_outbound_campaigns(id),
    prospect_id BIGINT REFERENCES corev4_prospects(id),

    -- Status
    status TEXT DEFAULT 'pending',
    -- 'pending', 'scheduled', 'sent', 'delivered', 'read', 'responded', 'opted_in', 'opted_out', 'failed'

    -- Primeiro toque
    first_touch_sent_at TIMESTAMPTZ,
    first_touch_delivered_at TIMESTAMPTZ,
    first_touch_read_at TIMESTAMPTZ,
    first_touch_response TEXT,
    first_touch_response_at TIMESTAMPTZ,
    first_touch_button_clicked TEXT, -- 'opt_in', 'opt_out', null

    -- Nutrição
    current_nurture_step INTEGER DEFAULT 0,
    nurture_history JSONB DEFAULT '[]'::JSONB,
    -- [{ "step": 1, "sent_at": "...", "response": "...", "response_at": "..." }]

    -- Handoff
    handed_off_to_frank BOOLEAN DEFAULT false,
    handoff_at TIMESTAMPTZ,
    handoff_context JSONB,

    -- Conversão
    converted BOOLEAN DEFAULT false,
    conversion_type TEXT, -- 'meeting_scheduled', 'qualified', 'purchased'
    converted_at TIMESTAMPTZ,

    -- Erros
    error_count INTEGER DEFAULT 0,
    last_error TEXT,
    last_error_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(campaign_id, prospect_id)
);

-- 4. CONSENT LOG (Registro de Consentimento - LGPD)
CREATE TABLE corev4_consent_log (
    id BIGSERIAL PRIMARY KEY,

    -- Referências
    prospect_id BIGINT REFERENCES corev4_prospects(id),
    contact_id BIGINT REFERENCES corev4_contacts(id),
    campaign_id BIGINT REFERENCES corev4_outbound_campaigns(id),

    -- Tipo de consentimento
    consent_type TEXT NOT NULL, -- 'opt_in', 'opt_out', 'data_access', 'data_deletion'
    consent_source TEXT NOT NULL, -- 'button_click', 'text_message', 'form', 'manual', 'api'

    -- Evidência
    message_id TEXT, -- ID da mensagem que gerou
    raw_response TEXT, -- Texto/botão original

    -- Metadata
    ip_address INET,
    user_agent TEXT,
    device_info JSONB,

    -- Timestamp
    consented_at TIMESTAMPTZ DEFAULT NOW(),

    -- Para auditoria
    created_by TEXT, -- 'system', 'admin', 'user'
    notes TEXT
);

-- 5. WARMUP STATUS (Status de Aquecimento)
CREATE TABLE corev4_warmup_status (
    id SERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES corev4_companies(id),
    instance_name TEXT NOT NULL,

    -- Status atual
    warmup_phase TEXT DEFAULT 'initial',
    -- 'initial', 'ramping', 'stable', 'throttled', 'blocked'
    warmup_day INTEGER DEFAULT 1,

    -- Limites
    current_daily_limit INTEGER DEFAULT 50,
    target_daily_limit INTEGER DEFAULT 1000,

    -- Métricas do dia
    sent_today INTEGER DEFAULT 0,
    delivered_today INTEGER DEFAULT 0,
    failed_today INTEGER DEFAULT 0,
    blocked_today INTEGER DEFAULT 0,

    -- Métricas históricas
    metrics_history JSONB DEFAULT '[]'::JSONB,
    -- [{ "date": "2025-01-15", "sent": 50, "delivered": 48, "rate": 0.96 }]

    -- Alertas
    last_alert TEXT,
    last_alert_at TIMESTAMPTZ,

    -- Timestamps
    warmup_started_at TIMESTAMPTZ,
    warmup_completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(company_id, instance_name)
);

-- 6. MESSAGE TEMPLATES (Templates de Mensagem)
CREATE TABLE corev4_message_templates (
    id TEXT PRIMARY KEY, -- 'first_touch_v1', 'nurture_pain_v2', etc.
    company_id INTEGER REFERENCES corev4_companies(id),

    -- Identificação
    name TEXT NOT NULL,
    description TEXT,
    category TEXT, -- 'first_touch', 'nurture', 'followup', 'confirmation'

    -- Conteúdo
    content_type TEXT NOT NULL, -- 'text', 'buttons', 'list', 'media'
    content JSONB NOT NULL,
    -- Para texto: { "text": "Olá {{nome}}..." }
    -- Para botões: { "text": "...", "buttons": [...] }

    -- Variáveis
    variables TEXT[], -- ['nome', 'empresa', 'cargo']

    -- Uso
    usage_count INTEGER DEFAULT 0,
    last_used_at TIMESTAMPTZ,

    -- Performance
    metrics JSONB DEFAULT '{}'::JSONB,
    -- { "sent": 1000, "response_rate": 0.18, "opt_out_rate": 0.02 }

    -- Status
    is_active BOOLEAN DEFAULT true,
    approved_for_hsm BOOLEAN DEFAULT false,
    hsm_template_id TEXT, -- ID do template aprovado pela Meta

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. BLOCKLIST (Lista de Não Contatar)
CREATE TABLE corev4_blocklist (
    id BIGSERIAL PRIMARY KEY,
    company_id INTEGER REFERENCES corev4_companies(id),

    phone_number TEXT NOT NULL,

    -- Motivo
    reason TEXT NOT NULL, -- 'user_opt_out', 'complaint', 'legal', 'manual'
    source_campaign_id BIGINT,
    source_message TEXT,

    -- Permanência
    is_permanent BOOLEAN DEFAULT true,
    expires_at TIMESTAMPTZ, -- Se temporário

    -- Auditoria
    added_by TEXT,
    added_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(phone_number, company_id)
);
```

### 7.2 Índices e Constraints

```sql
-- Índices para performance
CREATE INDEX idx_prospects_status ON corev4_prospects(status);
CREATE INDEX idx_prospects_validation ON corev4_prospects(validation_status);
CREATE INDEX idx_prospects_company_phone ON corev4_prospects(company_id, phone_number);

CREATE INDEX idx_campaigns_status ON corev4_outbound_campaigns(status);
CREATE INDEX idx_campaigns_company ON corev4_outbound_campaigns(company_id);

CREATE INDEX idx_executions_campaign ON corev4_campaign_executions(campaign_id);
CREATE INDEX idx_executions_prospect ON corev4_campaign_executions(prospect_id);
CREATE INDEX idx_executions_status ON corev4_campaign_executions(status);

CREATE INDEX idx_consent_prospect ON corev4_consent_log(prospect_id);
CREATE INDEX idx_consent_contact ON corev4_consent_log(contact_id);
CREATE INDEX idx_consent_type ON corev4_consent_log(consent_type);

CREATE INDEX idx_blocklist_phone ON corev4_blocklist(phone_number);
```

---

## 8. Cronograma de Implementação {#cronograma}

### Fase 1: Fundação (Semana 1-2)
- [ ] Criar tabelas de banco de dados
- [ ] Implementar List Import Flow
- [ ] Implementar List Validation Flow
- [ ] Criar templates iniciais de mensagem

### Fase 2: Aquecimento (Semana 3-4)
- [ ] Implementar Warmup Scheduler Flow
- [ ] Implementar Warmup Monitor Flow
- [ ] Configurar métricas e alertas
- [ ] Testar com volume baixo

### Fase 3: Prospecção (Semana 5-6)
- [ ] Implementar Campaign Orchestrator Flow
- [ ] Implementar First Touch Flow (com botões)
- [ ] Implementar Opt-in Handler Flow
- [ ] Integrar com Evolution API buttons

### Fase 4: Nutrição (Semana 7-8)
- [ ] Implementar Nurture Engine Flow
- [ ] Implementar Handoff Flow
- [ ] Integrar com FRANK (One Flow)
- [ ] Criar sequências de nutrição padrão

### Fase 5: Google Calendar Direto (Semana 9)
- [ ] Configurar Google Calendar API
- [ ] Atualizar Availability Flow
- [ ] Atualizar Booking Flow
- [ ] Deprecar Scheduler Flow (Cal.com)

### Fase 6: Testes e Refinamento (Semana 10-12)
- [ ] Testes E2E completos
- [ ] Ajustes de performance
- [ ] Documentação final
- [ ] Treinamento

---

## Resumo Executivo

### O que será construído:

| Item | Descrição |
|------|-----------|
| **10 novos flows** | Gestão de listas, aquecimento, prospecção, nutrição |
| **7 novas tabelas** | Prospects, campaigns, executions, consent, blocklist, warmup, templates |
| **Integração Google Calendar** | Substituição completa do Cal.com |
| **Mensagens com botões** | Via Evolution API |
| **Sistema de compliance** | Opt-in/out, consent log, blocklist |

### Benefícios esperados:

| Métrica | Valor Esperado |
|---------|----------------|
| Taxa de engajamento | 15-25% |
| Taxa de qualificação | 3-5% |
| Custo por lead qualificado | -60% vs SDR |
| Velocidade de prospecção | 20x mais rápido |

---

**Próximo passo:** Aprovar arquitetura e iniciar Fase 1.
