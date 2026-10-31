import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../controllers/viewer_3d_controller.dart';

/// BottomSheet para inspeção técnica e exibição detalhada de metadados BIM (Psets).
/// Otimizado como "Maquete de Bolso": traduz parâmetros IFC complexos em linguagem
/// clara de engenharia e obra civil, com unidades métricas e cards de alto contraste.
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
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x260F172A),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Puxador central (drag handle)
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          // Cabeçalho da Ficha Técnica (Maquete de Bolso)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges da Categoria IFC, Família e Composição Hierárquica
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.25),
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
                          if (metadata.familyName != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.border.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                metadata.familyName!.toUpperCase(),
                                style: AppTypography.badgeLabel.copyWith(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          if (metadata.isComposite)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.hub_outlined,
                                    size: 11,
                                    color: Color(0xFF059669),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'COMPOSTO (${metadata.subIds.length} PARTES)',
                                    style: AppTypography.badgeLabel.copyWith(
                                      color: const Color(0xFF059669),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Título Limpo do Elemento / Tipo
                      Text(
                        metadata.cleanTitle,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'ExpressID: #${metadata.expressID} • Classe IFC: ${metadata.category}',
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

          // Grid de Resumo Rápido para Obra (Hero Metrics)
          _buildHeroMetricsCards(metadata),

          const Divider(height: 1),

          // Lista de Propriedades e Conjuntos (Psets) com Rótulos Explicativos
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

  /// Grid de Resumo Rápido com métricas principais (Área, Volume, Inclinação)
  Widget _buildHeroMetricsCards(BimElementMetadata metadata) {
    final metrics = metadata.keyMetrics;
    if (metrics.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 14, color: AppColors.accent),
              const SizedBox(width: 4),
              Text(
                'RESUMO RÁPIDO PARA CANTEIRO',
                style: AppTypography.badgeLabel.copyWith(
                  color: AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: metrics.entries.take(4).map((entry) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.value,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Constrói um bloco de seção para um grupo de propriedades (ex: "Pset_Dimensions")
  Widget _buildPropertySection(String sectionTitle, dynamic sectionContent) {
    final cleanSectionTitle = formatPsetName(sectionTitle);

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
            // Título Amigável da Seção / Pset
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Row(
                children: [
                  Expanded(
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
                  if (sectionTitle.startsWith('Pset_'))
                    Text(
                      sectionTitle,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 10,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Linhas de Chave / Valor adaptadas para Mobile com rótulo claro e nome do parâmetro IFC
            ...properties.entries.map((prop) {
              final rawKey = prop.key;
              final friendlyKey = formatPropKey(rawKey);
              final friendlyVal = formatPropValue(rawKey, prop.value);
              final isBoolean = friendlyVal.startsWith('Sim') || friendlyVal.startsWith('Não');

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rótulo amigável + Sub-rótulo com nome técnico IFC
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            friendlyKey,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          if (friendlyKey != rawKey && !rawKey.startsWith('Pset_')) ...[
                            const SizedBox(height: 1),
                            Text(
                              'IFC: $rawKey',
                              style: const TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Valor com Unidade e Destaque Visual
                    Expanded(
                      flex: 5,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: isBoolean
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: friendlyVal.startsWith('Sim')
                                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                      : const Color(0xFFEF4444).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  friendlyVal,
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: friendlyVal.startsWith('Sim')
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFDC2626),
                                  ),
                                ),
                              )
                            : Text(
                                friendlyVal,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
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

  /// Traduz nomes de PropertySets em português de engenharia
  static String formatPsetName(String rawName) {
    final clean = BimElementMetadata.decodeIfcString(rawName).trim();
    final lower = clean.toLowerCase();
    if (lower == 'pset_roofcommon') return '📐 Parâmetros do Telhado';
    if (lower == 'pset_wallcommon') return '🧱 Parâmetros da Parede';
    if (lower == 'pset_slabcommon') return '🏗️ Parâmetros da Laje / Piso';
    if (lower == 'pset_quantitytakeoff') return '📊 Quantitativos & Medições';
    if (lower.contains('reinforcement')) return '⚙️ Armadura & Estrutura';
    if (lower == 'pset_doorcommon') return '🚪 Parâmetros da Porta';
    if (lower == 'pset_windowcommon') return '🪟 Parâmetros da Janela';
    if (lower == 'pset_columncommon') return '🏛️ Parâmetros do Pilar';
    if (lower == 'pset_beamcommon') return '📏 Parâmetros da Viga';
    if (lower == 'pset_buildingstoreycommon') return '🏢 Dados do Pavimento / Nível';
    if (lower == 'pset_buildingcommon') return '🏢 Dados Globais do Edifício';
    if (lower == 'propriedades gerais') return '🏷️ Identificação BIM & openBIM';
    if (lower == 'composição do elemento') return '🧩 Composição & Partes Físicas';
    if (lower == 'dados técnicos') return '⚙️ Especificações Técnicas';
    return clean.replaceAll('Pset_', '').replaceAll('Common', ' (Geral)');
  }

  /// Traduz chaves de parâmetros IFC em termos acessíveis para obra
  static String formatPropKey(String rawKey) {
    final clean = BimElementMetadata.decodeIfcString(rawKey).trim();
    final lower = clean.toLowerCase();
    switch (lower) {
      case 'totalarea':
        return 'Área Total de Superfície';
      case 'projectedarea':
        return 'Área Projetada Horizontal';
      case 'grossarea':
        return 'Área Bruta';
      case 'netarea':
        return 'Área Líquida';
      case 'pitchangle':
        return 'Inclinação (Caimento)';
      case 'thermaltransmittance':
        return 'Transmitância Térmica (U)';
      case 'reference':
        return 'Tipo / Referência do Material';
      case 'loadbearing':
        return 'Função Estrutural (Carga)';
      case 'isexternal':
        return 'Elemento Externo (Fachada)';
      case 'firerating':
        return 'Resistência ao Fogo';
      case 'combustible':
        return 'Material Combustível';
      case 'compartmentation':
        return 'Compartimentação Corta-Fogo';
      case 'height':
        return 'Altura Total';
      case 'width':
        return 'Espessura / Largura';
      case 'length':
        return 'Comprimento Linear';
      case 'volume':
        return 'Volume Total';
      case 'netvolume':
        return 'Volume Líquido';
      case 'grossvolume':
        return 'Volume Bruto';
      case 'perimeter':
        return 'Perímetro';
      case 'aboveground':
        return 'Acima do Nível do Solo';
      case 'numberofstoreys':
        return 'Quantidade de Pavimentos';
      case 'globalid':
        return 'GUID Universal (openBIM)';
      case 'expressid':
        return 'Linha / ID no Arquivo IFC';
      case 'tag':
        return 'ID Nativo do Revit';
      case 'categoria ifc':
        return 'Classe IFC (buildingSMART)';
      case 'nome':
        return 'Nome da Família / Tipo';
      case 'total de partes':
        return 'Total de Peças Integradas';
      case 'estrutura':
        return 'Tipo de Montagem';
      case 'ids dos componentes':
      case 'ids das peças':
        return 'IDs das Peças Agrupadas';
      default:
        return clean;
    }
  }

  /// Formata valores IFC em padrão civil amigável com unidades
  static String formatPropValue(String rawKey, dynamic rawVal) {
    if (rawVal == null) return 'Não especificado';
    var valStr = BimElementMetadata.decodeIfcString('$rawVal').trim();

    // Booleanos IFC (.T. / .F. / .U. / true / false)
    if (valStr == '.T.' || valStr.toLowerCase() == 'true') return 'Sim';
    if (valStr == '.F.' || valStr.toLowerCase() == 'false') return 'Não';
    if (valStr == '.U.' || valStr.toLowerCase() == 'unknown') return 'Não informado';

    final lowerKey = rawKey.toLowerCase();
    final numVal = double.tryParse(valStr.replaceAll(',', '.'));

    if (numVal != null) {
      if (lowerKey.contains('totalarea') ||
          lowerKey.contains('projectedarea') ||
          lowerKey.contains('grossarea') ||
          lowerKey.contains('netarea') ||
          lowerKey == 'area') {
        return '${numVal.toStringAsFixed(2).replaceAll('.', ',')} m²';
      }
      if (lowerKey.contains('volume')) {
        return '${numVal.toStringAsFixed(2).replaceAll('.', ',')} m³';
      }
      if (lowerKey.contains('pitch') || lowerKey.contains('angle') || lowerKey.contains('inclinacao')) {
        return '${numVal.toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ',')}°';
      }
      if (lowerKey.contains('height') ||
          lowerKey.contains('length') ||
          lowerKey.contains('width') ||
          lowerKey.contains('perimeter')) {
        if (numVal >= 100) {
          return '${(numVal / 1000).toStringAsFixed(2).replaceAll('.', ',')} m (${numVal.toStringAsFixed(0)} mm)';
        }
        return '${numVal.toStringAsFixed(2).replaceAll('.', ',')} m';
      }
      if (lowerKey.contains('thermal')) {
        return '${numVal.toStringAsFixed(2).replaceAll('.', ',')} W/(m²·K)';
      }
    }

    return valStr;
  }
}
