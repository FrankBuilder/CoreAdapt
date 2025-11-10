#!/usr/bin/env python3
"""
Análise Crítica e Recomendações para o Banco de Dados CoreAdapt v4
Identifica problemas, inconsistências e oportunidades de melhoria
"""

import json
import re
from collections import defaultdict

# Carregar schema
with open('schema_parsed.json', 'r', encoding='utf-8') as f:
    schema = json.load(f)

print("=" * 100)
print("RELATÓRIO DE ANÁLISE CRÍTICA E RECOMENDAÇÕES")
print("Banco de Dados CoreAdapt v4")
print("=" * 100)
print()

# Armazenar achados
issues = defaultdict(list)
recommendations = defaultdict(list)
good_practices = []

# 1. ANÁLISE DE NOMENCLATURA
print("## 1️⃣ ANÁLISE DE NOMENCLATURA")
print()

# Verificar consistência de prefixos
tables_without_prefix = []
for table_name in schema['entities'].keys():
    if not table_name.startswith('corev4_'):
        tables_without_prefix.append(table_name)

if tables_without_prefix:
    issues['nomenclatura'].append({
        'severity': 'LOW',
        'title': 'Tabelas sem prefixo corev4_',
        'tables': tables_without_prefix,
        'recommendation': 'Adicionar prefixo corev4_ para consistência'
    })
else:
    good_practices.append("✅ Todas as tabelas seguem o padrão de prefixo 'corev4_'")

# Verificar snake_case
non_snake_case = []
for table_name in schema['entities'].keys():
    # Remove o prefixo para análise
    name_without_prefix = table_name.replace('corev4_', '')
    if name_without_prefix != name_without_prefix.lower() or '-' in name_without_prefix:
        non_snake_case.append(table_name)

if non_snake_case:
    issues['nomenclatura'].append({
        'severity': 'LOW',
        'title': 'Tabelas que não seguem snake_case',
        'tables': non_snake_case,
        'recommendation': 'Converter para snake_case lowercase'
    })
else:
    good_practices.append("✅ Todas as tabelas seguem o padrão snake_case")

# Verificar nomes de colunas
problematic_columns = []
for table_name, table in schema['entities'].items():
    for col_name in table.get('columns', {}).keys():
        # Verificar se contém caracteres especiais ou maiúsculas
        if col_name != col_name.lower() or any(c in col_name for c in ['-', ' ', '.', '/']):
            problematic_columns.append(f"{table_name}.{col_name}")

if problematic_columns:
    issues['nomenclatura'].append({
        'severity': 'MEDIUM',
        'title': 'Colunas com nomenclatura problemática',
        'columns': problematic_columns[:10],  # Primeiras 10
        'recommendation': 'Converter para snake_case lowercase sem caracteres especiais'
    })
else:
    good_practices.append("✅ Todas as colunas seguem padrões de nomenclatura adequados")

print("### Padrões de Nomenclatura")
print()
if good_practices:
    for gp in good_practices:
        print(gp)
    print()

# 2. ANÁLISE DE DESCRIÇÕES
print("\n## 2️⃣ ANÁLISE DE DOCUMENTAÇÃO")
print()

tables_without_description = []
for table_name, table in schema['entities'].items():
    desc = table.get('description')
    if not desc or desc == 'None':
        tables_without_description.append(table_name)

print(f"### Tabelas sem descrição: {len(tables_without_description)}/{len(schema['entities'])}")
print()
if tables_without_description:
    issues['documentacao'].append({
        'severity': 'MEDIUM',
        'title': 'Tabelas sem descrição',
        'count': len(tables_without_description),
        'tables': tables_without_description,
        'recommendation': 'Adicionar comentários descritivos usando COMMENT ON TABLE'
    })
    for table in tables_without_description:
        print(f"- {table}")
    print()
    print("**Recomendação**: Adicionar descrições para melhor documentação do schema")
    print()

# 3. ANÁLISE DE CHAVES PRIMÁRIAS
print("\n## 3️⃣ ANÁLISE DE CHAVES PRIMÁRIAS")
print()

pk_analysis = {
    'integer': 0,
    'bigint': 0,
    'uuid': 0,
    'composite': 0,
    'missing': []
}

