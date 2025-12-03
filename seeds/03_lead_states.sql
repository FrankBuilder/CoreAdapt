-- ============================================================================
-- SEED: LEAD STATES (ANUM Scores)
-- CoreAdapt v4 | Tenant: CoreConnect (company_id = 1)
-- ============================================================================
-- Scores ANUM para cada lead com distribuição realista:
-- 15% Pre-qualified (0-29), 50% Developing (30-69),
-- 30% Qualified (70-84), 5% Highly Qualified (85-100)
-- ============================================================================

-- Limpar lead_states dos contatos demo
DELETE FROM corev4_lead_state
WHERE contact_id IN (SELECT id FROM corev4_contacts WHERE tags @> ARRAY['demo']::text[]);

-- Inserir lead states
INSERT INTO corev4_lead_state (
    id, contact_id, company_id,
    authority_score, need_score, urgency_score, money_score, total_score,
    qualification_stage, is_qualified, status,
    main_pain_category_id, main_pain_detail,
    analysis_count, last_analyzed_at, analyzed_at, created_at, updated_at
) VALUES
-- ============================================================================
-- FULL (85-100) - 3 leads (~5%)
-- ============================================================================
(2001, 1001, 1, 92, 88, 85, 90, 88.75, 'full', true, 'hot',
 1, 'Precisa escalar vendas urgentemente, tem budget aprovado e é decisor',
 3, '2025-08-05 14:30:00'::timestamptz, '2025-08-03 12:00:00'::timestamptz, '2025-08-03 12:00:00'::timestamptz, '2025-08-05 14:30:00'::timestamptz),

(2012, 1012, 1, 95, 90, 88, 85, 89.50, 'full', true, 'hot',
 2, 'CEO de fintech precisa qualificar leads de forma automatizada, já testou concorrentes',
 4, '2025-09-15 16:30:00'::timestamptz, '2025-09-12 14:00:00'::timestamptz, '2025-09-12 14:00:00'::timestamptz, '2025-09-15 16:30:00'::timestamptz),

(2028, 1028, 1, 90, 92, 88, 82, 88.00, 'full', true, 'hot',
 3, 'E-commerce com alta demanda, precisa converter mais visitantes em clientes',
 3, '2025-10-20 10:45:00'::timestamptz, '2025-10-17 11:00:00'::timestamptz, '2025-10-17 11:00:00'::timestamptz, '2025-10-20 10:45:00'::timestamptz),

-- ============================================================================
-- FULL (70-84) - 15 leads (~30%)
-- ============================================================================
(2002, 1002, 1, 78, 82, 75, 70, 76.25, 'full', true, 'warm',
 3, 'Loja de moda com vendas estagnadas, quer melhorar conversão no WhatsApp',
 2, '2025-08-12 16:45:00'::timestamptz, '2025-08-10 11:00:00'::timestamptz, '2025-08-10 11:00:00'::timestamptz, '2025-08-12 16:45:00'::timestamptz),

(2004, 1004, 1, 85, 80, 72, 75, 78.00, 'full', true, 'warm',
 5, 'Clínica médica sobrecarregada com agendamentos manuais',
 2, '2025-08-22 10:00:00'::timestamptz, '2025-08-20 15:00:00'::timestamptz, '2025-08-20 15:00:00'::timestamptz, '2025-08-22 10:00:00'::timestamptz),

(2009, 1009, 1, 80, 75, 78, 72, 76.25, 'full', true, 'warm',
 4, 'Construtora com equipe de vendas ineficiente',
 2, '2025-09-05 11:30:00'::timestamptz, '2025-09-02 10:30:00'::timestamptz, '2025-09-02 10:30:00'::timestamptz, '2025-09-05 11:30:00'::timestamptz),

(2014, 1014, 1, 75, 80, 82, 70, 76.75, 'full', true, 'warm',
 3, 'Imobiliária com alto volume de leads não qualificados',
 3, '2025-09-22 15:00:00'::timestamptz, '2025-09-19 12:00:00'::timestamptz, '2025-09-19 12:00:00'::timestamptz, '2025-09-22 15:00:00'::timestamptz),

(2015, 1015, 1, 88, 72, 70, 78, 77.00, 'full', true, 'warm',
 5, 'Clínica odontológica quer automatizar pré-atendimento',
 2, '2025-09-25 11:15:00'::timestamptz, '2025-09-22 10:00:00'::timestamptz, '2025-09-22 10:00:00'::timestamptz, '2025-09-25 11:15:00'::timestamptz),

