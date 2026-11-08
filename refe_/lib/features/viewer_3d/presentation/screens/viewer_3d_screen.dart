import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/services/localhost_server_service.dart';
import '../../../home/domain/models/project_model.dart';
import '../controllers/viewer_3d_controller.dart';
import '../widgets/bim_metadata_bottom_sheet.dart';
import '../widgets/bim_tabbar.dart';
import '../widgets/dynamic_bim_workspace.dart';
import '../widgets/hidden_elements_bottom_sheet.dart';
import '../widgets/measure_mode_overlay.dart';

/// Tela do Visualizador 3D baseada em ThatOpen Engine (@thatopen/components / Three.js).
/// Executa a Viewport WebGL em InAppWebView com JS Bridge bidirecional e Visualização Dinâmica Horizontal.
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
  int _webViewRecreationId = 0;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? Viewer3DController();
    LocalhostServerService.start();
  }

  @override
  void dispose() {
    try {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).catchError((_) {});
    } catch (_) {}
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
        final bool isDynamic =
            _controller.isDynamicViewActive && _controller.selectedElement != null;

        return PopScope(
          canPop: !isDynamic,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && isDynamic) {
              _controller.exitDynamicView();
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.primary,
            appBar: isDynamic
                ? null
                : AppBar(
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
                      // Botão de Ativação do Modo de Medição de Vãos Livres
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _controller.isMeasureMode
                              ? AppColors.accent
                              : Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _controller.isMeasureMode
                                ? AppColors.surface
                                : Colors.white.withValues(alpha: 0.20),
                            width: 1.2,
                          ),
                        ),
                        child: IconButton(
                          tooltip: _controller.isMeasureMode
                              ? 'Sair da Medição'
                              : 'Modo de Medição (Vãos)',
                          icon: const Icon(
                            Icons.straighten_rounded,
                            color: AppColors.surface,
                            size: 20,
                          ),
                          onPressed: _controller.isViewerReady
                              ? () {
                                  HapticFeedback.mediumImpact();
                                  _controller.toggleMeasureMode();
                                }
                              : null,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Botão de Plano de Corte Horizontal (Section Cut estilo BIM 360 / Fusion)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _controller.isSectionCutActive
                              ? AppColors.accent
                              : Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _controller.isSectionCutActive
                                ? AppColors.surface
                                : Colors.white.withValues(alpha: 0.20),
                            width: 1.2,
                          ),
                        ),
                        child: IconButton(
                          tooltip: _controller.isSectionCutActive
                              ? 'Desativar Corte'
                              : 'Plano de Corte ( Pavimentos )',
                          icon: const Icon(
                            Icons.content_cut_rounded,
                            color: AppColors.surface,
                            size: 19,
                          ),
                          onPressed: _controller.isViewerReady
                              ? () {
                                  HapticFeedback.mediumImpact();
                                  _controller.toggleSectionCut();
                                }
                              : null,
                        ),
                      ),
                      // Menu de Vistas Técnicas Predefinidas (ViewCube Autodesk Fusion / BIM 360)
                      PopupMenuButton<String>(
                        tooltip: 'Vistas Técnicas (ViewCube)',
                        enabled: _controller.isViewerReady,
                        icon: const Icon(Icons.view_in_ar_rounded, color: AppColors.surface),
                        color: AppColors.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (view) {
                          HapticFeedback.selectionClick();
                          _controller.setCameraView(view);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'iso',
                            child: Row(
                              children: [
                                Icon(Icons.threed_rotation_rounded, size: 18, color: AppColors.accent),
                                SizedBox(width: 10),
                                Text('Vista Isométrica (3D Home)'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'top',
                            child: Row(
                              children: [
                                Icon(Icons.grid_on_rounded, size: 18, color: AppColors.primary),
                                SizedBox(width: 10),
                                Text('Planta / Topo (Superior)'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'front',
                            child: Row(
                              children: [
                                Icon(Icons.crop_landscape_rounded, size: 18, color: AppColors.primary),
                                SizedBox(width: 10),
                                Text('Elevação Frontal'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'right',
                            child: Row(
                              children: [
                                Icon(Icons.view_sidebar_rounded, size: 18, color: AppColors.primary),
                                SizedBox(width: 10),
                                Text('Elevação Lateral Direita'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'left',
                            child: Row(
                              children: [
                                Icon(Icons.view_sidebar_outlined, size: 18, color: AppColors.primary),
                                SizedBox(width: 10),
                                Text('Elevação Lateral Esquerda'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Resetar Câmera',
                        icon: const Icon(Icons.center_focus_strong_rounded, color: AppColors.surface),
                        onPressed:
                            _controller.isViewerReady ? () => _controller.resetCamera() : null,
                      ),
                      IconButton(
                        tooltip: 'Recarregar Modelo',
                        icon: const Icon(Icons.refresh_rounded, color: AppColors.surface),
                        onPressed: _controller.isViewerReady
                            ? () => _controller.loadModelFile(
                                  widget.project.filePath,
                                  widget.project.format,
                                )
                            : null,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth > 0
                    ? constraints.maxWidth
                    : MediaQuery.of(context).size.width;
                final leftViewportWidth = isDynamic
                    ? (totalWidth * _controller.dynamicSplitRatio).clamp(160.0, totalWidth)
                    : totalWidth;

                return Stack(
                  children: [
                    // Viewport WebGL via InAppWebView: mantida fixa no slot 0 para redimensionar em tempo real sem recarregar o modelo 3D
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      width: leftViewportWidth,
                      child: InAppWebView(
                        key: ValueKey('bim_webview_$_webViewRecreationId'),
                        gestureRecognizers: {
                          Factory<OneSequenceGestureRecognizer>(
                            () => EagerGestureRecognizer(),
                          ),
                        },
                        initialUrlRequest: URLRequest(
                          url: WebUri('http://localhost:8080/index.html'),
                        ),
                        initialSettings: InAppWebViewSettings(
                          javaScriptEnabled: true,
                          allowFileAccessFromFileURLs: true,
                          allowUniversalAccessFromFileURLs: true,
                          isInspectable: kDebugMode,
                          transparentBackground: true,
                          supportZoom: false,
                          disableVerticalScroll: true,
                          disableHorizontalScroll: true,
                          disallowOverScroll: true,
                          mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                          useWideViewPort: true,
                          loadWithOverviewMode: true,
                        ),
                        onWebViewCreated: (webViewController) {
                          _controller.setWebViewController(webViewController);
                        },
                        onConsoleMessage: (controller, consoleMessage) {
                          debugPrint(
                            '[WebView Console] ${consoleMessage.messageLevel}: ${consoleMessage.message}',
                          );
                        },
                        onReceivedError: (controller, request, error) {
                          debugPrint('[WebView Error] ${request.url} - ${error.description}');
                        },
                        onWebContentProcessDidTerminate: (controller) async {
                          debugPrint(
                            '[WebView iOS onWebContentProcessDidTerminate] OOM WebKit recovery triggered',
                          );
                          _controller.handleRenderProcessGone(true);
                        },
                        onRenderProcessGone: (controller, detail) async {
                          debugPrint('[WebView RenderProcessGone] didCrash: ${detail.didCrash}');
                          _controller.handleRenderProcessGone(detail.didCrash);
                        },
                        onLoadStop: (webViewController, url) {
                          // Injeta o arquivo do modelo assim que o index.html terminar o carregamento
                          _controller.loadModelFile(
                            widget.project.filePath,
                            widget.project.format,
                          );
                        },
                      ),
                    ),

                    // Workspace Horizontal da Visualização Dinâmica (Lado Direito + Divisória + HUD Esquerdo)
                    if (isDynamic && !_controller.isLoading)
                      DynamicBimWorkspace(
                        controller: _controller,
                        project: widget.project,
                        totalWidth: totalWidth,
                        leftViewportWidth: leftViewportWidth,
                        onExit: () => _controller.exitDynamicView(),
                      ),

                    // Controle Deslizante de Plano de Corte Horizontal (Section Cut estilo BIM 360)
                    if (!isDynamic &&
                        _controller.isSectionCutActive &&
                        !_controller.isLoading &&
                        _controller.errorMessage == null)
                      _buildSectionCutOverlay(),

                    // Botão Flutuante de Fácil Acesso com Ícone do Olho para Elementos Ocultados
                    if (!isDynamic &&
                        _controller.hasHiddenElements &&
                        !_controller.isLoading &&
                        _controller.errorMessage == null &&
                        !_controller.isMeasureMode)
                      _buildFloatingHiddenEyeButton(),

                    // TabBar de Ações Rápidas Estilo Nubank (exibida ao clicar em um elemento 3D fora do modo dinâmico)
                    if (!isDynamic &&
                        _controller.selectedElement != null &&
                        !_controller.isLoading &&
                        !_controller.isMeasureMode)
                      NubankBimTabBar(
                        metadata: _controller.selectedElement!,
                        isIsolated: _controller.isElementIsolated(
                          _controller.selectedElement!.expressID,
                        ),
                        onViewBimData: () {
                          BimMetadataBottomSheet.show(
                            context: context,
                            metadata: _controller.selectedElement!,
                          );
                        },
                        onHideElement: () => _handleHideElement(_controller.selectedElement!),
                        onIsolateElement: () => _handleIsolateElement(_controller.selectedElement!),
                        onDynamicView: () {
                          final isCurrentlyLandscape =
                              MediaQuery.of(context).orientation == Orientation.landscape;
                          _controller.enterDynamicView(
                            currentlyLandscape: isCurrentlyLandscape,
                          );
                        },
                        onClose: () => _controller.clearSelectedElement(),
                      ),

                    // Overlay do Modo de Medição de Vãos Livres (1 toque / ponto a ponto)
                    if (!isDynamic && _controller.isMeasureMode && !_controller.isLoading)
                      MeasureModeOverlay(
                        controller: _controller,
                        onClose: () => _controller.setMeasureMode(false),
                      ),

                    // Overlay de Carregamento e Progresso
                    if (_controller.isLoading) _buildLoadingOverlay(),

                    // Banner Defensivo de Erro
                    if (_controller.errorMessage != null) _buildErrorOverlay(),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Abre o Bottom Sheet dedicado para visualização e gerenciamento de elementos ocultados
  void _openHiddenElementsSheet() {
    HapticFeedback.lightImpact();
    HiddenElementsBottomSheet.show(
      context: context,
      controller: _controller,
    );
  }

  /// Oculta o elemento selecionado no motor 3D
  void _handleHideElement(BimElementMetadata metadata) async {
    await _controller.hideSelectedElement();
  }

  /// Isola o elemento selecionado ou restaura a visão completa
  void _handleIsolateElement(BimElementMetadata metadata) async {
    await _controller.isolateSelectedElement();
  }

  /// Botão Flutuante de Fácil Acesso com Ícone do Olho para visualização rápida dos elementos ocultados
  Widget _buildFloatingHiddenEyeButton() {
    final count = _controller.hiddenCount;
    // Eleva a posição quando a NubankTabBar estiver aberta para não sobrepor
    final bottomOffset = _controller.selectedElement != null ? 90.0 : 20.0;

    return Positioned(
      bottom: bottomOffset,
      right: 16,
      child: SafeArea(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 260),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutBack,
          builder: (context, val, child) {
            return Transform.scale(
              scale: val,
              child: Opacity(
                opacity: val.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openHiddenElementsSheet,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.70),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.28),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.40),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.visibility_off_rounded,
                          color: Color(0xFFFBBF24),
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Ocultados',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.surface,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
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
                      if (_controller.renderProcessCrashed) {
                        setState(() {
                          _webViewRecreationId++;
                        });
                        _controller.prepareWebViewRecovery(
                          widget.project.filePath,
                          widget.project.format,
                        );
                      } else {
                        _controller.loadModelFile(
                          widget.project.filePath,
                          widget.project.format,
                        );
                      }
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

  /// Barra flutuante de Plano de Corte Horizontal (Section Analysis estilo Autodesk BIM 360 / Fusion)
  Widget _buildSectionCutOverlay() {
    final pct = (_controller.sectionCutRatio * 100).round();
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: SafeArea(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.65),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.content_cut_rounded, color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Corte: $pct%',
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.surface,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.accent,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.24),
                        thumbColor: AppColors.surface,
                        overlayColor: AppColors.accent.withValues(alpha: 0.2),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _controller.sectionCutRatio.clamp(0.05, 1.0),
                        min: 0.05,
                        max: 1.0,
                        onChanged: (val) => _controller.setSectionCutRatio(val),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar Corte',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, color: AppColors.surface, size: 18),
                    onPressed: () => _controller.toggleSectionCut(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
