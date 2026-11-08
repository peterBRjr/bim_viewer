import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../home/domain/models/project_model.dart';
import '../../domain/utils/bim_nomenclature_mapper.dart';
import '../controllers/viewer_3d_controller.dart';

/// Filtros rápidos de seção do painel direito na Visualização Dinâmica.
enum DynamicPanelFilter {
  all('Visão Completa', Icons.dashboard_customize_rounded),
  levels('Níveis & Peças', Icons.layers_rounded),
  elementSpecs('Propriedades IFC', Icons.tune_rounded),
  bimProject('Arquivo BIM', Icons.account_tree_rounded);

  final String label;
  final IconData icon;
  const DynamicPanelFilter(this.label, this.icon);
}

/// Workspace horizontal da Visualização Dinâmica:
/// - Esquerda (próximo à câmera / topo do celular): HUD leve sobre a Viewport 3D enquadrando o elemento na obra.
/// - Centro: Divisória interativa arrastável para personalizar o tamanho das janelas em tempo real.
/// - Direita: Painel dinâmico com filtro de quantidade por Nível (IfcBuildingStorey), especificações padronizadas
///   do elemento (openBIM) e especificações BIM importadas do arquivo.
class DynamicBimWorkspace extends StatefulWidget {
  final Viewer3DController controller;
  final ProjectModel project;
  final double totalWidth;
  final double leftViewportWidth;
  final VoidCallback onExit;

  const DynamicBimWorkspace({
    super.key,
    required this.controller,
    required this.project,
    required this.totalWidth,
    required this.leftViewportWidth,
    required this.onExit,
  });

  @override
  State<DynamicBimWorkspace> createState() => _DynamicBimWorkspaceState();
}

class _DynamicBimWorkspaceState extends State<DynamicBimWorkspace> {
  DynamicPanelFilter _activeFilter = DynamicPanelFilter.all;
  String _searchQuery = '';
  bool _isDraggingDivider = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleDividerDragUpdate(DragUpdateDetails details) {
    if (widget.totalWidth <= 0) return;
    final nextWidth = widget.leftViewportWidth + details.delta.dx;
    final nextRatio = (nextWidth / widget.totalWidth).clamp(0.28, 0.72);

    // Feedback tátil sutil ao cruzar o ponto equilibrado central (46%)
    final prevDiff = (widget.controller.dynamicSplitRatio - 0.46).abs();
    final nextDiff = (nextRatio - 0.46).abs();
    if (prevDiff >= 0.01 && nextDiff < 0.01) {
      HapticFeedback.selectionClick();
    }

    widget.controller.setDynamicSplitRatio(nextRatio);
  }