(2019, 1019, 1, 82, 78, 75, 80, 78.75, 'full', true, 'warm',
 7, 'Software house quer automatizar qualificação de leads B2B',
 3, '2025-09-30 18:30:00'::timestamptz, '2025-09-29 11:00:00'::timestamptz, '2025-09-29 11:00:00'::timestamptz, '2025-09-30 18:30:00'::timestamptz),

(2021, 1021, 1, 90, 78, 72, 68, 77.00, 'full', true, 'warm',
 8, 'Consultoria precisa de insights sobre leads para tomada de decisão',
 2, '2025-10-03 10:00:00'::timestamptz, '2025-10-01 09:30:00'::timestamptz, '2025-10-01 09:30:00'::timestamptz, '2025-10-03 10:00:00'::timestamptz),

(2024, 1024, 1, 70, 85, 80, 75, 77.50, 'full', true, 'warm',
 3, 'Joalheria de luxo precisa melhorar atendimento personalizado',
 2, '2025-10-10 11:00:00'::timestamptz, '2025-10-07 10:30:00'::timestamptz, '2025-10-07 10:30:00'::timestamptz, '2025-10-10 11:00:00'::timestamptz),

(2031, 1031, 1, 75, 72, 78, 82, 76.75, 'full', true, 'warm',
 6, 'Escritório contábil quer reduzir tempo gasto com atendimento básico',
 2, '2025-10-26 11:00:00'::timestamptz, '2025-10-23 10:00:00'::timestamptz, '2025-10-23 10:00:00'::timestamptz, '2025-10-26 11:00:00'::timestamptz),

(2035, 1035, 1, 85, 80, 78, 65, 77.00, 'full', true, 'warm',
 1, 'Startup em fase de crescimento acelerado precisa escalar vendas',
 3, '2025-10-31 18:00:00'::timestamptz, '2025-10-28 15:00:00'::timestamptz, '2025-10-28 15:00:00'::timestamptz, '2025-10-31 18:00:00'::timestamptz),

(2037, 1037, 1, 78, 75, 80, 72, 76.25, 'full', true, 'warm',
 3, 'Atacadista com grande volume de pedidos precisa qualificar compradores',
 2, '2025-11-07 14:15:00'::timestamptz, '2025-11-04 12:30:00'::timestamptz, '2025-11-04 12:30:00'::timestamptz, '2025-11-07 14:15:00'::timestamptz),

(2040, 1040, 1, 72, 78, 75, 80, 76.25, 'full', true, 'warm',
 6, 'Rede de supermercados quer otimizar custos com atendimento',
 2, '2025-11-16 09:30:00'::timestamptz, '2025-11-13 11:00:00'::timestamptz, '2025-11-13 11:00:00'::timestamptz, '2025-11-16 09:30:00'::timestamptz),

(2045, 1045, 1, 80, 72, 85, 70, 76.75, 'full', true, 'warm',
 3, 'Corretor de imóveis com urgência em qualificar leads quentes',
 2, '2025-11-29 14:45:00'::timestamptz, '2025-11-26 12:00:00'::timestamptz, '2025-11-26 12:00:00'::timestamptz, '2025-11-29 14:45:00'::timestamptz),

(2047, 1047, 1, 82, 78, 70, 75, 76.25, 'full', true, 'warm',
 5, 'Laboratório de análises quer automatizar agendamentos',
 2, '2025-12-02 15:30:00'::timestamptz, '2025-12-01 15:00:00'::timestamptz, '2025-12-01 15:00:00'::timestamptz, '2025-12-02 15:30:00'::timestamptz),

-- ============================================================================
-- PARTIAL (30-69) - 25 leads (~50%)
-- ============================================================================
(2003, 1003, 1, 65, 70, 55, 50, 60.00, 'partial', false, 'warm',
 3, 'Distribuidora interessada mas ainda avaliando opções',
 2, '2025-08-18 11:20:00'::timestamptz, '2025-08-15 10:00:00'::timestamptz, '2025-08-15 10:00:00'::timestamptz, '2025-08-18 11:20:00'::timestamptz),

