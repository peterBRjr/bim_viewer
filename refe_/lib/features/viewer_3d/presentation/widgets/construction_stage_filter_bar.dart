import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../controllers/viewer_3d_controller.dart';

/// Barra Flutuante de Filtro por Etapas da Obra (Fundação • Pré-Moldado • Estrutura Metálica).
/// Permite ao engenheiro isolar ou combinar visualmente as grandes fases de execução da obra.
class ConstructionStageFilterBar extends StatelessWidget {
  final Viewer3DController controller;

  const ConstructionStageFilterBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final summary = controller.stagesSummary;
    final isFiltering = controller.isStageFilterActive;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barra Principal com Chips Flutuantes
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. Chip Fundação
                        _buildStageChip(
                          context: context,
                          keyName: 'stage_chip_foundation',
                          stage: ConstructionStage.foundation,
                          label: 'Fundação',
                          count: summary?.foundationCount,
                          isActive: controller.filterFoundation,
                          activeColor: const Color(0xFFD97706), // Amber / Ocre
                          onTap: () {
                            HapticFeedback.selectionClick();
                            controller.toggleStage(ConstructionStage.foundation);
                          },
                          onLongPress: () {
                            HapticFeedback.heavyImpact();
                            controller.isolateStage(ConstructionStage.foundation);
                          },
                        ),
                        const SizedBox(width: 5),

                        // 2. Chip Pré-Moldado
                        _buildStageChip(
                          context: context,
                          keyName: 'stage_chip_precast',
                          stage: ConstructionStage.precast,
                          label: 'Pré-Moldado',
                          count: summary?.precastCount,
                          isActive: controller.filterPrecast,
                          activeColor: const Color(0xFF64748B), // Slate Concreto
                          onTap: () {
                            HapticFeedback.selectionClick();
                            controller.toggleStage(ConstructionStage.precast);
                          },
                          onLongPress: () {
                            HapticFeedback.heavyImpact();
                            controller.isolateStage(ConstructionStage.precast);
                          },
                        ),
                        const SizedBox(width: 5),

                        // 3. Chip Estrutura Metálica
                        _buildStageChip(
                          context: context,
                          keyName: 'stage_chip_steel',
                          stage: ConstructionStage.steel,
                          label: 'Metálica',
                          count: summary?.steelCount,
                          isActive: controller.filterSteel,
                          activeColor: const Color(0xFF2563EB), // Royal Blue Aço
                          onTap: () {
                            HapticFeedback.selectionClick();
                            controller.toggleStage(ConstructionStage.steel);
                          },
                          onLongPress: () {
                            HapticFeedback.heavyImpact();
                            controller.isolateStage(ConstructionStage.steel);
                          },
                        ),
                        const SizedBox(width: 5),

                        // 4. Chip Ver Tudo (Restaura todas as etapas)
                        InkWell(
                          key: const ValueKey('stage_chip_all'),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            controller.resetStageFilter();
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: !isFiltering
                                  ? Colors.white.withValues(alpha: 0.16)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: !isFiltering
                                    ? Colors.white.withValues(alpha: 0.35)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.all_inclusive_rounded,
                                  size: 14,
                                  color: !isFiltering
                                      ? Colors.white
                                      : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Ver Tudo',
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 11.5,
                                    fontWeight: !isFiltering
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: !isFiltering
                                        ? Colors.white
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Badge de Feedback Ativo (se estiver filtrando alguma etapa específica)
            if (isFiltering) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    key: const ValueKey('stage_filter_active_banner'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.40),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.filter_alt_rounded,
                          size: 13,
                          color: Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _getActiveFilterSummaryText(),
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          key: const ValueKey('stage_filter_restore_button'),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            controller.resetStageFilter();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Restaurar Obra',
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStageChip({
    required BuildContext context,
    required String keyName,
    required ConstructionStage stage,
    required String label,
    required int? count,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    return InkWell(
      key: ValueKey(keyName),
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.28)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? activeColor : Colors.white.withValues(alpha: 0.08),
            width: isActive ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(stage.emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive
                      ? activeColor
                      : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getActiveFilterSummaryText() {
    final active = <String>[];
    if (controller.filterFoundation) active.add('Fundação');
    if (controller.filterPrecast) active.add('Pré-Moldado');
    if (controller.filterSteel) active.add('Metálica');

    if (active.length == 1) {
      final name = active.first;
      final count = name == 'Fundação'
          ? controller.stagesSummary?.foundationCount
          : (name == 'Pré-Moldado'
              ? controller.stagesSummary?.precastCount
              : controller.stagesSummary?.steelCount);
      return 'Isolado: $name ${count != null && count > 0 ? "($count peças)" : ""}';
    }

    return 'Filtrando: ${active.join(" + ")}';
  }
}
