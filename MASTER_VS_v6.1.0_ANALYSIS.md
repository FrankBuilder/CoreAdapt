# ANÁLISE COMPARATIVA: Master Document 2025 vs FRANK v6.1.0

**Data:** 10 de Novembro de 2025
**Comparado:** `CoreConnect_AI_Master_Positioning_Document_2025.md` vs `FRANK_SYSTEM_MESSAGE_v6.1.0.md`

---

## 🔍 RESUMO EXECUTIVO

**Status:** ✅ **ALINHAMENTO PARCIAL** (80% alinhado, 20% requer ajustes)

**Ação recomendada:** **CRIAR v6.2.0** (formato completo) para alinhar com Master Document

**Principais diferenças críticas:** 3 (ANUM scores, Mesa positioning, concorrentes)

---

## ✅ O QUE ESTÁ ALINHADO (Não precisa mudar)

| Item | Master Document | v6.1.0 | Status |
|------|-----------------|--------|--------|
| **Garantia** | 30 dias | 30 dias | ✅ Alinhado |
| **Timeline** | Dia 0, 1-7, 8-30, 31 | Dia 0, 1-7, 8-30, 31 | ✅ Alinhado |
| **Preço** | R$ 997 setup + R$ 997/mês | R$ 997 setup + R$ 997/mês | ✅ Alinhado |
| **Contrato** | 6 meses | 6 meses | ✅ Alinhado |
| **Implementação** | 7 dias | 7 dias | ✅ Alinhado |
| **Filosofia** | "Qualificar gerando valor" | "Qualificar gerando valor" | ✅ Alinhado |
| **Mesa Gratuita** | 45min com Francisco | 45min com Francisco | ✅ Alinhado |

---

## ⚠️ DIFERENÇAS CRÍTICAS (Precisa ajustar)

### 1. **ANUM SCORES E AÇÕES** 🔴 CRÍTICO

**Master Document (2025):**
```yaml
score_0_30_frio:
  classificacao: "Lead frio"
  acao_frank: "Continua descobrindo, tenta aquecer educando"
  probabilidade_fechar: "<10%"

score_31_60_morno:
  classificacao: "Lead morno"
  acao_frank: "Oferece Mesa de Clareza™ (gratuita)"
  probabilidade_fechar: "30-40%"

score_61_100_quente:
  classificacao: "Lead quente"
  acao_frank: "Agenda reunião ou propõe Implementação direto"
  probabilidade_fechar: "60-80%"
```

**v6.1.0 (Atual):**
```
ANUM < 55: Graceful exit
ANUM 55-69: Offer Mesa (positioning: "descoberta sem compromisso")
ANUM ≥ 70: Offer Mesa (positioning: "próximo passo para começar")
```

**PROBLEMA IDENTIFICADO:**
- ❌ **Thresholds diferentes:** Master usa 0-30/31-60/61+ vs v6.1.0 usa <55/55-69/≥70
- ❌ **Mesa oferecida em scores diferentes:** Master oferece Mesa para 31-60, v6.1.0 oferece para 55-69 E ≥70
- ❌ **Ação para leads quentes diverge:** Master diz "propõe Implementação direto", v6.1.0 sempre oferece Mesa primeiro

**IMPACTO:** 🔴 **ALTO** - Lógica de qualificação fundamental está desalinhada

---

### 2. **POSICIONAMENTO DA MESA DE CLAREZA** 🟡 MÉDIO

**Master Document:**
```yaml
quando_ofertar:
  - "Lead qualificado (score 50-69) mas hesitante"
  - "Lead quer entender melhor antes de comprometer R$ 997"
  - "Lead tem dúvidas sobre fit no setor dele"
  - "Lead perdeu tempo com chatbot antes, quer garantia"
```

**v6.1.0:**
- ANUM ≥70: Mesa posicionada como "próximo passo para começar" (apresenta Implementation ANTES)
- ANUM 55-69: Mesa posicionada como "descoberta sem compromisso"

**PROBLEMA:**
- ⚠️ Master sugere Mesa para "50-69" (hesitante), não menciona ofertar para leads ≥70
- ⚠️ v6.1.0 oferece Mesa para AMBOS 55-69 E ≥70, com pitches diferentes

**IMPACTO:** 🟡 **MÉDIO** - Posicionamento da oferta pode confundir

---

### 3. **CITAÇÃO DE CONCORRENTES** 🟡 MÉDIO

**Master Document (Decisão Estratégica):**
```yaml
DECISÃO ESTRATÉGICA: Comparamos com categoria "Plataformas DIY" genérica,
NÃO citamos concorrentes específicos (BotConversa, Typebot, Manychat).

motivos_nao_citar:
  risco_awareness: "Cliente não conhecia → agora conhece → pesquisa → compra lá"
  risco_desatualizacao: "Concorrente muda preço → nosso site desatualizado"
  risco_legal: "Comparação comercial negativa pode gerar processo"
  risco_percepção: "Parece obsessão ou insegurança"
```

