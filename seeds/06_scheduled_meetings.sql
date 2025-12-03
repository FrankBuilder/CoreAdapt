-- ============================================================================
-- SEED: SCHEDULED MEETINGS (Reuniões Agendadas)
-- CoreAdapt v4 | Tenant: CoreConnect (company_id = 1)
-- ============================================================================
-- Reuniões em diversos estados:
-- - Passadas realizadas (completed)
-- - Passadas com no-show
-- - Passadas canceladas
-- - Futuras agendadas (próximos 30 dias)
-- ============================================================================

-- Limpar reuniões dos contatos demo
DELETE FROM corev4_scheduled_meetings
WHERE contact_id IN (SELECT id FROM corev4_contacts WHERE tags @> ARRAY['demo']::text[]);

-- ============================================================================
-- REUNIÕES REALIZADAS COM SUCESSO (10 reuniões)
-- ============================================================================
INSERT INTO corev4_scheduled_meetings (
    id, contact_id, company_id,
    meeting_date, meeting_end_date, meeting_duration_minutes,
    meeting_type, meeting_timezone, status,
    cal_booking_uid, cal_event_title, cal_meeting_url,
    cal_attendee_email, cal_attendee_name,
    anum_score_at_booking, authority_score, need_score, urgency_score, money_score,
    qualification_stage, pain_category, conversation_summary,
    reminder_24h_sent, reminder_24h_sent_at, reminder_1h_sent, reminder_1h_sent_at,
    meeting_completed, meeting_completed_at, no_show, meeting_notes, meeting_outcome, next_action,
    created_at, updated_at
) VALUES
-- Ricardo Mendes (Agosto)
(5001, 1001, 1,
 '2025-08-04 14:00:00'::timestamptz, '2025-08-04 15:00:00'::timestamptz, 60,
 'discovery', 'America/Sao_Paulo', 'completed',
 'cal-uid-1001', 'Demonstração CoreConnect - Ricardo', 'https://meet.google.com/abc-defg-hij',
 'ricardo.mendes@techsolutions.com.br', 'Ricardo Mendes Silva',
 88.75, 92, 88, 85, 90, 'qualified', 'Escalar/Crescer',
 'Lead altamente qualificado, diretor comercial com autonomia total. Budget aprovado de R$3-5k/mês. Urgência alta.',
 true, '2025-08-03 14:00:00'::timestamptz, true, '2025-08-04 13:00:00'::timestamptz,
 true, '2025-08-04 15:05:00'::timestamptz, false,
 'Reunião excelente! Ricardo ficou impressionado com a demo. Vamos enviar proposta comercial.',
 'proposal_sent', 'Enviar proposta até 06/08',
 '2025-08-03 12:00:00'::timestamptz, '2025-08-04 15:05:00'::timestamptz),

-- Dra. Mariana (Agosto)
(5002, 1004, 1,
 '2025-08-22 16:00:00'::timestamptz, '2025-08-22 16:30:00'::timestamptz, 30,
 'discovery', 'America/Sao_Paulo', 'completed',
 'cal-uid-1004', 'Demonstração CoreConnect - Dra. Mariana', 'https://meet.google.com/mno-pqrs-tuv',
 'dra.mariana@clinicasaude.med.br', 'Dra. Mariana Santos Lima',
 78.00, 85, 80, 72, 75, 'qualified', 'Atendimento ao Cliente',
 'Médica dermatologista, dona de clínica. Secretária sobrecarregada com agendamentos.',
 true, '2025-08-21 16:00:00'::timestamptz, true, '2025-08-22 15:00:00'::timestamptz,
 true, '2025-08-22 16:35:00'::timestamptz, false,
 'Dra. Mariana entendeu bem a solução. Quer ver integração com agenda dela.',
 'demo_scheduled', 'Agendar demo técnica com equipe',
 '2025-08-20 15:00:00'::timestamptz, '2025-08-22 16:35:00'::timestamptz),

