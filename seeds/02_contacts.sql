-- ============================================================================
-- SEED: CONTACTS (Leads Brasileiros)
-- CoreAdapt v4 | Tenant: CoreConnect (company_id = 1)
-- ============================================================================
-- 50 leads com nomes brasileiros, diversos setores e origens
-- IDs: 1001-1050 (para não conflitar com dados existentes)
-- Tag 'demo' para identificação e limpeza posterior
-- ============================================================================

-- Limpar dados demo anteriores (se existirem)
DELETE FROM corev4_contacts WHERE tags @> ARRAY['demo']::text[] AND company_id = 1;

-- Inserir 50 leads brasileiros
INSERT INTO corev4_contacts (
    id, company_id, full_name, whatsapp, phone_number, email,
    origin_source, utm_source, utm_medium, utm_campaign,
    sector, tags, opt_out, is_active, last_interaction_at, created_at, updated_at
) VALUES
-- ============================================================================
-- AGOSTO 2025 (8 leads) - Início da operação
-- ============================================================================
(1001, 1, 'Ricardo Mendes Silva', '5511999001001@s.whatsapp.net', '11999001001', 'ricardo.mendes@techsolutions.com.br',
 'whatsapp', 'google', 'cpc', 'automacao-vendas-ago25',
 'Tecnologia', ARRAY['demo', 'pme', 'tech'], false, true,
 '2025-08-05 14:30:00'::timestamptz, '2025-08-03 10:15:00'::timestamptz, '2025-08-05 14:30:00'::timestamptz),

(1002, 1, 'Fernanda Costa Oliveira', '5521988002002@s.whatsapp.net', '21988002002', 'fernanda.costa@modaelegance.com.br',
 'whatsapp', 'instagram', 'social', 'moda-varejo-ago25',
 'Varejo', ARRAY['demo', 'varejo', 'moda'], false, true,
 '2025-08-12 16:45:00'::timestamptz, '2025-08-10 09:00:00'::timestamptz, '2025-08-12 16:45:00'::timestamptz),

(1003, 1, 'Carlos Eduardo Ferreira', '5531977003003@s.whatsapp.net', '31977003003', 'carlos.ferreira@distribuidorabr.com.br',
 'whatsapp', 'google', 'organic', NULL,
 'Atacado/Distribuição', ARRAY['demo', 'atacado', 'distribuicao'], false, true,
 '2025-08-18 11:20:00'::timestamptz, '2025-08-15 08:30:00'::timestamptz, '2025-08-18 11:20:00'::timestamptz),

(1004, 1, 'Dra. Mariana Santos Lima', '5511966004004@s.whatsapp.net', '11966004004', 'dra.mariana@clinicasaude.med.br',
 'whatsapp', 'google', 'cpc', 'clinicas-medicas-ago25',
 'Saúde', ARRAY['demo', 'saude', 'clinica'], false, true,
 '2025-08-22 10:00:00'::timestamptz, '2025-08-20 14:00:00'::timestamptz, '2025-08-22 10:00:00'::timestamptz),

(1005, 1, 'José Roberto Almeida', '5585988005005@s.whatsapp.net', '85988005005', 'jose.almeida@agroindustria.com.br',
 'whatsapp', 'facebook', 'social', 'agro-nordeste-ago25',
 'Agronegócio', ARRAY['demo', 'agro', 'industria'], false, true,
 '2025-08-25 15:30:00'::timestamptz, '2025-08-23 11:00:00'::timestamptz, '2025-08-25 15:30:00'::timestamptz),

(1006, 1, 'Ana Paula Rodrigues', '5541955006006@s.whatsapp.net', '41955006006', 'ana.rodrigues@educacaoplus.com.br',
 'whatsapp', 'linkedin', 'social', 'educacao-sul-ago25',
 'Educação', ARRAY['demo', 'educacao', 'edtech'], false, true,
 '2025-08-28 09:15:00'::timestamptz, '2025-08-26 16:00:00'::timestamptz, '2025-08-28 09:15:00'::timestamptz),

