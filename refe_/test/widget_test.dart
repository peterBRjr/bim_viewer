import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refe_/main.dart';
import 'package:refe_/features/home/domain/models/project_model.dart';
import 'package:refe_/features/home/data/services/storage_service.dart';
import 'package:refe_/features/home/presentation/controllers/home_controller.dart';
import 'package:refe_/features/home/presentation/widgets/project_card.dart';
import 'package:refe_/features/home/presentation/widgets/confirm_delete_dialog.dart';
import 'package:refe_/features/viewer_3d/presentation/controllers/viewer_3d_controller.dart';
import 'package:refe_/features/viewer_3d/presentation/widgets/bim_metadata_bottom_sheet.dart';

class FakeStorageService extends StorageService {
  List<ProjectModel> fakeCatalog;

  FakeStorageService({List<ProjectModel>? initial})
      : fakeCatalog = initial != null ? List.from(initial) : [];

  @override
  Future<List<ProjectModel>> loadCatalog() async => List.from(fakeCatalog);

  @override
  Future<bool> saveCatalog(List<ProjectModel> projects) async {
    fakeCatalog = List.from(projects);
    return true;
  }

  @override
  Future<bool> deleteProject(String projectId) async {
    fakeCatalog.removeWhere((p) => p.id == projectId);
    return true;
  }
}

