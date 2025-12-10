-- ============================================================================
-- MIGRATION: Create corev4_pending_slot_offers table
-- CoreAdapt v4 | Autonomous Scheduling Feature
-- ============================================================================
-- Esta tabela armazena as ofertas de horários pendentes para cada lead,
-- permitindo rastrear quais slots foram oferecidos e qual foi selecionado.
-- ============================================================================

-- ============================================================================
-- TABELA PRINCIPAL: corev4_pending_slot_offers
-- ============================================================================
CREATE TABLE IF NOT EXISTS corev4_pending_slot_offers (
    id BIGSERIAL PRIMARY KEY,
    contact_id BIGINT NOT NULL REFERENCES corev4_contacts(id) ON DELETE CASCADE,
    company_id INTEGER NOT NULL REFERENCES corev4_companies(id) ON DELETE CASCADE,

    -- Timestamps da oferta
    offered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '24 hours'),

    -- Slots oferecidos (até 5)
    slot_1_datetime TIMESTAMPTZ NOT NULL,
    slot_1_label TEXT, -- "Terça, 10/12 às 14:00"
    slot_2_datetime TIMESTAMPTZ NOT NULL,
    slot_2_label TEXT,
    slot_3_datetime TIMESTAMPTZ,
    slot_3_label TEXT,
    slot_4_datetime TIMESTAMPTZ,
    slot_4_label TEXT,
    slot_5_datetime TIMESTAMPTZ,
    slot_5_label TEXT,

    -- Timezone usado na oferta
    offer_timezone TEXT NOT NULL DEFAULT 'America/Sao_Paulo',

    -- Mensagem original enviada ao lead
    offer_message_sent TEXT,

    -- Seleção do lead
    selected_slot INTEGER CHECK (selected_slot IS NULL OR (selected_slot >= 1 AND selected_slot <= 5)),
    selection_message TEXT, -- Mensagem original do lead
    selection_confidence DECIMAL(3,2) CHECK (selection_confidence IS NULL OR (selection_confidence >= 0 AND selection_confidence <= 1)),
    selected_at TIMESTAMPTZ,

    -- Status da oferta
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending',              -- Aguardando resposta do lead
        'selected',             -- Lead selecionou um slot
        'confirmed',            -- Booking criado com sucesso
        'expired',              -- Expirou sem resposta
        'cancelled',            -- Cancelada (lead desistiu ou nova oferta)
        'slot_unavailable',     -- Slot selecionado não está mais disponível
        'needs_confirmation'    -- Parser incerto, aguardando confirmação
    )),

    -- Dados do booking (após confirmação)
    booking_id BIGINT REFERENCES corev4_scheduled_meetings(id) ON DELETE SET NULL,
    booking_created_at TIMESTAMPTZ,

    -- Contexto da oferta
    anum_score_at_offer INTEGER,
    conversation_context TEXT, -- Resumo do contexto que levou à oferta

    -- Tentativas de parsing
    parsing_attempts INTEGER DEFAULT 0,
    last_parsing_result JSONB, -- {"matched_slot": 2, "confidence": 0.95, "method": "direct_number"}

    -- Motivo de cancelamento/expiração
    cancellation_reason TEXT,

    -- Auditoria
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- ÍNDICES
-- ============================================================================

-- Busca por contato (mais comum)
CREATE INDEX IF NOT EXISTS idx_pending_slots_contact
ON corev4_pending_slot_offers(contact_id);

-- Busca por status pendente
CREATE INDEX IF NOT EXISTS idx_pending_slots_pending
ON corev4_pending_slot_offers(status, expires_at)
WHERE status = 'pending';

-- Busca por empresa
CREATE INDEX IF NOT EXISTS idx_pending_slots_company
ON corev4_pending_slot_offers(company_id);

-- Busca por expiração (para job de cleanup)
CREATE INDEX IF NOT EXISTS idx_pending_slots_expiring
ON corev4_pending_slot_offers(expires_at)
WHERE status = 'pending';

