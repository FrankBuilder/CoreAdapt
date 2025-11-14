#!/usr/bin/env python3
"""
Correção PRAGMÁTICA: Pricing com configuração fácil

O usuário precisa apenas configurar URL e API key do Supabase
no topo do código do Calculate node.
"""

import json
from pathlib import Path


def fix_calculate_nodes_pragmatic(workflow):
    """
    Versão pragmática: usuário configura credenciais no topo do código
    """
    print("=" * 80)
    print("CORRIGINDO: Calculate nodes (versão pragmática)")
    print("=" * 80)

    # Template de fetch (usuário configura URL e KEY)
    fetch_template = '''// ============================================================================
// CONFIGURAÇÃO - ATUALIZE COM SUAS CREDENCIAIS DO SUPABASE
// ============================================================================
// Pegar do Supabase Dashboard → Settings → API
const SUPABASE_URL = 'https://jrvzexchifudbdxeqvuh.supabase.co';  // ← SEU PROJECT URL
const SUPABASE_ANON_KEY = 'SUA_ANON_KEY_AQUI';  // ← SUA ANON KEY

// ============================================================================
// FETCH PRICING FROM SUPABASE
// ============================================================================
async function fetchPricing() {
  try {
    const url = `${SUPABASE_URL}/rest/v1/v_llm_pricing_active?select=*`;

    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'apikey': SUPABASE_ANON_KEY,
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        'Content-Type': 'application/json'
      }
    });

    if (!response.ok) {
      console.warn(`⚠️ Failed to fetch pricing: ${response.status}`);
      return [];
    }

    const data = await response.json();
    console.log(`📊 Loaded ${data.length} pricing entries from Supabase`);
    return data;
  } catch (error) {
    console.error(`❌ Error fetching pricing: ${error.message}`);
    return [];
  }
}

// Buscar preços
const pricingData = await fetchPricing();

// Criar mapa de pricing
const pricingMap = new Map();
for (const row of pricingData) {
  pricingMap.set(row.model_name, {
    input: row.input_cost_per_1m,
    output: row.output_cost_per_1m,
    provider: row.provider,
    display_name: row.display_name
  });
}'''

    fixed_nodes = []

    # Calculate: Assistant Cost
    for i, node in enumerate(workflow["nodes"]):
        if node.get("name") == "Calculate: Assistant Cost":
            print("\n✅ Atualizando 'Calculate: Assistant Cost'")

            new_code = fetch_template + '''

// ============================================================================
// CALCULATE ASSISTANT COST
// ============================================================================

const items = $input.all();
const results = [];

const DEFAULT_PRICING = {
  input: 0.50,
  output: 1.50,
  provider: 'unknown',
  display_name: 'Unknown Model'
};

for (const item of items) {
  const usage = item.json.usage || {};

  let inputTokens = usage.promptTokens || usage.prompt_tokens || 0;
  let outputTokens = usage.completionTokens || usage.completion_tokens || 0;
  let totalTokens = usage.totalTokens || usage.total_tokens || 0;

  if (totalTokens > 0 && inputTokens === 0 && outputTokens === 0) {
    inputTokens = Math.floor(totalTokens * 0.6);
    outputTokens = Math.floor(totalTokens * 0.4);
  }

  if (totalTokens === 0) {
    totalTokens = inputTokens + outputTokens;
  }

  const rawModel = item.json.model || item.json.modelName || 'unknown';

  // Buscar pricing
  let pricing = null;
  let modelUsed = rawModel;

  if (pricingMap.has(rawModel)) {
    pricing = pricingMap.get(rawModel);
  } else {
    // Match parcial
    for (const [modelName, modelPricing] of pricingMap.entries()) {
      if (rawModel.toLowerCase().includes(modelName.toLowerCase())) {
        pricing = modelPricing;
        modelUsed = modelName;
        console.log(`🔍 Partial match: "${rawModel}" → "${modelName}"`);
        break;
      }
    }
  }

  if (!pricing) {
    pricing = DEFAULT_PRICING;
    console.warn(`⚠️ Model "${rawModel}" not in pricing table`);
  }

  const inputCost = (inputTokens / 1_000_000) * pricing.input;
  const outputCost = (outputTokens / 1_000_000) * pricing.output;
  const totalCost = inputCost + outputCost;

  console.log(`💰 ${pricing.display_name || modelUsed}:`);
  console.log(`   Input: ${inputTokens} @ $${pricing.input}/1M = $${inputCost.toFixed(8)}`);
  console.log(`   Output: ${outputTokens} @ $${pricing.output}/1M = $${outputCost.toFixed(8)}`);
  console.log(`   Total: $${totalCost.toFixed(8)}`);

  results.push({
    json: {
      ...item.json,
      tokens_used: totalTokens,
      tokens_input: inputTokens,
      tokens_output: outputTokens,
      cost_usd: parseFloat(totalCost.toFixed(8)),
      cost_input: parseFloat(inputCost.toFixed(8)),
      cost_output: parseFloat(outputCost.toFixed(8)),
      model_used: modelUsed,
      model_display_name: pricing.display_name || modelUsed,
      pricing_provider: pricing.provider,
      pricing_rate_input: pricing.input,
      pricing_rate_output: pricing.output,
      pricing_source: 'supabase_dynamic'
    }
  });
}

return results;'''

            workflow["nodes"][i]["parameters"]["jsCode"] = new_code
            print("   ✅ Código atualizado (precisa configurar SUPABASE_URL e KEY)")
            fixed_nodes.append("Calculate: Assistant Cost")

    # Calculate: User Tokens & Cost
    for i, node in enumerate(workflow["nodes"]):
        if node.get("name") == "Calculate: User Tokens & Cost":
            print("\n✅ Atualizando 'Calculate: User Tokens & Cost'")

            new_code = fetch_template + '''

// ============================================================================
// CALCULATE USER TOKENS & COST
// ============================================================================

const items = $input.all();
const results = [];

const DEFAULT_PRICING = {
  input: 0.50,
  output: 1.50
};

for (const item of items) {
  const usage = item.json.usage || {};

  let inputTokens = usage.promptTokens || usage.prompt_tokens || 0;
  let outputTokens = usage.completionTokens || usage.completion_tokens || 0;
  let totalTokens = usage.totalTokens || usage.total_tokens || 0;

  if (totalTokens > 0 && inputTokens === 0 && outputTokens === 0) {
    inputTokens = Math.floor(totalTokens * 0.6);
    outputTokens = Math.floor(totalTokens * 0.4);
  }

  if (totalTokens === 0) {
    totalTokens = inputTokens + outputTokens;
  }

  const rawModel = item.json.model || item.json.modelName || 'unknown';

  let pricing = null;
  let modelUsed = rawModel;

  if (pricingMap.has(rawModel)) {
    pricing = pricingMap.get(rawModel);
  } else {
    for (const [modelName, modelPricing] of pricingMap.entries()) {
      if (rawModel.toLowerCase().includes(modelName.toLowerCase())) {
        pricing = modelPricing;
        modelUsed = modelName;
        break;
      }
    }
  }

  if (!pricing) {
    pricing = DEFAULT_PRICING;
  }

  const inputCost = (inputTokens / 1_000_000) * pricing.input;
  const outputCost = (outputTokens / 1_000_000) * pricing.output;
  const totalCost = inputCost + outputCost;

  results.push({
    json: {
      ...item.json,
      user_tokens_used: totalTokens,
      user_tokens_input: inputTokens,
      user_tokens_output: outputTokens,
      user_cost_usd: parseFloat(totalCost.toFixed(8)),
      user_cost_input: parseFloat(inputCost.toFixed(8)),
      user_cost_output: parseFloat(outputCost.toFixed(8)),
      model_used: modelUsed,
      pricing_source: 'supabase_dynamic'
    }
  });
}

return results;'''

            workflow["nodes"][i]["parameters"]["jsCode"] = new_code
            print("   ✅ Código atualizado")
            fixed_nodes.append("Calculate: User Tokens & Cost")

    return fixed_nodes


