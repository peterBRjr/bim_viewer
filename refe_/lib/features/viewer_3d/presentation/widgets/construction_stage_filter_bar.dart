import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../controllers/viewer_3d_controller.dart';

/// Botão Flutuante com indicação em tempo real do filtro de etapas ativo.
/// Ao clicar, abre um [showDialog] moderno contendo Radio Buttons para seleção
/// exclusiva entre Obra Completa, Fundação, Pré-Moldado e Estrutura Metálica.
class ConstructionStageFilterButton extends StatelessWidget {
  final Viewer3DController controller;

  const ConstructionStageFilterButton({
    super.key,
    required this.controller,
  });

  void _openFilterDialog(BuildContext context) {
    HapticFeedback.selectionClick();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => ConstructionStageFilterDialog(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final mode = controller.currentStageFilterMode;
        final isFiltering = controller.isStageFilterActive;

        Color activeIndicatorColor;
        String modeText;
        IconData modeIcon;

        switch (mode) {
          case StageFilterMode.foundation:
            activeIndicatorColor = const Color(0xFFD97706); // Amber
            modeText = 'Fundação';
            modeIcon = Icons.foundation_rounded;
            break;
          case StageFilterMode.precast:
            activeIndicatorColor = const Color(0xFF8B5CF6); // Purple
            modeText = 'Pré-Moldado';
            modeIcon = Icons.view_in_ar_rounded;
            break;
          case StageFilterMode.steel:
            activeIndicatorColor = const Color(0xFF2563EB); // Royal Blue
            modeText = 'Metálica';
            modeIcon = Icons.architecture_rounded;
            break;
          case StageFilterMode.all:
            activeIndicatorColor = const Color(0xFF38BDF8); // Sky Blue
            modeText = 'Obra Completa';
            modeIcon = Icons.layers_rounded;
            break;
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 10, left: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('stage_filter_floating_button'),
                onTap: () => _openFilterDialog(context),
                borderRadius: BorderRadius.circular(24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isFiltering
                              ? activeIndicatorColor.withValues(alpha: 0.85)
                              : Colors.white.withValues(alpha: 0.16),
                          width: isFiltering ? 1.4 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isFiltering
                                ? activeIndicatorColor.withValues(alpha: 0.30)
                                : Colors.black.withValues(alpha: 0.30),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Ícone com indicador de cor
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: activeIndicatorColor.withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              modeIcon,
                              size: 14,
                              color: activeIndicatorColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Texto com indicação do filtro
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'FILTRO VISUAL',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: isFiltering ? activeIndicatorColor : const Color(0xFF94A3B8),
                                ),
                              ),
                              Text(
                                modeText,
                                style: const TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Diálogo modal moderno contendo Radio Buttons para seleção exclusiva
/// da etapa construtiva a ser visualizada no modelo 3D.
class ConstructionStageFilterDialog extends StatelessWidget {
  final Viewer3DController controller;

  const ConstructionStageFilterDialog({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final currentMode = controller.currentStageFilterMode;
        final summary = controller.stagesSummary;

        return Dialog(
          key: const ValueKey('construction_stage_filter_dialog'),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 16,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header do Dialog
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.layers_rounded,
                            size: 20,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filtro de Visualização',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 1),
                              Text(
                                'Selecione a etapa para isolar na obra',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('close_stage_filter_dialog_button'),
                          icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 14),

                    // Opções com Radio Button
                    RadioGroup<StageFilterMode>(
                      groupValue: currentMode,
                      onChanged: (StageFilterMode? val) {
                        if (val != null) {
                          HapticFeedback.selectionClick();
                          controller.setStageFilterMode(val);
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Obra Completa
                          _buildRadioOptionCard(
                            context: context,
                            keyName: 'stage_radio_all',
                            mode: StageFilterMode.all,
                            title: 'Obra Completa',
                            subtitle: 'Exibe todas as estruturas do projeto',
                            countText: summary != null && summary.totalCount > 0 ? '${summary.totalCount} itens' : null,
                            icon: Icons.domain_rounded,
                            color: const Color(0xFF0F172A),
                            isSelected: currentMode == StageFilterMode.all,
                          ),

                          const SizedBox(height: 8),

                          // 2. Fundação
                          _buildRadioOptionCard(
                            context: context,
                            keyName: 'stage_radio_foundation',
                            mode: StageFilterMode.foundation,
                            title: 'Fundação',
                            subtitle: 'Sapatas, blocos, estacas e vigas baldrame',
                            countText: summary != null && summary.foundationCount > 0 ? '${summary.foundationCount} peças' : null,
                            icon: Icons.foundation_rounded,
                            color: const Color(0xFFD97706),
                            isSelected: currentMode == StageFilterMode.foundation,
                          ),

                          const SizedBox(height: 8),

                          // 3. Pré-Moldado
                          _buildRadioOptionCard(
                            context: context,
                            keyName: 'stage_radio_precast',
                            mode: StageFilterMode.precast,
                            title: 'Pré-Moldado',
                            subtitle: 'Pilares pré-fabricados, vigas e painéis',
                            countText: summary != null && summary.precastCount > 0 ? '${summary.precastCount} peças' : null,
                            icon: Icons.view_in_ar_rounded,
                            color: const Color(0xFF8B5CF6),
                            isSelected: currentMode == StageFilterMode.precast,
                          ),

                          const SizedBox(height: 8),

                          // 4. Estrutura Metálica
                          _buildRadioOptionCard(
                            context: context,
                            keyName: 'stage_radio_steel',
                            mode: StageFilterMode.steel,
                            title: 'Estrutura Metálica',
                            subtitle: 'Perfis laminados, treliças e terças',
                            countText: summary != null && summary.steelCount > 0 ? '${summary.steelCount} peças' : null,
                            icon: Icons.architecture_rounded,
                            color: const Color(0xFF2563EB),
                            isSelected: currentMode == StageFilterMode.steel,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Botão Concluir
                    ElevatedButton(
                      key: const ValueKey('confirm_stage_filter_dialog_button'),
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Concluir',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRadioOptionCard({
    required BuildContext context,
    required String keyName,
    required StageFilterMode mode,
    required String title,
    required String subtitle,
    required String? countText,
    required IconData icon,
    required Color color,
    required bool isSelected,
  }) {
    return InkWell(
      key: ValueKey(keyName),
      onTap: () {
        HapticFeedback.selectionClick();
        controller.setStageFilterMode(mode);
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.60) : AppColors.border,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Radio Button
            Radio<StageFilterMode>(
              value: mode,
              activeColor: color,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            // Ícone da Etapa
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isSelected ? 0.20 : 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: 10),
            // Informações da Etapa
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (countText != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            countText,
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compatibilidade de nome com interfaces existentes
typedef ConstructionStageFilterBar = ConstructionStageFilterButton;
