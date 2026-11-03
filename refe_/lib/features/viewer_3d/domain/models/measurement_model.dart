/// Modelo que encapsula os dados de uma medição técnica 3D (Vão Livre ou Ponto a Ponto).
class MeasurementModel {
  final String id;
  final double distance;
  final String type; // 'span' (vão livre automático com 1 toque) ou 'point_to_point' (2 toques)
  final String label;
  final double startX;
  final double startY;
  final double startZ;
  final double endX;
  final double endY;
  final double endZ;
  final double deltaX;
  final double deltaY;
  final double deltaZ;
  final DateTime createdAt;

  const MeasurementModel({
    required this.id,
    required this.distance,
    required this.type,
    required this.label,
    required this.startX,
    required this.startY,
    required this.startZ,
    required this.endX,
    required this.endY,
    required this.endZ,
    required this.deltaX,
    required this.deltaY,
    required this.deltaZ,
    required this.createdAt,
  });

  factory MeasurementModel.fromMap(Map<String, dynamic> map) {
    final start = (map['startPoint'] as Map?)?.cast<String, dynamic>() ?? {};
    final end = (map['endPoint'] as Map?)?.cast<String, dynamic>() ?? {};

    final dX = (map['deltaX'] as num?)?.toDouble() ??
        (((end['x'] as num?)?.toDouble() ?? 0.0) - ((start['x'] as num?)?.toDouble() ?? 0.0)).abs();
    final dY = (map['deltaY'] as num?)?.toDouble() ??
        (((end['y'] as num?)?.toDouble() ?? 0.0) - ((start['y'] as num?)?.toDouble() ?? 0.0)).abs();
    final dZ = (map['deltaZ'] as num?)?.toDouble() ??
        (((end['z'] as num?)?.toDouble() ?? 0.0) - ((start['z'] as num?)?.toDouble() ?? 0.0)).abs();

    final dist = (map['distance'] as num?)?.toDouble() ?? 0.0;
    final typeStr = map['type']?.toString() ?? 'span';

    return MeasurementModel(
      id: map['id']?.toString() ?? 'meas_${DateTime.now().millisecondsSinceEpoch}',
      distance: dist,
      type: typeStr,
      label: map['label']?.toString() ??
          (typeStr == 'span'
              ? 'Vão Livre: ${_formatMeters(dist)}'
              : 'Distância: ${_formatMeters(dist)}'),
      startX: (start['x'] as num?)?.toDouble() ?? 0.0,
      startY: (start['y'] as num?)?.toDouble() ?? 0.0,
      startZ: (start['z'] as num?)?.toDouble() ?? 0.0,
      endX: (end['x'] as num?)?.toDouble() ?? 0.0,
      endY: (end['y'] as num?)?.toDouble() ?? 0.0,
      endZ: (end['z'] as num?)?.toDouble() ?? 0.0,
      deltaX: dX,
      deltaY: dY,
      deltaZ: dZ,
      createdAt: DateTime.now(),
    );
  }

  static String _formatMeters(double val) {
    return '${val.toStringAsFixed(2).replaceAll('.', ',')} m';
  }

  String get formattedDistance => _formatMeters(distance);
  String get formattedDeltaX => _formatMeters(deltaX);
  String get formattedDeltaY => _formatMeters(deltaY);
  String get formattedDeltaZ => _formatMeters(deltaZ);

  bool get isSpan => type == 'span';
  bool get isPointToPoint => type == 'point_to_point';
}
