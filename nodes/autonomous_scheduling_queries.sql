-- ============================================================================
-- AUTONOMOUS SCHEDULING QUERIES
-- CoreAdapt v4 | Queries SQL para Agendamento Autônomo
-- ============================================================================
-- Estas queries devem ser usadas nos nodes SQL do One Flow para suportar
-- o agendamento autônomo.
-- ============================================================================

-- ============================================================================
-- QUERY 1: Buscar estado da conversa com oferta pendente
-- Uso: No início do One Flow, após receber mensagem
-- ============================================================================
-- Parâmetros: $1 = contact_id, $2 = company_id
SELECT
    c.id AS chat_id,
    c.conversation_state,
    c.pending_offer_id,
    c.state_changed_at,
    c.state_data,
    -- Dados da oferta pendente (se houver)
    o.id AS offer_id,
    o.status AS offer_status,
    o.expires_at AS offer_expires_at,
    o.slot_1_datetime,
    o.slot_1_label,
    o.slot_2_datetime,
    o.slot_2_label,
    o.slot_3_datetime,
    o.slot_3_label,
    -- Verificar se oferta ainda é válida
    CASE
        WHEN o.id IS NOT NULL AND o.expires_at > NOW() AND o.status = 'pending'
        THEN true
        ELSE false
    END AS has_valid_offer,
    -- Minutos desde mudança de estado
    EXTRACT(EPOCH FROM (NOW() - c.state_changed_at))::INTEGER / 60 AS minutes_in_state
FROM corev4_chats c
LEFT JOIN corev4_pending_slot_offers o
    ON o.id = c.pending_offer_id
    AND o.status IN ('pending', 'needs_confirmation')
WHERE c.contact_id = $1
  AND c.company_id = $2
ORDER BY c.created_at DESC
LIMIT 1;

-- ============================================================================
-- QUERY 2: Buscar oferta pendente com detalhes dos slots
-- Uso: Quando conversation_state = 'awaiting_slot_selection'
-- ============================================================================
-- Parâmetros: $1 = contact_id
SELECT
    o.id AS offer_id,
    o.contact_id,
    o.company_id,
    o.status,
    o.expires_at,
    o.offer_timezone,
    -- Slots formatados como JSON array
    jsonb_build_array(
        jsonb_build_object(
            'index', 1,
            'datetime', o.slot_1_datetime,
            'label', o.slot_1_label
        ),
        jsonb_build_object(
            'index', 2,
            'datetime', o.slot_2_datetime,
            'label', o.slot_2_label
        ),
        jsonb_build_object(
            'index', 3,
            'datetime', o.slot_3_datetime,
            'label', o.slot_3_label
        )
    ) FILTER (WHERE o.slot_1_datetime IS NOT NULL) AS slots,
    -- Tempo restante
    EXTRACT(EPOCH FROM (o.expires_at - NOW())) / 3600 AS hours_remaining
FROM corev4_pending_slot_offers o
WHERE o.contact_id = $1
  AND o.status IN ('pending', 'needs_confirmation')
  AND o.expires_at > NOW()
ORDER BY o.created_at DESC
LIMIT 1;

-- ============================================================================
-- QUERY 3: Registrar seleção de slot
-- Uso: Após parser detectar seleção
-- ============================================================================
-- Parâmetros: $1 = offer_id, $2 = selected_slot, $3 = selection_message, $4 = confidence
UPDATE corev4_pending_slot_offers
SET
    selected_slot = $2,
    selection_message = $3,
    selection_confidence = $4,
    selected_at = NOW(),
    status = CASE
        WHEN $4 >= 0.8 THEN 'selected'
        ELSE 'needs_confirmation'
    END,
    parsing_attempts = parsing_attempts + 1,
    updated_at = NOW()
WHERE id = $1
  AND status IN ('pending', 'needs_confirmation')
RETURNING
    id AS offer_id,
    selected_slot,
    status,
    CASE selected_slot
        WHEN 1 THEN slot_1_datetime
        WHEN 2 THEN slot_2_datetime
        WHEN 3 THEN slot_3_datetime
        WHEN 4 THEN slot_4_datetime
        WHEN 5 THEN slot_5_datetime
    END AS selected_datetime,
    CASE selected_slot
        WHEN 1 THEN slot_1_label
        WHEN 2 THEN slot_2_label
        WHEN 3 THEN slot_3_label
        WHEN 4 THEN slot_4_label
        WHEN 5 THEN slot_5_label
    END AS selected_label;

-- ============================================================================
-- QUERY 4: Atualizar estado da conversa
-- Uso: Após oferecer horários ou após booking
-- ============================================================================
-- Parâmetros: $1 = contact_id, $2 = company_id, $3 = new_state, $4 = pending_offer_id (nullable)
UPDATE corev4_chats
SET
    conversation_state = $3,
    pending_offer_id = $4,
    state_changed_at = NOW(),
    updated_at = NOW()
