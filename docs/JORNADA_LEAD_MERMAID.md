# Jornada do Lead — CoreAdapt

**Diagramas Mermaid com explicações completas**

---

## 1. Visão Macro: O Funil Completo

```mermaid
flowchart LR
    subgraph PROSPECÇÃO ["🔍 FASE 1: PROSPECÇÃO"]
        A1[Google Maps API]
        A2[LinkedIn API]
        A3[Import CSV/Sheets]
    end

    subgraph VALIDAÇÃO ["✅ FASE 2: VALIDAÇÃO"]
        B1[Validar Formato]
        B2[Check WhatsApp]
        B3[Remover Duplicatas]
    end

    subgraph ENGAJAMENTO ["🎯 FASE 3: ENGAJAMENTO"]
        C1[Warmup]
        C2[First Touch]
        C3[Opt-in/Out]
    end

    subgraph QUALIFICAÇÃO ["🧠 FASE 4: QUALIFICAÇÃO"]
        D1[CoreOne FRANK]
        D2[ANUM Score]
    end

    subgraph CONVERSÃO ["📅 FASE 5: CONVERSÃO"]
        E1[Oferecer Horários]
        E2[Agendar Reunião]
        E3[Lembretes]
    end

    A1 --> B1
    A2 --> B1
    A3 --> B1
    B1 --> B2 --> B3
    B3 --> C1 --> C2 --> C3
    C3 -->|Opt-in| D1
    C3 -->|Opt-out| X[Blocklist]
    D1 --> D2
    D2 -->|Score ≥ 60| E1
    D2 -->|Score < 60| N[Nurture]
    N -->|Engajou| D1
    E1 --> E2 --> E3
```

### Explicação das Fases

| Fase | O que acontece | Taxa esperada |
|------|----------------|---------------|
| **Prospecção** | Sistema busca empresas em APIs externas | 100% (entrada) |
| **Validação** | Limpa lista, valida WhatsApp | ~90% passam |
| **Engajamento** | Primeiro contato com botões | ~20% respondem |
| **Qualificação** | Conversa ANUM com CoreOne | ~30% qualificam |
| **Conversão** | Agendamento autônomo | ~50% agendam |

**Resultado final:** De 1.000 prospects → ~30 reuniões agendadas (3%)

---

## 2. Fluxo Detalhado: Prospecção

```mermaid
flowchart TB
    subgraph ENTRADA ["📥 FONTES DE DADOS"]
        GM["🗺️ Google Maps API<br/>(Local Business Search)"]
        LI["💼 LinkedIn API<br/>(Unipile)"]
        CSV["📄 Import Manual<br/>(CSV/Google Sheets)"]
    end

    subgraph PROSPECTOR ["🔍 PROSPECTOR FLOW"]
        direction TB
        P1["Recebe termo de busca<br/>'Dentistas em Fortaleza'"]
        P2["Chama RapidAPI<br/>limit: 500 resultados"]
        P3["Para cada resultado:"]
        P4["Scraping do site<br/>(Scraptio API)"]
        P5["Resumo via IA<br/>(GPT-4.1-mini)"]
        P6["Salva em corev4_prospects"]
    end

    subgraph DADOS ["📊 DADOS EXTRAÍDOS"]
        D1["business_id: 'ChIJ...'"]
        D2["nome: 'Clínica Sorriso'"]
        D3["telefone: '+55 85 99999-1234'"]
        D4["endereco: 'Rua X, 123'"]
        D5["cidade: 'Fortaleza'"]
        D6["rating: 4.8 ⭐"]
        D7["website: 'clinicasorriso.com.br'"]
        D8["resumo_ia: 'Clínica odontológica<br/>com 15 anos...'"]
    end

    GM --> P1
    LI --> P1
    CSV --> P1
    P1 --> P2 --> P3 --> P4 --> P5 --> P6
    P6 --> D1 & D2 & D3 & D4 & D5 & D6 & D7 & D8

    style GM fill:#4285F4,color:#fff
    style LI fill:#0A66C2,color:#fff
    style CSV fill:#34A853,color:#fff
```

