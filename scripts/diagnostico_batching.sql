-- ════════════════════════════════════════════════════════════════
-- DIAGNÓSTICO COMPLETO: MESSAGE BATCHING
-- ════════════════════════════════════════════════════════════════

\echo ''
\echo '═══════════════════════════════════════════════════════════'
\echo 'TESTE 1: Verificar se migration foi executada'
\echo '═══════════════════════════════════════════════════════════'

SELECT
  CASE
    WHEN COUNT(*) = 3 THEN '✅ PASSOU: Todas as 3 colunas existem'
    ELSE '❌ FALHOU: Faltam ' || (3 - COUNT(*))::text || ' colunas'
  END as status,
  string_agg(column_name, ', ') as colunas_encontradas
FROM information_schema.columns
WHERE table_name = 'corev4_chats'
  AND column_name IN ('batch_collecting', 'batch_expires_at', 'batch_messages');

\echo ''
\echo 'Colunas que deveriam existir:'
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'corev4_chats'
  AND column_name IN ('batch_collecting', 'batch_expires_at', 'batch_messages')
ORDER BY column_name;

\echo ''
\echo '═══════════════════════════════════════════════════════════'
\echo 'TESTE 2: Verificar se há batches sendo coletados'
\echo '═══════════════════════════════════════════════════════════'

SELECT
  CASE
    WHEN COUNT(*) > 0 THEN '✅ PASSOU: ' || COUNT(*)::text || ' chats com dados de batch'
    ELSE '❌ FALHOU: Nenhum chat com batch_collecting ou batch_messages'
  END as status
FROM corev4_chats
WHERE batch_collecting = TRUE
   OR batch_messages IS NOT NULL;

\echo ''
\echo 'Últimos 5 chats (ver status de batch):'
SELECT
  id,
  SUBSTRING(whatsapp_number, 1, 15) as whatsapp,
  batch_collecting,
  batch_expires_at,
  CASE
    WHEN batch_messages IS NULL THEN 'NULL'
    WHEN jsonb_array_length(batch_messages) = 0 THEN 'EMPTY'
    ELSE jsonb_array_length(batch_messages)::text || ' msgs'
  END as batch_msgs
FROM corev4_chats
ORDER BY id DESC
LIMIT 5;

\echo ''
\echo '═══════════════════════════════════════════════════════════'
\echo 'TESTE 3: Verificar se VIEW existe'
\echo '═══════════════════════════════════════════════════════════'

SELECT
  CASE
    WHEN COUNT(*) > 0 THEN '✅ PASSOU: View v_llm_pricing_active existe'
    ELSE '❌ FALHOU: View não encontrada'
  END as status
FROM information_schema.views
WHERE table_name = 'v_llm_pricing_active';

\echo ''
\echo '═══════════════════════════════════════════════════════════'
\echo 'TESTE 4: Contar execuções recentes do One Flow'
\echo '═══════════════════════════════════════════════════════════'

\echo 'Últimas execuções (últimos 5 minutos):'
SELECT
  COUNT(*) as total_execucoes,
  COUNT(DISTINCT contact_id) as contatos_unicos,
  CASE
    WHEN COUNT(*) > COUNT(DISTINCT contact_id) * 2 THEN
      '⚠️ ALERTA: Múltiplas execuções por contato (batching pode não estar funcionando)'
    ELSE
      '✅ Normal'
  END as analise
FROM corev4_messages
WHERE sender_type = 'assistant'
  AND created_at > NOW() - INTERVAL '5 minutes';

\echo ''
\echo 'Mensagens por contato (últimos 5 min):'
SELECT
  contact_id,
  COUNT(*) as num_respostas,
  string_agg(SUBSTRING(message_content, 1, 30), ' | ') as previews
FROM corev4_messages
WHERE sender_type = 'assistant'
  AND created_at > NOW() - INTERVAL '5 minutes'
GROUP BY contact_id
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC
LIMIT 5;

\echo ''
\echo '═══════════════════════════════════════════════════════════'
\echo 'RESUMO DO DIAGNÓSTICO'
\echo '═══════════════════════════════════════════════════════════'
\echo ''
\echo 'Se todos os testes passaram:'
\echo '  ✅ Migration executada'
\echo '  ✅ Batches sendo coletados'
\echo '  ✅ View de pricing existe'
\echo '  ✅ Execuções normais'
\echo ''
\echo 'Se algum falhou, veja a solução no output acima.'
\echo ''
