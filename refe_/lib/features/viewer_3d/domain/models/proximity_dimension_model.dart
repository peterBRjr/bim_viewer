/// Modelo de dados representando a cota de proximidade 3D
/// entre o elemento inspecionado e o elemento físico/lógico mais próximo (≤ 6.0m).
class ProximityDimensionModel {
  final int targetExpressId;
  final int? neighborExpressId;
  final String neighborType;
  final String neighborName;
  final double distanceMeters;
  final String formattedDistance;
  final bool hasNeighbor;

  const ProximityDimensionModel({
    required this.targetExpressId,
    this.neighborExpressId,
    required this.neighborType,
    required this.neighborName,
    required this.distanceMeters,
    required this.formattedDistance,
    required this.hasNeighbor,
  });

  factory ProximityDimensionModel.fromMap(Map<String, dynamic> map) {
    final dist = (map['distanceMeters'] as num?)?.toDouble() ?? 0.0;
    final hasNeigh = map['hasNeighbor'] == true || (dist > 0.001 && dist <= 6.0);
    final targetId = (map['targetExpressId'] as num?)?.toInt() ?? 0;
    final neighborId = (map['neighborExpressId'] as num?)?.toInt();
    final type = map['neighborType'] as String? ?? 'Elemento';
    final name = map['neighborName'] as String? ?? '';
    final formatted = map['formattedDistance'] as String? ?? '${dist.toStringAsFixed(2)} m';

    return ProximityDimensionModel(
      targetExpressId: targetId,
      neighborExpressId: neighborId,
      neighborType: type,
      neighborName: name,
      distanceMeters: dist,
      formattedDistance: formatted,
      hasNeighbor: hasNeigh,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'targetExpressId': targetExpressId,
      'neighborExpressId': neighborExpressId,
      'neighborType': neighborType,
      'neighborName': neighborName,
      'distanceMeters': distanceMeters,
      'formattedDistance': formattedDistance,
      'hasNeighbor': hasNeighbor,
    };
  }

  @override
  String toString() {
    if (!hasNeighbor) return 'Sem elementos a menos de 6 m';
    return '$formattedDistance até $neighborType';
  }
}

