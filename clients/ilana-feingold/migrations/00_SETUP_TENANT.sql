-- ============================================================================
-- SETUP TENANT: DRA. ILANA FEINGOLD
-- ============================================================================
-- Execute este arquivo no Supabase SQL Editor para criar o tenant completo
--
-- IMPORTANTE: Execute na ordem correta (os scripts dependem uns dos outros)
--
-- Conteúdo:
--   1. Criar empresa (corev4_companies)
--   2. Criar configuração de followup (corev4_followup_configs)
--   3. Criar steps de followup (corev4_followup_steps)
--   4. Criar categorias de motivação (corev4_pain_categories)
--
-- Autor: CoreAdapt
-- Data: December 8, 2025
-- Cliente: Dra. Ilana Feingold - Psicóloga Clínica
-- ============================================================================

-- ============================================================================
-- PARTE 1: CRIAR EMPRESA/TENANT
-- ============================================================================

-- O system_prompt completo está no arquivo LIS_SYSTEM_MESSAGE_v1.0.md
-- Aqui usamos uma versão resumida para o campo (o prompt completo vai no n8n)

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
    created_at,
    updated_at
) VALUES (
    'Dra. Ilana Feingold - Psicóloga Clínica',
    'ilana-feingold',
    'Lis',
    'Assistente virtual acolhedora e empática. Tom informal mas respeitoso. Foco em acolhimento, não em vendas. Não faz diagnósticos. Usa framework MAP (Motivação, Alinhamento, Prontidão) em vez de ANUM.',
    'Você é LIS, Assistente Virtual da Dra. Ilana Feingold, psicóloga clínica (CRP 11/04021). Sua missão é acolher pessoas que buscam atendimento psicológico, responder dúvidas com empatia, e encaminhar para agendamento. NUNCA faça diagnósticos ou confirme patologias. Sessão: R$380 (~50min). Plano mensal: R$1.400 (4 sessões). Horários: Seg/Ter/Qui 14h-19h. Link: https://cal.com/francisco-pasteur-coreadapt/agenda-dra.ilana-feingold. Secretária Nara: (85) 98869-2353.',
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
        "monthly_plan_price": 1400,
        "working_hours": {
            "monday": "14:00-19:00",
            "tuesday": "14:00-19:00",
            "thursday": "14:00-19:00",
            "wednesday": "emergencies_only"
        }
    }'::jsonb,
    NOW(),
    NOW()
)
RETURNING id;

-- ============================================================================
-- GUARDE O ID RETORNADO! Você vai usar nas próximas queries
-- Substitua {COMPANY_ID} pelo valor retornado (ex: 2)
-- ============================================================================


-- ============================================================================
-- PARTE 2: CRIAR CONFIGURAÇÃO DE FOLLOWUP
-- ============================================================================
-- Timing adaptado para contexto de saúde mental (mais suave)
-- 4 steps em vez de 6 (original CoreAdapt)
-- Delays mais longos, tom mais gentil

-- IMPORTANTE: Substitua {COMPANY_ID} pelo ID retornado na PARTE 1

INSERT INTO corev4_followup_configs (
    company_id,
    total_steps,
    qualification_threshold,
    disqualification_threshold,
    is_active,
    created_at,
    updated_at
) VALUES (
    {COMPANY_ID},  -- ⚠️ SUBSTITUA PELO ID DA EMPRESA
    4,             -- 4 steps (vs 6 do original)
    70,            -- Threshold para considerar "pronto"
    30,            -- Threshold para desqualificar
    true,
    NOW(),
    NOW()
)
RETURNING id;

-- ============================================================================
-- GUARDE O CONFIG_ID RETORNADO! Você vai usar na próxima query
-- Substitua {CONFIG_ID} pelo valor retornado
-- ============================================================================


-- ============================================================================
-- PARTE 3: CRIAR STEPS DE FOLLOWUP
-- ============================================================================
-- Timing específico para contexto de saúde mental:
-- Step 1: 6 horas (vs 1h do original) - Check-in gentil
-- Step 2: 48 horas (vs 24h) - Agregar valor
-- Step 3: 120 horas / 5 dias (vs 72h) - Porta aberta
-- Step 4: 240 horas / 10 dias (vs 144h) - Despedida gentil

-- IMPORTANTE: Substitua {CONFIG_ID} pelo ID retornado na PARTE 2

INSERT INTO corev4_followup_steps (
    config_id,
    step_number,
    wait_hours,
    wait_minutes,
    created_at,
    updated_at
) VALUES
    ({CONFIG_ID}, 1, 6, 0, NOW(), NOW()),    -- Step 1: 6 horas - Check-in gentil
    ({CONFIG_ID}, 2, 48, 0, NOW(), NOW()),   -- Step 2: 2 dias - Agregar valor
    ({CONFIG_ID}, 3, 120, 0, NOW(), NOW()),  -- Step 3: 5 dias - Porta aberta
    ({CONFIG_ID}, 4, 240, 0, NOW(), NOW());  -- Step 4: 10 dias - Despedida gentil


-- ============================================================================
-- PARTE 4: CRIAR CATEGORIAS DE MOTIVAÇÃO
-- ============================================================================
-- Equivalente às "pain_categories" mas adaptadas para psicologia
-- No contexto de saúde mental, "dor" vira "motivação para buscar ajuda"

-- IMPORTANTE: Substitua {COMPANY_ID} pelo ID da empresa

