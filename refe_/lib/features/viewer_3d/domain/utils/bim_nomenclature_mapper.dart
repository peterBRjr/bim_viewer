import 'package:flutter/material.dart';
import '../models/bim_element_metadata.dart';

/// Propriedade IFC padronizada conforme boas práticas openBIM (ISO 16739 / buildingSMART / ABNT NBR 15965).
class StandardizedBimProperty {
  final String displayLabel;
  final String canonicalIfcKey;
  final String formattedValue;
  final bool isBoolean;
  final bool booleanTrue;

  const StandardizedBimProperty({
    required this.displayLabel,
    required this.canonicalIfcKey,
    required this.formattedValue,
    this.isBoolean = false,
    this.booleanTrue = false,
  });
}

/// Seção de propriedades padronizada para exibição técnica em obra.
class StandardizedBimSection {
  final String displayTitle;
  final String rawPsetName;
  final IconData icon;
  final List<StandardizedBimProperty> properties;

  const StandardizedBimSection({
    required this.displayTitle,
    required this.rawPsetName,
    required this.icon,
    required this.properties,
  });
}

/// Utilitário de padronização semântica e nomenclatura openBIM para propriedades importadas de arquivos `.IFC`.
abstract final class BimNomenclatureMapper {
  /// Converte todos os PropertySets (`psets`) brutos de um elemento em seções padronizadas e legíveis.
  static List<StandardizedBimSection> normalizeAllSections(
    Map<String, dynamic> psets, {
    String searchQuery = '',
  }) {
    final List<StandardizedBimSection> sections = [];
    final q = searchQuery.trim().toLowerCase();

    // Ordem semântica recomendada em fichas BIM executivas:
    // 1. Geometria / Quantitativos -> 2. Materiais -> 3. Tipo -> 4. Psets Common -> 5. Identificação Geral
    final entries = psets.entries.toList()
      ..sort((a, b) => _sectionPriority(a.key).compareTo(_sectionPriority(b.key)));

    for (final entry in entries) {
      final rawSection = entry.key;
      final content = entry.value;
      final sectionMeta = formatSectionHeader(rawSection);

      final List<StandardizedBimProperty> normalizedProps = [];

      if (content is Map) {
        for (final propEntry in content.entries) {
          final rawKey = propEntry.key.toString();
          final rawVal = propEntry.value;
          if (rawVal == null) continue;
          final rawValStr = BimElementMetadata.decodeIfcString('$rawVal').trim();
          if (rawValStr.isEmpty || rawValStr == 'N/A' || rawValStr == 'null') continue;

          final label = formatPropertyKey(rawKey);
          final formattedVal = formatPropertyValue(rawKey, rawVal);
          final isBool = formattedVal == 'Sim' || formattedVal == 'Não';

          if (q.isNotEmpty) {
            final matches = label.toLowerCase().contains(q) ||
                rawKey.toLowerCase().contains(q) ||
                formattedVal.toLowerCase().contains(q) ||
                sectionMeta.title.toLowerCase().contains(q);
            if (!matches) continue;
          }

          normalizedProps.add(
            StandardizedBimProperty(
              displayLabel: label,
              canonicalIfcKey: rawKey,
              formattedValue: formattedVal,
              isBoolean: isBool,
              booleanTrue: formattedVal == 'Sim',
            ),
          );
        }
      } else if (content != null) {
        final formattedVal = formatPropertyValue(rawSection, content);
        if (q.isEmpty ||
            sectionMeta.title.toLowerCase().contains(q) ||
            formattedVal.toLowerCase().contains(q)) {
          normalizedProps.add(
            StandardizedBimProperty(
              displayLabel: sectionMeta.title,
              canonicalIfcKey: rawSection,
              formattedValue: formattedVal,
            ),
          );
        }
      }

      if (normalizedProps.isNotEmpty) {
        sections.add(
          StandardizedBimSection(
            displayTitle: sectionMeta.title,
            rawPsetName: BimElementMetadata.decodeIfcString(rawSection).trim(),
            icon: sectionMeta.icon,
            properties: normalizedProps,
          ),
        );
      }
    }

    return sections;
  }

  static int _sectionPriority(String rawName) {
    final l = rawName.toLowerCase();
    if (l.contains('geometria') || l.contains('quantity') || l.startsWith('qto_') || l.contains('basequantities') || l.contains('dimens')) {
      return 1;
    }
    if (l.contains('materi')) return 2;
    if (l.contains('tipo') || l.contains('type')) return 3;
    if (l.startsWith('pset_')) return 4;
    if (l.contains('composi')) return 5;
    if (l.contains('propriedades gerais') || l.contains('identity')) return 6;
    return 5;
  }

