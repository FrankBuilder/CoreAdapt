-- ============================================================================
-- SEED: CATEGORIAS DE DOR (Pain Categories)
-- CoreAdapt v4 | Tenant: CoreConnect (company_id = 1)
-- ============================================================================
-- Execute primeiro este script para garantir que as categorias existam
-- ============================================================================

-- Inserir categorias de dor (ignorar se já existirem)
INSERT INTO corev4_pain_categories (id, company_id, category_key, category_label_pt, category_label_en, description, display_order, is_active, created_at)
VALUES
    (1, 1, 'scaling_growth', 'Escalar/Crescer', 'Scaling/Growth', 'Dificuldade em escalar operações e crescer o negócio', 1, true, NOW()),
    (2, 1, 'lead_qualification', 'Qualificação de Leads', 'Lead Qualification', 'Problemas para qualificar leads de forma eficiente', 2, true, NOW()),
    (3, 1, 'sales_conversion', 'Conversão de Vendas', 'Sales Conversion', 'Baixa taxa de conversão de leads em clientes', 3, true, NOW()),
    (4, 1, 'team_productivity', 'Produtividade da Equipe', 'Team Productivity', 'Equipe sobrecarregada ou pouco produtiva', 4, true, NOW()),
    (5, 1, 'customer_service', 'Atendimento ao Cliente', 'Customer Service', 'Problemas no atendimento e suporte ao cliente', 5, true, NOW()),
    (6, 1, 'cost_reduction', 'Redução de Custos', 'Cost Reduction', 'Necessidade de reduzir custos operacionais', 6, true, NOW()),
    (7, 1, 'automation', 'Automação de Processos', 'Process Automation', 'Processos manuais que precisam ser automatizados', 7, true, NOW()),
    (8, 1, 'data_insights', 'Dados e Insights', 'Data & Insights', 'Falta de dados para tomada de decisão', 8, true, NOW()),
    (9, 1, 'competition', 'Concorrência', 'Competition', 'Pressão competitiva no mercado', 9, true, NOW()),
    (10, 1, 'time_management', 'Gestão de Tempo', 'Time Management', 'Falta de tempo para atividades estratégicas', 10, true, NOW())
ON CONFLICT (id) DO NOTHING;

-- Atualizar sequence se necessário
SELECT setval('corev4_pain_categories_id_seq', (SELECT MAX(id) FROM corev4_pain_categories), true);
