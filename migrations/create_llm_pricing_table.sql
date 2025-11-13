-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Migration: Create llm_pricing table for dynamic model pricing
-- Purpose: Centralize LLM pricing to avoid hardcoded values in workflows
-- Date: 2025-11-13
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- ============================================================================
-- TABLE: llm_pricing
-- ============================================================================
-- Stores pricing information for different LLM models
-- This allows updating prices without modifying workflows

CREATE TABLE IF NOT EXISTS llm_pricing (
  -- Primary identifier (model name as used in API responses)
  model_name TEXT PRIMARY KEY,

  -- Pricing per 1 million tokens (USD)
  input_cost_per_1m DECIMAL(10,6) NOT NULL,
  output_cost_per_1m DECIMAL(10,6) NOT NULL,

  -- Provider information
  provider TEXT NOT NULL CHECK (provider IN ('google', 'openai', 'anthropic', 'other')),

  -- Model metadata
  display_name TEXT,
  is_active BOOLEAN DEFAULT TRUE,

  -- Audit fields
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Optional: Price history tracking
  valid_from TIMESTAMPTZ DEFAULT NOW(),
  valid_until TIMESTAMPTZ DEFAULT NULL,

  -- Notes for price changes
  notes TEXT
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Fast lookup by model name (already indexed via PRIMARY KEY)
-- But add index for active models only
CREATE INDEX IF NOT EXISTS idx_llm_pricing_active
  ON llm_pricing(model_name)
  WHERE is_active = TRUE;

-- Index for querying by provider
CREATE INDEX IF NOT EXISTS idx_llm_pricing_provider
  ON llm_pricing(provider);

-- Index for current valid prices
CREATE INDEX IF NOT EXISTS idx_llm_pricing_valid
  ON llm_pricing(valid_from, valid_until)
  WHERE is_active = TRUE;

-- ============================================================================
-- TRIGGER: Auto-update updated_at
-- ============================================================================

CREATE OR REPLACE FUNCTION update_llm_pricing_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_llm_pricing_updated_at
  BEFORE UPDATE ON llm_pricing
  FOR EACH ROW
  EXECUTE FUNCTION update_llm_pricing_updated_at();

-- ============================================================================
-- SEED DATA: Current pricing (as of Nov 2025)
-- ============================================================================

INSERT INTO llm_pricing (
  model_name,
  input_cost_per_1m,
  output_cost_per_1m,
  provider,
  display_name,
  notes
) VALUES
  -- ========================================
  -- GOOGLE GEMINI
  -- ========================================
  (
    'gemini-1.5-pro',
    1.25,
    5.00,
    'google',
    'Gemini 1.5 Pro',
    'Google flagship multimodal model with 1M token context'
  ),
  (
    'gemini-1.5-pro-latest',
    1.25,
    5.00,
    'google',
    'Gemini 1.5 Pro (Latest)',
    'Auto-updated to latest Pro version'
  ),
  (
    'gemini-1.5-flash',
    0.075,
    0.30,
    'google',
    'Gemini 1.5 Flash',
    'Fast, cost-effective model for high-volume tasks'
  ),
  (
    'gemini-1.5-flash-latest',
    0.075,
    0.30,
    'google',
    'Gemini 1.5 Flash (Latest)',
    'Auto-updated to latest Flash version'
  ),
  (
    'gemini-pro',
    0.50,
    1.50,
    'google',
    'Gemini Pro',
    'Legacy Gemini Pro model'
  ),

  -- ========================================
  -- OPENAI GPT
  -- ========================================
  (
    'gpt-4o',
    2.50,
    10.00,
    'openai',
    'GPT-4o',
    'OpenAI flagship omni-modal model'
  ),
  (
    'gpt-4o-mini',
    0.150,
    0.600,
    'openai',
    'GPT-4o Mini',
    'Affordable small model from GPT-4o family'
  ),
  (
    'gpt-4-turbo',
    10.00,
    30.00,
    'openai',
    'GPT-4 Turbo',
    'Latest GPT-4 with vision, 128k context'
  ),
  (
    'gpt-4',
    30.00,
    60.00,
    'openai',
    'GPT-4',
    'Original GPT-4, 8k context'
  ),
  (
    'gpt-3.5-turbo',
    0.50,
    1.50,
    'openai',
    'GPT-3.5 Turbo',
    'Fast, affordable model for simple tasks'
  ),

  -- ========================================
  -- ANTHROPIC CLAUDE
  -- ========================================
  (
    'claude-3-5-sonnet-20241022',
    3.00,
    15.00,
    'anthropic',
    'Claude 3.5 Sonnet',
    'Latest Claude 3.5 Sonnet with improved coding'
  ),
  (
    'claude-3-opus-20240229',
    15.00,
    75.00,
    'anthropic',
    'Claude 3 Opus',
    'Most capable Claude model'
  ),
  (
    'claude-3-sonnet-20240229',
    3.00,
    15.00,
    'anthropic',
    'Claude 3 Sonnet',
    'Balanced performance and cost'
  ),
  (
    'claude-3-haiku-20240307',
    0.25,
    1.25,
    'anthropic',
    'Claude 3 Haiku',
    'Fastest Claude model'
  )
ON CONFLICT (model_name) DO UPDATE SET
  input_cost_per_1m = EXCLUDED.input_cost_per_1m,
  output_cost_per_1m = EXCLUDED.output_cost_per_1m,
  display_name = EXCLUDED.display_name,
  notes = EXCLUDED.notes,
  updated_at = NOW();

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE llm_pricing IS 'Centralized pricing for LLM models used in workflows';
COMMENT ON COLUMN llm_pricing.model_name IS 'Model identifier as returned by API (e.g., gemini-1.5-pro)';
COMMENT ON COLUMN llm_pricing.input_cost_per_1m IS 'Cost per 1 million input tokens in USD';
COMMENT ON COLUMN llm_pricing.output_cost_per_1m IS 'Cost per 1 million output tokens in USD';
COMMENT ON COLUMN llm_pricing.valid_from IS 'Price valid from this date (for historical tracking)';
COMMENT ON COLUMN llm_pricing.valid_until IS 'Price valid until this date (NULL = current price)';

-- ============================================================================
-- VERIFY
-- ============================================================================

SELECT
  model_name,
  display_name,
  provider,
  input_cost_per_1m,
  output_cost_per_1m,
  is_active
FROM llm_pricing
ORDER BY provider, input_cost_per_1m;

-- Expected output: 14 rows (5 Gemini, 5 OpenAI, 4 Claude)

-- ============================================================================
-- HELPER VIEWS (OPTIONAL)
-- ============================================================================

-- View for quick price lookup (what n8n will use)
CREATE OR REPLACE VIEW v_llm_pricing_active AS
SELECT
  model_name,
  input_cost_per_1m,
  output_cost_per_1m,
  provider,
  display_name
FROM llm_pricing
WHERE is_active = TRUE
  AND (valid_until IS NULL OR valid_until > NOW());

COMMENT ON VIEW v_llm_pricing_active IS 'Active LLM prices for current use';

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================

-- Get pricing for a specific model
-- SELECT * FROM v_llm_pricing_active WHERE model_name = 'gemini-1.5-pro';

-- List all active models by provider
-- SELECT provider, model_name, input_cost_per_1m, output_cost_per_1m
-- FROM v_llm_pricing_active
-- ORDER BY provider, input_cost_per_1m;

-- Update price (e.g., Gemini price change)
-- UPDATE llm_pricing
-- SET input_cost_per_1m = 1.50, output_cost_per_1m = 6.00
-- WHERE model_name = 'gemini-1.5-pro';

-- Add new model
-- INSERT INTO llm_pricing (model_name, input_cost_per_1m, output_cost_per_1m, provider, display_name)
-- VALUES ('gpt-5', 5.00, 20.00, 'openai', 'GPT-5');

-- Deactivate old model
-- UPDATE llm_pricing SET is_active = FALSE WHERE model_name = 'gpt-3.5-turbo';