### Exemplo Real

**Entrada do usuário:**
> "Quero prospectar escritórios de advocacia trabalhista na Zona Sul do Rio"

**O que o sistema faz:**
1. Agente IA interpreta → `termo_busca: "Escritórios advocacia trabalhista Zona Sul Rio de Janeiro, Brasil"`
2. Chama RapidAPI → Retorna 347 resultados
3. Para cada resultado:
   - Extrai dados básicos (nome, telefone, endereço, rating)
   - Faz scraping do site
   - IA resume: *"Escritório especializado em direito trabalhista, 20 anos de experiência, foco em empresas de médio porte, destaque para compliance trabalhista..."*
4. Salva no banco com `status: 'new'`

---

## 3. Fluxo Detalhado: Validação

```mermaid
flowchart TB
    subgraph INPUT ["📥 ENTRADA"]
        I1["corev4_prospects<br/>status = 'new'"]
    end

    subgraph VALIDACAO ["✅ LIST VALIDATION FLOW"]
        V1{"Formato telefone OK?<br/>55 + DDD + 9 dígitos"}
        V2{"Já existe no banco?<br/>(duplicata)"}
        V3{"Está na blocklist?<br/>(opt-out anterior)"}
        V4{"WhatsApp ativo?<br/>(Evolution API)"}
        V5["Calcular prospect_score"]
    end

    subgraph OUTPUT ["📤 SAÍDA"]
        O1["✅ status = 'valid'<br/>prospect_score: 75"]
        O2["❌ status = 'invalid_format'"]
        O3["❌ status = 'duplicate'"]
        O4["❌ status = 'opted_out'"]
        O5["❌ status = 'no_whatsapp'"]
    end

    I1 --> V1
    V1 -->|Não| O2
    V1 -->|Sim| V2
    V2 -->|Sim| O3
    V2 -->|Não| V3
    V3 -->|Sim| O4
    V3 -->|Não| V4
    V4 -->|Não| O5
    V4 -->|Sim| V5
    V5 --> O1

    style O1 fill:#34A853,color:#fff
    style O2 fill:#EA4335,color:#fff
    style O3 fill:#EA4335,color:#fff
    style O4 fill:#EA4335,color:#fff
    style O5 fill:#EA4335,color:#fff
```

### Cálculo do Prospect Score

```mermaid
flowchart LR
    subgraph FATORES ["📊 FATORES DO SCORE"]
        F1["Rating Google<br/>4.5+ = +20 pts"]
        F2["Qtd Reviews<br/>50+ = +15 pts"]
        F3["Tem website<br/>Sim = +15 pts"]
        F4["Tem email<br/>Sim = +10 pts"]
        F5["Resumo IA<br/>Qualidade = +20 pts"]
        F6["Cidade tier<br/>Capital = +20 pts"]
    end

    subgraph SCORE ["🎯 RESULTADO"]
        S1["0-40: Tier C<br/>(baixa prioridade)"]
        S2["41-70: Tier B<br/>(média prioridade)"]
        S3["71-100: Tier A<br/>(alta prioridade)"]
    end

    F1 & F2 & F3 & F4 & F5 & F6 --> CALC["Soma dos pontos"]
    CALC --> S1 & S2 & S3
```

---

## 4. Fluxo Detalhado: Engajamento (First Touch)

