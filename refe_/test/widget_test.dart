import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refe_/main.dart';
import 'package:refe_/features/home/domain/models/project_model.dart';
import 'package:refe_/features/home/data/services/storage_service.dart';
import 'package:refe_/features/home/presentation/controllers/home_controller.dart';
import 'package:refe_/features/home/presentation/widgets/project_card.dart';
import 'package:refe_/features/home/presentation/widgets/confirm_delete_dialog.dart';
import 'package:refe_/features/viewer_3d/data/services/viewer_3d_js_bridge.dart';
import 'package:refe_/features/viewer_3d/presentation/controllers/viewer_3d_controller.dart';
import 'package:refe_/features/viewer_3d/presentation/widgets/bim_metadata_bottom_sheet.dart';
import 'package:refe_/features/viewer_3d/presentation/widgets/bim_tabbar.dart';
import 'package:refe_/features/viewer_3d/presentation/widgets/dynamic_bim_workspace.dart';
import 'package:refe_/features/viewer_3d/domain/models/measurement_model.dart';
import 'package:refe_/features/viewer_3d/domain/utils/bim_nomenclature_mapper.dart';
import 'package:refe_/features/viewer_3d/presentation/widgets/measure_mode_overlay.dart';

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

class RecordingViewer3dJsBridge extends Viewer3dJsBridge {
  final List<int> selectCalls = [];
  final List<int> focusCalls = [];
  int clearSimilarCalls = 0;

  @override
  Future<void> selectElementByExpressId(int expressID, {bool focusCamera = true}) async {
    selectCalls.add(expressID);
  }

  @override
  Future<void> focusElementInDynamicView(int expressID) async {
    focusCalls.add(expressID);
  }

  @override
  Future<void> clearSimilarHighlights() async {
    clearSimilarCalls++;
  }

  bool? proximityEnabled;

