-- ============================================================================
-- SEED: FOLLOW-UP CAMPAIGNS & EXECUTIONS
-- CoreAdapt v4 | Tenant: CoreConnect (company_id = 1)
-- ============================================================================
-- Campanhas de follow-up em diversos estados:
-- - Ativas (em andamento)
-- - Completadas (todos os steps enviados)
-- - Paradas (por reunião, qualificação, opt-out, etc)
-- ============================================================================

-- Limpar campanhas e execuções dos contatos demo
DELETE FROM corev4_followup_executions
WHERE contact_id IN (SELECT id FROM corev4_contacts WHERE tags @> ARRAY['demo']::text[]);

DELETE FROM corev4_followup_campaigns
WHERE contact_id IN (SELECT id FROM corev4_contacts WHERE tags @> ARRAY['demo']::text[]);

-- ============================================================================
-- CAMPANHAS PARADAS POR REUNIÃO AGENDADA (sucesso!)
-- ============================================================================
INSERT INTO corev4_followup_campaigns (
    id, contact_id, company_id, config_id, status,
    steps_completed, total_steps, last_step_sent_at,
    should_continue, stopped_reason, created_at, updated_at
) VALUES
(3001, 1001, 1, 1, 'stopped', 1, 5, '2025-08-04 09:00:00'::timestamptz, false, 'meeting_scheduled', '2025-08-03 14:00:00'::timestamptz, '2025-08-04 09:00:00'::timestamptz),
(3002, 1012, 1, 1, 'stopped', 1, 5, '2025-09-13 10:00:00'::timestamptz, false, 'meeting_scheduled', '2025-09-12 17:00:00'::timestamptz, '2025-09-13 10:00:00'::timestamptz),
(3004, 1004, 1, 1, 'stopped', 2, 5, '2025-08-22 09:00:00'::timestamptz, false, 'meeting_scheduled', '2025-08-20 16:00:00'::timestamptz, '2025-08-22 09:00:00'::timestamptz),
(3009, 1009, 1, 1, 'stopped', 1, 5, '2025-09-03 14:00:00'::timestamptz, false, 'meeting_scheduled', '2025-09-02 15:00:00'::timestamptz, '2025-09-03 14:00:00'::timestamptz),
(3014, 1014, 1, 1, 'stopped', 2, 5, '2025-09-21 10:00:00'::timestamptz, false, 'meeting_scheduled', '2025-09-19 14:00:00'::timestamptz, '2025-09-21 10:00:00'::timestamptz),
(3019, 1019, 1, 1, 'stopped', 1, 5, '2025-09-30 09:00:00'::timestamptz, false, 'meeting_scheduled', '2025-09-29 15:00:00'::timestamptz, '2025-09-30 09:00:00'::timestamptz),
(3028, 1028, 1, 1, 'stopped', 1, 5, '2025-10-18 09:00:00'::timestamptz, false, 'meeting_scheduled', '2025-10-17 12:00:00'::timestamptz, '2025-10-18 09:00:00'::timestamptz),
(3021, 1021, 1, 1, 'stopped', 2, 5, '2025-10-04 10:00:00'::timestamptz, false, 'meeting_scheduled', '2025-10-01 11:00:00'::timestamptz, '2025-10-04 10:00:00'::timestamptz),
(3047, 1047, 1, 1, 'stopped', 1, 5, '2025-12-02 09:00:00'::timestamptz, false, 'meeting_scheduled', '2025-12-01 16:00:00'::timestamptz, '2025-12-02 09:00:00'::timestamptz),

-- ============================================================================
-- CAMPANHAS PARADAS POR QUALIFICAÇÃO (lead muito bom, não precisa mais)
-- ============================================================================
(3002b, 1002, 1, 1, 'stopped', 3, 5, '2025-08-14 14:00:00'::timestamptz, false, 'qualified', '2025-08-10 12:00:00'::timestamptz, '2025-08-14 14:00:00'::timestamptz),
(3015, 1015, 1, 1, 'stopped', 2, 5, '2025-09-24 15:00:00'::timestamptz, false, 'qualified', '2025-09-22 12:00:00'::timestamptz, '2025-09-24 15:00:00'::timestamptz),

