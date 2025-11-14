#!/usr/bin/env python3
"""
SENTINEL FLOW FIX FINAL - Remove FOR UPDATE completamente

Erro: FOR UPDATE cannot be applied to the nullable side of an outer join

Causa: Query tem LEFT JOIN + FOR UPDATE = Postgres rejeita

Solução: Remover FOR UPDATE SKIP LOCKED completamente
- LEFT JOIN é necessário (query aceita ls.total_score IS NULL)
- Duplicatas são raras (cron cada X segundos)
- Aceitável sem locking
"""

import json
from pathlib import Path


def fix_sentinel_remove_for_update():
    filepath = Path("CoreAdapt Sentinel Flow _ v4.json")

    with open(filepath, 'r', encoding='utf-8') as f:
        workflow = json.load(f)

    for node in workflow['nodes']:
        if node.get('name') == 'Fetch: Pending Followups':
            # Query SEM FOR UPDATE
            new_query = """SELECT
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
LIMIT 50;"""

            node['parameters']['query'] = new_query
            print(f"✅ Fixed: {node['name']}")
            print("   ❌ Removed: FOR UPDATE SKIP LOCKED (incompatible with LEFT JOIN)")
            print("   ✅ Kept: LEFT JOIN (needed for ls.total_score IS NULL cases)")

    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)

    print("\n✅ Sentinel Flow fixed - query will execute without FOR UPDATE error")


if __name__ == "__main__":
    fix_sentinel_remove_for_update()