(1007, 1, 'Marcelo Souza Neto', '5519944007007@s.whatsapp.net', '19944007007', 'marcelo.neto@autospecas.com.br',
 'whatsapp', 'google', 'cpc', 'autopecas-ago25',
 'Automotivo', ARRAY['demo', 'automotivo', 'pecas'], false, true,
 '2025-08-30 13:45:00'::timestamptz, '2025-08-28 10:30:00'::timestamptz, '2025-08-30 13:45:00'::timestamptz),

(1008, 1, 'Juliana Martins Pereira', '5511933008008@s.whatsapp.net', '11933008008', 'juliana.martins@belezaecia.com.br',
 'whatsapp', 'instagram', 'social', 'beleza-sp-ago25',
 'Beleza/Estética', ARRAY['demo', 'beleza', 'estetica'], false, true,
 '2025-08-31 17:00:00'::timestamptz, '2025-08-29 14:00:00'::timestamptz, '2025-08-31 17:00:00'::timestamptz),

-- ============================================================================
-- SETEMBRO 2025 (12 leads) - Crescimento
-- ============================================================================
(1009, 1, 'Roberto Carlos Gomes', '5521922009009@s.whatsapp.net', '21922009009', 'roberto.gomes@construtoraalpha.com.br',
 'whatsapp', 'google', 'cpc', 'construcao-set25',
 'Construção Civil', ARRAY['demo', 'construcao', 'engenharia'], false, true,
 '2025-09-05 11:30:00'::timestamptz, '2025-09-02 09:00:00'::timestamptz, '2025-09-05 11:30:00'::timestamptz),

(1010, 1, 'Patrícia Helena Dias', '5531911010010@s.whatsapp.net', '31911010010', 'patricia.dias@pharmaplus.com.br',
 'whatsapp', 'google', 'organic', NULL,
 'Farmacêutico', ARRAY['demo', 'farma', 'saude'], false, true,
 '2025-09-08 14:20:00'::timestamptz, '2025-09-05 10:00:00'::timestamptz, '2025-09-08 14:20:00'::timestamptz),

(1011, 1, 'André Luiz Moreira', '5548900011011@s.whatsapp.net', '48900011011', 'andre.moreira@logisticasul.com.br',
 'whatsapp', 'linkedin', 'social', 'logistica-sc-set25',
 'Logística', ARRAY['demo', 'logistica', 'transporte'], false, true,
 '2025-09-12 10:00:00'::timestamptz, '2025-09-10 08:30:00'::timestamptz, '2025-09-12 10:00:00'::timestamptz),

(1012, 1, 'Beatriz Campos Lima', '5511899012012@s.whatsapp.net', '11899012012', 'beatriz.campos@fintechbr.com.br',
 'whatsapp', 'google', 'cpc', 'fintech-sp-set25',
 'Fintech', ARRAY['demo', 'fintech', 'tech'], false, true,
 '2025-09-15 16:30:00'::timestamptz, '2025-09-12 11:00:00'::timestamptz, '2025-09-15 16:30:00'::timestamptz),

(1013, 1, 'Paulo Henrique Barbosa', '5562888013013@s.whatsapp.net', '62888013013', 'paulo.barbosa@alimentosbom.com.br',
 'whatsapp', 'facebook', 'social', 'alimentos-go-set25',
 'Alimentos', ARRAY['demo', 'alimentos', 'industria'], false, true,
 '2025-09-18 09:45:00'::timestamptz, '2025-09-15 14:00:00'::timestamptz, '2025-09-18 09:45:00'::timestamptz),

(1014, 1, 'Camila Rocha Santos', '5521877014014@s.whatsapp.net', '21877014014', 'camila.rocha@imobiliariaprime.com.br',
 'whatsapp', 'google', 'cpc', 'imoveis-rj-set25',
 'Imobiliário', ARRAY['demo', 'imobiliario', 'vendas'], false, true,
 '2025-09-22 15:00:00'::timestamptz, '2025-09-19 10:30:00'::timestamptz, '2025-09-22 15:00:00'::timestamptz),