-- ============================================================================
-- CAMPANHAS PARADAS POR OPT-OUT
-- ============================================================================
(3051, 1051, 1, 1, 'stopped', 1, 5, '2025-08-19 10:00:00'::timestamptz, false, 'opt_out', '2025-08-18 12:00:00'::timestamptz, '2025-08-19 10:00:00'::timestamptz),
(3052, 1052, 1, 1, 'stopped', 2, 5, '2025-09-14 11:00:00'::timestamptz, false, 'opt_out', '2025-09-12 14:00:00'::timestamptz, '2025-09-14 11:00:00'::timestamptz),
(3053, 1053, 1, 1, 'stopped', 1, 5, '2025-10-21 15:00:00'::timestamptz, false, 'opt_out', '2025-10-20 12:00:00'::timestamptz, '2025-10-21 15:00:00'::timestamptz),

-- ============================================================================
-- CAMPANHAS COMPLETADAS (todos os 5 steps enviados, sem resposta)
-- ============================================================================
(3003, 1003, 1, 1, 'completed', 5, 5, '2025-08-25 09:00:00'::timestamptz, false, NULL, '2025-08-15 12:00:00'::timestamptz, '2025-08-25 09:00:00'::timestamptz),
(3006, 1006, 1, 1, 'completed', 5, 5, '2025-09-05 14:00:00'::timestamptz, false, NULL, '2025-08-26 18:00:00'::timestamptz, '2025-09-05 14:00:00'::timestamptz),
(3010, 1010, 1, 1, 'completed', 5, 5, '2025-09-18 10:00:00'::timestamptz, false, NULL, '2025-09-05 14:00:00'::timestamptz, '2025-09-18 10:00:00'::timestamptz),
(3017, 1017, 1, 1, 'completed', 5, 5, '2025-10-10 09:00:00'::timestamptz, false, NULL, '2025-09-27 18:00:00'::timestamptz, '2025-10-10 09:00:00'::timestamptz),
(3022, 1022, 1, 1, 'completed', 5, 5, '2025-10-15 11:00:00'::timestamptz, false, NULL, '2025-10-02 15:00:00'::timestamptz, '2025-10-15 11:00:00'::timestamptz),
(3025, 1025, 1, 1, 'completed', 5, 5, '2025-10-22 14:00:00'::timestamptz, false, NULL, '2025-10-09 18:00:00'::timestamptz, '2025-10-22 14:00:00'::timestamptz),
(3030, 1030, 1, 1, 'completed', 5, 5, '2025-11-03 10:00:00'::timestamptz, false, NULL, '2025-10-21 15:00:00'::timestamptz, '2025-11-03 10:00:00'::timestamptz),
(3034, 1034, 1, 1, 'completed', 5, 5, '2025-11-09 09:00:00'::timestamptz, false, NULL, '2025-10-27 14:00:00'::timestamptz, '2025-11-09 09:00:00'::timestamptz),