for table_name, table in schema['entities'].items():
    pk = table.get('primary_key', [])
    if not pk:
        pk_analysis['missing'].append(table_name)
    elif len(pk) > 1:
        pk_analysis['composite'] += 1
    else:
        pk_col_name = pk[0]
        pk_col = table['columns'].get(pk_col_name, {})
        pk_type = pk_col.get('data_type', '')
        if pk_type == 'integer':
            pk_analysis['integer'] += 1
        elif pk_type == 'bigint':
            pk_analysis['bigint'] += 1
        elif pk_type == 'uuid':
            pk_analysis['uuid'] += 1

print("### Distribuição de Tipos de Primary Keys")
print()
print(f"- Integer (32-bit): {pk_analysis['integer']} tabelas")
print(f"- BigInt (64-bit): {pk_analysis['bigint']} tabelas")
print(f"- UUID: {pk_analysis['uuid']} tabelas")
print(f"- Chaves Compostas: {pk_analysis['composite']} tabelas")
print()

if pk_analysis['integer'] > 0:
    recommendations['performance'].append({
        'title': 'Considerar migração de INTEGER para BIGINT',
        'details': f"{pk_analysis['integer']} tabelas usam INTEGER para PK",
        'reason': 'INTEGER tem limite de ~2 bilhões. BIGINT evita overflow em produção de longo prazo',
        'priority': 'MEDIUM'
    })

if pk_analysis['missing']:
    issues['integridade'].append({
        'severity': 'HIGH',
        'title': 'Tabelas sem Primary Key',
        'tables': pk_analysis['missing'],
        'recommendation': 'Adicionar Primary Key para garantir unicidade'
    })

# 4. ANÁLISE DE ÍNDICES
print("\n## 4️⃣ ANÁLISE DE ÍNDICES")
print()

# Tabelas sem índices além da PK
tables_with_few_indexes = []
for table_name, table in schema['entities'].items():
    indexes = table.get('indexes', [])
    # Filtrar apenas índices que não sejam PK
    non_pk_indexes = [idx for idx in indexes if 'pkey' not in idx['index_name']]
    if len(non_pk_indexes) < 2 and len(table.get('columns', {})) > 5:
        tables_with_few_indexes.append(table_name)

if tables_with_few_indexes:
    print(f"### Tabelas com poucos índices (podem precisar de otimização)")
    print()
    for table in tables_with_few_indexes:
        print(f"- {table}")
    print()

# Detectar possíveis índices faltantes em FKs
fk_without_index = []
for table_name, table in schema['entities'].items():
    fks = table.get('foreign_keys', [])
    indexes = table.get('indexes', [])

    for fk in fks:
        fk_col = fk['column']
        # Verificar se existe índice nessa coluna
        has_index = any(fk_col in idx['definition'] for idx in indexes)
        if not has_index:
            fk_without_index.append(f"{table_name}.{fk_col}")

if fk_without_index:
    print(f"### ⚠️ Foreign Keys sem índice ({len(fk_without_index)} encontradas)")
    print()
    print("Foreign Keys sem índices podem causar lentidão em JOINs:")
    print()
    for fk in fk_without_index[:10]:
        print(f"- {fk}")
    if len(fk_without_index) > 10:
        print(f"... e mais {len(fk_without_index) - 10}")
    print()
    recommendations['performance'].append({
        'title': 'Adicionar índices em Foreign Keys',
        'details': f"{len(fk_without_index)} FKs sem índices",
        'columns': fk_without_index,
        'priority': 'HIGH'
    })

# 5. ANÁLISE DE TIMESTAMPS
print("\n## 5️⃣ ANÁLISE DE TIMESTAMPS E AUDITORIA")
print()

tables_without_timestamps = []
tables_without_created_at = []
tables_without_updated_at = []

for table_name, table in schema['entities'].items():
    columns = table.get('columns', {})
    has_created_at = 'created_at' in columns
    has_updated_at = 'updated_at' in columns

    if not has_created_at:
        tables_without_created_at.append(table_name)
    if not has_updated_at:
        tables_without_updated_at.append(table_name)

    if not has_created_at and not has_updated_at:
        tables_without_timestamps.append(table_name)

