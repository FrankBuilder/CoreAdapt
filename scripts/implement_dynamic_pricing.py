#!/usr/bin/env python3
"""
Script para implementar pricing dinâmico usando tabela Supabase

Mudanças:
1. Adicionar node "Fetch: Model Pricing" que busca preços do Supabase
2. Modificar "Calculate: Assistant Cost" para usar preços do fetch
3. Modificar "Calculate: User Tokens & Cost" para usar preços do fetch
4. Atualizar conexões do workflow
"""

import json
from pathlib import Path
import uuid


def create_fetch_model_pricing_node():
    """
    Criar node que busca pricing do Supabase
    """
    print("✅ Criando node 'Fetch: Model Pricing'")

    node = {
        "parameters": {
            "operation": "executeQuery",
            "query": """-- Buscar todos os preços ativos de modelos LLM
SELECT
  model_name,
  input_cost_per_1m,
  output_cost_per_1m,
  provider,
  display_name
FROM v_llm_pricing_active
ORDER BY provider, model_name;""",
            "options": {}
        },
        "id": str(uuid.uuid4()),
        "name": "Fetch: Model Pricing",
        "type": "n8n-nodes-base.supabase",
        "typeVersion": 1,
        "position": [900, 350],  # Posição no canvas
        "credentials": {
            "supabaseApi": {
                "id": "LCC4ysI1Fxd9iDGz",  # Mesma credential que outros nodes Supabase
                "name": "Supabase Core"
            }
        }
    }

    print("   - Busca da view v_llm_pricing_active")
    print("   - Retorna todos os modelos ativos")

    return node


def update_calculate_assistant_cost_node(workflow):
    """
    Atualizar node Calculate: Assistant Cost para usar pricing dinâmico
    """
    print("\n" + "=" * 80)
    print("ATUALIZANDO: Calculate: Assistant Cost")
    print("=" * 80)

    for i, node in enumerate(workflow["nodes"]):
        if node.get("name") == "Calculate: Assistant Cost":
            print("✅ Node encontrado - implementando pricing dinâmico")

            new_code = '''// ============================================================================
// CALCULATE ASSISTANT COST - Pricing Dinâmico do Supabase
// ============================================================================

const items = $input.all();
const results = [];

// ✅ BUSCAR PREÇOS DO SUPABASE (node anterior)
const pricingData = $('Fetch: Model Pricing').all();

// Criar mapa de pricing para lookup rápido
const pricingMap = new Map();
for (const row of pricingData) {
  pricingMap.set(row.json.model_name, {
    input: row.json.input_cost_per_1m,
    output: row.json.output_cost_per_1m,
    provider: row.json.provider,
    display_name: row.json.display_name
  });
}

console.log(`📊 Loaded pricing for ${pricingMap.size} models from Supabase`);

// Fallback genérico se modelo não estiver no banco
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

  // Se só tem total, estimar input/output (60/40)
  if (totalTokens > 0 && inputTokens === 0 && outputTokens === 0) {
    inputTokens = Math.floor(totalTokens * 0.6);
    outputTokens = Math.floor(totalTokens * 0.4);
  }

  if (totalTokens === 0) {
    totalTokens = inputTokens + outputTokens;
  }

  // Detectar modelo usado
  const rawModel = item.json.model || item.json.modelName || 'unknown';

  // ✅ BUSCAR PREÇOS DO MAPA (com fallback para match parcial)
  let pricing = null;
  let modelUsed = rawModel;

  // 1. Tentar match exato
  if (pricingMap.has(rawModel)) {
    pricing = pricingMap.get(rawModel);
  } else {
    // 2. Tentar match parcial (ex: "gemini-1.5-pro-002" → "gemini-1.5-pro")
    for (const [modelName, modelPricing] of pricingMap.entries()) {
      if (rawModel.toLowerCase().includes(modelName.toLowerCase())) {
        pricing = modelPricing;
        modelUsed = modelName;
        console.log(`🔍 Partial match: "${rawModel}" → "${modelName}"`);
        break;
      }
    }
  }

  // 3. Se ainda não achou, usar fallback
  if (!pricing) {
    pricing = DEFAULT_PRICING;
    console.warn(`⚠️ Model "${rawModel}" not found in pricing table, using default`);
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
      pricing_source: 'supabase'
    }
  });
}

return results;'''

            workflow["nodes"][i]["parameters"]["jsCode"] = new_code
            print("   ✅ Pricing dinâmico implementado")
            print("   ✅ Busca preços do node 'Fetch: Model Pricing'")
            print("   ✅ Match parcial de nomes de modelo")
            print("   ✅ Fallback genérico para modelos desconhecidos")
            return True

    print("   ⚠️ Node 'Calculate: Assistant Cost' não encontrado")
    return False


def update_calculate_user_tokens_cost_node(workflow):
    """
    Atualizar node Calculate: User Tokens & Cost para usar pricing dinâmico
    """
    print("\n" + "=" * 80)
    print("ATUALIZANDO: Calculate: User Tokens & Cost")
    print("=" * 80)

    for i, node in enumerate(workflow["nodes"]):
        if node.get("name") == "Calculate: User Tokens & Cost":
            print("✅ Node encontrado - implementando pricing dinâmico")

            new_code = '''// ============================================================================
// CALCULATE USER TOKENS & COST - Pricing Dinâmico do Supabase
// ============================================================================

const items = $input.all();
const results = [];

// ✅ BUSCAR PREÇOS DO SUPABASE
const pricingData = $('Fetch: Model Pricing').all();

const pricingMap = new Map();
for (const row of pricingData) {
  pricingMap.set(row.json.model_name, {
    input: row.json.input_cost_per_1m,
    output: row.json.output_cost_per_1m,
    provider: row.json.provider,
    display_name: row.json.display_name
  });
}

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
      pricing_source: 'supabase'
    }
  });
}

return results;'''

            workflow["nodes"][i]["parameters"]["jsCode"] = new_code
            print("   ✅ Mesmo fix aplicado")
            return True

    print("   ⚠️ Node 'Calculate: User Tokens & Cost' não encontrado")
    return False


