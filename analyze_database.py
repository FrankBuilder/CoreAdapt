#!/usr/bin/env python3
"""
Deep Dive Analysis do Banco de Dados CoreAdapt v4
Análise abissal de cada tabela, campo, relacionamento e uso
"""

import json
import re
from collections import defaultdict
from pathlib import Path

# Carregar schema
with open('schema_parsed.json', 'r', encoding='utf-8') as f:
    schema = json.load(f)

# Carregar fluxos N8N para análise de uso
n8n_flows = [
    'CoreAdapt Commands Flow _ v4.json',
    'CoreAdapt Genesis Flow _ v4.json',
    'CoreAdapt Main Router Flow _ v4.json',
    'CoreAdapt Meeting Reminders Flow _ v4.json',
    'CoreAdapt One Flow _ v4.json',
    'CoreAdapt Scheduler Flow _ v4.json',
    'CoreAdapt Sentinel Flow _ v4.json',
    'CoreAdapt Sync Flow _ v4.json',
    'Create Followup Campaign _ v4.json',
    'Reactivate Blocked Contact _ v4.json',
    'Process Audio Message _ v4.json',
    'Normalize Evolution API _ v4.json',
]

# Mapear uso de tabelas nos fluxos
table_usage = defaultdict(lambda: {'flows': set(), 'operations': defaultdict(int)})

for flow_file in n8n_flows:
    try:
        with open(flow_file, 'r', encoding='utf-8') as f:
            flow_content = f.read()

        # Extrair nome do fluxo
        flow_name = flow_file.replace(' _ v4.json', '').replace('_', ' ')

        # Procurar por tabelas corev4_*
        for table_name in schema.get('entities', {}).keys():
            if table_name in flow_content:
                table_usage[table_name]['flows'].add(flow_name)

                # Tentar detectar tipo de operação
                if re.search(rf'\bSELECT\b.*\bFROM\b.*\b{table_name}\b', flow_content, re.IGNORECASE):
                    table_usage[table_name]['operations']['SELECT'] += 1
                if re.search(rf'\bINSERT\b.*\bINTO\b.*\b{table_name}\b', flow_content, re.IGNORECASE):
                    table_usage[table_name]['operations']['INSERT'] += 1
                if re.search(rf'\bUPDATE\b.*\b{table_name}\b', flow_content, re.IGNORECASE):
                    table_usage[table_name]['operations']['UPDATE'] += 1
                if re.search(rf'\bDELETE\b.*\bFROM\b.*\b{table_name}\b', flow_content, re.IGNORECASE):
                    table_usage[table_name]['operations']['DELETE'] += 1
    except Exception as e:
        print(f"Erro ao processar {flow_file}: {e}")

# Categorizar tabelas por domínio
categories = {
    'Gestão de Contatos': [
        'corev4_contacts',
        'corev4_contact_extras',
        'corev4_companies',
    ],
    'Conversas e Mensagens': [
        'corev4_chats',
        'corev4_chat_history',
        'corev4_message_dedup',
        'corev4_message_media',
        'corev4_n8n_chat_histories',
    ],
    'Qualificação de Leads (ANUM)': [
        'corev4_lead_state',
        'corev4_anum_history',
        'corev4_pain_categories',
    ],
    'Follow-up e Campanhas': [
        'corev4_followup_campaigns',
        'corev4_followup_configs',
        'corev4_followup_executions',
        'corev4_followup_sequences',
        'corev4_followup_steps',
        'corev4_followup_stage_history',
    ],
    'Reuniões e Agendamentos': [
        'corev4_scheduled_meetings',
        'corev4_meeting_offers',
    ],
    'Inteligência Artificial': [
        'corev4_ai_decisions',
    ],
    'Logs e Auditoria': [
        'corev4_execution_logs',
    ],
    'Utilitários e Migração': [
        'corev4_session_id_migration',
    ],
}

# Inverter mapa de categorias
table_to_category = {}
for category, tables in categories.items():
    for table in tables:
        table_to_category[table] = category

