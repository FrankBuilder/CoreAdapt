#!/usr/bin/env python3
"""
Fix: Suportar formato de usage do Gemini E OpenAI

Gemini retorna:
- usageMetadata.promptTokenCount
- usageMetadata.candidatesTokenCount
- usageMetadata.totalTokenCount

OpenAI retorna:
- usage.promptTokens
- usage.completionTokens
- usage.totalTokens
"""

import json
from pathlib import Path


def fix_calculate_nodes_for_gemini(workflow):
    """
    Atualizar Calculate nodes para suportar Gemini + OpenAI
    """
    print("=" * 80)
    print("CORRIGINDO: Suporte a Gemini + OpenAI")
    print("=" * 80)

    # Template de extração multi-provider
    token_extraction = '''// Extrair tokens (suporta OpenAI E Gemini)
  let inputTokens = 0;
  let outputTokens = 0;
  let totalTokens = 0;

  // OpenAI format: usage.promptTokens, usage.completionTokens
  if (usage.promptTokens || usage.prompt_tokens) {
    inputTokens = usage.promptTokens || usage.prompt_tokens || 0;
    outputTokens = usage.completionTokens || usage.completion_tokens || 0;
    totalTokens = usage.totalTokens || usage.total_tokens || 0;
    console.log('📊 Detected OpenAI usage format');
  }
  // Gemini format: usageMetadata.promptTokenCount, candidatesTokenCount
  else if (item.json.usageMetadata) {
    const meta = item.json.usageMetadata;
    inputTokens = meta.promptTokenCount || 0;
    outputTokens = meta.candidatesTokenCount || 0;
    totalTokens = meta.totalTokenCount || 0;
    console.log('📊 Detected Gemini usageMetadata format');
  }
  // Fallback: try direct properties
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

            # Substituir extração de tokens
            old_extraction = '''  const usage = item.json.usage || {};

  let inputTokens = usage.promptTokens || usage.prompt_tokens || 0;
  let outputTokens = usage.completionTokens || usage.completion_tokens || 0;
  let totalTokens = usage.totalTokens || usage.total_tokens || 0;'''

            if old_extraction in code:
                code = code.replace(old_extraction, f'''  const usage = item.json.usage || {{}};

{token_extraction}''')
                workflow["nodes"][i]["parameters"]["jsCode"] = code
                print("   ✅ Suporte multi-provider adicionado (OpenAI + Gemini)")
                fixed.append("Assistant Cost")
            else:
                print("   ⚠️ Padrão não encontrado (código pode ter mudado)")

    # Calculate: User Tokens & Cost
    for i, node in enumerate(workflow["nodes"]):
        if node.get("name") == "Calculate: User Tokens & Cost":
            print("\n✅ Atualizando 'Calculate: User Tokens & Cost'")

            code = node["parameters"]["jsCode"]

            old_extraction = '''  const usage = item.json.usage || {};

  let inputTokens = usage.promptTokens || usage.prompt_tokens || 0;
  let outputTokens = usage.completionTokens || usage.completion_tokens || 0;
  let totalTokens = usage.totalTokens || usage.total_tokens || 0;'''

            if old_extraction in code:
                code = code.replace(old_extraction, f'''  const usage = item.json.usage || {{}};

{token_extraction}''')
                workflow["nodes"][i]["parameters"]["jsCode"] = code
                print("   ✅ Suporte multi-provider adicionado")
                fixed.append("User Cost")
            else:
                print("   ⚠️ Padrão não encontrado")

    return fixed


def main():
    print("=" * 80)
    print("FIX: SUPORTE MULTI-PROVIDER (GEMINI + OPENAI)")
    print("=" * 80)
    print()

    filepath = Path("CoreAdapt One Flow _ v4.json")

    if not filepath.exists():
        print(f"❌ Arquivo não encontrado: {filepath}")
        return

    # Backup
    backup_path = filepath.with_name(filepath.stem + "_BEFORE_GEMINI_FIX.json")
    print(f"📦 Backup: {backup_path.name}")

    with open(filepath, 'r', encoding='utf-8') as f:
        workflow = json.load(f)

    with open(backup_path, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)

    print(f"   ✅ Criado\n")

    # Fix
    fixed = fix_calculate_nodes_for_gemini(workflow)

    if fixed:
        print("\n" + "=" * 80)
        print("💾 SALVANDO")
        print("=" * 80)

        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(workflow, f, indent=2, ensure_ascii=False)

        print(f"✅ Salvo: {filepath}")

        print("\n" + "=" * 80)
        print("✅ CORREÇÃO APLICADA")
        print("=" * 80)
        print()
        print("📋 Agora suporta:")
        print("   ✅ OpenAI: usage.promptTokens, completionTokens")
        print("   ✅ Gemini: usageMetadata.promptTokenCount, candidatesTokenCount")
        print("   ✅ Fallback: propriedades diretas no JSON")
        print()
        print("📋 Próximos passos:")
        print("   1. Reimportar workflow")
        print("   2. Testar com mensagem")
        print("   3. Logs devem mostrar:")
        print("      📊 Detected Gemini usageMetadata format")
        print("      💰 Gemini 1.5 Pro: [tokens e custos]")
        print()
    else:
        print("\n❌ Nenhuma correção aplicada")


if __name__ == "__main__":
    main()
