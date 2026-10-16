import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../controllers/viewer_3d_controller.dart';

/// BottomSheet para inspeção técnica e exibição detalhada de metadados BIM (Psets).
class BimMetadataBottomSheet extends StatelessWidget {
  final BimElementMetadata metadata;

  const BimMetadataBottomSheet({
    super.key,
    required this.metadata,
  });

  /// Invocador utilitário do BottomSheet modal.
  static Future<void> show({
    required BuildContext context,
    required BimElementMetadata metadata,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BimMetadataBottomSheet(metadata: metadata),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Puxador central (drag handle)
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Cabeçalho da Ficha Técnica
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge da Categoria IFC (Royal Blue #2563EB)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          metadata.friendlyCategory.toUpperCase(),
                          style: AppTypography.badgeLabel.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Título Amigável do Elemento
                      Text(
                        metadata.displayName,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'ExpressID: #${metadata.expressID} • ${metadata.category}',
                        style: AppTypography.bodySmall.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Lista de Propriedades e Conjuntos (Psets)
          Flexible(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                if (metadata.psets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Nenhum conjunto de propriedades (Pset) disponível.',
                        style: AppTypography.bodyMedium,
                      ),
                    ),
                  )
                else
                  ...metadata.psets.entries.map((groupEntry) {
                    return _buildPropertySection(groupEntry.key, groupEntry.value);
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói um bloco de seção para um grupo de propriedades (ex: "Pset_Dimensions")
  Widget _buildPropertySection(String sectionTitle, dynamic sectionContent) {
    final cleanSectionTitle = BimElementMetadata.decodeIfcString(sectionTitle);

    if (sectionContent is Map) {
      final properties = sectionContent.cast<String, dynamic>();

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título da Seção / Pset
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Text(
                cleanSectionTitle,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            const Divider(height: 1),

            // Linhas de Chave / Valor adaptadas para Mobile (rótulo em cima, valor legível embaixo)
            ...properties.entries.map((prop) {
              final cleanKey = BimElementMetadata.decodeIfcString(prop.key);
              final cleanVal = BimElementMetadata.decodeIfcString('${prop.value}');

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cleanKey,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cleanVal,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
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

    // Seção simples com valor direto
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cleanSectionTitle, style: AppTypography.bodySmall),
          const SizedBox(height: 2),
          Text(
            BimElementMetadata.decodeIfcString('$sectionContent'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