-- Roberto Carlos - Construção (Setembro)
(5003, 1009, 1,
 '2025-09-04 10:00:00'::timestamptz, '2025-09-04 11:00:00'::timestamptz, 60,
 'discovery', 'America/Sao_Paulo', 'completed',
 'cal-uid-1009', 'Demonstração CoreConnect - Roberto', 'https://meet.google.com/wxy-zabc-def',
 'roberto.gomes@construtoraalpha.com.br', 'Roberto Carlos Gomes',
 76.25, 80, 75, 78, 72, 'qualified', 'Produtividade da Equipe',
 'Diretor comercial de construtora. 300 leads de incorporações por mês.',
 true, '2025-09-03 10:00:00'::timestamptz, true, '2025-09-04 09:00:00'::timestamptz,
 true, '2025-09-04 11:10:00'::timestamptz, false,
 'Muito interessado! Quer pilotar em um lançamento específico.',
 'pilot_scheduled', 'Definir lançamento para piloto',
 '2025-09-02 14:00:00'::timestamptz, '2025-09-04 11:10:00'::timestamptz),

-- Beatriz Campos - Fintech (Setembro)
(5004, 1012, 1,
 '2025-09-13 15:00:00'::timestamptz, '2025-09-13 16:00:00'::timestamptz, 60,
 'discovery', 'America/Sao_Paulo', 'completed',
 'cal-uid-1012', 'Demonstração CoreConnect - Beatriz', 'https://meet.google.com/ghi-jklm-nop',
 'beatriz.campos@fintechbr.com.br', 'Beatriz Campos Lima',
 89.50, 95, 90, 88, 85, 'qualified', 'Qualificação de Leads',
 'CEO de fintech, 2000 leads/mês, budget R$10k. Já testou concorrentes.',
 true, '2025-09-12 15:00:00'::timestamptz, true, '2025-09-13 14:00:00'::timestamptz,
 true, '2025-09-13 16:15:00'::timestamptz, false,
 'Beatriz fechou contrato na reunião! Início em outubro.',
 'closed_won', 'Enviar contrato e iniciar onboarding',
 '2025-09-12 16:00:00'::timestamptz, '2025-09-13 16:15:00'::timestamptz),

-- Camila Rocha - Imobiliária (Setembro)
(5005, 1014, 1,
 '2025-09-23 14:00:00'::timestamptz, '2025-09-23 14:45:00'::timestamptz, 45,
 'discovery', 'America/Sao_Paulo', 'completed',
 'cal-uid-1014', 'Demonstração CoreConnect - Camila', 'https://meet.google.com/qrs-tuvw-xyz',
 'camila.rocha@imobiliariaprime.com.br', 'Camila Rocha Santos',
 76.75, 75, 80, 82, 70, 'qualified', 'Conversão de Vendas',
 'Dona de imobiliária. Alto volume de leads não qualificados.',
 true, '2025-09-22 14:00:00'::timestamptz, true, '2025-09-23 13:00:00'::timestamptz,
 true, '2025-09-23 14:50:00'::timestamptz, false,
 'Camila gostou da solução. Precisa aprovar com sócio.',
 'pending_approval', 'Follow-up em 1 semana',
 '2025-09-19 12:00:00'::timestamptz, '2025-09-23 14:50:00'::timestamptz),

-- Felipe Augusto - Software House (Outubro)
(5006, 1019, 1,
 '2025-09-30 14:00:00'::timestamptz, '2025-09-30 15:00:00'::timestamptz, 60,
 'discovery', 'America/Sao_Paulo', 'completed',
 'cal-uid-1019', 'Demonstração CoreConnect - Felipe', 'https://meet.google.com/abc-defg-123',
 'felipe.cardoso@softwarehouse.com.br', 'Felipe Augusto Cardoso',
 78.75, 82, 78, 75, 80, 'qualified', 'Automação de Processos',
 'Sócio de software house. Ticket médio R$50k, 80% das reuniões não fecham.',
 true, '2025-09-29 14:00:00'::timestamptz, true, '2025-09-30 13:00:00'::timestamptz,
 true, '2025-09-30 15:10:00'::timestamptz, false,
 'Felipe viu valor claro. Quer proposta para integrar ao CRM deles.',
 'proposal_sent', 'Enviar proposta customizada',
 '2025-09-29 14:00:00'::timestamptz, '2025-09-30 15:10:00'::timestamptz),

