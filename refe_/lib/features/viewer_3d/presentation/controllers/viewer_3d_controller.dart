import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../core/services/localhost_server_service.dart';
import '../../data/services/viewer_3d_js_bridge.dart';
import '../../domain/models/bim_element_metadata.dart';
import '../../domain/models/measurement_model.dart';

export '../../domain/models/bim_element_metadata.dart';

/// Controller reativo responsável pelo gerenciamento de estado da UI e
/// coordenação com a Viewport 3D WebGL através do [Viewer3dJsBridge].
class Viewer3DController extends ChangeNotifier implements Viewer3dJsBridgeListener {
  final Viewer3dJsBridge _jsBridge;
  InAppWebViewController? _webViewController;

  bool _isViewerReady = false;
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  String? _errorMessage;
  BimElementMetadata? _selectedElement;
  final Set<int> _hiddenElementIds = {};
  final Map<int, BimElementMetadata> _hiddenElementsMap = {};
  bool _isGhostPreviewActive = false;
  int? _isolatedElementId;

  // Estado do Modo de Medição de Vãos Livres 3D
  bool _isMeasureMode = false;
  String _measureSubMode = 'span'; // 'span' (vão livre 1 toque) ou 'point_to_point' (2 toques)
  final List<MeasurementModel> _measurements = [];
  MeasurementModel? _lastMeasurement;
  bool _isWaitingSecondPoint = false;
  String? _measureStatusMessage;

  // Estado de Navegação Técnica e Plano de Corte (Padrão Autodesk Fusion / BIM 360)
  bool _isSectionCutActive = false;
  double _sectionCutRatio = 0.75;
  String _currentCameraView = 'iso';
  bool _renderProcessCrashed = false;

  String? _pendingFilePath;
  String? _pendingFormat;

  Viewer3DController({Viewer3dJsBridge? jsBridge})
      : _jsBridge = jsBridge ?? Viewer3dJsBridge();

  InAppWebViewController? get webViewController => _webViewController;
  bool get isViewerReady => _isViewerReady;
  bool get isLoading => _isLoading;
  double get loadingProgress => _loadingProgress;
  String? get errorMessage => _errorMessage;
  BimElementMetadata? get selectedElement => _selectedElement;
  Set<int> get hiddenElementIds => Set.unmodifiable(_hiddenElementIds);
  bool get hasHiddenElements => _hiddenElementIds.isNotEmpty;
  bool get isGhostPreviewActive => _isGhostPreviewActive;
  List<BimElementMetadata> get hiddenElements {
    return _hiddenElementIds.map((id) {
      return _hiddenElementsMap[id] ??
          BimElementMetadata(
            expressID: id,
            name: 'Elemento BIM #$id',
            category: 'IfcBuildingElement',
            psets: {},
          );
    }).toList();
  }
  int? get isolatedElementId => _isolatedElementId;
  bool get isIsolated => _isolatedElementId != null;
  int get hiddenCount => _hiddenElementIds.length;
  bool isHidden(int expressID) => _hiddenElementIds.contains(expressID);
  bool isElementIsolated(int expressID) => _isolatedElementId == expressID;

  // Getters do Modo de Medição
  bool get isMeasureMode => _isMeasureMode;
  String get measureSubMode => _measureSubMode;
  List<MeasurementModel> get measurements => List.unmodifiable(_measurements);
  MeasurementModel? get lastMeasurement => _lastMeasurement;
  bool get hasMeasurements => _measurements.isNotEmpty;
  int get measurementCount => _measurements.length;
  bool get isWaitingSecondPoint => _isWaitingSecondPoint;
  String? get measureStatusMessage => _measureStatusMessage;

  // Getters de Navegação Técnica e Resiliência (BIM 360 / Fusion)
  bool get isSectionCutActive => _isSectionCutActive;
  double get sectionCutRatio => _sectionCutRatio;
  String get currentCameraView => _currentCameraView;
  bool get renderProcessCrashed => _renderProcessCrashed;

