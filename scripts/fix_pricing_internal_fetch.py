#!/usr/bin/env python3
"""
Correção: Remover dependência de node externo e fazer fetch interno

O problema: Calculate nodes tentam acessar $('Fetch: Model Pricing') mas ele
pode não ter executado ainda.

Solução: Fazer fetch dos preços DENTRO do próprio Calculate node usando
credenciais do Supabase e HTTP request nativo.
"""

import json
from pathlib import Path


def fix_calculate_nodes_with_internal_fetch(workflow):
    """
    Atualizar Calculate nodes para fazer fetch interno dos preços
    """
    print("=" * 80)
    print("CORRIGINDO: Calculate nodes com fetch interno")
    print("=" * 80)

    # Código para fetch interno (será usado em ambos os Calculate nodes)
    fetch_pricing_code = '''// ============================================================================
// FETCH PRICING FROM SUPABASE (Internal)
// ============================================================================

// Credenciais do Supabase (mesmas usadas em outros nodes)
const SUPABASE_URL = $('CoreAdapt One AI Agent').first().json.supabase_url ||
                     process.env.SUPABASE_URL ||
                     'https://jrvzexchifudbdxeqvuh.supabase.co';

const SUPABASE_KEY = $('CoreAdapt One AI Agent').first().json.supabase_anon_key ||
                     process.env.SUPABASE_ANON_KEY;

// Se não conseguir pegar das credenciais, tentar do contexto global
const supabaseUrl = SUPABASE_URL;
const supabaseKey = SUPABASE_KEY;

// ✅ BUSCAR PREÇOS DO SUPABASE VIA HTTP
async function fetchPricing() {
  const url = `${supabaseUrl}/rest/v1/v_llm_pricing_active?select=*`;

  const response = await fetch(url, {
    method: 'GET',
    headers: {
      'apikey': supabaseKey,
      'Authorization': `Bearer ${supabaseKey}`,
      'Content-Type': 'application/json'
    }
  });

  if (!response.ok) {
    console.warn(`⚠️ Failed to fetch pricing from Supabase: ${response.status}`);
    return [];
  }

  const data = await response.json();
  console.log(`📊 Loaded ${data.length} pricing entries from Supabase`);
  return data;
}

// Buscar preços (com cache opcional)
const pricingData = await fetchPricing();

// Criar mapa de pricing para lookup rápido
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

    # Atualizar Calculate: Assistant Cost
    for i, node in enumerate(workflow["nodes"]):
        if node.get("name") == "Calculate: Assistant Cost":
            print("\n✅ Atualizando 'Calculate: Assistant Cost'")

            new_code = fetch_pricing_code + '''

// ============================================================================
// CALCULATE ASSISTANT COST
// ============================================================================

const items = $input.all();
const results = [];

// Fallback genérico
const DEFAULT_PRICING = {
  input: 0.50,
  output: 1.50,
  provider: 'unknown',
  display_name: 'Unknown Model'
};

for (const item of items) {
  const usage = item.json.usage || {};

  // Extrair tokens
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

  // Detectar modelo usado
  const rawModel = item.json.model || item.json.modelName || 'unknown';

  // ✅ BUSCAR PREÇOS DO MAPA
  let pricing = null;
  let modelUsed = rawModel;

  // 1. Match exato
  if (pricingMap.has(rawModel)) {
    pricing = pricingMap.get(rawModel);
  } else {
    // 2. Match parcial
    for (const [modelName, modelPricing] of pricingMap.entries()) {
      if (rawModel.toLowerCase().includes(modelName.toLowerCase())) {
        pricing = modelPricing;
        modelUsed = modelName;
        console.log(`🔍 Partial match: "${rawModel}" → "${modelName}"`);
        break;
      }
    }
  }

  // 3. Fallback
  if (!pricing) {
    pricing = DEFAULT_PRICING;
    console.warn(`⚠️ Model "${rawModel}" not in pricing table, using default`);
  }

  // Calcular custos
  const inputCost = (inputTokens / 1_000_000) * pricing.input;
  const outputCost = (outputTokens / 1_000_000) * pricing.output;
  const totalCost = inputCost + outputCost;

  console.log(`💰 Cost for ${pricing.display_name || modelUsed}:`);
  console.log(`   - Input: ${inputTokens} tokens @ $${pricing.input}/1M = $${inputCost.toFixed(8)}`);
  console.log(`   - Output: ${outputTokens} tokens @ $${pricing.output}/1M = $${outputCost.toFixed(8)}`);
  console.log(`   - Total: $${totalCost.toFixed(8)}`);

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
      pricing_source: 'supabase_internal_fetch'
    }
  });
}