```mermaid
flowchart TB
    subgraph WARMUP ["🔥 WARMUP MONITOR"]
        W1["Dia 1-3: 50 msgs/dia"]
        W2["Dia 4-6: 100 msgs/dia"]
        W3["Dia 7-10: 250 msgs/dia"]
        W4["Dia 11+: 500 msgs/dia"]
        W5{"Taxa entrega<br/>> 95%?"}
    end

    subgraph FIRST_TOUCH ["🎯 FIRST TOUCH FLOW"]
        FT1["Seleciona próximos<br/>prospects (Tier A primeiro)"]
        FT2["Monta mensagem<br/>personalizada"]
        FT3["Envia via<br/>Evolution API"]
        FT4["Registra em<br/>campaign_executions"]
    end

    subgraph MENSAGEM ["💬 MENSAGEM COM BOTÕES"]
        M1["Olá João! 👋<br/><br/>Sou a Ana da TechSolutions.<br/><br/>Clínicas como a Sorriso estão<br/>economizando 70% do tempo<br/>em gestão de pacientes.<br/><br/>Posso mostrar como?"]
        B1["✅ Quero saber mais"]
        B2["❌ Não tenho interesse"]
    end

    W1 --> W2 --> W3 --> W4
    W4 --> W5
    W5 -->|Não| PAUSE["⏸️ Pausar e investigar"]
    W5 -->|Sim| FT1
    FT1 --> FT2 --> FT3 --> FT4
    FT3 --> M1
    M1 --> B1 & B2

    style B1 fill:#34A853,color:#fff
    style B2 fill:#EA4335,color:#fff
```

### Exemplo de Mensagem First Touch

```
┌────────────────────────────────────────────────────────┐
│                                                        │
│  Olá Dr. Carlos! 👋                                    │
│                                                        │
│  Sou o Frank da CoreConnect.AI.                        │
│                                                        │
│  Vi que a Clínica Sorriso tem avaliação               │
│  excelente (4.8 ⭐) no Google!                         │
│                                                        │
│  Clínicas como a sua estão dobrando o                 │
│  agendamento de pacientes usando IA no WhatsApp.      │
│                                                        │
│  Posso te mostrar como funciona em 2 minutos?         │
│                                                        │
│  ┌──────────────────┐  ┌──────────────────┐           │
│  │ ✅ Quero ver     │  │ ❌ Não, obrigado │           │
│  └──────────────────┘  └──────────────────┘           │
│                                                        │
└────────────────────────────────────────────────────────┘
```

---

## 5. Fluxo Detalhado: Opt-in Handler

```mermaid
flowchart TB
    subgraph ENTRADA ["📥 RESPOSTA DO LEAD"]
        R1["Clicou botão"]
        R2["Enviou texto"]
    end

    subgraph ANALISE ["🔍 OPT-IN HANDLER FLOW"]
        A1{"Qual botão?"}
        A2["Analisar sentimento<br/>do texto (IA)"]
        A3{"Sentimento?"}
    end

    subgraph ACOES ["⚡ AÇÕES"]
        OPT_IN["✅ OPT-IN"]
        OPT_OUT["❌ OPT-OUT"]
        RETRY["🔄 RETRY"]
    end

    subgraph REGISTROS ["📝 REGISTROS"]
        REG1["corev4_consent_log<br/>type: 'opt_in'<br/>timestamp: now()"]
        REG2["corev4_blocklist<br/>reason: 'user_opt_out'"]
        REG3["campaign_executions<br/>status: 'no_response'"]
    end

    subgraph PROXIMO ["➡️ PRÓXIMO PASSO"]
        NEXT1["Handoff → CoreOne<br/>(qualificação)"]
        NEXT2["Nunca mais<br/>contatar"]
        NEXT3["Retry em 7 dias<br/>(máx 2x)"]
    end

    R1 --> A1
    R2 --> A2 --> A3

    A1 -->|"✅ Quero saber"| OPT_IN
    A1 -->|"❌ Não tenho interesse"| OPT_OUT

    A3 -->|Positivo| OPT_IN
    A3 -->|Negativo| OPT_OUT
    A3 -->|Neutro/Dúvida| RETRY

    OPT_IN --> REG1 --> NEXT1
    OPT_OUT --> REG2 --> NEXT2
    RETRY --> REG3 --> NEXT3

    style OPT_IN fill:#34A853,color:#fff
    style OPT_OUT fill:#EA4335,color:#fff
    style RETRY fill:#FBBC04,color:#000
```

### Exemplos de Respostas e Classificação