  /// Registra o InAppWebViewController e configura a JS Bridge bidirecional.
  void setWebViewController(InAppWebViewController controller) {
    _webViewController = controller;
    _jsBridge.attach(controller, this);
  }

  @override
  void dispose() {
    _jsBridge.detach();
    super.dispose();
  }

  // =========================================================================
  // IMPLEMENTAÇÃO DE Viewer3dJsBridgeListener (Eventos recebidos do JS)
  // =========================================================================

  @override
  void onViewerReady() {
    _isViewerReady = true;
    _isLoading = false;
    notifyListeners();

    // Se havia modelo pendente antes da inicialização completa, injeta agora
    if (_pendingFilePath != null && _pendingFormat != null) {
      loadModelFile(_pendingFilePath!, _pendingFormat!);
      _pendingFilePath = null;
      _pendingFormat = null;
    }
  }

  @override
  void onLoadingProgress(double progress) {
    _loadingProgress = progress;
    _isLoading = progress < 100.0;
    notifyListeners();
  }

  @override
  void onElementSelected(BimElementMetadata metadata) {
    _selectedElement = metadata;
    notifyListeners();
  }

  @override
  void onElementDeselected() {
    if (_selectedElement != null) {
      _selectedElement = null;
      notifyListeners();
    }
  }

  @override
  void onVisibilityChanged({required bool isIsolated, int? isolatedId}) {
    _isolatedElementId = isIsolated ? isolatedId : null;
    notifyListeners();
  }

