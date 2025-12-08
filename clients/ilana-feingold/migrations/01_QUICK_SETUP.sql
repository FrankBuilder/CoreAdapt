-- ============================================================================
-- QUICK SETUP: DRA. ILANA FEINGOLD
-- ============================================================================
-- Versão simplificada - Execute tudo de uma vez
-- Assume que o próximo company_id disponível será usado automaticamente
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
    features
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
    }'::jsonb
);


-- ============================================================================
-- PASSO 2: CRIAR CONFIG DE FOLLOWUP
-- ============================================================================

INSERT INTO corev4_followup_configs (
    company_id,
    total_steps,
    qualification_threshold,
    disqualification_threshold,
    is_active
)
SELECT
    id,      -- company_id da empresa recém criada
    4,       -- 4 steps (adaptado para saúde mental)
    70,      -- threshold de qualificação
    30,      -- threshold de desqualificação
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

INSERT INTO corev4_pain_categories (company_id, category_key, category_label_pt, category_label_en, description, display_order, is_active)
SELECT
    c.id,
    cat.category_key,
    cat.category_label_pt,
    cat.category_label_en,
    cat.description,
    cat.display_order,
    true
FROM corev4_companies c
CROSS JOIN (
    VALUES
        ('anxiety', 'Ansiedade', 'Anxiety', 'Preocupação excessiva, nervosismo, sintomas físicos', 1),
        ('burnout', 'Burnout / Esgotamento', 'Burnout', 'Esgotamento profissional, exaustão', 2),
        ('depression', 'Depressão / Tristeza', 'Depression', 'Tristeza persistente, perda de interesse', 3),
        ('relationships', 'Dificuldades de Relacionamento', 'Relationships', 'Problemas em relacionamentos', 4),
        ('self_knowledge', 'Autoconhecimento', 'Self-Knowledge', 'Desenvolvimento pessoal', 5),
        ('abusive_relationships', 'Relações Abusivas', 'Abusive Relationships', 'Narcisismo, manipulação', 6),
        ('professional_performance', 'Performance Profissional', 'Professional Performance', 'Carreira, liderança', 7),
        ('self_esteem', 'Autoestima', 'Self-Esteem', 'Insegurança, autocrítica', 8),
        ('life_transition', 'Transição de Vida', 'Life Transition', 'Mudanças, expatriação', 9),
        ('grief', 'Luto / Perdas', 'Grief', 'Perdas significativas', 10)
) AS cat(category_key, category_label_pt, category_label_en, description, display_order)
WHERE c.slug = 'ilana-feingold'
ON CONFLICT (company_id, category_key) DO NOTHING;


-- ============================================================================
-- VERIFICAÇÃO
-- ============================================================================

SELECT
    '✅ Empresa criada' as status,
    c.id as company_id,
    c.name,
    c.bot_name
FROM corev4_companies c
WHERE c.slug = 'ilana-feingold';

SELECT
    '✅ Followup configurado' as status,
    fc.id as config_id,
    fc.total_steps,
    string_agg(fs.wait_hours || 'h', ' → ' ORDER BY fs.step_number) as timing
FROM corev4_followup_configs fc
JOIN corev4_companies c ON c.id = fc.company_id
LEFT JOIN corev4_followup_steps fs ON fs.config_id = fc.id
WHERE c.slug = 'ilana-feingold'
GROUP BY fc.id, fc.total_steps;

SELECT
    '✅ Categorias criadas' as status,
    COUNT(*) as total_categories
FROM corev4_pain_categories pc
JOIN corev4_companies c ON c.id = pc.company_id
WHERE c.slug = 'ilana-feingold';