(1015, 1, 'Dr. Marcos Vinícius Teixeira', '5511866015015@s.whatsapp.net', '11866015015', 'dr.marcos@odontoclinic.com.br',
 'whatsapp', 'instagram', 'social', 'odonto-sp-set25',
 'Saúde', ARRAY['demo', 'saude', 'odonto'], false, true,
 '2025-09-25 11:15:00'::timestamptz, '2025-09-22 09:00:00'::timestamptz, '2025-09-25 11:15:00'::timestamptz),

(1016, 1, 'Renata Azevedo Pinto', '5585855016016@s.whatsapp.net', '85855016016', 'renata.azevedo@hotelcosta.com.br',
 'whatsapp', 'google', 'organic', NULL,
 'Hotelaria/Turismo', ARRAY['demo', 'hotelaria', 'turismo'], false, true,
 '2025-09-28 14:30:00'::timestamptz, '2025-09-25 11:00:00'::timestamptz, '2025-09-28 14:30:00'::timestamptz),

(1017, 1, 'Thiago Nascimento Reis', '5551844017017@s.whatsapp.net', '51844017017', 'thiago.reis@metalurgicars.com.br',
 'whatsapp', 'linkedin', 'social', 'metalurgia-rs-set25',
 'Indústria', ARRAY['demo', 'industria', 'metalurgia'], false, true,
 '2025-09-30 10:45:00'::timestamptz, '2025-09-27 15:00:00'::timestamptz, '2025-09-30 10:45:00'::timestamptz),

(1018, 1, 'Luciana Freitas Carvalho', '5534833018018@s.whatsapp.net', '34833018018', 'luciana.freitas@agenciamkt.com.br',
 'whatsapp', 'instagram', 'social', 'marketing-mg-set25',
 'Marketing/Publicidade', ARRAY['demo', 'marketing', 'agencia'], false, true,
 '2025-09-30 17:00:00'::timestamptz, '2025-09-28 13:30:00'::timestamptz, '2025-09-30 17:00:00'::timestamptz),

(1019, 1, 'Felipe Augusto Cardoso', '5511822019019@s.whatsapp.net', '11822019019', 'felipe.cardoso@softwarehouse.com.br',
 'whatsapp', 'google', 'cpc', 'software-sp-set25',
 'Tecnologia', ARRAY['demo', 'tech', 'software'], false, true,
 '2025-09-30 18:30:00'::timestamptz, '2025-09-29 09:00:00'::timestamptz, '2025-09-30 18:30:00'::timestamptz),

(1020, 1, 'Gabriela Monteiro Silva', '5521811020020@s.whatsapp.net', '21811020020', 'gabriela.monteiro@petshopamigo.com.br',
 'whatsapp', 'facebook', 'social', 'pet-rj-set25',
 'Pet Shop', ARRAY['demo', 'pet', 'varejo'], false, true,
 '2025-09-30 19:15:00'::timestamptz, '2025-09-29 14:00:00'::timestamptz, '2025-09-30 19:15:00'::timestamptz),

-- ============================================================================
-- OUTUBRO 2025 (15 leads) - Pico de atividade
-- ============================================================================
(1021, 1, 'Eduardo Henrique Lopes', '5511800021021@s.whatsapp.net', '11800021021', 'eduardo.lopes@consultoriaexcel.com.br',
 'whatsapp', 'linkedin', 'social', 'consultoria-sp-out25',
 'Consultoria', ARRAY['demo', 'consultoria', 'b2b'], false, true,
 '2025-10-03 10:00:00'::timestamptz, '2025-10-01 08:30:00'::timestamptz, '2025-10-03 10:00:00'::timestamptz),

(1022, 1, 'Vanessa Ribeiro Costa', '5531789022022@s.whatsapp.net', '31789022022', 'vanessa.ribeiro@restaurantesabor.com.br',
 'whatsapp', 'google', 'organic', NULL,
 'Alimentação/Restaurante', ARRAY['demo', 'restaurante', 'food'], false, true,
 '2025-10-05 12:30:00'::timestamptz, '2025-10-02 11:00:00'::timestamptz, '2025-10-05 12:30:00'::timestamptz),

