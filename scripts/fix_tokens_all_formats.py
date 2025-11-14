#!/usr/bin/env python3
"""
TOKENS FIX FINAL - Adiciona suporte para TODOS os formatos possíveis

Formatos suportados (ordem de prioridade):
1. response.tokenUsage (AI Agent Gemini)
2. tokenUsage (n8n Gemini direct)
3. usage (OpenAI)
4. usageMetadata (Gemini API)
5. estimatedTokens (Model: OpenAI Chat node) ← NOVO
6. Direct properties (fallback)
"""

import json
from pathlib import Path


def fix_all_token_formats():
    filepath = Path("CoreAdapt One Flow _ v4.json")

    with open(filepath, 'r', encoding='utf-8') as f:
        workflow = json.load(f)

    for node in workflow['nodes']:
        if node.get('name') in ['Calculate: User Tokens & Cost', 'Calculate: Assistant Cost']:
            code = node['parameters']['jsCode']

            # Nova extração com TODOS os formatos
            new_extraction = '''// Extrair tokens - SUPORTE COMPLETO PARA TODOS OS FORMATOS
  let inputTokens = 0;
  let outputTokens = 0;
  let totalTokens = 0;

  // 1. AI Agent format: response.tokenUsage
  if (item.json.response && item.json.response.tokenUsage) {
    const tokenUsage = item.json.response.tokenUsage;
    inputTokens = tokenUsage.promptTokens || 0;
    outputTokens = tokenUsage.completionTokens || 0;
    totalTokens = tokenUsage.totalTokens || 0;
    console.log('📊 Detected AI Agent response.tokenUsage format');
  }
  // 2. Direct tokenUsage (n8n Gemini)
  else if (item.json.tokenUsage) {
    const tokenUsage = item.json.tokenUsage;
    inputTokens = tokenUsage.promptTokens || 0;
    outputTokens = tokenUsage.completionTokens || 0;
    totalTokens = tokenUsage.totalTokens || 0;
    console.log('📊 Detected n8n Gemini tokenUsage format');
  }
  // 3. OpenAI usage format
  else if (usage.promptTokens || usage.prompt_tokens) {
    inputTokens = usage.promptTokens || usage.prompt_tokens || 0;
    outputTokens = usage.completionTokens || usage.completion_tokens || 0;
    totalTokens = usage.totalTokens || usage.total_tokens || 0;
    console.log('📊 Detected OpenAI usage format');
  }
  // 4. Gemini API usageMetadata
  else if (item.json.usageMetadata) {
    const meta = item.json.usageMetadata;
    inputTokens = meta.promptTokenCount || 0;
    outputTokens = meta.candidatesTokenCount || 0;
    totalTokens = meta.totalTokenCount || 0;
    console.log('📊 Detected Gemini API usageMetadata format');
  }
  // 5. Model: OpenAI Chat node format (estimatedTokens)
  else if (item.json.estimatedTokens) {
    totalTokens = item.json.estimatedTokens || 0;
    // Estimativa: 75% input, 25% output (média conversacional)
    inputTokens = Math.floor(totalTokens * 0.75);
    outputTokens = Math.floor(totalTokens * 0.25);
    console.log('📊 Detected Model node estimatedTokens format (using 75/25 split)');
  }
  // 6. Fallback: direct properties
  else if (item.json.promptTokens || item.json.promptTokenCount) {
    inputTokens = item.json.promptTokens || item.json.promptTokenCount || 0;
    outputTokens = item.json.completionTokens || item.json.candidatesTokenCount || 0;
    totalTokens = item.json.totalTokens || item.json.totalTokenCount || 0;
    console.log('📊 Detected direct token properties');
  }

  // Se ainda zero, logar warning
  if (totalTokens === 0) {
    console.warn('⚠️ No token data found in any known format');
    console.warn('Available keys:', Object.keys(item.json).join(', '));
  }'''

            # Encontrar e substituir bloco de extração
            # Procurar por "let inputTokens = 0;" até próxima linha vazia
            import re
            pattern = r'// Extrair tokens.*?(?=\n\n  const rawModel)'

            if 'Extrair tokens' in code:
                code = re.sub(pattern, new_extraction, code, flags=re.DOTALL)
                node['parameters']['jsCode'] = code
                print(f"✅ Fixed: {node['name']}")

    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)

    print("\n✅ Token extraction fixed - supports ALL formats including estimatedTokens")


if __name__ == "__main__":
    fix_all_token_formats()