**v6.1.0:**
Cita **"BotConversa"** especificamente em:
- Linha ~255: "CoreAdapt pode não ser a melhor opção... BotConversa (R$ 199-297/mês)"
- Linha ~896: "BotConversa: R$ 297/mês + SEU tempo..."
- Linha ~937: "BotConversa sim! BotConversa (R$ 199-297/mês), Typebot..."

**PROBLEMA:**
- ❌ v6.1.0 viola decisão estratégica de NÃO citar concorrentes específicos
- ❌ Risco de dar propaganda grátis para BotConversa

**IMPACTO:** 🟡 **MÉDIO** - Estratégico, não operacional

---

### 4. **TOM DE VOZ E BUZZWORDS** 🟢 BAIXO

**Master Document evita:**
```yaml
evitar_absolutamente:
  buzzwords_vazios:
    - "❌ Transformação digital"
    - "❌ Revolução, disrupção"
    - "❌ Inteligência Adaptativa™ (removido)"
    - "❌ Ecossistema sinérgico"
```

**v6.1.0:**
Auditoria rápida não encontrou buzzwords graves, mas há algumas expressões formais:
- "Pelo que você me contou" (aparece múltiplas vezes - pode ser mais natural)
- Tom geral é bom, mas poderia ser mais direto em alguns pontos

**IMPACTO:** 🟢 **BAIXO** - Tom está majoritariamente correto

---

## 📋 RECOMENDAÇÕES

### Opção 1: **CRIAR v6.2.0 (FORMATO COMPLETO)** ⭐ RECOMENDADO

**Mudanças necessárias:**

1. **Atualizar ANUM Scores:**
   - 0-30: Lead frio → Continua descobrindo
   - 31-60: Lead morno → Oferece Mesa de Clareza
   - 61-100: Lead quente → Propõe Implementação direto OU oferece Mesa (se hesitante)

2. **Ajustar Offer Logic:**
   - ANUM 61-100 (quente): Apresenta Implementation com todos os detalhes, DEPOIS oferece Mesa
   - ANUM 31-60 (morno): Oferece Mesa como descoberta
   - ANUM 0-30 (frio): Continua descobrindo ou graceful exit

3. **Remover citações específicas de concorrentes:**
   - Substituir "BotConversa" → "Plataformas DIY"
   - Substituir "Typebot" → "Plataformas DIY"
   - Manter comparação genérica

**Versionamento:**
- `FRANK_SYSTEM_MESSAGE_v6.1.0.md` → Manter (garantia 30 dias, scores antigos)
- `FRANK_SYSTEM_MESSAGE_v6.2.0.md` → Criar (alinhado com Master Document)

---

### Opção 2: **NÃO MUDAR (Manter v6.1.0)** ❌ NÃO RECOMENDADO

**Se você escolher isso:**
- v6.1.0 fica DESALINHADO com Master Document
- Risco de confusão futura (qual é a fonte da verdade?)
- Concorrentes continuam sendo citados (contrário à decisão estratégica)

---

## 🎯 DECISÃO REQUERIDA

**Francisco, você precisa decidir:**

**1. ANUM Scores:** Qual usar?
- [ ] **Master Document:** 0-30 / 31-60 / 61-100
- [ ] **v6.1.0 atual:** <55 / 55-69 / ≥70

**2. Mesa para leads quentes (≥60 ou ≥70):**
- [ ] **Master:** Propõe Implementation direto, Mesa só se hesitante
- [ ] **v6.1.0:** SEMPRE oferece Mesa (mas apresenta Implementation primeiro)

**3. Citação de concorrentes:**
- [ ] **Master:** Genérico "Plataformas DIY" (sem citar BotConversa)
- [ ] **v6.1.0:** Cita "BotConversa" e "Typebot" especificamente

---

## ✅ PRÓXIMOS PASSOS

**SE você decidir alinhar com Master Document:**

1. Eu crio `FRANK_SYSTEM_MESSAGE_v6.2.0.md` com:
   - ANUM scores: 0-30 / 31-60 / 61-100
   - Offer logic: Implementation direto para ≥61, Mesa para 31-60
   - Sem citação de concorrentes específicos

2. Mantenho `v6.1.0` no repositório (histórico)

3. Deploy: v6.2.0 (alinhado com Master)

**SE você decidir manter v6.1.0:**
- Nada muda
- Mas recomendo documentar POR QUE escolheu scores diferentes do Master

---

**Me confirma qual caminho seguir.**
