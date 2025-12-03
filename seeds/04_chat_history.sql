-- ============================================================================
-- SEED: CHAT HISTORY (Histórico de Conversas)
-- CoreAdapt v4 | Tenant: CoreConnect (company_id = 1)
-- ============================================================================
-- Mensagens de conversa realistas para cada lead
-- Média de 8-12 mensagens por lead, variando conforme engajamento
-- ============================================================================

-- Limpar chat history dos contatos demo
DELETE FROM corev4_chat_history
WHERE contact_id IN (SELECT id FROM corev4_contacts WHERE tags @> ARRAY['demo']::text[]);

-- ============================================================================
-- LEAD 1001 - Ricardo Mendes (Highly Qualified - Tech)
-- ============================================================================
INSERT INTO corev4_chat_history (contact_id, company_id, session_id, role, message, message_type, tokens_used, cost_usd, model_used, message_timestamp, created_at)
VALUES
(1001, 1, 'sess-1001-001', 'user', 'Oi, vi o anúncio de vocês sobre automação de vendas', 'text', NULL, NULL, NULL, '2025-08-03 10:15:00'::timestamptz, '2025-08-03 10:15:00'::timestamptz),
(1001, 1, 'sess-1001-001', 'assistant', 'Olá Ricardo! Que bom receber sua mensagem! 🙂 Sou o Frank, assistente virtual da CoreConnect. Vi que você se interessou pela nossa solução de automação de vendas. Me conta um pouco, qual é o principal desafio que vocês enfrentam hoje na área comercial?', 'text', 245, 0.0024, 'gpt-4o-mini', '2025-08-03 10:15:32'::timestamptz, '2025-08-03 10:15:32'::timestamptz),
(1001, 1, 'sess-1001-001', 'user', 'Cara, nosso maior problema é escalar. Temos muito lead entrando mas a equipe não dá conta de qualificar tudo', 'text', NULL, NULL, NULL, '2025-08-03 10:18:00'::timestamptz, '2025-08-03 10:18:00'::timestamptz),
(1001, 1, 'sess-1001-001', 'assistant', 'Entendo perfeitamente, Ricardo! Esse é um desafio muito comum em empresas de tecnologia em crescimento. Quantos leads vocês recebem por mês aproximadamente? E qual o tamanho da equipe comercial hoje?', 'text', 198, 0.0019, 'gpt-4o-mini', '2025-08-03 10:18:28'::timestamptz, '2025-08-03 10:18:28'::timestamptz),
(1001, 1, 'sess-1001-001', 'user', 'Uns 500 leads/mês e somos 3 pessoas no comercial. Não conseguimos dar conta', 'text', NULL, NULL, NULL, '2025-08-03 10:20:00'::timestamptz, '2025-08-03 10:20:00'::timestamptz),
(1001, 1, 'sess-1001-001', 'assistant', 'Com 500 leads para 3 pessoas, são quase 170 leads por pessoa por mês! Realmente é muito difícil dar atenção de qualidade a todos. E você Ricardo, é quem toma as decisões sobre ferramentas de vendas na empresa?', 'text', 187, 0.0018, 'gpt-4o-mini', '2025-08-03 10:20:35'::timestamptz, '2025-08-03 10:20:35'::timestamptz),
(1001, 1, 'sess-1001-001', 'user', 'Sim, sou o diretor comercial. Tenho autonomia total pra isso', 'text', NULL, NULL, NULL, '2025-08-03 10:22:00'::timestamptz, '2025-08-03 10:22:00'::timestamptz),
(1001, 1, 'sess-1001-001', 'assistant', 'Ótimo, Ricardo! Isso facilita muito. E em termos de prazo, vocês estão buscando resolver isso com que urgência? Já tem um budget aprovado para esse tipo de solução?', 'text', 156, 0.0015, 'gpt-4o-mini', '2025-08-03 10:22:30'::timestamptz, '2025-08-03 10:22:30'::timestamptz),
(1001, 1, 'sess-1001-001', 'user', 'Urgente! Já perdemos muito dinheiro deixando lead esfriar. Temos budget de R$3-5k/mês aprovado pela diretoria', 'text', NULL, NULL, NULL, '2025-08-03 10:25:00'::timestamptz, '2025-08-03 10:25:00'::timestamptz),
(1001, 1, 'sess-1001-001', 'assistant', 'Ricardo, vocês são exatamente o perfil de empresa que mais se beneficia da nossa solução! A CoreConnect pode qualificar automaticamente esses 500 leads, identificando os mais quentes para seu time focar. Que tal agendarmos uma demonstração para você ver na prática?', 'text', 210, 0.0021, 'gpt-4o-mini', '2025-08-03 10:25:45'::timestamptz, '2025-08-03 10:25:45'::timestamptz),
(1001, 1, 'sess-1001-001', 'user', 'Vamos sim! Pode ser amanhã de tarde?', 'text', NULL, NULL, NULL, '2025-08-03 10:27:00'::timestamptz, '2025-08-03 10:27:00'::timestamptz),
(1001, 1, 'sess-1001-001', 'assistant', 'Perfeito! Vou verificar a agenda e te enviar um link para agendar o melhor horário. Você prefere reunião por vídeo ou presencial?', 'text', 145, 0.0014, 'gpt-4o-mini', '2025-08-03 10:27:28'::timestamptz, '2025-08-03 10:27:28'::timestamptz),
(1001, 1, 'sess-1001-001', 'user', 'Vídeo mesmo, mais prático', 'text', NULL, NULL, NULL, '2025-08-03 10:28:00'::timestamptz, '2025-08-03 10:28:00'::timestamptz),

