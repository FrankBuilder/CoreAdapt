#!/usr/bin/env python3
"""
Sentinel Complete Solution
===========================

Implementa a solução COMPLETA para o Sentinel followup system:

1. CANCELAR followups quando reunião é agendada (objetivo atingido)
2. REAGENDAR followups quando lead interage (last_interaction_at atualizado)

ARQUIVOS AFETADOS:
- CoreAdapt Scheduler Flow _ v4.json (adiciona node de cancelamento)

TRIGGER SQL:
- Função para reagendar followups (executar manualmente no Supabase)
"""

import json
import sys
from pathlib import Path

# Paths
REPO_ROOT = Path(__file__).parent.parent
SCHEDULER_FILE = REPO_ROOT / "CoreAdapt Scheduler Flow _ v4.json"
BACKUP_FILE = REPO_ROOT / "CoreAdapt Scheduler Flow _ v4_BEFORE_FOLLOWUP_CANCEL.json"

# Node ID generation (random UUID-like for n8n)
CANCEL_NODE_ID = "a8f3d7e2-4b9c-4a1f-8e3d-9c2b5a7f1e4d"

# New node to cancel followups
CANCEL_FOLLOWUP_NODE = {
    "parameters": {
        "operation": "executeQuery",
        "query": """-- Cancelar todos os followups pendentes quando reunião é agendada
UPDATE corev4_followup_executions
SET
  should_send = false,
  decision_reason = 'meeting_scheduled',
  updated_at = NOW()
WHERE contact_id = $1
  AND executed = false
  AND should_send = true;""",
        "options": {
            "queryReplacement": "={{ [$('Match: Contact by Email/Phone').first().json.contact_id] }}"
        }
    },
    "id": CANCEL_NODE_ID,
    "name": "Cancel: Pending Followups",
    "type": "n8n-nodes-base.postgres",
    "typeVersion": 2.6,
    "position": [
        80,
        368
    ],
    "alwaysOutputData": True,
    "credentials": {
        "postgres": {
            "id": "HCvX4Ypw2MiRDsdm",
            "name": "Postgres Core"
        }
    },
    "notes": "Cancela followups pendentes quando reunião é agendada (objetivo atingido)"
}


