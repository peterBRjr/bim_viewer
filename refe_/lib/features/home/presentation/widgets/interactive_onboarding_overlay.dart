import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Overlay de Guia Interativo (Onboarding) minimalista e clean em 4 passos curtos.
class InteractiveOnboardingOverlay extends StatelessWidget {
  final int currentStep;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;
  final VoidCallback onOpenExportGuide;

  const InteractiveOnboardingOverlay({
    super.key,
    required this.currentStep,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
    required this.onOpenExportGuide,
  });

  static const List<_OnboardingStepData> _steps = [
    _OnboardingStepData(
      stepNumber: 1,
      badge: 'PASSO 1 DE 4',
      title: 'Visualizador BIM 3D',
      description:
          'Explore seus projetos estruturais e arquitetônicos em 3D com alta fluidez e operação offline.',
      icon: Icons.view_in_ar_rounded,
      accentColor: Color(0xFF38BDF8),
      spotlightPosition: _SpotlightTarget.centerHero,
    ),
    _OnboardingStepData(
      stepNumber: 2,
      badge: 'PASSO 2 DE 4',
      title: 'Projeto Base (ajustado.ifc)',
      description:
          'Toque no card para abrir o modelo 3D. Na Visão Dinâmica, você enquadra qualquer peça com cota automática de proximidade.',
      icon: Icons.center_focus_strong_rounded,
      accentColor: Color(0xFF2563EB),
      spotlightPosition: _SpotlightTarget.projectCard,
    ),
    _OnboardingStepData(
      stepNumber: 3,
      badge: 'PASSO 3 DE 4',
      title: 'Adicionar Novo Arquivo',
      description:
          'Use o botão "Adicionar Projeto" para importar arquivos .IFC ou .GLB salvos no seu dispositivo.',
      icon: Icons.add_circle_outline_rounded,
      accentColor: Color(0xFF10B981),
      spotlightPosition: _SpotlightTarget.fabBottomRight,
    ),
    _OnboardingStepData(
      stepNumber: 4,
      badge: 'PASSO 4 DE 4',
      title: 'Guia de Exportação IFC',
      description:
          'Consulte o Guia IFC para configurar sua exportação nos níveis Básico, Médio ou Detalhado.',
      icon: Icons.tune_rounded,
      accentColor: Color(0xFF38BDF8),
      spotlightPosition: _SpotlightTarget.topRightAction,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final safeIndex = currentStep.clamp(0, _steps.length - 1);
    final step = _steps[safeIndex];
    final isLast = safeIndex == _steps.length - 1;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. Backdrop Translúcido Clean
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.72),
                ),
              ),
            ),
          ),

          // 2. Indicador Direcional Discreto
          _buildDirectionalSpotlightIndicator(context, step),

          // 3. Card Minimalista do Passo Atual
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.30),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Topo: Passo + Pular
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              step.badge,
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: step.accentColor,
                                letterSpacing: 0.6,
                              ),
                            ),
                            TextButton(
                              key: const ValueKey('onboarding_skip_button'),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                onSkip();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF94A3B8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Pular',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Ícone + Título
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: step.accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                step.icon,
                                size: 21,
                                color: step.accentColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                step.title,
                                style: const TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Texto Simples (1 a 2 frases)
                        Text(
                          step.description,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 13.5,
                            color: Color(0xFFCBD5E1),
                            height: 1.45,
                          ),
                        ),

                        if (isLast) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              key: const ValueKey(
                                'onboarding_open_export_guide_button',
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                onOpenExportGuide();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF38BDF8),
                                side: BorderSide(
                                  color: const Color(0xFF38BDF8)
                                      .withValues(alpha: 0.50),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Abrir Guia de Exportação IFC',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Rodapé: Indicadores + Navegação
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(_steps.length, (i) {
                                final active = i == safeIndex;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 6),
                                  width: active ? 18 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? step.accentColor
                                        : const Color(0xFF475569),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (safeIndex > 0) ...[
                                  TextButton(
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      onPrevious();
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF94A3B8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      minimumSize: Size.zero,
                                    ),
                                    child: const Text('Voltar'),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                ElevatedButton(
                                  key: const ValueKey('onboarding_next_button'),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    onNext();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    isLast ? 'Concluir' : 'Próximo',
                                    style: const TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionalSpotlightIndicator(
    BuildContext context,
    _OnboardingStepData step,
  ) {
    switch (step.spotlightPosition) {
      case _SpotlightTarget.fabBottomRight:
        return Positioned(
          bottom: 18,
          right: 16,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: step.accentColor.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: step.accentColor, width: 1.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Adicionar Projeto',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case _SpotlightTarget.topRightAction:
        return Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 14,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: step.accentColor.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: step.accentColor, width: 1.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_rounded, color: Colors.white, size: 15),
                  SizedBox(width: 5),
                  Text(
                    'Guia IFC',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      case _SpotlightTarget.projectCard:
      case _SpotlightTarget.centerHero:
        return const SizedBox.shrink();
    }
  }
}

enum _SpotlightTarget {
  centerHero,
  projectCard,
  fabBottomRight,
  topRightAction,
}

class _OnboardingStepData {
  final int stepNumber;
  final String badge;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final _SpotlightTarget spotlightPosition;

  const _OnboardingStepData({
    required this.stepNumber,
    required this.badge,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.spotlightPosition,
  });
}
