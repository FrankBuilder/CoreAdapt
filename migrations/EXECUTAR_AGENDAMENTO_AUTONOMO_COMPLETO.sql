-- ============================================================================
-- MIGRACAO COMPLETA: AGENDAMENTO AUTONOMO
-- CoreAdapt v4.1.0 | Janeiro 2026
-- ============================================================================
-- Execute este arquivo COMPLETO no Supabase SQL Editor
-- Ele inclui TODAS as tabelas, colunas e funcoes necessarias
-- ============================================================================

-- ============================================================================
-- PARTE 1: EXTENSOES
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- PARTE 2: TABELA corev4_calendar_settings (se nao existir)
-- ============================================================================
CREATE TABLE IF NOT EXISTS corev4_calendar_settings (
    id SERIAL PRIMARY KEY,
    company_id INTEGER UNIQUE NOT NULL REFERENCES corev4_companies(id) ON DELETE CASCADE,
    calendar_provider TEXT NOT NULL DEFAULT 'google' CHECK (calendar_provider IN ('google', 'cal_com', 'outlook')),
    calendar_id TEXT,
    timezone TEXT NOT NULL DEFAULT 'America/Sao_Paulo',
    business_hours_start TIME NOT NULL DEFAULT '09:00:00',
    business_hours_end TIME NOT NULL DEFAULT '18:00:00',
    meeting_duration_minutes INTEGER NOT NULL DEFAULT 45,
    buffer_before_minutes INTEGER NOT NULL DEFAULT 15,
    buffer_after_minutes INTEGER NOT NULL DEFAULT 15,
    min_notice_hours INTEGER NOT NULL DEFAULT 24,
    max_days_ahead INTEGER NOT NULL DEFAULT 14,
    max_meetings_per_day INTEGER NOT NULL DEFAULT 4,
    allowed_weekdays TEXT[] NOT NULL DEFAULT ARRAY['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
    preferred_time_slots JSONB DEFAULT '[
        {"start": "10:00", "end": "12:00", "priority": "high"},
        {"start": "14:00", "end": "16:00", "priority": "medium"}
    ]'::JSONB,
    preferred_weekdays JSONB DEFAULT '{"monday": 2, "tuesday": 3, "wednesday": 3, "thursday": 3, "friday": 1}'::JSONB,
    excluded_dates DATE[] DEFAULT ARRAY[]::DATE[],
    slots_to_offer INTEGER NOT NULL DEFAULT 3,
    offer_expiration_hours INTEGER NOT NULL DEFAULT 24,
    slot_offer_template TEXT DEFAULT 'Legal! Deixa eu ver a agenda do Francisco...

Temos essas opcoes nos proximos dias:
{slots}

Qual funciona melhor pra voce? (responde 1, 2 ou 3)',
    booking_confirmation_template TEXT DEFAULT 'Perfeito! Sua Mesa de Clareza esta confirmada:

{date}
Duracao: 45 minutos
Link: {meeting_url}

Te mando lembretes 24h e 1h antes.

Ate la!',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- PARTE 3: TABELA corev4_pending_slot_offers (se nao existir)
-- ============================================================================
CREATE TABLE IF NOT EXISTS corev4_pending_slot_offers (
    id BIGSERIAL PRIMARY KEY,
    contact_id BIGINT NOT NULL REFERENCES corev4_contacts(id) ON DELETE CASCADE,
    company_id INTEGER NOT NULL REFERENCES corev4_companies(id) ON DELETE CASCADE,
    slot_1_datetime TIMESTAMPTZ,
    slot_1_label TEXT,
    slot_2_datetime TIMESTAMPTZ,
    slot_2_label TEXT,
    slot_3_datetime TIMESTAMPTZ,
    slot_3_label TEXT,
    slot_4_datetime TIMESTAMPTZ,
    slot_4_label TEXT,
    slot_5_datetime TIMESTAMPTZ,
    slot_5_label TEXT,
    offer_timezone TEXT DEFAULT 'America/Sao_Paulo',
    offer_message_sent TEXT,
    selected_slot INTEGER CHECK (selected_slot BETWEEN 1 AND 5),
    selection_message TEXT,
    selection_confidence DECIMAL(3,2),
    selected_at TIMESTAMPTZ,
    anum_score_at_offer INTEGER,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'selected', 'needs_confirmation', 'confirmed', 'expired', 'cancelled')),
    cancellation_reason TEXT,
    booking_id BIGINT,
    booking_created_at TIMESTAMPTZ,
    parsing_attempts INTEGER DEFAULT 0,
    last_parsing_result JSONB,
    offered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '24 hours'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pending_offers_contact ON corev4_pending_slot_offers(contact_id);