-- ============================================================================
-- CAMPANHAS ATIVAS (em andamento)
-- ============================================================================
(3005, 1005, 1, 1, 'active', 3, 5, '2025-12-01 10:00:00'::timestamptz, true, NULL, '2025-08-23 14:00:00'::timestamptz, '2025-12-01 10:00:00'::timestamptz),
(3007, 1007, 1, 1, 'active', 2, 5, '2025-12-02 09:00:00'::timestamptz, true, NULL, '2025-08-28 14:00:00'::timestamptz, '2025-12-02 09:00:00'::timestamptz),
(3011, 1011, 1, 1, 'active', 4, 5, '2025-12-02 14:00:00'::timestamptz, true, NULL, '2025-09-10 12:00:00'::timestamptz, '2025-12-02 14:00:00'::timestamptz),
(3013, 1013, 1, 1, 'active', 3, 5, '2025-12-01 11:00:00'::timestamptz, true, NULL, '2025-09-15 16:00:00'::timestamptz, '2025-12-01 11:00:00'::timestamptz),
(3016, 1016, 1, 1, 'active', 2, 5, '2025-12-03 09:00:00'::timestamptz, true, NULL, '2025-09-25 14:00:00'::timestamptz, '2025-12-03 09:00:00'::timestamptz),
(3018, 1018, 1, 1, 'active', 3, 5, '2025-12-02 15:00:00'::timestamptz, true, NULL, '2025-09-28 16:00:00'::timestamptz, '2025-12-02 15:00:00'::timestamptz),
(3020, 1020, 1, 1, 'active', 2, 5, '2025-12-01 16:00:00'::timestamptz, true, NULL, '2025-09-29 17:00:00'::timestamptz, '2025-12-01 16:00:00'::timestamptz),
(3023, 1023, 1, 1, 'active', 3, 5, '2025-12-03 10:00:00'::timestamptz, true, NULL, '2025-10-05 14:00:00'::timestamptz, '2025-12-03 10:00:00'::timestamptz),
(3026, 1026, 1, 1, 'active', 2, 5, '2025-12-02 11:00:00'::timestamptz, true, NULL, '2025-10-12 14:00:00'::timestamptz, '2025-12-02 11:00:00'::timestamptz),
(3027, 1027, 1, 1, 'active', 3, 5, '2025-12-01 14:00:00'::timestamptz, true, NULL, '2025-10-15 17:00:00'::timestamptz, '2025-12-01 14:00:00'::timestamptz),
(3029, 1029, 1, 1, 'active', 2, 5, '2025-12-03 11:00:00'::timestamptz, true, NULL, '2025-10-19 14:00:00'::timestamptz, '2025-12-03 11:00:00'::timestamptz),
(3036, 1036, 1, 1, 'active', 4, 5, '2025-12-02 10:00:00'::timestamptz, true, NULL, '2025-11-01 12:00:00'::timestamptz, '2025-12-02 10:00:00'::timestamptz),
(3038, 1038, 1, 1, 'active', 3, 5, '2025-12-01 09:00:00'::timestamptz, true, NULL, '2025-11-07 12:00:00'::timestamptz, '2025-12-01 09:00:00'::timestamptz),
(3039, 1039, 1, 1, 'active', 2, 5, '2025-12-02 16:00:00'::timestamptz, true, NULL, '2025-11-10 16:00:00'::timestamptz, '2025-12-02 16:00:00'::timestamptz),
(3041, 1041, 1, 1, 'active', 2, 5, '2025-12-03 14:00:00'::timestamptz, true, NULL, '2025-11-16 14:00:00'::timestamptz, '2025-12-03 14:00:00'::timestamptz),
(3044, 1044, 1, 1, 'active', 1, 5, '2025-11-28 10:00:00'::timestamptz, true, NULL, '2025-11-24 14:00:00'::timestamptz, '2025-11-28 10:00:00'::timestamptz),
(3046, 1046, 1, 1, 'active', 1, 5, '2025-12-02 14:00:00'::timestamptz, true, NULL, '2025-12-01 12:00:00'::timestamptz, '2025-12-02 14:00:00'::timestamptz),
(3048, 1048, 1, 1, 'active', 1, 5, '2025-12-03 10:00:00'::timestamptz, true, NULL, '2025-12-02 10:00:00'::timestamptz, '2025-12-03 10:00:00'::timestamptz),
(3050, 1050, 1, 1, 'active', 1, 5, '2025-12-03 15:00:00'::timestamptz, true, NULL, '2025-12-03 12:00:00'::timestamptz, '2025-12-03 15:00:00'::timestamptz);

