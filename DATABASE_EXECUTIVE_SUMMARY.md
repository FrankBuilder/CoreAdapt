# 📊 DEEP DIVE DATABASE ANALYSIS - CoreAdapt v4
## Sumário Executivo

**Data da Análise**: 2025-11-10
**Banco de Dados**: PostgreSQL (Supabase)
**Schema**: corev4
**Versão**: v4

---

## 🎯 VISÃO GERAL

O CoreAdapt v4 é um sistema de gestão de leads inteligente com automação de follow-up, qualificação ANUM e agendamento de reuniões. O banco de dados está bem estruturado com **22 tabelas**, **14 views**, **2 functions** e **134 índices**.

### Estatísticas do Banco

| Métrica | Valor |
|---------|-------|
| Tabelas | 22 |
| Colunas Totais | 350 |
| Índices | 134 |
| Foreign Keys | 41 |
| Triggers | 8 |
| Views | 14 |
| Functions | 2 |
| Tabelas com RLS | 17 |

---

## 📁 CATEGORIZAÇÃO DAS TABELAS

### 1. Gestão de Contatos (3 tabelas)
Núcleo central do sistema - armazenamento de contatos e empresas.

- **corev4_contacts** (19 campos) - Contatos principais
- **corev4_contact_extras** (16 campos) - Dados extras e integrações
- **corev4_companies** (38 campos) - Dados das empresas/clientes

**Propósito**: Gerenciar cadastro de leads e empresas clientes. Inclui dados de contato, origem (UTMs), segmentação e opt-out.

**Relacionamentos**: Hub central - todas as outras tabelas referenciam contacts ou companies.

---

### 2. Conversas e Mensagens (5 tabelas)
Sistema completo de chat e histórico de conversas.

- **corev4_chats** (13 campos) - Gerenciamento de conversas ativas
- **corev4_chat_history** (15 campos) - Histórico de mensagens
- **corev4_message_dedup** (9 campos) - Deduplicação de mensagens
- **corev4_message_media** (19 campos) - Mídias anexadas
- **corev4_n8n_chat_histories** (4 campos) - Integração N8N

**Propósito**: Armazenar todas as interações via chat/WhatsApp, incluindo mensagens do lead e respostas do bot (Frank). Controla estado da conversa (aberta/fechada) e batch collection.

**Fluxos principais**:
- CoreAdapt Main Router Flow
- CoreAdapt One Flow
- Process Audio Message

---

### 3. Qualificação de Leads - ANUM (3 tabelas)
Sistema de pontuação e qualificação de leads usando metodologia ANUM.

- **corev4_lead_state** (19 campos) - Estado atual de qualificação
- **corev4_anum_history** (23 campos) - Histórico de análises
- **corev4_pain_categories** (11 campos) - Categorias de dores/problemas

**Propósito**: Avaliar leads em 4 dimensões (Authority, Need, Urgency, Money) gerando score de 0-100. Categoriza dores e mantém histórico de evolução da qualificação.

**Scores**:
- **Authority**: Poder de decisão
- **Need**: Necessidade/dor identificada
- **Urgency**: Urgência da solução
- **Money**: Capacidade financeira

**Fluxos principais**:
- CoreAdapt Sentinel Flow (análise ANUM)
- CoreAdapt Scheduler Flow

---

### 4. Follow-up e Campanhas (6 tabelas)
Sistema automatizado de nutrição de leads.

- **corev4_followup_campaigns** (13 campos) - Campanhas ativas
- **corev4_followup_configs** (10 campos) - Configurações de campanha
- **corev4_followup_executions** (19 campos) - Execuções agendadas
- **corev4_followup_sequences** (9 campos) - Sequências de mensagens
- **corev4_followup_steps** (7 campos) - Passos da sequência
- **corev4_followup_stage_history** (10 campos) - Histórico de estágios

**Propósito**: Automação de follow-up multi-step. Envia mensagens programadas baseadas em intervalo de tempo e score ANUM. Pausa automaticamente quando lead responde ou agenda reunião.

**Lógica de execução**:
1. Campanha criada com config_id
2. Execuções agendadas baseadas em steps (wait_hours/wait_minutes)
3. Sistema verifica condições antes de enviar (opt_out, reunião agendada, resposta do lead)
4. Marca execução como enviada e atualiza campanha

**Fluxos principais**:
- CoreAdapt Scheduler Flow (execução)
- Create Followup Campaign

---

### 5. Reuniões e Agendamentos (2 tabelas)
Integração com Cal.com para agendamento de "Mesa de Clareza".

- **corev4_scheduled_meetings** (48 campos) - Reuniões agendadas
- **corev4_meeting_offers** (21 campos) - Ofertas de reunião enviadas

**Propósito**: Armazenar reuniões agendadas via Cal.com. Inclui dados do booking, participante, lembretes (24h e 1h antes), status e outcome.

**Estados**:
- scheduled → confirmed → completed
- ou scheduled → cancelled/rescheduled