-- Eduardo Henrique - Consultoria (Outubro)
(5007, 1021, 1,
 '2025-10-03 16:00:00'::timestamptz, '2025-10-03 17:00:00'::timestamptz, 60,
 'discovery', 'America/Sao_Paulo', 'completed',
 'cal-uid-1021', 'Demonstração CoreConnect - Eduardo', 'https://meet.google.com/hij-klmn-456',
 'eduardo.lopes@consultoriaexcel.com.br', 'Eduardo Henrique Lopes',
 77.00, 90, 78, 72, 68, 'qualified', 'Dados e Insights',
 'Sócio-fundador de consultoria com 15 anos. 50 leads/mês de indicação.',
 true, '2025-10-02 16:00:00'::timestamptz, true, '2025-10-03 15:00:00'::timestamptz,
 true, '2025-10-03 17:05:00'::timestamptz, false,
 'Eduardo entendeu o valor de qualificar antes das reuniões. Quer testar.',
 'trial_started', 'Configurar trial de 14 dias',
 '2025-10-01 10:00:00'::timestamptz, '2025-10-03 17:05:00'::timestamptz),

-- Larissa Fonseca - E-commerce (Outubro)
(5008, 1028, 1,
 '2025-10-21 10:00:00'::timestamptz, '2025-10-21 11:00:00'::timestamptz, 60,
 'discovery', 'America/Sao_Paulo', 'completed',
 'cal-uid-1028', 'Demonstração CoreConnect - Larissa', 'https://meet.google.com/opq-rstu-789',
 'larissa.fonseca@ecommercepro.com.br', 'Larissa Fonseca Vieira',
 88.00, 90, 92, 88, 82, 'qualified', 'Conversão de Vendas',
 'Dona de e-commerce de skincare. 50mil visitas, 2% conversão. Recuperação de carrinhos manual.',
 true, '2025-10-20 10:00:00'::timestamptz, true, '2025-10-21 09:00:00'::timestamptz,
 true, '2025-10-21 11:15:00'::timestamptz, false,
 'Larissa amou! Fechou plano anual na reunião. Case de sucesso!',
 'closed_won', 'Iniciar onboarding imediato',
 '2025-10-17 11:00:00'::timestamptz, '2025-10-21 11:15:00'::timestamptz),

-- Gustavo Henrique - Contabilidade (Outubro)
(5009, 1031, 1,
 '2025-10-28 14:00:00'::timestamptz, '2025-10-28 14:45:00'::timestamptz, 45,
 'discovery', 'America/Sao_Paulo', 'completed',
 'cal-uid-1031', 'Demonstração CoreConnect - Gustavo', 'https://meet.google.com/vwx-yzab-012',
 'gustavo.melo@contabilidadeplus.com.br', 'Gustavo Henrique Melo',
 76.75, 75, 72, 78, 82, 'qualified', 'Redução de Custos',
 'Dono de escritório contábil. Quer reduzir tempo com atendimento básico.',
 true, '2025-10-27 14:00:00'::timestamptz, true, '2025-10-28 13:00:00'::timestamptz,
 true, '2025-10-28 14:50:00'::timestamptz, false,
 'Gustavo interessado mas quer ver ROI detalhado antes de decidir.',
 'pending_decision', 'Enviar análise de ROI',
 '2025-10-23 10:00:00'::timestamptz, '2025-10-28 14:50:00'::timestamptz),

-- Tatiana Mendes - Supermercado (Novembro)
(5010, 1040, 1,
 '2025-11-18 10:00:00'::timestamptz, '2025-11-18 11:00:00'::timestamptz, 60,
 'discovery', 'America/Sao_Paulo', 'completed',
 'cal-uid-1040', 'Demonstração CoreConnect - Tatiana', 'https://meet.google.com/cde-fghi-345',
 'tatiana.mendes@supermercadosbh.com.br', 'Tatiana Mendes Barros',
 76.25, 72, 78, 75, 80, 'qualified', 'Redução de Custos',
 'Dona de rede de 5 supermercados. Milhares de mensagens por dia.',
 true, '2025-11-17 10:00:00'::timestamptz, true, '2025-11-18 09:00:00'::timestamptz,
 true, '2025-11-18 11:10:00'::timestamptz, false,
 'Tatiana e marido participaram. Muito interessados no volume de automação.',
 'proposal_sent', 'Proposta enviada, aguardar retorno',
 '2025-11-13 11:00:00'::timestamptz, '2025-11-18 11:10:00'::timestamptz),