-- ============================================================================
-- LEAD 1002 - Fernanda Costa (Qualified - Varejo Moda)
-- ============================================================================
(1002, 1, 'sess-1002-001', 'user', 'Boa tarde! Vi vocês no Instagram', 'text', NULL, NULL, NULL, '2025-08-10 09:00:00'::timestamptz, '2025-08-10 09:00:00'::timestamptz),
(1002, 1, 'sess-1002-001', 'assistant', 'Boa tarde, Fernanda! Que bom que nos encontrou! Sou o Frank, da CoreConnect. Como posso ajudar você hoje?', 'text', 178, 0.0017, 'gpt-4o-mini', '2025-08-10 09:00:35'::timestamptz, '2025-08-10 09:00:35'::timestamptz),
(1002, 1, 'sess-1002-001', 'user', 'Tenho uma loja de moda feminina e as vendas pelo WhatsApp estagnaram', 'text', NULL, NULL, NULL, '2025-08-10 09:03:00'::timestamptz, '2025-08-10 09:03:00'::timestamptz),
(1002, 1, 'sess-1002-001', 'assistant', 'Entendo, Fernanda. Muitas lojas de moda passam por isso. As clientes entram em contato mas não fecham? Ou o problema é que poucas chegam a entrar em contato?', 'text', 167, 0.0016, 'gpt-4o-mini', '2025-08-10 09:03:40'::timestamptz, '2025-08-10 09:03:40'::timestamptz),
(1002, 1, 'sess-1002-001', 'user', 'O pessoal entra em contato sim, mas demora pra responder e acaba não comprando', 'text', NULL, NULL, NULL, '2025-08-10 09:06:00'::timestamptz, '2025-08-10 09:06:00'::timestamptz),
(1002, 1, 'sess-1002-001', 'assistant', 'Ah, isso é muito comum no varejo! A demora na resposta faz a cliente perder o impulso de compra. Você tem alguém dedicado para responder WhatsApp ou faz você mesma?', 'text', 189, 0.0018, 'gpt-4o-mini', '2025-08-10 09:06:45'::timestamptz, '2025-08-10 09:06:45'::timestamptz),
(1002, 1, 'sess-1002-001', 'user', 'Sou eu mesma, mas fico muito ocupada com a loja física', 'text', NULL, NULL, NULL, '2025-08-10 09:09:00'::timestamptz, '2025-08-10 09:09:00'::timestamptz),
(1002, 1, 'sess-1002-001', 'assistant', 'Fernanda, a CoreConnect pode fazer esse primeiro atendimento automático, tirando dúvidas sobre produtos, tamanhos, preços e até já direcionando para o pagamento. Você só entra quando realmente precisa. Quantos contatos você recebe por dia no WhatsApp?', 'text', 234, 0.0023, 'gpt-4o-mini', '2025-08-10 09:09:50'::timestamptz, '2025-08-10 09:09:50'::timestamptz),
(1002, 1, 'sess-1002-001', 'user', 'Uns 20-30 por dia. Seria ótimo ter ajuda com isso!', 'text', NULL, NULL, NULL, '2025-08-10 09:12:00'::timestamptz, '2025-08-10 09:12:00'::timestamptz),

