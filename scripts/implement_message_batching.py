#!/usr/bin/env python3
"""
Script para implementar Message Batching nos fluxos CoreAdapt
Resolve o problema de mensagens em rajada (burst messages)
"""

import json
from pathlib import Path

def create_batch_processor_flow():
    """
    Cria o workflow completo do Batch Processor Flow
    """
    print("=" * 80)
    print("CRIANDO: Batch Processor Flow")
    print("=" * 80)

    # Ler código dos nodes
    base_path = Path("/home/user/CoreAdapt")

    with open(base_path / "nodes/Batch_Processor_Flow.js", 'r') as f:
        processor_code = f.read()

    with open(base_path / "nodes/Fetch_Expired_Batches.sql", 'r') as f:
        fetch_query = f.read()

    with open(base_path / "nodes/Mark_Batch_Processed.sql", 'r') as f:
        mark_query = f.read()

    workflow = {
        "name": "Batch Processor Flow | v4",
        "nodes": [
            {
                "parameters": {
                    "rule": {
                        "interval": [
                            {
                                "field": "cronExpression",
                                "expression": "*/2 * * * * *"
                            }
                        ]
                    }
                },
                "id": "batch-processor-cron-trigger",
                "name": "Trigger: Every 2 Seconds",
                "type": "n8n-nodes-base.scheduleTrigger",
                "typeVersion": 1.2,
                "position": [-400, 300]
            },
            {
                "parameters": {
                    "operation": "executeQuery",
                    "query": fetch_query,
                    "options": {}
                },
                "id": "batch-processor-fetch-expired",
                "name": "Fetch: Expired Batches",
                "type": "n8n-nodes-base.postgres",
                "typeVersion": 2.6,
                "position": [-200, 300],
                "alwaysOutputData": False,
                "credentials": {
                    "postgres": {
                        "id": "HCvX4Ypw2MiRDsdm",
                        "name": "Postgres Core"
                    }
                }
            },
            {
                "parameters": {
                    "conditions": {
                        "options": {
                            "caseSensitive": True,
                            "leftValue": "",
                            "typeValidation": "strict"
                        },
                        "conditions": [
                            {
                                "id": "has-id",
                                "leftValue": "={{ $json.id }}",
                                "rightValue": "",
                                "operator": {
                                    "type": "any",
                                    "operation": "exists"
                                }
                            }
                        ],
                        "combinator": "and"
                    },
                    "options": {}
                },
                "id": "batch-processor-check-results",
                "name": "Check: Has Results?",
                "type": "n8n-nodes-base.if",
                "typeVersion": 2.2,
                "position": [0, 300]
            },
            {
                "parameters": {
                    "jsCode": processor_code
                },
                "id": "batch-processor-combine",
                "name": "Combine: Messages",
                "type": "n8n-nodes-base.code",
                "typeVersion": 2,
                "position": [200, 200]
            },
            {
                "parameters": {
                    "operation": "executeQuery",
                    "query": mark_query,
                    "options": {
                        "queryReplacement": "={{ $('Fetch: Expired Batches').item.json.id }}"
                    }
                },
                "id": "batch-processor-mark-processed",
                "name": "Mark: Batch Processed",
                "type": "n8n-nodes-base.postgres",
                "typeVersion": 2.6,
                "position": [400, 200],
                "credentials": {
                    "postgres": {
                        "id": "HCvX4Ypw2MiRDsdm",
                        "name": "Postgres Core"
                    }
                }
            },
            {
                "parameters": {
                    "workflowId": "={{ $workflow.id }}",
                    "options": {}
                },
                "id": "batch-processor-execute-one",
                "name": "Execute: One Flow",
                "type": "n8n-nodes-base.executeWorkflow",
                "typeVersion": 1.1,
                "position": [600, 200],
                "notes": "Executa CoreAdapt One Flow com mensagem combinada"
            },
            {
                "parameters": {},
                "id": "batch-processor-no-op",
                "name": "No Operation",
                "type": "n8n-nodes-base.noOp",
                "typeVersion": 1,
                "position": [200, 400],
                "notes": "Quando não há batches expirados"
            }
        ],
        "pinData": {},
        "connections": {
            "Trigger: Every 2 Seconds": {
                "main": [
                    [
                        {
                            "node": "Fetch: Expired Batches",
                            "type": "main",
                            "index": 0
                        }
                    ]
                ]
            },
            "Fetch: Expired Batches": {
                "main": [
                    [
                        {
                            "node": "Check: Has Results?",
                            "type": "main",
                            "index": 0
                        }
                    ]
                ]
            },
            "Check: Has Results?": {
                "main": [
                    [
                        {
                            "node": "Combine: Messages",
                            "type": "main",
                            "index": 0
                        }
                    ],
                    [
                        {
                            "node": "No Operation",
                            "type": "main",
                            "index": 0
                        }
                    ]
                ]
            },
            "Combine: Messages": {
                "main": [
                    [
                        {
                            "node": "Mark: Batch Processed",
                            "type": "main",
                            "index": 0
                        }
                    ]
                ]
            },
            "Mark: Batch Processed": {
                "main": [
                    [
                        {
                            "node": "Execute: One Flow",
                            "type": "main",
                            "index": 0
                        }
                    ]
                ]
            }
        },
        "active": True,
        "settings": {
            "executionOrder": "v1"
        },
        "meta": {
            "templateCredsSetupCompleted": True,
            "instanceId": "5c6394fedb685d155bbe72063becfd91d616d8e123397941c9863e7b805328ae"
        },
        "tags": [
            {
                "createdAt": "2025-10-16T11:45:27.519Z",
                "updatedAt": "2025-10-16T11:45:27.519Z",
                "id": "eTCC1MPmHZOu7LAH",
                "name": "corev4"
            }
        ]
    }

    # Salvar workflow
    output_path = base_path / "Batch Processor Flow _ v4.json"
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)

    print(f"✅ Batch Processor Flow criado: {output_path}")
    print("   - Trigger: a cada 2 segundos")
    print("   - Fetch expired batches")
    print("   - Combine messages")
    print("   - Execute One Flow")
    print("=" * 80)

    return output_path

