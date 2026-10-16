import 'dart:developer' as developer;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Serviço responsável pelo servidor HTTP local e 100% offline.
/// Permite que o WebView2 e WebGL carreguem WebAssembly (.wasm) sem restrições de CORS/file://.
class LocalhostServerService {
  static const int port = 8080;
  static const String documentRoot = 'assets/web_viewer';

  static final InAppLocalhostServer _localhostServer = InAppLocalhostServer(
    documentRoot: documentRoot,
    port: port,
  );

  static InAppLocalhostServer get server => _localhostServer;

  /// Inicia o servidor local offline caso ainda não esteja rodando.
  static Future<void> start() async {
    try {
      if (!_localhostServer.isRunning()) {
        await _localhostServer.start();
        developer.log(
          'Servidor Localhost 3D iniciado com sucesso em http://localhost:$port',
          name: 'LocalhostServerService',
        );
      }
    } catch (e, stack) {
      developer.log(
        'Falha ao iniciar LocalhostServer',
        error: e,
        stackTrace: stack,
        name: 'LocalhostServerService',
      );
    }
  }

  /// Encerra o servidor local liberando as portas e recursos de rede.
  static Future<void> stop() async {
    try {
      if (_localhostServer.isRunning()) {
        await _localhostServer.close();
        developer.log('Servidor Localhost 3D finalizado.', name: 'LocalhostServerService');
      }
    } catch (e) {
      developer.log('Erro ao encerrar LocalhostServer: $e', name: 'LocalhostServerService');
    }
  }
}
