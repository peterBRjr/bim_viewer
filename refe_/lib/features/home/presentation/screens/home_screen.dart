import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../viewer_3d/presentation/screens/viewer_3d_screen.dart';
import '../../domain/models/project_model.dart';
import '../controllers/home_controller.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/empty_projects_view.dart';
import '../widgets/interactive_onboarding_overlay.dart';
import '../widgets/project_card.dart';
import 'ifc_export_guide_screen.dart';

/// Tela inicial responsável pela listagem e gerenciamento de projetos BIM locais,
/// integrada ao Guia de Exportação IFC (Básico/Médio/Detalhado) e ao Tour Interativo.
class HomeScreen extends StatefulWidget {
  final HomeController? controller;
  final AuthController? authController;

  const HomeScreen({
    super.key,
    this.controller,
    this.authController,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller;
  bool _localTourVisible = false;
  int _localTourStep = 0;
  bool _localDontShowAgain = true;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? HomeController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadProjects();
    });
  }

  bool get _isTourActive =>
      (widget.authController?.showOnboardingTour ?? false) || _localTourVisible;

  int get _currentTourStep => widget.authController != null
      ? widget.authController!.onboardingStep
      : _localTourStep;

  void _startTour() {
    if (widget.authController != null) {
      widget.authController!.startOnboardingTour();
    } else {
      setState(() {
        _localTourStep = 0;
        _localTourVisible = true;
      });
    }
  }

  void _nextTourStep() {
    if (widget.authController != null) {
      widget.authController!.nextOnboardingStep(4);
    } else {
      setState(() {
        if (_localTourStep + 1 < 4) {
          _localTourStep++;
        } else {
          _localTourVisible = false;
          _localTourStep = 0;
        }
      });
    }
  }

  void _previousTourStep() {
    if (widget.authController != null) {
      widget.authController!.previousOnboardingStep();
    } else {
      setState(() {
        if (_localTourStep > 0) _localTourStep--;
      });
    }
  }

  void _skipTour() {
    if (widget.authController != null) {
      widget.authController!.completeOnboardingTour();
    } else {
      setState(() {
        _localTourVisible = false;
        _localTourStep = 0;
      });
    }
  }

  void _onDontShowAgainChanged(bool value) {
    if (widget.authController != null) {
      widget.authController!.setDontShowAgain(value);
    } else {
      setState(() {
        _localDontShowAgain = value;
      });
    }
  }

  void _openIfcExportGuide({int initialIndex = 1}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IfcExportGuideScreen(
          initialLevelIndex: initialIndex,
        ),
      ),
    );
  }

  /// Dispara a importação de arquivo BIM local via FilePicker e Storage seguro
  Future<void> _handleImportProject() async {
    final newProject = await _controller.importLocalProject();
    if (!mounted) return;

    if (newProject != null) {
      _showFeedback(
        message: 'Projeto "${newProject.name}" importado e salvo com sucesso!',
        isError: false,
      );
    } else if (_controller.errorMessage != null) {
      _showFeedback(
        message: _controller.errorMessage!,
        isError: true,
      );
    }
  }

  /// Confirma e processa a exclusão física e lógica do projeto
  Future<void> _handleDeleteProject(ProjectModel project) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context: context,
      project: project,
    );

    if (!confirmed || !mounted) return;

    final success = await _controller.deleteProject(project.id);
    if (!mounted) return;

    if (success) {
      _showFeedback(
        message: 'Projeto "${project.name}" excluído com sucesso.',
        isError: false,
      );
    } else {
      _showFeedback(
        message: _controller.errorMessage ?? 'Falha ao excluir o projeto.',
        isError: true,
      );
    }
  }

  /// Abre a viewport 3D para o projeto selecionado
  void _navigateToViewer(ProjectModel project) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Viewer3dScreen(project: project),
      ),
    );
  }

  /// Exibe mensagens de feedback com estilo alinhado ao Design System
  void _showFeedback({required String message, required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.surface),
        ),
        backgroundColor: isError ? AppColors.destructive : AppColors.primary,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[
      _controller,
      if (widget.authController != null) widget.authController!,
    ];

    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) {
        return Stack(
          children: [
            Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                backgroundColor: AppColors.primary,
                elevation: 0,
                title: const Text(
                  'Meus Projetos BIM',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.surface,
                    letterSpacing: -0.3,
                  ),
                ),
                actions: [
                  IconButton(
                    key: const ValueKey('open_ifc_export_guide_button'),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Guia de Exportação IFC',
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: Color(0xFF38BDF8),
                    ),
                    onPressed: () => _openIfcExportGuide(),
                  ),
                  IconButton(
                    key: const ValueKey('reopen_onboarding_tour_button'),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Tutorial de Uso',
                    icon: const Icon(
                      Icons.help_outline_rounded,
                      color: AppColors.surface,
                    ),
                    onPressed: _startTour,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Recarregar Projetos',
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.surface,
                    ),
                    onPressed: _controller.isLoading
                        ? null
                        : () => _controller.loadProjects(),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Importar Modelo BIM',
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.surface,
                    ),
                    onPressed: _controller.isLoading
                        ? null
                        : _handleImportProject,
                  ),
                  if (widget.authController != null)
                    IconButton(
                      key: const ValueKey('logout_button'),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Sair da Conta',
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFF94A3B8),
                      ),
                      onPressed: () => widget.authController!.logout(),
                    ),
                  const SizedBox(width: 4),
                ],
              ),
              body: SafeArea(
                child: Column(
                  children: [
                    _buildEngineeringQuickBanner(),
                    Expanded(child: _buildBody()),
                  ],
                ),
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: _controller.isLoading ? null : _handleImportProject,
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.surface,
                elevation: 3,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Adicionar Projeto',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Overlay do Guia Interativo de Boas-Vindas (Onboarding Tour)
            if (_isTourActive)
              Positioned.fill(
                child: InteractiveOnboardingOverlay(
                  currentStep: _currentTourStep,
                  initialDontShowAgain: widget.authController?.dontShowAgain ??
                      _localDontShowAgain,
                  onDontShowAgainChanged: _onDontShowAgainChanged,
                  onNext: _nextTourStep,
                  onPrevious: _previousTourStep,
                  onSkip: _skipTour,
                  onOpenExportGuide: () {
                    _skipTour();
                    _openIfcExportGuide();
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEngineeringQuickBanner() {
    final userName = widget.authController?.currentUser?.displayName;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.engineering_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  userName != null && userName.isNotEmpty
                      ? 'Olá, $userName • Catálogo Oficial iOS'
                      : 'Catálogo Oficial de Engenharia BIM',
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          InkWell(
            key: const ValueKey('banner_ifc_export_guide_card'),
            onTap: () => _openIfcExportGuide(),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.30),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 14,
                    color: AppColors.accent,
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Como Exportar IFC (Básico • Médio • Detalhado)',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading && _controller.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
        ),
      );
    }

    if (_controller.isEmpty) {
      return EmptyProjectsView(
        onImportPressed: _handleImportProject,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 700;
        final int crossAxisCount = isWide ? 2 : 1;

        return RefreshIndicator(
          onRefresh: () => _controller.loadProjects(),
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          child: GridView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 32 : 16,
              vertical: 20,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 215,
            ),
            itemCount: _controller.projectsCount,
            itemBuilder: (context, index) {
              final project = _controller.projects[index];
              return ProjectCard(
                project: project,
                onViewPressed: () => _navigateToViewer(project),
                onDeletePressed: () => _handleDeleteProject(project),
              );
            },
          ),
        );
      },
    );
  }
}
