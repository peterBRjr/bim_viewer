import 'package:flutter/foundation.dart';
import '../../data/services/file_picker_service.dart';
import '../../data/services/storage_service.dart';
import '../../domain/models/project_model.dart';

/// Controller reativo responsável pelo gerenciamento de estado da tela inicial (Home).
/// Orquestra a persistência local com o [StorageService] e a seleção de arquivos com o [FilePickerService].
class HomeController extends ChangeNotifier {
  final StorageService _storageService;
  final FilePickerService _filePickerService;

  List<ProjectModel> _projects = [];
  bool _isLoading = false;
  String? _errorMessage;

  HomeController({
    StorageService? storageService,
    FilePickerService? filePickerService,
  })  : _storageService = storageService ?? StorageService(),
        _filePickerService = filePickerService ?? FilePickerService();

  /// Lista de projetos cadastrados (somente leitura para componentes externos).
  List<ProjectModel> get projects => List.unmodifiable(_projects);

  /// Indica se há uma operação assíncrona em andamento.
  bool get isLoading => _isLoading;

  /// Mensagem de erro da última operação (se houver).
  String? get errorMessage => _errorMessage;

  /// Quantidade total de projetos no catálogo.
  int get projectsCount => _projects.length;

  /// Indica se a lista está vazia.
  bool get isEmpty => _projects.isEmpty;

  /// Carrega o catálogo de projetos locais persistidos.
  Future<void> loadProjects() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      _projects = await _storageService.loadCatalog();
    } catch (e) {
      _errorMessage = 'Falha ao carregar o catálogo de projetos: ${e.toString()}';
    } finally {
      _setLoading(false);
    }
  }

  /// Abre o seletor nativo, faz a cópia física segura para `projects/`
  /// e atualiza o catálogo de projetos.
  Future<ProjectModel?> importLocalProject() async {
    _errorMessage = null;

    try {
      final selectedFile = await _filePickerService.pickBimFile();
      if (selectedFile == null) {
        return null; // Usuário cancelou a seleção
      }

      _setLoading(true);

      // Copia física defensiva e persistência de metadados
      final newProject = await _storageService.saveLocalProjectFile(
        sourcePath: selectedFile.path,
        originalName: selectedFile.name,
        fileSizeMB: selectedFile.sizeMB,
        format: selectedFile.format,
      );

      _projects = [newProject, ..._projects];
      notifyListeners();
      return newProject;
    } catch (e) {
      _errorMessage = 'Erro ao importar arquivo BIM: ${e.toString()}';
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Registra um modelo BIM disponível via URL / Cloud Storage.
  Future<ProjectModel?> importCloudProject(String name, String url, {String format = 'IFC'}) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final cloudProject = await _storageService.saveCloudProject(
        name: name,
        url: url,
        format: format,
      );

      _projects = [cloudProject, ..._projects];
      notifyListeners();
      return cloudProject;
    } catch (e) {
      _errorMessage = 'Erro ao registrar projeto da nuvem: ${e.toString()}';
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Exclui o projeto do catálogo JSON e remove o arquivo físico correspondente.
  Future<bool> deleteProject(String id) async {
    _errorMessage = null;

    try {
      final success = await _storageService.deleteProject(id);
      if (success) {
        _projects.removeWhere((p) => p.id == id);
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Não foi possível encontrar o projeto para exclusão.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Erro ao excluir projeto: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
