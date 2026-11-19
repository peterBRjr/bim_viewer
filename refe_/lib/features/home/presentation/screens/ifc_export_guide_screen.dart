import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Guia Prático e Simpático de Exportação IFC para iOS
/// Focado no essencial: 3 níveis práticos (Básico • Médio • Detalhado),
/// parâmetros-chave indispensáveis e dicas rápidas para os principais softwares BIM.
class IfcExportGuideScreen extends StatefulWidget {
  final int initialLevelIndex;

  const IfcExportGuideScreen({
    super.key,
    this.initialLevelIndex = 1,
  });

  @override
  State<IfcExportGuideScreen> createState() => _IfcExportGuideScreenState();
}

class _IfcExportGuideScreenState extends State<IfcExportGuideScreen> {
  late int _selectedLevel;
  late final PageController _pageController;

  static const List<_ExportTierSpec> _tiers = [
    _ExportTierSpec(
      index: 0,
      idKey: 'tier_basico',
      shortTitle: 'Básico',
      emoji: '⚡',
      badgeText: 'NÍVEL 1 • ULTRA LEVE',
      headline: 'Exportação Básica (Máxima Leveza de Hardware)',
      subtitle:
          'Ideal para obras de grande porte, galpões e modelos gigantes que precisam abrir num piscar de olhos no canteiro.',
      accentColor: Color(0xFF10B981), // Emerald
      targetFileSize: '5 MB a 25 MB',
      targetRamUsage: '< 320 MB RAM',
      targetFps: '60 FPS Ultra Fluido',
      visualSummary:
          'Geometria limpa e rápida: pilares, vigas e lajes com medidas exatas para cotas 3D, dispensando parafusos e detalhes secundários pesados.',
      essentialParams: [
        _ParamItem(
          parameter: 'Definição de Vista (MVD)',
          value: 'IFC4 Reference View',
          reason: 'Usa malha leve, reduzindo o arquivo em até 60%.',
        ),
        _ParamItem(
          parameter: 'Nível de Detalhe (LOD)',
          value: 'Baixo (Low)',
          reason: 'Mantém as faces planas perfeitas e simplifica miudezas.',
        ),
        _ParamItem(
          parameter: 'Filtro de Elementos',
          value: 'Apenas elementos visíveis',
          reason: 'Oculte mobiliário e miudezas antes de exportar.',
        ),
        _ParamItem(
          parameter: 'Propriedades (Psets)',
          value: 'IFC Common Psets + Quantitativos',
          reason: 'Evita exportar milhares de dados de texto inúteis.',
        ),
      ],
      softwareTips: [
        _SoftwareTip(
          name: 'Autodesk Revit',
          icon: Icons.layers_rounded,
          tip:
              'Em File > Export > IFC: escolha "IFC4 Reference View" e na aba Level of Detail selecione "Low".',
        ),
        _SoftwareTip(
          name: 'Tekla Structures',
          icon: Icons.precision_manufacturing_rounded,
          tip:
              'Use "Surface Geometry" e desmarque parafusos (Bolts) e armaduras para o arquivo ficar super leve.',
        ),
        _SoftwareTip(
          name: 'Archicad / Eberick',
          icon: Icons.domain_rounded,
          tip:
              'Selecione "Apenas Núcleo Estrutural" e filtre vegetações e móveis.',
        ),
      ],
    ),
    _ExportTierSpec(
      index: 1,
      idKey: 'tier_medio',
      shortTitle: 'Médio',
      emoji: '⭐',
      badgeText: 'NÍVEL 2 • EQUILÍBRIO RECOMENDADO',
      headline: 'Exportação Média (Diferença Nítida a Olho Nu)',
      subtitle:
          'O perfil ideal para a grande maioria das obras: visual nítido de perfis de aço, chapas de ligação e caixilharia a 60 FPS.',
      accentColor: Color(0xFF2563EB), // Royal Blue
      targetFileSize: '20 MB a 65 MB',
      targetRamUsage: '~520 MB RAM',
      targetFps: '60 FPS Estável',
      visualSummary:
          'Diferença nítida a olho nu: contornos fiéis em perfis W/HP, chapas de ligação (gussets) e esquadrias bem definidas sem travar o celular.',
      essentialParams: [
        _ParamItem(
          parameter: 'Definição de Vista (MVD)',
          value: 'IFC2x3 Coordination View 2.0 ou IFC4',
          reason: 'Arestas vivas e excelente compatibilidade openBIM.',
        ),
        _ParamItem(
          parameter: 'Nível de Detalhe (LOD)',
          value: 'Médio (Medium)',
          reason: 'Curvas e conexões nítidas sem gerar excesso de polígonos.',
        ),
        _ParamItem(
          parameter: 'Chapas & Conexões',
          value: 'Ativar chapas e caixilhos',
          reason: 'Mostra chapas estruturais e esquadrias, omitindo porcas.',
        ),
        _ParamItem(
          parameter: 'Materiais & Cores',
          value: 'Ativar Material Psets',
          reason: 'Permite cores PBR realistas para aço, concreto e vidro.',
        ),
      ],
      softwareTips: [
        _SoftwareTip(
          name: 'Autodesk Revit',
          icon: Icons.layers_rounded,
          tip:
              'Deixe a vista 3D em nível Médio. No IFC Setup, marque "IFC2x3 Coordination View" e Level of Detail "Medium".',
        ),
        _SoftwareTip(
          name: 'Tekla Structures',
          icon: Icons.precision_manufacturing_rounded,
          tip:
              'Ative "Coordination View 2.0" com chapas (Plates) marcadas, mantendo parafusos desmarcados.',
        ),
        _SoftwareTip(
          name: 'Archicad / Eberick',
          icon: Icons.domain_rounded,
          tip:
              'Exporte estrutura e arquitetura completas com materiais, filtrando apenas carros e árvores.',
        ),
      ],
    ),
    _ExportTierSpec(
      index: 2,
      idKey: 'tier_detalhado',
      shortTitle: 'Detalhado (iOS)',
      emoji: '💎',
      badgeText: 'NÍVEL 3 • ALTA DEFINIÇÃO IPHONE',
      headline: 'Exportação Detalhada (Teto Gráfico iOS / Apple Metal)',
      subtitle:
          'Fidelidade máxima para apresentações executivas e inspeção minuciosa, calibrada para a GPU dos chips Apple sem exceder a memória.',
      accentColor: Color(0xFF0284C7), // Sky Blue
      targetFileSize: '50 MB a 120 MB (Teto Seguro iOS)',
      targetRamUsage: '~850 MB a 1.1 GB RAM',
      targetFps: '60 FPS / Apple Metal',
      visualSummary:
          'Fidelidade executiva completa: raios de perfis laminados, chumbadores, louças sanitárias e caixilharia detalhada com sombras suaves.',
      essentialParams: [
        _ParamItem(
          parameter: 'Teto Seguro de Arquivo',
          value: 'Até 120 MB por modelo',
          reason: 'Garante navegação fluida sem atingir o limite de memória do iOS.',
        ),
        _ParamItem(
          parameter: 'Nível de Detalhe (LOD)',
          value: 'Alto (Fine / High)',
          reason: 'Perfeito para blocos, setores ou pavimentos específicos.',
        ),
        _ParamItem(
          parameter: 'Divisão por Setor',
          value: 'Dividir se passar de 120 MB',
          reason: 'Em megaobras, separe estrutura metálica de instalações MEP.',
        ),
        _ParamItem(
          parameter: 'Propriedades openBIM',
          value: 'Psets Executivos Completos',
          reason: 'Habilita filtros de pavimentos e quantitativos precisos.',
        ),
      ],
      softwareTips: [
        _SoftwareTip(
          name: 'Autodesk Revit',
          icon: Icons.layers_rounded,
          tip:
              'Configure a vista 3D no nível "Fine" (Alto) e use Level of Detail "Medium" para o prédio todo ou "High" por setor.',
        ),
        _SoftwareTip(
          name: 'Tekla Structures',
          icon: Icons.precision_manufacturing_rounded,
          tip:
              'Ative perfis, chapas e chumbadores; use filtros por Fase de Montagem se a estrutura for muito extensa.',
        ),
        _SoftwareTip(
          name: 'Dica Especial (.GLB)',
          icon: Icons.auto_fix_high_rounded,
          tip:
              'O app também aceita arquivos 3D .GLB, que carregam até 5x mais rápido no iPhone!',
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedLevel = widget.initialLevelIndex.clamp(0, 2);
    _pageController = PageController(initialPage: _selectedLevel);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectLevel(int index) {
    if (_selectedLevel == index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedLevel = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeSpec = _tiers[_selectedLevel];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Guia de Exportação IFC',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Seletor Superior dos 3 Níveis
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                border: Border(
                  bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Row(
                  children: _tiers.map((tier) {
                    final isSelected = tier.index == _selectedLevel;
                    return Expanded(
                      child: GestureDetector(
                        key: ValueKey('export_toggle_${tier.idKey}'),
                        onTap: () => _selectLevel(tier.index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? tier.accentColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: tier.accentColor.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                tier.emoji,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  tier.shortTitle,
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 12.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF94A3B8),
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
                  }).toList(),
                ),
              ),
            ),

            // Conteúdo em Carrossel Horizontal
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _tiers.length,
                onPageChanged: (index) {
                  if (_selectedLevel != index) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedLevel = index);
                  }
                },
                itemBuilder: (context, index) {
                  return _buildTierContent(_tiers[index]);
                },
              ),
            ),

            // Rodapé com Paginação
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _selectedLevel > 0
                        ? () => _selectLevel(_selectedLevel - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    label: const Text('Anterior'),
                  ),
                  Row(
                    children: List.generate(_tiers.length, (i) {
                      final active = i == _selectedLevel;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 20 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: active
                              ? activeSpec.accentColor
                              : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  TextButton.icon(
                    onPressed: _selectedLevel < _tiers.length - 1
                        ? () => _selectLevel(_selectedLevel + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    label: const Text('Próximo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierContent(_ExportTierSpec tier) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        // 1. Card Principal: Resumo e Métricas
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tier.accentColor.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: tier.accentColor.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: tier.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      tier.badgeText,
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: tier.accentColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tier.headline,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tier.subtitle,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),

              // Pílulas de Metas de Desempenho
              Row(
                children: [
                  _buildMetricPill(
                    icon: Icons.sd_storage_outlined,
                    label: 'Tamanho Ideal',
                    value: tier.targetFileSize,
                    color: tier.accentColor,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricPill(
                    icon: Icons.memory_rounded,
                    label: 'Memória iOS',
                    value: tier.targetRamUsage,
                    color: tier.accentColor,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricPill(
                    icon: Icons.speed_rounded,
                    label: 'Fluidez',
                    value: tier.targetFps,
                    color: tier.accentColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Visual a olho nu
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.visibility_rounded,
                      size: 16,
                      color: tier.accentColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tier.visualSummary,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12,
                          color: AppColors.textDark,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Parâmetros Essenciais
        _buildSectionTitle(
          icon: Icons.tune_rounded,
          title: 'Configurações Essenciais',
          color: tier.accentColor,
        ),
        const SizedBox(height: 8),
        ...tier.essentialParams.map(
          (param) => _buildParamRow(param, tier.accentColor),
        ),
        const SizedBox(height: 14),

        // 3. Dicas Rápidas nos Softwares
        _buildSectionTitle(
          icon: Icons.desktop_windows_rounded,
          title: 'No seu software BIM',
          color: tier.accentColor,
        ),
        const SizedBox(height: 8),
        ...tier.softwareTips.map(
          (software) => _buildSoftwareRow(software, tier.accentColor),
        ),
        const SizedBox(height: 14),

        // 4. Como Passar para o Celular
        _buildQuickTransferCard(),
      ],
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildParamRow(_ParamItem item, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                item.parameter,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.value,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            item.reason,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 11.5,
              color: AppColors.textDark,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoftwareRow(_SoftwareTip software, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(software.icon, size: 16, color: accentColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  software.name,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  software.tip,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTransferCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.phone_iphone_rounded,
                size: 16,
                color: Color(0xFF38BDF8),
              ),
              SizedBox(width: 8),
              Text(
                'Como passar para o iPhone / iPad',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF38BDF8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '1. Exporte o arquivo .ifc no seu computador.\n'
            '2. Envie por WhatsApp, AirDrop ou iCloud e salve no app Arquivos.\n'
            '3. No app, toque no botão "Adicionar Projeto" para importar!',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 11.5,
              color: Color(0xFFCBD5E1),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportTierSpec {
  final int index;
  final String idKey;
  final String shortTitle;
  final String emoji;
  final String badgeText;
  final String headline;
  final String subtitle;
  final Color accentColor;
  final String targetFileSize;
  final String targetRamUsage;
  final String targetFps;
  final String visualSummary;
  final List<_ParamItem> essentialParams;
  final List<_SoftwareTip> softwareTips;

  const _ExportTierSpec({
    required this.index,
    required this.idKey,
    required this.shortTitle,
    required this.emoji,
    required this.badgeText,
    required this.headline,
    required this.subtitle,
    required this.accentColor,
    required this.targetFileSize,
    required this.targetRamUsage,
    required this.targetFps,
    required this.visualSummary,
    required this.essentialParams,
    required this.softwareTips,
  });
}

class _ParamItem {
  final String parameter;
  final String value;
  final String reason;

  const _ParamItem({
    required this.parameter,
    required this.value,
    required this.reason,
  });
}

class _SoftwareTip {
  final String name;
  final IconData icon;
  final String tip;

  const _SoftwareTip({
    required this.name,
    required this.icon,
    required this.tip,
  });
}