  @override
  void onViewerError(String message) {
    _errorMessage = message;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void onMeasureModeChanged({required bool enabled, required String mode}) {
    _isMeasureMode = enabled;
    _measureSubMode = mode;
    if (!_isMeasureMode) {
      _isWaitingSecondPoint = false;
      _measureStatusMessage = null;
    }
    notifyListeners();
  }

  @override
  void onMeasurementCreated(MeasurementModel measurement) {
    _measurements.add(measurement);
    _lastMeasurement = measurement;
    _isWaitingSecondPoint = false;
    _measureStatusMessage = measurement.isSpan
        ? 'Vão livre detectado: ${measurement.formattedDistance}'
        : 'Distância medida: ${measurement.formattedDistance}';
    notifyListeners();
  }

  @override
  void onMeasurementWaitingPoint({required bool isWaiting, String? message}) {
    _isWaitingSecondPoint = isWaiting;
    _measureStatusMessage = message;
    notifyListeners();
  }

  @override
  void onMeasurementRemoved() {
    if (_measurements.isNotEmpty) {
      _measurements.removeLast();
      _lastMeasurement = _measurements.isNotEmpty ? _measurements.last : null;
      _isWaitingSecondPoint = false;
      _measureStatusMessage = null;
      notifyListeners();
    }
  }

  @override
  void onMeasurementCleared() {
    _measurements.clear();
    _lastMeasurement = null;
    _isWaitingSecondPoint = false;
    _measureStatusMessage = null;
    notifyListeners();
  }

  // =========================================================================
  // COMANDOS DE AÇÃO (FLUTTER -> JS BRIDGE)
  // =========================================================================

  /// Realiza streaming HTTP local (ou leitura direta) e injeta o modelo BIM no motor WebGL via JS.
  Future<void> loadModelFile(String filePath, String format) async {
    _isLoading = true;
    _loadingProgress = 5.0;
    _errorMessage = null;
    _selectedElement = null;
    _hiddenElementIds.clear();
    _hiddenElementsMap.clear();
    _isolatedElementId = null;
    _isGhostPreviewActive = false;
    _isMeasureMode = false;
    _measurements.clear();
    _lastMeasurement = null;
    _isWaitingSecondPoint = false;
    _measureStatusMessage = null;
    _isSectionCutActive = false;
    _sectionCutRatio = 0.75;
    _currentCameraView = 'iso';
    _renderProcessCrashed = false;
    notifyListeners();

    if (!_isViewerReady || !_jsBridge.isAttached) {
      developer.log('Viewer ainda não está pronto. Enfileirando carregamento de: $filePath', name: 'Viewer3DController');
      _pendingFilePath = filePath;
      _pendingFormat = format;
      return;
    }

    try {
      final cleanFormat = format.toUpperCase();
      final isRemoteUrl = filePath.startsWith('http://') || filePath.startsWith('https://');

      if (isRemoteUrl) {
        _loadingProgress = 12.0;
        notifyListeners();
        await _jsBridge.loadModelFromUrl(filePath, cleanFormat);
        return;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        throw FileSystemException('Arquivo do modelo BIM não encontrado no disco local', filePath);
      }

      _loadingProgress = 10.0;
      notifyListeners();

      // Prioriza streaming HTTP local 100% offline para evitar estouro de memória/IPC em modelos grandes (ex: 90+ MB)
      final streamUrl = await LocalhostServerService.registerModelFile(filePath);
      if (streamUrl != null) {
        await _jsBridge.loadModelFromUrl(streamUrl, cleanFormat);
        return;
      }

      // Fallback em Base64 apenas caso o servidor de streaming local não esteja disponível
      final Uint8List bytes = await file.readAsBytes();
      final String base64Data = base64Encode(bytes);

      _loadingProgress = 35.0;
      notifyListeners();

      await _jsBridge.loadModelBase64(base64Data, cleanFormat);
    } catch (e, stack) {
      developer.log('Falha ao carregar modelo no visualizador 3D', error: e, stackTrace: stack, name: 'Viewer3DController');
      _errorMessage = 'Falha ao carregar modelo: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Dispara o comando para restaurar o ponto de vista da câmera no JS.
  Future<void> resetCamera() async {
    _currentCameraView = 'iso';
    notifyListeners();
    await _jsBridge.resetCamera();
  }

  /// Altera o ângulo da câmera para vistas técnicas predefinidas estilo ViewCube ('iso', 'top', 'front', 'right', 'left', 'back').
  Future<void> setCameraView(String view) async {
    _currentCameraView = view.toLowerCase();
    notifyListeners();
    await _jsBridge.setCameraView(_currentCameraView);
  }

  /// Alterna o Plano de Corte Horizontal (Section Cut estilo BIM 360 / Fusion).
  Future<void> toggleSectionCut() async {
    _isSectionCutActive = !_isSectionCutActive;
    notifyListeners();
    await _jsBridge.setSectionCut(_isSectionCutActive, _sectionCutRatio);
  }

  /// Atualiza a altura percentual (0.05 a 1.0) do Plano de Corte Horizontal em tempo real.
  Future<void> setSectionCutRatio(double ratio) async {
    _sectionCutRatio = ratio.clamp(0.05, 1.0);
    if (!_isSectionCutActive) {
      _isSectionCutActive = true;
    }
    notifyListeners();
    await _jsBridge.setSectionCut(true, _sectionCutRatio);
  }

  /// Intercepta quedas do processo de renderização da WebView (ex: OOM do Android) evitando que o app feche.
  void handleRenderProcessGone(bool didCrash) {
    developer.log(
      'Processo de renderização WebView encerrado pelo sistema (didCrash: $didCrash)',
      name: 'Viewer3DController',
    );
    _isViewerReady = false;
    _isLoading = false;
    _renderProcessCrashed = true;
    _errorMessage = 'O motor gráfico 3D precisou liberar memória do dispositivo. Toque em "Tentar novamente" para recarregar o modelo com segurança.';
    notifyListeners();
  }

  /// Prepara o controller para recriação limpa da WebView após recuperação de processo.
  void prepareWebViewRecovery(String filePath, String format) {
    _renderProcessCrashed = false;
    _errorMessage = null;
    _isViewerReady = false;
    _isLoading = true;
    _loadingProgress = 5.0;
    _pendingFilePath = filePath;
    _pendingFormat = format;
    notifyListeners();
  }

  /// Oculta o elemento atualmente selecionado no motor 3D e retorna seus metadados.
  Future<BimElementMetadata?> hideSelectedElement() async {
    if (_selectedElement == null) return null;
    final element = _selectedElement!;
    _hiddenElementIds.add(element.expressID);
    _hiddenElementsMap[element.expressID] = element;
    if (_isolatedElementId == element.expressID) {
      _isolatedElementId = null;
    }
    _selectedElement = null;
    notifyListeners();

    await _jsBridge.hideElement(element.expressID);
    return element;
  }

  /// Reexibe um elemento específico previamente ocultado.
  Future<void> showElement(int expressID) async {
    _hiddenElementIds.remove(expressID);
    _hiddenElementsMap.remove(expressID);
    if (_hiddenElementIds.isEmpty) {
      _isGhostPreviewActive = false;
    }
    notifyListeners();

    await _jsBridge.showElement(expressID);
  }

  /// Isola o elemento selecionado, ocultando todos os outros elementos da cena 3D.
  /// Se o mesmo elemento já estiver isolado, restaura a visibilidade normal.
  Future<void> isolateSelectedElement() async {
    if (_selectedElement == null) return;
    final id = _selectedElement!.expressID;
    if (_isolatedElementId == id) {
      _isolatedElementId = null;
    } else {
      _isolatedElementId = id;
    }
    notifyListeners();

    await _jsBridge.isolateElement(id);
  }

  /// Restaura a visibilidade completa do modelo (desfaz isolamentos e ocultações).
  Future<void> restoreAllVisibility() async {
    _hiddenElementIds.clear();
    _hiddenElementsMap.clear();
    _isolatedElementId = null;
    _isGhostPreviewActive = false;
    notifyListeners();

    await _jsBridge.restoreAllVisibility();
  }

  /// Ativa ou desativa a pré-visualização translúcida fantasma (raio-X) dos elementos ocultos no 3D.
  Future<void> setGhostPreview(bool active) async {
    _isGhostPreviewActive = active;
    notifyListeners();

    await _jsBridge.previewHiddenElements(active);
  }

  /// Limpa a seleção do elemento atual sincronizando com o JavaScript.
  Future<void> clearSelectedElement() async {
    _selectedElement = null;
    notifyListeners();

    await _jsBridge.clearSelection();
  }

  /// Alterna entre ativar e desativar o Modo de Medição de Vãos Livres
  Future<void> toggleMeasureMode() async {
    final nextState = !_isMeasureMode;
    await setMeasureMode(nextState, mode: _measureSubMode);
  }

  /// Ativa ou desativa o Modo de Medição de Vãos Livres (spans) e distâncias
  Future<void> setMeasureMode(bool enabled, {String mode = 'span'}) async {
    _isMeasureMode = enabled;
    _measureSubMode = mode;
    _isWaitingSecondPoint = false;
    if (enabled) {
      _selectedElement = null;
    }
    notifyListeners();

    await _jsBridge.setMeasureMode(enabled, mode: mode);
  }

  /// Alterna o submodo de medição ('span' = vão livre 1 toque, 'point_to_point' = 2 toques)
  Future<void> setMeasureSubMode(String mode) async {
    _measureSubMode = mode;
    _isWaitingSecondPoint = false;
    notifyListeners();

    await _jsBridge.setMeasureSubMode(mode);
  }

  /// Limpa todas as medições e cotas ativas na cena 3D
  Future<void> clearMeasurements() async {
    _measurements.clear();
    _lastMeasurement = null;
    _isWaitingSecondPoint = false;
    _measureStatusMessage = null;
    _isSectionCutActive = false;
    _sectionCutRatio = 0.75;
    _currentCameraView = 'iso';
    _renderProcessCrashed = false;
    notifyListeners();

    await _jsBridge.clearMeasurements();
  }

  /// Remove a última medição realizada (ação de desfazer)
  Future<void> removeLastMeasurement() async {
    if (_measurements.isNotEmpty) {
      _measurements.removeLast();
      _lastMeasurement = _measurements.isNotEmpty ? _measurements.last : null;
      _isWaitingSecondPoint = false;
      notifyListeners();
    }

    await _jsBridge.removeLastMeasurement();
  }
}
