#!/usr/bin/env python3
"""
Fix token extraction: Add support for response.tokenUsage format

Output do Gemini via AI Agent tem estrutura:
{
  "response": {
    "tokenUsage": {
      "completionTokens": 96,
      "promptTokens": 18484,
      "totalTokens": 18580
    }
  }
}

Os nodes Calculate estavam procurando apenas em item.json.tokenUsage (nível raiz).
Agora adicionamos suporte para item.json.response.tokenUsage também.
"""

import json
from pathlib import Path


def fix_calculate_nodes():
    filepath = Path("CoreAdapt One Flow _ v4.json")

    print("=" * 80)
    print("FIX: Token Extraction - Add response.tokenUsage Support")
    print("=" * 80)
    print()

    with open(filepath, 'r', encoding='utf-8') as f:
        workflow = json.load(f)

    # Backup
    backup_path = filepath.with_name(filepath.stem + "_BEFORE_RESPONSE_FIX.json")
    print(f"📦 Backup: {backup_path.name}")
    with open(backup_path, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)

    nodes_fixed = 0

    for node in workflow['nodes']:
        if node.get('name') in ['Calculate: User Tokens & Cost', 'Calculate: Assistant Cost']:
            print(f"\n🔧 Fixing: {node['name']}")

            code = node['parameters']['jsCode']

            # Encontrar onde está o extraction code
            if 'n8n Gemini format: tokenUsage' in code:
                print("   ✅ Already has tokenUsage extraction")

                # Adicionar suporte para response.tokenUsage ANTES da checagem atual
                new_extraction = '''// Extrair tokens (suporta OpenAI, Gemini API, n8n Gemini, e AI Agent response)
  let inputTokens = 0;
  let outputTokens = 0;
  let totalTokens = 0;

  // 1. AI Agent format: response.tokenUsage (NOVO - MAIS COMUM)
  if (item.json.response && item.json.response.tokenUsage) {
    const tokenUsage = item.json.response.tokenUsage;
    inputTokens = tokenUsage.promptTokens || 0;
    outputTokens = tokenUsage.completionTokens || 0;
    totalTokens = tokenUsage.totalTokens || 0;
    console.log('📊 Detected AI Agent response.tokenUsage format');
  }
  // 2. n8n Gemini format: tokenUsage.promptTokens, completionTokens (nível raiz)
  else if (item.json.tokenUsage) {
    const tokenUsage = item.json.tokenUsage;
    inputTokens = tokenUsage.promptTokens || 0;
    outputTokens = tokenUsage.completionTokens || 0;
    totalTokens = tokenUsage.totalTokens || 0;
    console.log('📊 Detected n8n Gemini tokenUsage format');
  }
  // 3. OpenAI format: usage.promptTokens, completionTokens
  else if (usage.promptTokens || usage.prompt_tokens) {
    inputTokens = usage.promptTokens || usage.prompt_tokens || 0;
    outputTokens = usage.completionTokens || usage.completion_tokens || 0;
    totalTokens = usage.totalTokens || usage.total_tokens || 0;
    console.log('📊 Detected OpenAI usage format');
  }
  // 4. Gemini API direct: usageMetadata.promptTokenCount, candidatesTokenCount
  else if (item.json.usageMetadata) {
    const meta = item.json.usageMetadata;
    inputTokens = meta.promptTokenCount || 0;
    outputTokens = meta.candidatesTokenCount || 0;
    totalTokens = meta.totalTokenCount || 0;
    console.log('📊 Detected Gemini API usageMetadata format');
  }
  // 5. Fallback: try direct properties
  else if (item.json.promptTokens || item.json.promptTokenCount) {
    inputTokens = item.json.promptTokens || item.json.promptTokenCount || 0;
    outputTokens = item.json.completionTokens || item.json.candidatesTokenCount || 0;
    totalTokens = item.json.totalTokens || item.json.totalTokenCount || 0;
    console.log('📊 Detected direct token properties');
  }'''

                # Substituir o bloco antigo
                old_pattern = '''// Extrair tokens (suporta OpenAI, Gemini API, e n8n Gemini)
  let inputTokens = 0;
  let outputTokens = 0;
  let totalTokens = 0;

  // 1. n8n Gemini format: tokenUsage.promptTokens, completionTokens
  if (item.json.tokenUsage) {
    const tokenUsage = item.json.tokenUsage;
    inputTokens = tokenUsage.promptTokens || 0;
    outputTokens = tokenUsage.completionTokens || 0;
    totalTokens = tokenUsage.totalTokens || 0;
    console.log('📊 Detected n8n Gemini tokenUsage format');
  }
  // 2. OpenAI format: usage.promptTokens, completionTokens
  else if (usage.promptTokens || usage.prompt_tokens) {
    inputTokens = usage.promptTokens || usage.prompt_tokens || 0;
    outputTokens = usage.completionTokens || usage.completion_tokens || 0;
    totalTokens = usage.totalTokens || usage.total_tokens || 0;
    console.log('📊 Detected OpenAI usage format');
  }
  // 3. Gemini API direct: usageMetadata.promptTokenCount, candidatesTokenCount
  else if (item.json.usageMetadata) {
    const meta = item.json.usageMetadata;
    inputTokens = meta.promptTokenCount || 0;
    outputTokens = meta.candidatesTokenCount || 0;
    totalTokens = meta.totalTokenCount || 0;
    console.log('📊 Detected Gemini API usageMetadata format');
  }
  // 4. Fallback: try direct properties
  else if (item.json.promptTokens || item.json.promptTokenCount) {
    inputTokens = item.json.promptTokens || item.json.promptTokenCount || 0;
    outputTokens = item.json.completionTokens || item.json.candidatesTokenCount || 0;
    totalTokens = item.json.totalTokens || item.json.totalTokenCount || 0;
    console.log('📊 Detected direct token properties');
  }'''

                if old_pattern in code:
                    code = code.replace(old_pattern, new_extraction)
                    node['parameters']['jsCode'] = code
                    nodes_fixed += 1
                    print(f"   ✅ Added response.tokenUsage support")
                else:
                    print(f"   ⚠️  Pattern not found - may need manual fix")

    if nodes_fixed > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(workflow, f, indent=2, ensure_ascii=False)

        print("\n" + "=" * 80)
        print(f"✅ Fixed {nodes_fixed} nodes")
        print("=" * 80)
        print()
        print("🔍 Token extraction priority:")
        print("   1. response.tokenUsage (AI Agent Gemini) ← NOVO")
        print("   2. tokenUsage (n8n Gemini direct)")
        print("   3. usage (OpenAI)")
        print("   4. usageMetadata (Gemini API)")
        print("   5. Direct properties (fallback)")
        print()
        print("📋 Next steps:")
        print("   1. Reimportar workflow no n8n")
        print("   2. Testar mensagem")
        print("   3. Verificar logs: 'Detected AI Agent response.tokenUsage format'")
        print("   4. Confirmar tokens > 0")
    else:
        print("\n⚠️  No nodes were fixed - check code structure manually")


if __name__ == "__main__":
    fix_calculate_nodes()