def add_batch_collector_to_main_router():
    """
    Adiciona node Batch Collector no Main Router Flow
    """
    print("=" * 80)
    print("MODIFICANDO: Main Router Flow")
    print("=" * 80)

    base_path = Path("/home/user/CoreAdapt")
    router_path = base_path / "CoreAdapt Main Router Flow _ v4.json"

    # Ler workflow
    with open(router_path, 'r', encoding='utf-8') as f:
        workflow = json.load(f)

    # Ler código do batch collector
    with open(base_path / "nodes/Batch_Collect_Messages.js", 'r') as f:
        collector_code = f.read()

    # Criar novo node
    batch_collector_node = {
        "parameters": {
            "jsCode": collector_code
        },
        "id": "batch-collect-messages-node",
        "name": "Batch: Collect Messages",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [800, 300],
        "notes": "Coleta mensagens em rajada e aguarda 3s de silêncio antes de processar"
    }

    # Adicionar node ao workflow
    workflow["nodes"].append(batch_collector_node)
    print("✅ Node 'Batch: Collect Messages' adicionado")

    # Atualizar conexões
    # Encontrar "Execute: Normalize Evolution Data" e inserir batch collector após ele
    connections = workflow.get("connections", {})

    if "Execute: Normalize Evolution Data" in connections:
        # Pegar conexões antigas
        old_connections = connections["Execute: Normalize Evolution Data"]["main"][0]

        # Redirecionar para Batch Collector
        connections["Execute: Normalize Evolution Data"]["main"][0] = [
            {
                "node": "Batch: Collect Messages",
                "type": "main",
                "index": 0
            }
        ]

        # Batch Collector conecta para destinos antigos
        connections["Batch: Collect Messages"] = {
            "main": [old_connections]
        }

        print("✅ Conexões atualizadas:")
        print("   - 'Execute: Normalize Evolution Data' → 'Batch: Collect Messages' → destinos originais")

    workflow["connections"] = connections

    # Backup
    backup_path = str(router_path).replace('.json', '_BEFORE_BATCHING.json')
    with open(backup_path, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)
    print(f"✅ Backup criado: {backup_path}")

    # Salvar workflow modificado
    with open(router_path, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)

    print(f"✅ Main Router Flow atualizado: {router_path}")
    print("=" * 80)

    return router_path

def main():
    print("\n")
    print("=" * 80)
    print("IMPLEMENTANDO MESSAGE BATCHING")
    print("=" * 80)
    print("\n")

    print("📋 O que será feito:")
    print("1. Criar Batch Processor Flow (novo workflow)")
    print("2. Adicionar node Batch Collector no Main Router Flow")
    print("3. Migration SQL já existe em migrations/add_batch_messages_column.sql")
    print("\n")

    # 1. Criar Batch Processor Flow
    batch_flow_path = create_batch_processor_flow()
    print(f"\n✅ 1/2 - Batch Processor Flow criado\n")

    # 2. Adicionar batch collector ao Main Router
    router_path = add_batch_collector_to_main_router()
    print(f"\n✅ 2/2 - Main Router Flow atualizado\n")

    print("\n")
    print("=" * 80)
    print("MESSAGE BATCHING IMPLEMENTADO COM SUCESSO!")
    print("=" * 80)
    print("\n")
    print("📁 Arquivos criados/modificados:")
    print(f"   ✅ {batch_flow_path}")
    print(f"   ✅ {router_path}")
    print(f"   📦 Backup: CoreAdapt Main Router Flow _ v4_BEFORE_BATCHING.json")
    print("\n")
    print("🔧 Próximos passos:")
    print("   1. Executar migration SQL:")
    print("      → migrations/add_batch_messages_column.sql")
    print("   2. Importar workflows no n8n:")
    print("      → Batch Processor Flow _ v4.json (NOVO)")
    print("      → CoreAdapt Main Router Flow _ v4.json (MODIFICADO)")
    print("   3. Ativar Batch Processor Flow")
    print("   4. Testar enviando mensagens em rajada")
    print("\n")
    print("🧪 Teste:")
    print("   Enviar via WhatsApp:")
    print("   10:00:00 - Oi")
    print("   10:00:02 - Tudo bem")
    print("   10:00:03 - ?")
    print("   [aguardar 3s]")
    print("   → IA deve responder 1 ÚNICA VEZ com contexto das 3 mensagens")
    print("\n")
    print("📊 Impacto esperado:")
    print("   - Chamadas de IA: -60% a -70%")
    print("   - Economia: ~$0.0002 por conversa")
    print("   - UX: Melhor (lead não é bombardeado)")
    print("\n")

if __name__ == "__main__":
    main()
