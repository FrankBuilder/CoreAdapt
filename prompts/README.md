# Prompts dos Agentes CoreConnect.AI

## Versão: Janeiro 2026 — Alinhados com Manifesto

Estes prompts foram escritos para alinhamento total com:
- **Manifesto Estratégico de Posicionamento — Francisco Pasteur**
- **Diretrizes Comportamentais dos Agentes CoreConnect.AI**
- **Sync Flow v4** (lógica real de scoring ANUM)

---

## Arquivos

| Arquivo | Agente | Uso |
|---------|--------|-----|
| `FRANK_v8.0_SYSTEM_MESSAGE.txt` | FRANK | Copiar no node AI Agent do One Flow |
| `SENTINEL_v3.0_SYSTEM_MESSAGE.txt` | SENTINEL | Copiar no node AI Agent do Sentinel Flow |
| `SYNC_v3.0_SYSTEM_MESSAGE.txt` | SYNC | Copiar no node AI Agent do Sync Flow |

---

## Como Usar

1. Abra o flow correspondente no n8n
2. Localize o node **AI Agent**
3. Em **Options > System Message**, substitua pelo conteúdo do arquivo `.txt`
4. Salve o flow

---

## Resumo dos Agentes

### FRANK (Consultor de Triagem)
- **Papel:** Conversa com leads, qualifica naturalmente
- **Tom:** Humano, calmo, direto, sem jargões técnicos
- **Objetivo:** Lead quer falar com Pasteur OU entende que não é momento

### SENTINEL (Reengajamento)
- **Papel:** Vai atrás de leads que esfriaram
- **Tom:** Econômico, cirúrgico, contextual
- **Objetivo:** Reabrir conversa sem parecer insistente

### SYNC (Analítico Silencioso)
- **Papel:** Analisa conversas, extrai scores ANUM
- **Output:** JSON com scores, evidências, categoria de dor
- **Não conversa** — apenas dados estruturados

---

## ANUM Scoring (SYNC)

```
total_score = (authority + need + urgency + money) / 4
```

| Stage | Condição |
|-------|----------|
| `pre` | total < 40 |
| `partial` | total 40-59 |
| `full` | total ≥60 E nenhuma dimensão = 0 |
| `full_but_incomplete` | total ≥60 MAS alguma dimensão = 0 |
| `rejected` | Desqualificação explícita |

---

## Princípio Central

> "Negócios não quebram por falta de esforço. Quebram por excesso de dependência do dono."

Francisco Pasteur **destrava negócios**. Não vende software, ferramentas ou IA.

---

## Histórico de Versões

| Data | Versão | Mudança |
|------|--------|---------|
| Jan 2026 | FRANK v8.0 | Versão completa com tabelas, exemplos, regras detalhadas |
| Jan 2026 | SENTINEL v3.0 | Versão completa com templates, casos especiais, ciclo de reengajamento |
| Jan 2026 | SYNC v3.0 | Versão completa com scoring correto (média 0-100), pain categories |

## Tamanho dos Arquivos

| Arquivo | Tamanho | Linhas |
|---------|---------|--------|
| FRANK | ~18KB | ~600 linhas |
| SENTINEL | ~16KB | ~550 linhas |
| SYNC | ~7KB | ~230 linhas |

Todos os prompts são versões **completas** com:
- Tabelas detalhadas de comportamento
- Exemplos de boas e más respostas
- Regras explícitas e invioláveis
- Casos especiais e edge cases
- Formatação para WhatsApp
