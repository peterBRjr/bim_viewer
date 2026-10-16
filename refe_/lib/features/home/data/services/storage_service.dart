import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/project_model.dart';

/// Serviço responsável pelo gerenciamento de persistência local segura (I/O e Metadados).
/// Garante que cópias físicas dos arquivos BIM sejam mantidas no armazenamento seguro do app,
/// prevenindo perdas caso o usuário apague ou mova o arquivo do diretório Downloads.
class StorageService {
  static const String _catalogFileName = 'projects_catalog.json';
  static const String _projectsFolderName = 'projects';
  final Uuid _uuid;

  StorageService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  /// Retorna o diretório interno de documentos da aplicação.
  Future<Directory> _getAppDocDir() async {
    return await getApplicationDocumentsDirectory();
  }

  /// Retorna e assegura a existência do diretório físico de projetos `projects/`.
  Future<Directory> _getProjectsDir() async {
    final appDir = await _getAppDocDir();
    final projectsDir = Directory(p.join(appDir.path, _projectsFolderName));
    if (!await projectsDir.exists()) {
      await projectsDir.create(recursive: true);
    }
    return projectsDir;
  }

  /// Retorna o arquivo de catálogo JSON.
  Future<File> _getCatalogFile() async {
    final appDir = await _getAppDocDir();
    return File(p.join(appDir.path, _catalogFileName));
  }

  /// Carrega a lista de projetos persistidos no arquivo JSON interno.
  /// Se Projeto1.ifc dos assets ainda não estiver no catálogo, extrai automaticamente.
  Future<List<ProjectModel>> loadCatalog() async {
    try {
      final file = await _getCatalogFile();
      List<ProjectModel> projects = [];

      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final dynamic decoded = jsonDecode(content);
          if (decoded is List) {
            projects = decoded
                .whereType<Map<String, dynamic>>()
                .map((item) => ProjectModel.fromMap(item))
                .toList();
          }
        }
      }

      // Limpa entradas e arquivos obsoletos de Projeto1 se existirem
      final hadOldProjects = projects.any((p) => p.name.contains('Projeto1'));
      if (hadOldProjects) {
        for (final oldProj in projects.where((p) => p.name.contains('Projeto1'))) {
          try {
            final f = File(oldProj.filePath);
            if (await f.exists()) {
              await f.delete();
            }
          } catch (_) {}
        }
        projects.removeWhere((p) => p.name.contains('Projeto1'));
      }

      // Semeia ajustado.ifc dos assets caso não esteja no catálogo
      bool catalogUpdated = hadOldProjects;
      if (!projects.any((p) => p.name.contains('ajustado'))) {
        final seeded = await _seedProjectFromAsset('assets/models/ajustado.ifc', 'ajustado.ifc');
        if (seeded != null) {
          projects = [seeded, ...projects];
          catalogUpdated = true;
        }
      }

      if (catalogUpdated) {
        await saveCatalog(projects);
      }

