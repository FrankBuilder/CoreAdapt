#!/usr/bin/env python3
"""
Correções de versões de nodes e conversão de HTTP Requests para Subworkflows.

Correções:
1. Execute Subworkflow → versão 1.2 com formato correto de seleção
2. HTTP Request → versão 4.3
3. Call: Booking Flow → converter para Execute Subworkflow
4. OpenAI nodes → versão 2.1
5. Merge nodes → versão 3.2
"""

import json

print("📦 Carregando One Flow...")
with open('CoreAdapt One Flow _ v4.1_AUTONOMOUS.json', 'r', encoding='utf-8') as f:
    one_flow = json.load(f)

changes_made = []

for i, node in enumerate(one_flow['nodes']):
    node_type = node.get('type', '')
    node_name = node.get('name', '')

    # 1. Atualizar Execute Subworkflow para versão 1.2
    if node_type == 'n8n-nodes-base.executeWorkflow':
        if node['typeVersion'] != 1.2:
            one_flow['nodes'][i]['typeVersion'] = 1.2
            changes_made.append(f"✅ {node_name}: executeWorkflow → v1.2")

    # 2. Atualizar HTTP Request para versão 4.3
    if node_type == 'n8n-nodes-base.httpRequest':
        if node['typeVersion'] != 4.3:
            one_flow['nodes'][i]['typeVersion'] = 4.3
            changes_made.append(f"✅ {node_name}: httpRequest → v4.3")

    # 3. Converter Call: Booking Flow de HTTP Request para Execute Subworkflow
    if node_name == 'Call: Booking Flow' and node_type == 'n8n-nodes-base.httpRequest':
        one_flow['nodes'][i] = {
            "parameters": {
                "source": "database",
                "workflowId": {
                    "__rl": True,
                    "value": "",  # Será selecionado manualmente no n8n
                    "mode": "list",
                    "cachedResultName": "CoreAdapt Booking Flow | v4.1"
                },
                "options": {
                    "waitForSubWorkflow": True
                },
                "workflowInputs": {
                    "mappingMode": "defineBelow",
                    "value": {
                        "offer_id": "={{ $json.offer_id }}",
                        "selected_slot": "={{ $json.selected_slot }}",
                        "confidence": "={{ $json.confidence }}"
                    }
                }
            },
            "id": node['id'],
            "name": "Call: Booking Flow",
            "type": "n8n-nodes-base.executeWorkflow",
            "typeVersion": 1.2,
            "position": node.get('position', [-1060, -16]),
            "retryOnFail": True,
            "maxTries": 3
        }
        changes_made.append(f"✅ Call: Booking Flow: httpRequest → executeWorkflow v1.2")

    # 4. Atualizar OpenAI nodes para versão 2.1
    if 'openai' in node_type.lower() or 'OpenAI' in node_name:
        if node.get('typeVersion', 0) < 2.1:
            # Só atualizar se for um node de chat/completion
            if 'lmChatOpenAi' in node_type or 'openAi' in node_type:
                one_flow['nodes'][i]['typeVersion'] = 2.1
                changes_made.append(f"✅ {node_name}: OpenAI → v2.1")

    # 5. Atualizar Merge nodes para versão 3.2
    if node_type == 'n8n-nodes-base.merge':
        if node['typeVersion'] != 3.2:
            one_flow['nodes'][i]['typeVersion'] = 3.2
            changes_made.append(f"✅ {node_name}: merge → v3.2")

# Também atualizar Call: Availability Flow e Call: Availability Filtered
for i, node in enumerate(one_flow['nodes']):
    node_name = node.get('name', '')
    node_type = node.get('type', '')

    if node_name == 'Call: Availability Flow' and node_type == 'n8n-nodes-base.executeWorkflow':
        one_flow['nodes'][i]['typeVersion'] = 1.2
        one_flow['nodes'][i]['parameters']['workflowId'] = {
            "__rl": True,
            "value": "",  # Será selecionado manualmente
            "mode": "list",
            "cachedResultName": "CoreAdapt Availability Flow | v4.3"
        }
        changes_made.append(f"✅ Call: Availability Flow: formato corrigido para seleção manual")

    if node_name == 'Call: Availability Filtered' and node_type == 'n8n-nodes-base.executeWorkflow':
        one_flow['nodes'][i]['typeVersion'] = 1.2
        one_flow['nodes'][i]['parameters']['workflowId'] = {
            "__rl": True,
            "value": "",  # Será selecionado manualmente
            "mode": "list",
            "cachedResultName": "CoreAdapt Availability Flow | v4.3"
        }
        changes_made.append(f"✅ Call: Availability Filtered: formato corrigido para seleção manual")