def insert_fetch_pricing_node(workflow):
    """
    Inserir node Fetch: Model Pricing no workflow

    Estratégia:
    - Adicionar o node logo após o AI Agent
    - Executar em paralelo (não bloqueia o fluxo principal)
    - Calculate nodes vão buscar dele quando precisarem
    """
    print("\n" + "=" * 80)
    print("INSERINDO NODE NO WORKFLOW")
    print("=" * 80)

    # Criar node
    fetch_node = create_fetch_model_pricing_node()
    workflow["nodes"].append(fetch_node)

    # Atualizar conexões
    # O node Fetch deve executar logo no início do workflow
    # Vamos conectá-lo após "CoreAdapt One AI Agent"
    connections = workflow.get("connections", {})

    if "CoreAdapt One AI Agent" in connections:
        # Adicionar Fetch: Model Pricing às conexões do AI Agent
        # (vai executar em paralelo com o resto do fluxo)

        # Pegar conexões existentes
        ai_agent_connections = connections["CoreAdapt One AI Agent"]["main"][0]

        # Adicionar fetch pricing às conexões
        ai_agent_connections.append({
            "node": "Fetch: Model Pricing",
            "type": "main",
            "index": 0
        })

        print("   ✅ Node conectado após 'CoreAdapt One AI Agent'")
        print("   ✅ Executa em paralelo com o fluxo principal")
    else:
        print("   ⚠️ 'CoreAdapt One AI Agent' não encontrado nas conexões")
        print("   ⚠️ Node adicionado mas sem conexões - conectar manualmente")

    workflow["connections"] = connections
    return workflow


def main():
    print("=" * 80)
    print("IMPLEMENTANDO PRICING DINÂMICO COM SUPABASE")
    print("=" * 80)
    print()
    print("📋 O que será feito:")
    print("   1. Criar tabela llm_pricing no Supabase (migration SQL)")
    print("   2. Adicionar node 'Fetch: Model Pricing' no workflow")
    print("   3. Atualizar 'Calculate: Assistant Cost' para usar pricing dinâmico")
    print("   4. Atualizar 'Calculate: User Tokens & Cost' para usar pricing dinâmico")
    print()

    filepath = Path("CoreAdapt One Flow _ v4.json")

    if not filepath.exists():
        print(f"❌ Arquivo não encontrado: {filepath}")
        return

    # Criar backup
    backup_path = filepath.with_name(filepath.stem + "_BEFORE_DYNAMIC_PRICING.json")
    print(f"📦 Criando backup: {backup_path.name}")

    with open(filepath, 'r', encoding='utf-8') as f:
        workflow = json.load(f)

    with open(backup_path, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)

    print(f"   ✅ Backup criado\n")

    # Aplicar mudanças
    changes = []

    # 1. Inserir node Fetch: Model Pricing
    workflow = insert_fetch_pricing_node(workflow)
    changes.append("fetch_node")

    # 2. Atualizar Calculate: Assistant Cost
    if update_calculate_assistant_cost_node(workflow):
        changes.append("assistant_cost")

    # 3. Atualizar Calculate: User Tokens & Cost
    if update_calculate_user_tokens_cost_node(workflow):
        changes.append("user_cost")

    # Salvar workflow atualizado
    if changes:
        print("\n" + "=" * 80)
        print(f"💾 SALVANDO MUDANÇAS ({len(changes)} alterações)")
        print("=" * 80)

        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(workflow, f, indent=2, ensure_ascii=False)

        print(f"✅ Arquivo atualizado: {filepath}")
        print(f"📦 Backup disponível: {backup_path}")

        print("\n" + "=" * 80)
        print("✅ PRICING DINÂMICO IMPLEMENTADO!")
        print("=" * 80)
        print()
        print("📋 Próximos passos:")
        print()
        print("1. EXECUTAR MIGRATION SQL:")
        print("   psql -h localhost -U postgres -d core \\")
        print("     -f migrations/create_llm_pricing_table.sql")
        print()
        print("2. REIMPORTAR WORKFLOW NO N8N:")
        print("   - CoreAdapt One Flow _ v4.json")
        print()
        print("3. TESTAR:")
        print("   - Enviar mensagem no WhatsApp")
        print("   - Verificar logs do 'Calculate: Assistant Cost'")
        print("   - Confirmar que pricing vem do Supabase")
        print()
        print("4. ATUALIZAR PREÇOS (quando necessário):")
        print("   UPDATE llm_pricing")
        print("   SET input_cost_per_1m = 1.50, output_cost_per_1m = 6.00")
        print("   WHERE model_name = 'gemini-1.5-pro';")
        print()
        print("💡 BENEFÍCIOS:")
        print("   ✅ Zero mudanças no workflow para atualizar preços")
        print("   ✅ Preços centralizados no Supabase")
        print("   ✅ Suporta novos modelos sem tocar no código")
        print("   ✅ Histórico de preços (se usar valid_from/valid_until)")
        print()
    else:
        print("\n❌ Nenhuma mudança aplicada")


if __name__ == "__main__":
    main()
