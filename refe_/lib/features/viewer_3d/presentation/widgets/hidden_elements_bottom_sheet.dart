import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../controllers/viewer_3d_controller.dart';

/// Modal BottomSheet interativo para visualização rápida e gerenciamento
/// dos elementos BIM que foram temporariamente ocultados da cena 3D.
class HiddenElementsBottomSheet extends StatelessWidget {
  final Viewer3DController controller;
  final VoidCallback? onAllRestored;

  const HiddenElementsBottomSheet({
    super.key,
    required this.controller,
    this.onAllRestored,
  });

  /// Invocador utilitário com abertura suave e cantos arredondados
  static Future<void> show({
    required BuildContext context,
    required Viewer3DController controller,
    VoidCallback? onAllRestored,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => HiddenElementsBottomSheet(
        controller: controller,
        onAllRestored: onAllRestored,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hiddenItems = controller.hiddenElements;
        final hasHidden = hiddenItems.isNotEmpty;

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.70,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.94),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.0,
                  ),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 28,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Puxador central (Drag Handle)
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),

                    // 2. Cabeçalho com Ícone do Olho e Contagem
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Icon(
                              Icons.visibility_off_rounded,
                              size: 18,
                              color: Color(0xFFFBBF24),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Flexible(
                                      child: Text(
                                        'Elementos Ocultados',
                                        style: TextStyle(
                                          fontFamily: AppTypography.fontFamily,
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.surface,
                                          letterSpacing: -0.3,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${hiddenItems.length}',
                                        style: const TextStyle(
                                          fontFamily: AppTypography.fontFamily,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFFDE68A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hasHidden
                                      ? 'Toque para visualizar ou reexibir no modelo'
                                      : 'Todos os elementos visíveis',
                                  style: const TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 11.5,
                                    color: AppColors.textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Fechar',
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: const EdgeInsets.all(4),
                            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),

                    const Divider(color: Color(0xFF334155), height: 16),

                    // 3. Barra de Ação Rápida (Botão "Reexibir Todos" + Alternador Raio-X no 3D)
                    if (hasHidden) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Row(
                          children: [
                            // Botão Principal: Reexibir Todos Novamente
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  controller.restoreAllVisibility();
                                  onAllRestored?.call();
                                  Navigator.of(context).pop();
                                },
                                icon: const Icon(Icons.visibility_rounded, size: 16),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Reexibir Todos'),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Botão/Switch: Prévia Fantasma no 3D (Raio-X)
                            InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                controller.setGhostPreview(!controller.isGhostPreviewActive);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                decoration: BoxDecoration(
                                  color: controller.isGhostPreviewActive
                                      ? const Color(0xFFF59E0B).withValues(alpha: 0.22)
                                      : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: controller.isGhostPreviewActive
                                        ? const Color(0xFFF59E0B).withValues(alpha: 0.60)
                                        : Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      controller.isGhostPreviewActive
                                          ? Icons.remove_red_eye_rounded
                                          : Icons.remove_red_eye_outlined,
                                      size: 16,
                                      color: controller.isGhostPreviewActive
                                          ? const Color(0xFFFBBF24)
                                          : AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Raio-X 3D',
                                      style: TextStyle(
                                        fontFamily: AppTypography.fontFamily,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: controller.isGhostPreviewActive
                                          ? const Color(0xFFFDE68A)
                                          : AppColors.surface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],

                    // 4. Lista dos Elementos Ocultados
                    Flexible(
                      child: hasHidden
                          ? ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                              itemCount: hiddenItems.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final element = hiddenItems[index];
                                return _HiddenElementCard(
                                  metadata: element,
                                  onUnhide: () {
                                    HapticFeedback.lightImpact();
                                    controller.showElement(element.expressID);
                                    if (controller.hiddenCount == 0) {
                                      onAllRestored?.call();
                                      Navigator.of(context).pop();
                                    }
                                  },
                                );
                              },
                            )
                          : _buildEmptyState(context),
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

  /// Exibição quando todos os elementos já foram restaurados
  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 38,
              color: Color(0xFF34D399),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Tudo Visível!',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.surface,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Nenhum elemento está oculto no momento.',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 13,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.surface,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Concluir'),
          ),
        ],
      ),
    );
  }
}

/// Cartão individual estilizado para cada elemento BIM ocultado
class _HiddenElementCard extends StatelessWidget {
  final BimElementMetadata metadata;
  final VoidCallback onUnhide;

  const _HiddenElementCard({
    required this.metadata,
    required this.onUnhide,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          // Ícone da Categoria BIM
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              metadata.categoryIcon,
              size: 18,
              color: const Color(0xFF60A5FA),
            ),
          ),
          const SizedBox(width: 12),

          // Informações do Elemento
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metadata.displayName,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.surface,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '#${metadata.expressID} • ${metadata.friendlyCategory}',
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Botão Tipo Olho: "Visualizar Novamente / Reexibir"
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onUnhide,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.visibility_rounded,
                      size: 14,
                      color: Color(0xFF60A5FA),
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Reexibir',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF93C5FD),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