-- ============================================================================
-- LEAD 1003 - Carlos Eduardo (Developing - Atacado)
-- ============================================================================
(1003, 1, 'sess-1003-001', 'user', 'Olá, tudo bem?', 'text', NULL, NULL, NULL, '2025-08-15 08:30:00'::timestamptz, '2025-08-15 08:30:00'::timestamptz),
(1003, 1, 'sess-1003-001', 'assistant', 'Olá! Tudo ótimo por aqui, e com você? Sou o Frank, assistente da CoreConnect. Em que posso ajudar?', 'text', 156, 0.0015, 'gpt-4o-mini', '2025-08-15 08:30:30'::timestamptz, '2025-08-15 08:30:30'::timestamptz),
(1003, 1, 'sess-1003-001', 'user', 'Bem também. Estou pesquisando soluções de automação para minha distribuidora', 'text', NULL, NULL, NULL, '2025-08-15 08:33:00'::timestamptz, '2025-08-15 08:33:00'::timestamptz),
(1003, 1, 'sess-1003-001', 'assistant', 'Que legal, Carlos! Distribuidoras têm um fluxo grande de pedidos e orçamentos, né? O que vocês estão buscando automatizar especificamente?', 'text', 167, 0.0016, 'gpt-4o-mini', '2025-08-15 08:33:35'::timestamptz, '2025-08-15 08:33:35'::timestamptz),
(1003, 1, 'sess-1003-001', 'user', 'A gente recebe muito pedido de orçamento pelo whats e demora pra responder', 'text', NULL, NULL, NULL, '2025-08-15 08:36:00'::timestamptz, '2025-08-15 08:36:00'::timestamptz),
(1003, 1, 'sess-1003-001', 'assistant', 'Entendo! Automação de orçamentos é uma das funcionalidades mais pedidas. Você é o responsável pela área comercial na distribuidora?', 'text', 145, 0.0014, 'gpt-4o-mini', '2025-08-15 08:36:40'::timestamptz, '2025-08-15 08:36:40'::timestamptz),
(1003, 1, 'sess-1003-001', 'user', 'Não, sou gerente. Mas estou levantando opções pro diretor', 'text', NULL, NULL, NULL, '2025-08-15 08:39:00'::timestamptz, '2025-08-15 08:39:00'::timestamptz),
(1003, 1, 'sess-1003-001', 'assistant', 'Perfeito, Carlos! Posso te enviar um material completo sobre como a CoreConnect funciona para distribuidoras? Assim você consegue apresentar pro diretor com todas as informações.', 'text', 178, 0.0017, 'gpt-4o-mini', '2025-08-15 08:39:45'::timestamptz, '2025-08-15 08:39:45'::timestamptz),
(1003, 1, 'sess-1003-001', 'user', 'Pode enviar sim, vou analisar', 'text', NULL, NULL, NULL, '2025-08-15 08:41:00'::timestamptz, '2025-08-15 08:41:00'::timestamptz),

-- ============================================================================
-- LEAD 1004 - Dra. Mariana (Qualified - Saúde)
-- ============================================================================
(1004, 1, 'sess-1004-001', 'user', 'Oi! Sou médica e tenho uma clínica. Vocês atendem área de saúde?', 'text', NULL, NULL, NULL, '2025-08-20 14:00:00'::timestamptz, '2025-08-20 14:00:00'::timestamptz),
(1004, 1, 'sess-1004-001', 'assistant', 'Olá, Dra. Mariana! Sim, atendemos várias clínicas médicas! Sou o Frank, da CoreConnect. Qual é a sua especialidade e qual desafio vocês estão enfrentando?', 'text', 189, 0.0018, 'gpt-4o-mini', '2025-08-20 14:00:40'::timestamptz, '2025-08-20 14:00:40'::timestamptz),
(1004, 1, 'sess-1004-001', 'user', 'Sou dermatologista. Minha secretária não dá conta de atender tudo, muita gente querendo agendar consulta', 'text', NULL, NULL, NULL, '2025-08-20 14:03:00'::timestamptz, '2025-08-20 14:03:00'::timestamptz),
(1004, 1, 'sess-1004-001', 'assistant', 'Dermatologia tem demanda alta mesmo! O atendimento automatizado pode fazer triagem, tirar dúvidas sobre valores, horários disponíveis e até já confirmar agendamento. A senhora é proprietária da clínica?', 'text', 198, 0.0019, 'gpt-4o-mini', '2025-08-20 14:03:45'::timestamptz, '2025-08-20 14:03:45'::timestamptz),
(1004, 1, 'sess-1004-001', 'user', 'Sim, sou dona. Quero algo pra ontem! kkkk', 'text', NULL, NULL, NULL, '2025-08-20 14:05:00'::timestamptz, '2025-08-20 14:05:00'::timestamptz),
(1004, 1, 'sess-1004-001', 'assistant', 'Haha, entendo a urgência, Dra. Mariana! Muitas clínicas perdem pacientes por demora no retorno. Temos um plano específico para área de saúde. Que tal uma demonstração rápida de 20 minutos?', 'text', 187, 0.0018, 'gpt-4o-mini', '2025-08-20 14:05:50'::timestamptz, '2025-08-20 14:05:50'::timestamptz),
(1004, 1, 'sess-1004-001', 'user', 'Pode ser! Mas só consigo quinta à tarde', 'text', NULL, NULL, NULL, '2025-08-20 14:07:00'::timestamptz, '2025-08-20 14:07:00'::timestamptz),

