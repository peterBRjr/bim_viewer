import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Guia Técnico Interativo de Exportação IFC (Básico • Médio • Detalhado para iOS)
/// com parâmetros pesquisados para Autodesk Revit, Tekla Structures, Archicad e Eberick/CYPE,
/// além de diagramas vetoriais de tesselação de malha e fluxo de transferência para o iPhone.
class IfcExportGuideScreen extends StatefulWidget {
  final int initialLevelIndex;

  const IfcExportGuideScreen({
    super.key,
    this.initialLevelIndex = 1, // Inicia no Médio por padrão ou permite alternar
  });

  @override
  State<IfcExportGuideScreen> createState() => _IfcExportGuideScreenState();
}

class _IfcExportGuideScreenState extends State<IfcExportGuideScreen> {
  late int _selectedLevel;
  late final PageController _pageController;

  static const List<_ExportTierSpec> _tiers = [
    _ExportTierSpec(
      index: 0,
      idKey: 'tier_basico',
      shortTitle: 'Básico',
      badgeText: 'NÍVEL 1 • ULTRA LEVE & RÁPIDO',
      headline: 'Exportação Básica (Máxima Leveza de Hardware)',
      subtitle:
          'Focado em obras de grande porte, galpões extensos ou carregamento instantâneo com baixíssimo uso de RAM.',
      accentColor: Color(0xFF10B981), // Emerald
      targetFileSize: '5 MB a 25 MB',
      targetPolygons: '40.000 a 120.000 triângulos',
      targetRamUsage: '< 320 MB RAM no iOS',
      visualDifferenceSummary:
          'Geometria prismática limpa: vigas I, pilares, lajes e paredes mantêm medidas exatas para cota 3D, porém curvas secundárias são facetadas e miudezas (parafusos/estribos) são omitidas.',
      indispensableParams: [
        _ParamItem(
          parameter: 'Schema / MVD (Definição de Vista)',
          value: 'IFC4 Reference View',
          reason:
              'Usa IfcTriangulatedFaceSet nativo em vez de B-Reps pesados, reduzindo o arquivo em até 60%.',
        ),
        _ParamItem(
          parameter: 'Level of Detail (Tesselação no Revit)',
          value: 'Baixo (Low) ou Extra Baixo (Extra Low)',
          reason:
              'Simplifica curvas de conexões e tubos em poucos polígonos sem afetar cotas entre faces.',
        ),
        _ParamItem(
          parameter: 'Elementos Visíveis (Filtro de Vista 3D)',
          value: 'Somente Elementos Visíveis na Vista (Active View)',
          reason:
              'Isole apenas estrutura/arquitetura principal antes de exportar, ocultando mobiliário e parafusos.',
        ),
        _ParamItem(
          parameter: 'Property Sets & Quantitativos',
          value: 'Apenas IFC Common Psets + Base Quantities',
          reason:
              'Desmarque "Revit Property Sets" para não exportar milhares de linhas de texto desnecessárias.',
        ),
      ],
      softwareGuides: [
        _SoftwareConfigGuide(
          softwareName: 'Autodesk Revit (2022–2026)',
          icon: Icons.layers_rounded,
          steps: [
            'Vá em File > Export > IFC > Modify Setup.',
            'Na aba General: escolha "IFC4 Reference View".',
            'Na aba Additional Content: marque "Export only elements visible in view".',
            'Na aba Property Sets: marque apenas "Export IFC common property sets" e "Export base quantities".',
            'Na aba Level of Detail: selecione "Low" (Baixo) ou "Extra Low".',
          ],
        ),
        _SoftwareConfigGuide(
          softwareName: 'Tekla Structures (Aço & Pré-Moldados)',
          icon: Icons.precision_manufacturing_rounded,
          steps: [
            'Em File > Export > IFC: selecione "Surface Geometry" ou "Coordination View 2.0".',
            'Na aba Advanced: DESMARQUE obrigatoriamente "Bolts" (Parafusos), "Welds" (Soldas) e "Reinforcing bars" (Armaduras).',
            'Mantenha XS_EXPORT_BREP_AS_EXACT_SOLID = FALSE para evitar malhas pesadas em perfis laminados.',
          ],
        ),
        _SoftwareConfigGuide(
          softwareName: 'Archicad / Eberick / CYPECAD',
          icon: Icons.domain_rounded,
          steps: [
            'No Archicad: use Exibição Parcial da Estrutura em "Apenas Núcleo Estrutural" e oculte a camada de Mobiliário.',
            'No Eberick / TQS: exporte a estrutura de concreto (Vigas, Pilares, Lajes e Fundações) com "Exportar Armaduras 3D = Desativado".',
          ],
        ),
      ],
    ),
    _ExportTierSpec(
      index: 1,
      idKey: 'tier_medio',
      shortTitle: 'Médio',
      badgeText: 'NÍVEL 2 • EQUILÍBRIO VISUAL RECOMENDADO',
      headline: 'Exportação Média (Diferença Nítida a Olho Nu)',
      subtitle:
          'Eleva a definição geométrica de perfis metálicos, chapas de ligação, esquadrias e curvas com fluidez total a 60 FPS.',
      accentColor: Color(0xFF2563EB), // Royal Blue
      targetFileSize: '20 MB a 65 MB',
      targetPolygons: '150.000 a 450.000 triângulos',
      targetRamUsage: '~520 MB RAM no iOS',
      visualDifferenceSummary:
          'Diferença imediata a olho nu em relação ao Básico: abas e almas de perfis metálicos (W/HP), chapas de ligação (gussets), batentes de esquadrias, guarda-corpos e trechos curvos ganham contornos fiéis sem sobrecarregar o processador.',
      indispensableParams: [
        _ParamItem(
          parameter: 'Schema / MVD (Definição de Vista)',
          value: 'IFC2x3 Coordination View 2.0 ou IFC4 Reference View',
          reason:
              'Preserva extrusões paramétricas (IfcExtrudedAreaSolid) com arestas vivas e precisas.',
        ),
        _ParamItem(
          parameter: 'Level of Detail (Tesselação no Revit)',
          value: 'Médio (Medium)',
          reason:
              'Eleva a subdivisão de arcos, perfis dobrados e conexões a um nível nítido a olho nu sem gerar milhões de vértices.',
        ),
        _ParamItem(
          parameter: 'Chapas, Ligações e Esquadrias',
          value: 'Ativar Plates / Gussets / Esquadrias; Ocultar Roscas',
          reason:
              'Mostra todas as chapas de ligação da estrutura metálica e caixilhos, omitindo apenas porcas/arruelas.',
        ),
        _ParamItem(
          parameter: 'Materiais e Camadas Construtivas',
          value: 'Ativar Material Property Sets + Parts',
          reason:
              'Permite que o visualizador renderize cores PBR distintas para aço, concreto, vidro e alvenaria.',
        ),
      ],
      softwareGuides: [
        _SoftwareConfigGuide(
          softwareName: 'Autodesk Revit (2022–2026)',
          icon: Icons.layers_rounded,
          steps: [
            'Em Modify Setup > General: selecione "IFC2x3 Coordination View 2.0" ou "IFC4 Reference View".',
            'Na aba Level of Detail: altere de Low para "Medium" (Médio) — melhora visivelmente curvas, escadas e conexões.',
            'Na aba Property Sets: ative "Export IFC common property sets", "Export base quantities" e "Export material property sets".',
            'Configure o Nível de Detalhe da Vista 3D do Revit como "Médio" (Medium) antes de exportar.',
          ],
        ),
        _SoftwareConfigGuide(
          softwareName: 'Tekla Structures (Aço & Pré-Moldados)',
          icon: Icons.precision_manufacturing_rounded,
          steps: [
            'Exporte com "Coordination View 2.0".',
            'Na aba Advanced: MARQUE "Plates" (Chapas de ligação) e "Secondary parts" (Terças/Contraventamentos).',
            'Mantenha "Bolts" (Parafusos) e "Reinforcing bars" desmarcados para manter o arquivo ágil e nítido.',
          ],
        ),
        _SoftwareConfigGuide(
          softwareName: 'Archicad / Eberick / CYPECAD',
          icon: Icons.domain_rounded,
          steps: [
            'No Archicad: exporte "Estrutura Completa" com esquadrias e revestimentos, filtrando apenas vegetação 3D e veículos.',
            'No Eberick / CYPECAD: exporte fôrmas + estruturas metálicas de cobertura + fundações com propriedades completas.',
          ],
        ),
      ],
    ),
    _ExportTierSpec(
      index: 2,
      idKey: 'tier_detalhado',
      shortTitle: 'Detalhado (iOS)',
      badgeText: 'NÍVEL 3 • ALTA DEFINIÇÃO CALIBRADA PARA IPHONE',
      headline: 'Exportação Detalhada (Teto Gráfico iOS / Apple Metal)',
      subtitle:
          'Calibrado para extrair o máximo da GPU Apple (iPhone / iPad Super Retina) em apresentações executivas e auditoria de montagem, respeitando o teto seguro do iOS.',
      accentColor: Color(0xFF0284C7), // Sky Blue / Deep Cyan
      targetFileSize: '50 MB a 120 MB (Teto Seguro iOS)',
      targetPolygons: '500.000 a 1.100.000 triângulos',
      targetRamUsage: '~850 MB a 1,1 GB RAM no iOS',
      visualDifferenceSummary:
          'Fidelidade executiva máxima: raios de concordância em perfis laminados, nervuras, chumbadores, louças sanitárias detalhadas, caixilharia completa e conjuntos de fixação, mantendo-se abaixo do limite de 120 MB para nunca exceder a memória do WebKit no iPhone.',
      indispensableParams: [
        _ParamItem(
          parameter: 'Teto de Segurança para iOS (WKWebView Metal)',
          value: 'Máximo recomendado: 120 MB por arquivo IFC',
          reason:
              'O iOS impõe limite rígido de RAM por aba WebGL (~1.4 GB). Manter o IFC até 120 MB garante 60 FPS constantes sem fechamento abrupto.',
        ),
        _ParamItem(
          parameter: 'Level of Detail (Tesselação no Revit)',
          value: 'Médio-Alto (Vista 3D em Fine + Tessellation Medium/High)',
          reason:
              'Use Vista 3D em nível "Alto (Fine)" no Revit combinada com Tessellation "Medium" (ou "High" apenas para blocos/setores isolados).',
        ),
        _ParamItem(
          parameter: 'Divisão por Disciplina ou Bloco (Projetos Gigantes)',
          value: 'Separar por Setor / Disciplina se passar de 120 MB',
          reason:
              'Em obras industriais gigantes, exporte Estrutura Metálica e MEP/Civil ou armaduras pesadas em arquivos separados.',
        ),
        _ParamItem(
          parameter: 'Psets Executivos Completos (openBIM)',
          value: 'Common Psets + Base Quantities + Schedules + Materials',
          reason:
              'Habilita 100% dos filtros por pavimento, quantitativos de área/volume e cota inteligente de 6m na Visão Dinâmica.',
        ),
      ],
      softwareGuides: [
        _SoftwareConfigGuide(
          softwareName: 'Autodesk Revit (2022–2026)',
          icon: Icons.layers_rounded,
          steps: [
            'Defina a Vista 3D de exportação no nível "Fine" (Alto) para exibir raios de alma/aba de perfis de aço e detalhes de esquadrias.',
            'Em Modify Setup > Level of Detail: use "Medium" para o prédio completo ou "High" para setores/pavimentos específicos.',
            'Na aba Advanced: marque "Use active view when creating geometry" e "Store the IFC GUID in an element parameter".',
            'Verifique o tamanho final do .ifc gerado: se ficar até ~120 MB, o iPhone renderizará com sombras suaves 2048px e MSAA.',
          ],
        ),
        _SoftwareConfigGuide(
          softwareName: 'Tekla Structures (Aço & Pré-Moldados)',
          icon: Icons.precision_manufacturing_rounded,
          steps: [
            'Ative perfis principais, secundários, chapas de ligação (Plates), chumbadores (Anchor rods) e grades.',
            'Se desejar exibir conjuntos de parafusos na inspeção de ligação, exporte por Etapa/Fase (Selection Filter) mantendo o arquivo < 110 MB.',
          ],
        ),
        _SoftwareConfigGuide(
          softwareName: 'Otimização Final Opcional (Simplebim / Solibri / GLB)',
          icon: Icons.auto_fix_high_rounded,
          steps: [
            'Dica Pro: passar o arquivo IFC pelo Simplebim remove pontos duplicados reduzindo 40% do peso sem perder 1 único detalhe visual.',
            'O app também aceita modelos convertidos em .GLB / .GLTF binário, que carregam até 5x mais rápido no iPhone.',
          ],
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedLevel = widget.initialLevelIndex.clamp(0, 2);
    _pageController = PageController(initialPage: _selectedLevel);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectLevel(int index) {
    if (_selectedLevel == index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedLevel = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeSpec = _tiers[_selectedLevel];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Guia de Exportação IFC (iOS)',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Cabeçalho Fixo com Toggle Button de 3 Níveis (Básico • Médio • Detalhado)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                border: Border(
                  bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.swipe_rounded,
                        size: 14,
                        color: Color(0xFF38BDF8),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Selecione o nível ou deslize horizontalmente para comparar os parâmetros:',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      children: _tiers.map((tier) {
                        final isSelected = tier.index == _selectedLevel;
                        return Expanded(
                          child: GestureDetector(
                            key: ValueKey('export_toggle_${tier.idKey}'),
                            onTap: () => _selectLevel(tier.index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? tier.accentColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: tier.accentColor.withValues(
                                            alpha: 0.35,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    tier.index == 0
                                        ? Icons.bolt_rounded
                                        : (tier.index == 1
                                            ? Icons.tune_rounded
                                            : Icons.hd_rounded),
                                    size: 15,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      tier.shortTitle,
                                      style: TextStyle(
                                        fontFamily: AppTypography.fontFamily,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFFCBD5E1),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Slide Horizontal (PageView) com Conteúdo Completo de Cada Nível
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _tiers.length,
                onPageChanged: (index) {
                  if (_selectedLevel != index) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedLevel = index);
                  }
                },
                itemBuilder: (context, index) {
                  return _buildTierPageContent(_tiers[index]);
                },
              ),
            ),

            // 3. Indicador Inferior de Paginação
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _selectedLevel > 0
                        ? () => _selectLevel(_selectedLevel - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    label: const Text('Nível Anterior'),
                  ),
                  Row(
                    children: List.generate(_tiers.length, (i) {
                      final active = i == _selectedLevel;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? activeSpec.accentColor
                              : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  TextButton.icon(
                    onPressed: _selectedLevel < _tiers.length - 1
                        ? () => _selectLevel(_selectedLevel + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    label: const Text('Próximo Nível'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierPageContent(_ExportTierSpec tier) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        // Card 1: Resumo Técnico + Ilustração Vetorial da Malha 3D
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tier.accentColor.withValues(alpha: 0.40),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: tier.accentColor.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tier.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tier.badgeText,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: tier.accentColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                tier.headline,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tier.subtitle,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Ilustração Gráfica Desenhada em Canvas: Comparativo de Tesselação e Perfil Metálico
              Container(
                height: 155,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CustomPaint(
                    painter: _IfcMeshLodDiagramPainter(
                      levelIndex: tier.index,
                      accentColor: tier.accentColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Métricas de Hardware (Tamanho, Polígonos e RAM no iPhone)
              Row(
                children: [
                  _buildMetricTile(
                    label: 'Tamanho IFC Ideal',
                    value: tier.targetFileSize,
                    icon: Icons.sd_storage_outlined,
                    color: tier.accentColor,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricTile(
                    label: 'Densidade 3D',
                    value: tier.targetPolygons,
                    icon: Icons.auto_awesome_motion_rounded,
                    color: tier.accentColor,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricTile(
                    label: 'Teto RAM iOS',
                    value: tier.targetRamUsage,
                    icon: Icons.memory_rounded,
                    color: tier.accentColor,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Diferença Visual a Olho Nu
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.visibility_rounded,
                      size: 18,
                      color: tier.accentColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'O que muda a olho nu no Visualizador 3D:',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tier.visualDifferenceSummary,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12,
                              color: AppColors.textMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Card 2: Parâmetros Indispensáveis de Exportação
        _buildSectionHeader(
          icon: Icons.tune_rounded,
          title: 'PARÂMETROS INDISPENSÁVEIS DE EXPORTAÇÃO',
          color: tier.accentColor,
        ),
        const SizedBox(height: 10),
        ...tier.indispensableParams.map(
          (param) => _buildIndispensableParamCard(param, tier.accentColor),
        ),
        const SizedBox(height: 18),

        // Card 3: Passo a Passo nos Softwares BIM (Revit, Tekla, Archicad, Eberick)
        _buildSectionHeader(
          icon: Icons.desktop_windows_rounded,
          title: 'COMO CONFIGURAR NO SEU SOFTWARE BIM',
          color: tier.accentColor,
        ),
        const SizedBox(height: 10),
        ...tier.softwareGuides.map(
          (guide) => _buildSoftwareGuideCard(guide, tier.accentColor),
        ),
        const SizedBox(height: 18),

        // Card 4: Como Enviar o Arquivo Exportado para o iPhone / iPad
        _buildTransferToPhoneCard(),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIndispensableParamCard(_ParamItem item, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.parameter,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accentColor.withValues(alpha: 0.25)),
            ),
            child: Text(
              item.value,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.reason,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 12,
              color: AppColors.textDark,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoftwareGuideCard(
    _SoftwareConfigGuide guide,
    Color accentColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(guide.icon, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  guide.softwareName,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          ...List.generate(guide.steps.length, (idx) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${idx + 1}',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      guide.steps[idx],
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12.5,
                        color: AppColors.textDark,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTransferToPhoneCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.phone_iphone_rounded,
                size: 18,
                color: Color(0xFF38BDF8),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'COMO TRAZER SEU ARQUIVO IFC PARA O IPHONE / IPAD',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF38BDF8),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildTransferStepRow(
            number: '1',
            title: 'Exporte no PC (.IFC ou .GLB)',
            desc:
                'Gere o arquivo no Revit, Tekla, Archicad ou Eberick seguindo o perfil Básico, Médio ou Detalhado.',
          ),
          const SizedBox(height: 8),
          _buildTransferStepRow(
            number: '2',
            title: 'Envie por E-mail, iCloud Drive, AirDrop ou WhatsApp',
            desc:
                'No iPhone, abra o anexo recebido e escolha "Salvar em Arquivos" (app nativo Files do iOS).',
          ),
          const SizedBox(height: 8),
          _buildTransferStepRow(
            number: '3',
            title: 'Toque em "Adicionar Projeto" na Tela Inicial',
            desc:
                'Selecione o arquivo salvo. O app fará uma cópia segura offline para inspeção 3D no canteiro de obras!',
          ),
        ],
      ),
    );
  }

  Widget _buildTransferStepRow({
    required String number,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 11.5,
                  color: Color(0xFFCBD5E1),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExportTierSpec {
  final int index;
  final String idKey;
  final String shortTitle;
  final String badgeText;
  final String headline;
  final String subtitle;
  final Color accentColor;
  final String targetFileSize;
  final String targetPolygons;
  final String targetRamUsage;
  final String visualDifferenceSummary;
  final List<_ParamItem> indispensableParams;
  final List<_SoftwareConfigGuide> softwareGuides;

  const _ExportTierSpec({
    required this.index,
    required this.idKey,
    required this.shortTitle,
    required this.badgeText,
    required this.headline,
    required this.subtitle,
    required this.accentColor,
    required this.targetFileSize,
    required this.targetPolygons,
    required this.targetRamUsage,
    required this.visualDifferenceSummary,
    required this.indispensableParams,
    required this.softwareGuides,
  });
}

class _ParamItem {
  final String parameter;
  final String value;
  final String reason;

  const _ParamItem({
    required this.parameter,
    required this.value,
    required this.reason,
  });
}

class _SoftwareConfigGuide {
  final String softwareName;
  final IconData icon;
  final List<String> steps;

  const _SoftwareConfigGuide({
    required this.softwareName,
    required this.icon,
    required this.steps,
  });
}

/// Desenha o diagrama técnico comparativo da geometria IFC (Perfil I de Aço + Ligação)
/// ilustrando visualmente o Nível Básico (Low LOD), Médio (Medium LOD) e Detalhado (iOS High LOD).
class _IfcMeshLodDiagramPainter extends CustomPainter {
  final int levelIndex;
  final Color accentColor;

  const _IfcMeshLodDiagramPainter({
    required this.levelIndex,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Grid de fundo técnico
    final gridPaint = Paint()
      ..color = const Color(0xFF334155).withValues(alpha: 0.35)
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final strokePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final wirePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    // Desenho do Perfil I Metálico (W-Beam) no lado esquerdo/central
    final cx = size.width * 0.30;
    final cy = size.height * 0.54;
    const w = 84.0;
    const h = 92.0;
    const flangeH = 14.0;
    const webW = 16.0;

    if (levelIndex == 0) {
      // NÍVEL 1 (BÁSICO): Geometria simplificada de baixa tesselação (sem raios de concordância nem chapas secundárias)
      final iBeamPath = Path()
        ..moveTo(cx - w / 2, cy - h / 2)
        ..lineTo(cx + w / 2, cy - h / 2)
        ..lineTo(cx + w / 2, cy - h / 2 + flangeH)
        ..lineTo(cx + webW / 2, cy - h / 2 + flangeH)
        ..lineTo(cx + webW / 2, cy + h / 2 - flangeH)
        ..lineTo(cx + w / 2, cy + h / 2 - flangeH)
        ..lineTo(cx + w / 2, cy + h / 2)
        ..lineTo(cx - w / 2, cy + h / 2)
        ..lineTo(cx - w / 2, cy + h / 2 - flangeH)
        ..lineTo(cx - webW / 2, cy + h / 2 - flangeH)
        ..lineTo(cx - webW / 2, cy - h / 2 + flangeH)
        ..lineTo(cx - w / 2, cy - h / 2 + flangeH)
        ..close();

      canvas.drawPath(iBeamPath, fillPaint);
      canvas.drawPath(iBeamPath, strokePaint);

      // Triangulação enxuta (poucas diagonais)
      canvas.drawLine(
        Offset(cx - w / 2, cy - h / 2),
        Offset(cx + w / 2, cy - h / 2 + flangeH),
        wirePaint,
      );
      canvas.drawLine(
        Offset(cx - webW / 2, cy - h / 2 + flangeH),
        Offset(cx + webW / 2, cy + h / 2 - flangeH),
        wirePaint,
      );
    } else if (levelIndex == 1) {
      // NÍVEL 2 (MÉDIO): Perfil I com chanfros/curvas visíveis + Chapa de Ligação (Gusset Plate) e Enrijecedores
      final plateRect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: w + 24,
        height: h + 18,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(plateRect, const Radius.circular(6)),
        Paint()
          ..color = const Color(0xFF64748B).withValues(alpha: 0.25)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(plateRect, const Radius.circular(6)),
        Paint()
          ..color = const Color(0xFF94A3B8)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );

      final iBeamPath = Path()
        ..moveTo(cx - w / 2, cy - h / 2)
        ..lineTo(cx + w / 2, cy - h / 2)
        ..lineTo(cx + w / 2, cy - h / 2 + flangeH)
        ..quadraticBezierTo(
          cx + webW / 2,
          cy - h / 2 + flangeH,
          cx + webW / 2,
          cy - h / 2 + flangeH + 10,
        )
        ..lineTo(cx + webW / 2, cy + h / 2 - flangeH - 10)
        ..quadraticBezierTo(
          cx + webW / 2,
          cy + h / 2 - flangeH,
          cx + w / 2,
          cy + h / 2 - flangeH,
        )
        ..lineTo(cx + w / 2, cy + h / 2)
        ..lineTo(cx - w / 2, cy + h / 2)
        ..lineTo(cx - w / 2, cy + h / 2 - flangeH)
        ..quadraticBezierTo(
          cx - webW / 2,
          cy + h / 2 - flangeH,
          cx - webW / 2,
          cy + h / 2 - flangeH - 10,
        )
        ..lineTo(cx - webW / 2, cy - h / 2 + flangeH + 10)
        ..quadraticBezierTo(
          cx - webW / 2,
          cy - h / 2 + flangeH,
          cx - w / 2,
          cy - h / 2 + flangeH,
        )
        ..close();

      canvas.drawPath(iBeamPath, fillPaint);
      canvas.drawPath(iBeamPath, strokePaint);
    } else {
      // NÍVEL 3 (DETALHADO iOS): Perfil I de Alta Precisão + Chapa Base + Furações/Chumbadores + Cota 3D
      final plateRect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: w + 30,
        height: h + 22,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(plateRect, const Radius.circular(8)),
        Paint()
          ..color = const Color(0xFF38BDF8).withValues(alpha: 0.14)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(plateRect, const Radius.circular(8)),
        Paint()
          ..color = const Color(0xFF38BDF8)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );

      // Chumbadores / Furos técnicos nos 4 cantos da chapa
      final boltPaint = Paint()
        ..color = const Color(0xFF38BDF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      for (final dx in [-w / 2 - 4, w / 2 + 4]) {
        for (final dy in [-h / 2 - 2, h / 2 + 2]) {
          canvas.drawCircle(Offset(cx + dx, cy + dy), 4.5, boltPaint);
        }
      }

      final iBeamPath = Path()
        ..moveTo(cx - w / 2, cy - h / 2)
        ..lineTo(cx + w / 2, cy - h / 2)
        ..lineTo(cx + w / 2, cy - h / 2 + flangeH)
        ..quadraticBezierTo(
          cx + webW / 2,
          cy - h / 2 + flangeH,
          cx + webW / 2,
          cy - h / 2 + flangeH + 12,
        )
        ..lineTo(cx + webW / 2, cy + h / 2 - flangeH - 12)
        ..quadraticBezierTo(
          cx + webW / 2,
          cy + h / 2 - flangeH,
          cx + w / 2,
          cy + h / 2 - flangeH,
        )
        ..lineTo(cx + w / 2, cy + h / 2)
        ..lineTo(cx - w / 2, cy + h / 2)
        ..lineTo(cx - w / 2, cy + h / 2 - flangeH)
        ..quadraticBezierTo(
          cx - webW / 2,
          cy + h / 2 - flangeH,
          cx - webW / 2,
          cy + h / 2 - flangeH - 12,
        )
        ..lineTo(cx - webW / 2, cy - h / 2 + flangeH + 12)
        ..quadraticBezierTo(
          cx - webW / 2,
          cy - h / 2 + flangeH,
          cx - w / 2,
          cy - h / 2 + flangeH,
        )
        ..close();

      canvas.drawPath(iBeamPath, fillPaint);
      canvas.drawPath(iBeamPath, strokePaint);
    }

    // Painel informativo direito dentro do Canvas
    final infoX = size.width * 0.56;
    final titleTp = TextPainter(
      text: TextSpan(
        text: levelIndex == 0
            ? 'MALHA LOW-POLY\n• Extrusão Simples\n• Sem Parafusos/Soldas\n• Zero Sobrecarga GPU'
            : (levelIndex == 1
                ? 'MALHA EQUILIBRADA\n• Raios e Abas Nítidos\n• Chapas de Ligação\n• Cores PBR por Material'
                : 'MALHA ULTRA iOS METAL\n• Geometria Executiva\n• Ligações & Chumbadores\n• Teto Seguro <= 120 MB'),
        style: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.45,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.40);

    titleTp.paint(canvas, Offset(infoX, size.height * 0.24));
  }

  @override
  bool shouldRepaint(covariant _IfcMeshLodDiagramPainter oldDelegate) {
    return oldDelegate.levelIndex != levelIndex ||
        oldDelegate.accentColor != accentColor;
  }
}
