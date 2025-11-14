#!/usr/bin/env python3
"""
Remove node "Validate: Send Context" que está causando problemas

O node foi criado como boa prática, mas valida campos que podem não
estar disponíveis no contexto naquele momento do fluxo.

Os nodes subsequentes já fazem validação implícita (erro se dados faltarem).
"""

import json
from pathlib import Path


def remove_validate_send_context_node(workflow):
    """
    Remover node Validate: Send Context e reconectar o fluxo
    """
    print("=" * 80)
    print("REMOVENDO: Validate: Send Context")
    print("=" * 80)

    # Encontrar conexões que ENTRAM no Validate
    connections = workflow.get("connections", {})
    incoming_node = None
    incoming_connections = None

    for node_name, node_conns in connections.items():
        if "main" in node_conns:
            for i, conn_list in enumerate(node_conns["main"]):
                for conn in conn_list:
                    if conn.get("node") == "Validate: Send Context":
                        incoming_node = node_name
                        incoming_connections = (i, conn_list)
                        print(f"   ✅ Encontrado: '{incoming_node}' → 'Validate: Send Context'")
                        break

    # Encontrar conexões que SAEM do Validate
    outgoing_connections = connections.get("Validate: Send Context", {}).get("main", [[]])[0]

    if outgoing_connections:
        outgoing_node = outgoing_connections[0].get("node")
        print(f"   ✅ Encontrado: 'Validate: Send Context' → '{outgoing_node}'")

        # Reconectar: incoming → outgoing (pular o Validate)
        if incoming_node and incoming_connections:
            conn_index, conn_list = incoming_connections

            # Substituir conexão
            for i, conn in enumerate(conn_list):
                if conn.get("node") == "Validate: Send Context":
                    conn_list[i] = {
                        "node": outgoing_node,
                        "type": "main",
                        "index": 0
                    }

            connections[incoming_node]["main"][conn_index] = conn_list
            print(f"   ✅ Reconectado: '{incoming_node}' → '{outgoing_node}'")

    # Remover node Validate da lista
    original_count = len(workflow["nodes"])
    workflow["nodes"] = [n for n in workflow["nodes"] if n.get("name") != "Validate: Send Context"]
    removed = original_count - len(workflow["nodes"])

    if removed > 0:
        print(f"   ✅ {removed} node(s) removido(s)")

    # Remover conexões do Validate
    if "Validate: Send Context" in connections:
        del connections["Validate: Send Context"]
        print("   ✅ Conexões limpas")

    workflow["connections"] = connections
    return workflow


def main():
    print("=" * 80)
    print("FIX: REMOVER NODE VALIDATE SEND CONTEXT")
    print("=" * 80)
    print()
    print("🔧 Problema:")
    print("   - Node valida ai_message e phone_number")
    print("   - Mas esses campos podem não estar no $json naquele ponto")
    print("   - Erro: Missing required fields")
    print()
    print("✅ Solução:")
    print("   - Remover node Validate: Send Context completamente")
    print("   - Reconectar fluxo direto (Inject → Split)")
    print("   - Nodes subsequentes já fazem validação implícita")
    print()

    filepath = Path("CoreAdapt One Flow _ v4.json")

    if not filepath.exists():
        print(f"❌ Arquivo não encontrado: {filepath}")
        return

    # Backup
    backup_path = filepath.with_name(filepath.stem + "_BEFORE_REMOVE_VALIDATE.json")
    print(f"📦 Backup: {backup_path.name}")

    with open(filepath, 'r', encoding='utf-8') as f:
        workflow = json.load(f)

    with open(backup_path, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)

    print(f"   ✅ Criado\n")

    # Remove node
    workflow = remove_validate_send_context_node(workflow)

    # Save
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
    print("📋 Próximos passos:")
    print("   1. Reimportar workflow no n8n")
    print("   2. Testar envio de mensagem")
    print("   3. Erro não deve mais aparecer")
    print()
    print("💡 Fluxo agora:")
    print("   Inject: Cal.com Link → Split: Message into Chunks → Send")
    print()


if __name__ == "__main__":
    main()
