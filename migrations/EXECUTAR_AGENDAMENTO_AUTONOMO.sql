-- ============================================================================
-- MIGRAÇÕES PARA AGENDAMENTO AUTÔNOMO - CoreAdapt v4
-- Execute este arquivo completo no Supabase SQL Editor
-- Data: 2026-01-05
-- ============================================================================

-- ============================================================================
-- PARTE 1: TABELA corev4_calendar_settings
-- Configurações de calendário para cada empresa
-- ============================================================================

-- Criar extensão para criptografia se não existir
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Tabela principal
CREATE TABLE IF NOT EXISTS corev4_calendar_settings (
    id SERIAL PRIMARY KEY,
    company_id INTEGER UNIQUE NOT NULL REFERENCES corev4_companies(id) ON DELETE CASCADE,

    -- Provedor de calendário
    calendar_provider TEXT NOT NULL DEFAULT 'google' CHECK (calendar_provider IN ('google', 'cal_com', 'outlook')),
    calendar_id TEXT, -- ID do calendário (ex: 'primary' ou email do Google Calendar)

    -- Configurações de timezone
    timezone TEXT NOT NULL DEFAULT 'America/Sao_Paulo',

    -- Horário comercial
    business_hours_start TIME NOT NULL DEFAULT '09:00:00',
    business_hours_end TIME NOT NULL DEFAULT '18:00:00',

    -- Configurações de reunião
    meeting_duration_minutes INTEGER NOT NULL DEFAULT 45 CHECK (meeting_duration_minutes > 0 AND meeting_duration_minutes <= 240),
    buffer_before_minutes INTEGER NOT NULL DEFAULT 15 CHECK (buffer_before_minutes >= 0),
    buffer_after_minutes INTEGER NOT NULL DEFAULT 15 CHECK (buffer_after_minutes >= 0),

    -- Restrições de agendamento
    min_notice_hours INTEGER NOT NULL DEFAULT 24 CHECK (min_notice_hours >= 0),
    max_days_ahead INTEGER NOT NULL DEFAULT 14 CHECK (max_days_ahead > 0 AND max_days_ahead <= 90),
    max_meetings_per_day INTEGER NOT NULL DEFAULT 4 CHECK (max_meetings_per_day > 0),

    -- Dias da semana permitidos (array de nomes)
    allowed_weekdays TEXT[] NOT NULL DEFAULT ARRAY['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],

    -- Preferências de horário para scoring
    preferred_time_slots JSONB DEFAULT '[
        {"start": "10:00", "end": "12:00", "priority": "high", "label": "Manhã produtiva"},
        {"start": "14:00", "end": "16:00", "priority": "medium", "label": "Tarde cedo"},
        {"start": "09:00", "end": "10:00", "priority": "low", "label": "Início do dia"},
        {"start": "16:00", "end": "18:00", "priority": "low", "label": "Final do dia"}
    ]'::JSONB,

    -- Dias da semana preferidos para scoring
    preferred_weekdays JSONB DEFAULT '{
        "monday": 2,
        "tuesday": 3,
        "wednesday": 3,
        "thursday": 3,
        "friday": 1
    }'::JSONB,

    -- Datas excluídas (feriados, férias, etc.)
    excluded_dates DATE[] DEFAULT ARRAY[]::DATE[],

    -- Credenciais da API (criptografadas)
    api_credentials_encrypted BYTEA,
    api_refresh_token_encrypted BYTEA,
    api_token_expires_at TIMESTAMPTZ,

    -- Cal.com específico (se provider = 'cal_com')
    cal_com_api_key_encrypted BYTEA,
    cal_com_event_type_id TEXT,
    cal_com_username TEXT,

    -- Configurações de oferta de horários
    slots_to_offer INTEGER NOT NULL DEFAULT 3 CHECK (slots_to_offer >= 2 AND slots_to_offer <= 5),
    offer_expiration_hours INTEGER NOT NULL DEFAULT 24 CHECK (offer_expiration_hours > 0),

    -- Mensagens customizadas
    slot_offer_template TEXT DEFAULT 'Legal! Deixa eu ver a agenda do Francisco...

