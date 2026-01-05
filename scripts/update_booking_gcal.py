#!/usr/bin/env python3
"""
Script para atualizar o Booking Flow com criação real de eventos no Google Calendar.
Substitui o node placeholder por integração real.
"""

import json

# Carregar Booking Flow
with open('CoreAdapt Booking Flow _ v4.json', 'r', encoding='utf-8') as f:
    flow = json.load(f)

# ============================================================================
# 1. SUBSTITUIR NODE "Create: Calendar Event" por Google Calendar real
# ============================================================================

# Encontrar o node atual
for i, node in enumerate(flow['nodes']):
    if node['name'] == 'Create: Calendar Event':
        # Substituir por node Google Calendar
        flow['nodes'][i] = {
            "parameters": {
                "resource": "event",
                "operation": "create",
                "calendar": {
                    "__rl": True,
                    "value": "={{ $('Fetch: Calendar Settings').first()?.json?.calendar_id || 'primary' }}",
                    "mode": "id"
                },
                "start": "={{ $json.selected_datetime }}",
                "end": "={{ $json.selected_end }}",
                "additionalFields": {
                    "summary": "=Mesa de Clareza - {{ $json.contact.name }}",
                    "description": "=📋 **Mesa de Clareza com {{ $json.contact.name }}**\n\n📱 WhatsApp: {{ $json.contact.whatsapp }}\n📧 Email: {{ $json.contact.email || 'Não informado' }}\n\n🎯 ANUM Score: {{ $json.qualification.anum_score || 'N/A' }}/100\n📊 Stage: {{ $json.qualification.stage || 'N/A' }}\n💬 Dor: {{ $json.qualification.pain_category || 'Não categorizada' }}\n\n✅ Agendado via CoreAdapt (Autônomo)",
                    "attendees": [],
                    "conferenceDataVersion": 1,
                    "guestsCanModify": False,
                    "location": "Google Meet (link no convite)",
                    "sendUpdates": "all"
                },
                "options": {
                    "conferenceData": {
                        "createRequest": {
                            "requestId": "={{ 'coreadapt-' + Date.now().toString(36) + '-' + Math.random().toString(36).substr(2, 9) }}",
                            "conferenceSolutionKey": {
                                "type": "hangoutsMeet"
                            }
                        }
                    },
                    "timeZone": "={{ $json.timezone || 'America/Sao_Paulo' }}"
                }
            },
            "id": "book-create-gcal-event-001",
            "name": "Create: Google Calendar Event",
            "type": "n8n-nodes-base.googleCalendar",
            "typeVersion": 1.3,
            "position": [168, -48],
            "credentials": {
                "googleCalendarOAuth2Api": {
                    "id": "CONFIGURE_ME",
                    "name": "Google Calendar Pasteur"
                }
            }
        }
        print("✅ Node 'Create: Calendar Event' substituído por Google Calendar real")
        break

# ============================================================================
# 2. ADICIONAR NODE para buscar calendar_id das settings
# ============================================================================

# Adicionar node para buscar calendar settings
fetch_calendar_settings_node = {
    "parameters": {
        "operation": "executeQuery",
        "query": "SELECT calendar_id, timezone FROM corev4_calendar_settings WHERE company_id = $1 AND is_active = true",
        "options": {
            "queryReplacement": "={{ [$json.company_id] }}"
        }
    },
    "id": "book-fetch-cal-settings-001",
    "name": "Fetch: Calendar Settings",
    "type": "n8n-nodes-base.postgres",
    "typeVersion": 2.6,
    "position": [-56, -144],
    "alwaysOutputData": True,
    "credentials": {
        "postgres": {
            "id": "HCvX4Ypw2MiRDsdm",
            "name": "Postgres Core"
        }
    }
}

# Verificar se já existe
exists = any(n['name'] == 'Fetch: Calendar Settings' for n in flow['nodes'])
if not exists:
    flow['nodes'].append(fetch_calendar_settings_node)
    print("✅ Node 'Fetch: Calendar Settings' adicionado")

# ============================================================================
# 3. ATUALIZAR NODE que extrai meeting URL do evento criado
# ============================================================================

# Adicionar node para extrair dados do evento criado
extract_event_node = {
    "parameters": {
        "jsCode": """const validationData = $('Validate: Selected Slot').first().json;
const gcalEvent = $input.first().json;

// Extrair meeting URL do Google Calendar event
let meetingUrl = '';
let meetingId = '';

// Tentar extrair do conferenceData (Google Meet)
if (gcalEvent.conferenceData && gcalEvent.conferenceData.entryPoints) {
  const videoEntry = gcalEvent.conferenceData.entryPoints.find(e => e.entryPointType === 'video');
  if (videoEntry) {
    meetingUrl = videoEntry.uri;
  }
}

// Fallback: usar hangoutLink se disponível
if (!meetingUrl && gcalEvent.hangoutLink) {
  meetingUrl = gcalEvent.hangoutLink;
}

// Extrair ID do evento
meetingId = gcalEvent.id || 'gcal-' + Date.now().toString(36);

// Se ainda não tiver URL, criar placeholder (não deveria acontecer)
if (!meetingUrl) {
  meetingUrl = `https://meet.google.com/lookup/${meetingId}`;
  console.log('AVISO: Não foi possível extrair Google Meet URL do evento');
}

return [{
  json: {
    ...validationData,
    meeting_id: meetingId,
    meeting_url: meetingUrl,
    gcal_event_id: gcalEvent.id,
    gcal_html_link: gcalEvent.htmlLink,
    created_via: 'autonomous_booking_gcal'
  }
}];"""
    },
    "id": "book-extract-event-001",
    "name": "Extract: Event Data",
    "type": "n8n-nodes-base.code",
    "typeVersion": 2,
    "position": [280, -48]
}

