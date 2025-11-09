# Modelos OpenAI e Google Gemini Disponíveis no n8n AI Agent Node

**Data da pesquisa**: 09 de Novembro de 2025  
**Versão do n8n**: 1.115.3+  
**AI Agent Node**: v2.2+

---

## 📌 IMPORTANTE: Como o n8n carrega os modelos

O n8n **carrega dinamicamente** os modelos disponíveis diretamente da API de cada provedor. Isso significa:

- **Para OpenAI**: O n8n faz um `GET` para `/v1/models` e filtra todos os modelos que começam com `gpt-` (excluindo `gpt-4-vision`)
- **Para Google Gemini**: O n8n carrega os modelos disponíveis através da API do Google AI
- **O que você vê no dropdown** = modelos disponíveis para **sua conta/API key específica**
- A disponibilidade depende do seu nível de assinatura e acesso ao provedor

**Código fonte do n8n** (confirmado em GitHub):
```javascript
// Localizado em: packages/nodes-base/nodes/OpenAi/ChatDescription.ts
typeOptions: {
    loadOptions: {
        routing: {
            request: {
                method: 'GET',
                url: '/v1/models',
            },
            output: {
                postReceive: [
                    {
                        type: 'filter',
                        properties: {
                            pass: "={{ $responseItem.id.startsWith('gpt-') && !$responseItem.id.startsWith('gpt-4-vision') }}",
                        },
                    },
                    // ... sorting and formatting
                ],
            },
        },
    },
}
```

---

## 🔴 MODELOS OPENAI - LISTAGEM COMPLETA ATUAL

### Família GPT-5 (Lançados em Agosto de 2025)

#### GPT-5 (Standard)
- **ID do modelo**: `gpt-5`
- **Contexto**: 272,000 tokens (input) / 128,000 tokens (output)
- **Capacidades**: Multimodal (text, image input), text output
- **Preço**: $1.25/million (input), $10/million (output)
- **Reasoning levels**: minimal, low, medium, high
- **Características especiais**: 
  - Modelo flagship mais avançado da OpenAI
  - Suporta "thinking" (raciocínio) com tokens invisíveis
  - Redução de 45% em erros factuais vs GPT-4o
  - 94.6% no AIME 2025 (matemática)
  - 74.9% no SWE-bench Verified (código)

#### GPT-5 Mini
- **ID do modelo**: `gpt-5-mini`
- **Contexto**: 272,000 tokens (input) / 128,000 tokens (output)
- **Preço**: Significativamente mais barato que GPT-5
- **Características**: Versão otimizada para custo mantendo alta performance

#### GPT-5 Nano
- **ID do modelo**: `gpt-5-nano`
- **Contexto**: 272,000 tokens (input) / 128,000 tokens (output)
- **Preço**: Mais econômico da família GPT-5
- **Características**: Ultra eficiente para tarefas de alto volume

#### GPT-5 Pro (via ChatGPT Pro - $200/mês)
- **ID do modelo**: `gpt-5-pro` (thinking-pro)
- **Disponibilidade**: Apenas via ChatGPT Pro subscription
- **Características**: Parallel test time compute, máximo reasoning

#### GPT-5 Codex
- **ID do modelo**: `gpt-5-codex`
- **Características**: Especializado em geração e análise de código
- **Requer**: Registro prévio para acesso

#### GPT-5 Chat
- **ID do modelo**: `gpt-5-chat`
- **Versão especial**: `gpt-5-chat` (2025-10-03)
- **Características**: Otimizado para inteligência emocional e saúde mental
- **Não requer**: Registro

---

### Família GPT-4.1 (Lançados em Abril de 2025)

#### GPT-4.1
- **ID do modelo**: `gpt-4.1`
- **Contexto**: 1 milhão de tokens
- **Características**:
  - 55% de acerto no SWE-bench Verified (vs 33% do GPT-4o)
  - Melhor em código, instruction-following e long-context
  - Sucessor do GPT-4.5

#### GPT-4.1 Mini
- **ID do modelo**: `gpt-4.1-mini`
- **Características**:
  - Redução de 50% em latência vs GPT-4o
  - 83% mais barato que GPT-4o
  - Excelente custo-benefício

#### GPT-4.1 Nano
- **ID do modelo**: `gpt-4.1-nano`
- **Características**: Versão ultra-leve e econômica

