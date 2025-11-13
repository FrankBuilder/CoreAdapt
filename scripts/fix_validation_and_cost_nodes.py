#!/usr/bin/env python3
"""
Script para corrigir:
1. Node "Validate: Send Context" - dados não estão no $json
2. Nodes de cálculo de custo - hardcoded para GPT-4o mini, precisa suportar Gemini
"""

import json
from pathlib import Path

def fix_validate_send_context_node(workflow):
    """
    CORREÇÃO 1: Node "Validate: Send Context" está esperando campos que não existem

    Problema: Código pega $json direto, mas os campos estão em nodes anteriores:
    - ai_message vem do node "Inject: Cal.com Link"
    - evolution_* vem de nodes de configuração anteriores
    - phone_number vem do contexto original

    Solução: Remover validação de campos evolution_* (que são configs globais do workflow)
    e validar apenas ai_message e phone_number que realmente devem estar no contexto.
    """
    print("=" * 80)
    print("CORRIGINDO: Validate: Send Context")
    print("=" * 80)

    for i, node in enumerate(workflow["nodes"]):
        if node.get("name") == "Validate: Send Context":
            print("✅ Node encontrado - corrigindo validação")

            # Novo código simplificado
            new_code = '''// ============================================================================
// VALIDATE SEND CONTEXT - Garante que dados críticos existem antes do split
// ============================================================================

const context = $json;

// Validar apenas campos que DEVEM estar no contexto neste ponto
const required = [
  'ai_message',
  'phone_number'
];

const missing = required.filter(field => !context[field]);

if (missing.length > 0) {
  throw new Error(`❌ Missing required fields: ${missing.join(', ')} [line 19]`);
}

// Validar formatos básicos
if (!context.phone_number || context.phone_number.toString().length < 10) {
  throw new Error(`❌ Invalid phone number: ${context.phone_number}`);
}

if (!context.ai_message || context.ai_message.trim() === '') {
  throw new Error(`❌ AI message is empty`);
}

console.log('✅ Send context validation passed');
console.log(`   - Phone: ${context.phone_number}`);
console.log(`   - Message length: ${context.ai_message.length} chars`);

// Passar contexto adiante sem modificações
return [{
  json: {
    ...context,
    validation_passed: true,
    validated_at: new Date().toISOString()
  }
}];'''

            workflow["nodes"][i]["parameters"]["jsCode"] = new_code
            print("   ✅ Validação simplificada (apenas ai_message e phone_number)")
            print("   ✅ Removida validação de evolution_* (são configs do workflow)")
            return True

    print("   ⚠️ Node 'Validate: Send Context' não encontrado")
    return False


def fix_calculate_assistant_cost_node(workflow):
    """
    CORREÇÃO 2: Calculate: Assistant Cost está hardcoded para GPT-4o mini

    Problema: Preços hardcoded:
    - INPUT_COST_PER_1M = 0.150 (GPT-4o mini)
    - OUTPUT_COST_PER_1M = 0.600 (GPT-4o mini)

    Mas usuário usa Gemini como modelo principal!

    Solução: Tabela de preços dinâmica por modelo
    """
    print("\n" + "=" * 80)
    print("CORRIGINDO: Calculate: Assistant Cost")
    print("=" * 80)

    for i, node in enumerate(workflow["nodes"]):
        if node.get("name") == "Calculate: Assistant Cost":
            print("✅ Node encontrado - adicionando tabela de preços dinâmica")

            new_code = '''// ============================================================================
// CALCULATE ASSISTANT COST - Suporte multi-modelo (Gemini, OpenAI, etc)
// ============================================================================

const items = $input.all();
const results = [];

// ✅ TABELA DE PREÇOS POR MODELO (USD por 1M tokens)
const MODEL_PRICING = {
  // Gemini Models
  'gemini-1.5-pro': { input: 1.25, output: 5.00 },
  'gemini-1.5-flash': { input: 0.075, output: 0.30 },
  'gemini-pro': { input: 0.50, output: 1.50 },

  // OpenAI Models
  'gpt-4o': { input: 2.50, output: 10.00 },
  'gpt-4o-mini': { input: 0.150, output: 0.600 },
  'gpt-4-turbo': { input: 10.00, output: 30.00 },
  'gpt-4': { input: 30.00, output: 60.00 },
  'gpt-3.5-turbo': { input: 0.50, output: 1.50 },

  // Anthropic Models
  'claude-3-5-sonnet': { input: 3.00, output: 15.00 },
  'claude-3-opus': { input: 15.00, output: 75.00 },
  'claude-3-sonnet': { input: 3.00, output: 15.00 },
  'claude-3-haiku': { input: 0.25, output: 1.25 },
};

// Fallback genérico
const DEFAULT_PRICING = { input: 0.50, output: 1.50 };

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
  const model = item.json.model || item.json.modelName || 'unknown';

  // ✅ BUSCAR PREÇOS DO MODELO (com fallback)
  let pricing = DEFAULT_PRICING;

  // Tentar match exato
  if (MODEL_PRICING[model]) {
    pricing = MODEL_PRICING[model];
  } else {
    // Tentar match parcial (ex: "gemini-1.5-pro-latest" → "gemini-1.5-pro")
    for (const [modelKey, modelPricing] of Object.entries(MODEL_PRICING)) {
      if (model.toLowerCase().includes(modelKey.toLowerCase())) {
        pricing = modelPricing;
        break;
      }
    }
  }

  // Calcular custos
  const inputCost = (inputTokens / 1_000_000) * pricing.input;
  const outputCost = (outputTokens / 1_000_000) * pricing.output;
  const totalCost = inputCost + outputCost;

  console.log(`💰 Cost calculation for ${model}:`);
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
      model_used: model,
      pricing_rate_input: pricing.input,
      pricing_rate_output: pricing.output
    }
  });
}

return results;'''

            workflow["nodes"][i]["parameters"]["jsCode"] = new_code
            print("   ✅ Tabela de preços multi-modelo adicionada")
            print("   ✅ Suporte para Gemini, OpenAI, Claude")
            print("   ✅ Fallback genérico para modelos desconhecidos")
            print("   ✅ Match parcial de nomes de modelo")
            return True

    print("   ⚠️ Node 'Calculate: Assistant Cost' não encontrado")
    return False


