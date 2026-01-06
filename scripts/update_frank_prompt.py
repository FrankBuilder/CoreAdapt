#!/usr/bin/env python3
"""
Atualização completa do prompt FRANK e remoção de referências ao Cal.com.

Mudanças:
1. Prompt FRANK: Adicionar regra de não inventar horários
2. Prompt FRANK: Remover referência ao Cal.com link
3. Check: Can Offer Meeting: Remover cal_booking_link
4. Detect: Meeting Offer Sent: Atualizar detecção para novo sistema
"""

import json
import re

print("📦 Carregando One Flow...")
with open('CoreAdapt One Flow _ v4.1_AUTONOMOUS.json', 'r', encoding='utf-8') as f:
    one_flow = json.load(f)

# ============================================================================
# 1. ATUALIZAR PROMPT DO FRANK (node CoreAdapt One AI Agent)
# ============================================================================

for node in one_flow['nodes']:
    if node.get('name') == 'CoreAdapt One AI Agent':
        # Encontrar o text (prompt dinâmico)
        if 'text' in node.get('parameters', {}):
            old_text = node['parameters']['text']

            # Substituir a referência ao Cal.com por instrução do novo sistema
            new_text = old_text.replace(
                "{{ $('Check: Can Offer Meeting').first().json.can_offer_meeting && $('Check: Can Offer Meeting').first().json.meeting_qualification.scores.total >= 55 ? 'Cal.com Link for Mesa de Clareza: ' + ($('Check: Can Offer Meeting').first().json.cal_booking_link || 'N/A - Ask for availability instead') : '' }}",
                """{{ $('Check: Can Offer Meeting').first().json.can_offer_meeting && $('Check: Can Offer Meeting').first().json.meeting_qualification.scores.total >= 55 ? 'SISTEMA DE AGENDAMENTO AUTÔNOMO ATIVO - Ao oferecer Mesa de Clareza, diga apenas "Deixa eu ver a agenda do Pasteur..." e PARE. O sistema vai buscar e inserir os horários reais automaticamente.' : '' }}"""
            )

            # Adicionar regra crítica de não inventar horários no final do TASK
            # Procurar por "Generate response now." e adicionar antes
            scheduling_rule = """
⚠️ REGRA CRÍTICA - AGENDAMENTO:
NUNCA invente ou liste horários/datas específicas.
Quando for oferecer Mesa de Clareza:
- Diga APENAS: "Deixa eu ver a agenda do Pasteur..."
- NÃO continue com horários como "Segunda às 10h"
- O sistema vai inserir automaticamente os horários reais
- Se você inventar datas, elas estarão ERRADAS

❌ ERRADO: "Temos Segunda às 10h, Terça às 14h..."
✅ CERTO: "Deixa eu ver a agenda do Pasteur..."

"""

            new_text = new_text.replace(
                "Generate response now.",
                scheduling_rule + "Generate response now."
            )

            node['parameters']['text'] = new_text
            print("✅ Prompt dinâmico atualizado com regra de agendamento")

        # Encontrar o systemMessage e atualizar também
        if 'options' in node.get('parameters', {}) and 'systemMessage' in node['parameters']['options']:
            old_system = node['parameters']['options']['systemMessage']

            # Adicionar seção de agendamento autônomo após CORE IDENTITY
            scheduling_section = """

---

## ⚠️ REGRA CRÍTICA: AGENDAMENTO AUTÔNOMO

**NUNCA gere horários ou datas específicas na sua resposta.**

O CoreAdapt possui um sistema de agendamento autônomo que:
1. Consulta o Google Calendar em tempo real
2. Verifica disponibilidade real do Pasteur
3. Oferece apenas horários realmente disponíveis
4. Cria eventos automaticamente quando confirmado

**Quando for oferecer Mesa de Clareza:**
```
✅ CORRETO:
"Faz muito sentido você conversar com o Pasteur.
Deixa eu ver a agenda dele..."

❌ ERRADO:
"Temos essas opções:
1. Segunda às 10h
2. Terça às 14h"
```

**Por quê?**
- Se você inventar datas, elas estarão ERRADAS (mês errado, dia da semana errado)
- O sistema vai detectar e substituir, mas é ineficiente
- Apenas diga "Deixa eu ver a agenda..." e PARE

---

"""
            # Inserir após "---" que vem depois de CORE IDENTITY
            # Procurar por "## CORECONNECT.AI" e inserir antes
            if "## CORECONNECT.AI" in old_system:
                new_system = old_system.replace(
                    "## CORECONNECT.AI",
                    scheduling_section + "## CORECONNECT.AI"
                )
            else:
                # Se não encontrar, adicionar no início após a primeira seção
                new_system = old_system.replace(
                    "---\n\n\n\n---",
                    "---" + scheduling_section + "\n---"
                )

            node['parameters']['options']['systemMessage'] = new_system
            print("✅ System message atualizado com regra de agendamento")
        break

# ============================================================================
# 2. ATUALIZAR CHECK: CAN OFFER MEETING - Remover cal_booking_link
# ============================================================================