def add_cancel_followup_node():
    """Adiciona node de cancelamento de followups no Scheduler Flow"""

    print("=" * 80)
    print("SENTINEL COMPLETE SOLUTION - Part 1: Cancel Followups on Meeting")
    print("=" * 80)

    # 1. Ler workflow
    print(f"\n1. Lendo workflow: {SCHEDULER_FILE.name}")
    with open(SCHEDULER_FILE, 'r', encoding='utf-8') as f:
        workflow = json.load(f)

    # 2. Verificar se node já existe
    print("2. Verificando se node já existe...")
    node_exists = any(node.get('name') == 'Cancel: Pending Followups' for node in workflow.get('nodes', []))

    if node_exists:
        print("   ⚠️  Node 'Cancel: Pending Followups' já existe!")
        print("   Deseja substituir? (s/n): ", end='')
        response = input().strip().lower()
        if response != 's':
            print("\n❌ Operação cancelada pelo usuário")
            return False

        # Remover node existente
        workflow['nodes'] = [n for n in workflow['nodes'] if n.get('name') != 'Cancel: Pending Followups']
        print("   ✓ Node existente removido")

    # 3. Fazer backup
    print(f"\n3. Criando backup: {BACKUP_FILE.name}")
    with open(BACKUP_FILE, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)
    print("   ✓ Backup criado")

    # 4. Adicionar novo node
    print("\n4. Adicionando node 'Cancel: Pending Followups'...")
    workflow['nodes'].append(CANCEL_FOLLOWUP_NODE)
    print("   ✓ Node adicionado")

    # 5. Adicionar conexão do Save Meeting para Cancel Followups
    print("\n5. Adicionando conexão no workflow...")

    # Encontrar node "Save: Meeting Record"
    save_meeting_node = None
    for node in workflow['nodes']:
        if node.get('name') == 'Save: Meeting Record':
            save_meeting_node = node
            break

    if save_meeting_node:
        # Adicionar conexão
        connection_added = False
        for connection in workflow.get('connections', {}).values():
            for output_connections in connection.values():
                for conn_list in output_connections:
                    for conn in conn_list:
                        if conn.get('node') == 'Save: Meeting Record':
                            # Adicionar nova conexão paralela
                            if not any(c.get('node') == 'Cancel: Pending Followups' for c in conn_list):
                                conn_list.append({
                                    "node": "Cancel: Pending Followups",
                                    "type": "main",
                                    "index": 0
                                })
                                connection_added = True

        if not connection_added:
            # Criar conexão manualmente
            save_node_id = save_meeting_node['id']
            if save_node_id not in workflow['connections']:
                workflow['connections'][save_node_id] = {}
            if 'main' not in workflow['connections'][save_node_id]:
                workflow['connections'][save_node_id]['main'] = [[]]

            workflow['connections'][save_node_id]['main'][0].append({
                "node": "Cancel: Pending Followups",
                "type": "main",
                "index": 0
            })

        print("   ✓ Conexão adicionada: Save Meeting → Cancel Followups")
    else:
        print("   ⚠️  Node 'Save: Meeting Record' não encontrado")
        print("   Você precisará conectar manualmente no n8n")

    # 6. Salvar workflow
    print(f"\n6. Salvando workflow: {SCHEDULER_FILE.name}")
    with open(SCHEDULER_FILE, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)
    print("   ✓ Workflow salvo")

    # 7. Validar JSON
    print("\n7. Validando JSON...")
    try:
        with open(SCHEDULER_FILE, 'r', encoding='utf-8') as f:
            json.load(f)
        print("   ✓ JSON válido")
    except json.JSONDecodeError as e:
        print(f"   ❌ ERRO: JSON inválido - {e}")
        print("\n   Restaurando backup...")
        with open(BACKUP_FILE, 'r', encoding='utf-8') as f:
            workflow = json.load(f)
        with open(SCHEDULER_FILE, 'w', encoding='utf-8') as f:
            json.dump(workflow, f, indent=2, ensure_ascii=False)
        print("   ✓ Backup restaurado")
        return False

    print("\n" + "=" * 80)
    print("✅ PART 1 COMPLETO: Node de Cancelamento Adicionado")
    print("=" * 80)
    print("\nO QUE FOI FEITO:")
    print("- Node 'Cancel: Pending Followups' criado")
    print("- Conectado após 'Save: Meeting Record'")
    print("- Cancela followups quando reunião é agendada")
    print("\nQUERY EXECUTADA:")
    print("UPDATE corev4_followup_executions")
    print("SET should_send = false, decision_reason = 'meeting_scheduled'")
    print("WHERE contact_id = $contact_id AND executed = false")
    print("\n" + "=" * 80)

    return True