(1023, 1, 'Diego Fernandes Oliveira', '5547778023023@s.whatsapp.net', '47778023023', 'diego.fernandes@textilsc.com.br',
 'whatsapp', 'google', 'cpc', 'textil-sc-out25',
 'Têxtil', ARRAY['demo', 'textil', 'industria'], false, true,
 '2025-10-08 15:45:00'::timestamptz, '2025-10-05 10:00:00'::timestamptz, '2025-10-08 15:45:00'::timestamptz),

(1024, 1, 'Amanda Cristina Borges', '5511767024024@s.whatsapp.net', '11767024024', 'amanda.borges@joalheriastar.com.br',
 'whatsapp', 'instagram', 'social', 'joalheria-sp-out25',
 'Joalheria', ARRAY['demo', 'joalheria', 'luxo'], false, true,
 '2025-10-10 11:00:00'::timestamptz, '2025-10-07 09:30:00'::timestamptz, '2025-10-10 11:00:00'::timestamptz),

(1025, 1, 'Rodrigo Alves Pinheiro', '5521756025025@s.whatsapp.net', '21756025025', 'rodrigo.alves@segurancatotal.com.br',
 'whatsapp', 'google', 'cpc', 'seguranca-rj-out25',
 'Segurança', ARRAY['demo', 'seguranca', 'servicos'], false, true,
 '2025-10-12 14:20:00'::timestamptz, '2025-10-09 16:00:00'::timestamptz, '2025-10-12 14:20:00'::timestamptz),

(1026, 1, 'Isabela Duarte Machado', '5561745026026@s.whatsapp.net', '61745026026', 'isabela.duarte@advocaciabsb.com.br',
 'whatsapp', 'linkedin', 'social', 'advocacia-df-out25',
 'Jurídico', ARRAY['demo', 'juridico', 'advocacia'], false, true,
 '2025-10-15 09:30:00'::timestamptz, '2025-10-12 11:00:00'::timestamptz, '2025-10-15 09:30:00'::timestamptz),

(1027, 1, 'Bruno César Nogueira', '5571734027027@s.whatsapp.net', '71734027027', 'bruno.nogueira@energiasolar.com.br',
 'whatsapp', 'facebook', 'social', 'energia-ba-out25',
 'Energia', ARRAY['demo', 'energia', 'solar'], false, true,
 '2025-10-18 16:00:00'::timestamptz, '2025-10-15 14:30:00'::timestamptz, '2025-10-18 16:00:00'::timestamptz),

(1028, 1, 'Larissa Fonseca Vieira', '5511723028028@s.whatsapp.net', '11723028028', 'larissa.fonseca@ecommercepro.com.br',
 'whatsapp', 'google', 'cpc', 'ecommerce-sp-out25',
 'E-commerce', ARRAY['demo', 'ecommerce', 'tech'], false, true,
 '2025-10-20 10:45:00'::timestamptz, '2025-10-17 09:00:00'::timestamptz, '2025-10-20 10:45:00'::timestamptz),

(1029, 1, 'Rafael Mendonça Araújo', '5581712029029@s.whatsapp.net', '81712029029', 'rafael.mendonca@academiafit.com.br',
 'whatsapp', 'instagram', 'social', 'fitness-pe-out25',
 'Fitness/Academia', ARRAY['demo', 'fitness', 'saude'], false, true,
 '2025-10-22 13:15:00'::timestamptz, '2025-10-19 10:30:00'::timestamptz, '2025-10-22 13:15:00'::timestamptz),

(1030, 1, 'Natália Campos Rocha', '5527701030030@s.whatsapp.net', '27701030030', 'natalia.campos@graficarapida.com.br',
 'whatsapp', 'google', 'organic', NULL,
 'Gráfica', ARRAY['demo', 'grafica', 'industria'], false, true,
 '2025-10-24 15:30:00'::timestamptz, '2025-10-21 12:00:00'::timestamptz, '2025-10-24 15:30:00'::timestamptz),

