import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/project_model.dart';

/// Card estilizado de exibição de cada projeto BIM cadastrado.
/// Segue o Design System: Fundo Branco (#FFFFFF), Raio de 12px, Sombra leve,
/// Ação Primária em Royal Blue (#2563EB) e Exclusão em Vermelho Alerta (#EF4444).
class ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final VoidCallback onViewPressed;
  final VoidCallback onDeletePressed;

  const ProjectCard({
    super.key,
    required this.project,
    required this.onViewPressed,
    required this.onDeletePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppTheme.borderRadius,
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppTheme.borderRadius,
        child: InkWell(
          borderRadius: AppTheme.borderRadius,
          onTap: onViewPressed,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Topo do card: Ícone indicador e botão de exclusão
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.layers_outlined,
                        color: AppColors.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.name,
                            style: AppTypography.cardTitle.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            project.formattedDate,
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    // Ícone de ação destrutiva (Excluir)
                    IconButton(
                      tooltip: 'Excluir modelo',
                      splashRadius: 20,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.destructive,
                        size: 22,
                      ),
                      onPressed: onDeletePressed,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Seção intermediária: Badges de metadados
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Badge de Formato (.GLB / .IFC)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '.${project.format}',
                        style: AppTypography.badgeLabel.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    // Badge de Tamanho (MB)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        project.formattedSize,
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Botão de Ação Primária: Visualizar (Royal Blue #2563EB)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onViewPressed,
                    icon: const Icon(Icons.view_in_ar_rounded, size: 18),
                    label: const Text('Visualizar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.surface,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: AppTypography.buttonLabel,
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
}