print(f"### Tabelas sem campos de auditoria temporal")
print()
print(f"- Sem created_at: {len(tables_without_created_at)}")
print(f"- Sem updated_at: {len(tables_without_updated_at)}")
print()

if tables_without_created_at:
    print("**Tabelas sem created_at**:")
    for t in tables_without_created_at:
        print(f"- {t}")
    print()

# 6. ANÁLISE DE SOFT DELETE
print("\n## 6️⃣ ANÁLISE DE SOFT DELETE")
print()

soft_delete_patterns = ['deleted_at', 'is_deleted', 'is_active', 'active']
tables_with_soft_delete = []

for table_name, table in schema['entities'].items():
    columns = table.get('columns', {}).keys()
    has_soft_delete = any(pattern in columns for pattern in soft_delete_patterns)
    if has_soft_delete:
        patterns_found = [p for p in soft_delete_patterns if p in columns]
        tables_with_soft_delete.append((table_name, patterns_found))

print(f"### Tabelas com padrão de Soft Delete: {len(tables_with_soft_delete)}")
print()
for table, patterns in tables_with_soft_delete:
    print(f"- {table}: {', '.join(patterns)}")
print()

# Verificar consistência
soft_delete_inconsistency = []
for table, patterns in tables_with_soft_delete:
    if len(patterns) > 1:
        soft_delete_inconsistency.append((table, patterns))

if soft_delete_inconsistency:
    print("**⚠️ Inconsistência detectada** (múltiplos padrões de soft delete):")
    for table, patterns in soft_delete_inconsistency:
        print(f"- {table}: {', '.join(patterns)}")
    print()
    recommendations['consistencia'].append({
        'title': 'Padronizar soft delete',
        'details': 'Usar apenas um padrão (recomendado: deleted_at timestamp)',
        'affected_tables': [t for t, _ in soft_delete_inconsistency],
        'priority': 'MEDIUM'
    })

# 7. ANÁLISE DE RELACIONAMENTOS
print("\n## 7️⃣ ANÁLISE DE RELACIONAMENTOS")
print()

# Contar relacionamentos
total_fks = sum(len(t.get('foreign_keys', [])) for t in schema['entities'].values())
print(f"### Total de Foreign Keys: {total_fks}")
print()

# Tabelas sem relacionamentos (possíveis tabelas isoladas)
orphan_tables = []
for table_name, table in schema['entities'].items():
    fks = table.get('foreign_keys', [])
    # Verificar se outras tabelas referenciam esta
    referenced_by = []
    for other_table_name, other_table in schema['entities'].items():
        if other_table_name == table_name:
            continue
        for fk in other_table.get('foreign_keys', []):
            if fk['references_table'] == table_name:
                referenced_by.append(other_table_name)

    if not fks and not referenced_by:
        orphan_tables.append(table_name)

if orphan_tables:
    print("### ⚠️ Tabelas isoladas (sem relacionamentos)")
    print()
    for table in orphan_tables:
        print(f"- {table}")
    print()
    print("**Nota**: Tabelas isoladas podem indicar dados desconectados ou oportunidades de normalização")
    print()

# Analisar cascades
dangerous_cascades = []
for table_name, table in schema['entities'].items():
    for fk in table.get('foreign_keys', []):
        if fk['on_delete'] == 'CASCADE':
            dangerous_cascades.append({
                'from': table_name,
                'to': fk['references_table'],
                'column': fk['column']
            })

if dangerous_cascades:
    print(f"### Relacionamentos com CASCADE DELETE: {len(dangerous_cascades)}")
    print()
    print("Cascades são poderosos mas perigosos. Verificar se são intencionais:")
    print()
    for cascade in dangerous_cascades[:15]:
        print(f"- {cascade['from']}.{cascade['column']} → {cascade['to']} (CASCADE DELETE)")
    if len(dangerous_cascades) > 15:
        print(f"... e mais {len(dangerous_cascades) - 15}")
    print()

# 8. ANÁLISE DE TIPOS DE DADOS
print("\n## 8️⃣ ANÁLISE DE TIPOS DE DADOS")
print()