-- ============================================================================
-- LEAD 1012 - Beatriz (Highly Qualified - Fintech)
-- ============================================================================
(1012, 1, 'sess-1012-001', 'user', 'Bom dia! Sou CEO de uma fintech e preciso urgente de uma solução de qualificação de leads', 'text', NULL, NULL, NULL, '2025-09-12 11:00:00'::timestamptz, '2025-09-12 11:00:00'::timestamptz),
(1012, 1, 'sess-1012-001', 'assistant', 'Bom dia, Beatriz! Que ótimo receber seu contato! Sou o Frank, da CoreConnect. Fintechs são um dos setores que mais atendemos. Me conta, qual é o volume de leads que vocês recebem e qual o principal gargalo hoje?', 'text', 234, 0.0023, 'gpt-4o-mini', '2025-09-12 11:00:45'::timestamptz, '2025-09-12 11:00:45'::timestamptz),
(1012, 1, 'sess-1012-001', 'user', 'Recebemos 2000 leads/mês pelo site e campanhas. Só 5% vira cliente. Preciso melhorar isso', 'text', NULL, NULL, NULL, '2025-09-12 11:03:00'::timestamptz, '2025-09-12 11:03:00'::timestamptz),
(1012, 1, 'sess-1012-001', 'assistant', 'Com 2000 leads e 5% de conversão, vocês fecham cerca de 100 clientes por mês. O desafio é identificar os leads mais quentes entre os 2000, certo? Já testaram alguma ferramenta de qualificação?', 'text', 198, 0.0019, 'gpt-4o-mini', '2025-09-12 11:03:50'::timestamptz, '2025-09-12 11:03:50'::timestamptz),
(1012, 1, 'sess-1012-001', 'user', 'Já testamos 2 concorrentes mas não funcionaram bem. Preciso de algo mais inteligente', 'text', NULL, NULL, NULL, '2025-09-12 11:06:00'::timestamptz, '2025-09-12 11:06:00'::timestamptz),
(1012, 1, 'sess-1012-001', 'assistant', 'Entendo! Muitas ferramentas usam regras fixas, mas a CoreConnect usa IA para analisar o contexto da conversa e identificar intenção real de compra. Como CEO, você tem autonomia para contratar?', 'text', 212, 0.0021, 'gpt-4o-mini', '2025-09-12 11:06:55'::timestamptz, '2025-09-12 11:06:55'::timestamptz),
(1012, 1, 'sess-1012-001', 'user', 'Sim, total. E tenho budget de até R$10k/mês pra isso. Quando podemos ver uma demo?', 'text', NULL, NULL, NULL, '2025-09-12 11:09:00'::timestamptz, '2025-09-12 11:09:00'::timestamptz),
(1012, 1, 'sess-1012-001', 'assistant', 'Beatriz, vocês são o perfil perfeito! Com esse volume e budget, consigo montar uma proposta bem robusta. Posso agendar uma demo para ainda esta semana?', 'text', 178, 0.0017, 'gpt-4o-mini', '2025-09-12 11:09:50'::timestamptz, '2025-09-12 11:09:50'::timestamptz),
(1012, 1, 'sess-1012-001', 'user', 'Amanhã à tarde seria ideal!', 'text', NULL, NULL, NULL, '2025-09-12 11:11:00'::timestamptz, '2025-09-12 11:11:00'::timestamptz),

-- ============================================================================
-- LEAD 1021 - Eduardo (Qualified - Consultoria)
-- ============================================================================
(1021, 1, 'sess-1021-001', 'user', 'Boa tarde, trabalho com consultoria empresarial', 'text', NULL, NULL, NULL, '2025-10-01 08:30:00'::timestamptz, '2025-10-01 08:30:00'::timestamptz),
(1021, 1, 'sess-1021-001', 'assistant', 'Boa tarde, Eduardo! Consultoria é uma área que se beneficia muito de qualificação inteligente de leads. Em que posso ajudar?', 'text', 156, 0.0015, 'gpt-4o-mini', '2025-10-01 08:30:35'::timestamptz, '2025-10-01 08:30:35'::timestamptz),
(1021, 1, 'sess-1021-001', 'user', 'Preciso entender melhor o perfil dos leads antes de investir tempo em reuniões', 'text', NULL, NULL, NULL, '2025-10-01 08:33:00'::timestamptz, '2025-10-01 08:33:00'::timestamptz),
(1021, 1, 'sess-1021-001', 'assistant', 'Exatamente! Em consultoria, cada reunião demanda preparo. Qualificar antes economiza muito tempo. Você é sócio da consultoria?', 'text', 145, 0.0014, 'gpt-4o-mini', '2025-10-01 08:33:40'::timestamptz, '2025-10-01 08:33:40'::timestamptz),
(1021, 1, 'sess-1021-001', 'user', 'Sim, sou sócio-fundador. Tenho 15 anos de mercado', 'text', NULL, NULL, NULL, '2025-10-01 08:35:00'::timestamptz, '2025-10-01 08:35:00'::timestamptz),
(1021, 1, 'sess-1021-001', 'assistant', 'Que bacana, Eduardo! Com 15 anos você sabe bem o valor do tempo. A CoreConnect faz uma pré-qualificação conversacional, coletando informações-chave antes da sua equipe entrar. Quantos leads vocês recebem por mês?', 'text', 198, 0.0019, 'gpt-4o-mini', '2025-10-01 08:35:50'::timestamptz, '2025-10-01 08:35:50'::timestamptz),
(1021, 1, 'sess-1021-001', 'user', 'Uns 50 leads qualificados vindos de indicação e LinkedIn', 'text', NULL, NULL, NULL, '2025-10-01 08:38:00'::timestamptz, '2025-10-01 08:38:00'::timestamptz),

