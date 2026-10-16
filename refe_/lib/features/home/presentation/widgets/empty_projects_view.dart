import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/app_theme.dart';

/// Componente visual amigável exibido quando não há projetos cadastrados na aplicação.
class EmptyProjectsView extends StatelessWidget {
  /// Callback disparado quando o usuário clica no botão de ação principal
  final VoidCallback onImportPressed;

  const EmptyProjectsView({
    super.key,
    required this.onImportPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Container visual com ícone técnico em destaque
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.border,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.view_in_ar_rounded,
                  size: 48,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 28),

              // Título principal do Empty State
              const Text(
                'Nenhum projeto BIM cadastrado',
                style: AppTypography.dashboardTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Mensagem explicativa técnica com foco em operação offline
              const Text(
                'Seu repositório local está pronto para operação em canteiro de obras. '
                'Importe modelos 3D para visualização offline de alto desempenho.',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Badges dos formatos suportados (.GLB, .GLTF, .IFC)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: const [
                  _FormatBadge(label: 'GLB'),
                  _FormatBadge(label: 'GLTF'),
                  _FormatBadge(label: 'IFC'),
                ],
              ),
              const SizedBox(height: 32),

              // Botão de ação principal estilizado com AppColors.accent
              ElevatedButton.icon(
                onPressed: onImportPressed,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Importar Primeiro Modelo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.borderRadius,
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge auxiliar para exibição de formatos técnicos aceitos
class _FormatBadge extends StatelessWidget {
  final String label;

  const _FormatBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '.$label',
        style: AppTypography.badgeLabel.copyWith(
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