# Atualizar versão do fluxo
one_flow['name'] = "CoreAdapt One Flow | v4.4 (Node Versions Fixed)"
one_flow['versionId'] = "one-flow-v4.4-versions-fixed"

# Salvar
with open('CoreAdapt One Flow _ v4.1_AUTONOMOUS.json', 'w', encoding='utf-8') as f:
    json.dump(one_flow, f, indent=2, ensure_ascii=False)

print("\n" + "="*70)
print("✅ CORREÇÕES DE VERSÕES APLICADAS!")
print("="*70)
print("\nMudanças realizadas:")
for change in changes_made:
    print(f"  {change}")

print("""
⚠️  IMPORTANTE - AÇÕES MANUAIS NO N8N:

Após importar o fluxo, você precisa configurar manualmente:

1. Node "Call: Availability Flow"
   → Clique no node
   → Em "Workflow", selecione "CoreAdapt Availability Flow | v4.3"

2. Node "Call: Availability Filtered"
   → Clique no node
   → Em "Workflow", selecione "CoreAdapt Availability Flow | v4.3"

3. Node "Call: Booking Flow"
   → Clique no node
   → Em "Workflow", selecione "CoreAdapt Booking Flow | v4.1"

Isso é necessário porque o n8n usa IDs internos que são diferentes
em cada instalação.
""")

# ============================================================================
# AGORA VAMOS ATUALIZAR O BOOKING FLOW PARA ACEITAR SUBWORKFLOW
# ============================================================================

print("\n📦 Carregando Booking Flow...")
with open('CoreAdapt Booking Flow _ v4.json', 'r', encoding='utf-8') as f:
    booking_flow = json.load(f)

# Verificar se já tem Subworkflow Trigger
has_trigger = any(n.get('type') == 'n8n-nodes-base.executeWorkflowTrigger' for n in booking_flow['nodes'])

if not has_trigger:
    # Adicionar trigger node
    trigger_node = {
        "parameters": {},
        "id": "booking-subworkflow-trigger",
        "name": "Subworkflow Trigger",
        "type": "n8n-nodes-base.executeWorkflowTrigger",
        "typeVersion": 1,
        "position": [-1200, 0]  # Posicionar ao lado do webhook existente
    }
    booking_flow['nodes'].append(trigger_node)

    # Encontrar o primeiro node após o webhook e conectar o trigger também
    if 'Webhook: Book Slot' in booking_flow.get('connections', {}):
        first_target = booking_flow['connections']['Webhook: Book Slot']['main'][0][0]['node']
        booking_flow['connections']['Subworkflow Trigger'] = {
            "main": [[{"node": first_target, "type": "main", "index": 0}]]
        }

    print("✅ Subworkflow Trigger adicionado ao Booking Flow")

# Atualizar versões dos nodes no Booking Flow também
for i, node in enumerate(booking_flow['nodes']):
    node_type = node.get('type', '')

    if node_type == 'n8n-nodes-base.httpRequest':
        booking_flow['nodes'][i]['typeVersion'] = 4.3

    if node_type == 'n8n-nodes-base.merge':
        booking_flow['nodes'][i]['typeVersion'] = 3.2

# Atualizar nome/versão
booking_flow['name'] = "CoreAdapt Booking Flow | v4.2 (Subworkflow Support)"
booking_flow['versionId'] = "booking-flow-v4.2-subworkflow"

with open('CoreAdapt Booking Flow _ v4.json', 'w', encoding='utf-8') as f:
    json.dump(booking_flow, f, indent=2, ensure_ascii=False)
print("✅ Booking Flow salvo")

print("\n" + "="*70)
print("✅ TODOS OS FLUXOS ATUALIZADOS!")
print("="*70)
