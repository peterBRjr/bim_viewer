import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/localhost_server_service.dart';
import '../../../home/domain/models/project_model.dart';
import '../controllers/viewer_3d_controller.dart';
import '../widgets/bim_inspector_panel.dart';

/// Tela do Visualizador 3D baseada em ThatOpen Engine (@thatopen/components / Three.js).
/// Executa a Viewport WebGL em InAppWebView com JS Bridge bidirecional.
class Viewer3dScreen extends StatefulWidget {
  final ProjectModel project;
  final Viewer3DController? controller;

  const Viewer3dScreen({
    super.key,
    required this.project,
    this.controller,
  });

  @override
  State<Viewer3dScreen> createState() => _Viewer3dScreenState();
}

class _Viewer3dScreenState extends State<Viewer3dScreen> {
  late final Viewer3DController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? Viewer3DController();
    LocalhostServerService.start();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.primary,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            elevation: 0,
            leading: const BackButton(color: AppColors.surface),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.project.name,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.surface,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${widget.project.format} • ${widget.project.formattedSize}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Resetar Câmera',
                icon: const Icon(Icons.center_focus_strong_rounded, color: AppColors.surface),
                onPressed: _controller.isViewerReady ? () => _controller.resetCamera() : null,
              ),
              IconButton(
                tooltip: 'Recarregar Modelo',
                icon: const Icon(Icons.refresh_rounded, color: AppColors.surface),
                onPressed: _controller.isViewerReady
                    ? () => _controller.loadModelFile(widget.project.filePath, widget.project.format)
                    : null,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              // Viewport WebGL via InAppWebView
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri('http://localhost:8080/index.html'),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  allowFileAccessFromFileURLs: true,
                  allowUniversalAccessFromFileURLs: true,
                  isInspectable: kDebugMode,
                  transparentBackground: true,
                  supportZoom: true,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  useWideViewPort: true,
                  loadWithOverviewMode: true,
                ),
                onWebViewCreated: (webViewController) {
                  _controller.setWebViewController(webViewController);
                },
                onConsoleMessage: (controller, consoleMessage) {
                  debugPrint('[WebView Console] ${consoleMessage.messageLevel}: ${consoleMessage.message}');
                },
                onReceivedError: (controller, request, error) {
                  debugPrint('[WebView Error] ${request.url} - ${error.description}');
                },
                onLoadStop: (webViewController, url) {
                  // Injeta o arquivo do modelo assim que o index.html terminar o carregamento
                  _controller.loadModelFile(
                    widget.project.filePath,
                    widget.project.format,
                  );
                },
              ),

              // Barra Flutuante de Atalhos na Zona do Polegar
              if (_controller.selectedElement == null && !_controller.isLoading && _controller.errorMessage == null)
                _buildFloatingToolBar(),

              // Painel de Inspeção BIM Responsivo (Mobile: Card compacto / Tablet: Dock lateral)
              if (_controller.selectedElement != null)
                BimInspectorPanel(
                  metadata: _controller.selectedElement!,
                  onClose: () => _controller.clearSelectedElement(),
                ),

              // Overlay de Carregamento e Progresso
              if (_controller.isLoading)
                _buildLoadingOverlay(),

              // Banner Defensivo de Erro
              if (_controller.errorMessage != null)
                _buildErrorOverlay(),
            ],
          ),
        );
      },
    );
  }

  /// Barra de ferramentas flutuante na parte inferior (ergonômica para uma mão no celular)
  Widget _buildFloatingToolBar() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 360;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!isSmall)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_outlined, size: 13, color: AppColors.surface),
                        SizedBox(width: 5),
                        Text(
                          'Toque para inspecionar',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 11,
                            color: AppColors.surface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Centralizar Câmera',
                        icon: const Icon(Icons.center_focus_strong_rounded, color: AppColors.primary, size: 18),
                        onPressed: _controller.isViewerReady ? () => _controller.resetCamera() : null,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        tooltip: 'Recarregar',
                        icon: const Icon(Icons.refresh_rounded, color: AppColors.textMuted, size: 18),
                        onPressed: _controller.isViewerReady
                            ? () => _controller.loadModelFile(widget.project.filePath, widget.project.format)
                            : null,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Overlay elegante exibido enquanto o modelo está sendo decodificado e renderizado
  Widget _buildLoadingOverlay() {
    final progress = _controller.loadingProgress.clamp(0.0, 100.0);

    return Container(
      color: AppColors.primary.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Renderizando Modelo BIM',
                style: AppTypography.cardTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Carregando geometria e propriedades técnicas...',
                style: AppTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress / 100.0 : null,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${progress.toInt()}%',
                style: AppTypography.badgeLabel.copyWith(
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Banner com tratamento defensivo caso o arquivo esteja corrompido ou haja erro WebGL
  Widget _buildErrorOverlay() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.destructive, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.destructive,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Falha no Visualizador 3D',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.destructive,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _controller.errorMessage!,
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      _controller.loadModelFile(
                        widget.project.filePath,
                        widget.project.format,
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