**Fluxos principais**:
- CoreAdapt Meeting Reminders Flow
- CoreAdapt Commands Flow (marcar no-show, conclusão)

---

### 6. Inteligência Artificial (1 tabela)
Registro de decisões tomadas por IA.

- **corev4_ai_decisions** (11 campos) - Decisões de IA

**Propósito**: Auditoria de decisões tomadas por LLM (ex: enviar ou não follow-up). Armazena contexto, raciocínio, confiança, tokens e custo.

**Uso**: Debugging e análise de comportamento do bot.

---

### 7. Logs e Auditoria (1 tabela)
Logs de execução de workflows.

- **corev4_execution_logs** (11 campos) - Logs de execução

**Propósito**: Registro de execuções de workflows N8N. Rastreia performance, erros e métricas.

---

### 8. Utilitários (1 tabela)
Tabelas de suporte técnico.

- **corev4_session_id_migration** (5 campos) - Migração de UUIDs

**Propósito**: Tabela temporária para migração de session_ids de integer para UUID.

---

## 🔗 FLUXO DE DADOS PRINCIPAL

```
1. LEAD ENTRA
   ↓
2. corev4_contacts (criado/atualizado)
   ↓
3. corev4_chats + corev4_chat_history (conversa)
   ↓
4. corev4_lead_state (análise ANUM via Sentinel)
   ↓
5. DECISÃO:

   A) Score alto → corev4_meeting_offers → corev4_scheduled_meetings
      └─> FIM (meta atingida)

   B) Score médio/baixo → corev4_followup_campaigns
      ↓
      corev4_followup_executions (nutrição automática)
      ↓
      Volta para (3) quando lead responde

   C) Opt-out ou desqualificação → PAUSA
```

---

## ✅ PONTOS FORTES DO BANCO DE DADOS

1. **Nomenclatura Consistente**: 100% das tabelas seguem padrão `corev4_` + snake_case
2. **Segurança Multi-tenant**: 17/22 tabelas com RLS habilitado
3. **Integridade Referencial**: 41 Foreign Keys garantindo consistência
4. **Otimização**: 134 índices bem distribuídos
5. **Auditoria**: Triggers automáticos para updated_at em todas as tabelas relevantes
6. **Soft Delete**: Implementado via is_active em tabelas principais
7. **Flexibilidade**: Uso estratégico de JSONB para dados semi-estruturados

---

## ⚠️ PROBLEMAS IDENTIFICADOS

### 🔴 Alta Prioridade

1. **3 Foreign Keys sem índice** - podem causar lentidão em JOINs:
   - `corev4_companies.default_followup_config_id`
   - `corev4_meeting_offers.booking_id`
   - `corev4_followup_stage_history.company_id`

2. **2 tabelas com coluna company_id mas sem RLS**:
   - `corev4_message_dedup`
   - `corev4_session_id_migration`

### 🟡 Média Prioridade

3. **17 tabelas com PRIMARY KEY INTEGER** (limite de 2 bilhões)
   - Recomendação: migrar para BIGINT para produção de longo prazo

4. **15/22 tabelas sem descrição** (COMMENT ON TABLE)
   - Dificulta onboarding e manutenção

5. **10 tabelas sem campo updated_at**
   - Dificulta auditoria de alterações

### 🟢 Baixa Prioridade

6. **Inconsistência TEXT vs VARCHAR**
   - 70 colunas TEXT vs 49 VARCHAR
   - No PostgreSQL, TEXT é preferível (sem overhead)

---

## 🎯 RECOMENDAÇÕES PRIORITÁRIAS

### Ação Imediata (1-2 semanas)

1. **Adicionar índices nas 3 Foreign Keys faltantes**
   ```sql
   CREATE INDEX idx_companies_default_followup_config
     ON corev4_companies(default_followup_config_id);

   CREATE INDEX idx_meeting_offers_booking
     ON corev4_meeting_offers(booking_id);

   CREATE INDEX idx_followup_stage_history_company
     ON corev4_followup_stage_history(company_id);
   ```

2. **Habilitar RLS nas 2 tabelas faltantes**
   ```sql
   ALTER TABLE corev4_message_dedup ENABLE ROW LEVEL SECURITY;
   ALTER TABLE corev4_session_id_migration ENABLE ROW LEVEL SECURITY;

   CREATE POLICY tenant_isolation_message_dedup ON corev4_message_dedup
     USING (company_id = current_setting('app.current_company_id', true)::integer);
   ```

### Médio Prazo (1-2 meses)

3. **Adicionar descrições em todas as tabelas**
   ```sql
   COMMENT ON TABLE corev4_companies IS
     'Dados das empresas clientes do CoreAdapt - configurações gerais, integrações e branding';

   COMMENT ON TABLE corev4_lead_state IS
     'Estado atual de qualificação ANUM de cada lead - snapshot da última análise';

   -- ... (continuar para todas as 15 tabelas)
   ```