| Resposta do Lead | Classificação | Ação |
|------------------|---------------|------|
| *Clicou "✅ Quero saber mais"* | Opt-in | → Handoff |
| *Clicou "❌ Não tenho interesse"* | Opt-out | → Blocklist |
| *"Sim, me conta mais"* | Positivo | → Handoff |
| *"Não me interessa"* | Negativo | → Blocklist |
| *"Para de me mandar mensagem"* | Negativo | → Blocklist |
| *"Quem é você?"* | Neutro | → Retry com mais contexto |
| *"Agora não posso"* | Neutro | → Retry em 7 dias |
| *"Quanto custa?"* | Positivo | → Handoff imediato |
| *(sem resposta 48h)* | No response | → Retry em 7 dias |

---

## 6. Fluxo Detalhado: Handoff (Proativo → Receptivo)

```mermaid
flowchart TB
    subgraph PROATIVO ["🎯 SISTEMA PROATIVO"]
        P1["Lead fez opt-in"]
        P2["corev4_prospects<br/>corev4_campaign_executions"]
    end

    subgraph HANDOFF ["🔄 HANDOFF FLOW"]
        H1["Criar corev4_contacts<br/>(se não existe)"]
        H2["Criar corev4_chats"]
        H3["Copiar contexto:<br/>• campaign_id<br/>• touches recebidos<br/>• engagement_score<br/>• resumo_ia"]
        H4["Marcar prospect como<br/>converted_to_contact_id"]
        H5["Disparar Main Router<br/>com flag handoff=true"]
    end

    subgraph RECEPTIVO ["🧠 SISTEMA RECEPTIVO"]
        R1["Main Router"]
        R2["One Flow (CoreOne)"]
        R3["CoreOne recebe contexto:<br/>'Lead veio da campanha X,<br/>mostrou interesse após<br/>case study, perguntou<br/>sobre preço'"]
    end

    P1 --> P2 --> H1 --> H2 --> H3 --> H4 --> H5
    H5 --> R1 --> R2 --> R3

    style HANDOFF fill:#9C27B0,color:#fff
```

### Contexto Passado no Handoff

```json
{
  "handoff_source": "proactive_campaign",
  "campaign": {
    "id": "camp_dentistas_fortaleza_q1",
    "name": "Dentistas Fortaleza Q1 2026"
  },
  "prospect": {
    "nome": "Dr. Carlos Silva",
    "empresa": "Clínica Sorriso",
    "cargo_inferido": "Proprietário",
    "cidade": "Fortaleza"
  },
  "engagement": {
    "touches_received": 1,
    "first_touch_response": "Clicou opt-in",
    "engagement_score": 72,
    "tempo_resposta": "4 horas"
  },
  "enrichment": {
    "rating_google": 4.8,
    "reviews_count": 127,
    "resumo_site": "Clínica odontológica com 15 anos, foco em implantes e estética dental, equipe de 8 profissionais..."
  },
  "recommended_approach": "Lead mostrou interesse rápido. Abordar direto o valor, perguntar sobre volume de pacientes atual."
}
```

---

## 7. Fluxo Detalhado: Qualificação (CoreOne + ANUM)

```mermaid
flowchart TB
    subgraph COREONE ["🧠 ONE FLOW (COREONE)"]
        C1["Recebe mensagem<br/>+ contexto handoff"]
        C2["Gera resposta<br/>personalizada"]
        C3["Envia via<br/>Evolution API"]
        C4["Aguarda resposta"]
    end

    subgraph SYNC ["📊 SYNC FLOW (ANUM)"]
        S1["Analisa conversa"]
        S2["Extrai sinais ANUM"]
        S3["Calcula scores"]
        S4["Atualiza corev4_chats"]
    end

    subgraph ANUM ["🎯 METODOLOGIA ANUM"]
        A["**A**uthority<br/>É o decisor?<br/>0-100"]
        N["**N**eed<br/>Tem a dor?<br/>0-100"]
        U["**U**rgency<br/>Precisa agora?<br/>0-100"]
        M["**M**oney<br/>Tem budget?<br/>0-100"]
    end

    subgraph RESULTADO ["📈 RESULTADO"]
        R1{"Score médio<br/>≥ 60?"}
        R2["✅ QUALIFICADO<br/>→ Oferecer agendamento"]
        R3["⏳ NURTURE<br/>→ Continuar nutrição"]
    end

    C1 --> C2 --> C3 --> C4
    C4 --> S1 --> S2 --> S3 --> S4
    S2 --> A & N & U & M
    A & N & U & M --> R1
    R1 -->|Sim| R2
    R1 -->|Não| R3
    R3 -->|"Após mais<br/>interações"| C1

    style R2 fill:#34A853,color:#fff
    style R3 fill:#FBBC04,color:#000
```