  @override
  Widget build(BuildContext context) {
    final element = widget.controller.selectedElement;
    if (element == null) return const SizedBox.shrink();

    final leftW = widget.leftViewportWidth;
    final rightW = (widget.totalWidth - leftW).clamp(200.0, widget.totalWidth);
    final leftPct = (widget.controller.dynamicSplitRatio * 100).round();
    final rightPct = 100 - leftPct;

    return Stack(
      children: [
        // 1. HUD Flutuante Minimalista sobre a Viewport 3D à Esquerda (Perto da Câmera do Celular)
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          width: leftW,
          child: IgnorePointer(
            ignoring: false,
            child: _buildLeft3dViewportHud(context, element),
          ),
        ),

        // 2. Painel Direito de Especificações do Elemento, Filtro por Nível e Dados BIM do Projeto
        Positioned(
          top: 0,
          bottom: 0,
          left: leftW,
          width: rightW,
          child: _buildRightSpecificationsPane(context, element),
        ),

        // 3. Divisória Interativa Personalizável (Arrastar ou Duplo-Toque para Resetar)
        Positioned(
          top: 0,
          bottom: 0,
          left: leftW - 12,
          width: 24,
          child: _buildResizableDividerHandle(leftPct, rightPct),
        ),

        // 4. Indicador Flutuante de Proporção das Janelas durante o Arraste da Divisória
        if (_isDraggingDivider)
          Positioned(
            top: 16,
            left: (leftW - 74).clamp(12.0, widget.totalWidth - 160.0),
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accent, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  '3D $leftPct%  •  Dados $rightPct%',
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.surface,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ===========================================================================
  // LADO ESQUERDO (TOPO DO APARELHO / CÂMERA): HUD DE VISUALIZAÇÃO NA OBRA
  // ===========================================================================

  Widget _buildLeft3dViewportHud(BuildContext context, BimElementMetadata element) {
    final isIsolated = widget.controller.isElementIsolated(element.expressID);
    final isSwitching = widget.controller.isSwitchingDynamicElement;

    return SafeArea(
      right: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Topo Esquerdo: Botão Voltar + Badge "Visualização na Obra"
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGlassActionButton(
                  icon: Icons.arrow_back_rounded,
                  label: 'Voltar',
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    widget.onExit();
                  },
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSwitching
                            ? AppColors.accent.withValues(alpha: 0.65)
                            : Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSwitching)
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: Color(0xFF60A5FA),
                            ),
                          )
                        else
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            isSwitching
                                ? 'Renderizando peça...'
                                : 'Vista na Obra • #${element.expressID}',
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.surface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Rodapé Esquerdo: Controles Rápidos de Contexto 3D na Obra
            Align(
              alignment: Alignment.bottomCenter,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 140),
                  opacity: isSwitching ? 0.55 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHudMiniToggle(
                          icon: Icons.center_focus_strong_rounded,
                          label: 'Focar Peça',
                          isActive: false,
                          onTap: isSwitching
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  widget.controller.focusCurrentElementInDynamicView();
                                },
                        ),
                        const SizedBox(width: 4),
                        _buildHudMiniToggle(
                          icon: Icons.blur_on_rounded,
                          label: 'Raio-X Obra',
                          isActive: widget.controller.isDynamicXrayActive,
                          onTap: isSwitching
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  widget.controller.toggleDynamicXrayContext();
                                },
                        ),
                        const SizedBox(width: 4),
                        _buildHudMiniToggle(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Similares 3D',
                          isActive: widget.controller.highlightSimilarIn3D,
                          activeColor: AppColors.success,
                          onTap: isSwitching
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  widget.controller.toggleHighlightSimilarIn3D();
                                },
                        ),
                        const SizedBox(width: 4),
                        _buildHudMiniToggle(
                          icon: isIsolated
                              ? Icons.all_inclusive_rounded
                              : Icons.filter_center_focus_rounded,
                          label: isIsolated ? 'Ver Obra' : 'Isolar',
                          isActive: isIsolated,
                          onTap: isSwitching
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  widget.controller.isolateSelectedElement();
                                },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.surface),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.surface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHudMiniToggle({
    required IconData icon,
    required String label,
    required bool isActive,
    Color activeColor = AppColors.accent,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? AppColors.surface : const Color(0xFFCBD5E1),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppColors.surface : const Color(0xFFE2E8F0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // DIVISÓRIA CENTRAL ARRASTÁVEL (AJUSTE DE TAMANHO DAS JANELAS)
  // ===========================================================================

  Widget _buildResizableDividerHandle(int leftPct, int rightPct) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) {
          HapticFeedback.lightImpact();
          setState(() => _isDraggingDivider = true);
        },
        onHorizontalDragUpdate: _handleDividerDragUpdate,
        onHorizontalDragEnd: (_) {
          setState(() => _isDraggingDivider = false);
        },
        onHorizontalDragCancel: () {
          setState(() => _isDraggingDivider = false);
        },
        onDoubleTap: () {
          HapticFeedback.mediumImpact();
          widget.controller.resetDynamicSplitRatio();
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Linha vertical divisória contínua
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _isDraggingDivider ? 3.0 : 1.5,
              color: _isDraggingDivider ? AppColors.accent : AppColors.border,
            ),
            // Puxador ergonômico central (Grip Pill)
            Tooltip(
              message: 'Arraste para ajustar as janelas ($leftPct% / $rightPct%) • Toque duplo para padrão',
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: _isDraggingDivider ? 18 : 14,
                height: _isDraggingDivider ? 68 : 54,
                decoration: BoxDecoration(
                  color: _isDraggingDivider ? AppColors.accent : AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isDraggingDivider
                        ? AppColors.surface
                        : Colors.white.withValues(alpha: 0.30),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    size: 13,
                    color: AppColors.surface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // LADO DIREITO: PAINEL DE ESPECIFICAÇÕES IFC, FILTRO DE NÍVEL E PROJETO BIM
  // ===========================================================================

  Widget _buildRightSpecificationsPane(BuildContext context, BimElementMetadata element) {
    final standardizedSections = BimNomenclatureMapper.normalizeAllSections(
      element.psets,
      searchQuery: _searchQuery,
    );

    return Material(
      color: AppColors.background,
      child: SafeArea(
        left: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Cabeçalho Compacto do Elemento & Controles de Janela
            _buildRightHeader(element),

            // 2. Barra de Filtros Rápidos Dinâmicos (Visão Completa | Níveis & Peças | Propriedades IFC | Arquivo BIM)
            _buildDynamicFilterBar(),

            const Divider(height: 1, color: AppColors.border),

            // 3. Conteúdo Dinâmico Scrollável
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                children: [
                  // BLOCO A: Quantitativo da Peça no Projeto + Filtro por Nível (DropdownList)
                  if (_activeFilter == DynamicPanelFilter.all ||
                      _activeFilter == DynamicPanelFilter.levels) ...[
                    _buildStoreyQuantityCard(element),
                    const SizedBox(height: 12),
                  ],

                  // BLOCO B: Especificações do Elemento com Boas Práticas openBIM
                  if (_activeFilter == DynamicPanelFilter.all ||
                      _activeFilter == DynamicPanelFilter.elementSpecs) ...[
                    _buildElementSpecificationsSection(element, standardizedSections),
                    const SizedBox(height: 12),
                  ],

                  // BLOCO C: Especificações BIM Importadas do Arquivo / Projeto
                  if (_activeFilter == DynamicPanelFilter.all ||
                      _activeFilter == DynamicPanelFilter.bimProject) ...[
                    _buildImportedBimProjectSpecsCard(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cabeçalho compacto e informativo do elemento selecionado com botões de ajuste rápido e saída
  Widget _buildRightHeader(BimElementMetadata element) {
    final hostLevel = element.hostStoreyName ?? element.analytics?.hostStoreyName;
    final isExpandedInfo = widget.controller.dynamicSplitRatio <= 0.38;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
      color: AppColors.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.22)),
            ),
            child: Icon(element.categoryIcon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        element.friendlyCategory.toUpperCase(),
                        style: AppTypography.badgeLabel.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    if (hostLevel != null && hostLevel.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.layers_rounded, size: 10, color: Color(0xFF059669)),
                            const SizedBox(width: 3),
                            Text(
                              hostLevel,
                              style: const TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      '#${element.expressID} • ${element.category}',
                      style: AppTypography.bodySmall.copyWith(fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  element.cleanTitle,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Botão rápido para expandir/equilibrar o painel de especificações além da divisória arrastável
          IconButton(
            tooltip: isExpandedInfo ? 'Equilibrar Janelas (46/54)' : 'Ampliar Especificações (34/66)',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              isExpandedInfo ? Icons.vertical_split_rounded : Icons.open_in_full_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              if (isExpandedInfo) {
                widget.controller.resetDynamicSplitRatio();
              } else {
                widget.controller.setDynamicSplitRatio(0.34);
              }
            },
          ),
          IconButton(
            tooltip: 'Sair da Visualização Dinâmica',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.primary),
            onPressed: () {
              HapticFeedback.lightImpact();
              widget.onExit();
            },
          ),
        ],
      ),
    );
  }

  /// Barra horizontal de navegação rápida entre os módulos do painel direito
  Widget _buildDynamicFilterBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: DynamicPanelFilter.values.map((filter) {
            final selected = _activeFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                selected: selected,
                showCheckmark: false,
                avatar: Icon(
                  filter.icon,
                  size: 14,
                  color: selected ? AppColors.surface : AppColors.textMuted,
                ),
                label: Text(filter.label),
                labelStyle: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? AppColors.surface : AppColors.textDark,
                ),
                selectedColor: AppColors.accent,
                backgroundColor: AppColors.background,
                side: BorderSide(
                  color: selected ? AppColors.accent : AppColors.border,
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() => _activeFilter = filter);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ===========================================================================
  // BLOCO A: QUANTITATIVO DA PEÇA E FILTRO DINÂMICO POR NÍVEL (STOREY DROPDOWN)
  // ===========================================================================

  Widget _buildStoreyQuantityCard(BimElementMetadata element) {
    final storeys = widget.controller.availableStoreys;
    final selectedStoreyId = widget.controller.selectedStoreyFilterId;
    final isSwitching = widget.controller.isSwitchingDynamicElement;
    final analytics = element.analytics ??
        BimPieceAnalytics(
          typeName: element.cleanTitle,
          totalInProject: 1,
          totalCategoryInProject: 1,
          allInstanceIds: [element.expressID],
          hostStoreyId: element.hostStoreyId,
          hostStoreyName: element.hostStoreyName,
        );

    // Garante que o valor do Dropdown seja sempre válido na lista atual de níveis
    final validSelectedId =
        (selectedStoreyId != null && storeys.any((s) => s.expressID == selectedStoreyId))
            ? selectedStoreyId
            : null;

    final selectedStoreyObj = validSelectedId != null
        ? storeys.where((s) => s.expressID == validSelectedId).firstOrNull
        : null;

    final pieceCount = analytics.countForStorey(validSelectedId);
    final totalProjectCount = analytics.totalInProject;
    final ratio = analytics.ratioOfProjectForStorey(validSelectedId);
    final pctInt = (ratio * 100).round();
    final categoryCount = analytics.categoryCountForStorey(validSelectedId);
    final instancesInScope = analytics.instancesForStorey(validSelectedId);
    final aggMetrics = analytics.metricsForStorey(validSelectedId);
    final categoryPlural = BimNomenclatureMapper.friendlyCategoryPlural(element.category);

    final currentIndexInScope = instancesInScope.indexOf(element.expressID);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho do Card de Quantitativo por Nível
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.analytics_rounded, size: 16, color: AppColors.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QUANTITATIVO DA PEÇA POR NÍVEL',
                      style: AppTypography.badgeLabel.copyWith(
                        color: AppColors.accent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Filtre pelos pavimentos do arquivo IFC para atualizar quantidades e métricas',
                      style: AppTypography.bodySmall.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // DropdownList dos Níveis existentes no arquivo IFC selecionado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 1.2),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                key: const ValueKey('storey_filter_dropdown'),
                value: validSelectedId,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                dropdownColor: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Row(
                      children: [
                        const Icon(Icons.apartment_rounded, size: 16, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            storeys.isEmpty
                                ? 'Todos os Níveis (Modelo Completo)'
                                : 'Todos os Níveis (${storeys.length} pavimentos • $totalProjectCount un.)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...storeys.map((storey) {
                    final countOnLevel = analytics.countForStorey(storey.expressID);
                    final isElementHost = analytics.hostStoreyId == storey.expressID;
                    return DropdownMenuItem<int?>(
                      value: storey.expressID,
                      child: Row(
                        children: [
                          Icon(
                            Icons.layers_rounded,
                            size: 15,
                            color: countOnLevel > 0 ? AppColors.accent : AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              storey.dropdownLabel,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 12.5,
                                fontWeight:
                                    countOnLevel > 0 ? FontWeight.w700 : FontWeight.w500,
                                color: countOnLevel > 0
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                          if (isElementHost) ...[
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PEÇA ATUAL',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: countOnLevel > 0
                                  ? AppColors.accent.withValues(alpha: 0.12)
                                  : AppColors.border.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$countOnLevel un.',
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: countOnLevel > 0
                                    ? AppColors.accent
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: isSwitching
                    ? null
                    : (newStoreyId) {
                        HapticFeedback.selectionClick();
                        widget.controller.setStoreyFilter(newStoreyId);
                      },
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Métricas Dinâmicas Atualizadas conforme o Nível Selecionado
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Column(
              key: ValueKey('storey_stats_${validSelectedId ?? "ALL"}_${analytics.typeName}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cards Principais de Contagem
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              validSelectedId == null
                                  ? 'TOTAL DESTA PEÇA NA OBRA'
                                  : 'DESTA PEÇA EM ${selectedStoreyObj?.name.toUpperCase() ?? "NÍVEL"}',
                              style: const TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF93C5FD),
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$pieceCount',
                                  style: const TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.surface,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  pieceCount == 1 ? 'unidade' : 'unidades',
                                  style: const TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              validSelectedId == null
                                  ? '100% do projeto mapeado'
                                  : '$pctInt% do total de $totalProjectCount un. do projeto',
                              style: const TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 10.5,
                                color: Color(0xFF94A3B8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              validSelectedId == null
                                  ? 'CATEGORIA ($categoryPlural)'
                                  : 'CONTEXTO DO PAVIMENTO',
                              style: const TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$categoryCount $categoryPlural',
                              style: const TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              selectedStoreyObj != null
                                  ? 'Cota ${selectedStoreyObj.formattedElevation} • ${selectedStoreyObj.totalElementsInStorey} itens BIM'
                                  : '${widget.controller.projectSpecs?.totalElements ?? totalProjectCount} elementos totais no IFC',
                              style: AppTypography.bodySmall.copyWith(fontSize: 10.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Barra de Proporção Visual no Nível
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      pieceCount > 0 ? AppColors.accent : AppColors.textMuted,
                    ),
                  ),
                ),

                // Métricas Físicas Somadas para o Nível Selecionado
                if (pieceCount > 0 &&
                    (aggMetrics.lengthM > 0 ||
                        aggMetrics.areaM2 > 0 ||
                        aggMetrics.volumeM3 > 0)) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (aggMetrics.lengthM > 0)
                        _buildMiniStatBox(
                          label: validSelectedId == null
                              ? 'Comp. Acumulado'
                              : 'Comp. no Nível',
                          value: aggMetrics.formattedLength,
                        ),
                      if (aggMetrics.areaM2 > 0) ...[
                        const SizedBox(width: 6),
                        _buildMiniStatBox(
                          label: validSelectedId == null
                              ? 'Área Acumulada'
                              : 'Área no Nível',
                          value: aggMetrics.formattedArea,
                        ),
                      ],
                      if (aggMetrics.volumeM3 > 0) ...[
                        const SizedBox(width: 6),
                        _buildMiniStatBox(
                          label: validSelectedId == null
                              ? 'Volume Acumulado'
                              : 'Volume no Nível',
                          value: aggMetrics.formattedVolume,
                        ),
                      ],
                    ],
                  ),
                ],

                // Navegador Interativo de Instâncias no 3D (< Peça X de N > + Destacar Todas) com sincronização anti-gargalo
                if (instancesInScope.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: isSwitching
                            ? AppColors.accent.withValues(alpha: 0.45)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (isSwitching)
                          const SizedBox(
                            key: ValueKey('instance_loading_indicator'),
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          )
                        else
                          const Icon(Icons.my_location_rounded, size: 14, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isSwitching
                                ? 'Carregando e renderizando peça...'
                                : (currentIndexInScope >= 0
                                    ? 'Inspecionando ${currentIndexInScope + 1} de ${instancesInScope.length} nesta vista'
                                    : '${instancesInScope.length} un. disponíveis neste nível'),
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isSwitching ? AppColors.accent : AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (instancesInScope.length > 1) ...[
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 120),
                            opacity: isSwitching ? 0.32 : 1.0,
                            child: InkWell(
                              key: const ValueKey('instance_prev_button'),
                              borderRadius: BorderRadius.circular(6),
                              onTap: isSwitching
                                  ? null
                                  : () {
                                      HapticFeedback.selectionClick();
                                      final prevIdx = currentIndexInScope > 0
                                          ? currentIndexInScope - 1
                                          : instancesInScope.length - 1;
                                      widget.controller.inspectPieceInstance(instancesInScope[prevIdx]);
                                    },
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.chevron_left_rounded, size: 18, color: AppColors.primary),
                              ),
                            ),
                          ),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 120),
                            opacity: isSwitching ? 0.32 : 1.0,
                            child: InkWell(
                              key: const ValueKey('instance_next_button'),
                              borderRadius: BorderRadius.circular(6),
                              onTap: isSwitching
                                  ? null
                                  : () {
                                      HapticFeedback.selectionClick();
                                      final nextIdx = currentIndexInScope >= 0 &&
                                              currentIndexInScope < instancesInScope.length - 1
                                          ? currentIndexInScope + 1
                                          : 0;
                                      widget.controller.inspectPieceInstance(instancesInScope[nextIdx]);
                                    },
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 120),
                          opacity: isSwitching ? 0.38 : 1.0,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: isSwitching
                                ? null
                                : () {
                                    HapticFeedback.selectionClick();
                                    if (instancesInScope.length == 1 && currentIndexInScope < 0) {
                                      widget.controller.inspectPieceInstance(instancesInScope.first);
                                    } else {
                                      widget.controller.toggleHighlightSimilarIn3D();
                                    }
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: widget.controller.highlightSimilarIn3D
                                    ? AppColors.success
                                    : AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                instancesInScope.length == 1 && currentIndexInScope < 0
                                    ? 'Ir até Peça'
                                    : (widget.controller.highlightSimilarIn3D
                                        ? 'Destacadas'
                                        : 'Ver no 3D'),
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: widget.controller.highlightSimilarIn3D
                                      ? AppColors.surface
                                      : AppColors.accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'Nenhuma unidade de "${element.cleanTitle}" está registrada neste pavimento.',
                      style: AppTypography.bodySmall.copyWith(fontSize: 11.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatBox({required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
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
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // BLOCO B: ESPECIFICAÇÕES DO ELEMENTO (BOAS PRÁTICAS DE NOMENCLATURA IFC)
  // ===========================================================================

  Widget _buildElementSpecificationsSection(
    BimElementMetadata element,
    List<StandardizedBimSection> sections,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho + Campo de Busca Rápida de Parâmetros IFC
        Row(
          children: [
            const Icon(Icons.fact_check_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'ESPECIFICAÇÕES DO ELEMENTO (PADRÃO openBIM)',
                style: AppTypography.badgeLabel.copyWith(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Barra de filtro rápido de propriedades
        SizedBox(
          height: 36,
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 12.5,
              color: AppColors.textDark,
            ),
            decoration: InputDecoration(
              hintText: 'Buscar propriedade, dimensão ou material IFC...',
              hintStyle: AppTypography.bodySmall.copyWith(fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, size: 17, color: AppColors.textMuted),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.clear_rounded, size: 16, color: AppColors.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.accent, width: 1.3),
              ),
            ),
          ),
        ),

        // Chips de Materiais Importados (quando presentes no IFC)
        if (element.materials.isNotEmpty && _searchQuery.isEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: element.materials.take(3).map((mat) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.texture_rounded, size: 13, color: AppColors.accent),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        mat,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 8),

        if (sections.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              _searchQuery.isEmpty
                  ? 'Nenhuma propriedade adicional exportada para este elemento.'
                  : 'Nenhuma propriedade corresponde a "$_searchQuery".',
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
          )
        else
          ...sections.map(_buildStandardizedPsetCard),
      ],
    );
  }

  Widget _buildStandardizedPsetCard(StandardizedBimSection section) {
    final showTechnicalSubtitle = section.rawPsetName.toLowerCase() != section.displayTitle.toLowerCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(section.icon, size: 15, color: AppColors.accent),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    section.displayTitle,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (showTechnicalSubtitle)
                  Flexible(
                    child: Text(
                      section.rawPsetName,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 10,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...section.properties.map((prop) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prop.displayLabel,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (prop.displayLabel.toLowerCase() !=
                            prop.canonicalIfcKey.toLowerCase())
                          Text(
                            'IFC: ${prop.canonicalIfcKey}',
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 9.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: prop.isBoolean
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: prop.booleanTrue
                                    ? AppColors.success.withValues(alpha: 0.14)
                                    : AppColors.destructive.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                prop.formattedValue,
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: prop.booleanTrue
                                      ? const Color(0xFF059669)
                                      : AppColors.destructive,
                                ),
                              ),
                            )
                          : Text(
                              prop.formattedValue,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
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

  // ===========================================================================
  // BLOCO C: ESPECIFICAÇÕES BIM IMPORTADAS DO ARQUIVO E INFORMAÇÕES DO PROJETO
  // ===========================================================================

  Widget _buildImportedBimProjectSpecsCard() {
    final specs = widget.controller.projectSpecs;

    final projectTitle = (specs != null && specs.projectName.isNotEmpty)
        ? specs.projectName
        : widget.project.name;
    final schemaBadge = specs?.schema.isNotEmpty == true ? specs!.schema : widget.project.format;
    final mvdBadge = specs?.viewDefinition.isNotEmpty == true
        ? specs!.viewDefinition
        : 'Modelo 3D Offline';

    final List<({String label, String value})> projectRows = [
      (label: 'Arquivo Importado', value: '${widget.project.name} (${widget.project.formattedSize})'),
      if (specs != null && specs.projectNumber.isNotEmpty)
        (label: 'Código do Projeto (IfcProject)', value: specs.projectNumber),
      if (specs != null && specs.projectPhase.isNotEmpty)
        (label: 'Disciplina / Fase BIM', value: specs.projectPhase),
      if (specs != null && specs.authoringApp.isNotEmpty)
        (label: 'Software Autoral BIM', value: specs.authoringApp),
      if (specs != null && (specs.author.isNotEmpty || specs.organization.isNotEmpty))
        (
          label: 'Responsável / Organização',
          value: [specs.author, specs.organization].where((s) => s.isNotEmpty).join(' • ')
        ),
      if (specs != null && specs.address.isNotEmpty)
        (label: 'Localização da Obra', value: specs.address),
      if (specs != null && specs.siteName.isNotEmpty)
        (label: 'Terreno (IfcSite)', value: specs.siteName),
      if (specs != null && specs.coordinateSystem.isNotEmpty)
        (label: 'Referencial Geodésico', value: specs.coordinateSystem),
      if (specs != null)
        (
          label: 'Unidades Nativas IFC',
          value: '${specs.lengthUnit} • ${specs.areaUnit}'
        ),
      if (specs != null && specs.storeys.isNotEmpty)
        (
          label: 'Estrutura Altimétrica',
          value: '${specs.storeys.length} níveis (${specs.elevationSpanLabel})'
        ),
      if (specs != null && specs.totalElements > 0)
        (label: 'Total de Elementos Modelados', value: '${specs.totalElements} peças físicas'),
      if (specs != null && specs.exportDate.isNotEmpty)
        (label: 'Data de Exportação IFC', value: specs.formattedExportDate),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho escuro elegante com selo openBIM
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.domain_verification_rounded, size: 16, color: Color(0xFF60A5FA)),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'ESPECIFICAÇÕES BIM DO PROJETO & ARQUIVO',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF93C5FD),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        schemaBadge,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.surface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  projectTitle,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.surface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'MVD: $mvdBadge',
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 11,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
          ),

          // Linhas de metadados importados do arquivo IFC
          ...projectRows.map((row) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      row.label,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 6,
                    child: Text(
                      row.value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Resumo de Inventário por Categoria IFC do Arquivo
          if (specs != null && specs.categorySummary.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INVENTÁRIO DE DISCIPLINAS / CATEGORIAS NO IFC',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: (specs.categorySummary.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value)))
                        .take(8)
                        .map((entry) {
                      final catLabel = BimNomenclatureMapper.friendlyCategoryPlural(entry.key);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '$catLabel: ${entry.value}',
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

