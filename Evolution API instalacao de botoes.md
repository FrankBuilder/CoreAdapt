# Guia técnico: Botões interativos na Evolution API v2 com n8n

A Evolution API v2 suporta três tipos de botões interativos via endpoints específicos, mas **botões no modo Baileys (WhatsApp Web) apresentam instabilidade conhecida** em versões recentes (v2.2.3+). Para cenários de aquecimento com opt-out, as **listas interativas são mais estáveis** que reply buttons. O segredo para evitar banimento está na combinação de aquecimento progressivo (mínimo 14 dias), delays humanizados entre envios (20-40 segundos), e botão de opt-out obrigatório na primeira mensagem — isso remove as opções "Denunciar" e "Bloquear" quando o usuário interage.

---

## Endpoints e payloads para cada tipo de botão

A Evolution API v2 oferece dois endpoints principais funcionais para mensagens interativas. Todos requerem header `apikey` para autenticação.

### Reply Buttons (botões de resposta rápida)

**Endpoint:** `POST /message/sendButtons/{instance}`

**Headers necessários:**
```
Content-Type: application/json
apikey: SUA_API_KEY_AQUI
```

**Payload completo:**
```json
{
  "number": "5511999999999",
  "title": "Confirmação de Interesse",
  "description": "Olá! Somos da Empresa X. Deseja receber informações sobre nossos produtos?",
  "footer": "Responda clicando em uma opção",
  "buttons": [
    {
      "type": "reply",
      "displayText": "Sim, tenho interesse",
      "id": "interesse_sim"
    },
    {
      "type": "reply",
      "displayText": "Agora não",
      "id": "interesse_nao"
    },
    {
      "type": "reply",
      "displayText": "Não quero receber",
      "id": "optout"
    }
  ],
  "delay": 1500
}
```

**Limitações técnicas:** máximo **3 botões** por mensagem, até **20-25 caracteres** por botão, emojis e formatação não permitidos no texto dos botões.

### List Buttons (listas interativas com seções)

**Endpoint:** `POST /message/sendList/{instance}`

Este formato é **mais estável** que reply buttons no modo Baileys.

**Payload completo:**
```json
{
  "number": "5511999999999",
  "title": "Central de Atendimento",
  "description": "Olá! Como podemos ajudar você hoje?",
  "buttonText": "📋 Ver Opções",
  "footerText": "Empresa X - Atendimento",
  "values": [
    {
      "title": "🛒 Comercial",
      "rows": [
        {
          "title": "Conhecer produtos",
          "description": "Catálogo e novidades",
          "rowId": "comercial_produtos"
        },
        {
          "title": "Solicitar orçamento",
          "description": "Proposta personalizada",
          "rowId": "comercial_orcamento"
        }
      ]
    },
    {
      "title": "🔧 Suporte",
      "rows": [
        {
          "title": "Dúvidas técnicas",
          "description": "Ajuda com produto",
          "rowId": "suporte_tecnico"
        }
      ]
    },
    {
      "title": "⚙️ Preferências",
      "rows": [
        {
          "title": "Não quero mais receber",
          "description": "Cancelar mensagens",
          "rowId": "optout_cancelar"
        }
      ]
    }
  ],
  "delay": 1500
}
```

**Limitações:** máximo **10 itens** no total, até **24 caracteres** por título de item, múltiplas seções permitidas (recomendado até 5).

### Call-to-Action buttons (URL e telefone)