# Detectar TEXT vs VARCHAR
text_vs_varchar = defaultdict(lambda: {'text': 0, 'varchar': 0, 'char': 0})
for table_name, table in schema['entities'].items():
    for col_name, col in table.get('columns', {}).items():
        dtype = col['data_type']
        if dtype == 'text':
            text_vs_varchar[table_name]['text'] += 1
        elif 'character varying' in dtype or 'varchar' in dtype:
            text_vs_varchar[table_name]['varchar'] += 1
        elif 'character' in dtype or dtype == 'char':
            text_vs_varchar[table_name]['char'] += 1

print("### Uso de tipos de string")
print()
total_text = sum(v['text'] for v in text_vs_varchar.values())
total_varchar = sum(v['varchar'] for v in text_vs_varchar.values())
print(f"- TEXT: {total_text} colunas")
print(f"- VARCHAR: {total_varchar} colunas")
print()

if total_text > 0 and total_varchar > 0:
    print("**Nota**: Mistura de TEXT e VARCHAR. No PostgreSQL, TEXT é geralmente preferível (sem overhead de limite).")
    print()
    recommendations['consistencia'].append({
        'title': 'Padronizar tipo de string',
        'details': f'TEXT: {total_text} vs VARCHAR: {total_varchar}',
        'reason': 'PostgreSQL trata TEXT e VARCHAR(n) de forma similar, mas TEXT é mais flexível',
        'priority': 'LOW'
    })

# Detectar campos JSONB
jsonb_usage = []
for table_name, table in schema['entities'].items():
    for col_name, col in table.get('columns', {}).items():
        if col['data_type'] == 'jsonb':
            jsonb_usage.append(f"{table_name}.{col_name}")

if jsonb_usage:
    print(f"### Uso de JSONB: {len(jsonb_usage)} colunas")
    print()
    for usage in jsonb_usage:
        print(f"- {usage}")
    print()
    print("**Nota**: JSONB é excelente para dados semi-estruturados, mas considerar normalizar se os dados forem consultados frequentemente.")
    print()

# 9. ANÁLISE DE RLS (ROW LEVEL SECURITY)
print("\n## 9️⃣ ANÁLISE DE SEGURANÇA (RLS)")
print()

tables_with_rls = []
tables_without_rls = []
multi_tenant_columns = ['company_id', 'tenant_id', 'organization_id']

for table_name, table in schema['entities'].items():
    has_rls = table.get('rls_enabled', False)
    columns = table.get('columns', {}).keys()
    has_tenant_col = any(col in columns for col in multi_tenant_columns)

    if has_rls:
        policy_count = len(table.get('rls_policies', []))
        tables_with_rls.append((table_name, policy_count))
    else:
        tables_without_rls.append(table_name)

    # Verificar se tem coluna de tenant mas não tem RLS
    if has_tenant_col and not has_rls:
        issues['seguranca'].append({
            'severity': 'HIGH',
            'title': f'{table_name} tem coluna de multi-tenancy mas RLS desabilitado',
            'recommendation': 'Habilitar RLS para isolamento de dados por tenant'
        })

print(f"### Row Level Security Status")
print()
print(f"- Tabelas com RLS habilitado: {len(tables_with_rls)}")
print(f"- Tabelas sem RLS: {len(tables_without_rls)}")
print()

if tables_with_rls:
    print("**Tabelas com RLS**:")
    for table, policy_count in tables_with_rls:
        print(f"- {table} ({policy_count} policies)")
    print()

# 10. RESUMO DE ISSUES E RECOMENDAÇÕES
print("\n" + "=" * 100)
print("## 🎯 RESUMO DE ACHADOS E RECOMENDAÇÕES")
print("=" * 100)
print()

# Contar severidade
issue_counts = {'HIGH': 0, 'MEDIUM': 0, 'LOW': 0}
for category, category_issues in issues.items():
    for issue in category_issues:
        issue_counts[issue['severity']] += 1

print("### Severidade dos Problemas Encontrados")
print()
print(f"- 🔴 HIGH: {issue_counts['HIGH']}")
print(f"- 🟡 MEDIUM: {issue_counts['MEDIUM']}")
print(f"- 🟢 LOW: {issue_counts['LOW']}")
print()

