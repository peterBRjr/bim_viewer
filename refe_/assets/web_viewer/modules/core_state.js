/**
 * ThatOpen Engine & Three.js 3D BIM Viewport - Módulo de Estado Central e JS Bridge
 */

window.BimEngine = window.BimEngine || {};

// Estado global reativo da engine 3D
const state = {
  scene: null,
  camera: null,
  renderer: null,
  controls: null,
  raycaster: null,
  mouse: new THREE.Vector2(),
  currentModel: null,
  selectedObject: null,
  originalMaterial: null,
  highlightMaterial: null,
  ifcLoader: null,
  initialCameraPos: new THREE.Vector3(12, 12, 16),
  initialCameraTarget: new THREE.Vector3(0, 0, 0),
  pointerDownPos: null,
  activePointers: new Set(),
  multiTouchGestureOccurred: false,
  hiddenIds: new Set(),
  isolatedElementId: null,
  isolatedElementIds: new Set(),
  childToParent: new Map(),
  parentToChildren: new Map(),
  originalIndices: null,
  originalGroups: null,
  ghostMaterial: null,
  isPreviewingHidden: false,
  isMeasureMode: false,
  measureSubMode: 'span', // 'span' (vão livre 1 toque) ou 'point_to_point' (2 toques)
  measureGroup: null,
  measurements: [],
  pendingMeasurePoint: null,
  pendingMeasureMarker: null,
  isHeavyModel: false,
  modelBox: new THREE.Box3(),
  sectionPlane: new THREE.Plane(new THREE.Vector3(0, -1, 0), 100),
  isSectionActive: false,
  sectionRatio: 1.0,
  cameraAnimFrame: null,
  pivotAnimFrame: null,
  isElementPivotActive: false,
  activePivotElementId: null,
  gridHelper: null,
  archBumpTexture: null,
  // Estado de Análise BIM, Pavimentos (Storeys) e Visualização Dinâmica
  elementBounds: new Map(),
  storeys: [],
  elementToStorey: new Map(),
  storeyToElements: new Map(),
  elementToType: new Map(),
  typeToElements: new Map(),
  elementMetaIndex: new Map(),
  elementCategoryMap: new Map(),
  elementToPsetIds: new Map(),
  elementToMaterialIds: new Map(),
  relationIndexesReady: false,
  relationIndexPromise: null,
  psetPropsCache: new Map(),
  materialPropsCache: new Map(),
  typePropsCache: new Map(),
  pieceAnalyticsCache: new Map(),
  enrichedPayloadCache: new Map(),
  bimProjectSpecs: null,
  lengthUnitScale: 0.001,
  secondaryHighlightMaterial: null,
  xrayContextMaterial: null,
  isDynamicViewActive: false,
  isTransitioningElement: false,
  isDynamicXrayActive: false,
  dynamicXrayKeepIds: new Set(),
  similarHighlightedIds: [],
  similarSubsetSignature: '',
  preDynamicViewSnapshot: null,
};

/**
 * Envia mensagens estruturadas para o shell Flutter via InAppWebView JS Bridge.
 */
function notifyFlutter(handlerName, data = {}) {
  try {
    if (window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
      window.flutter_inappwebview.callHandler(handlerName, data);
    } else {
      console.log(`[JS Bridge Simulado] -> ${handlerName}:`, data);
    }
  } catch (err) {
    console.error(`Erro ao invocar JS Bridge '${handlerName}':`, err);
  }
}

// Exportações para namespaces global e BimEngine
window.BimEngine.state = state;
window.BimEngine.notifyFlutter = notifyFlutter;
window.state = state;
window.notifyFlutter = notifyFlutter;

