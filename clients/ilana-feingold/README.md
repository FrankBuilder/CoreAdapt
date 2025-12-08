# Cliente: Dra. Ilana Feingold

**Tipo:** Consultório de Psicologia
**Tenant:** ilana-feingold
**Created:** December 8, 2025

---

## Sobre a Cliente

**Profissional:** Dra. Ilana Feingold
**CRP:** 11/04021
**Experiência:** 20 anos
**Especialização:** TCC, Terapia do Esquema, PNL

**Nicho:**
- Jovens e adultos
- Casais
- Expatriados
- Executivos

**Demandas principais:**
- Ansiedade
- Burnout
- Relacionamentos
- Autoconhecimento
- Depressão
- Relações abusivas / narcisismo
- Performance profissional

**Não atende:**
- Crianças
- Pacientes com quadros psicóticos

---

## Arquivos do Tenant

```
clients/ilana-feingold/
├── README.md                              # Este arquivo
├── LIS_SYSTEM_MESSAGE_v1.0.md            # Prompt principal (CoreOne equivalent)
├── LIS_SENTINEL_SYSTEM_MESSAGE_v1.0.md   # Prompt de follow-up (Sentinel)
└── migrations/
    ├── 00_CLEANUP.sql                     # Limpar dados parciais (se der erro)
    └── 01_QUICK_SETUP.sql                 # Setup completo (empresa + followup + categorias)
```

---

## Configuração

### Agente Principal: LIS

**Nome:** Lis
**Persona:** Assistente virtual acolhedora
**Framework:** MAP (Motivação, Alinhamento, Prontidão)

**Diferenças do FRANK (CoreAdapt original):**
- Não usa ANUM (muito comercial para saúde mental)
- Foco em acolhimento, não qualificação
- Responde perguntas antes de fazer perguntas
- Triagem leve (apenas casos de exclusão)
- Não faz diagnósticos

### Follow-up: LIS SENTINEL

**Steps:** 4 (vs 5 do original)
**Timing:**
- Step 1: 6 horas (vs 1 hora)
- Step 2: 2 dias (vs 1 dia)
- Step 3: 5 dias (vs 3 dias)
- Step 4: 10 dias (vs 13 dias)

**Tom:** Muito mais suave, sem urgência artificial

---

## Serviços e Preços

| Serviço | Valor |
|---------|-------|
| Sessão avulsa | R$ 380 |
| Plano mensal (4 sessões) | R$ 1.400 |

**Duração:** ~50 minutos (flexível)
**Modalidades:** Online, Presencial, Híbrido

---

## Agendamento

**Cal.com:**
```
https://cal.com/francisco-pasteur-coreadapt/agenda-dra.ilana-feingold
```

**Secretária (Nara):**
```
WhatsApp: (85) 98869-2353
```

**Horários:**
- Segunda: 14h-19h
- Terça: 14h-19h
- Quinta: 14h-19h
- Quarta: Eventualmente (urgências)

---

## Deployment Checklist

### Setup do Banco de Dados

**Se for a primeira vez:**
```sql
-- Execute: migrations/01_QUICK_SETUP.sql
-- Cria: empresa, followup config, steps, categorias
```

**Se deu erro e precisa recomeçar:**
```sql
-- Execute PRIMEIRO: migrations/00_CLEANUP.sql
-- DEPOIS: migrations/01_QUICK_SETUP.sql
```

### Checklist Completo

**Banco de Dados (Supabase):**
- [ ] Executar `01_QUICK_SETUP.sql` no SQL Editor
- [ ] Verificar company_id criado
- [ ] Configurar Evolution API (url, instance, api_key) na empresa

**n8n (Workflows):**
- [ ] Duplicar workflow CoreAdapt One Flow
- [ ] Substituir system_prompt pelo conteúdo de `LIS_SYSTEM_MESSAGE_v1.0.md`
- [ ] Configurar company_id nos nodes
- [ ] Duplicar workflow CoreAdapt Sentinel Flow
- [ ] Substituir system_prompt pelo conteúdo de `LIS_SENTINEL_SYSTEM_MESSAGE_v1.0.md`

**Evolution API:**
- [ ] Criar instância WhatsApp
- [ ] Configurar webhook apontando para n8n
- [ ] Testar conexão

**Testes:**
- [ ] Enviar mensagem "oi" e verificar resposta da Lis
- [ ] Verificar se followup é criado corretamente
- [ ] Testar fluxo de agendamento

---

## Contatos

**Cliente:** Dra. Ilana Feingold
**WhatsApp Consultório:** (85) 98869-2353
**Secretária:** Nara

---

## Changelog

### v1.0 (December 8, 2025)
- Initial setup
- Created LIS_SYSTEM_MESSAGE_v1.0.md
- Created LIS_SENTINEL_SYSTEM_MESSAGE_v1.0.md
- Created motivation_categories seed