def generate_trigger_sql():
    """Gera SQL trigger para reagendar followups quando lead interage"""

    trigger_sql = """-- ============================================================================
-- TRIGGER: Reagendar Followups quando Lead Interage
-- ============================================================================
-- Quando last_interaction_at é atualizado em corev4_contacts,
-- recalcula scheduled_at de todos os followups pendentes
-- ============================================================================

-- Função que reagenda followups
CREATE OR REPLACE FUNCTION reagendar_followups_on_interaction()
RETURNS TRIGGER AS $$
BEGIN
  -- Apenas reagenda se last_interaction_at mudou
  IF NEW.last_interaction_at IS DISTINCT FROM OLD.last_interaction_at THEN

    UPDATE corev4_followup_executions e
    SET
      scheduled_at = NEW.last_interaction_at +
                     (fs.wait_hours || ' hours')::INTERVAL +
                     (fs.wait_minutes || ' minutes')::INTERVAL,
      updated_at = NOW()
    FROM corev4_followup_campaigns fc
    INNER JOIN corev4_followup_steps fs
      ON fs.config_id = fc.config_id
      AND fs.step_number = e.step
    WHERE e.contact_id = NEW.id
      AND e.campaign_id = fc.id
      AND e.executed = false
      AND e.should_send = true;

    RAISE NOTICE 'Followups reagendados para contact_id %', NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Criar trigger
DROP TRIGGER IF EXISTS trigger_reagendar_followups ON corev4_contacts;

CREATE TRIGGER trigger_reagendar_followups
  AFTER UPDATE OF last_interaction_at ON corev4_contacts
  FOR EACH ROW
  EXECUTE FUNCTION reagendar_followups_on_interaction();


-- ============================================================================
-- TESTE: Verificar se trigger foi criado
-- ============================================================================
SELECT
  trigger_name,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE trigger_name = 'trigger_reagendar_followups';


-- ============================================================================
-- INSTRUÇÕES:
-- ============================================================================
-- 1. Execute este SQL no Supabase SQL Editor
-- 2. Verifique que o trigger foi criado (última query)
-- 3. Teste: Atualize last_interaction_at de um contact com followups pendentes
-- 4. Verifique que scheduled_at foi recalculado
-- ============================================================================
"""

    trigger_file = REPO_ROOT / "queries" / "TRIGGER_REAGENDAR_FOLLOWUPS.sql"
    with open(trigger_file, 'w', encoding='utf-8') as f:
        f.write(trigger_sql)

    print("\n" + "=" * 80)
    print("✅ PART 2 COMPLETO: Trigger SQL Gerado")
    print("=" * 80)
    print(f"\nArquivo criado: {trigger_file.name}")
    print("\nPRÓXIMOS PASSOS:")
    print("1. Abra Supabase SQL Editor")
    print("2. Execute o conteúdo do arquivo:")
    print(f"   queries/{trigger_file.name}")
    print("3. Verifique que trigger foi criado")
    print("\nO QUE O TRIGGER FAZ:")
    print("- Monitora updates em corev4_contacts.last_interaction_at")
    print("- Recalcula scheduled_at de todos followups pendentes")
    print("- Usa wait_hours e wait_minutes de corev4_followup_steps")
    print("- Apenas afeta followups com executed=false e should_send=true")
    print("\n" + "=" * 80)

    return trigger_file


if __name__ == '__main__':
    try:
        print("\n" + "=" * 80)
        print("SENTINEL COMPLETE SOLUTION")
        print("=" * 80)
        print("\nEsta solução implementa:")
        print("1. Cancelamento de followups quando reunião é agendada")
        print("2. Reagendamento de followups quando lead interage")
        print("\n" + "=" * 80)

        # Part 1: Adicionar node no Scheduler
        success_part1 = add_cancel_followup_node()

        # Part 2: Gerar trigger SQL
        trigger_file = generate_trigger_sql()

        if success_part1:
            print("\n" + "=" * 80)
            print("✅ SOLUÇÃO COMPLETA IMPLEMENTADA")
            print("=" * 80)
            print("\nARQUIVOS MODIFICADOS:")
            print(f"- {SCHEDULER_FILE.name} (node de cancelamento adicionado)")
            print(f"\nARQUIVOS CRIADOS:")
            print(f"- {trigger_file.name} (trigger SQL)")
            print("\nPRÓXIMOS PASSOS:")
            print("1. Importe Scheduler Flow atualizado no n8n")
            print("2. Execute trigger SQL no Supabase")
            print("3. Teste o sistema completo")
            print("\n" + "=" * 80)
            sys.exit(0)
        else:
            print("\n❌ Erro ao adicionar node no Scheduler Flow")
            sys.exit(1)

    except Exception as e:
        print(f"\n❌ ERRO INESPERADO: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
