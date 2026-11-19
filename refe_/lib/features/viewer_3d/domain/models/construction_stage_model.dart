/// Etapas Físicas Construtivas de uma Obra (openBIM / Galpões Industriais e Edificações).
enum ConstructionStage {
  /// Subestrutura (Sapatas, Blocos, Estacas, Baldrames, Radiers)
  foundation,

  /// Superestrutura de Concreto Pré-fabricado (Pilares com consolos, Vigas pré, Lajes alveolares, Painéis)
  precast,

  /// Estrutura Metálica e Cobertura (Tesouras, Treliças, Terças metálicas, Contraventamentos, Chapas)
  steel,

  /// Outros elementos (Esquadrias, Fechamentos secundários, Instalações)
  other;

  String get displayName {
    switch (this) {
      case ConstructionStage.foundation:
        return 'Fundação';
      case ConstructionStage.precast:
        return 'Pré-Moldado';
      case ConstructionStage.steel:
        return 'Estrutura Metálica';
      case ConstructionStage.other:
        return 'Outros';
    }
  }

  String get emoji {
    switch (this) {
      case ConstructionStage.foundation:
        return '🧱';
      case ConstructionStage.precast:
        return '🏗️';
      case ConstructionStage.steel:
        return '🔩';
      case ConstructionStage.other:
        return '📦';
    }
  }
}

/// Sumário e quantitativo de peças identificadas por etapa da obra.
class ConstructionStagesSummary {
  final int foundationCount;
  final int precastCount;
  final int steelCount;
  final int otherCount;
  final int totalCount;

  const ConstructionStagesSummary({
    this.foundationCount = 0,
    this.precastCount = 0,
    this.steelCount = 0,
    this.otherCount = 0,
    this.totalCount = 0,
  });

  bool get hasAnyStages =>
      foundationCount > 0 || precastCount > 0 || steelCount > 0;

  factory ConstructionStagesSummary.fromMap(Map<String, dynamic> map) {
    return ConstructionStagesSummary(
      foundationCount: (map['foundationCount'] as num?)?.toInt() ?? 0,
      precastCount: (map['precastCount'] as num?)?.toInt() ?? 0,
      steelCount: (map['steelCount'] as num?)?.toInt() ?? 0,
      otherCount: (map['otherCount'] as num?)?.toInt() ?? 0,
      totalCount: (map['totalCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'foundationCount': foundationCount,
      'precastCount': precastCount,
      'steelCount': steelCount,
      'otherCount': otherCount,
      'totalCount': totalCount,
    };
  }

  @override
  String toString() =>
      'ConstructionStagesSummary(fundação: $foundationCount, pré-moldado: $precastCount, metálica: $steelCount, outros: $otherCount)';
}

/// Modo de seleção exclusivo (Radio Button) para o filtro de visualização de etapas.
enum StageFilterMode {
  all,
  foundation,
  precast,
  steel;

  String get label {
    switch (this) {
      case StageFilterMode.all:
        return 'Obra Completa';
      case StageFilterMode.foundation:
        return 'Fundação';
      case StageFilterMode.precast:
        return 'Pré-Moldado';
      case StageFilterMode.steel:
        return 'Estrutura Metálica';
    }
  }

  String get description {
    switch (this) {
      case StageFilterMode.all:
        return 'Visualização de todas as estruturas e etapas da obra';
      case StageFilterMode.foundation:
        return 'Sapatas, blocos de coroamento, estacas e baldrames';
      case StageFilterMode.precast:
        return 'Pilares de concreto, vigas portantes e painéis';
      case StageFilterMode.steel:
        return 'Perfis laminados, treliças espaciais e terças';
    }
  }
}