INSERT INTO corev4_pain_categories (
    company_id,
    category_key,
    category_label_pt,
    category_label_en,
    description,
    display_order,
    is_active,
    created_at
) VALUES
    -- 1. Ansiedade
    ({COMPANY_ID}, 'anxiety', 'Ansiedade', 'Anxiety',
     'Preocupação excessiva, nervosismo, dificuldade de relaxar, sintomas físicos de ansiedade',
     1, true, NOW()),

    -- 2. Burnout / Esgotamento Profissional
    ({COMPANY_ID}, 'burnout', 'Burnout / Esgotamento', 'Burnout / Exhaustion',
     'Esgotamento relacionado ao trabalho, exaustão física e emocional, perda de motivação profissional',
     2, true, NOW()),

    -- 3. Depressão / Tristeza
    ({COMPANY_ID}, 'depression', 'Depressão / Tristeza', 'Depression / Sadness',
     'Tristeza persistente, perda de interesse, desesperança, alterações de sono e apetite',
     3, true, NOW()),

    -- 4. Relacionamentos
    ({COMPANY_ID}, 'relationships', 'Dificuldades de Relacionamento', 'Relationship Difficulties',
     'Problemas em relacionamentos amorosos, familiares ou sociais, dificuldade de conexão',
     4, true, NOW()),

    -- 5. Autoconhecimento
    ({COMPANY_ID}, 'self_knowledge', 'Autoconhecimento', 'Self-Knowledge',
     'Desejo de se conhecer melhor, entender padrões, desenvolvimento pessoal',
     5, true, NOW()),

    -- 6. Relações Abusivas / Narcisismo
    ({COMPANY_ID}, 'abusive_relationships', 'Relações Abusivas / Narcisismo', 'Abusive Relationships / Narcissism',
     'Relacionamentos com pessoas narcisistas, manipuladoras, padrões de abuso emocional',
     6, true, NOW()),

    -- 7. Performance Profissional
    ({COMPANY_ID}, 'professional_performance', 'Performance Profissional', 'Professional Performance',
     'Questões de carreira, liderança, tomada de decisão, performance executiva',
     7, true, NOW()),

    -- 8. Autoestima
    ({COMPANY_ID}, 'self_esteem', 'Autoestima', 'Self-Esteem',
     'Baixa autoestima, insegurança, autocrítica excessiva, síndrome do impostor',
     8, true, NOW()),

    -- 9. Transição de Vida / Expatriação
    ({COMPANY_ID}, 'life_transition', 'Transição de Vida / Expatriação', 'Life Transition / Expatriation',
     'Mudanças de país, carreira, relacionamento, adaptação a novas realidades',
     9, true, NOW()),

    -- 10. Luto / Perdas
    ({COMPANY_ID}, 'grief', 'Luto / Perdas', 'Grief / Loss',
     'Perda de pessoas queridas, términos, perdas significativas de vida',
     10, true, NOW())

ON CONFLICT (company_id, category_key) DO UPDATE SET
    category_label_pt = EXCLUDED.category_label_pt,
    category_label_en = EXCLUDED.category_label_en,
    description = EXCLUDED.description,
    display_order = EXCLUDED.display_order;


-- ============================================================================
-- VERIFICAÇÃO FINAL
-- ============================================================================
-- Execute estas queries para verificar se tudo foi criado corretamente

-- Verificar empresa criada
SELECT id, name, slug, bot_name, is_active
FROM corev4_companies
WHERE slug = 'ilana-feingold';

-- Verificar config de followup
SELECT fc.id, fc.company_id, fc.total_steps, c.name as company_name
FROM corev4_followup_configs fc
JOIN corev4_companies c ON c.id = fc.company_id
WHERE c.slug = 'ilana-feingold';

-- Verificar steps de followup
SELECT fs.step_number, fs.wait_hours, fs.wait_minutes,
       CONCAT(fs.wait_hours, 'h ', fs.wait_minutes, 'min') as delay_formatted
FROM corev4_followup_steps fs
JOIN corev4_followup_configs fc ON fc.id = fs.config_id
JOIN corev4_companies c ON c.id = fc.company_id
WHERE c.slug = 'ilana-feingold'
ORDER BY fs.step_number;

-- Verificar categorias de motivação
SELECT category_key, category_label_pt, display_order
FROM corev4_pain_categories
WHERE company_id = (SELECT id FROM corev4_companies WHERE slug = 'ilana-feingold')
ORDER BY display_order;


-- ============================================================================
-- RESUMO DO SETUP
-- ============================================================================
/*
✅ Empresa: Dra. Ilana Feingold - Psicóloga Clínica
✅ Bot: Lis (assistente virtual)
✅ Framework: MAP (Motivação, Alinhamento, Prontidão)
✅ Followup: 4 steps com timing adaptado para saúde mental
   - Step 1: 6h (check-in gentil)
   - Step 2: 48h (agregar valor)
   - Step 3: 120h/5d (porta aberta)
   - Step 4: 240h/10d (despedida gentil)
✅ Categorias: 10 motivações para busca de terapia

PRÓXIMOS PASSOS:
1. Copiar o company_id gerado
2. Configurar Evolution API (webhook + instance)
3. Configurar n8n com os prompts completos:
   - LIS_SYSTEM_MESSAGE_v1.0.md
   - LIS_SENTINEL_SYSTEM_MESSAGE_v1.0.md
4. Testar fluxo completo
*/