-- ============================================================================
-- LEAD 1028 - Larissa (Highly Qualified - E-commerce)
-- ============================================================================
(1028, 1, 'sess-1028-001', 'user', 'Oi! Tenho um e-commerce e preciso converter mais', 'text', NULL, NULL, NULL, '2025-10-17 09:00:00'::timestamptz, '2025-10-17 09:00:00'::timestamptz),
(1028, 1, 'sess-1028-001', 'assistant', 'Olá Larissa! E-commerce é um dos segmentos que mais cresce com automação de vendas! Qual é o seu nicho e volume de visitantes?', 'text', 167, 0.0016, 'gpt-4o-mini', '2025-10-17 09:00:40'::timestamptz, '2025-10-17 09:00:40'::timestamptz),
(1028, 1, 'sess-1028-001', 'user', 'Vendo produtos de skincare. 50mil visitas/mês e só 2% converte', 'text', NULL, NULL, NULL, '2025-10-17 09:03:00'::timestamptz, '2025-10-17 09:03:00'::timestamptz),
(1028, 1, 'sess-1028-001', 'assistant', 'Skincare tem alto potencial! 50 mil visitas com 2% dá 1000 vendas. Se a gente aumentar pra 3%, são 500 vendas a mais! Vocês usam WhatsApp para recuperar carrinhos abandonados?', 'text', 198, 0.0019, 'gpt-4o-mini', '2025-10-17 09:03:50'::timestamptz, '2025-10-17 09:03:50'::timestamptz),
(1028, 1, 'sess-1028-001', 'user', 'Usamos mas manual. Não damos conta de todos', 'text', NULL, NULL, NULL, '2025-10-17 09:06:00'::timestamptz, '2025-10-17 09:06:00'::timestamptz),
(1028, 1, 'sess-1028-001', 'assistant', 'Exatamente o problema que resolvemos! Automação para recuperar carrinhos, tirar dúvidas sobre produtos e já fechar a venda. Você é dona do e-commerce?', 'text', 178, 0.0017, 'gpt-4o-mini', '2025-10-17 09:06:45'::timestamptz, '2025-10-17 09:06:45'::timestamptz),
(1028, 1, 'sess-1028-001', 'user', 'Sim! Fundei há 3 anos. Tô pronta pra investir no que funcionar', 'text', NULL, NULL, NULL, '2025-10-17 09:08:00'::timestamptz, '2025-10-17 09:08:00'::timestamptz),

-- ============================================================================
-- LEAD 1034 - Priscila (Pre-qualified - Laboratorio)
-- ============================================================================
(1034, 1, 'sess-1034-001', 'user', 'Oi, só queria saber mais sobre o que vocês fazem', 'text', NULL, NULL, NULL, '2025-10-27 10:00:00'::timestamptz, '2025-10-27 10:00:00'::timestamptz),
(1034, 1, 'sess-1034-001', 'assistant', 'Olá! Claro, Priscila! Somos a CoreConnect, uma plataforma de qualificação de leads usando IA. Ajudamos empresas a identificar os melhores prospects automaticamente. Você trabalha em qual área?', 'text', 189, 0.0018, 'gpt-4o-mini', '2025-10-27 10:00:45'::timestamptz, '2025-10-27 10:00:45'::timestamptz),
(1034, 1, 'sess-1034-001', 'user', 'Laboratório de análises clínicas. Só tô pesquisando mesmo por enquanto', 'text', NULL, NULL, NULL, '2025-10-27 10:03:00'::timestamptz, '2025-10-27 10:03:00'::timestamptz),
(1034, 1, 'sess-1034-001', 'assistant', 'Sem problemas! Pesquisar bem antes de decidir é importante. Quer que eu envie um material explicativo sobre como funcionamos com empresas de saúde?', 'text', 145, 0.0014, 'gpt-4o-mini', '2025-10-27 10:03:40'::timestamptz, '2025-10-27 10:03:40'::timestamptz),
(1034, 1, 'sess-1034-001', 'user', 'Pode enviar, mas não sei quando vou olhar', 'text', NULL, NULL, NULL, '2025-10-27 10:05:00'::timestamptz, '2025-10-27 10:05:00'::timestamptz),