# Verificar se já existe ou substituir
for i, node in enumerate(flow['nodes']):
    if node['name'] == 'Extract: Event Data':
        flow['nodes'][i] = extract_event_node
        print("✅ Node 'Extract: Event Data' atualizado")
        break
else:
    flow['nodes'].append(extract_event_node)
    print("✅ Node 'Extract: Event Data' adicionado")

# ============================================================================
# 4. ATUALIZAR CONEXÕES
# ============================================================================

# Adicionar conexão: Check: No Conflicts -> Fetch: Calendar Settings -> Create: Google Calendar Event
flow['connections']['Check: No Conflicts'] = {
    "main": [
        [{"node": "Fetch: Calendar Settings", "type": "main", "index": 0}],
        [{"node": "Respond: Slot Conflict", "type": "main", "index": 0}]
    ]
}

flow['connections']['Fetch: Calendar Settings'] = {
    "main": [
        [{"node": "Create: Google Calendar Event", "type": "main", "index": 0}]
    ]
}

flow['connections']['Create: Google Calendar Event'] = {
    "main": [
        [{"node": "Extract: Event Data", "type": "main", "index": 0}]
    ]
}

flow['connections']['Extract: Event Data'] = {
    "main": [
        [{"node": "Save: Meeting Record", "type": "main", "index": 0}]
    ]
}

# Remover conexão antiga se existir
if 'Create: Calendar Event' in flow['connections']:
    del flow['connections']['Create: Calendar Event']

print("✅ Conexões atualizadas")

# ============================================================================
# 5. ATUALIZAR "Save: Meeting Record" para usar dados do evento real
# ============================================================================

for node in flow['nodes']:
    if node['name'] == 'Save: Meeting Record':
        # Atualizar query replacement para usar $json do Extract: Event Data
        node['parameters']['options']['queryReplacement'] = """={{ [
  $json.contact_id,
  $json.company_id,
  $json.selected_datetime,
  $json.selected_end,
  $json.duration_minutes,
  $json.timezone,
  $json.gcal_event_id || $json.meeting_id,
  $json.contact.name,
  $json.meeting_url,
  $json.contact.email,
  $json.qualification.anum_score || 0,
  $json.qualification.stage,
  $json.qualification.pain_category
] }}"""
        print("✅ Node 'Save: Meeting Record' atualizado")
        break

# ============================================================================
# 6. ATUALIZAR referências em outros nodes
# ============================================================================

for node in flow['nodes']:
    if node['name'] == 'Prepare: Confirmation Message':
        # Atualizar para usar Extract: Event Data
        node['parameters']['jsCode'] = node['parameters']['jsCode'].replace(
            "$('Create: Calendar Event')",
            "$('Extract: Event Data')"
        )
        print("✅ Node 'Prepare: Confirmation Message' atualizado")

    if node['name'] == 'Respond: Booking Success':
        # Atualizar responseBody
        node['parameters']['responseBody'] = """={{ {
  success: true,
  booking_created: true,
  meeting_id: $('Save: Meeting Record').first().json.meeting_record_id,
  meeting_datetime: $('Validate: Selected Slot').first().json.selected_datetime,
  meeting_url: $('Extract: Event Data').first().json.meeting_url,
  gcal_event_id: $('Extract: Event Data').first().json.gcal_event_id,
  confirmation_sent: true,
  contact: $('Validate: Selected Slot').first().json.contact
} }}"""
        print("✅ Node 'Respond: Booking Success' atualizado")

# ============================================================================
# 7. SALVAR FLUXO ATUALIZADO
# ============================================================================

flow['name'] = "CoreAdapt Booking Flow | v4.1 (Google Calendar)"
flow['versionId'] = "booking-v4.1-gcal"

with open('CoreAdapt Booking Flow _ v4.json', 'w', encoding='utf-8') as f:
    json.dump(flow, f, indent=2, ensure_ascii=False)

print("\n✅ Booking Flow atualizado com sucesso!")
print("Mudanças:")
print("  - Node 'Create: Calendar Event' substituído por Google Calendar real")
print("  - Adicionado 'Fetch: Calendar Settings' para obter calendar_id")
print("  - Adicionado 'Extract: Event Data' para extrair Google Meet URL")
print("  - Conexões atualizadas")
print("\n⚠️ IMPORTANTE: Configure a credencial 'Google Calendar Pasteur' no n8n!")
print("Próximo passo: Re-importar no n8n")