---

### Família GPT-4o (Omni) - AINDA DISPONÍVEL

#### GPT-4o
- **ID do modelo**: `gpt-4o`, `chatgpt-4o-latest`
- **Contexto**: 128K tokens
- **Características**:
  - Multimodal nativo (text + vision)
  - Disponível para usuários free e paid
  - Modelo "legacy" mas ainda amplamente usado

#### GPT-4o Mini
- **ID do modelo**: `gpt-4o-mini`
- **Contexto**: 128K tokens
- **Características**:
  - Versão mais leve e rápida do GPT-4o
  - Excelente custo-benefício
  - Substituído pelo GPT-4.1 Mini na API principal

#### GPT-4o Audio
- **ID do modelo**: `gpt-4o-audio`, `gpt-4o-mini-audio`
- **Características**:
  - Suporte a entrada e saída de áudio
  - Transcrição e síntese de fala

#### GPT-4o Transcribe
- **ID do modelo**: `gpt-4o-transcribe`, `gpt-4o-mini-transcribe`
- **Características**: Transcrição de áudio com suporte multilíngue

#### GPT-4o Mini TTS
- **ID do modelo**: `gpt-4o-mini-tts`
- **Preço**: ¼ do custo do GPT-4o Audio
- **Características**: Síntese de fala expressiva e controlável

---

### Família GPT-4 Turbo - DISPONÍVEL MAS SENDO SUBSTITUÍDA

#### GPT-4 Turbo
- **IDs**: Vários, base `gpt-4`
- **Contexto**: 128K tokens
- **Características**: Predecessor do GPT-4o

#### GPT-4
- **IDs**: Vários, base `gpt-4`
- **Contexto**: 8K-32K tokens (dependendo da versão)
- **Status**: Retirado do ChatGPT em 30/04/2025, ainda disponível via API

---

### Família O-series (Reasoning Models)

#### O3
- **ID do modelo**: `o3`
- **Características**: Modelo de raciocínio avançado
- **Uso**: Matemática complexa, código, STEM

#### O4-mini
- **ID do modelo**: `o4-mini`
- **Características**: Versão compacta de reasoning
- **Status**: Substituído pelo GPT-5 mini

#### O4-mini Deep Research
- **ID do modelo**: `o4-mini-deep-research`
- **Características**: Pesquisa multi-step com citações

#### O3 Deep Research
- **ID do modelo**: `o3-deep-research`
- **Características**: Pesquisa avançada com busca web

#### O1 (séries anteriores)
- **IDs**: `o1`, `o1-preview`, `o1-mini`
- **Características**: Primeiros modelos de reasoning da OpenAI

---

### Modelos de Preview e Busca

#### GPT-4o Search Preview
- **ID do modelo**: `gpt-4o-search-preview`, `gpt-4o-mini-search-preview`
- **Características**: Otimizado para parsing de queries de busca

#### Computer Use Preview
- **ID do modelo**: `computer-use-preview`
- **Características**: Automação de interface gráfica

---

### GPT-3.5 Turbo (LEGACY - NÃO RECOMENDADO)

#### GPT-3.5 Turbo
- **ID do modelo**: `gpt-3.5-turbo`
- **Contexto**: 16K tokens
- **Status**: Desatualizado (conhecimento até setembro 2021)
- **Uso**: Apenas via API, não mais no ChatGPT

---

### Modelos Open Source

#### gpt-oss-120b
- **Características**: 
  - Modelo open weight mais potente da OpenAI
  - Roda em single H100 GPU
  - Licença Apache 2.0

#### gpt-oss-20b
- **Características**: Versão menor open weight

---

### Modelos Especializados

#### GPT Image 1
- **ID do modelo**: `gpt-image-1`
- **Características**: Geração de imagens (substitui DALL·E 3 na API)

#### DALL·E 3
- **Status**: Ainda disponível
- **Preço**: $0.011 (1024x1024 low-quality), $0.167 (1024x1024 high-quality)

#### Whisper
- **Uso**: Transcrição e tradução de áudio
- **Preço**: $0.006 por minuto
- **Status**: Legacy, mas ainda útil para baixo custo

---

## 📊 RESUMO DE MODELOS OPENAI DISPONÍVEIS NO N8N