-- Atualizar sequence
SELECT setval('corev4_followup_campaigns_id_seq', GREATEST((SELECT MAX(id) FROM corev4_followup_campaigns), 3100), true);

-- ============================================================================
-- FOLLOW-UP EXECUTIONS (Steps individuais)
-- ============================================================================

-- Função auxiliar para gerar executions
DO $$
DECLARE
    camp RECORD;
    step_num INT;
    base_date TIMESTAMPTZ;
    step_date TIMESTAMPTZ;
    exec_id INT := 4001;
BEGIN
    FOR camp IN
        SELECT * FROM corev4_followup_campaigns
        WHERE contact_id >= 1001 AND contact_id <= 1053
        ORDER BY id
    LOOP
        base_date := camp.created_at;

        -- Gerar executions para cada step completado
        FOR step_num IN 1..camp.steps_completed LOOP
            step_date := base_date + ((step_num - 1) * INTERVAL '48 hours');

            INSERT INTO corev4_followup_executions (
                id, campaign_id, contact_id, company_id, step, total_steps,
                scheduled_at, executed, sent_at, should_send, decision_reason,
                generated_message, anum_at_execution, created_at, updated_at
            ) VALUES (
                exec_id,
                camp.id,
                camp.contact_id,
                camp.company_id,
                step_num,
                camp.total_steps,
                step_date,
                true,
                step_date + INTERVAL '5 minutes',
                true,
                'Enviado automaticamente conforme agendamento',
                CASE step_num
                    WHEN 1 THEN 'Olá! Vi que conversamos recentemente sobre automação de vendas. Ficou alguma dúvida? Estou à disposição!'
                    WHEN 2 THEN 'Oi! Passando para ver se conseguiu avaliar nossa proposta. Posso ajudar com mais informações?'
                    WHEN 3 THEN 'Olá! Tenho uma novidade: liberamos uma demonstração especial. Quer agendar?'
                    WHEN 4 THEN 'Oi! Ainda está considerando a CoreConnect? Muitos clientes do seu setor têm resultados incríveis!'
                    ELSE 'Olá! Última mensagem por aqui. Se tiver interesse futuro, estou à disposição!'
                END,
                (SELECT total_score FROM corev4_lead_state WHERE contact_id = camp.contact_id LIMIT 1),
                step_date,
                step_date + INTERVAL '5 minutes'
            );

            exec_id := exec_id + 1;
        END LOOP;

        -- Se campanha ativa, adicionar próximo step pendente
        IF camp.status = 'active' AND camp.steps_completed < camp.total_steps THEN
            step_date := base_date + (camp.steps_completed * INTERVAL '48 hours');

            INSERT INTO corev4_followup_executions (
                id, campaign_id, contact_id, company_id, step, total_steps,
                scheduled_at, executed, sent_at, should_send, decision_reason,
                generated_message, anum_at_execution, created_at, updated_at
            ) VALUES (
                exec_id,
                camp.id,
                camp.contact_id,
                camp.company_id,
                camp.steps_completed + 1,
                camp.total_steps,
                step_date,
                false,
                NULL,
                true,
                'Agendado para envio',
                NULL,
                NULL,
                step_date - INTERVAL '24 hours',
                step_date - INTERVAL '24 hours'
            );

            exec_id := exec_id + 1;
        END IF;
    END LOOP;
END $$;

-- Atualizar sequence
SELECT setval('corev4_followup_executions_id_seq', GREATEST((SELECT MAX(id) FROM corev4_followup_executions), 5000), true);

-- Verificar resultados
SELECT
    status,
    COUNT(*) AS total_campanhas,
    SUM(steps_completed) AS total_steps_enviados,
    ROUND(AVG(steps_completed), 1) AS media_steps
FROM corev4_followup_campaigns
WHERE contact_id >= 1001 AND contact_id <= 1053
GROUP BY status
ORDER BY status;