-- ============================================================================
-- LEAD 1047 - Pedro (Qualified - Laboratório - Dezembro)
-- ============================================================================
(1047, 1, 'sess-1047-001', 'user', 'Boa tarde! Vi que vocês trabalham com automação para área de saúde', 'text', NULL, NULL, NULL, '2025-12-01 14:00:00'::timestamptz, '2025-12-01 14:00:00'::timestamptz),
(1047, 1, 'sess-1047-001', 'assistant', 'Boa tarde, Pedro! Sim, temos várias clínicas e laboratórios como clientes! Você é de qual área?', 'text', 156, 0.0015, 'gpt-4o-mini', '2025-12-01 14:00:35'::timestamptz, '2025-12-01 14:00:35'::timestamptz),
(1047, 1, 'sess-1047-001', 'user', 'Tenho um laboratório de análises clínicas. Quero automatizar agendamentos', 'text', NULL, NULL, NULL, '2025-12-01 14:03:00'::timestamptz, '2025-12-01 14:03:00'::timestamptz),
(1047, 1, 'sess-1047-001', 'assistant', 'Laboratórios têm muito volume de agendamento mesmo! A automação pode fazer triagem, confirmar exames que precisam de preparo, e já agendar. Você é proprietário?', 'text', 178, 0.0017, 'gpt-4o-mini', '2025-12-01 14:03:45'::timestamptz, '2025-12-01 14:03:45'::timestamptz),
(1047, 1, 'sess-1047-001', 'user', 'Sim, sou dono. Temos 3 unidades em SP', 'text', NULL, NULL, NULL, '2025-12-01 14:05:00'::timestamptz, '2025-12-01 14:05:00'::timestamptz),
(1047, 1, 'sess-1047-001', 'assistant', 'Três unidades é um bom porte! A centralização do atendimento inicial pode otimizar muito a operação. Qual o volume de agendamentos por dia nas 3 unidades?', 'text', 167, 0.0016, 'gpt-4o-mini', '2025-12-01 14:05:50'::timestamptz, '2025-12-01 14:05:50'::timestamptz),
(1047, 1, 'sess-1047-001', 'user', 'Uns 200 agendamentos/dia no total. Muito trabalho manual', 'text', NULL, NULL, NULL, '2025-12-01 14:08:00'::timestamptz, '2025-12-01 14:08:00'::timestamptz);

-- ============================================================================
-- GERAÇÃO EM MASSA - Conversas adicionais para outros leads
-- ============================================================================
-- Usando padrão de mensagens para manter consistência

-- Lead 1005 (Agro)
INSERT INTO corev4_chat_history (contact_id, company_id, session_id, role, message, message_type, tokens_used, cost_usd, model_used, message_timestamp, created_at)
SELECT
    1005, 1, 'sess-1005-001',
    CASE WHEN n % 2 = 1 THEN 'user' ELSE 'assistant' END,
    CASE
        WHEN n = 1 THEN 'Olá, trabalho no agronegócio'
        WHEN n = 2 THEN 'Olá! O agronegócio tem desafios únicos de vendas! Me conta mais sobre sua operação?'
        WHEN n = 3 THEN 'Vendemos insumos agrícolas. O ciclo de venda é longo'
        WHEN n = 4 THEN 'Entendo! Insumos têm sazonalidade forte. Vocês usam WhatsApp para prospecção?'
        WHEN n = 5 THEN 'Usamos mas é bem informal ainda'
        WHEN n = 6 THEN 'Posso mostrar como estruturar isso melhor. Você é responsável pelas vendas?'
        ELSE 'Sou gerente comercial. Vou avaliar com calma'
    END,
    'text',
    CASE WHEN n % 2 = 0 THEN 156 + (n * 10) ELSE NULL END,
    CASE WHEN n % 2 = 0 THEN 0.0015 + (n * 0.0001) ELSE NULL END,
    CASE WHEN n % 2 = 0 THEN 'gpt-4o-mini' ELSE NULL END,
    '2025-08-23 11:00:00'::timestamptz + (n * INTERVAL '3 minutes'),
    '2025-08-23 11:00:00'::timestamptz + (n * INTERVAL '3 minutes')
FROM generate_series(1, 7) AS n;

-- Lead 1009 (Construção Civil)
INSERT INTO corev4_chat_history (contact_id, company_id, session_id, role, message, message_type, tokens_used, cost_usd, model_used, message_timestamp, created_at)
SELECT
    1009, 1, 'sess-1009-001',
    CASE WHEN n % 2 = 1 THEN 'user' ELSE 'assistant' END,
    CASE
        WHEN n = 1 THEN 'Bom dia, sou da área de construção civil'
        WHEN n = 2 THEN 'Bom dia Roberto! Construção civil tem vendas complexas, né? Como posso ajudar?'
        WHEN n = 3 THEN 'Nosso time de vendas não consegue dar conta dos leads de incorporações'
        WHEN n = 4 THEN 'Incorporações têm ticket alto e ciclo longo. Quantos leads vocês recebem por mês?'
        WHEN n = 5 THEN 'Uns 300 interessados em apartamentos novos'
        WHEN n = 6 THEN 'É muito! Automação pode fazer pré-atendimento e qualificar. Você decide sobre ferramentas?'
        WHEN n = 7 THEN 'Sou diretor comercial, tenho autonomia pra isso'
        WHEN n = 8 THEN 'Ótimo! Posso agendar uma demonstração focada em incorporadoras?'
        ELSE 'Pode sim, me manda os horários'
    END,
    'text',
    CASE WHEN n % 2 = 0 THEN 167 + (n * 8) ELSE NULL END,
    CASE WHEN n % 2 = 0 THEN 0.0016 + (n * 0.0001) ELSE NULL END,
    CASE WHEN n % 2 = 0 THEN 'gpt-4o-mini' ELSE NULL END,
    '2025-09-02 09:00:00'::timestamptz + (n * INTERVAL '2 minutes'),
    '2025-09-02 09:00:00'::timestamptz + (n * INTERVAL '2 minutes')
