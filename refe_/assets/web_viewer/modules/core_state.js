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
  isLowSpecDevice: false,
  basePixelRatio: 1.5,
  renderFramesRemaining: 15,
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
  // Cota de Proximidade e Anti-Obstrução da Visualização Dinâmica
  dynamicProximityGroup: null,
  showDynamicProximity: true,
  lastProximityData: null,
  occludedGhostIds: new Set(),
  occludedSavedMaterials: new Map(),
};

/**
 * Detecta automaticamente tablets/celulares de entrada (ex: 4 GB RAM, GPUs PowerVR / Mali-G52 / Adreno série 500-610)
 * para calibrar pipeline gráfico sem perda visual e mantendo 100% da qualidade Ultra em iPhones/flagships.
 */
function detectHardwareProfile() {
  try {
    const mem = Number(navigator.deviceMemory || 0);
    const cores = Number(navigator.hardwareConcurrency || 8);
    if ((mem > 0 && mem <= 4) || cores <= 4) {
      return true;
    }
    if (typeof document !== 'undefined') {
      const probeCanvas = document.createElement('canvas');
      const gl = probeCanvas.getContext('webgl') || probeCanvas.getContext('experimental-webgl');
      if (gl) {
        const dbg = gl.getExtension('WEBGL_debug_renderer_info');
        if (dbg) {
          const gpu = String(gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) || '').toLowerCase();
          if (
            gpu.includes('powervr') ||
            gpu.includes('ge8320') ||
            gpu.includes('mali-t') ||
            gpu.includes('mali-g3') ||
            gpu.includes('mali-g5') ||
            /adreno\s*\(tm\)\s*(3|4|5|610|612)/.test(gpu)
          ) {
            return true;
          }
        }
      }
    }
  } catch (e) {}
  return false;
}

/**
 * Solicita renderização sob demanda (On-Demand Rendering) por N frames,
 * zerando o consumo de GPU quando a câmera está parada e liberando fluidez total para a UI Flutter.
 */
function requestRender(frames = 4) {
  const count = Number(frames) || 4;
  if (count > state.renderFramesRemaining) {
    state.renderFramesRemaining = count;
  }
}

/**
 * Envia mensagens estruturadas para o shell Flutter via InAppWebView JS Bridge.
 */
function notifyFlutter(handlerName, data = {}) {
  requestRender(4);
  try {
    if (window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
      window.flutter_inappwebview.callHandler(handlerName, data);
    }
  } catch (err) {
    console.error(`Erro ao invocar JS Bridge '${handlerName}':`, err);
  }
}

// Exportações para namespaces global e BimEngine
window.BimEngine.state = state;
window.BimEngine.detectHardwareProfile = detectHardwareProfile;
window.BimEngine.requestRender = requestRender;
window.BimEngine.notifyFlutter = notifyFlutter;
window.state = state;
window.detectHardwareProfile = detectHardwareProfile;
window.requestRender = requestRender;
window.notifyFlutter = notifyFlutter;

