import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../domain/models/bim_element_metadata.dart';
import '../../domain/models/measurement_model.dart';

/// Callbacks disparados por eventos ocorridos dentro da Viewport WebGL 3D.
abstract class Viewer3dJsBridgeListener {
  void onViewerReady();
  void onLoadingProgress(double progress);
  void onElementSelected(BimElementMetadata metadata);
  void onElementDeselected();
  void onVisibilityChanged({required bool isIsolated, int? isolatedId});
  void onViewerError(String message);
  void onMeasureModeChanged({required bool enabled, required String mode});
  void onMeasurementCreated(MeasurementModel measurement);
  void onMeasurementWaitingPoint({required bool isWaiting, String? message});
  void onMeasurementRemoved();
  void onMeasurementCleared();
}

/// Serviço responsável por encapsular a comunicação bidirecional (JS Bridge)
/// entre o shell nativo Flutter e a engine 3D WebGL (Three.js/web-ifc).
class Viewer3dJsBridge {
  InAppWebViewController? _controller;
  Viewer3dJsBridgeListener? _listener;

  /// Vincula o controlador do InAppWebView e o ouvinte de eventos.
  void attach(InAppWebViewController controller, Viewer3dJsBridgeListener listener) {
    _controller = controller;
    _listener = listener;
    _registerHandlers(controller);
  }

  /// Desvincula o controlador para evitar retenção de memória.
  void detach() {
    _controller = null;
    _listener = null;
  }

  bool get isAttached => _controller != null;

  /// Registra os manipuladores de chamada JS nativos.
  void _registerHandlers(InAppWebViewController controller) {
    // 1. Notificação de inicialização da engine WebGL
    controller.addJavaScriptHandler(
      handlerName: 'onViewerReady',
      callback: (args) {
        developer.log('Engine 3D inicializada e pronta (onViewerReady)', name: 'Viewer3dJsBridge');
        _listener?.onViewerReady();
      },
    );

    // 2. Progresso de decodificação e parsing do modelo
    controller.addJavaScriptHandler(
      handlerName: 'onLoadingProgress',
      callback: (args) {
        if (args.isNotEmpty && args[0] is Map) {
          final data = (args[0] as Map).cast<String, dynamic>();
          final progress = (data['progress'] as num?)?.toDouble() ?? 0.0;
          _listener?.onLoadingProgress(progress);
        }
      },
    );

    // 3. Inspeção técnica: elemento selecionado via toque/clique no canvas
    controller.addJavaScriptHandler(
      handlerName: 'onElementSelected',
      callback: (args) {
        if (args.isNotEmpty && args[0] is Map) {
          final data = (args[0] as Map).cast<String, dynamic>();
          final metadata = BimElementMetadata.fromMap(data);
          _listener?.onElementSelected(metadata);
        }
      },
    );

    // 4. Elemento desselecionado (ex: toque no fundo vazio do 3D)
    controller.addJavaScriptHandler(
      handlerName: 'onElementDeselected',
      callback: (args) {
        _listener?.onElementDeselected();
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
          _listener?.onVisibilityChanged(isIsolated: isIsolated, isolatedId: isolatedId);
        }
      },
    );

    // 6. Captura defensiva de erros na renderização WebGL
    controller.addJavaScriptHandler(
      handlerName: 'onViewerError',
      callback: (args) {
        if (args.isNotEmpty && args[0] is Map) {
          final data = (args[0] as Map).cast<String, dynamic>();
          final message = data['message']?.toString() ?? 'Erro desconhecido na Viewport 3D';
          _listener?.onViewerError(message);
        }
      },
    );