Temos essas opções nos próximos dias:
{slots}

Qual funciona melhor pra você? (responde 1, 2 ou 3)',

    booking_confirmation_template TEXT DEFAULT '✅ Perfeito! Sua Mesa de Clareza está confirmada:

📅 {date}
⏰ {time}
🔗 Link: {meeting_url}

Te mando lembretes 24h e 1h antes.

Até lá! 🚀',

    -- Status e auditoria
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_sync_at TIMESTAMPTZ,
    last_sync_status TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_calendar_settings_company ON corev4_calendar_settings(company_id);
CREATE INDEX IF NOT EXISTS idx_calendar_settings_provider ON corev4_calendar_settings(calendar_provider);
CREATE INDEX IF NOT EXISTS idx_calendar_settings_active ON corev4_calendar_settings(is_active) WHERE is_active = true;

-- Trigger para updated_at
CREATE OR REPLACE FUNCTION update_calendar_settings_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_calendar_settings_updated_at ON corev4_calendar_settings;
CREATE TRIGGER trg_calendar_settings_updated_at
    BEFORE UPDATE ON corev4_calendar_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_calendar_settings_timestamp();

-- Funções de criptografia
CREATE OR REPLACE FUNCTION encrypt_calendar_credential(
    p_plaintext TEXT,
    p_encryption_key TEXT DEFAULT 'coreadapt_calendar_key_2025'
) RETURNS BYTEA AS $$
BEGIN
    RETURN pgp_sym_encrypt(p_plaintext, p_encryption_key);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION decrypt_calendar_credential(
    p_encrypted BYTEA,
    p_encryption_key TEXT DEFAULT 'coreadapt_calendar_key_2025'
) RETURNS TEXT AS $$
BEGIN
    IF p_encrypted IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN pgp_sym_decrypt(p_encrypted, p_encryption_key);
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- View segura (sem credenciais)
CREATE OR REPLACE VIEW v_calendar_settings_safe AS
SELECT
    id,
    company_id,
    calendar_provider,
    calendar_id,
    timezone,
    business_hours_start,
    business_hours_end,
    meeting_duration_minutes,
    buffer_before_minutes,
    buffer_after_minutes,
    min_notice_hours,
    max_days_ahead,
    max_meetings_per_day,
    allowed_weekdays,
    preferred_time_slots,
    preferred_weekdays,
    excluded_dates,
    cal_com_event_type_id,
    cal_com_username,
    slots_to_offer,
    offer_expiration_hours,
    slot_offer_template,
    booking_confirmation_template,
    is_active,
    last_sync_at,
    last_sync_status,
    created_at,
    updated_at,
    CASE WHEN api_credentials_encrypted IS NOT NULL THEN true ELSE false END AS has_api_credentials,
    CASE WHEN cal_com_api_key_encrypted IS NOT NULL THEN true ELSE false END AS has_cal_com_key
FROM corev4_calendar_settings;