**Família GPT-5** (Agosto 2025 - MAIS RECENTES):
- gpt-5
- gpt-5-mini
- gpt-5-nano
- gpt-5-pro (requer registro)
- gpt-5-codex (requer registro)
- gpt-5-chat

**Família GPT-4.1** (Abril 2025):
- gpt-4.1
- gpt-4.1-mini
- gpt-4.1-nano

**Família GPT-4o** (ainda disponível):
- gpt-4o
- gpt-4o-mini
- chatgpt-4o-latest
- gpt-4o-audio
- gpt-4o-mini-audio
- gpt-4o-transcribe
- gpt-4o-mini-transcribe
- gpt-4o-mini-tts

**Família GPT-4 Turbo**:
- gpt-4-turbo
- gpt-4 (várias versões)

**O-series** (Reasoning):
- o3
- o4-mini
- o3-deep-research
- o4-mini-deep-research
- o1, o1-preview, o1-mini (séries anteriores)

**Preview/Search**:
- gpt-4o-search-preview
- gpt-4o-mini-search-preview
- computer-use-preview

**Legacy**:
- gpt-3.5-turbo

**IMPORTANTE**: A lista EXATA de modelos que aparece no seu dropdown do n8n depende:
1. Dos modelos que a OpenAI disponibiliza para sua conta
2. Do seu nível de acesso/assinatura
3. De registros específicos (GPT-5 Pro, GPT-5 Codex)

---

## 🟢 MODELOS GOOGLE GEMINI - LISTAGEM COMPLETA ATUAL

### Família Gemini 2.5 (MAIS RECENTES - Novembro 2025)

#### Gemini 2.5 Pro
- **ID do modelo**: `gemini-2.5-pro`
- **Tipo**: Stable
- **Contexto**: 1,048,576 tokens (input) / 65,536 tokens (output)
- **Capacidades**:
  - Input: Audio, images, video, text, PDF
  - Output: Text
- **Características especiais**:
  - Modelo de "thinking" (raciocínio) state-of-the-art
  - Análise de grandes datasets, codebases e documentos
  - Suporte a: Batch API, Caching, Code Execution, File Search, Function Calling
  - Grounding (Google Maps, Search), Structured Outputs, URL Context
- **Modalidade de raciocínio**: Thinking suportado

#### Gemini 2.5 Pro TTS
- **ID do modelo**: `gemini-2.5-pro-preview-tts`
- **Tipo**: Preview
- **Contexto**: 8,192 tokens (input) / 16,384 tokens (output)
- **Capacidades**:
  - Input: Text
  - Output: Audio
- **Características**: Text-to-Speech com suporte a múltiplos speakers e 24 idiomas

---

#### Gemini 2.5 Flash
- **ID do modelo**: `gemini-2.5-flash`
- **Tipo**: Stable
- **Contexto**: 1,048,576 tokens (input) / 65,536 tokens (output)
- **Capacidades**:
  - Input: Text, images, video, audio
  - Output: Text
