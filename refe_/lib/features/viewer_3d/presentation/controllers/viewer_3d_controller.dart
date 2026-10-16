import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Metadados de um elemento BIM selecionado via Raycaster na Viewport 3D.
class BimElementMetadata {
  final int expressID;
  final String name;
  final String category;
  final Map<String, dynamic> psets;

  const BimElementMetadata({
    required this.expressID,
    required this.name,
    required this.category,
    required this.psets,
  });

  factory BimElementMetadata.fromMap(Map<String, dynamic> map) {
    return BimElementMetadata(
      expressID: (map['expressID'] as num?)?.toInt() ?? 0,
      name: map['name']?.toString() ?? 'Elemento Desconhecido',
      category: map['category']?.toString() ?? 'IfcBuildingElementProxy',
      psets: (map['psets'] as Map?)?.cast<String, dynamic>() ?? {},
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

  /// Retorna o nome amigável e limpo para visualização.
  String get displayName {
    final decoded = decodeIfcString(name).trim();
    if (decoded.isEmpty || decoded == 'null') {
      return '$friendlyCategory #$expressID';
    }
    // Remove códigos longos entre colchetes no final do Revit (ex: "Parede [123456]" -> "Parede")
    return decoded.replaceAll(RegExp(r'\s*\[\d+\]$'), '');
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

  /// Extrai as métricas de obra mais úteis (Área, Volume, Dimensões, Nível).
  Map<String, String> get keyMetrics {
    final Map<String, String> metrics = {};

    for (final pset in psets.values) {
      if (pset is Map) {
        for (final entry in pset.entries) {
          final key = entry.key.toString().toLowerCase();
          final val = decodeIfcString(entry.value.toString()).trim();

          if (metrics.length < 3) {
            if (key.contains('area') || key.contains('área')) {
              metrics['Área'] = val.endsWith('m²') ? val : '$val m²';
            } else if (key.contains('volume')) {
              metrics['Volume'] = val.endsWith('m³') ? val : '$val m³';
            } else if (key.contains('length') || key.contains('comprimento')) {
              metrics['Comp.'] = val.endsWith('m') ? val : '$val m';
            } else if (key.contains('height') || key.contains('altura')) {
              metrics['Altura'] = val.endsWith('m') ? val : '$val m';
            } else if (key.contains('width') || key.contains('espessura') || key.contains('largura')) {
              metrics['Espes.'] = val.endsWith('m') || val.endsWith('cm') ? val : '$val m';
            } else if (key.contains('level') || key.contains('nível') || key.contains('pavimento')) {
              metrics['Nível'] = val;
            }
          }
        }
      }
    }

    if (metrics.isEmpty) {
      metrics['Item'] = '#$expressID';
      metrics['Tipo'] = friendlyCategory;
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

  String? _pendingFilePath;
  String? _pendingFormat;

  InAppWebViewController? get webViewController => _webViewController;
  bool get isViewerReady => _isViewerReady;
  bool get isLoading => _isLoading;
  double get loadingProgress => _loadingProgress;
  String? get errorMessage => _errorMessage;
  BimElementMetadata? get selectedElement => _selectedElement;

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

    // 4. Captura defensiva de erros na renderização WebGL
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
  }

  /// Lê o arquivo local como bytes, converte para Base64 e injeta no motor WebGL via JS.
  Future<void> loadModelFile(String filePath, String format) async {
    _isLoading = true;
    _loadingProgress = 5.0;
    _errorMessage = null;
    _selectedElement = null;
    notifyListeners();

    if (!_isViewerReady || _webViewController == null) {
      developer.log('Viewer ainda não está pronto. Enfileirando carregamento de: $filePath', name: 'Viewer3DController');
      _pendingFilePath = filePath;
      _pendingFormat = format;
      return;
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileSystemException('Arquivo do modelo BIM não encontrado no disco local', filePath);
      }

      _loadingProgress = 15.0;
      notifyListeners();

      // Leitura binária protegida
      final Uint8List bytes = await file.readAsBytes();
      final String base64Data = base64Encode(bytes);

      _loadingProgress = 35.0;
      notifyListeners();

      // Executa o carregamento no JavaScript da Viewport
      await _webViewController?.evaluateJavascript(
        source: 'window.loadBimModel("$base64Data", "${format.toUpperCase()}");',
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
    if (_webViewController != null) {
      await _webViewController?.evaluateJavascript(source: 'window.resetCamera();');
    }
  }

  /// Limpa a seleção do elemento atual.
  void clearSelectedElement() {
    _selectedElement = null;
    notifyListeners();
  }
}
