// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Node: Batch: Collect Messages v1.0
// Location: CoreAdapt Main Router Flow (after Normalize, before Route Audio)
// Purpose: Collect rapid-fire messages into batches (3s window)
// Behavior:
//   - First message → Creates batch, returns EMPTY (waits for more)
//   - Subsequent messages → Adds to batch, resets timer, returns EMPTY
//   - After 3s silence → Cron processor combines and sends to One Flow
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const message = $input.first().json;

// ════════════════════════════════════════════════════════
// CONFIGURAÇÃO
// ════════════════════════════════════════════════════════
const BATCH_TIMEOUT_SECONDS = 3;

// ════════════════════════════════════════════════════════
// DADOS DA MENSAGEM
// ════════════════════════════════════════════════════════
const whatsappId = message.whatsapp_id;
const companyId = message.company_id || 1; // Default ou pegar de config

// Verificar se é mensagem válida para batch
if (!whatsappId || message.is_from_me || message.is_broadcast) {
  // Mensagens do bot ou broadcast não fazem batch
  return [{
    json: {
      ...message,
      batch_mode: false,
      batch_reason: 'not_batchable'
    }
  }];
}

// ════════════════════════════════════════════════════════
// STEP 1: Verificar se já existe batch ativo
// ════════════════════════════════════════════════════════

const checkBatchQuery = `
  SELECT
    id,
    contact_id,
    batch_expires_at,
    batch_messages,
    array_length(batch_messages, 1) as message_count,
    EXTRACT(EPOCH FROM (batch_expires_at - NOW())) AS seconds_remaining
  FROM corev4_chats
  WHERE company_id = $1
    AND contact_id = (
      SELECT id FROM corev4_contacts
      WHERE whatsapp = $2 AND company_id = $1
      LIMIT 1
    )
    AND batch_collecting = TRUE
    AND batch_expires_at > NOW()
  LIMIT 1
`;

let batchResult;
try {
  batchResult = await $executeQuery('postgres', checkBatchQuery, [companyId, whatsappId]);
} catch (error) {
  // Se der erro na query, processa normalmente (fail-safe)
  console.error('Batch check failed:', error.message);
  return [{
    json: {
      ...message,
      batch_mode: false,
      batch_reason: 'query_error',
      error: error.message
    }
  }];
}

// ════════════════════════════════════════════════════════
// CENÁRIO 1: Batch já existe - ADICIONAR MENSAGEM
// ════════════════════════════════════════════════════════

if (batchResult && batchResult.length > 0) {
  const batch = batchResult[0];

  // Criar objeto da mensagem para armazenar
  const messageObj = {
    message_id: message.message_id,
    whatsapp_id: message.whatsapp_id,
    message_content: message.message_content,
    message_type: message.message_type,
    media_type: message.media_type,
    has_media: message.has_media,
    media_url: message.media_url,
    transcribed: message.transcribed,
    timestamp: new Date().toISOString(),
    raw: message
  };

  // Adicionar ao array e resetar timer
  const updateBatchQuery = `
    UPDATE corev4_chats
    SET
      batch_messages = array_append(batch_messages, $1::jsonb),
      batch_expires_at = NOW() + INTERVAL '${BATCH_TIMEOUT_SECONDS} seconds',
      last_message_ts = EXTRACT(EPOCH FROM NOW())::bigint,
      last_lead_message_ts = EXTRACT(EPOCH FROM NOW())::bigint,
      updated_at = NOW()
    WHERE id = $2
    RETURNING
      id,
      array_length(batch_messages, 1) as total_messages,
      batch_expires_at
  `;

  try {
    const updateResult = await $executeQuery('postgres', updateBatchQuery, [
      JSON.stringify(messageObj),
      batch.id
    ]);

    console.log(`✅ Batch ${batch.id}: Added message ${updateResult[0].total_messages}/${BATCH_TIMEOUT_SECONDS}s`);

    // RETORNA VAZIO - não processa ainda, aguarda mais mensagens
    return [];

  } catch (error) {
    // Se falhar, processa normalmente (fail-safe)
    console.error('Batch update failed:', error.message);
    return [{
      json: {
        ...message,
        batch_mode: false,
        batch_reason: 'update_error'
      }
    }];
  }
}

// ════════════════════════════════════════════════════════
// CENÁRIO 2: Batch não existe - CRIAR NOVO
// ════════════════════════════════════════════════════════

// Buscar contact_id
const getContactQuery = `
  SELECT id FROM corev4_contacts
  WHERE whatsapp = $1 AND company_id = $2
  LIMIT 1
`;

let contactResult;
try {
  contactResult = await $executeQuery('postgres', getContactQuery, [whatsappId, companyId]);
} catch (error) {
  // Se não achar contato, processa normalmente (pode ser criado depois)
  return [{
    json: {
      ...message,
      batch_mode: false,
      batch_reason: 'contact_not_found'
    }
  }];
}

if (!contactResult || contactResult.length === 0) {
  // Contato ainda não existe, deixa passar (Genesis Flow cria)
  return [{
    json: {
      ...message,
      batch_mode: false,
      batch_reason: 'new_contact'
    }
  }];
}

const contactId = contactResult[0].id;

// Criar objeto da primeira mensagem
const messageObj = {
  message_id: message.message_id,
  whatsapp_id: message.whatsapp_id,
  message_content: message.message_content,
  message_type: message.message_type,
  media_type: message.media_type,
  has_media: message.has_media,
  media_url: message.media_url,
  transcribed: message.transcribed,
  timestamp: new Date().toISOString(),
  raw: message
};

// Criar ou atualizar chat com batch collection ativa
const upsertBatchQuery = `
  INSERT INTO corev4_chats (
    contact_id,
    company_id,
    batch_collecting,
    batch_expires_at,
    batch_messages,
    last_message_ts,
    last_lead_message_ts,
    conversation_open
  ) VALUES (
    $1,
    $2,
    TRUE,
    NOW() + INTERVAL '${BATCH_TIMEOUT_SECONDS} seconds',
    ARRAY[$3::jsonb],
    EXTRACT(EPOCH FROM NOW())::bigint,
    EXTRACT(EPOCH FROM NOW())::bigint,
    TRUE
  )
  ON CONFLICT (contact_id, company_id) DO UPDATE
  SET
    batch_collecting = TRUE,
    batch_expires_at = NOW() + INTERVAL '${BATCH_TIMEOUT_SECONDS} seconds',
    batch_messages = ARRAY[$3::jsonb],
    last_message_ts = EXTRACT(EPOCH FROM NOW())::bigint,
    last_lead_message_ts = EXTRACT(EPOCH FROM NOW())::bigint,
    conversation_open = TRUE,
    updated_at = NOW()
  RETURNING id
`;

try {
  const result = await $executeQuery('postgres', upsertBatchQuery, [
    contactId,
    companyId,
    JSON.stringify(messageObj)
  ]);

  console.log(`🆕 Batch ${result[0].id}: Started for contact ${contactId} (${BATCH_TIMEOUT_SECONDS}s)`);

  // RETORNA VAZIO - aguarda mais mensagens
  return [];

} catch (error) {
  // Se falhar, processa normalmente (fail-safe)
  console.error('Batch creation failed:', error.message);
  return [{
    json: {
      ...message,
      batch_mode: false,
      batch_reason: 'creation_error'
    }
  }];
}
