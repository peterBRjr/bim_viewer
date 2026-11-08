import 'package:flutter/material.dart';
import 'bim_project_specs.dart';

export 'bim_project_specs.dart';

/// Metadados de um elemento BIM selecionado via Raycaster na Viewport 3D.
class BimElementMetadata {
  final int expressID;
  final String name;
  final String category;
  final Map<String, dynamic> psets;
  final List<int> subIds;
  final bool isComposite;
  final String? globalId;
  final String? tag;
  final String? predefinedType;
  final String? typeName;
  final int? hostStoreyId;
  final String? hostStoreyName;
  final List<String> materials;
  final Map<String, double> geometricDimensions;
  final BimPieceAnalytics? analytics;
  final bool alreadyFocusedInJs;

  const BimElementMetadata({
    required this.expressID,
    required this.name,
    required this.category,
    required this.psets,
    this.subIds = const [],
    this.isComposite = false,
    this.globalId,
    this.tag,
    this.predefinedType,
    this.typeName,
    this.hostStoreyId,
    this.hostStoreyName,
    this.materials = const [],
    this.geometricDimensions = const {},
    this.analytics,
    this.alreadyFocusedInJs = false,
  });

  factory BimElementMetadata.fromMap(Map<String, dynamic> map) {
    final subIdsRaw = (map['subIds'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
    final matsRaw = (map['materials'] as List?)
            ?.map((e) => decodeIfcString(e.toString()).trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];

    final Map<String, double> parsedDims = {};
    if (map['geometricDimensions'] is Map) {
      (map['geometricDimensions'] as Map).forEach((k, v) {
        if (v is num) parsedDims[k.toString()] = v.toDouble();
      });
    }

    BimPieceAnalytics? parsedAnalytics;
    if (map['analytics'] is Map) {
      parsedAnalytics = BimPieceAnalytics.fromMap(
        (map['analytics'] as Map).cast<String, dynamic>(),
      );
    }

    return BimElementMetadata(
      expressID: (map['expressID'] as num?)?.toInt() ?? 0,
      name: map['name']?.toString() ?? 'Elemento Desconhecido',
      category: map['category']?.toString() ?? 'IfcBuildingElementProxy',
      psets: (map['psets'] as Map?)?.cast<String, dynamic>() ?? {},
      subIds: subIdsRaw,
      isComposite: map['isComposite'] == true || subIdsRaw.length > 1,
      globalId: map['globalId']?.toString(),
      tag: map['tag']?.toString(),
      predefinedType: map['predefinedType']?.toString(),
      typeName: map['typeName'] != null ? decodeIfcString(map['typeName'].toString()).trim() : null,
      hostStoreyId: (map['hostStoreyId'] as num?)?.toInt(),
      hostStoreyName: map['hostStoreyName'] != null
          ? decodeIfcString(map['hostStoreyName'].toString()).trim()
          : null,
      materials: matsRaw,
      geometricDimensions: parsedDims,
      analytics: parsedAnalytics,
      alreadyFocusedInJs: map['alreadyFocusedInJs'] == true,
    );
  }

  /// Decodifica sequências ISO-10303-21 (STEP) de arquivos IFC (\X2\XXXX\X0\ UTF-16 e \X\XX ISO-8859-1).
  static String decodeIfcString(String text) {
    if (!text.contains(r'\X')) return text;
    var result = text;

    // 1. Sequências UTF-16 (\X2\00ED00E3...\X0\)
    result = result.replaceAllMapped(RegExp(r'\\X2\\([0-9A-Fa-f]+)\\X0\\'), (match) {
      final hex = match.group(1) ?? '';
      final sb = StringBuffer();
      for (var i = 0; i + 3 < hex.length; i += 4) {
        final code = int.tryParse(hex.substring(i, i + 4), radix: 16);
        if (code != null) sb.writeCharCode(code);
      }
      return sb.toString();
    });

    // 2. Sequências ISO-8859-1 de 1 byte (\X\E7 -> ç, \X\ED -> í, etc.)
    result = result.replaceAllMapped(RegExp(r'\\X\\([0-9A-Fa-f]{2})'), (match) {
      final code = int.tryParse(match.group(1) ?? '', radix: 16);
      return code != null ? String.fromCharCode(code) : match.group(0)!;
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
    if (cat.contains('footing') || cat.contains('pile')) return 'Fundação';
    if (cat.contains('member')) return 'Perfil Estrutural';
    if (cat.contains('plate')) return 'Chapa / Painel';
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

    if (hostStoreyName != null && hostStoreyName!.isNotEmpty && metrics.length < 4 && !metrics.containsKey('Nível')) {
      metrics['Nível'] = hostStoreyName!;
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