      return projects;
    } catch (e, stack) {
      developer.log(
        'Falha defensiva ao carregar catálogo de projetos',
        error: e,
        stackTrace: stack,
        name: 'StorageService',
      );
      return [];
    }
  }

  /// Extrai um arquivo BIM de assets para a pasta local de projetos do dispositivo.
  Future<ProjectModel?> _seedProjectFromAsset(String assetPath, String originalName) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final bytes = byteData.buffer.asUint8List();
      final projectsDir = await _getProjectsDir();
      final String projectId = _uuid.v4();
      final destinationFileName = '${projectId}_$originalName';
      final destinationFile = File(p.join(projectsDir.path, destinationFileName));
      await destinationFile.writeAsBytes(bytes, flush: true);

      return ProjectModel(
        id: projectId,
        name: originalName,
        filePath: destinationFile.path,
        fileSizeMB: bytes.length / (1024 * 1024),
        format: 'IFC',
        createdAt: DateTime.now(),
      );
    } catch (e, stack) {
      developer.log(
        'Aviso: Não foi possível semear asset $assetPath: $e',
        error: e,
        stackTrace: stack,
        name: 'StorageService',
      );
      return null;
    }
  }

  /// Persiste a lista completa de projetos no arquivo JSON interno.
  Future<bool> saveCatalog(List<ProjectModel> projects) async {
    try {
      final file = await _getCatalogFile();
      final listData = projects.map((p) => p.toMap()).toList();
      final jsonString = jsonEncode(listData);
      await file.writeAsString(jsonString, flush: true);
      return true;
    } catch (e, stack) {
      developer.log(
        'Falha defensiva ao salvar catálogo de projetos',
        error: e,
        stackTrace: stack,
        name: 'StorageService',
      );
      return false;
    }
  }

  /// Realiza a cópia física segura do arquivo BIM para o diretório interno `projects/`
  /// e registra a entidade no catálogo JSON.
  Future<ProjectModel> saveLocalProjectFile({
    required String sourcePath,
    required String originalName,
    required double fileSizeMB,
    required String format,
  }) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw FileSystemException('Arquivo de origem não encontrado', sourcePath);
      }

      final projectsDir = await _getProjectsDir();
      final String projectId = _uuid.v4();

      // Sanitiza o nome do arquivo para evitar caracteres inválidos no filesystem
      final sanitizedName = originalName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final destinationFileName = '${projectId}_$sanitizedName';
      final destinationPath = p.join(projectsDir.path, destinationFileName);

      // Efetua cópia física defensiva
      final destinationFile = await sourceFile.copy(destinationPath);

      // Recalcula tamanho exato do arquivo copiado para integridade
      double exactSizeMB = fileSizeMB;
      if (await destinationFile.exists()) {
        final bytes = await destinationFile.length();
        exactSizeMB = bytes / (1024 * 1024);
      }

      final newProject = ProjectModel(
        id: projectId,
        name: originalName,
        filePath: destinationFile.path,
        fileSizeMB: exactSizeMB,
        format: format.toUpperCase(),
        createdAt: DateTime.now(),
      );

      // Atualiza catálogo persistente
      final currentCatalog = await loadCatalog();
      final updatedCatalog = [newProject, ...currentCatalog];
      await saveCatalog(updatedCatalog);

      return newProject;
    } catch (e, stack) {
      developer.log(
        'Erro ao copiar arquivo físico e registrar projeto no armazenamento seguro',
        error: e,
        stackTrace: stack,
        name: 'StorageService',
      );
      rethrow;
    }
  }

  /// Registra um projeto remoto/nuvem no catálogo de projetos.
  Future<ProjectModel> saveCloudProject({
    required String name,
    required String url,
    String format = 'IFC',
  }) async {
    try {
      final String projectId = _uuid.v4();
      final cloudProject = ProjectModel(
        id: projectId,
        name: name,
        filePath: url,
        fileSizeMB: 0.0,
        format: format.toUpperCase(),
        createdAt: DateTime.now(),
      );

      final currentCatalog = await loadCatalog();
      final updatedCatalog = [cloudProject, ...currentCatalog];
      await saveCatalog(updatedCatalog);

      return cloudProject;
    } catch (e, stack) {
      developer.log(
        'Erro ao registrar projeto de nuvem',
        error: e,
        stackTrace: stack,
        name: 'StorageService',
      );
      rethrow;
    }
  }

  /// Remove o projeto do catálogo JSON e deleta o arquivo físico do disco local.
  Future<bool> deleteProject(String projectId) async {
    try {
      final currentCatalog = await loadCatalog();
      final index = currentCatalog.indexWhere((p) => p.id == projectId);
      if (index == -1) {
        return false;
      }

      final projectToDelete = currentCatalog[index];

      // Remove arquivo físico se existir localmente
      if (projectToDelete.filePath.isNotEmpty) {
        try {
          final file = File(projectToDelete.filePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          developer.log(
            'Aviso: falha ao remover arquivo físico (${projectToDelete.filePath}), prosseguindo remoção do catálogo.',
            error: e,
            name: 'StorageService',
          );
        }
      }

      // Atualiza catálogo no JSON
      currentCatalog.removeAt(index);
      return await saveCatalog(currentCatalog);
    } catch (e, stack) {
      developer.log(
        'Erro ao excluir projeto',
        error: e,
        stackTrace: stack,
        name: 'StorageService',
      );
      return false;
    }
  }
}