  /// Traduz o nome do PropertySet IFC para nomenclatura técnica padronizada (ABNT NBR 15965 / buildingSMART).
  static ({String title, IconData icon}) formatSectionHeader(String rawName) {
    final clean = BimElementMetadata.decodeIfcString(rawName).trim();
    final lower = clean.toLowerCase();

    if (lower.contains('geometria física 3d')) {
      return (title: 'Dimensões Físicas & Cotas (3D)', icon: Icons.straighten_rounded);
    }
    if (lower.contains('materiais e camadas') || lower.contains('materials and finishes')) {
      return (title: 'Materiais & Camadas Construtivas', icon: Icons.layers_rounded);
    }
    if (lower.contains('especificação de tipo')) {
      return (title: 'Catálogo de Tipo (IfcTypeObject)', icon: Icons.category_rounded);
    }
    if (lower == 'pset_wallcommon') {
      return (title: 'Desempenho Técnico da Parede', icon: Icons.view_week_rounded);
    }
    if (lower == 'pset_windowcommon') {
      return (title: 'Especificações da Esquadria (Janela)', icon: Icons.window_rounded);
    }
    if (lower == 'pset_doorcommon') {
      return (title: 'Especificações da Esquadria (Porta)', icon: Icons.meeting_room_rounded);
    }
    if (lower == 'pset_slabcommon') {
      return (title: 'Desempenho da Laje / Piso', icon: Icons.view_compact_alt_rounded);
    }
    if (lower == 'pset_roofcommon') {
      return (title: 'Especificações da Cobertura / Telhado', icon: Icons.roofing_rounded);
    }
    if (lower == 'pset_beamcommon') {
      return (title: 'Parâmetros Estruturais da Viga', icon: Icons.horizontal_rule_rounded);
    }
    if (lower == 'pset_columncommon') {
      return (title: 'Parâmetros Estruturais do Pilar', icon: Icons.view_column_rounded);
    }
    if (lower == 'pset_staircommon') {
      return (title: 'Parâmetros de Circulação (Escada)', icon: Icons.stairs_rounded);
    }
    if (lower == 'pset_railingcommon') {
      return (title: 'Parâmetros de Guarda-Corpo', icon: Icons.fence_rounded);
    }
    if (lower == 'pset_quantitytakeoff' || lower.startsWith('qto_') || lower.contains('basequantities')) {
      return (title: 'Quantitativos Oficiais (Qto openBIM)', icon: Icons.calculate_rounded);
    }
    if (lower.contains('reinforcement')) {
      return (title: 'Armadura & Detalhamento Estrutural', icon: Icons.grid_4x4_rounded);
    }
    if (lower == 'constraints' || lower == 'restrições') {
      return (title: 'Restrições & Vínculos de Nível', icon: Icons.vertical_align_center_rounded);
    }
    if (lower == 'dimensions' || lower == 'cotas') {
      return (title: 'Cotas & Geometria Paramétrica', icon: Icons.aspect_ratio_rounded);
    }
    if (lower == 'construction' || lower == 'construção') {
      return (title: 'Método Construtivo', icon: Icons.construction_rounded);
    }
    if (lower == 'phasing' || lower == 'fases') {
      return (title: 'Planejamento & Fases de Obra (4D)', icon: Icons.schedule_rounded);
    }
    if (lower == 'structural' || lower == 'estrutural') {
      return (title: 'Análise & Função Estrutural', icon: Icons.architecture_rounded);
    }
    if (lower == 'propriedades gerais' || lower == 'identity data' || lower == 'dados de identidade') {
      return (title: 'Identificação & Rastreabilidade openBIM', icon: Icons.qr_code_2_rounded);
    }
    if (lower == 'composição do elemento') {
      return (title: 'Montagem & Subcomponentes BIM', icon: Icons.hub_rounded);
    }

    // Humaniza nomes em PascalCase/underscore (ex: "Pset_ManufacturerTypeInformation" -> "Manufacturer Type Information")
    var humanized = clean
        .replaceFirst(RegExp(r'^Pset_', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^Qto_', caseSensitive: false), 'Quantitativos: ')
        .replaceAll('Common', ' (Padrão)')
        .replaceAll('_', ' ');
    humanized = humanized.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    return (title: humanized.trim(), icon: Icons.tune_rounded);
  }

  /// Padroniza chaves de atributos IFC (camelCase / PascalCase / Inglês Técnico) para nomenclatura clara de engenharia.
  static String formatPropertyKey(String rawKey) {
    final clean = BimElementMetadata.decodeIfcString(rawKey).trim();
    final lower = clean.toLowerCase().replaceAll('_', '').replaceAll(' ', '');

    switch (lower) {
      // Identificação e Classificação
      case 'expressid':
        return 'Código Interno IFC (ExpressID)';
      case 'globalid':
        return 'Identificador Global Único (GUID)';
      case 'nome':
      case 'name':
        return 'Designação do Elemento';
      case 'categoriaifc':
      case 'ifccategory':
        return 'Classe Normativa (buildingSMART)';
      case 'tag':
      case 'mark':
        return 'Marca / Tag de Projeto';
      case 'typemark':
        return 'Marca de Tipo (Catálogo)';
      case 'objecttype':
        return 'Família / Subtipo do Objeto';
      case 'predefinedtype':
        return 'Subclasse Predefinida IFC';
      case 'typename':
        return 'Especificação de Tipo (Família)';
      case 'typeclass':
        return 'Entidade de Tipo IFC';
      case 'elementtype':
        return 'Código de Tipo Construtivo';
      case 'applicableoccurrence':
        return 'Ocorrência Aplicável';
      case 'constructiontype':
        return 'Sistema / Tipologia Construtiva';
      case 'operationtype':
        return 'Modo de Abertura / Operação';
      case 'description':
      case 'descrição':
        return 'Descrição Técnica';
      case 'reference':
        return 'Referência de Catálogo / Tipo';
      case 'assemblycode':
      case 'códigodeconjunto':
        return 'Código de Composição (Uniformat)';
      case 'assemblydescription':
        return 'Descrição da Composição';
      case 'omniclassnumber':
        return 'Código de Classificação OmniClass';
      case 'omniclasstitle':
        return 'Título OmniClass';

      // Dimensões e Quantitativos (Qto)
      case 'length':
      case 'nominallength':
      case 'comprimento':
        return 'Comprimento Linear';
      case 'width':
      case 'nominalwidth':
      case 'espessura':
      case 'largura':
        return 'Largura / Espessura';
      case 'height':
      case 'nominalheight':
      case 'unconnectedheight':
      case 'altura':
      case 'alturadesconectada':
        return 'Altura Livre / Pé-Direito';
      case 'overallheight':
        return 'Altura Total do Vão';
      case 'overallwidth':
        return 'Largura Total do Vão';
      case 'sillheight':
      case 'alturadopeitoril':
        return 'Altura do Peitoril';
      case 'headheight':
      case 'alturadaverga':
        return 'Altura da Verga';
      case 'depth':
      case 'profundidade':
        return 'Profundidade';
      case 'perimeter':
      case 'perímetro':
        return 'Perímetro';
      case 'baseelevation':
        return 'Cota Altimétrica de Base';
      case 'topelevation':
        return 'Cota Altimétrica de Topo';
      case 'baseconstraint':
      case 'restriçãodabase':
        return 'Nível de Base (Vínculo)';
      case 'baseoffset':
      case 'deslocamentodabase':
        return 'Deslocamento da Base (Offset)';
      case 'topconstraint':
      case 'restriçãosuperior':
        return 'Nível de Topo (Vínculo)';
      case 'topoffset':
      case 'deslocamentosuperior':
        return 'Deslocamento Superior (Offset)';
      case 'area':
      case 'totalarea':
        return 'Área Total de Superfície';
      case 'projectedarea':
      case 'grossfootprintarea':
      case 'netfootprintarea':
        return 'Área de Projeção Horizontal';
      case 'grossarea':
      case 'grosssidearea':
        return 'Área Bruta (Sem Descontos)';
      case 'netarea':
      case 'netsidearea':
        return 'Área Líquida (Executiva)';
      case 'crosssectionarea':
        return 'Área da Seção Transversal';
      case 'outersurfacearea':
        return 'Área de Superfície Externa';
      case 'volume':
        return 'Volume Geométrico Total';
      case 'grossvolume':
        return 'Volume Bruto';
      case 'netvolume':
        return 'Volume Líquido de Concretagem/Obra';
      case 'grossweight':
      case 'netweight':
      case 'weight':
        return 'Massa / Peso Estimado';
      case 'pitchangle':
      case 'slope':
      case 'inclinação':
        return 'Inclinação / Caimento';

      // Desempenho Técnico, Segurança e Térmica
      case 'loadbearing':
        return 'Função Estrutural (Portante)';
      case 'isexternal':
        return 'Exposição Externa (Envoltória/Fachada)';
      case 'extendtostructure':
        return 'Estender até a Estrutura';
      case 'compartmentation':
        return 'Compartimentação Corta-Fogo';
      case 'combustible':
        return 'Material Combustível';
      case 'firerating':
        return 'Resistência ao Fogo (TRRF)';
      case 'acousticrating':
        return 'Isolamento Acústico (Rw)';
      case 'thermaltransmittance':
        return 'Transmitância Térmica (U)';
      case 'surfaceflamespread':
      case 'surfacespreadofflame':
        return 'Propagação Superficial de Chamas';
      case 'structuralusage':
        return 'Uso Estrutural';
      case 'phasecreated':
      case 'fasecriada':
        return 'Fase de Execução';
      case 'phasedemolished':
      case 'fasedemolida':
        return 'Fase de Demolição';
    }

    // Humanização automática de termos camelCase/PascalCase desconhecidos sem perder legibilidade
    final spaced = clean
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m.group(1)} ${m.group(2)}')
        .trim();
    if (spaced.isEmpty) return clean;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  /// Formata valores IFC com unidades SI padronizadas para engenharia civil brasileira.
  static String formatPropertyValue(String rawKey, dynamic rawVal) {
    if (rawVal == null) return 'Não especificado';
    final valStr = BimElementMetadata.decodeIfcString('$rawVal').trim();

    if (valStr == '.T.' || valStr.toLowerCase() == 'true') return 'Sim';
    if (valStr == '.F.' || valStr.toLowerCase() == 'false') return 'Não';
    if (valStr == '.U.' || valStr.toLowerCase() == 'unknown' || valStr == 'NOTDEFINED') {
      return 'Não definido';
    }

    final lowerKey = rawKey.toLowerCase().trim();
    final isIdentifierKey = lowerKey == 'id' ||
        lowerKey == 'expressid' ||
        lowerKey == 'globalid' ||
        lowerKey.endsWith('_id') ||
        lowerKey.endsWith('guid');
    // IDs, tags e códigos não devem receber casas decimais nem unidades métricas
    if (isIdentifierKey ||
        lowerKey.contains('tag') ||
        lowerKey.contains('mark') ||
        lowerKey.contains('code') ||
        lowerKey.contains('number')) {
      return valStr;
    }

    final numVal = double.tryParse(valStr.replaceAll(',', '.'));
    if (numVal != null) {
      if (lowerKey.contains('area') || lowerKey.contains('área')) {
        return '${numVal.toStringAsFixed(2).replaceAll('.', ',')} m²';
      }
      if (lowerKey.contains('volume')) {
        return '${numVal.toStringAsFixed(2).replaceAll('.', ',')} m³';
      }
      if (lowerKey.contains('weight') || lowerKey.contains('peso') || lowerKey.contains('massa')) {
        return '${numVal.toStringAsFixed(1).replaceAll('.', ',')} kg';
      }
      if (lowerKey.contains('pitch') || lowerKey.contains('angle') || lowerKey.contains('slope') || lowerKey.contains('inclina')) {
        return '${numVal.toStringAsFixed(1).replaceAll(',0', '').replaceAll('.0', '').replaceAll('.', ',')}°';
      }
      if (lowerKey.contains('thermal')) {
        return '${numVal.toStringAsFixed(2).replaceAll('.', ',')} W/(m²·K)';
      }
      if (lowerKey.contains('height') ||
          lowerKey.contains('width') ||
          lowerKey.contains('length') ||
          lowerKey.contains('depth') ||
          lowerKey.contains('perimeter') ||
          lowerKey.contains('offset') ||
          lowerKey.contains('thickness') ||
          lowerKey.contains('altura') ||
          lowerKey.contains('largura') ||
          lowerKey.contains('espessura') ||
          lowerKey.contains('comprimento')) {
        if (numVal.abs() >= 50) {
          // Valor originalmente em milímetros (ex: 200 -> 0,20 m (200 mm))
          final m = numVal / 1000.0;
          return '${m.toStringAsFixed(2).replaceAll('.', ',')} m (${numVal.toStringAsFixed(0)} mm)';
        }
        final mm = (numVal * 1000).round();
        if (numVal > 0 && numVal < 1.0) {
          return '${numVal.toStringAsFixed(2).replaceAll('.', ',')} m ($mm mm)';
        }
        return '${numVal.toStringAsFixed(2).replaceAll('.', ',')} m';
      }
    }

    return valStr;
  }

  /// Traduz o nome de uma classe IFC (ex: `IfcWallStandardCase`) para o plural amigável em português.
  static String friendlyCategoryPlural(String ifcCategory) {
    final c = ifcCategory.toLowerCase();
    if (c.contains('wall')) return 'Paredes';
    if (c.contains('window')) return 'Janelas';
    if (c.contains('door')) return 'Portas';
    if (c.contains('slab')) return 'Lajes / Pisos';
    if (c.contains('column')) return 'Pilares';
    if (c.contains('beam')) return 'Vigas';
    if (c.contains('roof')) return 'Coberturas';
    if (c.contains('stair')) return 'Escadas';
    if (c.contains('railing')) return 'Guarda-Corpos';
    if (c.contains('member')) return 'Perfis Metálicos';
    if (c.contains('footing') || c.contains('pile')) return 'Fundações';
    if (c.contains('covering')) return 'Forros / Revestimentos';
    if (c.contains('plate')) return 'Chapas / Painéis';
    return ifcCategory.replaceFirst(RegExp(r'^Ifc', caseSensitive: false), '');
  }
}