void main() {
  group('BimViewerApp Widget Tests', () {
    testWidgets('App renders correctly with initial empty state', (WidgetTester tester) async {
      final fakeStorage = FakeStorageService(initial: []);
      final controller = HomeController(storageService: fakeStorage);

      await tester.pumpWidget(BimViewerApp(homeController: controller));
      await tester.pumpAndSettle();

      // Verifica se a AppBar e o título estão presentes
      expect(find.text('Meus Projetos BIM'), findsOneWidget);

      // Verifica se o Empty State inicial é exibido
      expect(find.text('Nenhum projeto BIM cadastrado'), findsOneWidget);
      expect(find.text('Importar Primeiro Modelo'), findsOneWidget);
      expect(find.text('Adicionar Projeto'), findsOneWidget);
    });

    testWidgets('App renders grid with project cards when catalog has items', (WidgetTester tester) async {
      final sampleProject = ProjectModel(
        id: 'sample-1',
        name: 'Edificio_Residencial.ifc',
        filePath: '/storage/Edificio_Residencial.ifc',
        fileSizeMB: 18.5,
        format: 'IFC',
        createdAt: DateTime(2026, 10, 14),
      );

      final fakeStorage = FakeStorageService(initial: [sampleProject]);
      final controller = HomeController(storageService: fakeStorage);

      await tester.pumpWidget(BimViewerApp(homeController: controller));
      await tester.pumpAndSettle();

      // Verifica exibição do card no GridView
      expect(find.text('Edificio_Residencial.ifc'), findsOneWidget);
      expect(find.text('.IFC'), findsOneWidget);
      expect(find.text('18.50 MB'), findsOneWidget);
      expect(find.text('Visualizar'), findsOneWidget);
    });
  });

  group('ProjectModel Unit Tests', () {
    test('toMap and fromMap work symmetrically', () {
      final now = DateTime(2026, 10, 14, 19, 30);
      final model = ProjectModel(
        id: 'test-uuid-1234',
        name: 'Edificio_Bloco_A.ifc',
        filePath: '/storage/models/Edificio_Bloco_A.ifc',
        fileSizeMB: 15.42,
        format: 'IFC',
        createdAt: now,
      );

      final map = model.toMap();
      final restored = ProjectModel.fromMap(map);

      expect(restored.id, model.id);
      expect(restored.name, model.name);
      expect(restored.filePath, model.filePath);
      expect(restored.fileSizeMB, model.fileSizeMB);
      expect(restored.format, model.format);
      expect(restored.createdAt, model.createdAt);
      expect(restored, equals(model));
    });

    test('copyWith properly overrides specified fields', () {
      final now = DateTime(2026, 10, 14, 19, 30);
      final model = ProjectModel(
        id: 'test-1',
        name: 'Original.glb',
        filePath: '/path/Original.glb',
        fileSizeMB: 8.5,
        format: 'GLB',
        createdAt: now,
      );

      final updated = model.copyWith(name: 'Updated.glb', fileSizeMB: 10.0);

      expect(updated.id, 'test-1');
      expect(updated.name, 'Updated.glb');
      expect(updated.fileSizeMB, 10.0);
      expect(updated.format, 'GLB');
      expect(updated.filePath, model.filePath);
    });

    test('formattedSize formats correctly for KB and MB', () {
      final modelMB = ProjectModel(
        id: '1',
        name: 'Grande.glb',
        filePath: '/path/Grande.glb',
        fileSizeMB: 12.345,
        format: 'GLB',
        createdAt: DateTime.now(),
      );
      expect(modelMB.formattedSize, '12.35 MB');

      final modelKB = ProjectModel(
        id: '2',
        name: 'Pequeno.glb',
        filePath: '/path/Pequeno.glb',
        fileSizeMB: 0.05,
        format: 'GLB',
        createdAt: DateTime.now(),
      );
      expect(modelKB.formattedSize, '51.2 KB');
    });
  });

  group('ProjectCard Widget Tests', () {
    testWidgets('renders project card details and handles actions', (WidgetTester tester) async {
      bool viewClicked = false;
      bool deleteClicked = false;

      final project = ProjectModel(
        id: 'card-test-1',
        name: 'Hospital_Central.ifc',
        filePath: '/local/Hospital_Central.ifc',
        fileSizeMB: 42.8,
        format: 'IFC',
        createdAt: DateTime(2026, 10, 14, 20, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectCard(
              project: project,
              onViewPressed: () => viewClicked = true,
              onDeletePressed: () => deleteClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('Hospital_Central.ifc'), findsOneWidget);
      expect(find.text('.IFC'), findsOneWidget);
      expect(find.text('42.80 MB'), findsOneWidget);
      expect(find.text('Visualizar'), findsOneWidget);

      await tester.tap(find.text('Visualizar'));
      expect(viewClicked, isTrue);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      expect(deleteClicked, isTrue);
    });
  });

  group('ConfirmDeleteDialog Tests', () {
    testWidgets('cancels and confirms delete correctly', (WidgetTester tester) async {
      final project = ProjectModel(
        id: 'del-1',
        name: 'Modelo_Remocao.glb',
        filePath: '/path/Modelo_Remocao.glb',
        fileSizeMB: 5.0,
        format: 'GLB',
        createdAt: DateTime.now(),
      );

      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await ConfirmDeleteDialog.show(
                    context: context,
                    project: project,
                  );
                },
                child: const Text('Abrir Modal'),
              ),
            ),
          ),
        ),
      );

      // Abre diálogo e clica em Cancelar
      await tester.tap(find.text('Abrir Modal'));
      await tester.pumpAndSettle();
      expect(find.text('Excluir Projeto'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      // Abre diálogo e clica em Excluir
      await tester.tap(find.text('Abrir Modal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  group('Viewer 3D and BIM Metadata Tests (Phase 3)', () {
    test('BimElementMetadata.fromMap parses properties correctly', () {
      final metadataMap = {
        'expressID': 105,
        'name': 'Pilar P1 - Concreto',
        'category': 'IfcColumn',
        'subIds': [101, 102],
        'isComposite': true,
        'psets': {
          'Pset_Dimensions': {
            'Largura': '0.50 m',
            'Altura': '3.20 m',
          },
          'Pset_Material': {
            'Material': 'Concreto C30',
          }
        }
      };

      final metadata = BimElementMetadata.fromMap(metadataMap);

      expect(metadata.expressID, 105);
      expect(metadata.name, 'Pilar P1 - Concreto');
      expect(metadata.category, 'IfcColumn');
      expect(metadata.isComposite, isTrue);
      expect(metadata.subIds, [101, 102]);
      expect(metadata.psets.containsKey('Pset_Dimensions'), isTrue);
      expect(metadata.psets['Pset_Dimensions']['Largura'], '0.50 m');
    });

    testWidgets('BimMetadataBottomSheet renders element details and Psets', (WidgetTester tester) async {
      const metadata = BimElementMetadata(
        expressID: 201,
        name: 'Viga Estrutural V1',
        category: 'IfcBeam',
        psets: {
          'Pset_Structural': {
            'Função': 'Viga Principal',
            'Carga': '80 kN',
          }
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => BimMetadataBottomSheet.show(
                  context: context,
                  metadata: metadata,
                ),
                child: const Text('Abrir Ficha Técnica'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Ficha Técnica'));
      await tester.pumpAndSettle();

      expect(find.text('Viga Estrutural V1'), findsOneWidget);
      expect(find.textContaining('IfcBeam'), findsOneWidget);
      expect(find.textContaining('ExpressID: #201'), findsOneWidget);
      expect(find.text('Pset_Structural'), findsOneWidget);
      expect(find.text('Viga Principal'), findsOneWidget);
    });

    test('Viewer3DController hidden elements tracking and preview state', () async {
      final controller = Viewer3DController();

      expect(controller.hasHiddenElements, isFalse);
      expect(controller.hiddenCount, 0);
      expect(controller.isGhostPreviewActive, isFalse);

      await controller.setGhostPreview(true);
      expect(controller.isGhostPreviewActive, isTrue);

      await controller.setGhostPreview(false);
      expect(controller.isGhostPreviewActive, isFalse);
    });

    test('Viewer3DController initial state and handlers', () {
      final controller = Viewer3DController();

      expect(controller.isViewerReady, isFalse);
      expect(controller.isLoading, isTrue);
      expect(controller.loadingProgress, 0.0);
      expect(controller.selectedElement, isNull);
      expect(controller.errorMessage, isNull);
    });
  });
}