# Função para formatar tipo de dado
def format_data_type(col):
    dtype = col['data_type']
    if col['character_maximum_length']:
        return f"{dtype}({col['character_maximum_length']})"
    elif col['numeric_precision']:
        return f"{dtype}({col['numeric_precision']})"
    elif dtype == 'ARRAY':
        return "text[]"
    return dtype

# Função para gerar descrição de campo baseada no nome
def infer_field_purpose(field_name, data_type):
    """Inferir propósito do campo baseado no nome e tipo"""

    # Padrões comuns
    if field_name == 'id':
        return 'Identificador único da tabela (Primary Key)'
    if field_name.endswith('_id'):
        ref = field_name.replace('_id', '')
        return f'Chave estrangeira para tabela de {ref}'
    if field_name == 'created_at':
        return 'Data/hora de criação do registro'
    if field_name == 'updated_at':
        return 'Data/hora da última atualização do registro'
    if field_name.startswith('is_'):
        return f'Flag booleano: {field_name.replace("is_", "")}'
    if field_name.startswith('has_'):
        return f'Flag booleano: {field_name.replace("has_", "")}'
    if field_name.endswith('_at'):
        event = field_name.replace('_at', '')
        return f'Timestamp do evento: {event}'
    if field_name.endswith('_count'):
        what = field_name.replace('_count', '')
        return f'Contador de {what}'
    if field_name.endswith('_url'):
        return f'URL para {field_name.replace("_url", "")}'
    if field_name.endswith('_email'):
        return f'Endereço de email para {field_name.replace("_email", "")}'
    if field_name.endswith('_score'):
        metric = field_name.replace('_score', '')
        return f'Pontuação/score de {metric}'
    if 'whatsapp' in field_name:
        return 'Número de telefone WhatsApp'
    if 'phone' in field_name:
        return 'Número de telefone'
    if 'utm_' in field_name:
        param = field_name.replace('utm_', '')
        return f'Parâmetro UTM: {param} (origem de marketing)'
    if 'evolution_' in field_name:
        return f'Integração Evolution API: {field_name.replace("evolution_", "")}'
    if 'cal_' in field_name:
        return f'Integração Cal.com: {field_name.replace("cal_", "")}'
    if 'llm_' in field_name:
        return f'Configuração de LLM: {field_name.replace("llm_", "")}'
    if 'crm_' in field_name:
        return f'Integração CRM: {field_name.replace("crm_", "")}'

    # Tipos de dados específicos
    if data_type == 'jsonb':
        return f'Dados JSON: {field_name}'
    if data_type == 'boolean':
        return f'Flag booleano: {field_name}'
    if data_type in ['timestamp with time zone', 'timestamp without time zone']:
        return f'Data/hora: {field_name}'

    return f'Campo {field_name}'

# Gerar documentação
print("=" * 100)
print("DEEP DIVE ANALYSIS - BANCO DE DADOS COREADAPT V4")
print("Análise Abissal e Documentação Completa")
print("=" * 100)
print()

# Estatísticas gerais
print("## 📊 ESTATÍSTICAS GERAIS")
print()
total_columns = sum(len(table.get('columns', {})) for table in schema.get('entities', {}).values())
total_indexes = sum(len(table.get('indexes', [])) for table in schema.get('entities', {}).values())
total_fks = sum(len(table.get('foreign_keys', [])) for table in schema.get('entities', {}).values())
total_triggers = sum(len(table.get('triggers', [])) for table in schema.get('entities', {}).values())

print(f"- **Tabelas**: {len(schema.get('entities', {}))}")
print(f"- **Colunas totais**: {total_columns}")
print(f"- **Índices**: {total_indexes}")
print(f"- **Foreign Keys**: {total_fks}")
print(f"- **Triggers**: {total_triggers}")
print(f"- **Views**: {len(schema.get('views', {}))}")
print(f"- **Functions**: {len(schema.get('functions', {}))}")
print()

