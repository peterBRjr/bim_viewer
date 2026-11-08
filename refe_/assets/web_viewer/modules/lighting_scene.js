/**
 * ThatOpen Engine & Three.js 3D BIM Viewport - Módulo de Iluminação e Cena WebGL
 */

window.BimEngine = window.BimEngine || {};

/**
 * Inicializa a Cena Three.js, Renderizador WebGL Logarítmico, Luzes Técnicas e Grid
 */
function initScene(container) {
  state.isLowSpecDevice = typeof detectHardwareProfile === 'function' ? detectHardwareProfile() : false;
  const maxDpr = state.isLowSpecDevice ? 1.25 : 2.0;
  state.basePixelRatio = Math.min(window.devicePixelRatio || 1, maxDpr);

  // 1. Cena
  state.scene = new THREE.Scene();
  state.scene.background = new THREE.Color(0x0F172A); // Slate Dark do Design System

  // 2. Renderizador WebGL Adaptativo:
  // Em tablets de 4 GB / GPUs Tile-Based de entrada (ex: PowerVR GE8320), desativa logarithmicDepthBuffer
  // para preservar o Hardware Early-Z (Hidden Surface Removal), multiplicando o FPS sem perder qualidade.
  state.renderer = new THREE.WebGLRenderer({
    antialias: true,
    alpha: false,
    powerPreference: 'high-performance',
    precision: 'highp',
    logarithmicDepthBuffer: !state.isLowSpecDevice
  });
  state.renderer.setSize(window.innerWidth, window.innerHeight);
  state.renderer.setPixelRatio(state.basePixelRatio);
  state.renderer.shadowMap.enabled = true;
  state.renderer.shadowMap.type = state.isLowSpecDevice ? THREE.PCFShadowMap : THREE.PCFSoftShadowMap;
  state.renderer.toneMapping = THREE.ACESFilmicToneMapping;
  state.renderer.toneMappingExposure = 1.12;
  state.renderer.localClippingEnabled = true;
  container.appendChild(state.renderer.domElement);

  // 3. Iluminação Técnica de Canteiro de Obras (Hemisphere + Sun + Fill + Ambient)
  const hemiLight = new THREE.HemisphereLight(0xF8FAFC, 0x334155, 0.65);
  hemiLight.position.set(0, 100, 0);
  state.scene.add(hemiLight);

  const ambientLight = new THREE.AmbientLight(0xffffff, 0.40);
  state.scene.add(ambientLight);

  const mainDirLight = new THREE.DirectionalLight(0xFFFBEB, 0.90);
  mainDirLight.position.set(35, 65, 45);
  mainDirLight.castShadow = true;
  const shadowRes = state.isLowSpecDevice ? 1024 : 2048;
  mainDirLight.shadow.mapSize.width = shadowRes;
  mainDirLight.shadow.mapSize.height = shadowRes;
  mainDirLight.shadow.bias = -0.0002;
  state.scene.add(mainDirLight);

  const fillLight = new THREE.DirectionalLight(0xCBD5E1, 0.50);
  fillLight.position.set(-35, 30, -35);
  state.scene.add(fillLight);

  // 4. Grid Técnico de Canteiro de Obras
  state.gridHelper = new THREE.GridHelper(40, 40, 0x2563EB, 0x1E293B);
  state.gridHelper.position.y = -0.05;
  state.scene.add(state.gridHelper);

  // 5. Raycaster para Seleção e Inspeção BIM
  state.raycaster = new THREE.Raycaster();

  // 6. Material de Destaque Semântico (Royal Blue #2563EB)
  state.highlightMaterial = new THREE.MeshStandardMaterial({
    color: 0x2563EB,
    roughness: 0.3,
    metalness: 0.2,
    emissive: 0x1D4ED8,
    emissiveIntensity: 0.35,
    depthTest: true,
    transparent: true,
    opacity: 0.88,
    polygonOffset: true,
    polygonOffsetFactor: -2,
    polygonOffsetUnits: -2,
  });

  // 7. Material Fantasma Translúcido para Revelação de Elementos Ocultados (Amber/Orange #F59E0B)
  state.ghostMaterial = new THREE.MeshStandardMaterial({
    color: 0xF59E0B,
    roughness: 0.4,
    metalness: 0.1,
    emissive: 0xD97706,
    emissiveIntensity: 0.30,
    transparent: true,
    opacity: 0.45,
    depthWrite: false,
  });

  // 7b. Material de Destaque Secundário para Peças Similares no Pavimento (Emerald #10B981)
  state.secondaryHighlightMaterial = new THREE.MeshStandardMaterial({
    color: 0x10B981,
    roughness: 0.32,
    metalness: 0.18,
    emissive: 0x059669,
    emissiveIntensity: 0.32,
    depthTest: true,
    transparent: true,
    opacity: 0.84,
    polygonOffset: true,
    polygonOffsetFactor: -1,
    polygonOffsetUnits: -1,
  });

  // 7c. Material Raio-X Arquitetônico para Contexto da Obra na Visualização Dinâmica
  state.xrayContextMaterial = new THREE.MeshStandardMaterial({
    color: 0x94A3B8,
    roughness: 0.55,
    metalness: 0.08,
    transparent: true,
    opacity: 0.14,
    depthWrite: false,
    side: THREE.DoubleSide,
  });

  // 8. Grupo Dedicado para Cotas e Medições Tridimensionais (Vãos Livres)
  state.measureGroup = new THREE.Group();
  state.measureGroup.name = 'Measurements';
  state.scene.add(state.measureGroup);
}

// Exportações
window.BimEngine.initScene = initScene;
window.initScene = initScene;

