-- ============================================
-- MOTIVATION CATEGORIES - DRA. ILANA FEINGOLD
-- Tenant-specific seed for psychology practice
-- ============================================
-- Version: 1.0
-- Created: December 8, 2025
-- Company: Dra. Ilana Feingold - Psicóloga Clínica
-- ============================================

-- Note: This uses a tenant-specific company_id
-- Replace {COMPANY_ID} with actual company_id when deploying

-- Clear existing categories for this tenant (if re-seeding)
-- DELETE FROM corev4_pain_categories WHERE company_id = {COMPANY_ID};

-- ============================================
-- MOTIVATION CATEGORIES (Equivalent to Pain Categories)
-- In psychology context, "pain" becomes "motivation"
-- ============================================

INSERT INTO corev4_pain_categories (
    company_id,
    category_key,
    category_label_pt,
    category_label_en,
    description_pt,
    description_en
) VALUES

-- 1. Ansiedade
(
    {COMPANY_ID},
    'anxiety',
    'Ansiedade',
    'Anxiety',
    'Preocupação excessiva, nervosismo, dificuldade de relaxar, sintomas físicos de ansiedade',
    'Excessive worry, nervousness, difficulty relaxing, physical anxiety symptoms'
),

-- 2. Burnout / Esgotamento Profissional
(
    {COMPANY_ID},
    'burnout',
    'Burnout / Esgotamento',
    'Burnout / Exhaustion',
    'Esgotamento relacionado ao trabalho, exaustão física e emocional, perda de motivação profissional',
    'Work-related exhaustion, physical and emotional depletion, loss of professional motivation'
),

-- 3. Depressão / Tristeza
(
    {COMPANY_ID},
    'depression',
    'Depressão / Tristeza',
    'Depression / Sadness',
    'Tristeza persistente, perda de interesse, desesperança, alterações de sono e apetite',
    'Persistent sadness, loss of interest, hopelessness, sleep and appetite changes'
),

-- 4. Relacionamentos
(
    {COMPANY_ID},
    'relationships',
    'Dificuldades de Relacionamento',
    'Relationship Difficulties',
    'Problemas em relacionamentos amorosos, familiares ou sociais, dificuldade de conexão',
    'Issues in romantic, family or social relationships, difficulty connecting'
),

-- 5. Autoconhecimento
(
    {COMPANY_ID},
    'self_knowledge',
    'Autoconhecimento',
    'Self-Knowledge',
    'Desejo de se conhecer melhor, entender padrões, desenvolvimento pessoal',
    'Desire for self-understanding, pattern recognition, personal development'
),

-- 6. Relações Abusivas / Narcisismo
(
    {COMPANY_ID},
    'abusive_relationships',
    'Relações Abusivas / Narcisismo',
    'Abusive Relationships / Narcissism',
    'Relacionamentos com pessoas narcisistas, manipuladoras, padrões de abuso emocional',
    'Relationships with narcissistic or manipulative people, emotional abuse patterns'
),

-- 7. Performance Profissional
(
    {COMPANY_ID},
    'professional_performance',
    'Performance Profissional',
    'Professional Performance',
    'Questões de carreira, liderança, tomada de decisão, performance executiva',
    'Career issues, leadership, decision-making, executive performance'
),

-- 8. Autoestima
(
    {COMPANY_ID},
    'self_esteem',
    'Autoestima',
    'Self-Esteem',
    'Baixa autoestima, insegurança, autocrítica excessiva, síndrome do impostor',
    'Low self-esteem, insecurity, excessive self-criticism, impostor syndrome'
),

-- 9. Transição de Vida / Expatriação
(
    {COMPANY_ID},
    'life_transition',
    'Transição de Vida / Expatriação',
    'Life Transition / Expatriation',
    'Mudanças de país, carreira, relacionamento, adaptação a novas realidades',
    'Country, career, relationship changes, adaptation to new realities'
),

-- 10. Luto / Perdas
(
    {COMPANY_ID},
    'grief',
    'Luto / Perdas',
    'Grief / Loss',
    'Perda de pessoas queridas, términos, perdas significativas de vida',
    'Loss of loved ones, breakups, significant life losses'
)

ON CONFLICT (company_id, category_key)
DO UPDATE SET
    category_label_pt = EXCLUDED.category_label_pt,
    category_label_en = EXCLUDED.category_label_en,
    description_pt = EXCLUDED.description_pt,
    description_en = EXCLUDED.description_en;

-- ============================================
-- VERIFICATION QUERY
-- ============================================
-- SELECT * FROM corev4_pain_categories WHERE company_id = {COMPANY_ID};
