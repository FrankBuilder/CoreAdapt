-- ============================================================================
-- MIGRATION: Create corev4_calendar_settings table
-- CoreAdapt v4 | Autonomous Scheduling Feature
-- ============================================================================
-- Esta tabela armazena as configurações de calendário para cada empresa,
-- permitindo agendamento autônomo via API (Google Calendar ou Cal.com).
-- ============================================================================

-- Criar extensão para criptografia se não existir
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- TABELA PRINCIPAL: corev4_calendar_settings
-- ============================================================================
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
    api_credentials_encrypted BYTEA, -- Usar pgcrypto para encrypt/decrypt
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

-- ============================================================================
-- ÍNDICES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_calendar_settings_company ON corev4_calendar_settings(company_id);
CREATE INDEX IF NOT EXISTS idx_calendar_settings_provider ON corev4_calendar_settings(calendar_provider);
CREATE INDEX IF NOT EXISTS idx_calendar_settings_active ON corev4_calendar_settings(is_active) WHERE is_active = true;

-- ============================================================================
-- TRIGGER PARA UPDATED_AT
-- ============================================================================
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

-- ============================================================================
-- FUNÇÕES AUXILIARES PARA CRIPTOGRAFIA
-- ============================================================================

-- Função para criptografar credenciais
CREATE OR REPLACE FUNCTION encrypt_calendar_credential(
    p_plaintext TEXT,
    p_encryption_key TEXT DEFAULT 'coreadapt_calendar_key_2025'
) RETURNS BYTEA AS $$
BEGIN
    RETURN pgp_sym_encrypt(p_plaintext, p_encryption_key);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função para descriptografar credenciais
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

-- ============================================================================
-- VIEW PARA ACESSO SEGURO (sem credenciais)
-- ============================================================================
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
    -- Indicadores de credenciais (sem valores)
    CASE WHEN api_credentials_encrypted IS NOT NULL THEN true ELSE false END AS has_api_credentials,
    CASE WHEN cal_com_api_key_encrypted IS NOT NULL THEN true ELSE false END AS has_cal_com_key
FROM corev4_calendar_settings;

-- ============================================================================
-- SEED: Configuração padrão para CoreConnect (company_id = 1)
-- ============================================================================
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
    1, -- CoreConnect
    'google',
    'primary', -- ou 'francisco@coreconnect.ai'
    'America/Sao_Paulo',
    '09:00:00',
    '18:00:00',
    45, -- Mesa de Clareza = 45min
    15,
    15,
    24, -- 24h de antecedência
    14, -- até 14 dias no futuro
    4,  -- máximo 4 reuniões/dia
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
        '2025-12-25'::DATE, -- Natal
        '2025-12-31'::DATE, -- Reveillon
        '2026-01-01'::DATE  -- Ano Novo
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
-- COMENTÁRIOS
-- ============================================================================
COMMENT ON TABLE corev4_calendar_settings IS 'Configurações de calendário para agendamento autônomo por empresa';
COMMENT ON COLUMN corev4_calendar_settings.calendar_provider IS 'Provedor de calendário: google, cal_com, outlook';
COMMENT ON COLUMN corev4_calendar_settings.preferred_time_slots IS 'Slots de horário preferidos com prioridade para scoring';
COMMENT ON COLUMN corev4_calendar_settings.preferred_weekdays IS 'Score de preferência por dia da semana (maior = melhor)';
COMMENT ON COLUMN corev4_calendar_settings.api_credentials_encrypted IS 'Credenciais da API criptografadas com pgcrypto';
COMMENT ON COLUMN corev4_calendar_settings.slots_to_offer IS 'Quantidade de horários a oferecer ao lead (2-5)';

-- ============================================================================
-- VERIFICAÇÃO
-- ============================================================================
SELECT
    'corev4_calendar_settings criada com sucesso!' AS status,
    COUNT(*) AS registros_seed
FROM corev4_calendar_settings;