### Exemplo de Conversa de Qualificação

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CONVERSA DE QUALIFICAÇÃO                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  COREONE: Que bom que quer saber mais, Dr. Carlos! 😊                │
│                                                                      │
│  Vi que a Clínica Sorriso tem avaliação excelente no Google.        │
│  Como vocês fazem hoje pra gerenciar os agendamentos?                │
│                                                                      │
│  ───────────────────────────────────────────────────────────────    │
│                                                                      │
│  LEAD: Usamos uma agenda no computador, mas é bem manual.           │
│  A recepcionista fica o dia todo no telefone.                        │
│                                                                      │
│  ───────────────────────────────────────────────────────────────    │
│  📊 ANUM DETECTADO:                                                  │
│  • Need: 75 (mencionou dor: processo manual, recepcionista ocupada) │
│  ───────────────────────────────────────────────────────────────    │
│                                                                      │
│  COREONE: Entendo! Isso é super comum.                               │
│  E essa parte de confirmar consultas, como funciona?                 │
│  Vocês ligam um por um ou mandam mensagem?                           │
│                                                                      │
│  ───────────────────────────────────────────────────────────────    │
│                                                                      │
│  LEAD: Tentamos ligar mas não dá tempo. Muito no-show.              │
│                                                                      │
│  ───────────────────────────────────────────────────────────────    │
│  📊 ANUM ATUALIZADO:                                                 │
│  • Need: 85 (confirmou dor adicional: no-show)                       │
│  • Urgency: 60 (problema está causando perda de receita)            │
│  ───────────────────────────────────────────────────────────────    │
│                                                                      │
│  COREONE: No-show é um problema sério, né?                          │
│  Clínicas que usam confirmação automática por WhatsApp               │
│  reduziram isso em 70%.                                              │
│                                                                      │
│  Você que cuida dessa parte ou tem alguém?                          │
│                                                                      │
│  ───────────────────────────────────────────────────────────────    │
│                                                                      │
│  LEAD: Eu que decido essas coisas, sou o dono.                      │
│                                                                      │
│  ───────────────────────────────────────────────────────────────    │
│  📊 ANUM ATUALIZADO:                                                 │
│  • Authority: 95 (é o decisor/dono)                                  │
│  • Need: 85                                                          │
│  • Urgency: 60                                                       │
│  • Money: 50 (ainda não mencionou)                                   │
│  • MÉDIA: 72.5 → ✅ QUALIFICADO!                                     │
│  ───────────────────────────────────────────────────────────────    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 8. Fluxo Detalhado: Agendamento Autônomo

```mermaid
flowchart TB
    subgraph TRIGGER ["🎯 GATILHO"]
        T1["ANUM Score ≥ 60"]
        T2["Lead pediu para agendar"]
        T3["CoreOne detectou<br/>momento certo"]
    end

    subgraph AVAILABILITY ["📅 AVAILABILITY FLOW"]
        A1["Consulta Google Calendar<br/>(freeBusy API)"]
        A2["Aplica regras:<br/>• Horário comercial (9-18h)<br/>• Dias úteis (seg-sex)<br/>• Antecedência mínima (24h)<br/>• Janela máxima (14 dias)"]
        A3["Aplica preferências:<br/>• Dias preferidos (ter-qui)<br/>• Horários preferidos (10-12h)"]
        A4["Gera 3 melhores slots"]
    end

    subgraph OFERTA ["💬 OFERTA DE HORÁRIOS"]
        O1["CoreOne apresenta<br/>os 3 horários"]
        O2["Lead escolhe"]
        O3["Parser interpreta<br/>a escolha"]
    end

    subgraph BOOKING ["✅ BOOKING FLOW"]
        B1["Verifica conflito<br/>(double-check)"]
        B2["Cria evento no<br/>Google Calendar"]
        B3["Gera link<br/>Google Meet"]
        B4["Envia confirmação<br/>ao lead"]
        B5["Agenda lembretes<br/>(24h e 1h antes)"]
    end

    T1 & T2 & T3 --> A1
    A1 --> A2 --> A3 --> A4
    A4 --> O1 --> O2 --> O3
    O3 --> B1 --> B2 --> B3 --> B4 --> B5

    style BOOKING fill:#34A853,color:#fff
```