for node in one_flow['nodes']:
    if node.get('name') == 'Check: Can Offer Meeting':
        if 'jsCode' in node.get('parameters', {}):
            old_code = node['parameters']['jsCode']

            # Remover a linha que define cal_booking_link
            new_code = old_code.replace(
                "// Cal.com link\n    cal_booking_link: 'https://cal.com/francisco-pasteur-coreadapt/mesa-de-clareza-45min'",
                "// Sistema de agendamento autônomo (Cal.com removido)\n    autonomous_scheduling: true"
            )

            node['parameters']['jsCode'] = new_code
            print("✅ Check: Can Offer Meeting atualizado (cal_booking_link removido)")
        break

# ============================================================================
# 3. ATUALIZAR DETECT: MEETING OFFER SENT - Novo sistema de detecção
# ============================================================================

NEW_DETECT_MEETING_CODE = '''// ================================================================
// Detect: Meeting Offer Sent v4.5.0 - Autonomous Scheduling
// Purpose: Check if AI response indicates scheduling intent
// Changes: Removed Cal.com detection, now detects scheduling phrases
// ================================================================

const aiResponse = $input.first().json.output;
const contextData = $('Check: Can Offer Meeting').first().json;

// Novos padrões para sistema autônomo
const schedulingPatterns = [
  /deixa eu ver a agenda/i,
  /vou verificar a agenda/i,
  /agenda do pasteur/i,
  /agenda do francisco/i,
  /mesa de clareza/i,
  /agendar.*reunião/i,
  /marcar.*conversa/i,
  /próximo passo.*agendar/i
];

const meetingOffered = schedulingPatterns.some(pattern => pattern.test(aiResponse));

// Verificar se FRANK tentou inventar horários (não deveria mais acontecer)
const inventedSlotsPattern = /(segunda|terça|terca|quarta|quinta|sexta)[^\\n]*\\d{1,2}[:/h]\\d{2}/i;
const frankInventedSlots = inventedSlotsPattern.test(aiResponse);

return [{
  json: {
    // Pass through AI response
    ...$input.first().json,

    // Add detection flags
    meeting_offered: meetingOffered,
    scheduling_intent_detected: meetingOffered,
    frank_invented_slots: frankInventedSlots,  // Flag para debug

    // Context for tracking
    contact_id: contextData.contact_id,
    company_id: contextData.company_id,
    anum_at_offer: {
      total: contextData.total_score,
      authority: contextData.authority_score,
      need: contextData.need_score,
      urgency: contextData.urgency_score,
      money: contextData.money_score
    },
    qualification_stage: contextData.qualification_stage,

    // Full message for logging
    offer_message: aiResponse,
    offered_at: new Date().toISOString()
  }
}];'''

for node in one_flow['nodes']:
    if node.get('name') == 'Detect: Meeting Offer Sent':
        node['parameters']['jsCode'] = NEW_DETECT_MEETING_CODE
        print("✅ Detect: Meeting Offer Sent atualizado para sistema autônomo")
        break

# ============================================================================
# 4. ATUALIZAR VERSÃO
# ============================================================================

one_flow['name'] = "CoreAdapt One Flow | v4.5 (Autonomous Scheduling)"
one_flow['versionId'] = "one-flow-v4.5-autonomous"

# ============================================================================
# SALVAR
# ============================================================================

with open('CoreAdapt One Flow _ v4.1_AUTONOMOUS.json', 'w', encoding='utf-8') as f:
    json.dump(one_flow, f, indent=2, ensure_ascii=False)

print("\n" + "="*70)
print("✅ PROMPT FRANK ATUALIZADO!")
print("="*70)
print("""
MUDANÇAS REALIZADAS:

1. PROMPT DINÂMICO (text)
   - Removida referência ao Cal.com link
   - Adicionada instrução: "SISTEMA DE AGENDAMENTO AUTÔNOMO ATIVO"
   - Adicionada REGRA CRÍTICA de não inventar horários

2. SYSTEM MESSAGE
   - Adicionada seção "⚠️ REGRA CRÍTICA: AGENDAMENTO AUTÔNOMO"
   - Exemplos claros de ✅ CORRETO vs ❌ ERRADO
   - Explicação do porquê não inventar datas

3. CHECK: CAN OFFER MEETING
   - Removido: cal_booking_link
   - Adicionado: autonomous_scheduling: true

4. DETECT: MEETING OFFER SENT
   - Removida detecção de Cal.com link
   - Adicionada detecção de frases de agendamento
   - Flag frank_invented_slots para debug

VERSÃO: v4.5 (Autonomous Scheduling)

O que o FRANK deve fazer agora:
- Quando ANUM >= 55, oferecer Mesa de Clareza
- Dizer: "Deixa eu ver a agenda do Pasteur..."
- PARAR e deixar o sistema inserir os horários reais

O sistema vai:
1. Detectar a frase "deixa eu ver a agenda"
2. Chamar Availability Flow
3. Obter horários reais do Google Calendar
4. Substituir/adicionar os horários na resposta
""")