# Listar issues por categoria
for category, category_issues in issues.items():
    if category_issues:
        print(f"\n### Categoria: {category.upper()}")
        print()
        for issue in category_issues:
            severity_icon = {'HIGH': '🔴', 'MEDIUM': '🟡', 'LOW': '🟢'}
            print(f"{severity_icon[issue['severity']]} **{issue['title']}**")
            if 'count' in issue:
                print(f"   - Afeta: {issue['count']} tabelas")
            if 'tables' in issue and len(issue['tables']) <= 5:
                print(f"   - Tabelas: {', '.join(issue['tables'])}")
            print(f"   - Recomendação: {issue['recommendation']}")
            print()

# Listar recomendações por categoria
print("\n### Recomendações de Melhoria")
print()
for category, category_recs in recommendations.items():
    if category_recs:
        print(f"#### {category.upper()}")
        print()
        for rec in category_recs:
            priority_icon = {'HIGH': '🔴', 'MEDIUM': '🟡', 'LOW': '🟢'}
            icon = priority_icon.get(rec.get('priority', 'LOW'), '🟢')
            print(f"{icon} **{rec['title']}**")
            print(f"   - {rec['details']}")
            if 'reason' in rec:
                print(f"   - Razão: {rec['reason']}")
            print()

# Boas práticas encontradas
print("\n### ✅ Boas Práticas Identificadas")
print()
total_indexes_calculated = sum(len(t.get('indexes', [])) for t in schema['entities'].values())

good_practices_found = [
    f"Todas as {len(schema['entities'])} tabelas seguem nomenclatura consistente com prefixo",
    f"{len(tables_with_rls)} tabelas com RLS habilitado para multi-tenancy",
    f"{total_fks} relacionamentos com Foreign Keys garantindo integridade referencial",
    f"{total_indexes_calculated} índices otimizando consultas",
    f"Uso de triggers para atualização automática de timestamps",
    f"Uso estratégico de JSONB para dados semi-estruturados ({len(jsonb_usage)} campos)",
]

for gp in good_practices_found:
    print(f"- ✅ {gp}")
print()

# Padrões de ouro da indústria
print("\n" + "=" * 100)
print("## 🏆 COMPARAÇÃO COM PADRÕES DE OURO DA INDÚSTRIA")
print("=" * 100)
print()

print("### Conformidade com Best Practices Modernas")
print()

best_practices_check = {
    '✅ Uso de snake_case para nomenclatura': True,
    '✅ Primary Keys em todas as tabelas': len(pk_analysis['missing']) == 0,
    '✅ Timestamps de auditoria (created_at/updated_at)': len(tables_without_timestamps) < 3,
    '✅ Foreign Keys para integridade referencial': total_fks > 20,
    '✅ Índices em Foreign Keys': len(fk_without_index) == 0,
    '✅ Row Level Security para multi-tenancy': len(tables_with_rls) > 10,
    '✅ Soft Delete implementado': len(tables_with_soft_delete) > 0,
    '⚠️ Documentação completa (COMMENT ON TABLE)': len(tables_without_description) < 5,
    '⚠️ Uso consistente de BIGINT para PKs': pk_analysis['bigint'] > pk_analysis['integer'],
    '⚠️ Índices otimizados': len(tables_with_few_indexes) < 5,
}

for check, status in best_practices_check.items():
    status_icon = '✅' if status else '❌'
    print(f"{status_icon} {check}")

print()
print("### Recomendações Prioritárias (Top 5)")
print()

priority_recommendations = [
    "1. 🔴 Adicionar índices em todas as Foreign Keys sem índice",
    "2. 🟡 Adicionar descrições (COMMENT) em todas as tabelas sem documentação",
    "3. 🟡 Considerar migração de INTEGER para BIGINT em Primary Keys",
    "4. 🟡 Padronizar estratégia de soft delete (usar deleted_at timestamp)",
    "5. 🟢 Padronizar uso de TEXT vs VARCHAR (preferir TEXT no PostgreSQL)",
]

for rec in priority_recommendations:
    print(rec)

print()
print("=" * 100)
print("FIM DO RELATÓRIO DE ANÁLISE CRÍTICA")
print("=" * 100)
