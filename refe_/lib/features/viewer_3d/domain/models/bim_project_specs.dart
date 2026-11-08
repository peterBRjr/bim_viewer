import 'bim_element_metadata.dart';

/// Informações de um Nível / Pavimento (`IfcBuildingStorey`) extraído do arquivo IFC.
class BimStoreyInfo {
  final int expressID;
  final String name;
  final double elevationMeters;
  final int totalElementsInStorey;

  const BimStoreyInfo({
    required this.expressID,
    required this.name,
    required this.elevationMeters,
    this.totalElementsInStorey = 0,
  });

  factory BimStoreyInfo.fromMap(Map<String, dynamic> map) {
    final rawName = map['name']?.toString() ?? 'Pavimento';
    return BimStoreyInfo(
      expressID: (map['expressID'] as num?)?.toInt() ?? 0,
      name: BimElementMetadata.decodeIfcString(rawName).trim(),
      elevationMeters: (map['elevationMeters'] as num?)?.toDouble() ?? 0.0,
      totalElementsInStorey: (map['totalElementsInStorey'] as num?)?.toInt() ?? 0,
    );
  }

  /// Formata a cota de elevação no padrão da construção civil brasileira (ex: +7,60 m / 0,00 m / -0,94 m).
  String get formattedElevation {
    final cleanVal = elevationMeters.abs() < 0.001 ? 0.0 : elevationMeters;
    final prefix = cleanVal > 0.001 ? '+' : '';
    return '$prefix${cleanVal.toStringAsFixed(2).replaceAll('.', ',')} m';
  }

  /// Rótulo amigável para Dropdown de Níveis (ex: "Nível 1 (0,00 m)").
  String get dropdownLabel => '$name ($formattedElevation)';
}

/// Métricas físicas acumuladas de uma peça (no projeto completo ou filtradas por pavimento).
class BimPieceAggregatedMetrics {
  final double lengthM;
  final double areaM2;
  final double volumeM3;

  const BimPieceAggregatedMetrics({
    this.lengthM = 0.0,
    this.areaM2 = 0.0,
    this.volumeM3 = 0.0,
  });

