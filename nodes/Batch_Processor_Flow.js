// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Node: Batch: Process Expired Batches v1.0
// Location: Standalone Cron Flow (runs every 2 seconds)
// Purpose: Find batches where 3s timeout expired and process them
// Flow Structure:
//   1. Cron Trigger (every 2s)
//   2. Fetch Expired Batches (SQL)
//   3. THIS NODE: Combine Messages
//   4. Execute Workflow: CoreAdapt One Flow
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const items = $input.all();

if (!items || items.length === 0) {
  // Nenhum batch expirado, não faz nada
  return [];
}

const results = [];

for (const item of items) {
  const batch = item.json;

  // ════════════════════════════════════════════════════════
  // VALIDAÇÕES
  // ════════════════════════════════════════════════════════

  if (!batch.batch_messages || batch.batch_messages.length === 0) {
    console.log(`⚠️ Batch ${batch.id}: No messages found, skipping`);
    continue;
  }

  // ════════════════════════════════════════════════════════
  // COMBINAR MENSAGENS
  // ════════════════════════════════════════════════════════

  // Parse JSON strings se necessário
  const messages = batch.batch_messages.map(msg => {
    if (typeof msg === 'string') {
      return JSON.parse(msg);
    }
    return msg;
  });

  // Ordenar por timestamp (mais antiga primeiro)
  messages.sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));

  // Pegar primeira mensagem como base
  const baseMessage = messages[0].raw || messages[0];

  // ════════════════════════════════════════════════════════
  // ESTRATÉGIA 1: Combinar só TEXTO
  // ════════════════════════════════════════════════════════

  // Verificar se TODAS são mensagens de texto
  const allText = messages.every(m =>
    !m.has_media &&
    (m.message_type === 'conversation' || m.message_type === 'text' || m.message_type === 'extendedTextMessage')
  );

  if (allText) {
    // Combinar textos com quebra de linha
    const combinedContent = messages
      .map(m => m.message_content || m.transcribed || '')
      .filter(c => c && c.trim())
      .join('\n');

    const combinedMessage = {
      ...baseMessage,
      message_content: combinedContent,
      message_count: messages.length,
      batch_id: batch.id,
      is_batched: true,
      batch_type: 'text_only',
      original_messages: messages,

      // Metadata para tracking
      first_message_at: messages[0].timestamp,
      last_message_at: messages[messages.length - 1].timestamp,
      batch_duration_seconds: (
        new Date(messages[messages.length - 1].timestamp) -
        new Date(messages[0].timestamp)
      ) / 1000
    };

    results.push({
      json: combinedMessage
    });

    console.log(`✅ Batch ${batch.id}: Combined ${messages.length} text messages for contact ${batch.contact_id}`);
    continue;
  }

  // ════════════════════════════════════════════════════════
  // ESTRATÉGIA 2: Tem MÍDIA - Processar SOMENTE A ÚLTIMA
  // ════════════════════════════════════════════════════════

  // Se tem mídia (áudio, imagem, etc), pega só a última mensagem
  // Porque provavelmente as anteriores eram contexto

  const lastMessage = messages[messages.length - 1];
  const previousTexts = messages
    .slice(0, -1)
    .filter(m => !m.has_media)
    .map(m => m.message_content || m.transcribed || '')
    .filter(c => c && c.trim())
    .join('\n');

  const finalMessage = {
    ...lastMessage.raw || lastMessage,
    message_count: messages.length,
    batch_id: batch.id,
    is_batched: true,
    batch_type: 'media_included',
    previous_context: previousTexts || null,
    original_messages: messages,

    // Se a última é áudio e as anteriores são texto, adicionar contexto
    combined_context: previousTexts
      ? `${previousTexts}\n\n[ÁUDIO/MÍDIA]`
      : null,

    // Metadata
    first_message_at: messages[0].timestamp,
    last_message_at: messages[messages.length - 1].timestamp,
    batch_duration_seconds: (
      new Date(messages[messages.length - 1].timestamp) -
      new Date(messages[0].timestamp)
    ) / 1000
  };

  results.push({
    json: finalMessage
  });

  console.log(`✅ Batch ${batch.id}: Processed ${messages.length} messages (media included) for contact ${batch.contact_id}`);
}

// ════════════════════════════════════════════════════════
// RETORNAR MENSAGENS COMBINADAS
// ════════════════════════════════════════════════════════

console.log(`📦 Processed ${results.length} batches`);

return results;