FROM generate_series(1, 9) AS n;

-- Lead 1019 (Software House)
INSERT INTO corev4_chat_history (contact_id, company_id, session_id, role, message, message_type, tokens_used, cost_usd, model_used, message_timestamp, created_at)
SELECT
    1019, 1, 'sess-1019-001',
    CASE WHEN n % 2 = 1 THEN 'user' ELSE 'assistant' END,
    CASE
        WHEN n = 1 THEN 'E aí! Tenho uma software house e preciso qualificar leads B2B'
        WHEN n = 2 THEN 'Fala Felipe! Software houses têm vendas consultivas. Qual o principal produto de vocês?'
        WHEN n = 3 THEN 'Desenvolvemos ERPs customizados. Ticket médio de R$50k'
        WHEN n = 4 THEN 'Ticket alto exige qualificação bem feita! Vocês perdem tempo com leads sem budget?'
        WHEN n = 5 THEN 'Demais! 80% das reuniões não fecham por falta de verba'
        WHEN n = 6 THEN 'A CoreConnect pode identificar budget antes da reunião. Você toma decisões de compra?'
        WHEN n = 7 THEN 'Sim, sou sócio. Posso fechar hoje se fizer sentido'
        WHEN n = 8 THEN 'Top! Vou preparar uma proposta personalizada. Podemos conversar amanhã?'
        ELSE 'Amanhã 14h funciona!'
    END,
    'text',
    CASE WHEN n % 2 = 0 THEN 178 + (n * 7) ELSE NULL END,
    CASE WHEN n % 2 = 0 THEN 0.0017 + (n * 0.0001) ELSE NULL END,
    CASE WHEN n % 2 = 0 THEN 'gpt-4o-mini' ELSE NULL END,
    '2025-09-29 09:00:00'::timestamptz + (n * INTERVAL '4 minutes'),
    '2025-09-29 09:00:00'::timestamptz + (n * INTERVAL '4 minutes')
FROM generate_series(1, 9) AS n;

-- Lead 1040 (Supermercado)
INSERT INTO corev4_chat_history (contact_id, company_id, session_id, role, message, message_type, tokens_used, cost_usd, model_used, message_timestamp, created_at)
SELECT
    1040, 1, 'sess-1040-001',
    CASE WHEN n % 2 = 1 THEN 'user' ELSE 'assistant' END,
    CASE
        WHEN n = 1 THEN 'Oi, tenho uma rede de supermercados em MG'
        WHEN n = 2 THEN 'Oi Tatiana! Redes de supermercados têm grande volume de atendimento. Como posso ajudar?'
        WHEN n = 3 THEN 'Quero reduzir custos com atendimento ao cliente no WhatsApp'
        WHEN n = 4 THEN 'Faz sentido! Vocês recebem muitas dúvidas sobre ofertas, horários, etc?'
        WHEN n = 5 THEN 'Sim! Milhares de mensagens por dia nas 5 lojas'
        WHEN n = 6 THEN 'Milhares é muito! Automação resolve 80% dessas dúvidas. Você é dona da rede?'
        WHEN n = 7 THEN 'Sim, fundei com meu marido há 12 anos'
        WHEN n = 8 THEN 'Que legal! Posso mostrar cases de outros supermercados que atendemos?'
        ELSE 'Pode sim, me manda'
    END,
    'text',
    CASE WHEN n % 2 = 0 THEN 156 + (n * 9) ELSE NULL END,
    CASE WHEN n % 2 = 0 THEN 0.0015 + (n * 0.0001) ELSE NULL END,
    CASE WHEN n % 2 = 0 THEN 'gpt-4o-mini' ELSE NULL END,
    '2025-11-13 10:00:00'::timestamptz + (n * INTERVAL '3 minutes'),
    '2025-11-13 10:00:00'::timestamptz + (n * INTERVAL '3 minutes')
FROM generate_series(1, 9) AS n;