-- Busca por booking (para referência inversa)
CREATE INDEX IF NOT EXISTS idx_pending_slots_booking
ON corev4_pending_slot_offers(booking_id)
WHERE booking_id IS NOT NULL;

-- ============================================================================
-- TRIGGER PARA UPDATED_AT
-- ============================================================================
CREATE OR REPLACE FUNCTION update_pending_slot_offers_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_pending_slots_updated_at ON corev4_pending_slot_offers;
CREATE TRIGGER trg_pending_slots_updated_at
    BEFORE UPDATE ON corev4_pending_slot_offers
    FOR EACH ROW
    EXECUTE FUNCTION update_pending_slot_offers_timestamp();

-- ============================================================================
-- FUNÇÃO: Obter oferta pendente de um contato
-- ============================================================================
CREATE OR REPLACE FUNCTION get_pending_slot_offer(p_contact_id BIGINT)
RETURNS TABLE (
    offer_id BIGINT,
    slot_1 TIMESTAMPTZ,
    slot_1_label TEXT,
    slot_2 TIMESTAMPTZ,
    slot_2_label TEXT,
    slot_3 TIMESTAMPTZ,
    slot_3_label TEXT,
    slot_4 TIMESTAMPTZ,
    slot_4_label TEXT,
    slot_5 TIMESTAMPTZ,
    slot_5_label TEXT,
    offer_timezone TEXT,
    expires_at TIMESTAMPTZ,
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        o.id AS offer_id,
        o.slot_1_datetime AS slot_1,
        o.slot_1_label,
        o.slot_2_datetime AS slot_2,
        o.slot_2_label,
        o.slot_3_datetime AS slot_3,
        o.slot_3_label,
        o.slot_4_datetime AS slot_4,
        o.slot_4_label,
        o.slot_5_datetime AS slot_5,
        o.slot_5_label,
        o.offer_timezone,
        o.expires_at,
        o.status
    FROM corev4_pending_slot_offers o
    WHERE o.contact_id = p_contact_id
      AND o.status IN ('pending', 'needs_confirmation')
      AND o.expires_at > NOW()
    ORDER BY o.created_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNÇÃO: Registrar seleção de slot
-- ============================================================================
CREATE OR REPLACE FUNCTION register_slot_selection(
    p_offer_id BIGINT,
    p_selected_slot INTEGER,
    p_selection_message TEXT,
    p_confidence DECIMAL(3,2) DEFAULT 1.0,
    p_parsing_result JSONB DEFAULT NULL
) RETURNS TABLE (
    success BOOLEAN,
    selected_datetime TIMESTAMPTZ,
    message TEXT
) AS $$
DECLARE
    v_offer RECORD;
    v_selected_datetime TIMESTAMPTZ;
BEGIN
    -- Buscar oferta
    SELECT * INTO v_offer
    FROM corev4_pending_slot_offers
    WHERE id = p_offer_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN QUERY SELECT false, NULL::TIMESTAMPTZ, 'Oferta não encontrada'::TEXT;
        RETURN;
    END IF;

    IF v_offer.status != 'pending' AND v_offer.status != 'needs_confirmation' THEN
        RETURN QUERY SELECT false, NULL::TIMESTAMPTZ,
            ('Oferta não está pendente. Status atual: ' || v_offer.status)::TEXT;
        RETURN;
    END IF;

    IF v_offer.expires_at < NOW() THEN
        UPDATE corev4_pending_slot_offers SET status = 'expired' WHERE id = p_offer_id;
        RETURN QUERY SELECT false, NULL::TIMESTAMPTZ, 'Oferta expirada'::TEXT;
        RETURN;
    END IF;

    -- Obter datetime do slot selecionado
    v_selected_datetime := CASE p_selected_slot
        WHEN 1 THEN v_offer.slot_1_datetime
        WHEN 2 THEN v_offer.slot_2_datetime
        WHEN 3 THEN v_offer.slot_3_datetime
        WHEN 4 THEN v_offer.slot_4_datetime
        WHEN 5 THEN v_offer.slot_5_datetime
    END;

    IF v_selected_datetime IS NULL THEN
        RETURN QUERY SELECT false, NULL::TIMESTAMPTZ,
            ('Slot ' || p_selected_slot || ' não existe nesta oferta')::TEXT;
        RETURN;
    END IF;

    -- Atualizar oferta
    UPDATE corev4_pending_slot_offers SET
        selected_slot = p_selected_slot,
        selection_message = p_selection_message,
        selection_confidence = p_confidence,
        selected_at = NOW(),
        status = CASE WHEN p_confidence >= 0.8 THEN 'selected' ELSE 'needs_confirmation' END,
        parsing_attempts = parsing_attempts + 1,
        last_parsing_result = COALESCE(p_parsing_result, last_parsing_result)
    WHERE id = p_offer_id;

    RETURN QUERY SELECT
        true,
        v_selected_datetime,
        ('Slot ' || p_selected_slot || ' selecionado com sucesso')::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNÇÃO: Cancelar ofertas anteriores ao criar nova
-- ============================================================================
CREATE OR REPLACE FUNCTION cancel_previous_slot_offers(
    p_contact_id BIGINT,
    p_reason TEXT DEFAULT 'new_offer_created'
) RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE corev4_pending_slot_offers
    SET
        status = 'cancelled',
        cancellation_reason = p_reason,
        updated_at = NOW()
    WHERE contact_id = p_contact_id
      AND status IN ('pending', 'needs_confirmation');

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- JOB: Expirar ofertas antigas (rodar via cron)
-- ============================================================================
CREATE OR REPLACE FUNCTION expire_old_slot_offers()
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE corev4_pending_slot_offers
    SET
        status = 'expired',
        cancellation_reason = 'auto_expired',
        updated_at = NOW()
    WHERE status = 'pending'
      AND expires_at < NOW();

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- VIEW: Ofertas pendentes com detalhes do contato
-- ============================================================================
CREATE OR REPLACE VIEW v_pending_slot_offers_details AS
SELECT
    o.id AS offer_id,
    o.contact_id,
    c.full_name AS contact_name,
    c.whatsapp AS contact_whatsapp,
    o.company_id,
    o.offered_at,
    o.expires_at,
    o.status,
    o.slot_1_datetime,
    o.slot_1_label,
    o.slot_2_datetime,
    o.slot_2_label,
    o.slot_3_datetime,
    o.slot_3_label,
    o.selected_slot,
    o.selected_at,
    o.selection_confidence,
    o.anum_score_at_offer,
    o.booking_id,
    -- Tempo restante
    CASE
        WHEN o.expires_at > NOW()
        THEN EXTRACT(EPOCH FROM (o.expires_at - NOW())) / 3600
        ELSE 0
    END AS hours_until_expiration,
    -- Flags
    o.expires_at < NOW() AS is_expired,
    o.selected_slot IS NOT NULL AS has_selection
FROM corev4_pending_slot_offers o
INNER JOIN corev4_contacts c ON o.contact_id = c.id;

-- ============================================================================
-- COMENTÁRIOS
-- ============================================================================
COMMENT ON TABLE corev4_pending_slot_offers IS 'Ofertas de horários pendentes para agendamento autônomo';
COMMENT ON COLUMN corev4_pending_slot_offers.slot_1_datetime IS 'Datetime UTC do primeiro slot oferecido';
COMMENT ON COLUMN corev4_pending_slot_offers.slot_1_label IS 'Label legível do slot (ex: Terça, 10/12 às 14:00)';
COMMENT ON COLUMN corev4_pending_slot_offers.selection_confidence IS 'Confiança do parser na seleção (0.0 a 1.0)';
COMMENT ON COLUMN corev4_pending_slot_offers.status IS 'Status: pending, selected, confirmed, expired, cancelled, slot_unavailable, needs_confirmation';
COMMENT ON COLUMN corev4_pending_slot_offers.last_parsing_result IS 'Resultado da última tentativa de parsing da mensagem do lead';

-- ============================================================================
-- VERIFICAÇÃO
-- ============================================================================
SELECT
    'corev4_pending_slot_offers criada com sucesso!' AS status,
    (SELECT COUNT(*) FROM corev4_pending_slot_offers) AS registros;