CREATE INDEX IF NOT EXISTS idx_pending_offers_status ON corev4_pending_slot_offers(status) WHERE status IN ('pending', 'needs_confirmation');
CREATE INDEX IF NOT EXISTS idx_pending_offers_expires ON corev4_pending_slot_offers(expires_at) WHERE status = 'pending';

-- ============================================================================
-- PARTE 4: TABELA corev4_scheduled_meetings (se nao existir)
-- ============================================================================
CREATE TABLE IF NOT EXISTS corev4_scheduled_meetings (
    id BIGSERIAL PRIMARY KEY,
    contact_id BIGINT NOT NULL REFERENCES corev4_contacts(id) ON DELETE CASCADE,
    company_id INTEGER NOT NULL REFERENCES corev4_companies(id) ON DELETE CASCADE,
    meeting_date TIMESTAMPTZ NOT NULL,
    meeting_end_date TIMESTAMPTZ NOT NULL,
    meeting_duration_minutes INTEGER NOT NULL DEFAULT 45,
    meeting_type TEXT DEFAULT 'mesa_clareza',
    meeting_timezone TEXT DEFAULT 'America/Sao_Paulo',
    status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'confirmed', 'completed', 'cancelled', 'no_show', 'rescheduled')),
    cal_booking_uid TEXT,
    cal_event_title TEXT,
    cal_meeting_url TEXT,
    cal_attendee_email TEXT,
    cal_attendee_name TEXT,
    anum_score_at_booking INTEGER,
    qualification_stage TEXT,
    pain_category TEXT,
    created_by TEXT DEFAULT 'autonomous_agent',
    cancellation_reason TEXT,
    rescheduled_to BIGINT REFERENCES corev4_scheduled_meetings(id),
    reminder_24h_sent BOOLEAN DEFAULT false,
    reminder_1h_sent BOOLEAN DEFAULT false,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_meetings_contact ON corev4_scheduled_meetings(contact_id);
CREATE INDEX IF NOT EXISTS idx_meetings_date ON corev4_scheduled_meetings(meeting_date);
CREATE INDEX IF NOT EXISTS idx_meetings_status ON corev4_scheduled_meetings(status) WHERE status IN ('scheduled', 'confirmed');

-- ============================================================================
-- PARTE 5: COLUNAS conversation_state em corev4_chats
-- ============================================================================
ALTER TABLE corev4_chats ADD COLUMN IF NOT EXISTS conversation_state TEXT DEFAULT 'normal';
ALTER TABLE corev4_chats ADD COLUMN IF NOT EXISTS pending_offer_id BIGINT;
ALTER TABLE corev4_chats ADD COLUMN IF NOT EXISTS state_changed_at TIMESTAMPTZ;
ALTER TABLE corev4_chats ADD COLUMN IF NOT EXISTS state_data JSONB DEFAULT '{}'::JSONB;

-- Constraint para valores validos
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_conversation_state_valid') THEN
        ALTER TABLE corev4_chats ADD CONSTRAINT chk_conversation_state_valid
        CHECK (conversation_state IN ('normal', 'awaiting_slot_selection', 'confirming_slot', 'confirming_booking', 'booking_in_progress', 'awaiting_reschedule'));
    END IF;
END $$;

