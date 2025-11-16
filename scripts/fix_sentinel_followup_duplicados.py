#!/usr/bin/env python3
"""
Fix Sentinel Followup Duplicados
=================================

PROBLEMA:
Múltiplos followups da mesma campanha são enviados simultaneamente quando
vencem durante espera de horário permitido.

SOLUÇÃO:
Modificar query para usar DISTINCT ON (campaign_id) e ORDER BY step ASC,
garantindo que apenas o primeiro step não executado seja processado.

ARQUIVO AFETADO:
- CoreAdapt Sentinel Flow _ v4.json

MUDANÇA:
- Node: "Fetch: Pending Followups"
- Query: Adicionar DISTINCT ON + ORDER BY correto
"""

import json
import sys
from pathlib import Path

# Paths
REPO_ROOT = Path(__file__).parent.parent
WORKFLOW_FILE = REPO_ROOT / "CoreAdapt Sentinel Flow _ v4.json"
BACKUP_FILE = REPO_ROOT / "CoreAdapt Sentinel Flow _ v4_BEFORE_DISTINCT_FIX.json"

# Nova query CORRIGIDA
NEW_QUERY = """SELECT DISTINCT ON (e.campaign_id)
  e.id AS execution_id,
  e.campaign_id,
  e.contact_id,
  e.company_id,
  e.step,
  e.total_steps,
  e.scheduled_at,

  c.full_name AS contact_name,
  c.phone_number,
  c.whatsapp,
  c.last_interaction_at,

  ls.total_score AS anum_score,
  CASE WHEN ls.total_score IS NULL THEN FALSE ELSE TRUE END AS has_been_analyzed,
  COALESCE(ls.qualification_stage, 'inicial') AS qualification_stage,

  co.evolution_api_url,
  co.evolution_instance,
  co.evolution_api_key,

  fs.wait_hours,
  fs.wait_minutes

FROM corev4_followup_executions e
INNER JOIN corev4_contacts c ON c.id = e.contact_id
LEFT JOIN corev4_lead_state ls ON ls.contact_id = e.contact_id
INNER JOIN corev4_companies co ON co.id = e.company_id
LEFT JOIN corev4_followup_campaigns fc ON fc.id = e.campaign_id
LEFT JOIN corev4_followup_steps fs ON fs.config_id = fc.config_id AND fs.step_number = e.step

WHERE e.executed = false
  AND e.should_send = true
  AND c.opt_out = false
  AND e.scheduled_at <= NOW()
  AND (
    c.last_interaction_at IS NULL
    OR
    c.last_interaction_at < e.scheduled_at
  )
  AND (
    ls.total_score IS NULL
    OR
    ls.total_score < 70
  )

ORDER BY e.campaign_id, e.step ASC, e.scheduled_at ASC
LIMIT 50;"""


def fix_sentinel_followup_query():
    """Corrige a query do Sentinel para evitar envio de followups duplicados"""

    print("=" * 80)
    print("FIX: Sentinel Followup Duplicados")
    print("=" * 80)

    # 1. Ler workflow
    print(f"\n1. Lendo workflow: {WORKFLOW_FILE.name}")
    with open(WORKFLOW_FILE, 'r', encoding='utf-8') as f:
        workflow = json.load(f)

    # 2. Encontrar node "Fetch: Pending Followups"
    print("2. Procurando node 'Fetch: Pending Followups'...")

    node_found = False
    for node in workflow.get('nodes', []):
        if node.get('name') == 'Fetch: Pending Followups':
            node_found = True

            # Verificar se tem a query antiga
            old_query = node['parameters']['query']

            print(f"   ✓ Node encontrado (id: {node['id']})")
            print(f"   - Query atual tem {len(old_query)} caracteres")

            # Verificar se já tem DISTINCT ON
            if 'DISTINCT ON' in old_query:
                print("   ⚠️  Query já contém DISTINCT ON - possivelmente já corrigida")
                print("\n   Deseja aplicar a correção mesmo assim? (s/n): ", end='')
                response = input().strip().lower()
                if response != 's':
                    print("\n❌ Operação cancelada pelo usuário")
                    return False

            # 3. Fazer backup
            print(f"\n3. Criando backup: {BACKUP_FILE.name}")
            with open(BACKUP_FILE, 'w', encoding='utf-8') as f:
                json.dump(workflow, f, indent=2, ensure_ascii=False)
            print("   ✓ Backup criado")

            # 4. Aplicar nova query
            print("\n4. Aplicando nova query com DISTINCT ON...")
            node['parameters']['query'] = NEW_QUERY

            print("   ✓ Query atualizada")
            print("\n   Mudanças aplicadas:")
            print("   - Adicionado: SELECT DISTINCT ON (e.campaign_id)")
            print("   - Modificado: ORDER BY e.campaign_id, e.step ASC, e.scheduled_at ASC")
            print("   - Efeito: Apenas o primeiro step pendente de cada campanha será processado")

            break

    if not node_found:
        print("\n❌ ERRO: Node 'Fetch: Pending Followups' não encontrado!")
        return False

    # 5. Salvar workflow corrigido
    print(f"\n5. Salvando workflow corrigido: {WORKFLOW_FILE.name}")
    with open(WORKFLOW_FILE, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)

    print("   ✓ Workflow salvo")

    # 6. Validar JSON
    print("\n6. Validando JSON...")
    try:
        with open(WORKFLOW_FILE, 'r', encoding='utf-8') as f:
            json.load(f)
        print("   ✓ JSON válido")
    except json.JSONDecodeError as e:
        print(f"   ❌ ERRO: JSON inválido - {e}")
        print("\n   Restaurando backup...")
        with open(BACKUP_FILE, 'r', encoding='utf-8') as f:
            workflow = json.load(f)
        with open(WORKFLOW_FILE, 'w', encoding='utf-8') as f:
            json.dump(workflow, f, indent=2, ensure_ascii=False)
        print("   ✓ Backup restaurado")
        return False

    print("\n" + "=" * 80)
    print("✅ CORREÇÃO APLICADA COM SUCESSO")
    print("=" * 80)
    print("\nPRÓXIMOS PASSOS:")
    print("1. Execute queries de diagnóstico:")
    print("   queries/DIAGNOSTICO_FOLLOWUP_DUPLICADOS.sql (seções 2, 4, 6, 7)")
    print("\n2. Importe o workflow atualizado no n8n")
    print("\n3. Teste com campanha controlada:")
    print("   - Crie followup com 2 steps rápidos (1min e 2min)")
    print("   - Deixe ambos vencerem fora do horário")
    print("   - Verifique que apenas 1 mensagem é enviada")
    print("\n4. Monitore logs nas primeiras 24h")
    print("\n" + "=" * 80)

    return True


if __name__ == '__main__':
    try:
        success = fix_sentinel_followup_query()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"\n❌ ERRO INESPERADO: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
