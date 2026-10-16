import 'dart:developer' as developer;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

/// Modelo de transferência de dados (DTO) com os metadados do arquivo BIM selecionado pelo usuário.
class SelectedBimFile {
  /// Caminho completo do arquivo de origem selecionado
  final String path;

  /// Nome original do arquivo (com extensão)
  final String name;

  /// Formato do modelo em caixa alta (ex: 'GLB', 'GLTF', 'IFC')
  final String format;

  /// Tamanho do arquivo em Megabytes
  final double sizeMB;

  const SelectedBimFile({
    required this.path,
    required this.name,
    required this.format,
    required this.sizeMB,
  });

  /// Representação textual amigável do tamanho
  String get formattedSize {
    if (sizeMB < 0.1) {
      final kb = sizeMB * 1024;
      return '${kb.toStringAsFixed(1)} KB';
    }
    return '${sizeMB.toStringAsFixed(2)} MB';
  }
}

/// Serviço responsável pela integração com o FilePicker nativo do sistema operacional.
/// Filtra extensões técnicas suportadas pelo visualizador (.glb, .gltf, .ifc).
class FilePickerService {
  static const List<String> supportedExtensions = ['glb', 'gltf', 'ifc'];

  /// Abre a interface nativa de seleção de arquivos configurada exclusivamente
  /// para modelos 3D e arquivos BIM.
  Future<SelectedBimFile?> pickBimFile() async {
    try {
      final PlatformFile? picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: supportedExtensions,
        dialogTitle: 'Selecione um modelo BIM ou 3D',
      );

      if (picked == null) {
        return null;
      }

      final String? filePath = picked.path;
      if (filePath == null || filePath.isEmpty) {
        developer.log(
          'O arquivo foi selecionado mas o caminho físico não pôde ser resolvido.',
          name: 'FilePickerService',
        );
        return null;
      }

      // Extração resiliente da extensão
      String format = picked.extension?.toUpperCase() ?? '';
      if (format.isEmpty) {
        final extFromPath = p.extension(picked.name).replaceAll('.', '').toUpperCase();
        format = extFromPath.isNotEmpty ? extFromPath : 'GLB';
      }

      // Cálculo defensivo do tamanho em MB
      double sizeInMB = 0.0;
      try {
        final int? length = await picked.length();
        if (length != null && length > 0) {
          sizeInMB = length / (1024 * 1024);
        } else {
          final file = File(filePath);
          if (await file.exists()) {
            final fileLength = await file.length();
            sizeInMB = fileLength / (1024 * 1024);
          }
        }
      } catch (_) {
        final file = File(filePath);
        if (await file.exists()) {
          final fileLength = await file.length();
          sizeInMB = fileLength / (1024 * 1024);
        }
      }

      return SelectedBimFile(
        path: filePath,
        name: picked.name,
        format: format,
        sizeMB: sizeInMB,
      );
    } catch (e, stack) {
      developer.log(
        'Erro ao selecionar arquivo BIM com FilePicker',
        error: e,
        stackTrace: stack,
        name: 'FilePickerService',
      );
      rethrow;
    }
  }
}
