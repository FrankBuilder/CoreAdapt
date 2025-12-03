# Seeds - Dados de Demonstração CoreAdapt v4

Este diretório contém scripts SQL para popular o banco de dados com dados de demonstração realistas para o tenant **CoreConnect** (company_id = 1).

## Visão Geral dos Dados

| Dado | Quantidade | Período |
|------|------------|---------|
| Leads (contacts) | 53 | Ago-Dez/2025 |
| Lead States (ANUM) | 50 | Com scores variados |
| Chat History | ~150 msgs | Conversas realistas |
| Follow-up Campaigns | 35 | Diversos status |
| Scheduled Meetings | 25 | Passadas e futuras |
| Pain Categories | 10 | Categorias de dor |

## Distribuição dos Leads

### Por Mês
- **Agosto 2025**: 8 leads
- **Setembro 2025**: 12 leads
- **Outubro 2025**: 15 leads
- **Novembro 2025**: 10 leads
- **Dezembro 2025**: 5 leads
- **Opt-out**: 3 leads

### Por Score ANUM
- **Highly Qualified (85-100)**: 3 leads (~5%)
- **Qualified (70-84)**: 15 leads (~30%)
- **Developing (30-69)**: 25 leads (~50%)
- **Pre-qualified (0-29)**: 7 leads (~15%)

### Por Setor
Tecnologia, Varejo, Atacado, Saúde, Agronegócio, Educação, Automotivo, Beleza, Construção, Farmacêutico, Logística, Fintech, Alimentos, Imobiliário, Hotelaria, Indústria, Marketing, E-commerce, Fitness, Gráfica, Contabilidade, Eventos, Jurídico, Energia, Pet, Veterinário, Decoração, Turismo

## Como Executar

### Opção 1: Supabase SQL Editor (Recomendado)

1. Acesse o Supabase Dashboard
2. Vá em **SQL Editor**
3. Execute os scripts **na ordem**:

```
1. 01_pain_categories.sql
2. 02_contacts.sql
3. 03_lead_states.sql
4. 04_chat_history.sql
5. 05_followup_campaigns.sql
6. 06_scheduled_meetings.sql
```

### Opção 2: psql (linha de comando)

```bash
# Conectar ao banco
psql "postgresql://postgres:[PASSWORD]@db.[PROJECT].supabase.co:5432/postgres"

# Executar scripts
\i seeds/01_pain_categories.sql
\i seeds/02_contacts.sql
\i seeds/03_lead_states.sql
\i seeds/04_chat_history.sql
\i seeds/05_followup_campaigns.sql
\i seeds/06_scheduled_meetings.sql
```

### Opção 3: Script concatenado

Se preferir, você pode concatenar todos os arquivos e executar de uma vez:

```bash
cat seeds/01_pain_categories.sql \
    seeds/02_contacts.sql \
    seeds/03_lead_states.sql \
    seeds/04_chat_history.sql \
    seeds/05_followup_campaigns.sql \
    seeds/06_scheduled_meetings.sql > seeds/all_seeds.sql
```

## Identificação dos Dados Demo

Todos os dados de demonstração são identificados por:

1. **Tag 'demo'** nos contacts: `tags @> ARRAY['demo']::text[]`
2. **IDs específicos**:
   - Contacts: 1001-1053
   - Lead States: 2001-2050
   - Campaigns: 3001-3050
   - Executions: 4001+
   - Meetings: 5001-5025

## Removendo os Dados Demo

Para limpar **APENAS** os dados de demonstração:

```sql
-- Execute o script de cleanup
\i seeds/99_cleanup_demo_data.sql
```

Este script remove apenas registros com tag 'demo', não afetando dados reais.

## Estrutura dos Arquivos

```
seeds/
├── README.md                    # Este arquivo
├── 01_pain_categories.sql       # Categorias de dor
├── 02_contacts.sql              # 53 leads brasileiros
├── 03_lead_states.sql           # Scores ANUM
├── 04_chat_history.sql          # Histórico de conversas
├── 05_followup_campaigns.sql    # Campanhas + executions
├── 06_scheduled_meetings.sql    # Reuniões agendadas
└── 99_cleanup_demo_data.sql     # Script de limpeza
```

## Dados Inclusos

### Reuniões

| Tipo | Quantidade |
|------|------------|
| Realizadas com sucesso | 10 |
| No-show | 3 |
| Canceladas | 2 |
| Futuras (próximos 30 dias) | 10 |

### Campanhas de Follow-up

| Status | Quantidade |
|--------|------------|
| Ativas | 18 |
| Completadas | 8 |
| Paradas (reunião) | 9 |
| Paradas (opt-out) | 3 |

### Setores com Mais Leads

1. Saúde (clínicas, laboratórios, odonto, veterinário)
2. Tecnologia (software, fintech, startup)
3. Varejo (moda, pet, e-commerce)
4. Indústria (têxtil, alimentos, metalurgia)

## Nomes Utilizados

Todos os nomes são fictícios mas realistas para o Brasil:
- Ricardo Mendes Silva
- Fernanda Costa Oliveira
- Dra. Mariana Santos Lima
- Beatriz Campos Lima
- Eduardo Henrique Lopes
- E mais 48...

## Notas Importantes

1. **Não execute em produção com dados reais** sem backup
2. Os IDs usados (1001+) foram escolhidos para evitar conflitos
3. Se já existirem IDs nessa faixa, ajuste os scripts
4. Os dados são consistentes entre si (FKs válidas)
5. Timestamps são de Ago-Dez 2025, compatíveis com a data atual

## Suporte

Se encontrar problemas, verifique:
1. Ordem de execução dos scripts
2. Existência das tabelas base (corev4_*)
3. Permissões no banco de dados
4. Conflitos de IDs

---

**Última atualização:** 2025-12-03
**Versão:** CoreAdapt v4.1