**Situação atual:** botões CTA (URL e telefone) **não funcionam nativamente** no modo Baileys da Evolution API. Existe issue documentada (#1249) reportando erro 400. Para usar CTA buttons, é necessário integrar com **Cloud API oficial da Meta**, que requer templates pré-aprovados.

**Alternativa funcional - usar link no texto:**
```json
{
  "number": "5511999999999",
  "text": "Acesse nosso site: https://empresa.com.br\n\nLigue para nós: (11) 99999-9999"
}
```

---

## Configuração completa no n8n 1.115.3

Existem duas abordagens para integrar Evolution API com n8n: community node dedicado ou HTTP Request node manual.

### Community Node oficial

O node `n8n-nodes-evolution-api` desenvolvido pela OrionDesign oferece integração simplificada.

**Instalação:**
1. Acesse Configurações → Community Nodes
2. Clique em "Instalar"
3. Digite `n8n-nodes-evolution-api`
4. Reinicie o n8n

**Configuração de credenciais:**
- **API URL:** `https://sua-evolution-api.com`
- **API Key:** sua chave de API
- **Instance Name:** nome da sua instância conectada

### HTTP Request Node (configuração manual)

Para controle total sobre os payloads, use o HTTP Request node diretamente.

**Configuração do node para enviar botões:**

```
Method: POST
URL: https://SUA_URL_EVOLUTION/message/sendButtons/NOME_INSTANCIA
Authentication: Header Auth
  - Name: apikey
  - Value: {{ $credentials.evolutionApi.apiKey }}
Body Content Type: JSON
```

**Payload com variáveis dinâmicas do n8n:**
```json
{
  "number": "{{ $json.telefone }}",
  "title": "Olá {{ $json.nome }}!",
  "description": "{{ $json.mensagem_personalizada }}",
  "footer": "Atendimento {{ $now.format('DD/MM/YYYY') }}",
  "buttons": [
    {
      "type": "reply",
      "displayText": "Sim, quero saber mais",
      "id": "interesse_{{ $json.lead_id }}"
    },
    {
      "type": "reply",
      "displayText": "Não tenho interesse",
      "id": "optout_{{ $json.lead_id }}"
    }
  ],
  "delay": {{ Math.floor(Math.random() * (3000 - 1500 + 1)) + 1500 }}
}
```

### Configuração de Webhook no n8n para receber callbacks

**Passo 1 - Criar node Webhook no n8n:**
- Adicione node "Webhook"
- Method: POST
- Path: `evolution-callback`
- Copie a URL gerada: `https://seu-n8n.com/webhook/evolution-callback`

**Passo 2 - Registrar webhook na Evolution API:**

Use HTTP Request node para configurar:

```
POST https://SUA_URL_EVOLUTION/webhook/set/NOME_INSTANCIA
```

```json
{
  "url": "https://seu-n8n.com/webhook/evolution-callback",
  "webhook_by_events": false,
  "webhook_base64": false,
  "events": [
    "MESSAGES_UPSERT",
    "MESSAGES_UPDATE",
    "CONNECTION_UPDATE"
  ]
}
```

---

## Estrutura dos callbacks quando botão é clicado

Todas as respostas de botões chegam via evento `MESSAGES_UPSERT`. Não existe evento separado "button.clicked" — é necessário identificar o tipo de resposta pelo campo `messageType`.

### Callback de Reply Button

Quando usuário clica em botão de resposta rápida:

```json
{
  "event": "messages.upsert",
  "instance": "minha-instancia",
  "data": {
    "key": {
      "id": "BAE5XXXXXXXXXX",
      "remoteJid": "5511999999999@s.whatsapp.net",
      "fromMe": false
    },
    "pushName": "Nome do Cliente",
    "message": {
      "buttonsResponseMessage": {
        "selectedButtonId": "optout",
        "selectedDisplayText": "Não quero receber",
        "contextInfo": {
          "stanzaId": "ID_MENSAGEM_ORIGINAL"
        }
      }
    },
    "messageType": "buttonsResponseMessage",
    "messageTimestamp": 1702300000
  }
}
```

**Campo chave para roteamento:** `selectedButtonId` contém o ID definido no envio.

### Callback de List Button

Quando usuário seleciona item de lista:

```json
{
  "event": "messages.upsert",
  "instance": "minha-instancia",
  "data": {
    "key": {
      "remoteJid": "5511999999999@s.whatsapp.net",
      "fromMe": false
    },
    "pushName": "Nome do Cliente",
    "message": {
      "listResponseMessage": {
        "title": "Não quero mais receber",
        "listType": 1,
        "singleSelectReply": {
          "selectedRowId": "optout_cancelar"
        }
      }
    },
    "messageType": "listResponseMessage"
  }
}
```

**Campo chave para roteamento:** `singleSelectReply.selectedRowId` contém o rowId definido no envio.

### Roteamento no n8n baseado na resposta

**Workflow completo para processar callbacks:**

```
[Webhook Node] → [IF Node: Identifica tipo] → [Switch Node: Roteia por ID]
```

**Expressões para extrair IDs no n8n:**

Para Reply Buttons:
```javascript
{{ $json.data.message.buttonsResponseMessage?.selectedButtonId }}
```

Para List Buttons:
```javascript
{{ $json.data.message.listResponseMessage?.singleSelectReply?.selectedRowId }}
```

**Configuração do Switch Node:**

| Condição | Valor | Ação |
|----------|-------|------|
| `selectedButtonId` equals `optout` | Adicionar à lista de bloqueio |
| `selectedButtonId` equals `interesse_sim` | Iniciar fluxo de vendas |
| `selectedRowId` equals `optout_cancelar` | Processar descadastramento |
| `selectedRowId` equals `comercial_produtos` | Enviar catálogo |

---

## Implementação de opt-out para aquecimento seguro

O botão de opt-out na primeira mensagem é **estratégico para evitar banimento** porque reduz drasticamente denúncias de spam. Quando o usuário tem opção fácil de cancelar, ele raramente clica em "Denunciar" ou "Bloquear".

### Template otimizado para primeira mensagem de prospecção

```json
{
  "number": "5511999999999",
  "title": "Olá! Somos da Empresa X",
  "description": "Vi que você demonstrou interesse em [CONTEXTO]. Posso te enviar informações sobre como podemos ajudar?\n\n💡 [Proposta de valor em 1 linha]",
  "footer": "Responda para continuar ou cancelar",
  "buttons": [
    {
      "type": "reply",
      "displayText": "Sim, quero saber mais",
      "id": "interesse_sim"
    },
    {
      "type": "reply",
      "displayText": "Talvez depois",
      "id": "interesse_depois"
    },
    {
      "type": "reply",
      "displayText": "Não, obrigado",
      "id": "optout"
    }
  ],
  "delay": 2000
}
```

### Processamento automático de opt-out no n8n

**Workflow de detecção e processamento:**

```
[Webhook: evolution-callback]
    → [IF: messageType contém "Response"]
    → [IF: ID contém "optout"]
        → [HTTP Request: Adicionar à blacklist]
        → [HTTP Request: Enviar confirmação Evolution API]
```

**Payload de confirmação de opt-out:**
```json
{
  "number": "{{ $json.data.key.remoteJid.replace('@s.whatsapp.net', '') }}",
  "text": "Você foi descadastrado com sucesso! ✅\n\nNão receberá mais mensagens da Empresa X.\n\nCaso mude de ideia, entre em contato pelo suporte.",
  "delay": 1000
}
```

---

## Estratégia de aquecimento e rate limiting

### Cronograma de aquecimento progressivo

| Fase | Período | Volume diário | Ações |
|------|---------|---------------|-------|
| **Preparação** | Dias 1-3 | 5-10 mensagens | Manual, sem API, contatos conhecidos |
| **Interação** | Dias 4-14 | 20-50 mensagens | Grupos de aquecimento, áudios, status |
| **Integração** | Dias 15-21 | 50-100 mensagens | Conexão com Evolution API, automação leve |
| **Escala** | Dia 22+ | +50/dia | Aumento gradual até 500-1000/dia |

### Configuração de delays humanizados

**Intervalo seguro entre envios:** mínimo **20 segundos**, ideal **20-40 segundos com variação aleatória**.

**Implementação de delay variável no n8n:**

Use node "Wait" após cada envio com expressão:
```javascript
{{ Math.floor(Math.random() * (40 - 20 + 1)) + 20 }}
```

Isso gera delay aleatório entre 20-40 segundos.

**Parâmetro delay na Evolution API:**
O campo `delay` no payload simula "digitando..." antes de enviar (em milissegundos):
```json
{
  "delay": {{ Math.floor(Math.random() * (3000 - 1500 + 1)) + 1500 }}
}
```

### Limites seguros de envio

| Período | Limite seguro | Limite máximo |
|---------|---------------|---------------|
| Por hora | 50-100 mensagens | 200 |
| Por dia | 500-1000 mensagens | 1500 |

**Regra de ouro:** dados recebidos devem ser **maiores ou iguais** aos dados enviados para manter boa reputação.

---

## Troubleshooting de problemas comuns

### Botões não aparecem para o destinatário

**Causa provável:** incompatibilidade do modo Baileys com versões recentes do WhatsApp.

**Soluções:**
1. Use **listas interativas** em vez de reply buttons (mais estáveis)
2. Implemente fallback com mensagem de texto numerada: "Digite 1 para Sim, 2 para Não"
3. Considere usar **enquetes (polls)** como alternativa:

```json
{
  "number": "5511999999999",
  "pollMessage": {
    "name": "Deseja receber nossas novidades?",
    "selectableCount": 1,
    "values": ["Sim, quero receber", "Não, obrigado"]
  }
}
```

### Callbacks não chegam no webhook

**Verificações:**
1. Confirme que URL do webhook está acessível externamente (teste com curl)
2. Verifique se eventos `MESSAGES_UPSERT` estão habilitados na configuração
3. Confirme que `webhook_by_events: false` está configurado (ou ajuste URLs correspondentes)
4. Verifique logs da Evolution API para erros de conexão

**Reconfigurar webhook:**
```
GET https://SUA_URL_EVOLUTION/webhook/find/NOME_INSTANCIA
```

### Erro 400 ao enviar botões CTA

**Causa:** botões URL e telefone não são suportados no modo Baileys.

**Solução:** use Cloud API oficial da Meta para CTA buttons, ou inclua links/telefones diretamente no texto da mensagem.

### Mensagem aparece como "não exibível nesta versão"

**Causa:** estrutura de botões incompatível com versão do WhatsApp do destinatário.

**Soluções:**
1. Simplifique o payload removendo campos opcionais
2. Reduza quantidade de botões para 2
3. Use texto mais curto nos botões (máximo 20 caracteres)
4. Teste com lista interativa como alternativa

---

## Checklist de implementação

**Antes de iniciar disparos em produção:**

- [ ] Chip aquecido por mínimo 14 dias com uso manual
- [ ] Perfil WhatsApp Business completo (foto, descrição, site)
- [ ] Evolution API v2 instalada e instância conectada
- [ ] Webhook configurado e testado no n8n
- [ ] Template de mensagem com botão de opt-out implementado
- [ ] Sistema de processamento de opt-out funcional
- [ ] Delays entre envios configurados (20-40 segundos)
- [ ] Lista de contatos com opt-in documentado
- [ ] Fallback para mensagem de texto caso botões falhem
- [ ] Monitoramento de taxa de bloqueios ativo

**Configurações recomendadas no payload:**

```json
{
  "delay": 2000,
  "linkPreview": false,
  "mentionsEveryOne": false
}
```

A combinação de botões interativos com opt-out visível, aquecimento adequado e delays humanizados reduz significativamente o risco de banimento em cenários de prospecção ativa e aquecimento de listas.