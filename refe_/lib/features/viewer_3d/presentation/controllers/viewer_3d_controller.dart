import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../core/services/localhost_server_service.dart';
import '../../domain/models/measurement_model.dart';

/// Metadados de um elemento BIM selecionado via Raycaster na Viewport 3D.
class BimElementMetadata {
  final int expressID;
  final String name;
  final String category;
  final Map<String, dynamic> psets;
  final List<int> subIds;
  final bool isComposite;

  const BimElementMetadata({
    required this.expressID,
    required this.name,
    required this.category,
    required this.psets,
    this.subIds = const [],
    this.isComposite = false,
  });

  factory BimElementMetadata.fromMap(Map<String, dynamic> map) {
    final subIdsRaw = (map['subIds'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
    return BimElementMetadata(
      expressID: (map['expressID'] as num?)?.toInt() ?? 0,
      name: map['name']?.toString() ?? 'Elemento Desconhecido',
      category: map['category']?.toString() ?? 'IfcBuildingElementProxy',
      psets: (map['psets'] as Map?)?.cast<String, dynamic>() ?? {},
      subIds: subIdsRaw,
      isComposite: map['isComposite'] == true || subIdsRaw.length > 1,
    );
  }

  /// Decodifica caracteres ISO-10303-21 comuns do Revit (ex: \X\E7 -> ç, \X\ED -> í)
  static String decodeIfcString(String text) {
    if (!text.contains(r'\X\') && !text.contains(r'\X2\')) return text;
    var result = text;
    final Map<String, String> ifcMap = {
      r'\X\E1': 'á', r'\X\E9': 'é', r'\X\ED': 'í', r'\X\F3': 'ó', r'\X\FA': 'ú',
      r'\X\E3': 'ã', r'\X\F5': 'õ', r'\X\E2': 'â', r'\X\EA': 'ê', r'\X\F4': 'ô',
      r'\X\E7': 'ç', r'\X\C1': 'Á', r'\X\C9': 'É', r'\X\CD': 'Í', r'\X\D3': 'Ó',
      r'\X\DA': 'Ú', r'\X\C3': 'Ã', r'\X\D5': 'Õ', r'\X\C2': 'Â', r'\X\CA': 'Ê',
      r'\X\D4': 'Ô', r'\X\C7': 'Ç', r'\X\AA': 'ª', r'\X\BA': 'º', r'\X\E0': 'à',
      r'\X\C0': 'À',
    };
    ifcMap.forEach((key, val) {
      result = result.replaceAll(key, val);
    });
    return result;
  }

  /// Retorna o nome amigável e limpo para visualização na maquete de bolso.
  String get displayName => cleanTitle;

  /// Extrai o nome do tipo limpo (ex: "Telhado básico:Telhado ventilado - Concreto:331235" -> "Telhado ventilado - Concreto")
  String get cleanTitle {
    final decoded = decodeIfcString(name).trim();
    if (decoded.isEmpty || decoded == 'null') {
      return '$friendlyCategory #$expressID';
    }
    final withoutBrackets = decoded.replaceAll(RegExp(r'\s*\[\d+\]$'), '');
    if (withoutBrackets.contains(':')) {
      final parts = withoutBrackets.split(':').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (parts.length >= 2 && !RegExp(r'^\d+$').hasMatch(parts[1])) {
        return parts[1];
      }
      return parts[0];
    }
    return withoutBrackets;
  }

  /// Família / Categoria do Revit (ex: "Telhado básico", "Parede básica")
  String? get familyName {
    final decoded = decodeIfcString(name).trim();
    if (decoded.contains(':')) {
      final parts = decoded.split(':').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (parts.length >= 2 && !RegExp(r'^\d+$').hasMatch(parts[1])) {
        return parts[0];
      }
    }
    return null;
  }

  /// Tradução amigável da categoria IFC para português.
  String get friendlyCategory {
    final cat = category.toLowerCase();
    if (cat.contains('wall') || cat.contains('parede')) return 'Parede';
    if (cat.contains('door') || cat.contains('porta')) return 'Porta';
    if (cat.contains('window') || cat.contains('janela')) return 'Janela';
    if (cat.contains('slab') || cat.contains('laje') || cat.contains('piso') || cat.contains('floor')) return 'Laje / Piso';
    if (cat.contains('column') || cat.contains('pilar') || cat.contains('coluna')) return 'Pilar';
    if (cat.contains('beam') || cat.contains('viga')) return 'Viga';
    if (cat.contains('roof') || cat.contains('telhado')) return 'Telhado';
    if (cat.contains('stair') || cat.contains('escada')) return 'Escada';
    if (cat.contains('railing') || cat.contains('guarda')) return 'Guarda-Corpo';
    if (cat.contains('pipe') || cat.contains('tubo')) return 'Tubulação';
    if (cat.contains('duct') || cat.contains('duto')) return 'Duto';
    if (cat.contains('covering') || cat.contains('forro')) return 'Forro';
    if (cat.contains('member')) return 'Perfil Estrutural';
    if (cat.contains('proxy')) return 'Elemento Genérico';
    return category.replaceAll('Ifc', '');
  }

  /// Ícone semântico representativo da categoria BIM.
  IconData get categoryIcon {
    final cat = category.toLowerCase();
    if (cat.contains('wall') || cat.contains('parede')) return Icons.view_week_outlined;
    if (cat.contains('door') || cat.contains('porta')) return Icons.meeting_room_outlined;
    if (cat.contains('window') || cat.contains('janela')) return Icons.window_rounded;
    if (cat.contains('slab') || cat.contains('laje') || cat.contains('piso')) return Icons.layers_outlined;
    if (cat.contains('column') || cat.contains('pilar')) return Icons.table_chart_outlined;
    if (cat.contains('beam') || cat.contains('viga')) return Icons.horizontal_rule_rounded;
    if (cat.contains('roof') || cat.contains('telhado')) return Icons.roofing_rounded;
    if (cat.contains('stair') || cat.contains('escada')) return Icons.stairs_rounded;
    if (cat.contains('railing')) return Icons.fence_rounded;
    return Icons.view_in_ar_rounded;
  }

  /// Formata números decimais para o padrão da construção civil brasileira (ex: 279,42 m²)
  static String formatNumberWithUnit(dynamic val, String unit) {
    if (val == null) return 'N/A';
    final strVal = val.toString().trim();
    final numVal = double.tryParse(strVal.replaceAll(',', '.'));
    if (numVal != null) {
      final formatted = numVal.toStringAsFixed(2).replaceAll('.', ',');
      return '$formatted $unit';
    }
    return strVal.endsWith(unit) ? strVal : '$strVal $unit';
  }

  /// Extrai as métricas de obra mais úteis (Área, Volume, Dimensões, Nível, Inclinação).
  Map<String, String> get keyMetrics {
    final Map<String, String> metrics = {};

    for (final pset in psets.values) {
      if (pset is Map) {
        for (final entry in pset.entries) {
          final key = entry.key.toString().toLowerCase();
          final val = decodeIfcString(entry.value.toString()).trim();

          if (metrics.length < 4) {
            if (key.contains('totalarea') || key == 'area' || key.contains('área')) {
              metrics['Área Total'] = formatNumberWithUnit(val, 'm²');
            } else if (key.contains('volume')) {
              metrics['Volume'] = formatNumberWithUnit(val, 'm³');
            } else if (key.contains('pitch') || key.contains('inclina')) {
              final numVal = double.tryParse(val.replaceAll(',', '.'));
              metrics['Caimento'] = numVal != null ? '${numVal.toStringAsFixed(0)}°' : '$val°';
            } else if (key.contains('length') || key.contains('comprimento')) {
              metrics['Comprimento'] = formatNumberWithUnit(val, 'm');
            } else if (key.contains('height') || key.contains('altura')) {
              metrics['Altura'] = formatNumberWithUnit(val, 'm');
            } else if (key.contains('width') || key.contains('espessura') || key.contains('largura')) {
              metrics['Espessura'] = formatNumberWithUnit(val, 'm');
            } else if (key.contains('level') || key.contains('nível') || key.contains('pavimento')) {
              metrics['Nível'] = val;
            }
          }
        }
      }
    }

    if (isComposite && !metrics.containsKey('Composição')) {
      metrics['Composição'] = '${subIds.length} partes';
    }

    if (metrics.isEmpty) {
      metrics['Elemento'] = '#$expressID';
      metrics['Categoria'] = friendlyCategory;
      metrics['Status'] = 'As-Built';
    }

    return metrics;
  }
}

/// Controller reativo responsável pela ponte de comunicação (JS Bridge) entre Flutter e WebGL.
class Viewer3DController extends ChangeNotifier {
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
    _registerJsHandlers(controller);
  }

  /// Registra os ouvintes nativos para chamadas originadas do JavaScript.
  void _registerJsHandlers(InAppWebViewController controller) {
    // 1. Notificação de inicialização da engine WebGL
    controller.addJavaScriptHandler(
      handlerName: 'onViewerReady',
      callback: (args) {
        developer.log('Engine 3D inicializada e pronta (onViewerReady)', name: 'Viewer3DController');
        _isViewerReady = true;
        _isLoading = false;
        notifyListeners();

        // Se havia modelo pendente antes da inicialização completa, injeta agora
        if (_pendingFilePath != null && _pendingFormat != null) {
          loadModelFile(_pendingFilePath!, _pendingFormat!);
          _pendingFilePath = null;
          _pendingFormat = null;
        }
      },
    );

    // 2. Progresso de decodificação e parsing do modelo
    controller.addJavaScriptHandler(
      handlerName: 'onLoadingProgress',
      callback: (args) {
        if (args.isNotEmpty && args[0] is Map) {
          final data = (args[0] as Map).cast<String, dynamic>();
          final progress = (data['progress'] as num?)?.toDouble() ?? 0.0;
          _loadingProgress = progress;
          _isLoading = progress < 100.0;
          notifyListeners();
        }
      },
    );

    // 3. Inspeção técnica: elemento selecionado via toque/clique no canvas
    controller.addJavaScriptHandler(
      handlerName: 'onElementSelected',
      callback: (args) {
        if (args.isNotEmpty && args[0] is Map) {
          final data = (args[0] as Map).cast<String, dynamic>();
          _selectedElement = BimElementMetadata.fromMap(data);
          notifyListeners();
        }
      },
    );

    // 4. Elemento deselecionado (ex: toque no fundo vazio do 3D)
    controller.addJavaScriptHandler(
      handlerName: 'onElementDeselected',
      callback: (args) {
        if (_selectedElement != null) {
          _selectedElement = null;
          notifyListeners();
        }
      },
    );

    // 5. Atualização de visibilidade consolidada (ocultação / isolamento)
    controller.addJavaScriptHandler(
      handlerName: 'onVisibilityChanged',
      callback: (args) {
        if (args.isNotEmpty && args[0] is Map) {
          final data = (args[0] as Map).cast<String, dynamic>();
          final isIsolated = data['isIsolated'] == true;
          final isolatedId = (data['isolatedId'] as num?)?.toInt();
          _isolatedElementId = isIsolated ? isolatedId : null;
          notifyListeners();
        }
      },
    );

    // 6. Captura defensiva de erros na renderização WebGL
    controller.addJavaScriptHandler(
      handlerName: 'onViewerError',
      callback: (args) {
        if (args.isNotEmpty && args[0] is Map) {
          final data = (args[0] as Map).cast<String, dynamic>();
          _errorMessage = data['message']?.toString() ?? 'Erro desconhecido na Viewport 3D';
          _isLoading = false;
          notifyListeners();
        }
      },
    );

    // 7. Notificações do Modo de Medição de Vãos e Distâncias 3D
    controller.addJavaScriptHandler(
      handlerName: 'onMeasureModeChanged',
      callback: (args) {
        if (args.isNotEmpty && args[0] is Map) {
          final data = (args[0] as Map).cast<String, dynamic>();
          _isMeasureMode = data['enabled'] == true;
          _measureSubMode = data['mode']?.toString() ?? 'span';
          if (!_isMeasureMode) {
            _isWaitingSecondPoint = false;
            _measureStatusMessage = null;
          }
          notifyListeners();
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onMeasurementCreated',
      callback: (args) {
        if (args.isNotEmpty && args[0] is Map) {
          final data = (args[0] as Map).cast<String, dynamic>();
          final measurement = MeasurementModel.fromMap(data);
          _measurements.add(measurement);
          _lastMeasurement = measurement;
          _isWaitingSecondPoint = false;
          _measureStatusMessage = measurement.isSpan
              ? 'Vão livre detectado: ${measurement.formattedDistance}'
              : 'Distância medida: ${measurement.formattedDistance}';
          notifyListeners();
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onMeasurementWaitingPoint',
      callback: (args) {
        if (args.isNotEmpty && args[0] is Map) {
          final data = (args[0] as Map).cast<String, dynamic>();
          final cancelled = data['cancelled'] == true;
          _isWaitingSecondPoint = !cancelled;
          _measureStatusMessage = cancelled ? null : data['message']?.toString();
          notifyListeners();
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onMeasurementRemoved',
      callback: (args) {
        if (_measurements.isNotEmpty) {
          _measurements.removeLast();
          _lastMeasurement = _measurements.isNotEmpty ? _measurements.last : null;
          _isWaitingSecondPoint = false;
          _measureStatusMessage = null;
          notifyListeners();
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onMeasurementCleared',
      callback: (args) {
        _measurements.clear();
        _lastMeasurement = null;
        _isWaitingSecondPoint = false;
        _measureStatusMessage = null;
        notifyListeners();
      },
    );
  }

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

    if (!_isViewerReady || _webViewController == null) {
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
        await _webViewController?.evaluateJavascript(
          source: 'window.loadBimModelFromUrl(${jsonEncode(filePath)}, ${jsonEncode(cleanFormat)});',
        );
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
        await _webViewController?.evaluateJavascript(
          source: 'window.loadBimModelFromUrl(${jsonEncode(streamUrl)}, ${jsonEncode(cleanFormat)});',
        );
        return;
      }

      // Fallback em Base64 apenas caso o servidor de streaming local não esteja disponível
      final Uint8List bytes = await file.readAsBytes();
      final String base64Data = base64Encode(bytes);

      _loadingProgress = 35.0;
      notifyListeners();

      await _webViewController?.evaluateJavascript(
        source: 'window.loadBimModel("$base64Data", "$cleanFormat");',
      );
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
    if (_webViewController != null) {
      await _webViewController?.evaluateJavascript(source: 'window.resetCamera();');
    }
  }

  /// Altera o ângulo da câmera para vistas técnicas predefinidas estilo ViewCube ('iso', 'top', 'front', 'right', 'left', 'back').
  Future<void> setCameraView(String view) async {
    _currentCameraView = view.toLowerCase();
    notifyListeners();
    if (_webViewController != null) {
      await _webViewController?.evaluateJavascript(
        source: 'window.setCameraView(${jsonEncode(_currentCameraView)});',
      );
    }
  }

  /// Alterna o Plano de Corte Horizontal (Section Cut estilo BIM 360 / Fusion).
  Future<void> toggleSectionCut() async {
    _isSectionCutActive = !_isSectionCutActive;
    notifyListeners();
    await _webViewController?.evaluateJavascript(
      source: 'window.setSectionCut($_isSectionCutActive, $_sectionCutRatio);',
    );
  }

  /// Atualiza a altura percentual (0.05 a 1.0) do Plano de Corte Horizontal em tempo real.
  Future<void> setSectionCutRatio(double ratio) async {
    _sectionCutRatio = ratio.clamp(0.05, 1.0);
    if (!_isSectionCutActive) {
      _isSectionCutActive = true;
    }
    notifyListeners();
    await _webViewController?.evaluateJavascript(
      source: 'window.setSectionCut(true, $_sectionCutRatio);',
    );
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

    await _webViewController?.evaluateJavascript(
      source: 'window.hideElement(${element.expressID});',
    );
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

    await _webViewController?.evaluateJavascript(
      source: 'window.showElement($expressID);',
    );
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

    await _webViewController?.evaluateJavascript(
      source: 'window.isolateElement($id);',
    );
  }

  /// Restaura a visibilidade completa do modelo (desfaz isolamentos e ocultações).
  Future<void> restoreAllVisibility() async {
    _hiddenElementIds.clear();
    _hiddenElementsMap.clear();
    _isolatedElementId = null;
    _isGhostPreviewActive = false;
    notifyListeners();

    await _webViewController?.evaluateJavascript(
      source: 'window.restoreAllVisibility();',
    );
  }

  /// Ativa ou desativa a pré-visualização translúcida fantasma (raio-X) dos elementos ocultos no 3D.
  Future<void> setGhostPreview(bool active) async {
    _isGhostPreviewActive = active;
    notifyListeners();

    await _webViewController?.evaluateJavascript(
      source: 'window.previewHiddenElements($active);',
    );
  }

  /// Limpa a seleção do elemento atual sincronizando com o JavaScript.
  Future<void> clearSelectedElement() async {
    _selectedElement = null;
    notifyListeners();

    await _webViewController?.evaluateJavascript(
      source: 'window.clearSelection();',
    );
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

    await _webViewController?.evaluateJavascript(
      source: 'window.setMeasureMode($enabled, "$mode");',
    );
  }

  /// Alterna o submodo de medição ('span' = vão livre 1 toque, 'point_to_point' = 2 toques)
  Future<void> setMeasureSubMode(String mode) async {
    _measureSubMode = mode;
    _isWaitingSecondPoint = false;
    notifyListeners();

    await _webViewController?.evaluateJavascript(
      source: 'window.setMeasureSubMode("$mode");',
    );
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

    await _webViewController?.evaluateJavascript(
      source: 'window.clearMeasurements();',
    );
  }

  /// Remove a última medição realizada (ação de desfazer)
  Future<void> removeLastMeasurement() async {
    if (_measurements.isNotEmpty) {
      _measurements.removeLast();
      _lastMeasurement = _measurements.isNotEmpty ? _measurements.last : null;
      _isWaitingSecondPoint = false;
      notifyListeners();
    }

    await _webViewController?.evaluateJavascript(
      source: 'window.removeLastMeasurement();',
    );
  }
}
