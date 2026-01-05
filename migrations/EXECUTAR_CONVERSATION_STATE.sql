-- ============================================================================
-- MIGRACAO: Adicionar conversation_state ao corev4_chats
-- CoreAdapt v4 | Autonomous Scheduling Feature
-- Execute no Supabase SQL Editor
-- ============================================================================

-- ============================================================================
-- 1. ADICIONAR COLUNAS NECESSARIAS
-- ============================================================================

-- Coluna para estado da conversa
ALTER TABLE corev4_chats
ADD COLUMN IF NOT EXISTS conversation_state TEXT DEFAULT 'normal';

-- Coluna para referencia a oferta pendente
ALTER TABLE corev4_chats
ADD COLUMN IF NOT EXISTS pending_offer_id BIGINT;

-- Timestamp da ultima mudanca de estado
ALTER TABLE corev4_chats
ADD COLUMN IF NOT EXISTS state_changed_at TIMESTAMPTZ;

-- Dados temporarios do estado (JSON)
ALTER TABLE corev4_chats
ADD COLUMN IF NOT EXISTS state_data JSONB DEFAULT '{}'::JSONB;

-- ============================================================================
-- 2. ADICIONAR CONSTRAINTS (se nao existirem)
-- ============================================================================

DO $$
BEGIN
    -- Constraint para valores validos de conversation_state
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_conversation_state_valid'
    ) THEN
        ALTER TABLE corev4_chats
        ADD CONSTRAINT chk_conversation_state_valid
        CHECK (conversation_state IN (
            'normal',                  -- Conversa padrao com FRANK
            'awaiting_slot_selection', -- Aguardando lead escolher horario
            'confirming_slot',         -- Confirmando selecao ambigua
            'confirming_booking',      -- Confirmando dados do booking
            'booking_in_progress',     -- Criando booking no calendario
            'awaiting_reschedule'      -- Aguardando nova escolha apos erro
        ));
    END IF;

    -- FK para pending_offer_id (se tabela existir)
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
-- 3. CRIAR INDICES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_chats_conversation_state
ON corev4_chats(conversation_state)
WHERE conversation_state != 'normal';

CREATE INDEX IF NOT EXISTS idx_chats_pending_offer
ON corev4_chats(pending_offer_id)
WHERE pending_offer_id IS NOT NULL;

-- ============================================================================
-- 4. FUNCOES AUXILIARES
-- ============================================================================

-- Funcao: Atualizar estado da conversa
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

-- Funcao: Obter estado atual
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

-- Funcao: Resetar estado
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

-- Funcao: Auto-reset estados antigos (timeout 2h)
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
-- 5. ATUALIZAR REGISTROS EXISTENTES
-- ============================================================================

UPDATE corev4_chats
SET conversation_state = 'normal'
WHERE conversation_state IS NULL;

-- ============================================================================
-- VERIFICACAO
-- ============================================================================

SELECT
    'conversation_state adicionado com sucesso!' AS status,
    COUNT(*) AS total_chats,
    COUNT(CASE WHEN conversation_state = 'normal' THEN 1 END) AS em_estado_normal,
    COUNT(CASE WHEN pending_offer_id IS NOT NULL THEN 1 END) AS com_oferta_pendente
FROM corev4_chats;