(2005, 1005, 1, 55, 60, 45, 65, 56.25, 'partial', false, 'nurturing',
 1, 'Agroindustria com interesse mas processo de decisão lento',
 2, '2025-08-25 15:30:00'::timestamptz, '2025-08-23 12:00:00'::timestamptz, '2025-08-23 12:00:00'::timestamptz, '2025-08-25 15:30:00'::timestamptz),

(2006, 1006, 1, 50, 68, 55, 45, 54.50, 'partial', false, 'nurturing',
 4, 'Escola de idiomas com equipe pequena, precisa avaliar ROI',
 1, '2025-08-28 09:15:00'::timestamptz, '2025-08-26 17:00:00'::timestamptz, '2025-08-26 17:00:00'::timestamptz, '2025-08-28 09:15:00'::timestamptz),

(2007, 1007, 1, 60, 55, 50, 58, 55.75, 'partial', false, 'nurturing',
 6, 'Autopeças buscando reduzir custos operacionais',
 1, '2025-08-30 13:45:00'::timestamptz, '2025-08-28 11:30:00'::timestamptz, '2025-08-28 11:30:00'::timestamptz, '2025-08-30 13:45:00'::timestamptz),

(2008, 1008, 1, 45, 65, 60, 40, 52.50, 'partial', false, 'nurturing',
 5, 'Salão de beleza com interesse mas budget limitado',
 1, '2025-08-31 17:00:00'::timestamptz, '2025-08-29 15:00:00'::timestamptz, '2025-08-29 15:00:00'::timestamptz, '2025-08-31 17:00:00'::timestamptz),

(2010, 1010, 1, 68, 62, 55, 60, 61.25, 'partial', false, 'warm',
 5, 'Farmácia interessada em melhorar atendimento ao cliente',
 2, '2025-09-08 14:20:00'::timestamptz, '2025-09-05 11:00:00'::timestamptz, '2025-09-05 11:00:00'::timestamptz, '2025-09-08 14:20:00'::timestamptz),

(2011, 1011, 1, 55, 58, 65, 52, 57.50, 'partial', false, 'nurturing',
 7, 'Empresa de logística avaliando automação de processos',
 1, '2025-09-12 10:00:00'::timestamptz, '2025-09-10 09:30:00'::timestamptz, '2025-09-10 09:30:00'::timestamptz, '2025-09-12 10:00:00'::timestamptz),

(2013, 1013, 1, 48, 55, 42, 60, 51.25, 'partial', false, 'nurturing',
 6, 'Indústria alimentícia com interesse mas sem urgência',
 1, '2025-09-18 09:45:00'::timestamptz, '2025-09-15 15:00:00'::timestamptz, '2025-09-15 15:00:00'::timestamptz, '2025-09-18 09:45:00'::timestamptz),

(2016, 1016, 1, 62, 68, 55, 48, 58.25, 'partial', false, 'nurturing',
 5, 'Hotel buscando melhorar experiência do hóspede',
 2, '2025-09-28 14:30:00'::timestamptz, '2025-09-25 12:00:00'::timestamptz, '2025-09-25 12:00:00'::timestamptz, '2025-09-28 14:30:00'::timestamptz),

(2017, 1017, 1, 58, 50, 45, 62, 53.75, 'partial', false, 'nurturing',
 6, 'Metalúrgica interessada em reduzir custos com vendas',
 1, '2025-09-30 10:45:00'::timestamptz, '2025-09-27 16:00:00'::timestamptz, '2025-09-27 16:00:00'::timestamptz, '2025-09-30 10:45:00'::timestamptz),

(2018, 1018, 1, 65, 70, 58, 52, 61.25, 'partial', false, 'warm',
 2, 'Agência de marketing querendo qualificar leads de clientes',
 2, '2025-09-30 17:00:00'::timestamptz, '2025-09-28 14:30:00'::timestamptz, '2025-09-28 14:30:00'::timestamptz, '2025-09-30 17:00:00'::timestamptz),

(2020, 1020, 1, 40, 62, 55, 45, 50.50, 'partial', false, 'nurturing',
 5, 'Pet shop com interesse mas decisor não disponível',
 1, '2025-09-30 19:15:00'::timestamptz, '2025-09-29 15:00:00'::timestamptz, '2025-09-29 15:00:00'::timestamptz, '2025-09-30 19:15:00'::timestamptz),