4. **Adicionar campo updated_at nas 10 tabelas faltantes**
   ```sql
   ALTER TABLE corev4_message_dedup
     ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();

   CREATE TRIGGER update_message_dedup_updated_at
     BEFORE UPDATE ON corev4_message_dedup
     FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
   ```

### Longo Prazo (3-6 meses)

5. **Planejar migração de INTEGER para BIGINT em PKs**
   - Criar estratégia de migração sem downtime
   - Testar em ambiente de staging
   - Executar em janela de manutenção

6. **Padronizar tipos de string para TEXT**
   - Revisar colunas VARCHAR
   - Migrar para TEXT onde apropriado

---

## 📈 MÉTRICAS DE QUALIDADE DO BANCO

| Aspecto | Score | Observação |
|---------|-------|------------|
| Nomenclatura | 10/10 | ✅ Perfeito - 100% consistente |
| Indexação | 9/10 | ⚠️ Faltam 3 índices em FKs |
| Segurança (RLS) | 9/10 | ⚠️ Faltam 2 tabelas |
| Documentação | 4/10 | 🔴 68% das tabelas sem descrição |
| Auditoria | 7/10 | ⚠️ 10 tabelas sem updated_at |
| Integridade | 10/10 | ✅ Todas as FKs bem definidas |
| Escalabilidade | 7/10 | ⚠️ PKs INTEGER limitam crescimento |
| **SCORE GERAL** | **8.0/10** | **Bom - com melhorias identificadas** |

---

## 🏆 COMPARAÇÃO COM PADRÕES DA INDÚSTRIA

| Best Practice | Status | CoreAdapt v4 |
|---------------|--------|--------------|
| snake_case | ✅ | 100% conforme |
| Primary Keys | ✅ | Todas as tabelas |
| Foreign Keys | ✅ | 41 relacionamentos |
| Índices em FKs | ⚠️ | 93% (faltam 3) |
| Timestamps | ⚠️ | 95% created_at, 55% updated_at |
| RLS Multi-tenant | ✅ | 91% (17/22) |
| Soft Delete | ✅ | Implementado |
| Documentação | ❌ | 32% documentado |
| BIGINT para PKs | ⚠️ | 14% (tendência moderna) |
| Uso de Views | ✅ | 14 views bem estruturadas |

**Veredicto**: CoreAdapt v4 está **acima da média** da indústria em estrutura e segurança, mas pode melhorar em documentação e preparação para escala.

---

## 📚 DOCUMENTAÇÃO GERADA

Esta análise gerou 3 documentos detalhados:

1. **DATABASE_DEEP_DIVE_ANALYSIS.md** (1.637 linhas)
   - Análise detalhada de cada tabela
   - Todos os campos com propósitos inferidos
   - Relacionamentos completos
   - Views e Functions
   - Diagrama ERD em Mermaid

2. **DATABASE_RECOMMENDATIONS.md** (245 linhas)
   - Análise crítica de nomenclatura
   - Problemas de performance
   - Issues de segurança
   - Recomendações priorizadas

3. **DATABASE_EXECUTIVE_SUMMARY.md** (este documento)
   - Visão executiva consolidada
   - Métricas de qualidade
   - Roadmap de melhorias

---

## 🎓 GLOSSÁRIO DE TERMOS

- **ANUM**: Authority, Need, Urgency, Money - metodologia de qualificação de leads
- **RLS**: Row Level Security - segurança em nível de linha do PostgreSQL
- **Mesa de Clareza**: Nome da reunião de diagnóstico oferecida aos leads
- **Frank**: Nome do bot/assistente virtual
- **Evolution API**: API para integração com WhatsApp
- **Cal.com**: Plataforma de agendamento de reuniões
- **N8N**: Plataforma de automação de workflows
- **Soft Delete**: Marcar registro como inativo ao invés de deletar (is_active=false)

---

## 🚀 PRÓXIMOS PASSOS SUGERIDOS

### Sprint 1 (Imediato)
- [ ] Adicionar 3 índices em Foreign Keys
- [ ] Habilitar RLS em 2 tabelas faltantes
- [ ] Documentar as 5 tabelas mais críticas

### Sprint 2 (Curto Prazo)
- [ ] Adicionar descrições em todas as 15 tabelas
- [ ] Adicionar updated_at nas 10 tabelas faltantes
- [ ] Criar dashboard de monitoramento das métricas do banco

### Sprint 3 (Médio Prazo)
- [ ] Planejar migração INTEGER → BIGINT
- [ ] Padronizar tipos TEXT vs VARCHAR
- [ ] Revisar e otimizar CASCADE DELETEs

### Backlog (Longo Prazo)
- [ ] Implementar particionamento em tabelas grandes (chat_history)
- [ ] Avaliar archive strategy para dados históricos
- [ ] Criar documentação automática integrada ao CI/CD

---

## 📞 CONTATO

Para dúvidas sobre esta análise ou implementação das recomendações, consulte a documentação completa nos arquivos de análise detalhada.

**Análise realizada por**: Claude (Anthropic)
**Data**: 2025-11-10
**Projeto**: CoreAdapt v4 Database Deep Dive