(1031, 1, 'Gustavo Henrique Melo', '5511690031031@s.whatsapp.net', '11690031031', 'gustavo.melo@contabilidadeplus.com.br',
 'whatsapp', 'linkedin', 'social', 'contabil-sp-out25',
 'Contabilidade', ARRAY['demo', 'contabil', 'servicos'], false, true,
 '2025-10-26 11:00:00'::timestamptz, '2025-10-23 09:30:00'::timestamptz, '2025-10-26 11:00:00'::timestamptz),

(1032, 1, 'Carolina Batista Santos', '5521679032032@s.whatsapp.net', '21679032032', 'carolina.batista@eventosrj.com.br',
 'whatsapp', 'instagram', 'social', 'eventos-rj-out25',
 'Eventos', ARRAY['demo', 'eventos', 'servicos'], false, true,
 '2025-10-28 14:45:00'::timestamptz, '2025-10-25 11:00:00'::timestamptz, '2025-10-28 14:45:00'::timestamptz),

(1033, 1, 'Leonardo Ramos Cunha', '5551668033033@s.whatsapp.net', '51668033033', 'leonardo.ramos@agropecuariars.com.br',
 'whatsapp', 'facebook', 'social', 'agro-rs-out25',
 'Agronegócio', ARRAY['demo', 'agro', 'pecuaria'], false, true,
 '2025-10-29 09:00:00'::timestamptz, '2025-10-26 15:30:00'::timestamptz, '2025-10-29 09:00:00'::timestamptz),

(1034, 1, 'Priscila Andrade Lima', '5531657034034@s.whatsapp.net', '31657034034', 'priscila.andrade@laboratoriolab.com.br',
 'whatsapp', 'google', 'cpc', 'laboratorio-mg-out25',
 'Saúde', ARRAY['demo', 'laboratorio', 'saude'], false, true,
 '2025-10-30 16:30:00'::timestamptz, '2025-10-27 10:00:00'::timestamptz, '2025-10-30 16:30:00'::timestamptz),

(1035, 1, 'Vinícius Costa Nunes', '5511646035035@s.whatsapp.net', '11646035035', 'vinicius.costa@startuptech.io',
 'whatsapp', 'linkedin', 'social', 'startup-sp-out25',
 'Tecnologia', ARRAY['demo', 'startup', 'tech'], false, true,
 '2025-10-31 18:00:00'::timestamptz, '2025-10-28 14:00:00'::timestamptz, '2025-10-31 18:00:00'::timestamptz),

-- ============================================================================
-- NOVEMBRO 2025 (10 leads) - Mantendo ritmo
-- ============================================================================
(1036, 1, 'Daniela Souza Ferreira', '5521635036036@s.whatsapp.net', '21635036036', 'daniela.souza@modaintima.com.br',
 'whatsapp', 'instagram', 'social', 'moda-rj-nov25',
 'Varejo', ARRAY['demo', 'varejo', 'moda'], false, true,
 '2025-11-04 10:30:00'::timestamptz, '2025-11-01 09:00:00'::timestamptz, '2025-11-04 10:30:00'::timestamptz),

(1037, 1, 'Fábio Ricardo Moura', '5585624037037@s.whatsapp.net', '85624037037', 'fabio.moura@atacadaone.com.br',
 'whatsapp', 'google', 'cpc', 'atacado-ce-nov25',
 'Atacado/Distribuição', ARRAY['demo', 'atacado', 'distribuicao'], false, true,
 '2025-11-07 14:15:00'::timestamptz, '2025-11-04 11:30:00'::timestamptz, '2025-11-07 14:15:00'::timestamptz),

(1038, 1, 'Aline Cristina Pereira', '5541613038038@s.whatsapp.net', '41613038038', 'aline.pereira@escolaidiomas.com.br',
 'whatsapp', 'facebook', 'social', 'educacao-pr-nov25',
 'Educação', ARRAY['demo', 'educacao', 'idiomas'], false, true,
 '2025-11-10 11:00:00'::timestamptz, '2025-11-07 08:30:00'::timestamptz, '2025-11-10 11:00:00'::timestamptz),

