-- ============================================================================
-- QUICK SETUP: DRA. ILANA FEINGOLD (CORRIGIDO)
-- ============================================================================
-- Versão corrigida baseada no schema real do Supabase
-- Execute tudo de uma vez no SQL Editor
-- ============================================================================

-- ============================================================================
-- PASSO 1: CRIAR EMPRESA
-- ============================================================================

INSERT INTO corev4_companies (
    name,
    slug,
    bot_name,
    bot_personality,
    system_prompt,
    llm_model,
    llm_temperature,
    llm_max_tokens,
    greeting_message,
    plan_tier,
    is_active,
    features,
    enable_followup_campaigns,
    auto_create_campaigns
) VALUES (
    'Dra. Ilana Feingold - Psicóloga Clínica',
    'ilana-feingold',
    'Lis',
    'Assistente virtual acolhedora e empática para consultório de psicologia.',
    'Você é LIS, Assistente Virtual da Dra. Ilana Feingold, psicóloga clínica (CRP 11/04021) com 20 anos de experiência. Especialização: TCC, Terapia do Esquema, PNL. Atende: jovens, adultos, casais, expatriados, executivos. NÃO atende: crianças, casos psicóticos. NUNCA faça diagnósticos. Sessão: R$380 (~50min). Plano mensal: R$1.400 (4 sessões). Horários: Seg/Ter/Qui 14h-19h. Agendamento: https://cal.com/francisco-pasteur-coreadapt/agenda-dra.ilana-feingold ou Secretária Nara: (85) 98869-2353.',
    'gpt-4o',
    0.7,
    800,
    'Oi! Que bom que você chegou aqui 😊

Sou a Lis, assistente da Dra. Ilana Feingold.

Ela é psicóloga há 20 anos, atende online e presencial.

Posso te ajudar com informações, tirar dúvidas, ou te ajudar a agendar. Como posso te ajudar?',
    'pro',
    true,
    '{
        "sector": "psychology",
        "framework": "MAP",
        "has_followup": true,
        "followup_steps": 4,
        "cal_link": "https://cal.com/francisco-pasteur-coreadapt/agenda-dra.ilana-feingold",
        "secretary_phone": "5585988692353",
        "session_price": 380,
        "monthly_plan_price": 1400
    }'::jsonb,
    true,
    true
);


-- ============================================================================
-- PASSO 2: CRIAR CONFIG DE FOLLOWUP
-- ============================================================================
-- CORRIGIDO: Adicionado config_name que é NOT NULL

INSERT INTO corev4_followup_configs (
    company_id,
    config_name,
    total_steps,
    qualification_threshold,
    disqualification_threshold,
    max_no_response_days,
    is_active
)
SELECT
    id,
    'Campanha Ilana - Saúde Mental',  -- config_name (obrigatório)
    4,
    60,
    15,
    30,
    true
FROM corev4_companies
WHERE slug = 'ilana-feingold';


-- ============================================================================
-- PASSO 3: CRIAR STEPS DE FOLLOWUP
-- ============================================================================
-- Timing adaptado: 6h → 48h → 120h (5d) → 240h (10d)

INSERT INTO corev4_followup_steps (config_id, step_number, wait_hours, wait_minutes)
SELECT
    fc.id,
    step_data.step_number,
    step_data.wait_hours,
    0
FROM corev4_followup_configs fc
JOIN corev4_companies c ON c.id = fc.company_id
CROSS JOIN (
    VALUES
        (1, 6),    -- Step 1: 6 horas - Check-in gentil
        (2, 48),   -- Step 2: 2 dias - Agregar valor
        (3, 120),  -- Step 3: 5 dias - Porta aberta
        (4, 240)   -- Step 4: 10 dias - Despedida gentil
) AS step_data(step_number, wait_hours)
WHERE c.slug = 'ilana-feingold';


-- ============================================================================
-- PASSO 4: CRIAR CATEGORIAS DE MOTIVAÇÃO
-- ============================================================================
-- CORRIGIDO: Adicionado keywords (obrigatório)

