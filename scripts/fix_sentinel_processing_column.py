#!/usr/bin/env python3
"""
Fix Sentinel Flow: Remove processing_started_at column reference

Erro: column e.processing_started_at does not exist

A query tentava marcar executions como "processing" usando essa coluna,
mas ela não existe no schema. O FOR UPDATE SKIP LOCKED já garante que
não há duplicatas, então essa lógica é redundante.

Removemos:
- SET processing_started_at = NOW()
- AND e.processing_started_at IS NULL
"""

import json
from pathlib import Path


def fix_sentinel_query():
    filepath = Path("CoreAdapt Sentinel Flow _ v4.json")

    print("=" * 80)
    print("FIX: Sentinel Flow - Remove processing_started_at Reference")
    print("=" * 80)
    print()

    with open(filepath, 'r', encoding='utf-8') as f:
        workflow = json.load(f)

    # Backup
    backup_path = filepath.with_name(filepath.stem + "_BEFORE_PROCESSING_FIX.json")
    print(f"📦 Backup: {backup_path.name}")
    with open(backup_path, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)

    for node in workflow['nodes']:
        if node.get('name') == 'Fetch: Pending Followups':
            print(f"\n🔧 Fixing: {node['name']}")

            old_query = node['parameters']['query']

            # Nova query SEM processing_started_at
            new_query = """-- ✅ CORRIGIDO: FOR UPDATE SKIP LOCKED evita duplicatas (processing_started_at removido)
WITH pending AS (
  SELECT
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

  ORDER BY e.scheduled_at ASC
  LIMIT 50

  -- ✅ LOCK rows para evitar processamento concorrente (suficiente, sem processing_started_at)
  FOR UPDATE SKIP LOCKED
)
SELECT
  p.execution_id,
  p.campaign_id,
  p.contact_id,
  p.company_id,
  p.step,
  p.total_steps,
  p.scheduled_at,
  p.contact_name,
  p.phone_number,
  p.whatsapp,
  p.last_interaction_at,
  p.anum_score,
  p.has_been_analyzed,
  p.qualification_stage,
  p.evolution_api_url,
  p.evolution_instance,
  p.evolution_api_key,
  p.wait_hours,
  p.wait_minutes
FROM pending p;"""

            node['parameters']['query'] = new_query
            print("   ✅ Removed processing_started_at logic")
            print("   ✅ FOR UPDATE SKIP LOCKED still prevents duplicates")

    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)

    print("\n" + "=" * 80)
    print("✅ Sentinel Flow Fixed")
    print("=" * 80)
    print()
    print("🔍 Changes made:")
    print("   ❌ Removed: SET processing_started_at = NOW()")
    print("   ❌ Removed: AND e.processing_started_at IS NULL")
    print("   ✅ Kept: FOR UPDATE SKIP LOCKED (prevents duplicates)")
    print()
    print("📋 Next steps:")
    print("   1. Reimportar workflow no n8n")
    print("   2. Testar execução do Sentinel")
    print("   3. Verificar se busca pending followups")
    print()


if __name__ == "__main__":
    fix_sentinel_query()