(1039, 1, 'Maurício Lopes Teixeira', '5511602039039@s.whatsapp.net', '11602039039', 'mauricio.lopes@transportadora.com.br',
 'whatsapp', 'google', 'organic', NULL,
 'Logística', ARRAY['demo', 'logistica', 'transporte'], false, true,
 '2025-11-13 15:45:00'::timestamptz, '2025-11-10 13:00:00'::timestamptz, '2025-11-13 15:45:00'::timestamptz),

(1040, 1, 'Tatiana Mendes Barros', '5531591040040@s.whatsapp.net', '31591040040', 'tatiana.mendes@supermercadosbh.com.br',
 'whatsapp', 'google', 'cpc', 'supermercado-mg-nov25',
 'Varejo', ARRAY['demo', 'varejo', 'supermercado'], false, true,
 '2025-11-16 09:30:00'::timestamptz, '2025-11-13 10:00:00'::timestamptz, '2025-11-16 09:30:00'::timestamptz),

(1041, 1, 'Henrique Bastos Silva', '5521580041041@s.whatsapp.net', '21580041041', 'henrique.bastos@coworkingspace.com.br',
 'whatsapp', 'linkedin', 'social', 'coworking-rj-nov25',
 'Imobiliário', ARRAY['demo', 'coworking', 'servicos'], false, true,
 '2025-11-19 13:00:00'::timestamptz, '2025-11-16 11:30:00'::timestamptz, '2025-11-19 13:00:00'::timestamptz),

(1042, 1, 'Mariana Tavares Ramos', '5511569042042@s.whatsapp.net', '11569042042', 'mariana.tavares@clinicaveterinaria.com.br',
 'whatsapp', 'instagram', 'social', 'veterinario-sp-nov25',
 'Veterinário', ARRAY['demo', 'veterinario', 'saude'], false, true,
 '2025-11-22 10:15:00'::timestamptz, '2025-11-19 09:00:00'::timestamptz, '2025-11-22 10:15:00'::timestamptz),

(1043, 1, 'Alexandre Prado Neto', '5562558043043@s.whatsapp.net', '62558043043', 'alexandre.prado@frigorificogo.com.br',
 'whatsapp', 'facebook', 'social', 'frigorifico-go-nov25',
 'Alimentos', ARRAY['demo', 'frigorifico', 'industria'], false, true,
 '2025-11-25 16:30:00'::timestamptz, '2025-11-22 14:00:00'::timestamptz, '2025-11-25 16:30:00'::timestamptz),

(1044, 1, 'Bianca Carvalho Dias', '5571547044044@s.whatsapp.net', '71547044044', 'bianca.carvalho@saborbaiano.com.br',
 'whatsapp', 'google', 'organic', NULL,
 'Alimentação/Restaurante', ARRAY['demo', 'restaurante', 'food'], false, true,
 '2025-11-27 12:00:00'::timestamptz, '2025-11-24 10:30:00'::timestamptz, '2025-11-27 12:00:00'::timestamptz),

(1045, 1, 'Fernando Augusto Castro', '5511536045045@s.whatsapp.net', '11536045045', 'fernando.castro@corretoraimob.com.br',
 'whatsapp', 'google', 'cpc', 'corretor-sp-nov25',
 'Imobiliário', ARRAY['demo', 'imobiliario', 'corretor'], false, true,
 '2025-11-29 14:45:00'::timestamptz, '2025-11-26 11:00:00'::timestamptz, '2025-11-29 14:45:00'::timestamptz),

-- ============================================================================
-- DEZEMBRO 2025 (5 leads) - Mês atual
-- ============================================================================
(1046, 1, 'Juliana Fernandes Alves', '5521525046046@s.whatsapp.net', '21525046046', 'juliana.alves@agenciaviagens.com.br',
 'whatsapp', 'instagram', 'social', 'turismo-rj-dez25',
 'Hotelaria/Turismo', ARRAY['demo', 'turismo', 'viagens'], false, true,
 '2025-12-02 10:00:00'::timestamptz, '2025-12-01 09:30:00'::timestamptz, '2025-12-02 10:00:00'::timestamptz),

