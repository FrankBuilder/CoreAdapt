-- ============================================================================
-- MIGRATION: Adicionar campos faltantes em corev4_prospects
-- Data: 2026-01-05
-- ============================================================================

-- Endereço completo
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS address_street TEXT;
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS address_number TEXT;
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS address_complement TEXT;
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS address_neighborhood TEXT;
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS state TEXT;
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS zipcode TEXT;
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS country TEXT DEFAULT 'BR';

-- Coordenadas (do Google Maps)
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS latitude DECIMAL(10, 8);
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS longitude DECIMAL(11, 8);

-- Redes sociais
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS linkedin_url TEXT;
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS instagram_handle TEXT;
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS facebook_url TEXT;

-- Negócio
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS business_type TEXT;  -- 'dentista', 'advogado', etc
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS business_category TEXT;  -- categoria do Google Maps
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS business_subcategory TEXT;

-- Contato adicional
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS secondary_phone TEXT;
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS whatsapp_validated_at TIMESTAMPTZ;

-- Google Maps específico
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS google_place_id TEXT;
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS google_maps_url TEXT;
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS google_photos_count INTEGER;

-- Enriquecimento
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS enriched_at TIMESTAMPTZ;
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS enrichment_source TEXT;  -- 'scraptio', 'apollo', 'manual'
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS enrichment_data JSONB DEFAULT '{}'::JSONB;

-- Campanha de origem
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS campaign_id BIGINT REFERENCES corev4_outbound_campaigns(id);
ALTER TABLE corev4_prospects ADD COLUMN IF NOT EXISTS list_name TEXT;  -- nome da lista de prospecção

-- Índices para buscas comuns
CREATE INDEX IF NOT EXISTS idx_prospects_city ON corev4_prospects(city);
CREATE INDEX IF NOT EXISTS idx_prospects_state ON corev4_prospects(state);
CREATE INDEX IF NOT EXISTS idx_prospects_business_type ON corev4_prospects(business_type);
CREATE INDEX IF NOT EXISTS idx_prospects_campaign ON corev4_prospects(campaign_id);
CREATE INDEX IF NOT EXISTS idx_prospects_status ON corev4_prospects(status);
CREATE INDEX IF NOT EXISTS idx_prospects_google_place ON corev4_prospects(google_place_id);

-- Comentários
COMMENT ON COLUMN corev4_prospects.business_type IS 'Tipo de negócio: dentista, advogado, restaurante, etc';
COMMENT ON COLUMN corev4_prospects.business_category IS 'Categoria do Google Maps ou LinkedIn';
COMMENT ON COLUMN corev4_prospects.enrichment_data IS 'Dados extras do enriquecimento em JSON';

-- Verificar
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'corev4_prospects'
ORDER BY ordinal_position;