WHERE contact_id = $1
  AND company_id = $2
RETURNING id, conversation_state, pending_offer_id;

-- ============================================================================
-- QUERY 5: Verificar disponibilidade do ANUM para oferecer
-- Uso: Antes de chamar Availability Flow
-- ============================================================================
-- Parâmetros: $1 = contact_id
SELECT
    c.id AS contact_id,
    c.full_name,
    ls.total_score AS anum_score,
    ls.qualification_stage,
    -- Verificar se pode oferecer Mesa
    CASE
        WHEN ls.total_score >= 55 THEN true
        ELSE false
    END AS can_offer_mesa,
    -- Verificar se já tem reunião agendada
    EXISTS (
        SELECT 1
        FROM corev4_scheduled_meetings sm
        WHERE sm.contact_id = c.id
          AND sm.status IN ('scheduled', 'confirmed')
          AND sm.meeting_date > NOW()
    ) AS has_upcoming_meeting,
    -- Verificar se já recebeu oferta recente (últimas 24h)
    EXISTS (
        SELECT 1
        FROM corev4_pending_slot_offers o
        WHERE o.contact_id = c.id
          AND o.offered_at > NOW() - INTERVAL '24 hours'
    ) AS has_recent_offer
FROM corev4_contacts c
LEFT JOIN corev4_lead_state ls ON ls.contact_id = c.id
WHERE c.id = $1;

-- ============================================================================
-- QUERY 6: Buscar histórico recente para contexto
-- Uso: Para enriquecer contexto do FRANK
-- ============================================================================
-- Parâmetros: $1 = contact_id, $2 = limit (default 10)
SELECT
    role,
    message,
    message_timestamp,
    message_type
FROM corev4_chat_history
WHERE contact_id = $1
ORDER BY message_timestamp DESC
LIMIT COALESCE($2, 10);

-- ============================================================================
-- QUERY 7: Expirar ofertas antigas (para job de limpeza)
-- Uso: Cron job ou trigger
-- ============================================================================
UPDATE corev4_pending_slot_offers
SET
    status = 'expired',
    cancellation_reason = 'auto_expired',
    updated_at = NOW()
WHERE status = 'pending'
  AND expires_at < NOW()
RETURNING id, contact_id, company_id;

-- ============================================================================
-- QUERY 8: Buscar métricas de agendamento autônomo
-- Uso: Monitoramento e analytics
-- ============================================================================
SELECT
    DATE(offered_at) AS date,
    COUNT(*) AS total_offers,
    COUNT(CASE WHEN status = 'confirmed' THEN 1 END) AS confirmed,
    COUNT(CASE WHEN status = 'expired' THEN 1 END) AS expired,
    COUNT(CASE WHEN status = 'cancelled' THEN 1 END) AS cancelled,
    COUNT(CASE WHEN status = 'selected' THEN 1 END) AS selected_pending,
    ROUND(
        100.0 * COUNT(CASE WHEN status = 'confirmed' THEN 1 END) / NULLIF(COUNT(*), 0),
        2
    ) AS conversion_rate,
    ROUND(
        AVG(
            CASE WHEN selected_at IS NOT NULL
            THEN EXTRACT(EPOCH FROM (selected_at - offered_at)) / 60
            END
        ),
        2
    ) AS avg_selection_minutes
FROM corev4_pending_slot_offers
WHERE offered_at > NOW() - INTERVAL '30 days'
GROUP BY DATE(offered_at)
ORDER BY date DESC;

-- ============================================================================
-- QUERY 9: Distribuição de slots selecionados
-- Uso: Otimização de horários
-- ============================================================================
SELECT
    selected_slot,
    COUNT(*) AS times_selected,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM corev4_pending_slot_offers
WHERE selected_slot IS NOT NULL
  AND offered_at > NOW() - INTERVAL '30 days'
GROUP BY selected_slot
ORDER BY selected_slot;

-- ============================================================================
-- QUERY 10: Verificar conflitos antes de booking (double-check)
-- Uso: No Booking Flow, antes de criar evento
-- ============================================================================
-- Parâmetros: $1 = company_id, $2 = start_datetime, $3 = end_datetime
SELECT
    COUNT(*) AS conflict_count,
    array_agg(id) AS conflicting_meeting_ids
FROM corev4_scheduled_meetings
WHERE company_id = $1
  AND status IN ('scheduled', 'confirmed')
  AND (
    -- Novo meeting começaria durante outro
    (meeting_date <= $2::timestamptz AND meeting_end_date > $2::timestamptz)
    OR
    -- Novo meeting terminaria durante outro
    (meeting_date < $3::timestamptz AND meeting_end_date >= $3::timestamptz)
    OR
    -- Novo meeting contém outro
    (meeting_date >= $2::timestamptz AND meeting_end_date <= $3::timestamptz)
  );