- **Características especiais**:
  - Melhor modelo em termos de preço-performance
  - Ideal para: processamento em larga escala, baixa latência, alto volume
  - 22% mais eficiente que versão anterior (#2 no LMarena)
  - Thinking, agentic use cases
  - Suporte completo: Batch, Caching, Code Execution, File Search, Function Calling, Grounding

#### Gemini 2.5 Flash Preview
- **ID do modelo**: `gemini-2.5-flash-preview-09-2025`
- **Tipo**: Preview (Setembro 2025)
- **Contexto**: 1,048,576 tokens (input) / 65,536 tokens (output)
- **Características**: Versão preview com melhorias incrementais

---

#### Gemini 2.5 Flash Image (aka "nano banana" 🍌)
- **ID do modelo**: `gemini-2.5-flash-image`
- **Tipo**: Stable
- **Contexto**: 65,536 tokens (input) / 32,768 tokens (output)
- **Capacidades**:
  - Input: Images e text
  - Output: Images e text
- **Características especiais**:
  - **Geração nativa de imagens**
  - Edição de imagens com alta consistência
  - Geração de histórias visuais
  - **Requer**: Plano Blaze (pay-as-you-go) para uso

#### Gemini 2.5 Flash Image Preview
- **ID do modelo**: `gemini-2.5-flash-image-preview`
- **Tipo**: Preview
- **Características**: Versão preview do modelo de imagem

---

#### Gemini 2.5 Flash Live API
- **ID do modelo**: 
  - `gemini-2.5-flash-native-audio-preview-09-2025`
  - `gemini-live-2.5-flash-preview` (deprecated 09/12/2025)
- **Tipo**: Preview
- **Contexto**: 131,072 tokens (input) / 8,192 tokens (output)
- **Capacidades**:
  - Input: Audio, video, text
  - Output: Audio e text
- **Características especiais**:
  - **Live API** para conversação em tempo real
  - 30+ vozes distintas, 24+ idiomas
  - Áudio proativo (distingue speaker de background)
  - Responde a expressão emocional e tom
  - Function calling, Search grounding, Thinking
  - Ideal para: experiências conversacionais bidirecionais

#### Gemini 2.5 Flash TTS
- **ID do modelo**: `gemini-2.5-flash-preview-tts`
- **Tipo**: Preview
- **Contexto**: 8,192 tokens (input) / 16,384 tokens (output)
- **Capacidades**:
  - Input: Text
  - Output: Audio
- **Características**: Text-to-Speech com controle de expressão e estilo

---

#### Gemini 2.5 Flash-Lite
- **ID do modelo**: `gemini-2.5-flash-lite`
- **Tipo**: Stable
- **Contexto**: 1,048,576 tokens (input) / 65,536 tokens (output)
- **Capacidades**:
  - Input: Text, image, video, audio, PDF
  - Output: Text
- **Características especiais**:
  - **Modelo mais rápido** da família Flash
  - Otimizado para custo-eficiência e alto throughput
  - Ideal para tarefas simples em grande volume
  - Suporte a: Batch, Caching, Code Execution, Function Calling, Grounding, Thinking

#### Gemini 2.5 Flash-Lite Preview
- **ID do modelo**: `gemini-2.5-flash-lite-preview-09-2025`
- **Tipo**: Preview (Setembro 2025)
- **Contexto**: 1,048,576 tokens (input) / 65,536 tokens (output)

---

### Família Gemini 2.0 (Segunda Geração - ainda disponível)

#### Gemini 2.0 Flash
- **ID do modelo**: 
  - `gemini-2.0-flash` (latest)
  - `gemini-2.0-flash-001` (stable)
  - `gemini-2.0-flash-exp` (experimental)
- **Contexto**: 1,048,576 tokens (input) / 8,192 tokens (output)
- **Capacidades**:
  - Input: Audio, images, video, text
  - Output: Text
- **Características especiais**:
  - Modelo "workhorse" de segunda geração
  - 1M token context window
  - Tool use nativo superior
  - Velocidade aprimorada
  - Thinking: Experimental
  - Suporte a: Live API, Batch, Caching, Code Execution, Function Calling, Grounding

#### Gemini 2.0 Flash Image
- **ID do modelo**: `gemini-2.0-flash-preview-image-generation`
- **Tipo**: Preview
- **Contexto**: 32,768 tokens (input) / 8,192 tokens (output)
- **Capacidades**:
  - Input: Audio, images, video, text
  - Output: Text e images
- **Características**: Geração nativa de imagens
- **Restrição**: Não disponível em vários países da Europa, Oriente Médio e África

#### Gemini 2.0 Flash Live
- **ID do modelo**: `gemini-2.0-flash-live-001` (deprecated 09/12/2025)
- **Tipo**: Preview
- **Contexto**: 1,048,576 tokens (input) / 8,192 tokens (output)
- **Capacidades**:
  - Input: Audio, video, text
  - Output: Text e audio
- **Características**: Live API para conversação em tempo real

---

#### Gemini 2.0 Flash-Lite
- **ID do modelo**: 
  - `gemini-2.0-flash-lite` (latest)
  - `gemini-2.0-flash-lite-001` (stable)
- **Contexto**: 1,048,576 tokens (input) / 8,192 tokens (output)
- **Capacidades**:
  - Input: Audio, images, video, text
  - Output: Text
- **Características**:
  - Versão small workhorse de segunda geração
  - Otimizado para custo e baixa latência
  - 1M token context window
  - Não suporta: Thinking, Code Execution, File Search, Grounding com Maps

---

### Modelos Legados (DEPRECATED)

#### Gemini 1.5 Pro
- **Status**: **Totalmente retirado para novos projetos desde 29/04/2025**
- Usuários legacy podem manter acesso

#### Gemini 1.5 Flash
- **Status**: **Totalmente retirado para novos projetos desde 29/04/2025**
- Usuários legacy podem manter acesso

#### Gemini 1.0
- **Status**: Todos os modelos Gemini 1.0 estão retirados
- **Recomendação**: Migrar para Gemini 2.5 Flash-Lite

---

### Modelos Especializados

#### Gemini Robotics-ER 1.5
- **ID do modelo**: `gemini-robotics-er-1.5`
- **Tipo**: Preview
- **Características**: Especializado em compreensão espacial e raciocínio para robótica

#### Gemini 2.5 Pro Deep Think
- **ID**: (experimental, ainda não lançado publicamente)
- **Características**: Modo de reasoning experimental para 2.5 Pro
- **Uso**: Matemática e código extremamente complexos

---

## 📊 RESUMO DE MODELOS GOOGLE GEMINI DISPONÍVEIS NO N8N

**Família Gemini 2.5** (Novembro 2025 - MAIS RECENTES):
- gemini-2.5-pro
- gemini-2.5-pro-preview-tts
- gemini-2.5-flash (stable)
- gemini-2.5-flash-preview-09-2025
- gemini-2.5-flash-image (stable) 🍌
- gemini-2.5-flash-image-preview
- gemini-2.5-flash-native-audio-preview-09-2025
- gemini-live-2.5-flash-preview (deprecated 09/12/2025)
- gemini-2.5-flash-preview-tts
- gemini-2.5-flash-lite (stable)
- gemini-2.5-flash-lite-preview-09-2025

**Família Gemini 2.0** (ainda disponível):
- gemini-2.0-flash (latest)
- gemini-2.0-flash-001 (stable)
- gemini-2.0-flash-exp (experimental)
- gemini-2.0-flash-preview-image-generation
- gemini-2.0-flash-live-001 (deprecated 09/12/2025)
- gemini-2.0-flash-lite (latest)
- gemini-2.0-flash-lite-001 (stable)

**Modelos Especializados**:
- gemini-robotics-er-1.5

**IMPORTANT**: Gemini 1.5 e 1.0 foram totalmente deprecated

---

## 🔄 VERSIONING E NAMING PATTERNS

### OpenAI
Os modelos da OpenAI seguem várias convenções de nomenclatura:
- Numeração direta: `gpt-5`, `gpt-4.1`, `gpt-4o`
- Sufixos de tamanho: `-mini`, `-nano`
- Sufixos funcionais: `-audio`, `-transcribe`, `-tts`, `-codex`
- Aliases dinâmicos: `chatgpt-4o-latest`

### Google Gemini
Os modelos Gemini seguem padrões específicos de versionamento:

**Stable** (produção):
- Formato: `gemini-2.5-flash`
- Não muda, recomendado para produção

**Preview** (pode ser usado em produção):
- Formato: `gemini-2.5-flash-preview-09-2025`
- Billing habilitado, deprecado com 2 semanas de aviso

**Latest** (alias dinâmico):
- Formato: `gemini-flash-latest`
- Aponta para última release (stable/preview/experimental)
- Hot-swapped em cada novo release

**Experimental** (não recomendado para produção):
- Formato: `gemini-2.0-flash-exp`
- Rate limits mais restritivos
- Disponibilidade sujeita a mudanças

---

## 🌍 CONTEXT WINDOWS - COMPARAÇÃO

### OpenAI
| Modelo | Input | Output |
|--------|-------|--------|
| GPT-5 | 272K tokens | 128K tokens |
| GPT-5 Mini/Nano | 272K tokens | 128K tokens |
| GPT-4.1 | 1M tokens | - |
| GPT-4o | 128K tokens | - |
| GPT-4 Turbo | 128K tokens | - |
| GPT-4 | 8K-32K tokens | - |
| GPT-3.5 Turbo | 16K tokens | - |

### Google Gemini
| Modelo | Input | Output |
|--------|-------|--------|
| Gemini 2.5 Pro | 1,048,576 tokens | 65,536 tokens |
| Gemini 2.5 Flash | 1,048,576 tokens | 65,536 tokens |
| Gemini 2.5 Flash-Lite | 1,048,576 tokens | 65,536 tokens |
| Gemini 2.5 Flash Image | 65,536 tokens | 32,768 tokens |
| Gemini 2.5 Flash Live | 131,072 tokens | 8,192 tokens |
| Gemini 2.0 Flash | 1,048,576 tokens | 8,192 tokens |
| Gemini 2.0 Flash-Lite | 1,048,576 tokens | 8,192 tokens |

**Vencedor em contexto**: Gemini com **1M+ tokens** vs OpenAI com **272K tokens**

---

## 💰 CONSIDERAÇÕES DE PREÇO

### OpenAI
- **GPT-5**: $1.25/M input, $10/M output (50% mais barato que GPT-4o no input)
- **GPT-5 Mini**: Significativamente mais barato
- **GPT-5 Nano**: Mais econômico da família
- **GPT-4.1 Mini**: 83% mais barato que GPT-4o

### Google Gemini
- **Flash**: Melhor preço-performance
- **Flash-Lite**: Otimizado para custo e alto throughput
- **Pro**: Premium pricing, máxima capacidade
- **Batch API**: Até 90% de desconto em requisições não urgentes

---

## 🚀 CAPACIDADES ESPECIAIS POR PROVEDOR

### OpenAI - Recursos Únicos
✅ GPT-5 "Thinking" com reasoning invisível  
✅ Parallel test time compute (GPT-5 Pro)  
✅ Computer Use (automação de GUI)  
✅ Deep Research models (pesquisa multi-step)  
✅ Modelos open source (gpt-oss-120b/20b)  
✅ Reasoning effort configurável (minimal/low/medium/high)  
✅ Audio nativo (input/output) no GPT-4o  
✅ Foco em saúde mental (GPT-5 Chat)  

### Google Gemini - Recursos Únicos
✅ Contexto de 1M+ tokens (maior do mercado)  
✅ Live API com conversação bidirecional  
✅ Geração nativa de imagens (2.5 Flash Image)  
✅ Native audio com 30+ vozes, 24+ idiomas  
✅ Áudio proativo (detecta context vs background)  
✅ Grounding com Google Maps  
✅ Grounding com Google Search integrado  
✅ Robotics-specific model (ER 1.5)  
✅ Suporte a 140+ idiomas (Gemma 3n)  
✅ Video generation (Veo 3/3.1)  
✅ Lyria RealTime (geração de música ao vivo)  

---

## ⚡ GUIA DE SELEÇÃO RÁPIDA

### Quando usar OpenAI:
- **GPT-5**: Máxima qualidade, menor hallucination, reasoning complexo
- **GPT-5 Mini**: Equilíbrio custo-benefício com alta qualidade
- **GPT-5 Nano**: Tarefas simples em altíssimo volume
- **GPT-4.1**: Codebases enormes (1M context), debugging avançado
- **GPT-4o**: Multimodal estabelecido, disponível free tier
- **O-series**: Matemática complexa, STEM, multi-step reasoning

### Quando usar Google Gemini:
- **2.5 Pro**: Análise de grandes datasets, codebases, documentos longos
- **2.5 Flash**: Melhor preço-performance, uso geral agentic
- **2.5 Flash-Lite**: Alto throughput, baixíssima latência
- **2.5 Flash Image**: Geração/edição de imagens consistentes
- **2.5 Flash Live**: Conversação em tempo real, voice assistants
- **2.0 Flash**: Contexto de 1M tokens com tool use nativo

---

## 📚 FONTES E REFERÊNCIAS

### OpenAI
1. **OpenAI Platform Docs**: https://platform.openai.com/docs/models
2. **Introducing GPT-5** (Official Blog): https://openai.com/index/introducing-gpt-5/
3. **GPT-5 Launch Page**: https://openai.com/gpt-5/
4. **Azure OpenAI Documentation**: https://learn.microsoft.com/en-us/azure/ai-foundry/openai/concepts/models
5. **Simon Willison - GPT-5 Analysis**: https://simonwillison.net/2025/Aug/7/gpt-5/
6. **DataStudios - All OpenAI Models 2025**: https://www.datastudios.org/post/all-the-openai-api-models-in-2025-complete-overview-of-gpt-5-o-series-and-multimodal-ai
7. **Zapier - OpenAI Models Guide**: https://zapier.com/blog/openai-models/
8. **ScrumLaunch - OpenAI Models Comparison**: https://www.scrumlaunch.com/blog/openai-gpt-models-differences

### Google Gemini
1. **Gemini API Models Page**: https://ai.google.dev/gemini-api/docs/models
2. **Gemini API Changelog**: https://ai.google.dev/gemini-api/docs/changelog
3. **Google Cloud Vertex AI Models**: https://docs.cloud.google.com/vertex-ai/generative-ai/docs/models
4. **Firebase AI Logic Models**: https://firebase.google.com/docs/ai-logic/models
5. **Gemini I/O Updates (Developer Blog)**: https://developers.googleblog.com/en/gemini-api-io-updates/
6. **Android Gemini Documentation**: https://developer.android.com/ai/gemini
7. **Gemini Cookbook (GitHub)**: https://github.com/google-gemini/cookbook
8. **DataStudios - All Gemini Models 2025**: https://www.datastudios.org/post/all-gemini-models-available-in-2025-complete-list-for-web-app-api-and-vertex-ai
9. **Analytics Vidhya - Gemini 2.0 APIs**: https://www.analyticsvidhya.com/blog/2025/02/google-2-0-model-apis/

### n8n Específico
1. **n8n OpenAI Chat Model Docs**: https://docs.n8n.io/integrations/builtin/cluster-nodes/sub-nodes/n8n-nodes-langchain.lmchatopenai/
2. **n8n Google Gemini Chat Model Docs**: https://docs.n8n.io/integrations/builtin/cluster-nodes/sub-nodes/n8n-nodes-langchain.lmchatgooglegemini/
3. **n8n AI Agent Node Docs**: https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.agent/
4. **n8n GitHub Repository**: https://github.com/n8n-io/n8n
5. **n8n Release Notes**: https://docs.n8n.io/release-notes/
6. **n8n ChatDescription.ts Source Code**: https://github.com/n8n-io/n8n/blob/master/packages/nodes-base/nodes/OpenAi/ChatDescription.ts

### Issues e Discussões da Comunidade
- GitHub Issue #21523: https://github.com/n8n-io/n8n/issues/21523
- GitHub Issue #18149 (GPT-5 não funcionando): https://github.com/n8n-io/n8n/issues/18149
- GitHub Issue #12961 (AI Agent v1.76.1): https://github.com/n8n-io/n8n/issues/12961

---

## ⚠️ NOTAS IMPORTANTES

1. **Modelos carregados dinamicamente**: A lista exata que aparece no seu n8n depende:
   - Do que o provedor disponibiliza para sua conta
   - Do seu nível de assinatura/acesso
   - De registros específicos (ex: GPT-5 Pro requer ChatGPT Pro)

2. **Deprecações em andamento**:
   - `gemini-2.0-flash-live-001`: deprecated 09/12/2025
   - `gemini-live-2.5-flash-preview`: deprecated 09/12/2025
   - Gemini 1.5 e 1.0: totalmente retirados desde 29/04/2025

3. **Restrições regionais**:
   - `gemini-2.0-flash-preview-image-generation`: não disponível em Europa, Oriente Médio, África

4. **Requisitos de registro**:
   - OpenAI: GPT-5 Pro e GPT-5 Codex requerem registro
   - Google: Alguns modelos requerem plano Blaze (pay-as-you-go)

5. **Thinking/Reasoning**:
   - OpenAI: Reasoning effort configurável (minimal, low, medium, high)
   - Gemini 2.5: Thinking built-in em Pro, Flash, Flash-Lite
   - Gemini 2.0: Thinking experimental no Flash

---

## 🔄 ÚLTIMA ATUALIZAÇÃO

**Data**: 09 de Novembro de 2025  
**Pesquisa realizada**: 09 de Novembro de 2025  
**Versão do documento**: 1.0

**Nota**: As informações sobre modelos disponíveis podem mudar. Para a lista mais atualizada:
- OpenAI: Faça GET em `https://api.openai.com/v1/models` com sua API key
- Google Gemini: Faça GET em `https://generativelanguage.googleapis.com/v1beta/models?key={API_KEY}`
- n8n: Os dropdowns sempre refletem a lista atual da API

---

**Documento compilado por**: Claude (Anthropic)  
**Metodologia**: Web research + análise de código-fonte + documentação oficial
