import 'package:intl/intl.dart';

/// Entidade de domínio que representa um projeto BIM armazenado localmente no dispositivo.
class ProjectModel {
  /// Identificador único universal do projeto (UUID v4)
  final String id;

  /// Nome de exibição do projeto ou arquivo (ex: "Edifício Comercial - Bloco A")
  final String name;

  /// Caminho absoluto do arquivo no armazenamento local seguro
  final String filePath;

  /// Tamanho do arquivo em Megabytes (MB)
  final double fileSizeMB;

  /// Formato do modelo 3D/BIM (ex: 'GLB', 'gltf', 'IFC')
  final String format;

  /// Data e hora de importação ou criação do projeto
  final DateTime createdAt;

  const ProjectModel({
    required this.id,
    required this.name,
    required this.filePath,
    required this.fileSizeMB,
    required this.format,
    required this.createdAt,
  });

  /// Converte a entidade em um Map chave-valor para serialização e persistência.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'filePath': filePath,
      'fileSizeMB': fileSizeMB,
      'format': format,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Constrói uma instância de [ProjectModel] a partir de um Map com tratamento defensivo de tipos.
  factory ProjectModel.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    final rawDate = map['createdAt'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawDate);
    } else {
      parsedDate = DateTime.now();
    }

    return ProjectModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Projeto sem nome',
      filePath: map['filePath']?.toString() ?? '',
      fileSizeMB: (map['fileSizeMB'] as num?)?.toDouble() ?? 0.0,
      format: (map['format']?.toString() ?? 'UNKNOWN').toUpperCase(),
      createdAt: parsedDate,
    );
  }

  /// Retorna uma cópia da instância atual com campos atualizados opcionalmente.
  ProjectModel copyWith({
    String? id,
    String? name,
    String? filePath,
    double? fileSizeMB,
    String? format,
    DateTime? createdAt,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      fileSizeMB: fileSizeMB ?? this.fileSizeMB,
      format: format ?? this.format,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Retorna o tamanho formatado em string legível (ex: "14.25 MB").
  String get formattedSize {
    if (fileSizeMB < 0.1) {
      final kb = fileSizeMB * 1024;
      return '${kb.toStringAsFixed(1)} KB';
    }
    return '${fileSizeMB.toStringAsFixed(2)} MB';
  }

  /// Retorna a data formatada no padrão brasileiro (ex: "14/10/2026 19:30").
  String get formattedDate {
    return DateFormat('dd/MM/yyyy HH:mm').format(createdAt);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProjectModel &&
        other.id == id &&
        other.name == name &&
        other.filePath == filePath &&
        other.fileSizeMB == fileSizeMB &&
        other.format == format &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, filePath, fileSizeMB, format, createdAt);
  }

  @override
  String toString() {
    return 'ProjectModel(id: $id, name: $name, filePath: $filePath, fileSizeMB: $fileSizeMB, format: $format, createdAt: $createdAt)';
  }
}