# Análise por categoria
print("## 📁 CATEGORIZAÇÃO DE TABELAS")
print()
for category, tables in categories.items():
    print(f"### {category}")
    for table in tables:
        if table in schema['entities']:
            col_count = len(schema['entities'][table].get('columns', {}))
            desc = schema['entities'][table].get('description', 'Sem descrição')
            print(f"- **{table}** ({col_count} campos) - {desc}")
    print()

print("\n" + "=" * 100)
print("## 🔍 ANÁLISE DETALHADA POR TABELA")
print("=" * 100)
print()

# Análise detalhada de cada tabela
for table_name in sorted(schema['entities'].keys()):
    table = schema['entities'][table_name]
    category = table_to_category.get(table_name, 'Sem Categoria')

    print(f"\n### 📋 {table_name}")
    print(f"**Categoria**: {category}")
    print()

    # Descrição
    desc = table.get('description', 'Sem descrição disponível')
    print(f"**Descrição**: {desc}")
    print()

    # Uso nos fluxos
    if table_name in table_usage:
        usage = table_usage[table_name]
        print(f"**Usado em {len(usage['flows'])} fluxo(s)**:")
        for flow in sorted(usage['flows']):
            ops = []
            for op, count in usage['operations'].items():
                if count > 0:
                    ops.append(f"{op}({count})")
            ops_str = ", ".join(ops) if ops else "referenciado"
            print(f"- {flow}: {ops_str}")
        print()
    else:
        print("**⚠️ ATENÇÃO**: Tabela não encontrada nos fluxos N8N analisados")
        print()

    # Campos
    print(f"**Campos ({len(table.get('columns', {}))} total)**:")
    print()
    print("| Campo | Tipo | Nullable | Default | Propósito |")
    print("|-------|------|----------|---------|-----------|")

    for col_name, col in table.get('columns', {}).items():
        dtype = format_data_type(col)
        nullable = "✅" if col['nullable'] else "❌"
        default = col['default'] or '-'
        if len(default) > 30:
            default = default[:27] + '...'
        purpose = infer_field_purpose(col_name, col['data_type'])
        print(f"| `{col_name}` | {dtype} | {nullable} | `{default}` | {purpose} |")

    print()

    # Relacionamentos
    fks = table.get('foreign_keys', [])
    if fks:
        print(f"**Relacionamentos ({len(fks)} Foreign Keys)**:")
        print()
        for fk in fks:
            col = fk['column']
            ref_table = fk['references_table']
            ref_col = fk['references_column']
            on_delete = fk['on_delete']
            on_update = fk['on_update']
            print(f"- `{col}` → `{ref_table}.{ref_col}` (ON DELETE {on_delete}, ON UPDATE {on_update})")
        print()

    # Índices
    indexes = table.get('indexes', [])
    if indexes:
        print(f"**Índices ({len(indexes)} total)**:")
        print()
        for idx in indexes:
            idx_name = idx['index_name']
            definition = idx['definition']
            # Simplificar definição
            if 'UNIQUE' in definition:
                idx_type = "🔑 UNIQUE"
            elif 'pkey' in idx_name:
                idx_type = "🔑 PRIMARY KEY"
            else:
                idx_type = "📇 INDEX"

            # Extrair colunas do índice
            match = re.search(r'USING \w+ \((.+?)\)', definition)
            if match:
                cols = match.group(1)
                print(f"- {idx_type} `{idx_name}`: {cols}")
            else:
                print(f"- {idx_type} `{idx_name}`")
        print()

    # Triggers
    triggers = table.get('triggers', [])
    if triggers:
        print(f"**Triggers ({len(triggers)} total)**:")
        print()
        for trig in triggers:
            trig_name = trig['trigger_name']
            func_name = trig['function_name']
            event = trig['trigger_event']
            timing = trig['trigger_timing']
            print(f"- `{trig_name}`: {timing} {event} → `{func_name}()`")
        print()

    # RLS
    if table.get('rls_enabled'):
        policies = table.get('rls_policies', [])
        print(f"**Row Level Security (RLS)**: ✅ Habilitado ({len(policies)} policies)")
        print()
        for policy in policies:
            print(f"- **{policy['policy_name']}**: {policy['operation']} ({policy['permissive']})")
            if policy.get('using_expression'):
                print(f"  - USING: `{policy['using_expression']}`")
        print()

    # Constraints
    checks = table.get('check_constraints', [])
    if checks:
        non_null_checks = [c for c in checks if 'not_null' in c['constraint_name']]
        other_checks = [c for c in checks if 'not_null' not in c['constraint_name']]

        if other_checks:
            print(f"**Check Constraints ({len(other_checks)} validações)**:")
            print()
            for check in other_checks:
                name = check['constraint_name']
                clause = check['check_clause']
                print(f"- `{name}`: {clause}")
            print()

    # Unique constraints
    uniques = table.get('unique_constraints', [])
    if uniques:
        print(f"**Unique Constraints**:")
        print()
        for unique in uniques:
            cols = ', '.join([f"`{c}`" for c in unique['columns']])
            print(f"- {cols}")
        print()

    # Estatísticas
    row_count = table.get('row_count', 0)
    total_size = table.get('total_size', 'N/A')
    print(f"**Estatísticas**: {row_count} linhas, tamanho: {total_size}")
    print()
    print("-" * 100)