-- ============================================================================
-- REUNIÕES COM NO-SHOW (3 reuniões)
-- ============================================================================
(5011, 1002, 1,
 '2025-08-14 14:00:00'::timestamptz, '2025-08-14 15:00:00'::timestamptz, 60,
 'discovery', 'America/Sao_Paulo', 'completed',
 'cal-uid-1002-noshow', 'Demonstração CoreConnect - Fernanda', 'https://meet.google.com/noshow-001',
 'fernanda.costa@modaelegance.com.br', 'Fernanda Costa Oliveira',
 76.25, 78, 82, 75, 70, 'qualified', 'Conversão de Vendas',
 'Dona de loja de moda. Vendas estagnadas no WhatsApp.',
 true, '2025-08-13 14:00:00'::timestamptz, true, '2025-08-14 13:00:00'::timestamptz,
 false, NULL, true,
 'Lead não compareceu. Tentativa de reagendamento enviada.',
 'no_show', 'Reengajar via WhatsApp',
 '2025-08-10 11:00:00'::timestamptz, '2025-08-14 14:15:00'::timestamptz),

(5012, 1015, 1,
 '2025-09-26 10:00:00'::timestamptz, '2025-09-26 10:30:00'::timestamptz, 30,
 'discovery', 'America/Sao_Paulo', 'completed',
 'cal-uid-1015-noshow', 'Demonstração CoreConnect - Dr. Marcos', 'https://meet.google.com/noshow-002',
 'dr.marcos@odontoclinic.com.br', 'Dr. Marcos Vinícius Teixeira',
 77.00, 88, 72, 70, 78, 'qualified', 'Atendimento ao Cliente',
 'Dentista, dono de clínica. Quer automatizar pré-atendimento.',
 true, '2025-09-25 10:00:00'::timestamptz, true, '2025-09-26 09:00:00'::timestamptz,
 false, NULL, true,
 'Emergência na clínica. Pediu desculpas e reagendou.',
 'rescheduled', 'Reunião reagendada para semana seguinte',
 '2025-09-22 10:00:00'::timestamptz, '2025-09-26 10:15:00'::timestamptz),

(5013, 1035, 1,
 '2025-11-05 15:00:00'::timestamptz, '2025-11-05 16:00:00'::timestamptz, 60,
 'discovery', 'America/Sao_Paulo', 'completed',
 'cal-uid-1035-noshow', 'Demonstração CoreConnect - Vinícius', 'https://meet.google.com/noshow-003',
 'vinicius.costa@startuptech.io', 'Vinícius Costa Nunes',
 77.00, 85, 80, 78, 65, 'qualified', 'Escalar/Crescer',
 'Startup em crescimento acelerado.',
 true, '2025-11-04 15:00:00'::timestamptz, true, '2025-11-05 14:00:00'::timestamptz,
 false, NULL, true,
 'Lead não compareceu nem respondeu mensagens.',
 'lost', 'Mover para nurturing',
 '2025-10-28 15:00:00'::timestamptz, '2025-11-05 15:15:00'::timestamptz),

-- ============================================================================
-- REUNIÕES CANCELADAS (2 reuniões)
-- ============================================================================
(5014, 1037, 1,
 '2025-11-12 14:00:00'::timestamptz, '2025-11-12 15:00:00'::timestamptz, 60,
 'discovery', 'America/Sao_Paulo', 'cancelled',
 'cal-uid-1037-cancel', 'Demonstração CoreConnect - Fábio', 'https://meet.google.com/cancel-001',
 'fabio.moura@atacadaone.com.br', 'Fábio Ricardo Moura',
 76.25, 78, 75, 80, 72, 'qualified', 'Conversão de Vendas',
 'Atacadista com grande volume de pedidos.',
 true, '2025-11-11 14:00:00'::timestamptz, false, NULL,
 false, NULL, false,
 'Cancelado por mudança de prioridades na empresa.',
 'cancelled', 'Recontatar em janeiro',
 '2025-11-04 12:00:00'::timestamptz, '2025-11-10 16:00:00'::timestamptz),

(5015, 1045, 1,
 '2025-12-02 10:00:00'::timestamptz, '2025-12-02 10:45:00'::timestamptz, 45,
 'discovery', 'America/Sao_Paulo', 'cancelled',
 'cal-uid-1045-cancel', 'Demonstração CoreConnect - Fernando', 'https://meet.google.com/cancel-002',
 'fernando.castro@corretoraimob.com.br', 'Fernando Augusto Castro',
 76.75, 80, 72, 85, 70, 'qualified', 'Conversão de Vendas',
 'Corretor de imóveis com urgência em qualificar leads.',
 true, '2025-12-01 10:00:00'::timestamptz, false, NULL,
 false, NULL, false,
 'Cancelou por conflito de agenda. Pediu para reagendar.',
 'pending_reschedule', 'Aguardando nova data',
 '2025-11-26 12:00:00'::timestamptz, '2025-12-01 18:00:00'::timestamptz),