def main():
    print("=" * 80)
    print("FIX: PRICING DINÂMICO (VERSÃO PRAGMÁTICA)")
    print("=" * 80)
    print()

    filepath = Path("CoreAdapt One Flow _ v4.json")

    if not filepath.exists():
        print(f"❌ Arquivo não encontrado: {filepath}")
        return

    # Backup
    backup_path = filepath.with_name(filepath.stem + "_BEFORE_PRAGMATIC_FIX.json")
    print(f"📦 Backup: {backup_path.name}")

    with open(filepath, 'r', encoding='utf-8') as f:
        workflow = json.load(f)

    with open(backup_path, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)

    print(f"   ✅ Criado\n")

    # Fix
    fixed_nodes = fix_calculate_nodes_pragmatic(workflow)

    if fixed_nodes:
        print("\n" + "=" * 80)
        print("💾 SALVANDO")
        print("=" * 80)

        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(workflow, f, indent=2, ensure_ascii=False)

        print(f"✅ Salvo: {filepath}")

        print("\n" + "=" * 80)
        print("🔧 PRÓXIMOS PASSOS")
        print("=" * 80)
        print()
        print("1. PEGAR CREDENCIAIS DO SUPABASE:")
        print("   Dashboard → Settings → API:")
        print("   - Project URL (ex: https://xxx.supabase.co)")
        print("   - anon/public key")
        print()
        print("2. REIMPORTAR WORKFLOW:")
        print("   - CoreAdapt One Flow _ v4.json")
        print()
        print("3. EDITAR NODES NO N8N:")
        print("   a) Abrir node 'Calculate: Assistant Cost'")
        print("      - Linhas 4-5: Atualizar SUPABASE_URL e SUPABASE_ANON_KEY")
        print()
        print("   b) Abrir node 'Calculate: User Tokens & Cost'")
        print("      - Linhas 4-5: Atualizar SUPABASE_URL e SUPABASE_ANON_KEY")
        print()
        print("4. TESTAR:")
        print("   - Enviar mensagem no WhatsApp")
        print("   - Ver logs: 📊 Loaded X pricing entries")
        print()
        print("💡 As credenciais do Supabase são públicas (anon key)")
        print("   A segurança vem do Row Level Security (RLS)")
        print()
    else:
        print("\n❌ Nenhuma correção aplicada")


if __name__ == "__main__":
    main()