print("\n" + "=" * 100)
print("## 📊 VIEWS (VISÕES)")
print("=" * 100)
print()

for view_name, view in schema.get('views', {}).items():
    print(f"### 👁️ {view_name}")
    comment = view.get('comment', 'Sem descrição')
    print(f"**Descrição**: {comment}")
    print()

    # Mostrar definição SQL (primeiras linhas)
    definition = view.get('definition', '')
    if definition:
        lines = definition.strip().split('\n')[:10]
        print("**Definição SQL** (primeiras linhas):")
        print("```sql")
        print('\n'.join(lines))
        if len(definition.split('\n')) > 10:
            print("... (truncado)")
        print("```")
    print()
    print("-" * 100)
    print()

print("\n" + "=" * 100)
print("## ⚙️ FUNCTIONS (FUNÇÕES)")
print("=" * 100)
print()

functions = schema.get('functions', {})
if isinstance(functions, dict):
    functions_list = list(functions.items())
else:
    # Se for lista, tentar extrair nome da função
    functions_list = [(f.get('name', f'function_{i}'), f) for i, f in enumerate(functions)]

for func_name, func in functions_list:
    print(f"### 🔧 {func_name}()")
    print(f"**Descrição**: {func.get('comment', 'Sem descrição')}")
    print()

    # Mostrar definição (primeiras linhas)
    definition = func.get('definition', '')
    if definition:
        lines = definition.strip().split('\n')[:15]
        print("**Definição** (primeiras linhas):")
        print("```sql")
        print('\n'.join(lines))
        if len(definition.split('\n')) > 15:
            print("... (truncado)")
        print("```")
    print()
    print("-" * 100)
    print()

print("\n" + "=" * 100)
print("## 🔗 MAPA DE RELACIONAMENTOS")
print("=" * 100)
print()

print("Diagrama de relacionamentos entre tabelas:")
print()
print("```mermaid")
print("erDiagram")
print()

# Gerar relacionamentos para Mermaid
for table_name, table in schema['entities'].items():
    fks = table.get('foreign_keys', [])
    for fk in fks:
        ref_table = fk['references_table']
        col = fk['column']
        ref_col = fk['references_column']
        on_delete = fk['on_delete']

        # Determinar cardinalidade
        if on_delete == 'CASCADE':
            relationship = "||--o{"
        else:
            relationship = "||--||"

        print(f"    {ref_table} {relationship} {table_name} : \"{col}\"")

print("```")
print()

print("\n" + "=" * 100)
print("FIM DA ANÁLISE")
print("=" * 100)