### Exemplo de Oferta de Horários

```
┌─────────────────────────────────────────────────────────────────────┐
│                    AGENDAMENTO AUTÔNOMO                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  COREONE: Perfeito, Dr. Carlos!                                      │
│                                                                      │
│  Que tal agendarmos uma conversa de 30 minutos                      │
│  pra eu te mostrar como funciona na prática?                        │
│                                                                      │
│  Tenho esses horários disponíveis:                                  │
│                                                                      │
│  1️⃣  Terça (24/12) às 10:00                                         │
│  2️⃣  Quarta (25/12) às 14:30                                        │
│  3️⃣  Quinta (26/12) às 11:00                                        │
│                                                                      │
│  Qual funciona melhor pra você?                                     │
│                                                                      │
│  ───────────────────────────────────────────────────────────────    │
│                                                                      │
│  LEAD: Terça de manhã tá ótimo!                                      │
│                                                                      │
│  ───────────────────────────────────────────────────────────────    │
│  🔍 PARSER DETECTOU:                                                 │
│  • "Terça" → Slot 1                                                  │
│  • "de manhã" → confirma Slot 1 (10:00)                             │
│  • Confiança: 95%                                                    │
│  ───────────────────────────────────────────────────────────────    │
│                                                                      │
│  COREONE: Pronto, agendado! ✅                                        │
│                                                                      │
│  📅 Terça, 24/12 às 10:00                                            │
│  📍 Google Meet: meet.google.com/abc-defg-hij                       │
│  ⏱️ Duração: 30 minutos                                              │
│                                                                      │
│  Vou te mandar um lembrete amanhã e 1 hora antes.                   │
│  Até lá! 👋                                                          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Parser de Seleção de Horário

```mermaid
flowchart LR
    subgraph INPUT ["📥 RESPOSTA DO LEAD"]
        I1["'1'"]
        I2["'Opção 1'"]
        I3["'Terça'"]
        I4["'Terça de manhã'"]
        I5["'Primeiro horário'"]
        I6["'10 horas'"]
        I7["'Pode ser às 10'"]
    end

    subgraph PARSER ["🔍 PARSER"]
        P1["Regex: número direto"]
        P2["Regex: 'opção X'"]
        P3["Match: dia da semana"]
        P4["Match: horário"]
        P5["Match: ordinal"]
    end

    subgraph OUTPUT ["📤 RESULTADO"]
        O1["slot_selecionado: 1<br/>confianca: 95%"]
    end

    I1 --> P1 --> O1
    I2 --> P2 --> O1
    I3 --> P3 --> O1
    I4 --> P3 --> O1
    I5 --> P5 --> O1
    I6 --> P4 --> O1
    I7 --> P4 --> O1
