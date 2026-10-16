import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../viewer_3d/presentation/screens/viewer_3d_screen.dart';
import '../../domain/models/project_model.dart';
import '../controllers/home_controller.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/empty_projects_view.dart';
import '../widgets/project_card.dart';

/// Tela inicial responsável pela listagem e gerenciamento de projetos BIM locais.
/// Totalmente conectada ao [HomeController] para persistência segura e CRUD reativo.
class HomeScreen extends StatefulWidget {
  final HomeController? controller;

  const HomeScreen({
    super.key,
    this.controller,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? HomeController();
    // Carrega o catálogo persistido na inicialização da tela
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadProjects();
    });
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
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
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
                tooltip: 'Recarregar Projetos',
                icon: const Icon(Icons.refresh_rounded, color: AppColors.surface),
                onPressed: _controller.isLoading ? null : () => _controller.loadProjects(),
              ),
              IconButton(
                tooltip: 'Importar Modelo BIM',
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.surface),
                onPressed: _controller.isLoading ? null : _handleImportProject,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: _buildBody(),
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
        );
      },
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
        // Responsividade: 2 colunas para telas médias/grandes (desktop/tablet), 1 coluna para mobile
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
              mainAxisExtent: 215, // Altura padronizada para os cards técnicos
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
