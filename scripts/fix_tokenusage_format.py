#!/usr/bin/env python3
"""
Fix: Adicionar suporte ao formato tokenUsage do n8n Gemini integration

Gemini via n8n retorna:
- tokenUsage.promptTokens
- tokenUsage.completionTokens
- tokenUsage.totalTokens

(Não é usage.*, nem usageMetadata.*)
"""

import json
from pathlib import Path


def fix_token_extraction_for_n8n_gemini(workflow):
    """
    Adicionar suporte para tokenUsage (n8n Gemini format)
    """
    print("=" * 80)
    print("CORRIGINDO: Suporte a tokenUsage (n8n Gemini)")
    print("=" * 80)

    # Novo código de extração
    new_extraction = '''// Extrair tokens (suporta OpenAI, Gemini API, e n8n Gemini)
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

    fixed = []

    # Calculate: Assistant Cost
    for i, node in enumerate(workflow["nodes"]):
        if node.get("name") == "Calculate: Assistant Cost":
            print("\n✅ Atualizando 'Calculate: Assistant Cost'")

            code = node["parameters"]["jsCode"]

            # Encontrar e substituir a extração de tokens
            # Procurar pelo padrão que começa com "// Extrair tokens"
            if "// Extrair tokens" in code:
                # Encontrar início e fim do bloco de extração
                lines = code.split('\n')
                start_idx = None
                end_idx = None

                for idx, line in enumerate(lines):
                    if '// Extrair tokens' in line:
                        start_idx = idx
                    elif start_idx is not None and 'const rawModel =' in line:
                        end_idx = idx
                        break

                if start_idx and end_idx:
                    # Reconstruir código
                    before = '\n'.join(lines[:start_idx])
                    after = '\n'.join(lines[end_idx:])
                    new_code = before + '\n' + new_extraction + '\n\n' + after

                    workflow["nodes"][i]["parameters"]["jsCode"] = new_code
                    print("   ✅ tokenUsage support adicionado (n8n Gemini + OpenAI + Gemini API)")
                    fixed.append("Assistant Cost")
                else:
                    print("   ⚠️ Não consegui localizar bloco de extração")
            else:
                print("   ⚠️ Código mudou - padrão não encontrado")

    # Calculate: User Tokens & Cost
    for i, node in enumerate(workflow["nodes"]):
        if node.get("name") == "Calculate: User Tokens & Cost":
            print("\n✅ Atualizando 'Calculate: User Tokens & Cost'")

            code = node["parameters"]["jsCode"]

            if "// Extrair tokens" in code:
                lines = code.split('\n')
                start_idx = None
                end_idx = None

                for idx, line in enumerate(lines):
                    if '// Extrair tokens' in line:
                        start_idx = idx
                    elif start_idx is not None and 'const rawModel =' in line:
                        end_idx = idx
                        break

                if start_idx and end_idx:
                    before = '\n'.join(lines[:start_idx])
                    after = '\n'.join(lines[end_idx:])
                    new_code = before + '\n' + new_extraction + '\n\n' + after

                    workflow["nodes"][i]["parameters"]["jsCode"] = new_code
                    print("   ✅ tokenUsage support adicionado")
                    fixed.append("User Cost")
                else:
                    print("   ⚠️ Não consegui localizar bloco de extração")
            else:
                print("   ⚠️ Código mudou - padrão não encontrado")

    return fixed


def main():
    print("=" * 80)
    print("FIX: SUPORTE tokenUsage (n8n Gemini)")
    print("=" * 80)
    print()
    print("Formatos suportados após fix:")
    print("   1. tokenUsage.promptTokens (n8n Gemini) ← NOVO")
    print("   2. usage.promptTokens (OpenAI)")
    print("   3. usageMetadata.promptTokenCount (Gemini API)")
    print("   4. Direct properties (fallback)")
    print()

    filepath = Path("CoreAdapt One Flow _ v4.json")

    if not filepath.exists():
        print(f"❌ Arquivo não encontrado: {filepath}")
        return

    # Backup
    backup_path = filepath.with_name(filepath.stem + "_BEFORE_TOKENUSAGE_FIX.json")
    print(f"📦 Backup: {backup_path.name}")

    with open(filepath, 'r', encoding='utf-8') as f:
        workflow = json.load(f)

    with open(backup_path, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)

    print(f"   ✅ Criado\n")

    # Fix
    fixed = fix_token_extraction_for_n8n_gemini(workflow)

    if fixed:
        print("\n" + "=" * 80)
        print("💾 SALVANDO")
        print("=" * 80)

        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(workflow, f, indent=2, ensure_ascii=False)

        print(f"✅ Salvo: {filepath}")

        print("\n" + "=" * 80)
        print("✅ FIX APLICADO")
        print("=" * 80)
        print()
        print("📋 Próximos passos:")
        print("   1. Reimportar workflow no n8n")
        print("   2. Testar com mensagem")
        print("   3. Logs devem mostrar:")
        print("      📊 Detected n8n Gemini tokenUsage format")
        print("      💰 Gemini 2.5 Flash:")
        print("         Input: 14973 tokens @ $X/1M = $Y")
        print("         Output: 59 tokens @ $Z/1M = $W")
        print()
        print("💡 Exemplo da sua última execução:")
        print("   Input: 14973 tokens")
        print("   Output: 59 tokens")
        print("   Total: 15032 tokens")
        print()
    else:
        print("\n❌ Nenhuma correção aplicada")


if __name__ == "__main__":
    main()