-- FK para pending_offer_id
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_chats_pending_offer') THEN
        ALTER TABLE corev4_chats ADD CONSTRAINT fk_chats_pending_offer
        FOREIGN KEY (pending_offer_id) REFERENCES corev4_pending_slot_offers(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Indices
CREATE INDEX IF NOT EXISTS idx_chats_conversation_state ON corev4_chats(conversation_state) WHERE conversation_state != 'normal';
CREATE INDEX IF NOT EXISTS idx_chats_pending_offer ON corev4_chats(pending_offer_id) WHERE pending_offer_id IS NOT NULL;

-- ============================================================================
-- PARTE 6: FUNCOES AUXILIARES
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
    SELECT id INTO v_chat_id
    FROM corev4_chats
    WHERE contact_id = p_contact_id AND company_id = p_company_id
    ORDER BY created_at DESC LIMIT 1;

    IF v_chat_id IS NULL THEN
        INSERT INTO corev4_chats (contact_id, company_id, conversation_state, pending_offer_id, state_changed_at, state_data)
        VALUES (p_contact_id, p_company_id, p_new_state, p_pending_offer_id, NOW(), COALESCE(p_state_data, '{}'::JSONB));
    ELSE
        UPDATE corev4_chats SET
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

-- Funcao: Resetar estado
CREATE OR REPLACE FUNCTION reset_conversation_state(
    p_contact_id BIGINT,
    p_company_id INTEGER
) RETURNS BOOLEAN AS $$
BEGIN
    UPDATE corev4_chats SET
        conversation_state = 'normal',
        pending_offer_id = NULL,
        state_changed_at = NOW(),
        state_data = '{}'::JSONB,
        updated_at = NOW()
    WHERE contact_id = p_contact_id AND company_id = p_company_id;
    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Funcao: Cancelar ofertas anteriores
CREATE OR REPLACE FUNCTION cancel_previous_slot_offers(
    p_contact_id BIGINT,
    p_reason TEXT DEFAULT 'new_offer_created'
) RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE corev4_pending_slot_offers SET
        status = 'cancelled',
        cancellation_reason = p_reason,
        updated_at = NOW()
    WHERE contact_id = p_contact_id
      AND status IN ('pending', 'needs_confirmation');
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Funcao: Auto-expirar ofertas antigas
CREATE OR REPLACE FUNCTION auto_expire_slot_offers()
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE corev4_pending_slot_offers SET
        status = 'expired',
        cancellation_reason = 'auto_expired',
        updated_at = NOW()
    WHERE status = 'pending' AND expires_at < NOW();
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Funcao: Auto-resetar estados stale (2h)
CREATE OR REPLACE FUNCTION auto_reset_stale_states()
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE corev4_chats SET
        conversation_state = 'normal',
        pending_offer_id = NULL,
        state_changed_at = NOW(),
        state_data = jsonb_set(COALESCE(state_data, '{}'::JSONB), '{auto_reset_reason}', '"timeout_2h"'::JSONB),
        updated_at = NOW()
    WHERE conversation_state != 'normal'
      AND state_changed_at < NOW() - INTERVAL '2 hours';
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PARTE 7: INSERIR CONFIGURACAO PADRAO (se nao existir)
-- ============================================================================
INSERT INTO corev4_calendar_settings (company_id, calendar_provider, timezone, meeting_duration_minutes)
SELECT 1, 'google', 'America/Sao_Paulo', 45
WHERE NOT EXISTS (SELECT 1 FROM corev4_calendar_settings WHERE company_id = 1);

-- ============================================================================
-- PARTE 8: ATUALIZAR REGISTROS EXISTENTES
-- ============================================================================
UPDATE corev4_chats SET conversation_state = 'normal' WHERE conversation_state IS NULL;

-- ============================================================================
-- VERIFICACAO FINAL
-- ============================================================================
SELECT 'MIGRACAO COMPLETA!' AS status,
       (SELECT COUNT(*) FROM corev4_calendar_settings) AS calendar_settings,
       (SELECT COUNT(*) FROM corev4_pending_slot_offers) AS pending_offers,
       (SELECT COUNT(*) FROM corev4_scheduled_meetings) AS scheduled_meetings,
       (SELECT COUNT(*) FROM corev4_chats WHERE conversation_state IS NOT NULL) AS chats_com_state;