-- ============================================================================
-- REUNIÕES FUTURAS AGENDADAS (10 reuniões - próximos 30 dias)
-- ============================================================================
(5016, 1047, 1,
 '2025-12-05 14:00:00'::timestamptz, '2025-12-05 15:00:00'::timestamptz, 60,
 'discovery', 'America/Sao_Paulo', 'confirmed',
 'cal-uid-1047-future', 'Demonstração CoreConnect - Pedro', 'https://meet.google.com/future-001',
 'pedro.martins@laboratorioanalises.com.br', 'Pedro Henrique Martins',
 76.25, 82, 78, 70, 75, 'qualified', 'Atendimento ao Cliente',
 'Dono de laboratório com 3 unidades. 200 agendamentos/dia.',
 false, NULL, false, NULL,
 false, NULL, false, NULL, NULL, NULL,
 '2025-12-01 15:00:00'::timestamptz, '2025-12-01 15:00:00'::timestamptz),

(5017, 1024, 1,
 '2025-12-06 10:00:00'::timestamptz, '2025-12-06 10:45:00'::timestamptz, 45,
 'discovery', 'America/Sao_Paulo', 'scheduled',
 'cal-uid-1024-future', 'Demonstração CoreConnect - Amanda', 'https://meet.google.com/future-002',
 'amanda.borges@joalheriastar.com.br', 'Amanda Cristina Borges',
 77.50, 70, 85, 80, 75, 'qualified', 'Conversão de Vendas',
 'Dona de joalheria de luxo. Atendimento personalizado.',
 false, NULL, false, NULL,
 false, NULL, false, NULL, NULL, NULL,
 '2025-10-07 10:30:00'::timestamptz, '2025-10-07 10:30:00'::timestamptz),

(5018, 1026, 1,
 '2025-12-09 15:00:00'::timestamptz, '2025-12-09 16:00:00'::timestamptz, 60,
 'discovery', 'America/Sao_Paulo', 'confirmed',
 'cal-uid-1026-future', 'Demonstração CoreConnect - Isabela', 'https://meet.google.com/future-003',
 'isabela.duarte@advocaciabsb.com.br', 'Isabela Duarte Machado',
 58.75, 68, 55, 50, 62, 'developing', 'Gestão de Tempo',
 'Advogada. Sem tempo para qualificar clientes.',
 false, NULL, false, NULL,
 false, NULL, false, NULL, NULL, NULL,
 '2025-10-12 12:00:00'::timestamptz, '2025-10-12 12:00:00'::timestamptz),

(5019, 1018, 1,
 '2025-12-10 14:00:00'::timestamptz, '2025-12-10 15:00:00'::timestamptz, 60,
 'discovery', 'America/Sao_Paulo', 'scheduled',
 'cal-uid-1018-future', 'Demonstração CoreConnect - Luciana', 'https://meet.google.com/future-004',
 'luciana.freitas@agenciamkt.com.br', 'Luciana Freitas Carvalho',
 61.25, 65, 70, 58, 52, 'developing', 'Qualificação de Leads',
 'Agência de marketing. Qualificar leads de clientes.',
 false, NULL, false, NULL,
 false, NULL, false, NULL, NULL, NULL,
 '2025-09-28 14:30:00'::timestamptz, '2025-09-28 14:30:00'::timestamptz),

(5020, 1027, 1,
 '2025-12-12 10:00:00'::timestamptz, '2025-12-12 11:00:00'::timestamptz, 60,
 'discovery', 'America/Sao_Paulo', 'confirmed',
 'cal-uid-1027-future', 'Demonstração CoreConnect - Bruno', 'https://meet.google.com/future-005',
 'bruno.nogueira@energiasolar.com.br', 'Bruno César Nogueira',
 57.50, 52, 68, 62, 48, 'developing', 'Escalar/Crescer',
 'Empresa de energia solar em crescimento.',
 false, NULL, false, NULL,
 false, NULL, false, NULL, NULL, NULL,
 '2025-10-15 15:30:00'::timestamptz, '2025-10-15 15:30:00'::timestamptz),