(2022, 1022, 1, 52, 65, 48, 55, 55.00, 'partial', false, 'nurturing',
 5, 'Restaurante interessado em melhorar reservas',
 1, '2025-10-05 12:30:00'::timestamptz, '2025-10-02 12:00:00'::timestamptz, '2025-10-02 12:00:00'::timestamptz, '2025-10-05 12:30:00'::timestamptz),

(2023, 1023, 1, 60, 58, 52, 65, 58.75, 'partial', false, 'nurturing',
 7, 'Indústria têxtil avaliando automação de vendas B2B',
 2, '2025-10-08 15:45:00'::timestamptz, '2025-10-05 11:00:00'::timestamptz, '2025-10-05 11:00:00'::timestamptz, '2025-10-08 15:45:00'::timestamptz),

(2025, 1025, 1, 55, 48, 60, 50, 53.25, 'partial', false, 'nurturing',
 4, 'Empresa de segurança com equipe comercial sobrecarregada',
 1, '2025-10-12 14:20:00'::timestamptz, '2025-10-09 17:00:00'::timestamptz, '2025-10-09 17:00:00'::timestamptz, '2025-10-12 14:20:00'::timestamptz),

(2026, 1026, 1, 68, 55, 50, 62, 58.75, 'partial', false, 'warm',
 10, 'Escritório de advocacia sem tempo para qualificar clientes',
 2, '2025-10-15 09:30:00'::timestamptz, '2025-10-12 12:00:00'::timestamptz, '2025-10-12 12:00:00'::timestamptz, '2025-10-15 09:30:00'::timestamptz),

(2027, 1027, 1, 52, 68, 62, 48, 57.50, 'partial', false, 'nurturing',
 1, 'Empresa de energia solar em crescimento',
 1, '2025-10-18 16:00:00'::timestamptz, '2025-10-15 15:30:00'::timestamptz, '2025-10-15 15:30:00'::timestamptz, '2025-10-18 16:00:00'::timestamptz),

(2029, 1029, 1, 45, 60, 55, 42, 50.50, 'partial', false, 'nurturing',
 4, 'Academia de fitness com interesse inicial',
 1, '2025-10-22 13:15:00'::timestamptz, '2025-10-19 11:30:00'::timestamptz, '2025-10-19 11:30:00'::timestamptz, '2025-10-22 13:15:00'::timestamptz),

(2030, 1030, 1, 58, 52, 48, 55, 53.25, 'partial', false, 'nurturing',
 7, 'Gráfica buscando automatizar orçamentos',
 1, '2025-10-24 15:30:00'::timestamptz, '2025-10-21 13:00:00'::timestamptz, '2025-10-21 13:00:00'::timestamptz, '2025-10-24 15:30:00'::timestamptz),

(2032, 1032, 1, 48, 65, 58, 45, 54.00, 'partial', false, 'nurturing',
 5, 'Empresa de eventos querendo melhorar captação de clientes',
 1, '2025-10-28 14:45:00'::timestamptz, '2025-10-25 12:00:00'::timestamptz, '2025-10-25 12:00:00'::timestamptz, '2025-10-28 14:45:00'::timestamptz),

(2033, 1033, 1, 62, 55, 45, 68, 57.50, 'partial', false, 'nurturing',
 1, 'Agropecuária com potencial mas ciclo de venda longo',
 1, '2025-10-29 09:00:00'::timestamptz, '2025-10-26 16:30:00'::timestamptz, '2025-10-26 16:30:00'::timestamptz, '2025-10-29 09:00:00'::timestamptz),

(2036, 1036, 1, 50, 62, 55, 48, 53.75, 'partial', false, 'nurturing',
 3, 'Loja de moda íntima com interesse moderado',
 1, '2025-11-04 10:30:00'::timestamptz, '2025-11-01 10:00:00'::timestamptz, '2025-11-01 10:00:00'::timestamptz, '2025-11-04 10:30:00'::timestamptz),

(2038, 1038, 1, 55, 58, 50, 52, 53.75, 'partial', false, 'nurturing',
 4, 'Escola de idiomas avaliando opções',
 1, '2025-11-10 11:00:00'::timestamptz, '2025-11-07 09:30:00'::timestamptz, '2025-11-07 09:30:00'::timestamptz, '2025-11-10 11:00:00'::timestamptz),

(2039, 1039, 1, 60, 52, 55, 58, 56.25, 'partial', false, 'nurturing',
 7, 'Transportadora interessada em automação',
 1, '2025-11-13 15:45:00'::timestamptz, '2025-11-10 14:00:00'::timestamptz, '2025-11-10 14:00:00'::timestamptz, '2025-11-13 15:45:00'::timestamptz),