    // 7. Notificações do Modo de Medição de Vãos e Distâncias 3D
    controller.addJavaScriptHandler(
      handlerName: 'onMeasureModeChanged',
      callback: (args) {
        if (args.isNotEmpty && args[0] is Map) {
          final data = (args[0] as Map).cast<String, dynamic>();
          final enabled = data['enabled'] == true;
          final mode = data['mode']?.toString() ?? 'span';
          _listener?.onMeasureModeChanged(enabled: enabled, mode: mode);
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onMeasurementCreated',
      callback: (args) {
        if (args.isNotEmpty && args[0] is Map) {
          final data = (args[0] as Map).cast<String, dynamic>();
          final measurement = MeasurementModel.fromMap(data);
          _listener?.onMeasurementCreated(measurement);
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onMeasurementWaitingPoint',
      callback: (args) {
        if (args.isNotEmpty && args[0] is Map) {
          final data = (args[0] as Map).cast<String, dynamic>();
          final cancelled = data['cancelled'] == true;
          final message = cancelled ? null : data['message']?.toString();
          _listener?.onMeasurementWaitingPoint(isWaiting: !cancelled, message: message);
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onMeasurementRemoved',
      callback: (args) {
        _listener?.onMeasurementRemoved();
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onMeasurementCleared',
      callback: (args) {
        _listener?.onMeasurementCleared();
      },
    );
  }

  // =========================================================================
  // COMANDOS ENVIADOS DO FLUTTER PARA A VIEWPORT WEBGL 3D
  // =========================================================================

  Future<void> loadModelFromUrl(String url, String format) async {
    final cleanFormat = format.toUpperCase().replaceAll('.', '');
    await _controller?.evaluateJavascript(
      source: 'window.loadBimModelFromUrl(${jsonEncode(url)}, ${jsonEncode(cleanFormat)});',
    );
  }

  Future<void> loadModelBase64(String base64Data, String format) async {
    final cleanFormat = format.toUpperCase().replaceAll('.', '');
    await _controller?.evaluateJavascript(
      source: 'window.loadBimModel("$base64Data", "$cleanFormat");',
    );
  }

  Future<void> resetCamera() async {
    await _controller?.evaluateJavascript(source: 'window.resetCamera();');
  }

  Future<void> setCameraView(String view) async {
    await _controller?.evaluateJavascript(
      source: 'window.setCameraView(${jsonEncode(view.toLowerCase())});',
    );
  }

  Future<void> setSectionCut(bool active, double ratio) async {
    await _controller?.evaluateJavascript(
      source: 'window.setSectionCut($active, $ratio);',
    );
  }

  Future<void> hideElement(int expressID) async {
    await _controller?.evaluateJavascript(
      source: 'window.hideElement($expressID);',
    );
  }

  Future<void> showElement(int expressID) async {
    await _controller?.evaluateJavascript(
      source: 'window.showElement($expressID);',
    );
  }

  Future<void> isolateElement(int expressID) async {
    await _controller?.evaluateJavascript(
      source: 'window.isolateElement($expressID);',
    );
  }

  Future<void> restoreAllVisibility() async {
    await _controller?.evaluateJavascript(
      source: 'window.restoreAllVisibility();',
    );
  }

  Future<void> previewHiddenElements(bool active) async {
    await _controller?.evaluateJavascript(
      source: 'window.previewHiddenElements($active);',
    );
  }

  Future<void> clearSelection() async {
    await _controller?.evaluateJavascript(
      source: 'window.clearSelection();',
    );
  }

  Future<void> setMeasureMode(bool enabled, {String mode = 'span'}) async {
    await _controller?.evaluateJavascript(
      source: 'window.setMeasureMode($enabled, "$mode");',
    );
  }

  Future<void> setMeasureSubMode(String mode) async {
    await _controller?.evaluateJavascript(
      source: 'window.setMeasureSubMode("$mode");',
    );
  }

  Future<void> clearMeasurements() async {
    await _controller?.evaluateJavascript(
      source: 'window.clearMeasurements();',
    );
  }

  Future<void> removeLastMeasurement() async {
    await _controller?.evaluateJavascript(
      source: 'window.removeLastMeasurement();',
    );
  }
}

