/**
 * ============================================================================
 * GERADOR DE RELATÓRIO COMPLETO DE LEAD - CoreAdapt v4
 * ============================================================================
 *
 * Este script gera um relatório completo e detalhado sobre um lead específico,
 * incluindo score ANUM, histórico de mensagens, follow-ups, reuniões e métricas.
 *
 * USO:
 * node scripts/generate_lead_report.js --contact-id=123
 * node scripts/generate_lead_report.js --whatsapp="5585999855443@s.whatsapp.net"
 * node scripts/generate_lead_report.js --contact-id=123 --format=json
 * node scripts/generate_lead_report.js --contact-id=123 --output=report.txt
 *
 * OPÇÕES:
 * --contact-id=<id>         ID do contato no banco
 * --whatsapp=<numero>       Número do WhatsApp (formato: 5585999855443@s.whatsapp.net)
 * --format=<text|json|html> Formato de saída (padrão: text)
 * --output=<arquivo>        Arquivo de saída (padrão: console)
 * --include-full-history    Incluir histórico completo de mensagens (pode ser grande)
 *
 * ============================================================================
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// ============================================================================
// CONFIGURAÇÃO
// ============================================================================

// Supabase config - ajuste conforme necessário
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://your-project.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || 'your-service-key';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// ============================================================================
// PARSE DE ARGUMENTOS
// ============================================================================

function parseArgs() {
    const args = process.argv.slice(2);
    const options = {
        contactId: null,
        whatsapp: null,
        format: 'text',
        output: null,
        includeFullHistory: false
    };

    args.forEach(arg => {
        if (arg.startsWith('--contact-id=')) {
            options.contactId = parseInt(arg.split('=')[1]);
        } else if (arg.startsWith('--whatsapp=')) {
            options.whatsapp = arg.split('=')[1];
        } else if (arg.startsWith('--format=')) {
            options.format = arg.split('=')[1];
        } else if (arg.startsWith('--output=')) {
            options.output = arg.split('=')[1];
        } else if (arg === '--include-full-history') {
            options.includeFullHistory = true;
        }
    });

    if (!options.contactId && !options.whatsapp) {
        console.error('❌ Erro: É necessário fornecer --contact-id ou --whatsapp');
        console.log('\nUso:');
        console.log('  node scripts/generate_lead_report.js --contact-id=123');
        console.log('  node scripts/generate_lead_report.js --whatsapp="5585999855443@s.whatsapp.net"');
        process.exit(1);
    }

    return options;
}

// ============================================================================
// EXECUÇÃO DE QUERIES
// ============================================================================

async function executeQuery(query, params = {}) {
    try {
        const { data, error } = await supabase.rpc('execute_sql', {
            sql_query: query,
            params: params
        });

        if (error) {
            console.error('Erro ao executar query:', error);
            return null;
        }

        return data;
    } catch (err) {
        console.error('Erro:', err);
        return null;
    }
}

// ============================================================================
// QUERIES SQL (versões simplificadas para execução programática)
// ============================================================================

async function getContactBasicInfo(contactId, whatsapp) {
    const query = `
        SELECT
            c.id AS contact_id,
            c.company_id,
            c.full_name,
            c.whatsapp,
            c.phone_number,
            c.email,
            c.origin_source,
            c.sector,
            c.tags,
            c.opt_out,
            c.is_active,
            c.last_interaction_at,
            c.created_at AS contact_created_at,
            c.utm_source,
            c.utm_medium,
            c.utm_campaign,
            comp.name AS company_name,
            comp.bot_name,
            ce.audio_response,
            ce.text_response,
            ce.interactions AS total_interactions,
            ls.authority_score,
            ls.need_score,
            ls.urgency_score,
            ls.money_score,
            ls.total_score AS anum_total_score,
            ls.qualification_stage,
            ls.is_qualified,
            ls.status AS lead_status,
            ls.analysis_count,
            ls.last_analyzed_at,
            ls.analyzed_at AS first_analyzed_at,
            pc.category_label_pt AS pain_category,
            ls.main_pain_detail,
            ch.conversation_open,
            ch.batch_collecting
        FROM corev4_contacts c
        LEFT JOIN corev4_companies comp ON c.company_id = comp.id
        LEFT JOIN corev4_contact_extras ce ON c.id = ce.contact_id
        LEFT JOIN corev4_lead_state ls ON c.id = ls.contact_id
        LEFT JOIN corev4_pain_categories pc ON ls.main_pain_category_id = pc.id
        LEFT JOIN corev4_chats ch ON c.id = ch.contact_id
        WHERE ${contactId ? 'c.id = $1' : 'c.whatsapp = $1'}
    `;

    const { data, error } = await supabase.rpc('execute_sql', {
        sql: query,
        params: [contactId || whatsapp]
    });

    if (error) throw error;
    return data && data.length > 0 ? data[0] : null;
}

async function getFollowupCampaign(contactId) {
    const { data, error } = await supabase
        .from('corev4_followup_campaigns')
        .select(`
            *,
            config:corev4_followup_configs(*)
        `)
        .eq('contact_id', contactId)
        .single();

    if (error && error.code !== 'PGRST116') throw error;
    return data;
}

async function getFollowupExecutions(contactId) {
    const { data, error } = await supabase
        .from('corev4_followup_executions')
        .select('*')
        .eq('contact_id', contactId)
        .order('step', { ascending: true });

    if (error) throw error;
    return data || [];
}

async function getMeetings(contactId) {
    const { data, error } = await supabase
        .from('corev4_scheduled_meetings')
        .select('*')
        .eq('contact_id', contactId)
        .order('meeting_date', { ascending: false });

    if (error) throw error;
    return data || [];
}

async function getMessageHistory(contactId, limit = null) {
    let query = supabase
        .from('corev4_chat_history')
        .select('*')
        .eq('contact_id', contactId)
        .order('message_timestamp', { ascending: true });

    if (limit) {
        query = query.limit(limit);
    }

    const { data, error } = await query;

    if (error) throw error;
    return data || [];
}

async function getEngagementStats(contactId) {
    const messages = await getMessageHistory(contactId);

    const stats = {
        total_messages: messages.length,
        user_messages: messages.filter(m => m.role === 'user').length,
        bot_messages: messages.filter(m => m.role === 'assistant').length,
        messages_with_media: messages.filter(m => m.has_media).length,
        audio_messages: messages.filter(m => m.message_type === 'audio').length,
        image_messages: messages.filter(m => m.message_type === 'image').length,
        video_messages: messages.filter(m => m.message_type === 'video').length,
        document_messages: messages.filter(m => m.message_type === 'document').length,
        total_tokens: messages.reduce((sum, m) => sum + (m.tokens_used || 0), 0),
        total_cost: messages.reduce((sum, m) => sum + (m.cost_usd || 0), 0),
        first_message_at: messages.length > 0 ? messages[0].message_timestamp : null,
        last_message_at: messages.length > 0 ? messages[messages.length - 1].message_timestamp : null,
        last_user_message_at: messages.filter(m => m.role === 'user').slice(-1)[0]?.message_timestamp || null
    };

    return stats;
}

async function getReengagementAnalysis(contactId) {
    const messages = await getMessageHistory(contactId);
    const userMessages = messages.filter(m => m.role === 'user');

    let reengagementCount = 0;
    let longestSilenceHours = 0;

    for (let i = 1; i < userMessages.length; i++) {
        const prevMsg = new Date(userMessages[i - 1].message_timestamp);
        const currMsg = new Date(userMessages[i].message_timestamp);
        const diffHours = (currMsg - prevMsg) / (1000 * 60 * 60);

        if (diffHours > 48) {
            reengagementCount++;
        }

        if (diffHours > longestSilenceHours) {
            longestSilenceHours = diffHours;
        }
    }

    return {
        reengagement_count: reengagementCount,
        longest_silence_hours: longestSilenceHours
    };
}

// ============================================================================
// FORMATAÇÃO - TEXTO
// ============================================================================

function formatTextReport(data) {
    const lines = [];
    const contact = data.contact;
    const campaign = data.campaign;
    const executions = data.executions;
    const meetings = data.meetings;
    const stats = data.stats;
    const reengagement = data.reengagement;
    const recentMessages = data.recentMessages;

    // Header
    lines.push('═══════════════════════════════════════════════════════════════════════');
    lines.push('                    RELATÓRIO COMPLETO DO LEAD');
    lines.push('═══════════════════════════════════════════════════════════════════════');
    lines.push('');

    // Identificação
    lines.push('┌─────────────────────────────────────────────────────────────────────┐');
    lines.push('│  IDENTIFICAÇÃO DO LEAD                                              │');
    lines.push('└─────────────────────────────────────────────────────────────────────┘');
    lines.push('');
    lines.push(`ID: ${contact.contact_id}`);
    lines.push(`Nome: ${contact.full_name}`);
    lines.push(`WhatsApp: ${contact.whatsapp}`);
    lines.push(`Telefone: ${contact.phone_number || 'N/A'}`);
    lines.push(`Email: ${contact.email || 'N/A'}`);
    lines.push(`Empresa: ${contact.company_name}`);
    lines.push('');

    // Status Atual
    lines.push('┌─────────────────────────────────────────────────────────────────────┐');
    lines.push('│  STATUS ATUAL                                                       │');
    lines.push('└─────────────────────────────────────────────────────────────────────┘');
    lines.push('');

    let statusGeral = '✓ ATIVO';
    if (contact.opt_out) statusGeral = '🚫 OPT-OUT (não recebe mais mensagens)';
    else if (!contact.is_active) statusGeral = '⊗ INATIVO';
    else if (contact.conversation_open) statusGeral = '💬 CONVERSA ATIVA';

    lines.push(`Status Geral: ${statusGeral}`);
    lines.push(`Status Lead State: ${contact.lead_status || 'N/A'}`);

    if (contact.last_interaction_at) {
        const lastInteraction = new Date(contact.last_interaction_at);
        const hoursAgo = ((new Date() - lastInteraction) / (1000 * 60 * 60)).toFixed(1);
        lines.push(`Última Interação: ${lastInteraction.toLocaleString('pt-BR')} (há ${hoursAgo} horas)`);
    }
    lines.push('');

    // Score ANUM
    lines.push('┌─────────────────────────────────────────────────────────────────────┐');
    lines.push('│  SCORE ANUM (QUALIFICAÇÃO)                                          │');
    lines.push('└─────────────────────────────────────────────────────────────────────┘');
    lines.push('');

    if (contact.anum_total_score !== null) {
        lines.push(`ANUM TOTAL: ${contact.anum_total_score.toFixed(1)}/100`);
        lines.push(`  └─ Authority (Autoridade): ${contact.authority_score?.toFixed(1) || 0}/100`);
        lines.push(`  └─ Need (Necessidade): ${contact.need_score?.toFixed(1) || 0}/100`);
        lines.push(`  └─ Urgency (Urgência): ${contact.urgency_score?.toFixed(1) || 0}/100`);
        lines.push(`  └─ Money (Dinheiro): ${contact.money_score?.toFixed(1) || 0}/100`);
        lines.push('');
        lines.push(`Estágio de Qualificação: ${(contact.qualification_stage || 'N/A').toUpperCase()}`);
        lines.push(`${contact.is_qualified ? '✓ QUALIFICADO' : '○ NÃO QUALIFICADO'}`);
        lines.push(`Analisado ${contact.analysis_count || 0} vez(es)`);

        if (contact.last_analyzed_at) {
            lines.push(`Última Análise: ${new Date(contact.last_analyzed_at).toLocaleString('pt-BR')}`);
        }
        lines.push('');
        lines.push(`Categoria de Dor: ${contact.pain_category || 'Não identificada'}`);
        lines.push(`Detalhes: ${contact.main_pain_detail || 'N/A'}`);
    } else {
        lines.push('○ Ainda não foi analisado');
    }
    lines.push('');

    // Origem e Rastreamento
    lines.push('┌─────────────────────────────────────────────────────────────────────┐');
    lines.push('│  ORIGEM E RASTREAMENTO                                              │');
    lines.push('└─────────────────────────────────────────────────────────────────────┘');
    lines.push('');
    lines.push(`Origem: ${contact.origin_source}`);
    lines.push(`Setor: ${contact.sector || 'Não informado'}`);
    lines.push(`Tags: ${contact.tags?.join(', ') || 'Nenhuma'}`);
    lines.push(`UTM Source: ${contact.utm_source || 'N/A'}`);
    lines.push(`UTM Medium: ${contact.utm_medium || 'N/A'}`);
    lines.push(`UTM Campaign: ${contact.utm_campaign || 'N/A'}`);
    lines.push('');

    // Campanha de Follow-up
    lines.push('┌─────────────────────────────────────────────────────────────────────┐');
    lines.push('│  CAMPANHA DE FOLLOW-UP                                              │');
    lines.push('└─────────────────────────────────────────────────────────────────────┘');
    lines.push('');

    if (campaign) {
        let campaignStatus = '';
        if (campaign.status === 'completed') campaignStatus = '✓ Campanha Completada';
        else if (campaign.status === 'stopped') campaignStatus = `⊗ Campanha Parada: ${campaign.stopped_reason || 'não especificado'}`;
        else if (!campaign.should_continue) campaignStatus = `⊗ Campanha Pausada: ${campaign.pause_reason || 'não especificado'}`;
        else if (campaign.status === 'active') campaignStatus = '→ Campanha Ativa';

        lines.push(`Status: ${campaignStatus}`);

        const progress = ((campaign.steps_completed / campaign.total_steps) * 100).toFixed(1);
        lines.push(`Progresso: ${campaign.steps_completed}/${campaign.total_steps} passos (${progress}%)`);

        if (campaign.last_step_sent_at) {
            lines.push(`Último Passo Enviado: ${new Date(campaign.last_step_sent_at).toLocaleString('pt-BR')}`);
        }

        if (campaign.config) {
            lines.push(`Thresholds: Qualificação ≥${campaign.config.qualification_threshold} | Desqualificação <${campaign.config.disqualification_threshold}`);
        }
    } else {
        lines.push('○ Nenhuma campanha iniciada');
    }
    lines.push('');

    // Detalhamento dos Follow-ups
    if (executions && executions.length > 0) {
        lines.push('┌─────────────────────────────────────────────────────────────────────┐');
        lines.push('│  DETALHAMENTO DOS FOLLOW-UPS                                        │');
        lines.push('└─────────────────────────────────────────────────────────────────────┘');
        lines.push('');

        executions.forEach(exec => {
            let stepStatus = '';
            if (exec.executed && exec.sent_at) stepStatus = '✓ Enviado';
            else if (exec.executed && !exec.sent_at) stepStatus = '✗ Marcado como executado mas sem envio';
            else if (!exec.should_send) stepStatus = `⊗ Cancelado: ${exec.decision_reason || 'não especificado'}`;
            else if (new Date(exec.scheduled_at) > new Date()) stepStatus = `⏰ Agendado para ${new Date(exec.scheduled_at).toLocaleString('pt-BR')}`;
            else stepStatus = '⚠ Atrasado (deveria ter sido enviado)';

            lines.push(`Passo ${exec.step}/${exec.total_steps}: ${stepStatus}`);
            lines.push(`  └─ Agendado para: ${new Date(exec.scheduled_at).toLocaleString('pt-BR')}`);

            if (exec.sent_at) {
                lines.push(`  └─ Enviado em: ${new Date(exec.sent_at).toLocaleString('pt-BR')}`);
            }

            if (exec.anum_at_execution !== null) {
                lines.push(`  └─ ANUM na execução: ${exec.anum_at_execution.toFixed(1)}`);
            }

            if (exec.generated_message) {
                const preview = exec.generated_message.substring(0, 100);
                lines.push(`  └─ Mensagem: ${preview}${exec.generated_message.length > 100 ? '...' : ''}`);
            }

            lines.push('─────────────────────────────────────────────────────────────────────');
        });
        lines.push('');
    }

    // Reuniões
    if (meetings && meetings.length > 0) {
        lines.push('┌─────────────────────────────────────────────────────────────────────┐');
        lines.push('│  REUNIÕES AGENDADAS/REALIZADAS                                      │');
        lines.push('└─────────────────────────────────────────────────────────────────────┘');
        lines.push('');

        meetings.forEach(meeting => {
            let meetingStatus = '';
            if (meeting.meeting_completed) meetingStatus = `✓ Realizada em ${new Date(meeting.meeting_completed_at).toLocaleString('pt-BR')}`;
            else if (meeting.no_show) meetingStatus = `✗ No-show em ${new Date(meeting.no_show_reported_at).toLocaleString('pt-BR')}`;
            else if (meeting.status === 'cancelled') meetingStatus = `⊗ Cancelada: ${meeting.cal_cancel_reason || 'não especificado'}`;
            else if (meeting.status === 'rescheduled') meetingStatus = '⟲ Remarcada';
            else if (new Date(meeting.meeting_date) > new Date()) meetingStatus = `⏰ Agendada para ${new Date(meeting.meeting_date).toLocaleString('pt-BR')}`;

            lines.push(`Status: ${meetingStatus}`);
            lines.push(`Data/Hora: ${new Date(meeting.meeting_date).toLocaleString('pt-BR')} (${meeting.meeting_timezone})`);
            lines.push(`Duração: ${meeting.meeting_duration_minutes} minutos`);
            lines.push(`Tipo: ${meeting.meeting_type}`);
            lines.push(`Participante: ${meeting.cal_attendee_name} (${meeting.cal_attendee_email})`);

            if (meeting.cal_meeting_url) {
                lines.push(`URL: ${meeting.cal_meeting_url}`);
            }

            lines.push('');
            lines.push(`ANUM no agendamento: ${meeting.anum_score_at_booking?.toFixed(1) || 'N/A'}`);
            lines.push(`  └─ Authority: ${meeting.authority_score?.toFixed(1) || 0}`);
            lines.push(`  └─ Need: ${meeting.need_score?.toFixed(1) || 0}`);
            lines.push(`  └─ Urgency: ${meeting.urgency_score?.toFixed(1) || 0}`);
            lines.push(`  └─ Money: ${meeting.money_score?.toFixed(1) || 0}`);

            if (meeting.conversation_summary) {
                lines.push('');
                lines.push(`Resumo da conversa: ${meeting.conversation_summary.substring(0, 200)}...`);
            }

            if (meeting.meeting_notes) {
                lines.push(`Notas: ${meeting.meeting_notes}`);
            }

            if (meeting.meeting_outcome) {
                lines.push(`Resultado: ${meeting.meeting_outcome}`);
            }

            lines.push('═════════════════════════════════════════════════════════════════════');
        });
        lines.push('');
    }

    // Estatísticas de Engajamento
    lines.push('┌─────────────────────────────────────────────────────────────────────┐');
    lines.push('│  ESTATÍSTICAS DE ENGAJAMENTO                                        │');
    lines.push('└─────────────────────────────────────────────────────────────────────┘');
    lines.push('');
    lines.push(`Total de mensagens: ${stats.total_messages}`);
    lines.push(`  └─ Mensagens do lead: ${stats.user_messages}`);
    lines.push(`  └─ Mensagens do bot: ${stats.bot_messages}`);
    lines.push(`  └─ Mensagens com mídia: ${stats.messages_with_media}`);
    lines.push('');
    lines.push('Distribuição por tipo de mídia:');
    lines.push(`  └─ Áudios: ${stats.audio_messages}`);
    lines.push(`  └─ Imagens: ${stats.image_messages}`);
    lines.push(`  └─ Vídeos: ${stats.video_messages}`);
    lines.push(`  └─ Documentos: ${stats.document_messages}`);
    lines.push('');

    if (stats.first_message_at) {
        lines.push(`Primeira mensagem: ${new Date(stats.first_message_at).toLocaleString('pt-BR')}`);
    }

    if (stats.last_message_at) {
        const hoursAgo = ((new Date() - new Date(stats.last_message_at)) / (1000 * 60 * 60)).toFixed(1);
        lines.push(`Última mensagem: ${new Date(stats.last_message_at).toLocaleString('pt-BR')} (há ${hoursAgo} horas)`);
    }

    if (stats.last_user_message_at) {
        const hoursAgo = ((new Date() - new Date(stats.last_user_message_at)) / (1000 * 60 * 60)).toFixed(1);
        lines.push(`Última mensagem do lead: ${new Date(stats.last_user_message_at).toLocaleString('pt-BR')} (há ${hoursAgo} horas)`);
    }

    lines.push('');
    lines.push(`Total de tokens usados: ${stats.total_tokens}`);
    lines.push(`Custo total (USD): $${stats.total_cost.toFixed(4)}`);
    lines.push('');

    // Análise de Reengajamento
    lines.push('┌─────────────────────────────────────────────────────────────────────┐');
    lines.push('│  ANÁLISE DE REENGAJAMENTO                                           │');
    lines.push('└─────────────────────────────────────────────────────────────────────┘');
    lines.push('');
    lines.push(`Reengajamentos detectados: ${reengagement.reengagement_count} (gaps >48h seguidos de nova mensagem)`);
    lines.push(`Maior período de silêncio: ${reengagement.longest_silence_hours.toFixed(1)} horas`);
    lines.push('');

    // Últimas Mensagens
    if (recentMessages && recentMessages.length > 0) {
        lines.push('┌─────────────────────────────────────────────────────────────────────┐');
        lines.push('│  ÚLTIMAS 20 MENSAGENS DA CONVERSA                                   │');
        lines.push('└─────────────────────────────────────────────────────────────────────┘');
        lines.push('');

        recentMessages.slice(-20).forEach((msg, idx) => {
            const roleLabel = msg.role === 'user' ? '👤 Lead' :
                            msg.role === 'assistant' ? `🤖 ${contact.bot_name || 'Bot'}` :
                            '⚙️  Sistema';

            const timestamp = new Date(msg.message_timestamp).toLocaleString('pt-BR');
            const preview = msg.has_media ?
                `[${msg.message_type.toUpperCase()}] ${msg.message.substring(0, 100)}` :
                msg.message.substring(0, 150);

            lines.push(`#${idx + 1} - ${timestamp}`);
            lines.push(`${roleLabel}: ${preview}${msg.message.length > 150 ? '...' : ''}`);

            if (msg.role === 'assistant' && msg.tokens_used) {
                lines.push(`    (${msg.tokens_used} tokens, $${msg.cost_usd?.toFixed(6) || 0}, ${msg.model_used})`);
            }

            lines.push('─────────────────────────────────────────────────────────────────────');
        });
    }

    lines.push('');
    lines.push('═══════════════════════════════════════════════════════════════════════');
    lines.push(`Relatório gerado em: ${new Date().toLocaleString('pt-BR')}`);
    lines.push('═══════════════════════════════════════════════════════════════════════');

    return lines.join('\n');
}

// ============================================================================
// FORMATAÇÃO - JSON
// ============================================================================

function formatJSONReport(data) {
    return JSON.stringify(data, null, 2);
}

// ============================================================================
// FORMATAÇÃO - HTML
// ============================================================================

function formatHTMLReport(data) {
    const contact = data.contact;
    const campaign = data.campaign;
    const executions = data.executions;
    const meetings = data.meetings;
    const stats = data.stats;
    const reengagement = data.reengagement;
    const recentMessages = data.recentMessages;

    return `
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Relatório de Lead - ${contact.full_name}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 { font-size: 2em; margin-bottom: 10px; }
        .header p { opacity: 0.9; }
        .section {
            padding: 25px 30px;
            border-bottom: 1px solid #e0e0e0;
        }
        .section:last-child { border-bottom: none; }
        .section h2 {
            color: #667eea;
            margin-bottom: 15px;
            font-size: 1.5em;
            border-left: 4px solid #667eea;
            padding-left: 10px;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }
        .info-item {
            padding: 12px;
            background: #f8f9fa;
            border-radius: 6px;
            border-left: 3px solid #667eea;
        }
        .info-item label {
            display: block;
            font-size: 0.85em;
            color: #666;
            margin-bottom: 5px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .info-item value {
            display: block;
            font-size: 1.1em;
            color: #333;
            font-weight: 500;
        }
        .badge {
            display: inline-block;
            padding: 5px 12px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: 600;
            margin: 5px 5px 5px 0;
        }
        .badge.success { background: #d4edda; color: #155724; }
        .badge.warning { background: #fff3cd; color: #856404; }
        .badge.danger { background: #f8d7da; color: #721c24; }
        .badge.info { background: #d1ecf1; color: #0c5460; }
        .anum-score {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            margin: 15px 0;
        }
        .anum-score .total {
            font-size: 3em;
            font-weight: bold;
            margin-bottom: 10px;
        }
        .anum-breakdown {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 15px;
            margin-top: 15px;
        }
        .anum-item {
            background: rgba(255,255,255,0.2);
            padding: 15px;
            border-radius: 6px;
            text-align: center;
        }
        .anum-item .label {
            font-size: 0.9em;
            opacity: 0.9;
            margin-bottom: 5px;
        }
        .anum-item .value {
            font-size: 1.8em;
            font-weight: bold;
        }
        .timeline {
            position: relative;
            padding-left: 30px;
        }
        .timeline::before {
            content: '';
            position: absolute;
            left: 8px;
            top: 0;
            bottom: 0;
            width: 2px;
            background: #e0e0e0;
        }
        .timeline-item {
            position: relative;
            margin-bottom: 20px;
            padding-left: 20px;
        }
        .timeline-item::before {
            content: '';
            position: absolute;
            left: -26px;
            top: 5px;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            background: #667eea;
            border: 3px solid white;
            box-shadow: 0 0 0 2px #667eea;
        }
        .timeline-item.completed::before { background: #28a745; box-shadow: 0 0 0 2px #28a745; }
        .timeline-item.pending::before { background: #ffc107; box-shadow: 0 0 0 2px #ffc107; }
        .timeline-item.cancelled::before { background: #dc3545; box-shadow: 0 0 0 2px #dc3545; }
        .message {
            margin-bottom: 15px;
            padding: 12px;
            border-radius: 8px;
            position: relative;
        }
        .message.user {
            background: #e3f2fd;
            margin-left: 40px;
        }
        .message.assistant {
            background: #f3e5f5;
            margin-right: 40px;
        }
        .message .sender {
            font-weight: bold;
            margin-bottom: 5px;
            font-size: 0.9em;
        }
        .message .timestamp {
            font-size: 0.75em;
            color: #666;
            margin-bottom: 8px;
        }
        .message .text {
            line-height: 1.5;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }
        .stat-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
        }
        .stat-card .value {
            font-size: 2.5em;
            font-weight: bold;
            margin-bottom: 5px;
        }
        .stat-card .label {
            font-size: 0.9em;
            opacity: 0.9;
        }
        .footer {
            text-align: center;
            padding: 20px;
            background: #f8f9fa;
            color: #666;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Relatório Completo de Lead</h1>
            <p>Gerado em ${new Date().toLocaleString('pt-BR')}</p>
        </div>

        <!-- Identificação -->
        <div class="section">
            <h2>Identificação do Lead</h2>
            <div class="info-grid">
                <div class="info-item">
                    <label>Nome Completo</label>
                    <value>${contact.full_name}</value>
                </div>
                <div class="info-item">
                    <label>WhatsApp</label>
                    <value>${contact.whatsapp}</value>
                </div>
                <div class="info-item">
                    <label>Email</label>
                    <value>${contact.email || 'N/A'}</value>
                </div>
                <div class="info-item">
                    <label>Telefone</label>
                    <value>${contact.phone_number || 'N/A'}</value>
                </div>
                <div class="info-item">
                    <label>Empresa</label>
                    <value>${contact.company_name}</value>
                </div>
                <div class="info-item">
                    <label>ID</label>
                    <value>${contact.contact_id}</value>
                </div>
            </div>
        </div>

        <!-- Status -->
        <div class="section">
            <h2>Status Atual</h2>
            ${contact.opt_out ? '<span class="badge danger">🚫 OPT-OUT</span>' : ''}
            ${!contact.is_active ? '<span class="badge warning">⊗ INATIVO</span>' : ''}
            ${contact.conversation_open && contact.is_active && !contact.opt_out ? '<span class="badge success">💬 CONVERSA ATIVA</span>' : ''}
            ${!contact.conversation_open && contact.is_active && !contact.opt_out ? '<span class="badge info">✓ ATIVO</span>' : ''}
            <div class="info-grid" style="margin-top: 15px;">
                <div class="info-item">
                    <label>Última Interação</label>
                    <value>${contact.last_interaction_at ? new Date(contact.last_interaction_at).toLocaleString('pt-BR') : 'N/A'}</value>
                </div>
            </div>
        </div>

        <!-- Score ANUM -->
        <div class="section">
            <h2>Score ANUM (Qualificação)</h2>
            ${contact.anum_total_score !== null ? `
                <div class="anum-score">
                    <div class="total">${contact.anum_total_score.toFixed(1)}<span style="font-size: 0.5em;">/100</span></div>
                    <div style="font-size: 1.2em; opacity: 0.9;">Score Total</div>
                    <div class="anum-breakdown">
                        <div class="anum-item">
                            <div class="label">Authority</div>
                            <div class="value">${contact.authority_score?.toFixed(1) || 0}</div>
                        </div>
                        <div class="anum-item">
                            <div class="label">Need</div>
                            <div class="value">${contact.need_score?.toFixed(1) || 0}</div>
                        </div>
                        <div class="anum-item">
                            <div class="label">Urgency</div>
                            <div class="value">${contact.urgency_score?.toFixed(1) || 0}</div>
                        </div>
                        <div class="anum-item">
                            <div class="label">Money</div>
                            <div class="value">${contact.money_score?.toFixed(1) || 0}</div>
                        </div>
                    </div>
                </div>
                <div class="info-grid">
                    <div class="info-item">
                        <label>Estágio de Qualificação</label>
                        <value>${(contact.qualification_stage || 'N/A').toUpperCase()}</value>
                    </div>
                    <div class="info-item">
                        <label>Status de Qualificação</label>
                        <value>${contact.is_qualified ? '✓ QUALIFICADO' : '○ NÃO QUALIFICADO'}</value>
                    </div>
                    <div class="info-item">
                        <label>Análises Realizadas</label>
                        <value>${contact.analysis_count || 0}</value>
                    </div>
                    <div class="info-item">
                        <label>Categoria de Dor</label>
                        <value>${contact.pain_category || 'Não identificada'}</value>
                    </div>
                </div>
            ` : '<p>○ Ainda não foi analisado</p>'}
        </div>

        <!-- Estatísticas -->
        <div class="section">
            <h2>Estatísticas de Engajamento</h2>
            <div class="stats-grid">
                <div class="stat-card">
                    <div class="value">${stats.total_messages}</div>
                    <div class="label">Total de Mensagens</div>
                </div>
                <div class="stat-card">
                    <div class="value">${stats.user_messages}</div>
                    <div class="label">Mensagens do Lead</div>
                </div>
                <div class="stat-card">
                    <div class="value">${stats.bot_messages}</div>
                    <div class="label">Mensagens do Bot</div>
                </div>
                <div class="stat-card">
                    <div class="value">${reengagement.reengagement_count}</div>
                    <div class="label">Reengajamentos</div>
                </div>
            </div>
            <div class="info-grid" style="margin-top: 20px;">
                <div class="info-item">
                    <label>Total de Tokens</label>
                    <value>${stats.total_tokens.toLocaleString()}</value>
                </div>
                <div class="info-item">
                    <label>Custo Total (USD)</label>
                    <value>$${stats.total_cost.toFixed(4)}</value>
                </div>
                <div class="info-item">
                    <label>Maior Silêncio</label>
                    <value>${reengagement.longest_silence_hours.toFixed(1)} horas</value>
                </div>
            </div>
        </div>

        <!-- Campanha de Follow-up -->
        ${campaign ? `
        <div class="section">
            <h2>Campanha de Follow-up</h2>
            <div class="info-grid">
                <div class="info-item">
                    <label>Status</label>
                    <value>${campaign.status}</value>
                </div>
                <div class="info-item">
                    <label>Progresso</label>
                    <value>${campaign.steps_completed}/${campaign.total_steps} passos (${((campaign.steps_completed / campaign.total_steps) * 100).toFixed(1)}%)</value>
                </div>
            </div>
            ${executions.length > 0 ? `
                <div class="timeline" style="margin-top: 20px;">
                    ${executions.map(exec => {
                        let className = 'pending';
                        if (exec.executed && exec.sent_at) className = 'completed';
                        else if (!exec.should_send) className = 'cancelled';

                        return `
                            <div class="timeline-item ${className}">
                                <strong>Passo ${exec.step}/${exec.total_steps}</strong>
                                <div style="font-size: 0.9em; color: #666; margin-top: 5px;">
                                    Agendado: ${new Date(exec.scheduled_at).toLocaleString('pt-BR')}<br>
                                    ${exec.sent_at ? `Enviado: ${new Date(exec.sent_at).toLocaleString('pt-BR')}` : 'Não enviado'}
                                    ${exec.anum_at_execution !== null ? `<br>ANUM: ${exec.anum_at_execution.toFixed(1)}` : ''}
                                </div>
                            </div>
                        `;
                    }).join('')}
                </div>
            ` : ''}
        </div>
        ` : ''}

        <!-- Reuniões -->
        ${meetings.length > 0 ? `
        <div class="section">
            <h2>Reuniões</h2>
            ${meetings.map(meeting => `
                <div style="margin-bottom: 20px; padding: 15px; background: #f8f9fa; border-radius: 8px;">
                    <h3 style="color: #667eea; margin-bottom: 10px;">${meeting.cal_event_title || 'Reunião'}</h3>
                    <div class="info-grid">
                        <div class="info-item">
                            <label>Data/Hora</label>
                            <value>${new Date(meeting.meeting_date).toLocaleString('pt-BR')}</value>
                        </div>
                        <div class="info-item">
                            <label>Duração</label>
                            <value>${meeting.meeting_duration_minutes} minutos</value>
                        </div>
                        <div class="info-item">
                            <label>Status</label>
                            <value>${meeting.status}</value>
                        </div>
                        <div class="info-item">
                            <label>ANUM no Agendamento</label>
                            <value>${meeting.anum_score_at_booking?.toFixed(1) || 'N/A'}</value>
                        </div>
                    </div>
                </div>
            `).join('')}
        </div>
        ` : ''}

        <!-- Mensagens Recentes -->
        ${recentMessages.length > 0 ? `
        <div class="section">
            <h2>Últimas 20 Mensagens</h2>
            <div style="margin-top: 15px;">
                ${recentMessages.slice(-20).map(msg => `
                    <div class="message ${msg.role}">
                        <div class="sender">${msg.role === 'user' ? '👤 Lead' : msg.role === 'assistant' ? `🤖 ${contact.bot_name || 'Bot'}` : '⚙️ Sistema'}</div>
                        <div class="timestamp">${new Date(msg.message_timestamp).toLocaleString('pt-BR')}</div>
                        <div class="text">${msg.has_media ? `[${msg.message_type.toUpperCase()}] ` : ''}${msg.message.substring(0, 300)}${msg.message.length > 300 ? '...' : ''}</div>
                    </div>
                `).join('')}
            </div>
        </div>
        ` : ''}

        <div class="footer">
            Relatório gerado automaticamente pelo CoreAdapt v4 em ${new Date().toLocaleString('pt-BR')}
        </div>
    </div>
</body>
</html>
    `.trim();
}

// ============================================================================
// MAIN
// ============================================================================

async function main() {
    console.log('🚀 Gerando relatório de lead...\n');

    const options = parseArgs();

    try {
        // Fetch all data
        console.log('📊 Buscando informações do contato...');
        const contact = await getContactBasicInfo(options.contactId, options.whatsapp);

        if (!contact) {
            console.error('❌ Contato não encontrado!');
            process.exit(1);
        }

        console.log(`✓ Contato encontrado: ${contact.full_name}\n`);

        console.log('📧 Buscando campanha de follow-up...');
        const campaign = await getFollowupCampaign(contact.contact_id);
        console.log(`✓ ${campaign ? 'Campanha encontrada' : 'Nenhuma campanha'}\n`);

        console.log('📤 Buscando execuções de follow-up...');
        const executions = await getFollowupExecutions(contact.contact_id);
        console.log(`✓ ${executions.length} execuções encontradas\n`);

        console.log('📅 Buscando reuniões...');
        const meetings = await getMeetings(contact.contact_id);
        console.log(`✓ ${meetings.length} reuniões encontradas\n`);

        console.log('💬 Buscando histórico de mensagens...');
        const recentMessages = await getMessageHistory(contact.contact_id, options.includeFullHistory ? null : 50);
        console.log(`✓ ${recentMessages.length} mensagens encontradas\n`);

        console.log('📈 Calculando estatísticas...');
        const stats = await getEngagementStats(contact.contact_id);
        const reengagement = await getReengagementAnalysis(contact.contact_id);
        console.log('✓ Estatísticas calculadas\n');

        const data = {
            contact,
            campaign,
            executions,
            meetings,
            stats,
            reengagement,
            recentMessages
        };

        // Format output
        console.log('📝 Formatando relatório...\n');
        let output;

        if (options.format === 'json') {
            output = formatJSONReport(data);
        } else if (options.format === 'html') {
            output = formatHTMLReport(data);
        } else {
            output = formatTextReport(data);
        }

        // Output
        if (options.output) {
            fs.writeFileSync(options.output, output);
            console.log(`✓ Relatório salvo em: ${options.output}`);
        } else {
            console.log('\n' + output);
        }

        console.log('\n✅ Relatório gerado com sucesso!');

    } catch (error) {
        console.error('❌ Erro ao gerar relatório:', error);
        process.exit(1);
    }
}

// Run
if (require.main === module) {
    main();
}

module.exports = {
    getContactBasicInfo,
    getFollowupCampaign,
    getFollowupExecutions,
    getMeetings,
    getMessageHistory,
    getEngagementStats,
    getReengagementAnalysis,
    formatTextReport,
    formatJSONReport,
    formatHTMLReport
};