(2041, 1041, 1, 58, 55, 62, 50, 56.25, 'partial', false, 'nurturing',
 4, 'Coworking querendo melhorar produtividade do time',
 1, '2025-11-19 13:00:00'::timestamptz, '2025-11-16 12:30:00'::timestamptz, '2025-11-16 12:30:00'::timestamptz, '2025-11-19 13:00:00'::timestamptz),

-- ============================================================================
-- PRE (0-29) - 7 leads (~15%)
-- ============================================================================
(2034, 1034, 1, 25, 30, 20, 28, 25.75, 'pre', false, 'cold',
 8, 'Laboratório apenas buscando informações',
 1, '2025-10-30 16:30:00'::timestamptz, '2025-10-27 11:00:00'::timestamptz, '2025-10-27 11:00:00'::timestamptz, '2025-10-30 16:30:00'::timestamptz),

(2042, 1042, 1, 20, 35, 25, 18, 24.50, 'pre', false, 'cold',
 5, 'Clínica veterinária apenas pesquisando opções',
 1, '2025-11-22 10:15:00'::timestamptz, '2025-11-19 10:00:00'::timestamptz, '2025-11-19 10:00:00'::timestamptz, '2025-11-22 10:15:00'::timestamptz),

(2043, 1043, 1, 28, 22, 18, 30, 24.50, 'pre', false, 'cold',
 6, 'Frigorífico sem urgência, apenas curiosidade',
 1, '2025-11-25 16:30:00'::timestamptz, '2025-11-22 15:00:00'::timestamptz, '2025-11-22 15:00:00'::timestamptz, '2025-11-25 16:30:00'::timestamptz),

(2044, 1044, 1, 22, 28, 25, 20, 23.75, 'pre', false, 'cold',
 5, 'Restaurante apenas conhecendo a solução',
 1, '2025-11-27 12:00:00'::timestamptz, '2025-11-24 11:30:00'::timestamptz, '2025-11-24 11:30:00'::timestamptz, '2025-11-27 12:00:00'::timestamptz),

(2046, 1046, 1, 30, 25, 20, 22, 24.25, 'pre', false, 'cold',
 5, 'Agência de viagens em fase inicial de pesquisa',
 1, '2025-12-02 10:00:00'::timestamptz, '2025-12-01 10:30:00'::timestamptz, '2025-12-01 10:30:00'::timestamptz, '2025-12-02 10:00:00'::timestamptz),

(2048, 1048, 1, 25, 32, 28, 22, 26.75, 'pre', false, 'cold',
 3, 'E-commerce pequeno, ainda não tem volume',
 1, '2025-12-03 09:15:00'::timestamptz, '2025-12-02 09:00:00'::timestamptz, '2025-12-02 09:00:00'::timestamptz, '2025-12-03 09:15:00'::timestamptz),

(2049, 1049, 1, 18, 25, 22, 28, 23.25, 'pre', false, 'cold',
 8, 'Indústria de plásticos apenas buscando informações',
 1, '2025-12-03 11:45:00'::timestamptz, '2025-12-02 17:30:00'::timestamptz, '2025-12-02 17:30:00'::timestamptz, '2025-12-03 11:45:00'::timestamptz),

(2050, 1050, 1, 28, 30, 25, 20, 25.75, 'pre', false, 'cold',
 5, 'Loja de decoração em fase exploratória',
 1, '2025-12-03 14:00:00'::timestamptz, '2025-12-03 11:00:00'::timestamptz, '2025-12-03 11:00:00'::timestamptz, '2025-12-03 14:00:00'::timestamptz);

-- Atualizar sequence
SELECT setval('corev4_lead_state_id_seq', GREATEST((SELECT MAX(id) FROM corev4_lead_state), 2050), true);

-- Verificar distribuição
SELECT
    qualification_stage,
    COUNT(*) AS total,
    ROUND(AVG(total_score), 1) AS anum_medio
FROM corev4_lead_state
WHERE contact_id >= 1001 AND contact_id <= 1053
GROUP BY qualification_stage
ORDER BY
    CASE qualification_stage
        WHEN 'full' THEN 1
        WHEN 'partial' THEN 2
        WHEN 'pre' THEN 3
    END;
