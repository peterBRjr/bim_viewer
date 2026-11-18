import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Overlay de Guia Interativo (Onboarding / Spotlight Tour) com estética futurista
/// em Glassmorphism, foco visual direcionado por contraste de cor e navegação leve em 4 passos.
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
      badge: 'PASSO 1 DE 4 • BEM-VINDO AO AMBIENTE 3D',
      title: 'Engenharia Digital 3D no seu iPhone',
      description:
          'Explore maquetes estruturais e arquitetônicas openBIM (.IFC, .GLB e .GLTF) em 60 FPS com iluminação técnica, corte em tempo real e operação 100% offline para o canteiro de obras.',
      highlightTag: 'Projeto Base • ajustado.ifc pronto na tela inicial',
      icon: Icons.view_in_ar_rounded,
      accentColor: Color(0xFF38BDF8),
      spotlightPosition: _SpotlightTarget.centerHero,
    ),
    _OnboardingStepData(
      stepNumber: 2,
      badge: 'PASSO 2 DE 4 • INSPEÇÃO E VISÃO DINÂMICA',
      title: 'Abra o Projeto Base (ajustado.ifc)',
      description:
          'Toque no card do projeto para entrar no 3D. Ao selecionar qualquer parede, viga, pilar ou esquadria, ative a Visão Dinâmica para enquadramento automático sem obstruções e cota 3D até o vizinho mais próximo (≤ 6m).',
      highlightTag: 'Dica: Gire com 1 dedo, dê zoom em pinça e corte pavimentos',
      icon: Icons.center_focus_strong_rounded,
      accentColor: Color(0xFF2563EB),
      spotlightPosition: _SpotlightTarget.projectCard,
    ),
    _OnboardingStepData(
      stepNumber: 3,
      badge: 'PASSO 3 DE 4 • COMO ADICIONAR NOVOS ARQUIVOS',
      title: 'Importe Seus Próprios Modelos BIM',
      description:
          'Toque no botão azul "Adicionar Projeto" (no canto inferior direito ou no topo) para selecionar qualquer arquivo .IFC ou .GLB salvo no app Arquivos (Files), iCloud Drive, E-mail ou WhatsApp.',
      highlightTag: 'Cópia segura local: seus projetos ficam salvos offline',
      icon: Icons.add_circle_outline_rounded,
      accentColor: Color(0xFF10B981),
      spotlightPosition: _SpotlightTarget.fabBottomRight,
    ),
    _OnboardingStepData(
      stepNumber: 4,
      badge: 'PASSO 4 DE 4 • PARÂMETROS DE EXPORTAÇÃO IFC',
      title: 'Guia de Exportação (Básico • Médio • Detalhado)',
      description:
          'Antes de exportar do Revit, Tekla, Archicad ou Eberick, consulte nossa página "Guia IFC" no topo da tela para configurar os parâmetros exatos de cada nível sem sobrecarregar o hardware.',
      highlightTag: 'Configure tesselação, MVD e filtros para máxima fluidez no iOS',
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
          // 1. Backdrop Translúcido com Desfoque Suave (Direcionamento de Visão)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                child: Container(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.78),
                ),
              ),
            ),
          ),

          // 2. Indicador Luminoso Direcional (Truque de Visão / Spotlight Visual)
          _buildDirectionalSpotlightIndicator(context, step),

          // 3. Card Central / Contextual do Guia Interativo
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: step.accentColor.withValues(alpha: 0.55),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: step.accentColor.withValues(alpha: 0.22),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Barra Superior: Badge + Botão Pular
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: step.accentColor.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: step.accentColor.withValues(alpha: 0.40),
                                  ),
                                ),
                                child: Text(
                                  step.badge,
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: step.accentColor,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
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
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Pular Tour',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Ícone + Título Principal
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: step.accentColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: step.accentColor.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Icon(
                                step.icon,
                                size: 25,
                                color: step.accentColor,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                step.title,
                                style: const TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.4,
                                  height: 1.15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Descrição Clara e Direta
                        Text(
                          step.description,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFFCBD5E1),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Callout de Destaque Visual
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.tips_and_updates_rounded,
                                size: 16,
                                color: step.accentColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  step.highlightTag,
                                  style: const TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (isLast) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              key: const ValueKey('onboarding_open_export_guide_button'),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                onOpenExportGuide();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF38BDF8),
                                side: const BorderSide(color: Color(0xFF38BDF8)),
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.menu_book_rounded, size: 17),
                              label: const Text(
                                'Ver Guia de Exportação IFC Agora',
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

                        // Rodapé: Indicadores de Passo + Botões Voltar / Avançar
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 10,
                          children: [
                            // Dots de Progresso
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(_steps.length, (i) {
                                final active = i == safeIndex;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 6),
                                  width: active ? 20 : 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? step.accentColor
                                        : const Color(0xFF475569),
                                    borderRadius: BorderRadius.circular(4),
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
                                      foregroundColor: const Color(0xFFCBD5E1),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      minimumSize: Size.zero,
                                    ),
                                    child: const Text('Anterior'),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                ElevatedButton.icon(
                                  key: const ValueKey('onboarding_next_button'),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    onNext();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                  ),
                                  icon: Icon(
                                    isLast
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.arrow_forward_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    isLast ? 'Começar' : 'Próximo',
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: step.accentColor.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: step.accentColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: step.accentColor.withValues(alpha: 0.45),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Adicionar Projeto (.IFC / .GLB)',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: step.accentColor.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: step.accentColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: step.accentColor.withValues(alpha: 0.45),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Guia IFC no Topo',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
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
  final String highlightTag;
  final IconData icon;
  final Color accentColor;
  final _SpotlightTarget spotlightPosition;

  const _OnboardingStepData({
    required this.stepNumber,
    required this.badge,
    required this.title,
    required this.description,
    required this.highlightTag,
    required this.icon,
    required this.accentColor,
    required this.spotlightPosition,
  });
}