-- Seed para CoreConnect (company_id = 1)
INSERT INTO corev4_calendar_settings (
    company_id,
    calendar_provider,
    calendar_id,
    timezone,
    business_hours_start,
    business_hours_end,
    meeting_duration_minutes,
    buffer_before_minutes,
    buffer_after_minutes,
    min_notice_hours,
    max_days_ahead,
    max_meetings_per_day,
    allowed_weekdays,
    preferred_time_slots,
    preferred_weekdays,
    excluded_dates,
    cal_com_event_type_id,
    cal_com_username,
    slots_to_offer,
    offer_expiration_hours,
    is_active
) VALUES (
    1,
    'google',
    'primary',
    'America/Sao_Paulo',
    '09:00:00',
    '18:00:00',
    45,
    15,
    15,
    24,
    14,
    4,
    ARRAY['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
    '[
        {"start": "10:00", "end": "12:00", "priority": "high", "label": "Manhã produtiva"},
        {"start": "14:00", "end": "16:00", "priority": "high", "label": "Início da tarde"},
        {"start": "09:00", "end": "10:00", "priority": "medium", "label": "Primeira hora"},
        {"start": "16:00", "end": "18:00", "priority": "low", "label": "Final do dia"}
    ]'::JSONB,
    '{
        "monday": 2,
        "tuesday": 3,
        "wednesday": 3,
        "thursday": 3,
        "friday": 1
    }'::JSONB,
    ARRAY[
        '2025-12-25'::DATE,
        '2025-12-31'::DATE,
        '2026-01-01'::DATE
    ],
    'mesa-de-clareza-45min',
    'francisco-pasteur-coreadapt',
    3,
    24,
    true
) ON CONFLICT (company_id) DO UPDATE SET
    calendar_provider = EXCLUDED.calendar_provider,
    meeting_duration_minutes = EXCLUDED.meeting_duration_minutes,
    updated_at = NOW();

-- ============================================================================
-- PARTE 2: TABELA corev4_pending_slot_offers
-- Ofertas de horários pendentes para leads
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
    slot_1_label TEXT,
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
    selection_message TEXT,
    selection_confidence DECIMAL(3,2) CHECK (selection_confidence IS NULL OR (selection_confidence >= 0 AND selection_confidence <= 1)),
    selected_at TIMESTAMPTZ,

    -- Status da oferta
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending',
        'selected',
        'confirmed',
        'expired',
        'cancelled',
        'slot_unavailable',
        'needs_confirmation'
    )),

    -- Dados do booking (após confirmação)
    booking_id BIGINT REFERENCES corev4_scheduled_meetings(id) ON DELETE SET NULL,
    booking_created_at TIMESTAMPTZ,

    -- Contexto da oferta
    anum_score_at_offer INTEGER,
    conversation_context TEXT,

    -- Tentativas de parsing
    parsing_attempts INTEGER DEFAULT 0,
    last_parsing_result JSONB,

    -- Motivo de cancelamento/expiração
    cancellation_reason TEXT,

    -- Auditoria
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_pending_slots_contact ON corev4_pending_slot_offers(contact_id);
CREATE INDEX IF NOT EXISTS idx_pending_slots_pending ON corev4_pending_slot_offers(status, expires_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_pending_slots_company ON corev4_pending_slot_offers(company_id);
CREATE INDEX IF NOT EXISTS idx_pending_slots_expiring ON corev4_pending_slot_offers(expires_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_pending_slots_booking ON corev4_pending_slot_offers(booking_id) WHERE booking_id IS NOT NULL;

-- Trigger para updated_at
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

-- Função: Obter oferta pendente de um contato
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

-- Função: Registrar seleção de slot
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

-- Função: Cancelar ofertas anteriores
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

-- Função: Expirar ofertas antigas (rodar via cron)
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

-- View: Ofertas pendentes com detalhes do contato
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
    CASE
        WHEN o.expires_at > NOW()
        THEN EXTRACT(EPOCH FROM (o.expires_at - NOW())) / 3600
        ELSE 0
    END AS hours_until_expiration,
    o.expires_at < NOW() AS is_expired,
    o.selected_slot IS NOT NULL AS has_selection
FROM corev4_pending_slot_offers o
INNER JOIN corev4_contacts c ON o.contact_id = c.id;

-- ============================================================================
-- VERIFICAÇÃO FINAL
-- ============================================================================
SELECT 'MIGRAÇÃO CONCLUÍDA!' AS status;
SELECT 'corev4_calendar_settings' AS tabela, COUNT(*) AS registros FROM corev4_calendar_settings
UNION ALL
SELECT 'corev4_pending_slot_offers' AS tabela, COUNT(*) AS registros FROM corev4_pending_slot_offers;