  @override
  Future<void> setProximityDimensionEnabled(bool enabled) async {
    proximityEnabled = enabled;
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

  group('3D Free Span Measurement Mode Tests', () {
    test('MeasurementModel parses map and computes deltas correctly', () {
      final measMap = {
        'id': 'meas_999',
        'distance': 3.456,
        'type': 'span',
        'label': 'Vão Livre: 3,46 m',
        'startPoint': {'x': 1.0, 'y': 0.0, 'z': 2.0},
        'endPoint': {'x': 4.456, 'y': 0.0, 'z': 2.0},
        'deltaX': 3.456,
        'deltaY': 0.0,
        'deltaZ': 0.0,
      };

      final model = MeasurementModel.fromMap(measMap);

      expect(model.id, 'meas_999');
      expect(model.distance, 3.456);
      expect(model.formattedDistance, '3,46 m');
      expect(model.isSpan, isTrue);
      expect(model.isPointToPoint, isFalse);
      expect(model.formattedDeltaX, '3,46 m');
      expect(model.formattedDeltaY, '0,00 m');
    });

    test('Viewer3DController measurement state toggles and properties', () async {
      final controller = Viewer3DController();

      expect(controller.isMeasureMode, isFalse);
      expect(controller.measureSubMode, 'span');
      expect(controller.hasMeasurements, isFalse);
      expect(controller.measurementCount, 0);

      await controller.setMeasureMode(true, mode: 'span');
      expect(controller.isMeasureMode, isTrue);
      expect(controller.measureSubMode, 'span');

      await controller.setMeasureSubMode('point_to_point');
      expect(controller.measureSubMode, 'point_to_point');

      await controller.clearMeasurements();
      expect(controller.hasMeasurements, isFalse);
      expect(controller.lastMeasurement, isNull);

      await controller.setMeasureMode(false);
      expect(controller.isMeasureMode, isFalse);
    });

    testWidgets('MeasureModeOverlay renders exact presentation card and submode tabs', (WidgetTester tester) async {
      final controller = Viewer3DController();
      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MeasureModeOverlay(
              controller: controller,
              onClose: () => closed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica o card exato do usuário
      expect(find.text('Modo de Medição'), findsOneWidget);
      expect(
        find.text('Calcule vãos livres (spans) diretamente no modelo 3D com um toque.'),
        findsOneWidget,
      );

      // Verifica abas dos submodos
      expect(find.text('Vão Livre (1 Toque)'), findsOneWidget);
      expect(find.text('Ponto a Ponto'), findsOneWidget);

      // Botão Concluir
      expect(find.text('Concluir'), findsOneWidget);
      await tester.tap(find.text('Concluir'));
      expect(closed, isTrue);
    });
  });

  group('Randon IFC Catalog & Local Streaming Tests', () {
    testWidgets('App renders randon.ifc card in HomeScreen catalog', (WidgetTester tester) async {
      final randonProject = ProjectModel(
        id: 'randon-seed-1',
        name: 'randon.ifc',
        filePath: '/storage/projects/randon.ifc',
        fileSizeMB: 92.12,
        format: 'IFC',
        createdAt: DateTime(2026, 11, 1),
      );

      final fakeStorage = FakeStorageService(initial: [randonProject]);
      final controller = HomeController(storageService: fakeStorage);

      await tester.pumpWidget(BimViewerApp(homeController: controller));
      await tester.pumpAndSettle();

      expect(find.text('randon.ifc'), findsOneWidget);
      expect(find.text('.IFC'), findsOneWidget);
      expect(find.text('92.12 MB'), findsOneWidget);
      expect(find.text('Visualizar'), findsOneWidget);
    });

    test('Viewer3DController resilience, section cut, and ViewCube presets work properly', () async {
      final controller = Viewer3DController();

      expect(controller.isSectionCutActive, isFalse);
      expect(controller.sectionCutRatio, 0.75);
      expect(controller.currentCameraView, 'iso');
      expect(controller.renderProcessCrashed, isFalse);

      await controller.toggleSectionCut();
      expect(controller.isSectionCutActive, isTrue);

      await controller.setSectionCutRatio(0.45);
      expect(controller.sectionCutRatio, 0.45);

      await controller.setCameraView('top');
      expect(controller.currentCameraView, 'top');

      controller.handleRenderProcessGone(true);
      expect(controller.renderProcessCrashed, isTrue);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNotNull);

      controller.prepareWebViewRecovery('/storage/projects/randon.ifc', 'IFC');
      expect(controller.renderProcessCrashed, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.isLoading, isTrue);
    });
  });

  group('Viewer3dJsBridge & Clean Architecture Refactoring Tests', () {
    test('Viewer3dJsBridgeListener events update controller state cleanly', () {
      final controller = Viewer3DController();

      // Inicialmente não está pronto
      expect(controller.isViewerReady, isFalse);
      expect(controller.isLoading, isTrue);

      // Dispara onViewerReady via listener
      controller.onViewerReady();
      expect(controller.isViewerReady, isTrue);
      expect(controller.isLoading, isFalse);

      // Dispara onLoadingProgress
      controller.onLoadingProgress(45.0);
      expect(controller.loadingProgress, 45.0);
      expect(controller.isLoading, isTrue);

      // Dispara onElementSelected
      const metadata = BimElementMetadata(
        expressID: 550,
        name: 'Parede básica:Alvenaria 15cm:550',
        category: 'IfcWall',
        psets: {},
      );
      controller.onElementSelected(metadata);
      expect(controller.selectedElement, isNotNull);
      expect(controller.selectedElement?.expressID, 550);
      expect(controller.selectedElement?.friendlyCategory, 'Parede');
      expect(controller.selectedElement?.cleanTitle, 'Alvenaria 15cm');
      expect(controller.selectedElement?.familyName, 'Parede básica');

      // Dispara onElementDeselected
      controller.onElementDeselected();
      expect(controller.selectedElement, isNull);

      // Dispara onVisibilityChanged
      controller.onVisibilityChanged(isIsolated: true, isolatedId: 550);
      expect(controller.isIsolated, isTrue);
      expect(controller.isolatedElementId, 550);
      expect(controller.isElementIsolated(550), isTrue);

      controller.onVisibilityChanged(isIsolated: false, isolatedId: null);
      expect(controller.isIsolated, isFalse);
      expect(controller.isolatedElementId, isNull);

      // Dispara medições via listener
      controller.onMeasureModeChanged(enabled: true, mode: 'point_to_point');
      expect(controller.isMeasureMode, isTrue);
      expect(controller.measureSubMode, 'point_to_point');

      controller.onMeasurementWaitingPoint(isWaiting: true, message: 'Selecione ponto B');
      expect(controller.isWaitingSecondPoint, isTrue);
      expect(controller.measureStatusMessage, 'Selecione ponto B');

      final meas = MeasurementModel.fromMap({
        'id': 'meas_1',
        'distance': 5.2,
        'type': 'point_to_point',
        'label': 'Distância: 5,20 m',
        'startPoint': {'x': 0.0, 'y': 0.0, 'z': 0.0},
        'endPoint': {'x': 5.2, 'y': 0.0, 'z': 0.0},
        'deltaX': 5.2,
        'deltaY': 0.0,
        'deltaZ': 0.0,
      });
      controller.onMeasurementCreated(meas);
      expect(controller.hasMeasurements, isTrue);
      expect(controller.measurementCount, 1);
      expect(controller.lastMeasurement?.distance, 5.2);
      expect(controller.isWaitingSecondPoint, isFalse);

      controller.onMeasurementRemoved();
      expect(controller.hasMeasurements, isFalse);

      // Dispara erro
      controller.onViewerError('Erro de WebGL');
      expect(controller.errorMessage, 'Erro de WebGL');
      expect(controller.isLoading, isFalse);
    });

    test('BimElementMetadata string decoding and metric extraction', () {
      final decoded = BimElementMetadata.decodeIfcString(r'Laje de Concreto \X\E7\X\E3o');
      expect(decoded, 'Laje de Concreto ção');

      const metadata = BimElementMetadata(
        expressID: 99,
        name: 'Telhado',
        category: 'IfcRoof',
        psets: {
          'Dimensões': {
            'Área': '150.50',
            'Volume': '45.2',
            'Inclinação': '30',
          }
        },
      );

      final metrics = metadata.keyMetrics;
      expect(metrics['Área Total'], '150,50 m²');
      expect(metrics['Volume'], '45,20 m³');
      expect(metrics['Caimento'], '30°');
    });
  });

  group('Dynamic View (Visualização Dinâmica Horizontal, Níveis IFC & openBIM Specs)', () {
    test('BimNomenclatureMapper decodes UTF-16 IFC strings and standardizes nomenclature', () {
      final decodedUtf16 = BimElementMetadata.decodeIfcString(r'Funda\X2\00E700E3\X0\o N\X\EDvel 1');
      expect(decodedUtf16, 'Fundação Nível 1');

      expect(BimNomenclatureMapper.formatPropertyKey('LoadBearing'), 'Função Estrutural (Portante)');
      expect(BimNomenclatureMapper.formatPropertyKey('IsExternal'), 'Exposição Externa (Envoltória/Fachada)');
      expect(BimNomenclatureMapper.formatPropertyValue('LoadBearing', '.T.'), 'Sim');
      expect(BimNomenclatureMapper.formatPropertyValue('Width', 0.2), '0,20 m (200 mm)');
      expect(BimNomenclatureMapper.formatPropertyValue('GrossArea', 48.5), '48,50 m²');
    });

    testWidgets('NubankBimTabBar renders Dynamic View button and triggers callback', (WidgetTester tester) async {
      bool dynamicClicked = false;
      const metadata = BimElementMetadata(
        expressID: 61,
        name: 'Parede básica:Genérico - 200 mm:328802',
        category: 'IfcWallStandardCase',
        psets: {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NubankBimTabBar(
              metadata: metadata,
              isIsolated: false,
              onViewBimData: () {},
              onHideElement: () {},
              onIsolateElement: () {},
              onDynamicView: () => dynamicClicked = true,
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dinâmica'), findsOneWidget);
      await tester.tap(find.text('Dinâmica'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(dynamicClicked, isTrue);
    });

    test('Viewer3DController manages Dynamic View state, split ratio, and storey filtering', () async {
      final controller = Viewer3DController();
      addTearDown(controller.dispose);
      controller.onViewerReady();

      final specs = BimProjectSpecs.fromMap({
        'schema': 'IFC2X3',
        'viewDefinition': 'CoordinationView_V2.0',
        'authoringApp': 'Autodesk Revit 2027 (PTB)',
        'projectName': 'Projeto Turim',
        'projectNumber': '0029',
        'totalElements': 12,
        'storeys': [
          {'expressID': 26, 'name': r'N\X\EDvel 1', 'elevationMeters': 0.0, 'totalElementsInStorey': 11},
          {'expressID': 30, 'name': r'N\X\EDvel 2', 'elevationMeters': 7.6, 'totalElementsInStorey': 1},
          {'expressID': 34, 'name': r'N\X\EDvel 3', 'elevationMeters': 14.9, 'totalElementsInStorey': 0},
        ],
      });
      controller.onBimProjectSpecsLoaded(specs);
      expect(controller.availableStoreys.length, 3);
      expect(controller.availableStoreys[0].name, 'Nível 1');

      final element = BimElementMetadata.fromMap({
        'expressID': 354,
        'name': 'M_Fixo:0915 x 1830mm:330694',
        'category': 'IfcWindow',
        'hostStoreyId': 26,
        'hostStoreyName': 'Nível 1',
        'analytics': {
          'typeName': 'M_Fixo:0915 x 1830mm',
          'hostStoreyId': 26,
          'hostStoreyName': 'Nível 1',
          'totalInProject': 3,
          'totalCategoryInProject': 3,
          'allInstanceIds': [354, 571, 582],
          'countByStorey': {'26': 3, '30': 0, '34': 0},
          'instanceIdsByStorey': {
            '26': [354, 571, 582],
            '30': [],
            '34': [],
          },
          'categoryCountByStorey': {'26': 3, '30': 0, '34': 0},
          'totalMetrics': {'lengthM': 2.75, 'areaM2': 5.02, 'volumeM3': 1.0},
          'metricsByStorey': {
            '26': {'lengthM': 2.75, 'areaM2': 5.02, 'volumeM3': 1.0},
            '30': {'lengthM': 0.0, 'areaM2': 0.0, 'volumeM3': 0.0},
          },
        },
        'psets': {
          'Pset_WindowCommon': {'IsExternal': '.T.', 'Reference': '0915 x 1830mm'},
        },
      });
      controller.onElementSelected(element);

      await controller.enterDynamicView();
      expect(controller.isDynamicViewActive, isTrue);
      expect(controller.dynamicSplitRatio, 0.46);

      // Proteção contra toque acidental no vazio durante a Visualização Dinâmica
      controller.onElementDeselected();
      expect(controller.selectedElement, isNotNull);

      // Ajuste de tamanho da divisória
      controller.setDynamicSplitRatio(0.60);
      expect(controller.dynamicSplitRatio, 0.60);
      controller.setDynamicSplitRatio(0.95); // Deve limitar em 0.72
      expect(controller.dynamicSplitRatio, 0.72);
      controller.resetDynamicSplitRatio();
      expect(controller.dynamicSplitRatio, 0.46);

      // Filtro por Nível
      await controller.setStoreyFilter(26);
      expect(controller.selectedStoreyFilterId, 26);
      expect(element.analytics!.countForStorey(26), 3);

      await controller.setStoreyFilter(30);
      expect(controller.selectedStoreyFilterId, 30);
      expect(element.analytics!.countForStorey(30), 0);

      // Altera estados temporários dentro da Visualização Dinâmica (Isolar, Raio-X, Similares 3D)
      expect(controller.isIsolated, isFalse);
      await controller.isolateSelectedElement();
      expect(controller.isIsolated, isTrue);
      await controller.toggleDynamicXrayContext();
      expect(controller.isDynamicXrayActive, isTrue);
      await controller.toggleHighlightSimilarIn3D();
      expect(controller.highlightSimilarIn3D, isTrue);

      // Ao sair da Visualização Dinâmica, TUDO deve voltar exatamente como estava antes
      await controller.exitDynamicView();
      expect(controller.isDynamicViewActive, isFalse);
      expect(controller.isIsolated, isFalse);
      expect(controller.isDynamicXrayActive, isFalse);
      expect(controller.highlightSimilarIn3D, isFalse);
      expect(controller.selectedStoreyFilterId, isNull);
      expect(controller.selectedElement?.expressID, 354);
    });

    testWidgets('DynamicBimWorkspace updates quantities dynamically on Storey Dropdown change and resizes split view', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = Viewer3DController();
      addTearDown(controller.dispose);
      controller.onViewerReady();
      controller.onBimProjectSpecsLoaded(BimProjectSpecs.fromMap({
        'schema': 'IFC2X3',
        'viewDefinition': 'CoordinationView_V2.0',
        'authoringApp': 'Autodesk Revit 2027 (PTB)',
        'projectName': 'Projeto Turim',
        'projectNumber': '0029',
        'projectPhase': 'Projeto Arquitetônico',
        'address': 'Araraquara - SP • Brasil',
        'totalElements': 12,
        'storeys': [
          {'expressID': 26, 'name': 'Nível 1', 'elevationMeters': 0.0, 'totalElementsInStorey': 11},
          {'expressID': 30, 'name': 'Nível 2', 'elevationMeters': 7.6, 'totalElementsInStorey': 1},
        ],
        'categorySummary': {'IfcWall': 6, 'IfcWindow': 3},
      }));

      controller.onElementSelected(BimElementMetadata.fromMap({
        'expressID': 354,
        'name': 'M_Fixo:0915 x 1830mm:330694',
        'category': 'IfcWindow',
        'hostStoreyId': 26,
        'hostStoreyName': 'Nível 1',
        'materials': ['Alumínio Anodizado • 50 mm'],
        'analytics': {
          'typeName': 'M_Fixo:0915 x 1830mm',
          'hostStoreyId': 26,
          'hostStoreyName': 'Nível 1',
          'totalInProject': 3,
          'totalCategoryInProject': 3,
          'allInstanceIds': [354, 571, 582],
          'countByStorey': {'26': 3, '30': 0},
          'instanceIdsByStorey': {'26': [354, 571, 582], '30': []},
          'categoryCountByStorey': {'26': 3, '30': 0},
          'totalMetrics': {'lengthM': 2.75, 'areaM2': 5.02, 'volumeM3': 1.0},
          'metricsByStorey': {
            '26': {'lengthM': 2.75, 'areaM2': 5.02, 'volumeM3': 1.0},
            '30': {'lengthM': 0.0, 'areaM2': 0.0, 'volumeM3': 0.0},
          },
        },
        'psets': {
          'Pset_WindowCommon': {'IsExternal': '.T.', 'Reference': '0915 x 1830mm'},
        },
      }));

      await controller.enterDynamicView();

      final project = ProjectModel(
        id: 'proj-1',
        name: 'ajustado.ifc',
        filePath: '/local/ajustado.ifc',
        fileSizeMB: 1.2,
        format: 'IFC',
        createdAt: DateTime(2026, 11, 8),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                return DynamicBimWorkspace(
                  controller: controller,
                  project: project,
                  totalWidth: 1600,
                  leftViewportWidth: 1600 * controller.dynamicSplitRatio,
                  onExit: () => controller.exitDynamicView(),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica exibição inicial (Todos os Níveis -> 3 unidades + Especificações padronizadas)
      expect(find.text('0915 x 1830mm'), findsWidgets);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Exposição Externa (Envoltória/Fachada)'), findsOneWidget);

      // Seleciona "Nível 2 (+7,60 m)" no DropdownList e valida atualização dinâmica para 0 unidades
      await tester.tap(find.byKey(const ValueKey('storey_filter_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nível 2 (+7,60 m)').last);
      await tester.pumpAndSettle();

      expect(controller.selectedStoreyFilterId, 30);
      expect(find.text('0'), findsOneWidget);
      expect(find.textContaining('Nenhuma unidade'), findsOneWidget);

      // Filtra para ver a aba "Arquivo BIM" com as especificações importadas do arquivo IFC
      await tester.tap(find.text('Arquivo BIM'));
      await tester.pumpAndSettle();
      expect(find.text('Projeto Turim'), findsOneWidget);
      expect(find.text('Autodesk Revit 2027 (PTB)'), findsOneWidget);
      expect(find.text('IFC2X3'), findsOneWidget);

      // Arrasta a divisória central para personalizar o tamanho das janelas
      final handleFinder = find.byIcon(Icons.drag_indicator_rounded);
      await tester.drag(handleFinder, const Offset(160, 0));
      await tester.pumpAndSettle();
      expect(controller.dynamicSplitRatio, greaterThan(0.52));

      await controller.exitDynamicView();
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('DynamicBimWorkspace blocks rapid clicks on 146 columns until current load and render complete', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final bridge = RecordingViewer3dJsBridge();
      final controller = Viewer3DController(jsBridge: bridge);
      addTearDown(controller.dispose);
      controller.onViewerReady();

      final columnIds = List<int>.generate(146, (i) => 1001 + i);

      Map<String, dynamic> buildColumnPayload(int expressId, {bool alreadyFocused = false}) {
        return {
          'expressID': expressId,
          'name': 'M_Pilar Retangular Concreto:40x60cm:$expressId',
          'category': 'IfcColumn',
          'hostStoreyId': 10,
          'hostStoreyName': 'Térreo Estrutural',
          'alreadyFocusedInJs': alreadyFocused,
          'analytics': {
            'typeName': 'M_Pilar Retangular Concreto:40x60cm',
            'hostStoreyId': 10,
            'hostStoreyName': 'Térreo Estrutural',
            'totalInProject': 146,
            'totalCategoryInProject': 146,
            'allInstanceIds': columnIds,
            'countByStorey': {'10': 146},
            'instanceIdsByStorey': {'10': columnIds},
            'categoryCountByStorey': {'10': 146},
            'totalMetrics': {'lengthM': 87.6, 'areaM2': 315.36, 'volumeM3': 126.14},
            'metricsByStorey': {
              '10': {'lengthM': 87.6, 'areaM2': 315.36, 'volumeM3': 126.14},
            },
          },
          'psets': {
            'Pset_ColumnCommon': {'LoadBearing': '.T.', 'Reference': 'P-40x60'},
          },
        };
      }

      controller.onBimProjectSpecsLoaded(BimProjectSpecs.fromMap({
        'schema': 'IFC4',
        'projectName': 'Galpão Industrial Randon',
        'totalElements': 850,
        'storeys': [
          {'expressID': 10, 'name': 'Térreo Estrutural', 'elevationMeters': 0.0, 'totalElementsInStorey': 850},
        ],
        'categorySummary': {'IfcColumn': 146},
      }));

      controller.onElementSelected(BimElementMetadata.fromMap(buildColumnPayload(1001)));
      await controller.enterDynamicView();

      final project = ProjectModel(
        id: 'proj-randon',
        name: 'randon.ifc',
        filePath: '/local/randon.ifc',
        fileSizeMB: 92.4,
        format: 'IFC',
        createdAt: DateTime(2026, 11, 8),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                return DynamicBimWorkspace(
                  controller: controller,
                  project: project,
                  totalWidth: 1600,
                  leftViewportWidth: 1600 * controller.dynamicSplitRatio,
                  onExit: () => controller.exitDynamicView(),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Inspecionando 1 de 146 nesta vista'), findsOneWidget);
      expect(controller.isSwitchingDynamicElement, isFalse);

      // Dispara 8 cliques rápidos consecutivos na seta ">" antes de concluir o carregamento do Pilar #2
      final nextBtn = find.byKey(const ValueKey('instance_next_button'));
      await tester.tap(nextBtn);
      await tester.tap(nextBtn);
      await tester.tap(nextBtn);
      await tester.pump(const Duration(milliseconds: 40));

      // Verifica que os cliques excedentes foram bloqueados e o estado visual de carregamento está ativo
      expect(controller.isSwitchingDynamicElement, isTrue);
      expect(find.byKey(const ValueKey('instance_loading_indicator')), findsOneWidget);
      expect(find.text('Carregando e renderizando peça...'), findsOneWidget);

      // Mais 5 tentativas de clique enquanto o botão está desabilitado aguardando renderização
      await tester.tap(nextBtn, warnIfMissed: false);
      await tester.tap(nextBtn, warnIfMissed: false);
      await controller.inspectPieceInstance(1005);
      await controller.inspectPieceInstance(1006);
      await controller.inspectPieceInstance(1007);

      // Apenas UMA chamada JS (1002) deve ter passado pela ponte! Zero gargalo ou fila concorrente
      expect(bridge.selectCalls, [1002]);
      expect(bridge.focusCalls, isEmpty);
      expect(bridge.clearSimilarCalls, 0);

      // Agora simula a conclusão do carregamento e frame WebGL do Pilar #2 (1002)
      controller.onElementSelected(
        BimElementMetadata.fromMap(buildColumnPayload(1002, alreadyFocused: true)),
      );

      // Aguarda o commit do frame do Flutter (addPostFrameCallback)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));

      expect(controller.isSwitchingDynamicElement, isFalse);
      expect(find.text('Inspecionando 2 de 146 nesta vista'), findsOneWidget);
      expect(find.byKey(const ValueKey('instance_loading_indicator')), findsNothing);
      // Zero chamadas redundantes de foco ou limpeza de subsets similares
      expect(bridge.focusCalls, isEmpty);
      expect(bridge.clearSimilarCalls, 0);

      // Com o carregamento e renderização finalizados, o próximo clique avança normalmente para o Pilar #3 (1003)
      await tester.tap(nextBtn);
      await tester.pump(const Duration(milliseconds: 40));
      expect(bridge.selectCalls, [1002, 1003]);
      expect(controller.isSwitchingDynamicElement, isTrue);

      await controller.exitDynamicView();
      await tester.pump(const Duration(milliseconds: 500));
    });

    group('Dynamic View Proximity Dimension Tests (<= 6.0m)', () {
      test('ProximityDimensionModel parses map correctly and serializes symmetrically', () {
        final rawMap = {
          'targetExpressId': 2001,
          'neighborExpressId': 1420,
          'neighborType': 'Parede',
          'neighborName': 'Alvenaria Bloco 15cm #1420',
          'distanceMeters': 0.354,
          'formattedDistance': '0.35 m',
          'hasNeighbor': true,
        };

        final model = ProximityDimensionModel.fromMap(rawMap);
        expect(model.targetExpressId, 2001);
        expect(model.neighborExpressId, 1420);
        expect(model.neighborType, 'Parede');
        expect(model.neighborName, 'Alvenaria Bloco 15cm #1420');
        expect(model.distanceMeters, 0.354);
        expect(model.formattedDistance, '0.35 m');
        expect(model.hasNeighbor, isTrue);
        expect(model.toString(), '0.35 m até Parede');

        final serialized = model.toMap();
        expect(serialized['targetExpressId'], 2001);
        expect(serialized['neighborExpressId'], 1420);
        expect(serialized['neighborType'], 'Parede');
        expect(serialized['distanceMeters'], 0.354);

        final emptyMap = {
          'targetExpressId': 2001,
          'hasNeighbor': false,
          'distanceMeters': 0.0,
          'formattedDistance': 'Sem elementos a menos de 6 m',
        };
        final emptyModel = ProximityDimensionModel.fromMap(emptyMap);
        expect(emptyModel.hasNeighbor, isFalse);
        expect(emptyModel.toString(), 'Sem elementos a menos de 6 m');
      });

      test('Viewer3DController manages proximity dimension state and toggles', () async {
        final bridge = RecordingViewer3dJsBridge();
        final controller = Viewer3DController(jsBridge: bridge);
        addTearDown(controller.dispose);
        controller.onViewerReady();

        expect(controller.showProximityDimension, isTrue);
        expect(controller.proximityDimension, isNull);

        final element = BimElementMetadata.fromMap({
          'expressID': 501,
          'name': 'Pilar Concreto #501',
          'category': 'IfcColumn',
        });
        controller.onElementSelected(element);
        await controller.enterDynamicView();
        expect(controller.isDynamicViewActive, isTrue);

        final prox = ProximityDimensionModel(
          targetExpressId: 501,
          neighborExpressId: 102,
          neighborType: 'Parede',
          neighborName: 'Parede Divisória #102',
          distanceMeters: 0.28,
          formattedDistance: '0.28 m',
          hasNeighbor: true,
        );

        controller.onProximityDimensionCalculated(prox);
        expect(controller.proximityDimension, equals(prox));

        await controller.toggleProximityDimension();
        expect(controller.showProximityDimension, isFalse);
        expect(bridge.proximityEnabled, isFalse);

        await controller.toggleProximityDimension();
        expect(controller.showProximityDimension, isTrue);
        expect(bridge.proximityEnabled, isTrue);

        await controller.exitDynamicView();
        expect(controller.isDynamicViewActive, isFalse);
        expect(controller.proximityDimension, isNull);
      });

      testWidgets('DynamicBimWorkspace displays proximity dimension card with neighbor and distance', (WidgetTester tester) async {
        final bridge = RecordingViewer3dJsBridge();
        final controller = Viewer3DController(jsBridge: bridge);
        addTearDown(controller.dispose);
        controller.onViewerReady();

        final elementMetadata = BimElementMetadata.fromMap({
          'expressID': 7701,
          'name': 'Bacia Sanitária Deca Vogue Plus',
          'category': 'IfcFlowTerminal',
          'psets': {
            'Identificação': {'Tipo': 'Louça Sanitária'}
          },
          'analytics': {
            'typeName': 'Bacia Sanitária',
            'totalInProject': 12,
            'totalCategoryInProject': 12,
            'allInstanceIds': [7701],
            'hostStoreyId': 100,
            'hostStoreyName': 'Pavimento Térreo',
          },
        });

        controller.onElementSelected(elementMetadata);
        await controller.enterDynamicView();

        final prox = ProximityDimensionModel(
          targetExpressId: 7701,
          neighborExpressId: 8812,
          neighborType: 'Parede',
          neighborName: 'Parede Hidráulica #8812',
          distanceMeters: 0.18,
          formattedDistance: '0.18 m',
          hasNeighbor: true,
        );
        controller.onProximityDimensionCalculated(prox);

        final project = ProjectModel(
          id: 'proj-sanit',
          name: 'sanitarios.ifc',
          filePath: '/local/sanitarios.ifc',
          fileSizeMB: 12.0,
          format: 'IFC',
          createdAt: DateTime(2026, 11, 8),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  return DynamicBimWorkspace(
                    controller: controller,
                    project: project,
                    totalWidth: 1400,
                    leftViewportWidth: 1400 * controller.dynamicSplitRatio,
                    onExit: () => controller.exitDynamicView(),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('DISTÂNCIA AO ELEMENTO MAIS PRÓXIMO'), findsOneWidget);
        expect(find.text('0.18 m'), findsOneWidget);
        expect(find.textContaining('Parede Hidráulica #8812 (ID #8812)'), findsOneWidget);
        expect(find.text('Cota 6m'), findsOneWidget);

        // Testa o botão toggle Cota 6m no HUD da esquerda
        final cotaToggle = find.text('Cota 6m');
        await tester.tap(cotaToggle);
        await tester.pump();
        expect(controller.showProximityDimension, isFalse);
        expect(bridge.proximityEnabled, isFalse);

        await controller.exitDynamicView();
        await tester.pumpAndSettle();
      });
    });
  });
}