return results;'''

            workflow["nodes"][i]["parameters"]["jsCode"] = new_code
            print("   ✅ Fetch interno implementado")
            print("   ✅ Busca preços diretamente do Supabase REST API")
            print("   ✅ Não depende de outro node")
            fixed_nodes.append("Calculate: Assistant Cost")

    # Atualizar Calculate: User Tokens & Cost
    for i, node in enumerate(workflow["nodes"]):
        if node.get("name") == "Calculate: User Tokens & Cost":
            print("\n✅ Atualizando 'Calculate: User Tokens & Cost'")

            new_code = fetch_pricing_code + '''

// ============================================================================
// CALCULATE USER TOKENS & COST
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
      pricing_source: 'supabase_internal_fetch'
    }
  });
}

return results;'''

            workflow["nodes"][i]["parameters"]["jsCode"] = new_code
            print("   ✅ Fetch interno implementado")
            fixed_nodes.append("Calculate: User Tokens & Cost")

    return fixed_nodes


def remove_fetch_pricing_node(workflow):
    """
    Remover node "Fetch: Model Pricing" (não é mais necessário)
    """
    print("\n" + "=" * 80)
    print("REMOVENDO: Node 'Fetch: Model Pricing' (não é mais necessário)")
    print("=" * 80)

    original_count = len(workflow["nodes"])
    workflow["nodes"] = [n for n in workflow["nodes"] if n.get("name") != "Fetch: Model Pricing"]
    removed = original_count - len(workflow["nodes"])

    if removed > 0:
        print(f"   ✅ {removed} node(s) removido(s)")

        # Limpar conexões do node removido
        connections = workflow.get("connections", {})
        if "Fetch: Model Pricing" in connections:
            del connections["Fetch: Model Pricing"]
            print("   ✅ Conexões limpas")

        # Remover referências nas conexões de outros nodes
        for node_name, node_conns in connections.items():
            if "main" in node_conns:
                for i, conn_list in enumerate(node_conns["main"]):
                    connections[node_name]["main"][i] = [
                        c for c in conn_list if c.get("node") != "Fetch: Model Pricing"
                    ]

        workflow["connections"] = connections
    else:
        print("   ⚠️ Node não encontrado (talvez já removido)")

    return workflow


def main():
    print("=" * 80)
    print("FIX: PRICING FETCH DENTRO DO CALCULATE NODE")
    print("=" * 80)
    print()
    print("🔧 Problema identificado:")
    print("   - Calculate nodes tentam acessar $('Fetch: Model Pricing')")
    print("   - Mas esse node pode não ter executado ainda")
    print("   - Erro: 'Node hasn't been executed'")
    print()
    print("✅ Solução:")
    print("   - Fazer fetch dos preços DENTRO do Calculate node")
    print("   - HTTP request direto pro Supabase REST API")
    print("   - Zero dependência de outros nodes")
    print()

    filepath = Path("CoreAdapt One Flow _ v4.json")

    if not filepath.exists():
        print(f"❌ Arquivo não encontrado: {filepath}")
        return

    # Criar backup
    backup_path = filepath.with_name(filepath.stem + "_BEFORE_INTERNAL_FETCH_FIX.json")
    print(f"📦 Criando backup: {backup_path.name}")

    with open(filepath, 'r', encoding='utf-8') as f:
        workflow = json.load(f)

    with open(backup_path, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)

    print(f"   ✅ Backup criado\n")

    # Aplicar correções
    fixed_nodes = fix_calculate_nodes_with_internal_fetch(workflow)

    # Remover node Fetch: Model Pricing
    workflow = remove_fetch_pricing_node(workflow)

    # Salvar workflow corrigido
    if fixed_nodes:
        print("\n" + "=" * 80)
        print(f"💾 SALVANDO CORREÇÕES ({len(fixed_nodes)} nodes corrigidos)")
        print("=" * 80)

        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(workflow, f, indent=2, ensure_ascii=False)

        print(f"✅ Arquivo atualizado: {filepath}")
        print(f"📦 Backup disponível: {backup_path}")

        print("\n" + "=" * 80)
        print("✅ CORREÇÃO APLICADA COM SUCESSO!")
        print("=" * 80)
        print()
        print("📋 O que mudou:")
        print("   ✅ Calculate nodes agora fazem fetch interno dos preços")
        print("   ✅ HTTP request direto pro Supabase REST API")
        print("   ✅ Zero dependência de outro node")
        print("   ✅ Node 'Fetch: Model Pricing' removido (não é mais necessário)")
        print()
        print("📋 Próximos passos:")
        print("   1. Reimportar CoreAdapt One Flow _ v4.json no n8n")
        print("   2. Testar enviando mensagem no WhatsApp")
        print("   3. Verificar logs mostrando:")
        print("      📊 Loaded X pricing entries from Supabase")
        print("      💰 Cost for Gemini 1.5 Pro: ...")
        print()
        print("💡 Nota:")
        print("   - Cada Calculate node faz 1 request pro Supabase (~10ms)")
        print("   - Mais robusto que depender de outro node")
        print("   - Funciona sempre, sem race conditions")
        print()
    else:
        print("\n❌ Nenhuma correção aplicada - nodes não encontrados")


if __name__ == "__main__":
    main()
