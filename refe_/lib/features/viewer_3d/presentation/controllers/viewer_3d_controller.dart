import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
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

  // Estado da Visualização Dinâmica Horizontal (Split-Screen Personalizável + Níveis + Specs openBIM)
  bool _isDynamicViewActive = false;
  bool _isSwitchingDynamicElement = false;
  double _dynamicSplitRatio = 0.46; // 46% Viewport 3D (perto da câmera) | 54% Especificações e Projeto
  int? _selectedStoreyFilterId; // null = Todos os Níveis (Projeto Completo)
  bool _highlightSimilarIn3D = false;
  bool _isDynamicXrayActive = false;
  bool _hadSimilarHighlightsInJs = false;
  bool _hadXrayInJs = false;
  BimProjectSpecs? _projectSpecs;
  BimElementMetadata? _preDynamicElement;
  int? _preDynamicIsolatedElementId;
  bool _wasLandscapeBeforeDynamic = false;
  Timer? _viewportResizeTimer;
  Timer? _elementSwitchWatchdog;
  bool _isDisposed = false;

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

  // Getters da Visualização Dinâmica Horizontal
  bool get isDynamicViewActive => _isDynamicViewActive;
  bool get isSwitchingDynamicElement => _isSwitchingDynamicElement;
  double get dynamicSplitRatio => _dynamicSplitRatio;
  int? get selectedStoreyFilterId => _selectedStoreyFilterId;
  bool get highlightSimilarIn3D => _highlightSimilarIn3D;
  bool get isDynamicXrayActive => _isDynamicXrayActive;
  BimProjectSpecs? get projectSpecs => _projectSpecs;
  List<BimStoreyInfo> get availableStoreys => _projectSpecs?.storeys ?? const [];

  /// Registra o InAppWebViewController e configura a JS Bridge bidirecional.
  void setWebViewController(InAppWebViewController controller) {
    _webViewController = controller;
    _jsBridge.attach(controller, this);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _viewportResizeTimer?.cancel();
    _elementSwitchWatchdog?.cancel();
    if (_isDynamicViewActive) {
      _restorePreviousOrientationSafe();
    }
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
  void onBimProjectSpecsLoaded(BimProjectSpecs specs) {
    _projectSpecs = specs;
    notifyListeners();
  }

  @override
  void onElementSelected(BimElementMetadata metadata) {
    if (_isDisposed) return;
    final previousId = _selectedElement?.expressID;
    _selectedElement = metadata;

    if (_isDynamicViewActive) {
      // Se o filtro atual apontava para um pavimento inexistente, reseta para Todos os Níveis
      if (_selectedStoreyFilterId != null &&
          availableStoreys.isNotEmpty &&
          !availableStoreys.any((s) => s.expressID == _selectedStoreyFilterId)) {
        _selectedStoreyFilterId = null;
      }

      // Evita chamadas JS duplicadas quando selectElementByExpressId já focou e atualizou subsets no WebGL
      if (!metadata.alreadyFocusedInJs) {
        if (previousId != metadata.expressID) {
          _jsBridge.focusElementInDynamicView(metadata.expressID);
        }
        _syncDynamic3DHighlights();
      }
    }

    notifyListeners();
    _completeDynamicTransitionAfterFrame();
  }

  @override
  void onElementTransitionBusy(int expressID) {
    if (_isDisposed) return;
    _cancelDynamicTransitionImmediate();
  }

  @override
  void onElementDeselected() {
    if (_isDisposed) return;
    // Na Visualização Dinâmica, mantém o elemento atual inspecionado sem disparar loop de resseleção
    if (_isDynamicViewActive && _selectedElement != null) {
      return;
    }

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
    _cancelDynamicTransitionImmediate(notify: false);
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
  // COMANDOS DA VISUALIZAÇÃO DINÂMICA HORIZONTAL
  // =========================================================================

  /// Ativa a Visualização Dinâmica: salva o estado anterior (isolamento, orientação e câmera),
  /// gira a tela para horizontal (landscape com câmera à esquerda) e enquadra o elemento na obra.
  Future<void> enterDynamicView({bool currentlyLandscape = false}) async {
    if (_selectedElement == null) return;

    _viewportResizeTimer?.cancel();
    _cancelDynamicTransitionImmediate(notify: false);
    if (!_isDynamicViewActive) {
      _preDynamicElement = _selectedElement;
      _preDynamicIsolatedElementId = _isolatedElementId;
      _wasLandscapeBeforeDynamic = currentlyLandscape;
    }

    _isDynamicViewActive = true;
    _isMeasureMode = false;
    _selectedStoreyFilterId = null;
    _hadSimilarHighlightsInJs = false;
    _hadXrayInJs = false;
    notifyListeners();

    _lockLandscapeOrientationSafe();

    final expressID = _selectedElement!.expressID;
    await _jsBridge.enterDynamicViewMode(expressID);
  }

  /// Sai da Visualização Dinâmica e restaura fielmente como estava antes:
  /// orientação anterior (retrato), posição/alvo/frustum da câmera 3D, estado de isolamento, materiais sem Raio-X e TabBar.
  Future<void> exitDynamicView() async {
    if (!_isDynamicViewActive) return;

    _cancelDynamicTransitionImmediate(notify: false);
    _isDynamicViewActive = false;
    _highlightSimilarIn3D = false;
    _isDynamicXrayActive = false;
    _hadSimilarHighlightsInJs = false;
    _hadXrayInJs = false;
    _selectedStoreyFilterId = null;
    if (_preDynamicElement != null) {
      _selectedElement = _preDynamicElement;
    }
    _isolatedElementId = _preDynamicIsolatedElementId;
    _preDynamicElement = null;
    notifyListeners();

    await _jsBridge.exitDynamicViewMode();
    _restorePreviousOrientationSafe();

    // Reajusta o tamanho do canvas WebGL após o retorno da rotação e da AppBar
    _viewportResizeTimer?.cancel();
    _viewportResizeTimer = Timer(const Duration(milliseconds: 320), () {
      if (!_isDisposed) {
        _jsBridge.notifyViewportResized();
      }
    });
  }

  /// Atualiza a proporção da divisória horizontal (entre 28% e 72% para a janela 3D à esquerda).
  void setDynamicSplitRatio(double ratio) {
    final clamped = ratio.clamp(0.28, 0.72);
    if ((_dynamicSplitRatio - clamped).abs() < 0.002) return;
    _dynamicSplitRatio = clamped;
    notifyListeners();
    _jsBridge.notifyViewportResized();
  }

  /// Restaura a proporção equilibrada padrão da divisória (46% 3D / 54% Especificações do Projeto).
  void resetDynamicSplitRatio() {
    _dynamicSplitRatio = 0.46;
    notifyListeners();
    _jsBridge.notifyViewportResized();
    if (_selectedElement != null && !_isSwitchingDynamicElement) {
      _jsBridge.focusElementInDynamicView(_selectedElement!.expressID);
    }
  }

  /// Altera o Nível (`IfcBuildingStorey`) selecionado no DropdownList da Visualização Dinâmica.
  Future<void> setStoreyFilter(int? storeyId) async {
    if (_isSwitchingDynamicElement) return;
    _selectedStoreyFilterId = storeyId;
    notifyListeners();
    await _syncDynamic3DHighlights();
  }

  /// Alterna o destaque 3D de todas as peças idênticas existentes no nível selecionado.
  Future<void> toggleHighlightSimilarIn3D() async {
    if (_isSwitchingDynamicElement) return;
    _highlightSimilarIn3D = !_highlightSimilarIn3D;
    notifyListeners();
    await _syncDynamic3DHighlights();
  }

  /// Alterna o modo Contexto Raio-X da Obra (edifício translúcido destacando a peça em inspeção).
  Future<void> toggleDynamicXrayContext() async {
    if (_isSwitchingDynamicElement) return;
    _isDynamicXrayActive = !_isDynamicXrayActive;
    notifyListeners();
    await _syncDynamic3DHighlights();
  }

  /// Reenquadra a câmera 3D diretamente sobre a peça atual na obra.
  Future<void> focusCurrentElementInDynamicView() async {
    if (_selectedElement == null || _isSwitchingDynamicElement) return;
    await _jsBridge.focusElementInDynamicView(_selectedElement!.expressID);
  }

  /// Navega entre as instâncias da mesma peça no nível selecionado (ex: Pilar 2 de 146)
  /// exigindo conclusão integral do carregamento e renderização atual antes de aceitar novo clique.
  Future<void> inspectPieceInstance(int expressID) async {
    if (_isSwitchingDynamicElement) return;
    if (_selectedElement?.expressID == expressID) {
      await _jsBridge.focusElementInDynamicView(expressID);
      return;
    }

    _beginDynamicTransition();
    try {
      await _jsBridge.selectElementByExpressId(expressID, focusCamera: true);
    } catch (_) {
      _cancelDynamicTransitionImmediate();
    }
  }

  void _beginDynamicTransition() {
    _isSwitchingDynamicElement = true;
    _elementSwitchWatchdog?.cancel();
    _elementSwitchWatchdog = Timer(const Duration(seconds: 4), () {
      if (!_isDisposed && _isSwitchingDynamicElement) {
        _isSwitchingDynamicElement = false;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void _completeDynamicTransitionAfterFrame() {
    _elementSwitchWatchdog?.cancel();
    _elementSwitchWatchdog = null;
    if (!_isSwitchingDynamicElement) return;

    try {
      final scheduler = SchedulerBinding.instance;
      if (scheduler.hasScheduledFrame || scheduler.schedulerPhase != SchedulerPhase.idle) {
        scheduler.addPostFrameCallback((_) {
          if (!_isDisposed && _isSwitchingDynamicElement) {
            _isSwitchingDynamicElement = false;
            notifyListeners();
          }
        });
        return;
      }
    } catch (_) {
      // Ambiente de teste unitário puro sem SchedulerBinding ativo
    }

    Future.microtask(() {
      if (!_isDisposed && _isSwitchingDynamicElement) {
        _isSwitchingDynamicElement = false;
        notifyListeners();
      }
    });
  }

  void _cancelDynamicTransitionImmediate({bool notify = true}) {
    _elementSwitchWatchdog?.cancel();
    _elementSwitchWatchdog = null;
    if (_isSwitchingDynamicElement) {
      _isSwitchingDynamicElement = false;
      if (notify && !_isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<void> _syncDynamic3DHighlights() async {
    final elem = _selectedElement;
    if (elem == null) return;

    final instancesInFilter = elem.analytics?.instancesForStorey(_selectedStoreyFilterId) ?? [elem.expressID];

    if (_highlightSimilarIn3D && instancesInFilter.isNotEmpty) {
      _hadSimilarHighlightsInJs = true;
      await _jsBridge.highlightSimilarElements(
        instancesInFilter,
        activeExpressID: elem.expressID,
      );
    } else if (_hadSimilarHighlightsInJs) {
      _hadSimilarHighlightsInJs = false;
      await _jsBridge.clearSimilarHighlights();
    }

    if (_isDynamicXrayActive) {
      _hadXrayInJs = true;
      final keepIds = _highlightSimilarIn3D && instancesInFilter.isNotEmpty
          ? instancesInFilter
          : [elem.expressID];
      await _jsBridge.setDynamicXrayContext(true, keepIds);
    } else if (_hadXrayInJs) {
      _hadXrayInJs = false;
      await _jsBridge.setDynamicXrayContext(false, const []);
    }
  }

  void _lockLandscapeOrientationSafe() {
    try {
      // landscapeLeft coloca o topo físico do aparelho (câmera frontal) à esquerda da tela horizontal
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]).catchError((_) {});
    } catch (_) {}
  }

  void _restorePreviousOrientationSafe() {
    try {
      if (_wasLandscapeBeforeDynamic) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]).catchError((_) {});
      } else {
        // Mantém fixo em portraitUp para evitar que o acelerômetro gire de volta para horizontal
        // caso o usuário ainda esteja segurando o celular deitado no instante em que clicou em Voltar.
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]).catchError((_) {});
      }
    } catch (_) {}
  }

  // =========================================================================
  // COMANDOS DE AÇÃO (FLUTTER -> JS BRIDGE)
  // =========================================================================

  /// Realiza streaming HTTP local (ou leitura direta) e injeta o modelo BIM no motor WebGL via JS.
  Future<void> loadModelFile(String filePath, String format) async {
    _cancelDynamicTransitionImmediate(notify: false);
    if (_isDynamicViewActive) {
      _isDynamicViewActive = false;
      _restorePreviousOrientationSafe();
    }
    _isLoading = true;
    _loadingProgress = 5.0;
    _errorMessage = null;
    _selectedElement = null;
    _projectSpecs = null;
    _selectedStoreyFilterId = null;
    _highlightSimilarIn3D = false;
    _isDynamicXrayActive = false;
    _hadSimilarHighlightsInJs = false;
    _hadXrayInJs = false;
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
    _cancelDynamicTransitionImmediate(notify: false);
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
