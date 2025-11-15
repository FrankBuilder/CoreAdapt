#!/usr/bin/env python3
"""
Ajusta credenciais Supabase nos nodes Calculate
"""

import json
from pathlib import Path

SUPABASE_URL = 'https://uosauvyafotuhktpjjkm.supabase.co'
SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVvc2F1dnlhZm90dWhrdHBqamttIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjU0MDgxODcsImV4cCI6MjA0MDk4NDE4N30.3UzrMj0gw1aY8fcJw9649LjIKryLTNgmDNd9EuIpOx8'

filepath = Path("CoreAdapt One Flow _ v4.json")

with open(filepath, 'r', encoding='utf-8') as f:
    workflow = json.load(f)

for node in workflow['nodes']:
    if node.get('name') in ['Calculate: User Tokens & Cost', 'Calculate: Assistant Cost']:
        code = node['parameters']['jsCode']

        # Substituir URL
        code = code.replace(
            "const SUPABASE_URL = 'https://jrvzexchifudbdxeqvuh.supabase.co';",
            f"const SUPABASE_URL = '{SUPABASE_URL}';"
        )

        # Substituir KEY
        code = code.replace(
            "const SUPABASE_ANON_KEY = 'SUA_ANON_KEY_AQUI';",
            f"const SUPABASE_ANON_KEY = '{SUPABASE_ANON_KEY}';"
        )

        node['parameters']['jsCode'] = code
        print(f"✅ {node['name']}: Credenciais configuradas")

with open(filepath, 'w', encoding='utf-8') as f:
    json.dump(workflow, f, indent=2, ensure_ascii=False)

print(f"\n✅ Credenciais Supabase configuradas:")
print(f"   URL: {SUPABASE_URL}")
print(f"   KEY: {SUPABASE_ANON_KEY[:20]}...")
