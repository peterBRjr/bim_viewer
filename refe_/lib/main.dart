import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/localhost_server_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/home/presentation/controllers/home_controller.dart';
import 'features/home/presentation/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await LocalhostServerService.start();
  runApp(const BimViewerApp());
}

class BimViewerApp extends StatefulWidget {
  final HomeController? homeController;
  final AuthController? authController;
  final bool? requireLogin;

  const BimViewerApp({
    super.key,
    this.homeController,
    this.authController,
    this.requireLogin,
  });

  @override
  State<BimViewerApp> createState() => _BimViewerAppState();
}

class _BimViewerAppState extends State<BimViewerApp> {
  late final AuthController _authController;
  late final bool _enforceAuthGate;

  @override
  void initState() {
    super.initState();
    _authController = widget.authController ?? AuthController();
    // Em produção (quando nenhum homeController de mock é injetado), exige sempre o Login inicial
    _enforceAuthGate = widget.requireLogin ?? (widget.homeController == null);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _authController,
      builder: (context, _) {
        final showHome = !_enforceAuthGate || _authController.isAuthenticated;

        return MaterialApp(
          title: 'Visualizador BIM',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: showHome
              ? HomeScreen(
                  controller: widget.homeController,
                  authController: _authController,
                )
              : LoginScreen(controller: _authController),
        );
      },
    );
  }
}