INSERT INTO corev4_pain_categories (
    company_id,
    category_key,
    category_label_pt,
    category_label_en,
    description,
    keywords,
    display_order,
    is_active
)
SELECT
    c.id,
    cat.category_key,
    cat.category_label_pt,
    cat.category_label_en,
    cat.description,
    cat.keywords,
    cat.display_order,
    true
FROM corev4_companies c
CROSS JOIN (
    VALUES
        ('anxiety', 'Ansiedade', 'Anxiety',
         'Preocupação excessiva, nervosismo, sintomas físicos',
         ARRAY['ansiedade', 'nervoso', 'preocupação', 'pânico', 'medo']::text[], 1),
        ('burnout', 'Burnout / Esgotamento', 'Burnout',
         'Esgotamento profissional, exaustão',
         ARRAY['burnout', 'esgotamento', 'exausto', 'cansado', 'trabalho']::text[], 2),
        ('depression', 'Depressão / Tristeza', 'Depression',
         'Tristeza persistente, perda de interesse',
         ARRAY['depressão', 'triste', 'desesperança', 'vazio', 'sem energia']::text[], 3),
        ('relationships', 'Dificuldades de Relacionamento', 'Relationships',
         'Problemas em relacionamentos',
         ARRAY['relacionamento', 'casal', 'namoro', 'casamento', 'família']::text[], 4),
        ('self_knowledge', 'Autoconhecimento', 'Self-Knowledge',
         'Desenvolvimento pessoal',
         ARRAY['autoconhecimento', 'crescimento', 'desenvolvimento', 'entender']::text[], 5),
        ('abusive_relationships', 'Relações Abusivas', 'Abusive Relationships',
         'Narcisismo, manipulação',
         ARRAY['abuso', 'narcisista', 'manipulação', 'tóxico', 'controle']::text[], 6),
        ('professional_performance', 'Performance Profissional', 'Professional Performance',
         'Carreira, liderança',
         ARRAY['carreira', 'trabalho', 'liderança', 'performance', 'executivo']::text[], 7),
        ('self_esteem', 'Autoestima', 'Self-Esteem',
         'Insegurança, autocrítica',
         ARRAY['autoestima', 'insegurança', 'confiança', 'impostor', 'autocrítica']::text[], 8),
        ('life_transition', 'Transição de Vida', 'Life Transition',
         'Mudanças, expatriação',
         ARRAY['mudança', 'transição', 'expatriado', 'adaptação', 'novo']::text[], 9),
        ('grief', 'Luto / Perdas', 'Grief',
         'Perdas significativas',
         ARRAY['luto', 'perda', 'morte', 'término', 'separação']::text[], 10)
) AS cat(category_key, category_label_pt, category_label_en, description, keywords, display_order)
WHERE c.slug = 'ilana-feingold'
ON CONFLICT (company_id, category_key) DO NOTHING;


-- ============================================================================
-- PASSO 5: ATUALIZAR DEFAULT_FOLLOWUP_CONFIG_ID NA EMPRESA
-- ============================================================================

UPDATE corev4_companies
SET default_followup_config_id = (
    SELECT fc.id
    FROM corev4_followup_configs fc
    WHERE fc.company_id = corev4_companies.id
    LIMIT 1
)
WHERE slug = 'ilana-feingold';


-- ============================================================================
-- VERIFICAÇÃO FINAL
-- ============================================================================

SELECT
    '✅ Empresa criada' as status,
    c.id as company_id,
    c.name,
    c.bot_name,
    c.default_followup_config_id
FROM corev4_companies c
WHERE c.slug = 'ilana-feingold';

SELECT
    '✅ Followup configurado' as status,
    fc.id as config_id,
    fc.config_name,
    fc.total_steps,
    string_agg(fs.wait_hours || 'h', ' → ' ORDER BY fs.step_number) as timing
FROM corev4_followup_configs fc
JOIN corev4_companies c ON c.id = fc.company_id
LEFT JOIN corev4_followup_steps fs ON fs.config_id = fc.id
WHERE c.slug = 'ilana-feingold'
GROUP BY fc.id, fc.config_name, fc.total_steps;

SELECT
    '✅ Categorias criadas' as status,
    COUNT(*) as total_categories
FROM corev4_pain_categories pc
JOIN corev4_companies c ON c.id = pc.company_id
WHERE c.slug = 'ilana-feingold';
