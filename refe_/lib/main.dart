import 'package:flutter/material.dart';
import 'core/services/localhost_server_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/controllers/home_controller.dart';
import 'features/home/presentation/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalhostServerService.start();
  runApp(const BimViewerApp());
}

class BimViewerApp extends StatelessWidget {
  final HomeController? homeController;

  const BimViewerApp({
    super.key,
    this.homeController,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Visualizador BIM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: HomeScreen(controller: homeController),
    );
  }
}