(1047, 1, 'Pedro Henrique Martins', '5511514047047@s.whatsapp.net', '11514047047', 'pedro.martins@aboratorioanalises.com.br',
 'whatsapp', 'google', 'cpc', 'laboratorio-sp-dez25',
 'Saúde', ARRAY['demo', 'laboratorio', 'saude'], false, true,
 '2025-12-02 15:30:00'::timestamptz, '2025-12-01 14:00:00'::timestamptz, '2025-12-02 15:30:00'::timestamptz),

(1048, 1, 'Renata Oliveira Santos', '5585503048048@s.whatsapp.net', '85503048048', 'renata.santos@olojaonline.com.br',
 'whatsapp', 'facebook', 'social', 'ecommerce-ce-dez25',
 'E-commerce', ARRAY['demo', 'ecommerce', 'varejo'], false, true,
 '2025-12-03 09:15:00'::timestamptz, '2025-12-02 08:00:00'::timestamptz, '2025-12-03 09:15:00'::timestamptz),

(1049, 1, 'Marcos Paulo Ribeiro', '5531492049049@s.whatsapp.net', '31492049049', 'marcos.ribeiro@industriaplasticos.com.br',
 'whatsapp', 'linkedin', 'social', 'plasticos-mg-dez25',
 'Indústria', ARRAY['demo', 'plasticos', 'industria'], false, true,
 '2025-12-03 11:45:00'::timestamptz, '2025-12-02 16:30:00'::timestamptz, '2025-12-03 11:45:00'::timestamptz),

(1050, 1, 'Carla Regina Nunes', '5541481050050@s.whatsapp.net', '41481050050', 'carla.nunes@decoracaohouse.com.br',
 'whatsapp', 'google', 'organic', NULL,
 'Decoração', ARRAY['demo', 'decoracao', 'varejo'], false, true,
 '2025-12-03 14:00:00'::timestamptz, '2025-12-03 10:00:00'::timestamptz, '2025-12-03 14:00:00'::timestamptz),

-- ============================================================================
-- LEADS OPT-OUT (3 leads que pediram para sair)
-- ============================================================================
(1051, 1, 'Antônio José Pereira', '5511470051051@s.whatsapp.net', '11470051051', 'antonio.pereira@empresax.com.br',
 'whatsapp', 'google', 'cpc', 'teste-ago25',
 'Outros', ARRAY['demo', 'optout'], true, false,
 '2025-08-20 10:00:00'::timestamptz, '2025-08-18 09:00:00'::timestamptz, '2025-08-20 10:00:00'::timestamptz),

(1052, 1, 'Sandra Maria Costa', '5521459052052@s.whatsapp.net', '21459052052', 'sandra.costa@empresay.com.br',
 'whatsapp', 'facebook', 'social', 'teste-set25',
 'Outros', ARRAY['demo', 'optout'], true, false,
 '2025-09-15 14:30:00'::timestamptz, '2025-09-12 11:00:00'::timestamptz, '2025-09-15 14:30:00'::timestamptz),

(1053, 1, 'Jorge Luis Almeida', '5531448053053@s.whatsapp.net', '31448053053', 'jorge.almeida@empresaz.com.br',
 'whatsapp', 'google', 'organic', NULL,
 'Outros', ARRAY['demo', 'optout'], true, false,
 '2025-10-22 16:00:00'::timestamptz, '2025-10-20 10:30:00'::timestamptz, '2025-10-22 16:00:00'::timestamptz);

-- Atualizar sequence
SELECT setval('corev4_contacts_id_seq', GREATEST((SELECT MAX(id) FROM corev4_contacts), 1053), true);

-- Verificar inserção
SELECT COUNT(*) AS total_leads_demo FROM corev4_contacts WHERE tags @> ARRAY['demo']::text[];
