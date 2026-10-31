import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../controllers/viewer_3d_controller.dart';

/// Barra de ações inferior flutuante inspirada no estilo moderno e clean do app Nubank.
/// Exibe uma cápsula escura minimalista com 3 opções em ícones e círculo roxo ativo.
class NubankBimTabBar extends StatefulWidget {
  final BimElementMetadata metadata;
  final bool isIsolated;
  final VoidCallback onViewBimData;
  final VoidCallback onHideElement;
  final VoidCallback onIsolateElement;
  final VoidCallback onClose;

  const NubankBimTabBar({
    super.key,
    required this.metadata,
    required this.isIsolated,
    required this.onViewBimData,
    required this.onHideElement,
    required this.onIsolateElement,
    required this.onClose,
  });

  @override
  State<NubankBimTabBar> createState() => _NubankBimTabBarState();
}

class _NubankBimTabBarState extends State<NubankBimTabBar> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  // Índice da ação ativa (0: Dados BIM, 1: Ocultar, 2: Isolar)
  late int _activeIndex;

  @override
  void initState() {
    super.initState();
    _activeIndex = widget.isIsolated ? 2 : 0;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant NubankBimTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isIsolated != oldWidget.isIsolated) {
      if (widget.isIsolated) {
        _activeIndex = 2;
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleActionTap(int index, VoidCallback action) {
    HapticFeedback.selectionClick();
    setState(() {
      _activeIndex = index;
    });

    // Pequeno delay para percepção da transição ativa do círculo roxo
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) {
        action();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Tom azul característico do Design System (Royal Blue #2563EB)
    const Color activeBlue = AppColors.accent;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Mini Chip informativo e discreto com nome do elemento e botão fechar
                _buildElementMiniChip(activeBlue),

                const SizedBox(height: 8),

                // 2. TabBar Flutuante em Cápsula moderna e clean com destaque azul
                ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF18181B).withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: activeBlue.withValues(alpha: 0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Opção 1: Dados BIM / Ficha técnica
                          _NubankIconButton(
                            tooltip: 'Dados BIM',
                            icon: _activeIndex == 0 ? Icons.info_rounded : Icons.info_outline_rounded,
                            isActive: _activeIndex == 0,
                            activeColor: activeBlue,
                            onTap: () => _handleActionTap(0, widget.onViewBimData),
                          ),
                          const SizedBox(width: 8),

                          // Opção 2: Ocultar Elemento
                          _NubankIconButton(
                            tooltip: 'Ocultar elemento',
                            icon: _activeIndex == 1
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_off_outlined,
                            isActive: _activeIndex == 1,
                            activeColor: activeBlue,
                            onTap: () => _handleActionTap(1, widget.onHideElement),
                          ),
                          const SizedBox(width: 8),

                          // Opção 3: Isolar Elemento (ou Restaurar se já isolado)
                          _NubankIconButton(
                            tooltip: widget.isIsolated ? 'Restaurar vista' : 'Isolar elemento',
                            icon: widget.isIsolated
                                ? Icons.all_inclusive_rounded
                                : (_activeIndex == 2
                                    ? Icons.filter_center_focus_rounded
                                    : Icons.filter_center_focus_outlined),
                            isActive: _activeIndex == 2 || widget.isIsolated,
                            activeColor: activeBlue,
                            onTap: () => _handleActionTap(2, widget.onIsolateElement),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Mini Chip elegante flutuante com a identificação do elemento selecionado e botão fechar
  Widget _buildElementMiniChip(Color accentColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B).withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.metadata.categoryIcon,
                size: 13,
                color: const Color(0xFF60A5FA),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.metadata.displayName,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.surface,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.metadata.isComposite) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '${widget.metadata.subIds.length} partes',
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF34D399),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onClose();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão de ícone individual com estilo Nubank:
/// Quando ativo, exibe círculo roxo vibrante; quando inativo, ícone clean e translúcido.
class _NubankIconButton extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _NubankIconButton({
    required this.tooltip,
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  State<_NubankIconButton> createState() => _NubankIconButtonState();
}

class _NubankIconButtonState extends State<_NubankIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.isActive;

    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _isPressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: active ? widget.activeColor : Colors.transparent,
              shape: BoxShape.circle,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: widget.activeColor.withValues(alpha: 0.40),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                widget.icon,
                size: 22,
                color: active ? Colors.white : const Color(0xFFCBD5E1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
