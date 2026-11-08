import 'package:flutter/material.dart';

/// Metadados de um elemento BIM selecionado via Raycaster na Viewport 3D.
class BimElementMetadata {
  final int expressID;
  final String name;
  final String category;
  final Map<String, dynamic> psets;
  final List<int> subIds;
  final bool isComposite;

  const BimElementMetadata({
    required this.expressID,
    required this.name,
    required this.category,
    required this.psets,
    this.subIds = const [],
    this.isComposite = false,
  });

  factory BimElementMetadata.fromMap(Map<String, dynamic> map) {
    final subIdsRaw = (map['subIds'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
    return BimElementMetadata(
      expressID: (map['expressID'] as num?)?.toInt() ?? 0,
      name: map['name']?.toString() ?? 'Elemento Desconhecido',
      category: map['category']?.toString() ?? 'IfcBuildingElementProxy',
      psets: (map['psets'] as Map?)?.cast<String, dynamic>() ?? {},
      subIds: subIdsRaw,
      isComposite: map['isComposite'] == true || subIdsRaw.length > 1,
    );
  }

  /// Decodifica caracteres ISO-10303-21 comuns do Revit (ex: \X\E7 -> ç, \X\ED -> í)
  static String decodeIfcString(String text) {
    if (!text.contains(r'\X\') && !text.contains(r'\X2\')) return text;
    var result = text;
    final Map<String, String> ifcMap = {
      r'\X\E1': 'á', r'\X\E9': 'é', r'\X\ED': 'í', r'\X\F3': 'ó', r'\X\FA': 'ú',
      r'\X\E3': 'ã', r'\X\F5': 'õ', r'\X\E2': 'â', r'\X\EA': 'ê', r'\X\F4': 'ô',
      r'\X\E7': 'ç', r'\X\C1': 'Á', r'\X\C9': 'É', r'\X\CD': 'Í', r'\X\D3': 'Ó',
      r'\X\DA': 'Ú', r'\X\C3': 'Ã', r'\X\D5': 'Õ', r'\X\C2': 'Â', r'\X\CA': 'Ê',
      r'\X\D4': 'Ô', r'\X\C7': 'Ç', r'\X\AA': 'ª', r'\X\BA': 'º', r'\X\E0': 'à',
      r'\X\C0': 'À',
    };
    ifcMap.forEach((key, val) {
      result = result.replaceAll(key, val);
    });
    return result;
  }

  /// Retorna o nome amigável e limpo para visualização na maquete de bolso.
  String get displayName => cleanTitle;

  /// Extrai o nome do tipo limpo (ex: "Telhado básico:Telhado ventilado - Concreto:331235" -> "Telhado ventilado - Concreto")
  String get cleanTitle {
    final decoded = decodeIfcString(name).trim();
    if (decoded.isEmpty || decoded == 'null') {
      return '$friendlyCategory #$expressID';
    }
    final withoutBrackets = decoded.replaceAll(RegExp(r'\s*\[\d+\]$'), '');
    if (withoutBrackets.contains(':')) {
      final parts = withoutBrackets.split(':').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (parts.length >= 2 && !RegExp(r'^\d+$').hasMatch(parts[1])) {
        return parts[1];
      }
      return parts[0];
    }
    return withoutBrackets;
  }

  /// Família / Categoria do Revit (ex: "Telhado básico", "Parede básica")
  String? get familyName {
    final decoded = decodeIfcString(name).trim();
    if (decoded.contains(':')) {
      final parts = decoded.split(':').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (parts.length >= 2 && !RegExp(r'^\d+$').hasMatch(parts[1])) {
        return parts[0];
      }
    }
    return null;
  }

  /// Tradução amigável da categoria IFC para português.
  String get friendlyCategory {
    final cat = category.toLowerCase();
    if (cat.contains('wall') || cat.contains('parede')) return 'Parede';
    if (cat.contains('door') || cat.contains('porta')) return 'Porta';
    if (cat.contains('window') || cat.contains('janela')) return 'Janela';
    if (cat.contains('slab') || cat.contains('laje') || cat.contains('piso') || cat.contains('floor')) return 'Laje / Piso';
    if (cat.contains('column') || cat.contains('pilar') || cat.contains('coluna')) return 'Pilar';
    if (cat.contains('beam') || cat.contains('viga')) return 'Viga';
    if (cat.contains('roof') || cat.contains('telhado')) return 'Telhado';
    if (cat.contains('stair') || cat.contains('escada')) return 'Escada';
    if (cat.contains('railing') || cat.contains('guarda')) return 'Guarda-Corpo';
    if (cat.contains('pipe') || cat.contains('tubo')) return 'Tubulação';
    if (cat.contains('duct') || cat.contains('duto')) return 'Duto';
    if (cat.contains('covering') || cat.contains('forro')) return 'Forro';
    if (cat.contains('member')) return 'Perfil Estrutural';
    if (cat.contains('proxy')) return 'Elemento Genérico';
    return category.replaceAll('Ifc', '');
  }

  /// Ícone semântico representativo da categoria BIM.
  IconData get categoryIcon {
    final cat = category.toLowerCase();
    if (cat.contains('wall') || cat.contains('parede')) return Icons.view_week_outlined;
    if (cat.contains('door') || cat.contains('porta')) return Icons.meeting_room_outlined;
    if (cat.contains('window') || cat.contains('janela')) return Icons.window_rounded;
    if (cat.contains('slab') || cat.contains('laje') || cat.contains('piso')) return Icons.layers_outlined;
    if (cat.contains('column') || cat.contains('pilar')) return Icons.table_chart_outlined;
    if (cat.contains('beam') || cat.contains('viga')) return Icons.horizontal_rule_rounded;
    if (cat.contains('roof') || cat.contains('telhado')) return Icons.roofing_rounded;
    if (cat.contains('stair') || cat.contains('escada')) return Icons.stairs_rounded;
    if (cat.contains('railing')) return Icons.fence_rounded;
    return Icons.view_in_ar_rounded;
  }

  /// Formata números decimais para o padrão da construção civil brasileira (ex: 279,42 m²)
  static String formatNumberWithUnit(dynamic val, String unit) {
    if (val == null) return 'N/A';
    final strVal = val.toString().trim();
    final numVal = double.tryParse(strVal.replaceAll(',', '.'));
    if (numVal != null) {
      final formatted = numVal.toStringAsFixed(2).replaceAll('.', ',');
      return '$formatted $unit';
    }
    return strVal.endsWith(unit) ? strVal : '$strVal $unit';
  }

  /// Extrai as métricas de obra mais úteis (Área, Volume, Dimensões, Nível, Inclinação).
  Map<String, String> get keyMetrics {
    final Map<String, String> metrics = {};

    for (final pset in psets.values) {
      if (pset is Map) {
        for (final entry in pset.entries) {
          final key = entry.key.toString().toLowerCase();
          final val = decodeIfcString(entry.value.toString()).trim();

          if (metrics.length < 4) {
            if (key.contains('totalarea') || key == 'area' || key.contains('área')) {
              metrics['Área Total'] = formatNumberWithUnit(val, 'm²');
            } else if (key.contains('volume')) {
              metrics['Volume'] = formatNumberWithUnit(val, 'm³');
            } else if (key.contains('pitch') || key.contains('inclina')) {
              final numVal = double.tryParse(val.replaceAll(',', '.'));
              metrics['Caimento'] = numVal != null ? '${numVal.toStringAsFixed(0)}°' : '$val°';
            } else if (key.contains('length') || key.contains('comprimento')) {
              metrics['Comprimento'] = formatNumberWithUnit(val, 'm');
            } else if (key.contains('height') || key.contains('altura')) {
              metrics['Altura'] = formatNumberWithUnit(val, 'm');
            } else if (key.contains('width') || key.contains('espessura') || key.contains('largura')) {
              metrics['Espessura'] = formatNumberWithUnit(val, 'm');
            } else if (key.contains('level') || key.contains('nível') || key.contains('pavimento')) {
              metrics['Nível'] = val;
            }
          }
        }
      }
    }

    if (isComposite && !metrics.containsKey('Composição')) {
      metrics['Composição'] = '${subIds.length} partes';
    }

    if (metrics.isEmpty) {
      metrics['Elemento'] = '#$expressID';
      metrics['Categoria'] = friendlyCategory;
      metrics['Status'] = 'As-Built';
    }

    return metrics;
  }
}

