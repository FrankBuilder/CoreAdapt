# CoreAdapt Flows — Versões Atuais

## Última Atualização: 06/01/2026

### Fluxos Principais

| Flow | Versão | Arquivo | Descrição |
|------|--------|---------|-----------|
| One Flow | v4.6 | `CoreAdapt One Flow _ v4.6.json` | FRANK v8.0.0 (Manifesto-Aligned) |
| Availability Flow | v4.4 | `CoreAdapt Availability Flow _ v4.4.json` | Google Calendar + Timezone fix |
| Booking Flow | v4.3 | `CoreAdapt Booking Flow _ v4.3.json` | Subworkflow Trigger + Calendar |

### FRANK (AI Agent)

| Versão | Data | Mudanças |
|--------|------|----------|
| v8.0.0 | 06/01/2026 | Tom sóbrio alinhado com Manifesto de Posicionamento |
| v7.2.0 | 06/01/2026 | Regra de agendamento autônomo |
| v7.1.0 | - | WhatsApp formatting |
| v6.3.0 | - | Versão anterior (deprecated) |

### Histórico de Mudanças

#### v4.6 (One Flow) — 06/01/2026
- FRANK v8.0.0 com tom sóbrio e direto
- Removidas frases de vendedor ("Ótimo!", "Perfeito!")
- Posicionamento alinhado com Manifesto
- Foco em "destravar negócios" não "vender ferramenta"

#### v4.5 (One Flow) — 06/01/2026
- FRANK v7.2.0 com regra de não inventar horários
- Detecção de slots inventados
- Remoção de Cal.com

#### v4.4 (Availability Flow) — 06/01/2026
- Fix de timezone (Intl.DateTimeFormat)
- Distribuição de slots: 1 do primeiro dia + 2 do segundo
- Subworkflow Trigger para chamadas internas

#### v4.3 (Booking Flow) — 06/01/2026
- Subworkflow Trigger adicionado
- Integração com Google Calendar
- Criação de eventos automática

### Arquivos Legados (não usar)

- `CoreAdapt One Flow _ v4.json` — Versão base
- `CoreAdapt One Flow _ v4.1_AUTONOMOUS.json` — Primeira versão autônoma
- `CoreAdapt One Flow _ v4.5_AUTONOMOUS.json` — FRANK v7.2.0
- `CoreAdapt One Flow _ v4.6_MANIFESTO.json` — Intermediário

### Como Importar no n8n

1. Acesse n8n
2. Vá em Workflows → Import from File
3. Selecione os arquivos na ordem:
   - `CoreAdapt Availability Flow _ v4.4.json`
   - `CoreAdapt Booking Flow _ v4.3.json`
   - `CoreAdapt One Flow _ v4.6.json`
4. Configure as credenciais (Google Calendar, OpenAI, Supabase)
5. Configure os Execute Subworkflow nodes para apontar para os IDs corretos
6. Ative os fluxos

### Variáveis de Ambiente Necessárias

```
SUPABASE_URL=
SUPABASE_SERVICE_KEY=
OPENAI_API_KEY=
GOOGLE_CALENDAR_ID=
```
