import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../controllers/viewer_3d_controller.dart';
import '../../domain/models/measurement_model.dart';

/// Overlay interativo para o Modo de Medição no modelo 3D.
/// Permite calcular vãos livres (spans) com 1 toque ou medições ponto a ponto.
class MeasureModeOverlay extends StatefulWidget {
  final Viewer3DController controller;
  final VoidCallback onClose;

  const MeasureModeOverlay({
    super.key,
    required this.controller,
    required this.onClose,
  });

  @override
  State<MeasureModeOverlay> createState() => _MeasureModeOverlayState();
}

class _MeasureModeOverlayState extends State<MeasureModeOverlay> {
  bool _showBanner = true;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final lastMeasurement = controller.lastMeasurement;

    return SafeArea(
      child: Stack(
        children: [
          // 1. Banner Superior: Card Fiel do Modo de Medição (Apresentação técnica)
          if (_showBanner)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: _buildBannerCard(),
            ),

          // 2. Painel Inferior Flutuante com Controles e Leitura de Cotas
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildBottomMeasurementPanel(controller, lastMeasurement),
          ),
        ],
      ),
    );
  }

  /// Card de apresentação fiel ao diagrama / mockup de engenharia:
  /// "Modo de Medição: Calcule vãos livres (spans) diretamente no modelo 3D com um toque."
  Widget _buildBannerCard() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 280),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        return Transform.translate(
          offset: Offset(0, (1.0 - val) * -20),
          child: Opacity(
            opacity: val.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF94A3B8), // Borda cinza metálica técnica
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.straighten_rounded,
                color: AppColors.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Modo de Medição',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      letterSpacing: -0.3,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Calcule vãos livres (spans) diretamente no modelo 3D com um toque.',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF334155),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _showBanner = false);
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Painel Inferior Flutuante com Controles do Modo de Medição
  Widget _buildBottomMeasurementPanel(
    Viewer3DController controller,
    MeasurementModel? lastMeasurement,
  ) {
    final isSpanMode = controller.measureSubMode == 'span';
    final hasMeasurements = controller.hasMeasurements;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Alternador de Submodo (Vão Livre 1 Toque vs Ponto a Ponto)
              Row(
                children: [
                  Expanded(
                    child: _buildSubModeTab(
                      label: 'Vão Livre (1 Toque)',
                      icon: Icons.touch_app_rounded,
                      isActive: isSpanMode,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        controller.setMeasureSubMode('span');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSubModeTab(
                      label: 'Ponto a Ponto',
                      icon: Icons.linear_scale_rounded,
                      isActive: !isSpanMode,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        controller.setMeasureSubMode('point_to_point');
                      },
                    ),
                  ),
                ],
              ),

              // 2. Card de Resultado da Última Medição
              if (lastMeasurement != null) ...[
                const SizedBox(height: 12),
                _buildMeasurementResultCard(lastMeasurement, controller.measurementCount),
              ],

              // 3. Dica Contextual Dinâmica
              const SizedBox(height: 12),
              _buildContextualHint(controller, isSpanMode),

              // 4. Barra de Ações (Desfazer, Limpar, Concluir)
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Botão Desfazer Última Cota
                      IconButton(
                        tooltip: 'Desfazer última medição',
                        icon: const Icon(Icons.undo_rounded, size: 20),
                        color: hasMeasurements ? AppColors.surface : AppColors.textMuted.withValues(alpha: 0.5),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                        ),
                        onPressed: hasMeasurements
                            ? () {
                                HapticFeedback.lightImpact();
                                controller.removeLastMeasurement();
                              }
                            : null,
                      ),
                      const SizedBox(width: 8),
                      // Botão Limpar Todas as Cotas
                      IconButton(
                        tooltip: 'Limpar todas as cotas',
                        icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                        color: hasMeasurements ? const Color(0xFFF87171) : AppColors.textMuted.withValues(alpha: 0.5),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                        ),
                        onPressed: hasMeasurements
                            ? () {
                                HapticFeedback.mediumImpact();
                                controller.clearMeasurements();
                              }
                            : null,
                      ),
                    ],
                  ),
                  // Botão Concluir / Fechar Medição
                  FilledButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.onClose();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text(
                      'Concluir',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Aba seletora de submodo (Vão Livre vs Ponto a Ponto)
  Widget _buildSubModeTab({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accent : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? Colors.transparent : Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? AppColors.surface : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? AppColors.surface : AppColors.textMuted,
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
  }

  /// Card de Leitura Técnica da Medição Ativa
  Widget _buildMeasurementResultCard(MeasurementModel meas, int totalCount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: meas.isSpan ? AppColors.accent.withValues(alpha: 0.5) : const Color(0xFF10B981).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: meas.isSpan ? AppColors.accent.withValues(alpha: 0.2) : const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        meas.isSpan ? 'VÃO LIVRE' : 'DISTÂNCIA LINEAR',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: meas.isSpan ? const Color(0xFF60A5FA) : const Color(0xFF34D399),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Cota $totalCount ativa',
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  meas.formattedDistance,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.surface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ΔX: ${meas.formattedDeltaX} • ΔY (Desnível): ${meas.formattedDeltaY} • ΔZ: ${meas.formattedDeltaZ}',
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Dica de instrução técnica na tela
  Widget _buildContextualHint(Viewer3DController controller, bool isSpanMode) {
    String text;
    IconData icon;

    if (controller.isWaitingSecondPoint) {
      text = 'Toque no ponto final ou face oposta para fechar a medição.';
      icon = Icons.touch_app_rounded;
    } else if (isSpanMode) {
      text = 'Toque em qualquer face ou parede para calcular o vão livre instantaneamente.';
      icon = Icons.ads_click_rounded;
    } else {
      text = 'Toque no ponto A e depois no ponto B para traçar a cota.';
      icon = Icons.timeline_rounded;
    }

    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 12,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
      ],
    );
  }
}