-- Conversas curtas para leads Pre-qualified (apenas curiosidade)
INSERT INTO corev4_chat_history (contact_id, company_id, session_id, role, message, message_type, tokens_used, cost_usd, model_used, message_timestamp, created_at)
VALUES
-- Lead 1042 (Veterinário)
(1042, 1, 'sess-1042-001', 'user', 'Oi, o que vocês fazem?', 'text', NULL, NULL, NULL, '2025-11-19 09:00:00'::timestamptz, '2025-11-19 09:00:00'::timestamptz),
(1042, 1, 'sess-1042-001', 'assistant', 'Olá Mariana! Somos uma plataforma de automação de vendas com IA. Você trabalha em qual área?', 'text', 145, 0.0014, 'gpt-4o-mini', '2025-11-19 09:00:35'::timestamptz, '2025-11-19 09:00:35'::timestamptz),
(1042, 1, 'sess-1042-001', 'user', 'Tenho uma clínica veterinária. Só tava curiosa mesmo', 'text', NULL, NULL, NULL, '2025-11-19 09:02:00'::timestamptz, '2025-11-19 09:02:00'::timestamptz),
(1042, 1, 'sess-1042-001', 'assistant', 'Sem problemas! Fico à disposição se quiser saber mais no futuro. Bom dia!', 'text', 123, 0.0012, 'gpt-4o-mini', '2025-11-19 09:02:30'::timestamptz, '2025-11-19 09:02:30'::timestamptz),

-- Lead 1043 (Frigorífico)
(1043, 1, 'sess-1043-001', 'user', 'Boa tarde', 'text', NULL, NULL, NULL, '2025-11-22 14:00:00'::timestamptz, '2025-11-22 14:00:00'::timestamptz),
(1043, 1, 'sess-1043-001', 'assistant', 'Boa tarde! Sou o Frank, da CoreConnect. Como posso ajudar?', 'text', 134, 0.0013, 'gpt-4o-mini', '2025-11-22 14:00:30'::timestamptz, '2025-11-22 14:00:30'::timestamptz),
(1043, 1, 'sess-1043-001', 'user', 'Só queria entender o que é isso de IA pra vendas', 'text', NULL, NULL, NULL, '2025-11-22 14:02:00'::timestamptz, '2025-11-22 14:02:00'::timestamptz),
(1043, 1, 'sess-1043-001', 'assistant', 'Claro! Basicamente, usamos inteligência artificial para conversar com seus potenciais clientes 24h, qualificando os melhores para seu time comercial focar. Você trabalha em qual setor?', 'text', 178, 0.0017, 'gpt-4o-mini', '2025-11-22 14:02:45'::timestamptz, '2025-11-22 14:02:45'::timestamptz),
(1043, 1, 'sess-1043-001', 'user', 'Frigorífico. Mas só queria saber mesmo, não estou precisando agora', 'text', NULL, NULL, NULL, '2025-11-22 14:04:00'::timestamptz, '2025-11-22 14:04:00'::timestamptz),

-- Lead 1048 (E-commerce CE)
(1048, 1, 'sess-1048-001', 'user', 'Oi! Vi no Facebook', 'text', NULL, NULL, NULL, '2025-12-02 08:00:00'::timestamptz, '2025-12-02 08:00:00'::timestamptz),
(1048, 1, 'sess-1048-001', 'assistant', 'Olá Renata! Que bom! Sou o Frank. Você tem uma loja online?', 'text', 134, 0.0013, 'gpt-4o-mini', '2025-12-02 08:00:30'::timestamptz, '2025-12-02 08:00:30'::timestamptz),
(1048, 1, 'sess-1048-001', 'user', 'Sim, mas é pequena ainda. Não sei se faz sentido pra mim', 'text', NULL, NULL, NULL, '2025-12-02 08:02:00'::timestamptz, '2025-12-02 08:02:00'::timestamptz),
(1048, 1, 'sess-1048-001', 'assistant', 'Entendo! Temos planos para diferentes tamanhos. Quantos pedidos por mês você faz?', 'text', 145, 0.0014, 'gpt-4o-mini', '2025-12-02 08:02:35'::timestamptz, '2025-12-02 08:02:35'::timestamptz),
(1048, 1, 'sess-1048-001', 'user', 'Uns 30-40 pedidos. Ainda tô começando', 'text', NULL, NULL, NULL, '2025-12-02 08:04:00'::timestamptz, '2025-12-02 08:04:00'::timestamptz);

-- Verificar total de mensagens inseridas
SELECT
    COUNT(*) AS total_mensagens,
    COUNT(DISTINCT contact_id) AS leads_com_conversa,
    SUM(CASE WHEN role = 'user' THEN 1 ELSE 0 END) AS msgs_usuario,
    SUM(CASE WHEN role = 'assistant' THEN 1 ELSE 0 END) AS msgs_frank,
    ROUND(SUM(COALESCE(cost_usd, 0))::numeric, 4) AS custo_total_usd
FROM corev4_chat_history
WHERE contact_id >= 1001 AND contact_id <= 1053;