(5021, 1023, 1,
 '2025-12-16 14:00:00'::timestamptz, '2025-12-16 15:00:00'::timestamptz, 60,
 'discovery', 'America/Sao_Paulo', 'scheduled',
 'cal-uid-1023-future', 'Demonstração CoreConnect - Diego', 'https://meet.google.com/future-006',
 'diego.fernandes@textilsc.com.br', 'Diego Fernandes Oliveira',
 58.75, 60, 58, 52, 65, 'developing', 'Automação de Processos',
 'Indústria têxtil. Automação de vendas B2B.',
 false, NULL, false, NULL,
 false, NULL, false, NULL, NULL, NULL,
 '2025-10-05 11:00:00'::timestamptz, '2025-10-05 11:00:00'::timestamptz),

(5022, 1036, 1,
 '2025-12-18 10:00:00'::timestamptz, '2025-12-18 10:45:00'::timestamptz, 45,
 'discovery', 'America/Sao_Paulo', 'confirmed',
 'cal-uid-1036-future', 'Demonstração CoreConnect - Daniela', 'https://meet.google.com/future-007',
 'daniela.souza@modaintima.com.br', 'Daniela Souza Ferreira',
 53.75, 50, 62, 55, 48, 'developing', 'Conversão de Vendas',
 'Loja de moda íntima. Interesse moderado.',
 false, NULL, false, NULL,
 false, NULL, false, NULL, NULL, NULL,
 '2025-11-01 10:00:00'::timestamptz, '2025-11-01 10:00:00'::timestamptz),

(5023, 1041, 1,
 '2025-12-19 15:00:00'::timestamptz, '2025-12-19 16:00:00'::timestamptz, 60,
 'discovery', 'America/Sao_Paulo', 'scheduled',
 'cal-uid-1041-future', 'Demonstração CoreConnect - Henrique', 'https://meet.google.com/future-008',
 'henrique.bastos@coworkingspace.com.br', 'Henrique Bastos Silva',
 56.25, 58, 55, 62, 50, 'developing', 'Produtividade da Equipe',
 'Coworking. Melhorar produtividade do time.',
 false, NULL, false, NULL,
 false, NULL, false, NULL, NULL, NULL,
 '2025-11-16 12:30:00'::timestamptz, '2025-11-16 12:30:00'::timestamptz),

(5024, 1033, 1,
 '2025-12-23 10:00:00'::timestamptz, '2025-12-23 11:00:00'::timestamptz, 60,
 'discovery', 'America/Sao_Paulo', 'confirmed',
 'cal-uid-1033-future', 'Demonstração CoreConnect - Leonardo', 'https://meet.google.com/future-009',
 'leonardo.ramos@agropecuariars.com.br', 'Leonardo Ramos Cunha',
 57.50, 62, 55, 45, 68, 'developing', 'Escalar/Crescer',
 'Agropecuária. Ciclo de venda longo.',
 false, NULL, false, NULL,
 false, NULL, false, NULL, NULL, NULL,
 '2025-10-26 16:30:00'::timestamptz, '2025-10-26 16:30:00'::timestamptz),

(5025, 1011, 1,
 '2025-12-27 14:00:00'::timestamptz, '2025-12-27 15:00:00'::timestamptz, 60,
 'discovery', 'America/Sao_Paulo', 'scheduled',
 'cal-uid-1011-future', 'Demonstração CoreConnect - André', 'https://meet.google.com/future-010',
 'andre.moreira@logisticasul.com.br', 'André Luiz Moreira',
 57.50, 55, 58, 65, 52, 'developing', 'Automação de Processos',
 'Logística. Avaliando automação de processos.',
 false, NULL, false, NULL,
 false, NULL, false, NULL, NULL, NULL,
 '2025-09-10 09:30:00'::timestamptz, '2025-09-10 09:30:00'::timestamptz);

-- Atualizar sequence
SELECT setval('corev4_scheduled_meetings_id_seq', GREATEST((SELECT MAX(id) FROM corev4_scheduled_meetings), 5100), true);

-- Verificar distribuição de reuniões
SELECT
    CASE
        WHEN meeting_completed = true THEN 'Realizadas'
        WHEN no_show = true THEN 'No-Show'
        WHEN status = 'cancelled' THEN 'Canceladas'
        WHEN meeting_date > NOW() THEN 'Futuras'
        ELSE 'Pendentes'
    END AS categoria,
    COUNT(*) AS total,
    ROUND(AVG(anum_score_at_booking), 1) AS anum_medio
FROM corev4_scheduled_meetings
WHERE contact_id >= 1001 AND contact_id <= 1053
GROUP BY categoria
ORDER BY total DESC;
