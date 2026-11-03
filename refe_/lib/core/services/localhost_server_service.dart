import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Serviço responsável pelo servidor HTTP local e 100% offline.
/// Permite que o WebView2 e WebGL carreguem WebAssembly (.wasm) sem restrições de CORS/file://,
/// além de realizar streaming direto de arquivos BIM grandes (.ifc / .glb) a partir do disco local
/// sem sobrecarregar a memória RAM ou o limite de IPC de Base64.
class LocalhostServerService {
  static const int port = 8080;
  static const String documentRoot = 'assets/web_viewer';

  static final InAppLocalhostServer _localhostServer = InAppLocalhostServer(
    documentRoot: documentRoot,
    port: port,
  );

  static HttpServer? _modelStreamServer;
  static final Map<String, String> _registeredModels = {};
  static int _tokenCounter = 0;

  static InAppLocalhostServer get server => _localhostServer;

  /// Inicia o servidor local offline e o servidor de streaming de modelos caso ainda não estejam rodando.
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

    await _ensureModelStreamServer();
  }

  /// Garante que o servidor HTTP loopback para streaming binário de modelos locais esteja ativo.
  static Future<HttpServer?> _ensureModelStreamServer() async {
    if (_modelStreamServer != null) return _modelStreamServer;

    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _modelStreamServer = server;

      server.listen((HttpRequest request) async {
        request.response.headers.set('Access-Control-Allow-Origin', '*');
        request.response.headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
        request.response.headers.set('Access-Control-Allow-Headers', '*');
        request.response.headers.set('Cache-Control', 'no-store');

        if (request.method == 'OPTIONS') {
          request.response.statusCode = HttpStatus.noContent;
          await request.response.close();
          return;
        }

        final segments = request.uri.pathSegments;
        if (segments.length >= 2 && segments[0] == 'models') {
          final token = segments[1];
          final filePath = _registeredModels[token];

          if (filePath != null) {
            final file = File(filePath);
            if (await file.exists()) {
              try {
                final fileLength = await file.length();
                request.response.statusCode = HttpStatus.ok;
                request.response.headers.contentType = ContentType.binary;
                request.response.contentLength = fileLength;

                if (request.method == 'HEAD') {
                  await request.response.close();
                  return;
                }

                await request.response.addStream(file.openRead());
                await request.response.close();
                return;
              } catch (e, stack) {
                developer.log(
                  'Erro durante streaming do modelo local: $filePath',
                  error: e,
                  stackTrace: stack,
                  name: 'LocalhostServerService',
                );
              }
            }
          }
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });

      developer.log(
        'Servidor de Streaming BIM iniciado em http://127.0.0.1:${server.port}',
        name: 'LocalhostServerService',
      );
      return server;
    } catch (e, stack) {
      developer.log(
        'Falha ao iniciar servidor de streaming de modelos locais',
        error: e,
        stackTrace: stack,
        name: 'LocalhostServerService',
      );
      return null;
    }
  }

  /// Registra um arquivo BIM do disco local para streaming HTTP direto ao WebView
  /// e retorna a URL loopback correspondente.
  static Future<String?> registerModelFile(String filePath) async {
    final server = await _ensureModelStreamServer();
    if (server == null) return null;

    _tokenCounter++;
    final token = 'm_${DateTime.now().millisecondsSinceEpoch}_$_tokenCounter';
    // Mantém apenas os últimos registros para evitar acúmulo desnecessário
    if (_registeredModels.length > 12) {
      _registeredModels.remove(_registeredModels.keys.first);
    }
    _registeredModels[token] = filePath;

    return 'http://127.0.0.1:${server.port}/models/$token';
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

    try {
      await _modelStreamServer?.close(force: true);
      _modelStreamServer = null;
      _registeredModels.clear();
    } catch (e) {
      developer.log('Erro ao encerrar servidor de streaming BIM: $e', name: 'LocalhostServerService');
    }
  }
}