  factory BimPieceAggregatedMetrics.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const BimPieceAggregatedMetrics();
    return BimPieceAggregatedMetrics(
      lengthM: (map['lengthM'] as num?)?.toDouble() ?? 0.0,
      areaM2: (map['areaM2'] as num?)?.toDouble() ?? 0.0,
      volumeM3: (map['volumeM3'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get formattedLength => '${lengthM.toStringAsFixed(2).replaceAll('.', ',')} m';
  String get formattedArea => '${areaM2.toStringAsFixed(2).replaceAll('.', ',')} m²';
  String get formattedVolume => '${volumeM3.toStringAsFixed(2).replaceAll('.', ',')} m³';
}

/// Análise quantitativa dinâmica da peça selecionada em todo o projeto e por nível (`IfcBuildingStorey`).
class BimPieceAnalytics {
  final String typeName;
  final String ifcTypeClass;
  final int? hostStoreyId;
  final String? hostStoreyName;
  final int totalInProject;
  final int totalCategoryInProject;
  final List<int> allInstanceIds;
  final Map<int, int> countByStorey;
  final Map<int, List<int>> instanceIdsByStorey;
  final Map<int, int> categoryCountByStorey;
  final BimPieceAggregatedMetrics totalMetrics;
  final Map<int, BimPieceAggregatedMetrics> metricsByStorey;

  const BimPieceAnalytics({
    required this.typeName,
    this.ifcTypeClass = '',
    this.hostStoreyId,
    this.hostStoreyName,
    required this.totalInProject,
    this.totalCategoryInProject = 0,
    this.allInstanceIds = const [],
    this.countByStorey = const {},
    this.instanceIdsByStorey = const {},
    this.categoryCountByStorey = const {},
    this.totalMetrics = const BimPieceAggregatedMetrics(),
    this.metricsByStorey = const {},
  });

  factory BimPieceAnalytics.fromMap(Map<String, dynamic> map) {
    final Map<int, int> parsedCounts = {};
    if (map['countByStorey'] is Map) {
      (map['countByStorey'] as Map).forEach((k, v) {
        final id = int.tryParse(k.toString());
        if (id != null) parsedCounts[id] = (v as num?)?.toInt() ?? 0;
      });
    }

    final Map<int, List<int>> parsedInstances = {};
    if (map['instanceIdsByStorey'] is Map) {
      (map['instanceIdsByStorey'] as Map).forEach((k, v) {
        final id = int.tryParse(k.toString());
        if (id != null && v is List) {
          parsedInstances[id] = v.map((e) => (e as num).toInt()).toList();
        }
      });
    }

    final Map<int, int> parsedCatCounts = {};
    if (map['categoryCountByStorey'] is Map) {
      (map['categoryCountByStorey'] as Map).forEach((k, v) {
        final id = int.tryParse(k.toString());
        if (id != null) parsedCatCounts[id] = (v as num?)?.toInt() ?? 0;
      });
    }

    final Map<int, BimPieceAggregatedMetrics> parsedStoreyMetrics = {};
    if (map['metricsByStorey'] is Map) {
      (map['metricsByStorey'] as Map).forEach((k, v) {
        final id = int.tryParse(k.toString());
        if (id != null && v is Map) {
          parsedStoreyMetrics[id] = BimPieceAggregatedMetrics.fromMap(v.cast<String, dynamic>());
        }
      });
    }

    final allIds = (map['allInstanceIds'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
    final rawTotal = (map['totalInProject'] as num?)?.toInt() ?? (allIds.isNotEmpty ? allIds.length : 1);

    return BimPieceAnalytics(
      typeName: BimElementMetadata.decodeIfcString(map['typeName']?.toString() ?? '').trim(),
      ifcTypeClass: map['ifcTypeClass']?.toString() ?? '',
      hostStoreyId: (map['hostStoreyId'] as num?)?.toInt(),
      hostStoreyName: map['hostStoreyName'] != null
          ? BimElementMetadata.decodeIfcString(map['hostStoreyName'].toString()).trim()
          : null,
      totalInProject: rawTotal > 0 ? rawTotal : 1,
      totalCategoryInProject: (map['totalCategoryInProject'] as num?)?.toInt() ?? rawTotal,
      allInstanceIds: allIds,
      countByStorey: parsedCounts,
      instanceIdsByStorey: parsedInstances,
      categoryCountByStorey: parsedCatCounts,
      totalMetrics: BimPieceAggregatedMetrics.fromMap(
        (map['totalMetrics'] as Map?)?.cast<String, dynamic>(),
      ),
      metricsByStorey: parsedStoreyMetrics,
    );
  }

  /// Quantidade desta peça considerando o filtro de pavimento (`null` = Projeto Completo).
  int countForStorey(int? storeyId) {
    if (storeyId == null) return totalInProject;
    return countByStorey[storeyId] ?? 0;
  }

  /// Percentual representativo (0.0 a 1.0) da peça no nível selecionado frente ao total do projeto.
  double ratioOfProjectForStorey(int? storeyId) {
    if (totalInProject <= 0) return 0.0;
    if (storeyId == null) return 1.0;
    return (countForStorey(storeyId) / totalInProject).clamp(0.0, 1.0);
  }

  /// Quantidade total de elementos da mesma categoria (ex: todas as Paredes) no nível filtrado.
  int categoryCountForStorey(int? storeyId) {
    if (storeyId == null) return totalCategoryInProject;
    return categoryCountByStorey[storeyId] ?? 0;
  }

  /// Lista de ExpressIDs das instâncias desta peça no nível filtrado (`null` = todas do projeto).
  List<int> instancesForStorey(int? storeyId) {
    if (storeyId == null) return allInstanceIds;
    return instanceIdsByStorey[storeyId] ?? const [];
  }

  /// Métricas físicas somadas (Comprimento, Área, Volume) apenas das peças contidas no nível selecionado.
  BimPieceAggregatedMetrics metricsForStorey(int? storeyId) {
    if (storeyId == null) return totalMetrics;
    return metricsByStorey[storeyId] ?? const BimPieceAggregatedMetrics();
  }
}

/// Especificações globais openBIM importadas diretamente do cabeçalho e entidades raiz do arquivo `.IFC`.
class BimProjectSpecs {
  final String schema;
  final String viewDefinition;
  final String authoringApp;
  final String author;
  final String organization;
  final String projectName;
  final String projectNumber;
  final String projectPhase;
  final String siteName;
  final String buildingName;
  final String address;
  final String exportDate;
  final String coordinateSystem;
  final String lengthUnit;
  final String areaUnit;
  final String volumeUnit;
  final int totalElements;
  final List<BimStoreyInfo> storeys;
  final Map<String, int> categorySummary;

  const BimProjectSpecs({
    this.schema = 'IFC2X3',
    this.viewDefinition = 'CoordinationView V2.0',
    this.authoringApp = 'Software Autoral openBIM',
    this.author = '',
    this.organization = '',
    this.projectName = 'Projeto BIM',
    this.projectNumber = '',
    this.projectPhase = '',
    this.siteName = '',
    this.buildingName = '',
    this.address = '',
    this.exportDate = '',
    this.coordinateSystem = 'Coordenadas Compartilhadas',
    this.lengthUnit = 'Milímetros (mm)',
    this.areaUnit = 'Metros quadrados (m²)',
    this.volumeUnit = 'Metros cúbicos (m³)',
    this.totalElements = 0,
    this.storeys = const [],
    this.categorySummary = const {},
  });

  factory BimProjectSpecs.fromMap(Map<String, dynamic> map) {
    final storeysRaw = (map['storeys'] as List?) ?? const [];
    final parsedStoreys = storeysRaw
        .whereType<Map>()
        .map((m) => BimStoreyInfo.fromMap(m.cast<String, dynamic>()))
        .toList();

    final Map<String, int> parsedCatSummary = {};
    if (map['categorySummary'] is Map) {
      (map['categorySummary'] as Map).forEach((k, v) {
        parsedCatSummary[k.toString()] = (v as num?)?.toInt() ?? 0;
      });
    }

    return BimProjectSpecs(
      schema: BimElementMetadata.decodeIfcString(map['schema']?.toString() ?? 'IFC2X3').trim(),
      viewDefinition: BimElementMetadata.decodeIfcString(map['viewDefinition']?.toString() ?? '').trim(),
      authoringApp: BimElementMetadata.decodeIfcString(map['authoringApp']?.toString() ?? '').trim(),
      author: BimElementMetadata.decodeIfcString(map['author']?.toString() ?? '').trim(),
      organization: BimElementMetadata.decodeIfcString(map['organization']?.toString() ?? '').trim(),
      projectName: BimElementMetadata.decodeIfcString(map['projectName']?.toString() ?? 'Projeto BIM').trim(),
      projectNumber: BimElementMetadata.decodeIfcString(map['projectNumber']?.toString() ?? '').trim(),
      projectPhase: BimElementMetadata.decodeIfcString(map['projectPhase']?.toString() ?? '').trim(),
      siteName: BimElementMetadata.decodeIfcString(map['siteName']?.toString() ?? '').trim(),
      buildingName: BimElementMetadata.decodeIfcString(map['buildingName']?.toString() ?? '').trim(),
      address: BimElementMetadata.decodeIfcString(map['address']?.toString() ?? '').trim(),
      exportDate: BimElementMetadata.decodeIfcString(map['exportDate']?.toString() ?? '').trim(),
      coordinateSystem: BimElementMetadata.decodeIfcString(map['coordinateSystem']?.toString() ?? '').trim(),
      lengthUnit: BimElementMetadata.decodeIfcString(map['lengthUnit']?.toString() ?? 'Milímetros (mm)').trim(),
      areaUnit: BimElementMetadata.decodeIfcString(map['areaUnit']?.toString() ?? 'Metros quadrados (m²)').trim(),
      volumeUnit: BimElementMetadata.decodeIfcString(map['volumeUnit']?.toString() ?? 'Metros cúbicos (m³)').trim(),
      totalElements: (map['totalElements'] as num?)?.toInt() ?? 0,
      storeys: parsedStoreys,
      categorySummary: parsedCatSummary,
    );
  }

  /// Data de exportação formatada em DD/MM/AAAA HH:MM quando em ISO-8601.
  String get formattedExportDate {
    if (exportDate.isEmpty) return 'Não informada';
    final parsed = DateTime.tryParse(exportDate);
    if (parsed != null) {
      final d = parsed.day.toString().padLeft(2, '0');
      final m = parsed.month.toString().padLeft(2, '0');
      final y = parsed.year;
      final h = parsed.hour.toString().padLeft(2, '0');
      final min = parsed.minute.toString().padLeft(2, '0');
      return '$d/$m/$y às $h:$min';
    }
    return exportDate;
  }

  /// Amplitude altimétrica do edifício (do nível mais baixo ao mais alto).
  String get elevationSpanLabel {
    if (storeys.isEmpty) return 'Cota única';
    if (storeys.length == 1) return storeys.first.formattedElevation;
    return '${storeys.first.formattedElevation} até ${storeys.last.formattedElevation}';
  }
}