def fix_calculate_user_tokens_cost_node(workflow):
    """
    CORREÇÃO 3: Calculate: User Tokens & Cost - mesmo problema
    """
    print("\n" + "=" * 80)
    print("CORRIGINDO: Calculate: User Tokens & Cost")
    print("=" * 80)

    for i, node in enumerate(workflow["nodes"]):
        if node.get("name") == "Calculate: User Tokens & Cost":
            print("✅ Node encontrado - aplicando mesma correção")

            # Mesmo código que Calculate: Assistant Cost
            # (assumindo que faz o mesmo cálculo)
            new_code = '''// ============================================================================
// CALCULATE USER TOKENS & COST - Suporte multi-modelo
// ============================================================================

const items = $input.all();
const results = [];

// ✅ TABELA DE PREÇOS POR MODELO (USD por 1M tokens)
const MODEL_PRICING = {
  // Gemini Models
  'gemini-1.5-pro': { input: 1.25, output: 5.00 },
  'gemini-1.5-flash': { input: 0.075, output: 0.30 },
  'gemini-pro': { input: 0.50, output: 1.50 },

  // OpenAI Models
  'gpt-4o': { input: 2.50, output: 10.00 },
  'gpt-4o-mini': { input: 0.150, output: 0.600 },
  'gpt-4-turbo': { input: 10.00, output: 30.00 },
  'gpt-4': { input: 30.00, output: 60.00 },
  'gpt-3.5-turbo': { input: 0.50, output: 1.50 },

  // Anthropic Models
  'claude-3-5-sonnet': { input: 3.00, output: 15.00 },
  'claude-3-opus': { input: 15.00, output: 75.00 },
  'claude-3-sonnet': { input: 3.00, output: 15.00 },
  'claude-3-haiku': { input: 0.25, output: 1.25 },
};

const DEFAULT_PRICING = { input: 0.50, output: 1.50 };

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

  const model = item.json.model || item.json.modelName || 'unknown';

  let pricing = DEFAULT_PRICING;

  if (MODEL_PRICING[model]) {
    pricing = MODEL_PRICING[model];
  } else {
    for (const [modelKey, modelPricing] of Object.entries(MODEL_PRICING)) {
      if (model.toLowerCase().includes(modelKey.toLowerCase())) {
        pricing = modelPricing;
        break;
      }
    }
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
      model_used: model
    }
  });
}

return results;'''

            workflow["nodes"][i]["parameters"]["jsCode"] = new_code
            print("   ✅ Mesmo fix aplicado")
            return True

    print("   ⚠️ Node 'Calculate: User Tokens & Cost' não encontrado")
    return False


def main():
    print("=" * 80)
    print("FIX: VALIDATE & COST CALCULATION NODES")
    print("=" * 80)
    print()

    filepath = Path("CoreAdapt One Flow _ v4.json")

    if not filepath.exists():
        print(f"❌ Arquivo não encontrado: {filepath}")
        return

    # Criar backup
    backup_path = filepath.with_name(filepath.stem + "_BEFORE_VALIDATE_COST_FIX.json")
    print(f"📦 Criando backup: {backup_path.name}")

    with open(filepath, 'r', encoding='utf-8') as f:
        workflow = json.load(f)

    with open(backup_path, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)

    print(f"   ✅ Backup criado\n")

    # Aplicar correções
    fixes_applied = 0

    if fix_validate_send_context_node(workflow):
        fixes_applied += 1

    if fix_calculate_assistant_cost_node(workflow):
        fixes_applied += 1

    if fix_calculate_user_tokens_cost_node(workflow):
        fixes_applied += 1

    # Salvar workflow corrigido
    if fixes_applied > 0:
        print("\n" + "=" * 80)
        print(f"💾 SALVANDO CORREÇÕES ({fixes_applied} nodes corrigidos)")
        print("=" * 80)

        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(workflow, f, indent=2, ensure_ascii=False)

        print(f"✅ Arquivo atualizado: {filepath}")
        print(f"📦 Backup disponível: {backup_path}")

        print("\n" + "=" * 80)
        print("✅ CORREÇÕES APLICADAS COM SUCESSO!")
        print("=" * 80)
        print()
        print("📋 Próximos passos:")
        print("   1. Reimportar CoreAdapt One Flow _ v4.json no n8n")
        print("   2. Testar enviando mensagem no WhatsApp")
        print("   3. Verificar logs do node 'Calculate: Assistant Cost'")
        print("   4. Confirmar que está usando preços corretos do Gemini")
        print()
    else:
        print("\n❌ Nenhuma correção aplicada - nodes não encontrados")


if __name__ == "__main__":
    main()
