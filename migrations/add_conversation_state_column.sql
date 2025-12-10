-- ============================================================================
-- MIGRATION: Add conversation_state column to corev4_chats
-- CoreAdapt v4 | Autonomous Scheduling Feature
-- ============================================================================
-- Esta migração adiciona um campo para rastrear o estado da conversa,
-- permitindo a implementação de uma state machine para agendamento autônomo.
-- ============================================================================

-- ============================================================================
-- ADICIONAR COLUNA conversation_state
-- ============================================================================
ALTER TABLE corev4_chats
ADD COLUMN IF NOT EXISTS conversation_state TEXT DEFAULT 'normal';

-- Adicionar constraint para valores válidos
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_conversation_state_valid'
    ) THEN
        ALTER TABLE corev4_chats
        ADD CONSTRAINT chk_conversation_state_valid
        CHECK (conversation_state IN (
            'normal',                  -- Conversa padrão com FRANK
            'awaiting_slot_selection', -- Aguardando lead escolher horário
            'confirming_slot',         -- Confirmando seleção ambígua
            'confirming_booking',      -- Confirmando dados do booking
            'booking_in_progress',     -- Criando booking no calendário
            'awaiting_reschedule'      -- Aguardando nova escolha após erro
        ));
    END IF;
END $$;

-- ============================================================================
-- ADICIONAR COLUNA pending_offer_id (referência à oferta ativa)
-- ============================================================================
ALTER TABLE corev4_chats
ADD COLUMN IF NOT EXISTS pending_offer_id BIGINT;

-- Adicionar FK (se tabela de ofertas existir)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_name = 'corev4_pending_slot_offers'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint
            WHERE conname = 'fk_chats_pending_offer'
        ) THEN
            ALTER TABLE corev4_chats
            ADD CONSTRAINT fk_chats_pending_offer
            FOREIGN KEY (pending_offer_id)
            REFERENCES corev4_pending_slot_offers(id)
            ON DELETE SET NULL;
        END IF;
    END IF;
END $$;

-- ============================================================================
-- ADICIONAR COLUNA state_changed_at (timestamp da última mudança de estado)
-- ============================================================================
ALTER TABLE corev4_chats
ADD COLUMN IF NOT EXISTS state_changed_at TIMESTAMPTZ;

-- ============================================================================
-- ADICIONAR COLUNA state_data (dados temporários do estado)
-- ============================================================================
ALTER TABLE corev4_chats
ADD COLUMN IF NOT EXISTS state_data JSONB DEFAULT '{}'::JSONB;

-- ============================================================================
-- ÍNDICE para busca por estado
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_chats_conversation_state
ON corev4_chats(conversation_state)
WHERE conversation_state != 'normal';

CREATE INDEX IF NOT EXISTS idx_chats_pending_offer
ON corev4_chats(pending_offer_id)
WHERE pending_offer_id IS NOT NULL;

-- ============================================================================
-- FUNÇÃO: Atualizar estado da conversa
-- ============================================================================
CREATE OR REPLACE FUNCTION update_conversation_state(
    p_contact_id BIGINT,
    p_company_id INTEGER,
    p_new_state TEXT,
    p_pending_offer_id BIGINT DEFAULT NULL,
    p_state_data JSONB DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_chat_id BIGINT;
BEGIN
    -- Buscar ou criar chat
    SELECT id INTO v_chat_id
    FROM corev4_chats
    WHERE contact_id = p_contact_id
      AND company_id = p_company_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_chat_id IS NULL THEN
        INSERT INTO corev4_chats (contact_id, company_id, conversation_state, pending_offer_id, state_changed_at, state_data)
        VALUES (p_contact_id, p_company_id, p_new_state, p_pending_offer_id, NOW(), COALESCE(p_state_data, '{}'::JSONB));
    ELSE
        UPDATE corev4_chats
        SET
            conversation_state = p_new_state,
            pending_offer_id = p_pending_offer_id,
            state_changed_at = NOW(),
            state_data = COALESCE(p_state_data, state_data),
            updated_at = NOW()
        WHERE id = v_chat_id;
    END IF;

    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNÇÃO: Obter estado atual da conversa
-- ============================================================================
CREATE OR REPLACE FUNCTION get_conversation_state(
    p_contact_id BIGINT,
    p_company_id INTEGER
) RETURNS TABLE (
    chat_id BIGINT,
    conversation_state TEXT,
    pending_offer_id BIGINT,
    state_changed_at TIMESTAMPTZ,
    state_data JSONB,
    minutes_in_state INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id AS chat_id,
        c.conversation_state,
        c.pending_offer_id,
        c.state_changed_at,
        c.state_data,
        EXTRACT(EPOCH FROM (NOW() - c.state_changed_at))::INTEGER / 60 AS minutes_in_state
    FROM corev4_chats c
    WHERE c.contact_id = p_contact_id
      AND c.company_id = p_company_id
    ORDER BY c.created_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNÇÃO: Resetar estado para normal
-- ============================================================================
CREATE OR REPLACE FUNCTION reset_conversation_state(
    p_contact_id BIGINT,
    p_company_id INTEGER
) RETURNS BOOLEAN AS $$
BEGIN
    UPDATE corev4_chats
    SET
        conversation_state = 'normal',
        pending_offer_id = NULL,
        state_changed_at = NOW(),
        state_data = '{}'::JSONB,
        updated_at = NOW()
    WHERE contact_id = p_contact_id
      AND company_id = p_company_id;

    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGER: Auto-reset estado após timeout (2 horas)
-- ============================================================================
CREATE OR REPLACE FUNCTION auto_reset_stale_states()
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE corev4_chats
    SET
        conversation_state = 'normal',
        pending_offer_id = NULL,
        state_changed_at = NOW(),
        state_data = jsonb_set(
            COALESCE(state_data, '{}'::JSONB),
            '{auto_reset_reason}',
            '"timeout_2h"'::JSONB
        ),
        updated_at = NOW()
    WHERE conversation_state != 'normal'
      AND state_changed_at < NOW() - INTERVAL '2 hours';

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COMENTÁRIOS
-- ============================================================================
COMMENT ON COLUMN corev4_chats.conversation_state IS 'Estado atual da conversa: normal, awaiting_slot_selection, confirming_slot, confirming_booking, booking_in_progress, awaiting_reschedule';
COMMENT ON COLUMN corev4_chats.pending_offer_id IS 'Referência à oferta de horários pendente';
COMMENT ON COLUMN corev4_chats.state_changed_at IS 'Timestamp da última mudança de estado';
COMMENT ON COLUMN corev4_chats.state_data IS 'Dados temporários do estado atual (JSON)';

-- ============================================================================
-- ATUALIZAR REGISTROS EXISTENTES
-- ============================================================================
UPDATE corev4_chats
SET conversation_state = 'normal'
WHERE conversation_state IS NULL;

-- ============================================================================
-- VERIFICAÇÃO
-- ============================================================================
SELECT
    'Coluna conversation_state adicionada com sucesso!' AS status,
    COUNT(*) AS total_chats,
    COUNT(CASE WHEN conversation_state = 'normal' THEN 1 END) AS em_estado_normal
FROM corev4_chats;