```

---

## 9. Fluxo Completo: Jornada de Ponta a Ponta

```mermaid
flowchart TB
    subgraph DIA1 ["📅 DIA 1"]
        D1_1["🔍 Prospector busca<br/>'Dentistas Fortaleza'"]
        D1_2["✅ 347 empresas encontradas"]
        D1_3["📊 312 validadas (90%)"]
    end

    subgraph DIA2_7 ["📅 DIA 2-7"]
        D2_1["🔥 Warmup: 50→100 msgs/dia"]
        D2_2["📈 Taxa entrega: 96%"]
    end

    subgraph DIA8 ["📅 DIA 8"]
        D8_1["🎯 First Touch enviado<br/>para Clínica Sorriso"]
        D8_2["💬 'Olá Dr. Carlos...'<br/>+ botões"]
    end

    subgraph DIA8_TARDE ["📅 DIA 8 (4h depois)"]
        D8_3["✅ Lead clicou<br/>'Quero saber mais'"]
        D8_4["🔄 Handoff → CoreOne"]
    end

    subgraph DIA8_9 ["📅 DIA 8-9"]
        D9_1["🧠 CoreOne qualifica"]
        D9_2["📊 ANUM: 72.5"]
        D9_3["✅ QUALIFICADO!"]
    end

    subgraph DIA9 ["📅 DIA 9"]
        D9_4["📅 Oferece 3 horários"]
        D9_5["👆 Lead escolhe Terça 10h"]
        D9_6["✅ Reunião agendada!"]
        D9_7["📧 Confirmação enviada"]
    end

    subgraph DIA10 ["📅 DIA 10"]
        D10_1["⏰ Lembrete 24h antes"]
    end

    subgraph DIA11 ["📅 DIA 11 (Terça)"]
        D11_1["⏰ Lembrete 1h antes"]
        D11_2["🎉 REUNIÃO REALIZADA!"]
    end

    D1_1 --> D1_2 --> D1_3
    D1_3 --> D2_1 --> D2_2
    D2_2 --> D8_1 --> D8_2
    D8_2 --> D8_3 --> D8_4
    D8_4 --> D9_1 --> D9_2 --> D9_3
    D9_3 --> D9_4 --> D9_5 --> D9_6 --> D9_7
    D9_7 --> D10_1 --> D11_1 --> D11_2

    style D11_2 fill:#34A853,color:#fff,stroke:#2E7D32,stroke-width:3px
```

---

## 10. Estados do Lead (State Machine)

```mermaid
stateDiagram-v2
    [*] --> new: Prospector encontra

    new --> valid: Validação OK
    new --> invalid: Validação falhou

    valid --> contacted: First Touch enviado

    contacted --> opted_in: Clicou opt-in
    contacted --> opted_out: Clicou opt-out
    contacted --> no_response: 48h sem resposta

    no_response --> contacted: Retry (máx 2x)
    no_response --> archived: 2 retries sem resposta

    opted_out --> blocked: Movido p/ blocklist
    blocked --> [*]

    opted_in --> qualifying: Handoff → CoreOne

    qualifying --> qualified: ANUM ≥ 60
    qualifying --> nurturing: ANUM < 60

    nurturing --> qualifying: Engajou novamente
    nurturing --> archived: Exauriu sequência

    qualified --> scheduling: Ofereceu horários

    scheduling --> scheduled: Reunião agendada
    scheduling --> qualifying: Pediu mais info

    scheduled --> completed: Reunião realizada
    scheduled --> no_show: Não compareceu

    no_show --> rescheduling: Reagendar
    rescheduling --> scheduled: Novo horário

    completed --> [*]: 🎉 SUCESSO!
```

---

## 11. Métricas do Funil (Resumo)

```mermaid
pie title Funil de Conversão (1.000 prospects)
    "Inválidos (10%)" : 100
    "Sem resposta (70%)" : 700
    "Opt-out (2%)" : 20
    "Opt-in não qualificado (12%)" : 120
    "Qualificado não agendou (3%)" : 30
    "Reunião agendada (3%)" : 30
```

| Etapa | Quantidade | Taxa | Acumulado |
|-------|------------|------|-----------|
| Prospects encontrados | 1.000 | 100% | 100% |
| Validados | 900 | 90% | 90% |
| Responderam | 180 | 20% | 18% |
| Opt-in | 150 | 83% | 15% |
| Qualificados (ANUM ≥ 60) | 60 | 40% | 6% |
| Reunião agendada | 30 | 50% | **3%** |

---

## Como usar estes diagramas

1. **No GitHub:** Markdown com Mermaid renderiza automaticamente
2. **No Notion:** Cole o código Mermaid em bloco de código
3. **Em apresentações:** Use [Mermaid Live Editor](https://mermaid.live) para exportar PNG/SVG
4. **No site:** Inclua a lib Mermaid.js para renderizar

```html
<script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
<script>mermaid.initialize({startOnLoad:true});</script>
```
