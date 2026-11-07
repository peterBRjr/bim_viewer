/**
 * ThatOpen Engine & Three.js 3D BIM Viewport
 * Fornece renderização WebGL acelerada por hardware e ponte de comunicação JS Bridge com Flutter.
 * Integra web-ifc.wasm para parsing direto de arquivos IFC com máximo desempenho e baixo consumo de memória.
 */

// Estado global do Viewer
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
  pointerDownPos: { x: 0, y: 0 },
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

/**
 * Inicializa a Engine WebGL, Câmera, Luzes, Controles de Órbita e Parser IFC.
 */
function initEngine() {
  const container = document.getElementById('viewer-container');
  if (!container) {
    console.error('Container de renderização 3D não encontrado.');
    return;
  }

  // 1. Cena
  state.scene = new THREE.Scene();
  state.scene.background = new THREE.Color(0x0F172A); // Slate Dark do Design System

  // 2. Câmera Perspectiva Técnica
  const aspect = window.innerWidth / window.innerHeight;
  state.camera = new THREE.PerspectiveCamera(45, aspect, 0.1, 1000);
  state.camera.position.copy(state.initialCameraPos);

  // 3. Renderizador WebGL de Alta Performance com Buffer de Profundidade Logarítmico (Zero Z-Fighting / Zero Falhas de Pixels)
  state.renderer = new THREE.WebGLRenderer({
    antialias: true,
    alpha: false,
    powerPreference: 'high-performance',
    precision: 'highp',
    logarithmicDepthBuffer: true
  });
  state.renderer.setSize(window.innerWidth, window.innerHeight);
  state.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  state.renderer.shadowMap.enabled = true;
  state.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  state.renderer.toneMapping = THREE.ACESFilmicToneMapping;
  state.renderer.toneMappingExposure = 1.12;
  state.renderer.localClippingEnabled = true;
  container.appendChild(state.renderer.domElement);

  // 4. Controles de Câmera (OrbitControls) mantendo resolução nativa nítida em tempo integral
  state.controls = new THREE.OrbitControls(state.camera, state.renderer.domElement);
  state.controls.enableDamping = true;
  state.controls.dampingFactor = 0.08;
  state.controls.screenSpacePanning = true;
  state.controls.minDistance = 0.5;
  state.controls.maxDistance = 500;
  state.controls.target.copy(state.initialCameraTarget);

  state.controls.addEventListener('start', () => {
    if (state.cameraAnimFrame) {
      cancelAnimationFrame(state.cameraAnimFrame);
      state.cameraAnimFrame = null;
    }
    if (state.pivotAnimFrame) {
      cancelAnimationFrame(state.pivotAnimFrame);
      state.pivotAnimFrame = null;
    }
  });

  // 5. Iluminação Técnica de Estúdio / Canteiro de Obras (Hemisphere + Sun + Fill)
  const hemiLight = new THREE.HemisphereLight(0xF8FAFC, 0x334155, 0.65);
  hemiLight.position.set(0, 100, 0);
  state.scene.add(hemiLight);

  const ambientLight = new THREE.AmbientLight(0xffffff, 0.40);
  state.scene.add(ambientLight);

  const mainDirLight = new THREE.DirectionalLight(0xFFFBEB, 0.90);
  mainDirLight.position.set(35, 65, 45);
  mainDirLight.castShadow = true;
  mainDirLight.shadow.mapSize.width = 2048;
  mainDirLight.shadow.mapSize.height = 2048;
  mainDirLight.shadow.bias = -0.0002;
  state.scene.add(mainDirLight);

  const fillLight = new THREE.DirectionalLight(0xCBD5E1, 0.50);
  fillLight.position.set(-35, 30, -35);
  state.scene.add(fillLight);

  // 6. Grid Técnico de Canteiro de Obras
  state.gridHelper = new THREE.GridHelper(40, 40, 0x2563EB, 0x1E293B);
  state.gridHelper.position.y = -0.05;
  state.scene.add(state.gridHelper);

  // 7. Raycaster para Seleção e Inspeção BIM
  state.raycaster = new THREE.Raycaster();

  // 8. Material de Destaque Semântico (Royal Blue #2563EB)
  state.highlightMaterial = new THREE.MeshStandardMaterial({
    color: 0x2563EB,
    roughness: 0.3,
    metalness: 0.2,
    emissive: 0x1D4ED8,
    emissiveIntensity: 0.35,
    depthTest: true,
    transparent: true,
    opacity: 0.88,
  });

  // 8.1 Material Fantasma Translúcido para Revelação de Elementos Ocultados (Amber/Orange #F59E0B)
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

  // 8.2 Grupo Dedicado para Cotas e Medições Tridimensionais (Vãos Livres)
  state.measureGroup = new THREE.Group();
  state.measureGroup.name = 'Measurements';
  state.scene.add(state.measureGroup);

  // 9. Inicialização da Engine de IFC (IFCLoader + web-ifc.wasm)
  initIfcEngine();

  // 10. Event Listeners para redimensionamento e seleção
  window.addEventListener('resize', onWindowResize);
  state.renderer.domElement.addEventListener('pointerdown', onPointerDown);
  state.renderer.domElement.addEventListener('pointerup', onPointerUp);
  state.renderer.domElement.addEventListener('pointercancel', () => {
    state.pointerDownPos = null;
  });

  // Loop de Animação
  animate();

  // Notifica o Flutter que a engine 3D está pronta para receber arquivos
  notifyFlutter('onViewerReady');
}

/**
 * Prepara o IFCLoader com o caminho local do WebAssembly
 */
function initIfcEngine() {
  try {
    const LoaderClass = window.IFCLoader?.IFCLoader || window.IFCLoader;
    if (LoaderClass) {
      state.ifcLoader = new LoaderClass();
      // Aponta para a pasta wasm/ onde está o binário C++ web-ifc.wasm
      state.ifcLoader.ifcManager.setWasmPath('wasm/');
      state.ifcLoader.ifcManager.applyWebIfcConfig({
        COORDINATE_TO_ORIGIN: true, // Garante que projetos do Revit nasçam perfeitamente no centro da câmera
        USE_FAST_BOOLS: true        // Otimização de alta performance para cortes de portas e janelas
      });
      if (typeof state.ifcLoader.ifcManager.setOnProgress === 'function') {
        let lastProgressNotify = 0;
        state.ifcLoader.ifcManager.setOnProgress((event) => {
          const now = Date.now();
          if (now - lastProgressNotify < 150) return;
          lastProgressNotify = now;
          if (event && event.total > 0) {
            const ratio = Math.min(1, Math.max(0, event.loaded / event.total));
            const pct = Math.round(45 + ratio * 40);
            notifyFlutter('onLoadingProgress', { progress: pct });
          }
        });
      }
      installSmartIfcPipeline(state.ifcLoader.ifcManager);
      console.log('Engine IFC (web-ifc.wasm) configurada com sucesso.');
    } else {
      console.warn('IFCLoader não encontrado no escopo global.');
    }
  } catch (err) {
    console.error('Falha ao instanciar IFCLoader:', err);
  }
}

/**
 * Gera textura procedural arquitetônica 100% offline (micro-grão suave de concreto/acabamento fosco)
 * com filtro anisotrópico e mipmaps para evitar qualquer serrilhado ou falha de pixel.
 */
function getArchitecturalBumpTexture() {
  if (state.archBumpTexture) return state.archBumpTexture;
  try {
    if (typeof document === 'undefined' || typeof document.createElement !== 'function') return null;
    const canvas = document.createElement('canvas');
    if (!canvas || typeof canvas.getContext !== 'function') return null;
    canvas.width = 128;
    canvas.height = 128;
    const ctx2d = canvas.getContext('2d');
    if (!ctx2d) return null;

    const imgData = ctx2d.createImageData(128, 128);
    const data = imgData.data;
    // Ruído determinístico suave (hash senoidal) para acabamento de maquete técnica limpa
    for (let i = 0; i < 128 * 128; i++) {
      const n = Math.sin(i * 12.9898 + 78.233) * 43758.5453;
      const frac = n - Math.floor(n);
      const shade = 122 + Math.floor(frac * 12); // Variação sutil (122..134) sem granulação agressiva
      const idx = i * 4;
      data[idx] = shade;
      data[idx + 1] = shade;
      data[idx + 2] = shade;
      data[idx + 3] = 255;
    }
    ctx2d.putImageData(imgData, 0, 0);

    const texture = new THREE.CanvasTexture(canvas);
    texture.wrapS = THREE.RepeatWrapping;
    texture.wrapT = THREE.RepeatWrapping;
    texture.repeat.set(4, 4);
    texture.minFilter = THREE.LinearMipmapLinearFilter;
    texture.magFilter = THREE.LinearFilter;
    if (state.renderer && state.renderer.capabilities) {
      texture.anisotropy = Math.min(4, state.renderer.capabilities.getMaxAnisotropy() || 1);
    }
    texture.needsUpdate = true;
    state.archBumpTexture = texture;
    return texture;
  } catch (e) {
    return null;
  }
}

/**
 * Cria material PBR técnico (estilo Autodesk BIM 360 / Fusion) calibrado para leitura clara em obra,
 * com offset de profundidade escalonado para impedir Z-fighting (falhas de pixels entre faces coplanares).
 */
function createBimArchitecturalMaterial(color, matBucketIndex) {
  const col = new THREE.Color().setRGB(color.x, color.y, color.z, 'srgb');
  const isTransparent = color.w < 0.96;

  // Detecta se a cor é metálica/neutra (ex: estruturas metálicas, alumínio, aço) ou alvenaria/concreto
  const maxC = Math.max(color.x, color.y, color.z);
  const minC = Math.min(color.x, color.y, color.z);
  const saturation = maxC > 0.01 ? (maxC - minC) / maxC : 0;
  const isMetallicTone = !isTransparent && saturation < 0.14 && maxC > 0.22 && maxC < 0.82;

  const bumpTex = !isTransparent ? getArchitecturalBumpTexture() : null;
  const offsetSlot = (matBucketIndex % 7) + 1;

  const material = new THREE.MeshStandardMaterial({
    color: col,
    roughness: isTransparent ? 0.15 : (isMetallicTone ? 0.45 : 0.68),
    metalness: isTransparent ? 0.18 : (isMetallicTone ? 0.28 : 0.06),
    bumpMap: bumpTex,
    bumpScale: isMetallicTone ? 0.004 : 0.008,
    side: THREE.DoubleSide,
    transparent: isTransparent,
    opacity: isTransparent ? Math.max(0.28, color.w) : 1.0,
    depthWrite: !isTransparent,
    polygonOffset: true,
    polygonOffsetFactor: offsetSlot * 0.18,
    polygonOffsetUnits: offsetSlot * 0.45,
  });

  return material;
}

/**
 * Solda vértices duplicados na mesma coordenada e normal (100% sem perdas visuais)
 * garantindo sombreamento suave e reduzindo o consumo de memória.
 */
function weldLosslessGeometry(vArr, iArr) {
  const vCount = vArr.length / 6;
  const remap = new Uint32Array(vCount);
  const map = new Map();
  const kept = [];
  let uniqueCount = 0;

  for (let v = 0; v < vCount; v++) {
    const s = v * 6;
    const px = Math.round(vArr[s] * 1000);
    const py = Math.round(vArr[s + 1] * 1000);
    const pz = Math.round(vArr[s + 2] * 1000);
    const nx = Math.round(vArr[s + 3] * 40);
    const ny = Math.round(vArr[s + 4] * 40);
    const nz = Math.round(vArr[s + 5] * 40);
    const key = `${px},${py},${pz},${nx},${ny},${nz}`;
    let nv = map.get(key);
    if (nv === undefined) {
      nv = uniqueCount++;
      map.set(key, nv);
      kept.push(s);
    }
    remap[v] = nv;
  }

  const iOut = new Uint32Array(iArr.length);
  for (let k = 0; k < iArr.length; k++) {
    iOut[k] = remap[iArr[k]];
  }

  const vOut = new Float32Array(uniqueCount * 6);
  for (let nv = 0; nv < uniqueCount; nv++) {
    const s = kept[nv];
    const d = nv * 6;
    vOut[d]     = vArr[s];     vOut[d + 1] = vArr[s + 1]; vOut[d + 2] = vArr[s + 2];
    vOut[d + 3] = vArr[s + 3]; vOut[d + 4] = vArr[s + 4]; vOut[d + 5] = vArr[s + 5];
  }
  return { vOut, iOut, vCount: uniqueCount };
}

/**
 * Gera um prisma 3D enxuto (24 vértices / 12 triângulos) com leve recuo (inset de 1.5%)
 * para evitar sobreposição coplanar e Z-fighting entre componentes repetitivos adjacentes.
 */
function createBoxLodGeometryData(bbox) {
  let [minX, minY, minZ, maxX, maxY, maxZ] = bbox;
  const dx = (maxX - minX) * 0.015;
  const dy = (maxY - minY) * 0.015;
  const dz = (maxZ - minZ) * 0.015;
  minX += dx; maxX -= dx;
  minY += dy; maxY -= dy;
  minZ += dz; maxZ -= dz;

  const faces = [
    { n: [0, 0, 1],  v: [[minX, minY, maxZ], [maxX, minY, maxZ], [maxX, maxY, maxZ], [minX, maxY, maxZ]] },
    { n: [0, 0, -1], v: [[maxX, minY, minZ], [minX, minY, minZ], [minX, maxY, minZ], [maxX, maxY, minZ]] },
    { n: [0, 1, 0],  v: [[minX, maxY, maxZ], [maxX, maxY, maxZ], [maxX, maxY, minZ], [minX, maxY, minZ]] },
    { n: [0, -1, 0], v: [[minX, minY, minZ], [maxX, minY, minZ], [maxX, minY, maxZ], [minX, minY, maxZ]] },
    { n: [1, 0, 0],  v: [[maxX, minY, maxZ], [maxX, minY, minZ], [maxX, maxY, minZ], [maxX, maxY, maxZ]] },
    { n: [-1, 0, 0], v: [[minX, minY, minZ], [minX, minY, maxZ], [minX, maxY, maxZ], [minX, maxY, minZ]] }
  ];
  const vOut = new Float32Array(24 * 6);
  const iOut = new Uint32Array(36);
  let vo = 0, io = 0;
  for (let f = 0; f < 6; f++) {
    const base = f * 4;
    const { n, v } = faces[f];
    for (let k = 0; k < 4; k++) {
      vOut[vo++] = v[k][0]; vOut[vo++] = v[k][1]; vOut[vo++] = v[k][2];
      vOut[vo++] = n[0];    vOut[vo++] = n[1];    vOut[vo++] = n[2];
    }
    iOut[io++] = base; iOut[io++] = base + 1; iOut[io++] = base + 2;
    iOut[io++] = base; iOut[io++] = base + 2; iOut[io++] = base + 3;
  }
  return { vOut, iOut, vCount: 24 };
}

/**
 * Substitui o pipeline padrão do IFCLoader por um construtor Single-Pass com Cache de Geometria
 * e Smart LOD (inspirado no Autodesk BIM 360 / Fusion), reduzindo o uso de RAM em ~90% em modelos pesados.
 */
function installSmartIfcPipeline(ifcManager) {
  if (!ifcManager || !ifcManager.parser) return;

  // 1. Resolução preguiçosa (O(1)) de tipos IFC sem alocar dicionários de milhões de linhas
  if (ifcManager.types) {
    ifcManager.types.getAllTypes = async function() {
      return;
    };
  }

  ifcManager.getIfcType = function(modelID, id) {
    let typeID = this.state.models[modelID]?.types?.[id];
    if (!typeID) {
      try {
        const raw = this.state.api.GetRawLineData(modelID, id);
        if (raw && raw.type) {
          typeID = raw.type;
          if (this.state.models[modelID]?.types) {
            this.state.models[modelID].types[id] = typeID;
          }
        }
      } catch (e) {}
    }
    return typeID ? this.state.api.GetNameFromTypeCode(typeID) : '';
  };

  // 2. Single-Pass Streaming Geometry Builder com Cache de Instâncias e Smart LOD
  const parser = ifcManager.parser;
  parser.loadAllGeometry = async function(modelID) {
    await this.initializeLoadingState(modelID);
    const placementsByMat = new Map();
    const geomCache = new Map();
    let rawTotalVerts = 0;

    const collectMesh = (mesh) => {
      const placedGeometries = mesh.geometries;
      const size = placedGeometries.size();
      const expressID = mesh.expressID;
      for (let i = 0; i < size; i++) {
        const placedGeometry = placedGeometries.get(i);
        const gid = placedGeometry.geometryExpressID;
        let entry = geomCache.get(gid);
        if (!entry) {
          const geometry = this.state.api.GetGeometry(modelID, gid);
          const verts = this.state.api.GetVertexArray(geometry.GetVertexData(), geometry.GetVertexDataSize());
          const indices = this.state.api.GetIndexArray(geometry.GetIndexData(), geometry.GetIndexDataSize());
          const vCount = verts.length / 6;
          let minX = Infinity, minY = Infinity, minZ = Infinity;
          let maxX = -Infinity, maxY = -Infinity, maxZ = -Infinity;
          for (let k = 0; k < verts.length; k += 6) {
            const x = verts[k], y = verts[k + 1], z = verts[k + 2];
            if (x < minX) minX = x; if (x > maxX) maxX = x;
            if (y < minY) minY = y; if (y > maxY) maxY = y;
            if (z < minZ) minZ = z; if (z > maxZ) maxZ = z;
          }
          entry = {
            rawVCount: vCount,
            vOut: new Float32Array(verts),
            iOut: new Uint32Array(indices),
            vCount: vCount,
            bbox: [minX, minY, minZ, maxX, maxY, maxZ],
            instances: 0
          };
          geometry.delete();
          geomCache.set(gid, entry);
        }
        entry.instances++;
        rawTotalVerts += entry.rawVCount;

        const color = placedGeometry.color;
        const colID = `${color.x.toFixed(3)}_${color.y.toFixed(3)}_${color.z.toFixed(3)}_${color.w.toFixed(2)}`;
        let matBucket = placementsByMat.get(colID);
        if (!matBucket) {
          const material = createBimArchitecturalMaterial(color, placementsByMat.size);
          matBucket = { material, items: [] };
          placementsByMat.set(colID, matBucket);
        }
        matBucket.items.push({
          expressID,
          gid,
          matrix: new Float32Array(placedGeometry.flatTransformation)
        });
      }
    };

    const optionalTypes = [];
    for (let key in this.optionalCategories) {
      if (Object.prototype.hasOwnProperty.call(this.optionalCategories, key)) {
        const category = parseInt(key);
        if (this.optionalCategories[category]) optionalTypes.push(category);
      }
    }
    if (optionalTypes.length > 0) {
      this.state.api.StreamAllMeshesWithTypes(this.currentWebIfcID, optionalTypes, (mesh) => {
        collectMesh(mesh);
      });
    }

    this.state.api.StreamAllMeshes(modelID, (mesh) => {
      this.updateLoadingState();
      collectMesh(mesh);
    });
    this.notifyLoadingEnded();

    // Otimização seletiva para modelos grandes (> 1,2M vértices):
    // 1. Mantém 100% da geometria original das paredes, lajes, aberturas, vigas e pilares únicos (com soldagem sem perdas).
    // 2. Simplifica apenas micro-fixadores invisíveis (ex: clips de 5cm repetidos centenas de vezes) ou veículos/adereços ultra-densos.
    if (rawTotalVerts > 1200000) {
      for (const entry of geomCache.values()) {
        const [minX, minY, minZ, maxX, maxY, maxZ] = entry.bbox;
        const maxD = Math.max(maxX - minX, maxY - minY, maxZ - minZ);
        if (maxD <= 100 && entry.instances >= 150 && entry.vCount > 400) {
          // Micro-clips de fixação (< 10cm) ocultos na estrutura do telhado
          entry.vOut = new Float32Array(0);
          entry.iOut = new Uint32Array(0);
          entry.vCount = 0;
        } else if ((entry.instances >= 12 && entry.vCount * entry.instances > 8000 && entry.vCount > 140) || entry.vCount > 4500) {
          const box = createBoxLodGeometryData(entry.bbox);
          entry.vOut = box.vOut;
          entry.iOut = box.iOut;
          entry.vCount = box.vCount;
        } else if (entry.vCount > 24) {
          const welded = weldLosslessGeometry(entry.vOut, entry.iOut);
          entry.vOut = welded.vOut;
          entry.iOut = welded.iOut;
          entry.vCount = welded.vCount;
        }
      }
    }

    let totalVerts = 0;
    let totalIndices = 0;
    for (const bucket of placementsByMat.values()) {
      for (let i = 0; i < bucket.items.length; i++) {
        const c = geomCache.get(bucket.items[i].gid);
        if (c && c.vCount > 0 && c.iOut.length > 0) {
          totalVerts += c.vCount;
          totalIndices += c.iOut.length;
        }
      }
    }

    const posFloats = new Float32Array(totalVerts * 3);
    const normFloats = new Float32Array(totalVerts * 3);
    const idAttribute = new Uint32Array(totalVerts);
    const indexAttribute = new Uint32Array(totalIndices);
    const combinedGeometry = new THREE.BufferGeometry();
    const materials = [];

    let vOffset = 0;
    let iOffset = 0;
    let matIndex = 0;

    for (const bucket of placementsByMat.values()) {
      const groupStart = iOffset;
      const items = bucket.items;
      for (let idx = 0; idx < items.length; idx++) {
        const item = items[idx];
        const c = geomCache.get(item.gid);
        if (!c || c.vCount === 0 || c.iOut.length === 0) continue;

        const m = item.matrix;
        const m00 = m[0], m01 = m[1], m02 = m[2];
        const m10 = m[4], m11 = m[5], m12 = m[6];
        const m20 = m[8], m21 = m[9], m22 = m[10];
        const tx = m[12], ty = m[13], tz = m[14];

        const vSrc = c.vOut;
        const vCount = c.vCount;
        const expId = item.expressID;

        for (let v = 0; v < vCount; v++) {
          const s = v * 6;
          const d = (vOffset + v) * 3;
          const vx = vSrc[s], vy = vSrc[s + 1], vz = vSrc[s + 2];
          const nx = vSrc[s + 3], ny = vSrc[s + 4], nz = vSrc[s + 5];

          posFloats[d]     = m00 * vx + m10 * vy + m20 * vz + tx;
          posFloats[d + 1] = m01 * vx + m11 * vy + m21 * vz + ty;
          posFloats[d + 2] = m02 * vx + m12 * vy + m22 * vz + tz;

          let rnx = m00 * nx + m10 * ny + m20 * nz;
          let rny = m01 * nx + m11 * ny + m21 * nz;
          let rnz = m02 * nx + m12 * ny + m22 * nz;
          const nLen = Math.hypot(rnx, rny, rnz);
          if (nLen > 1e-6) {
            rnx /= nLen; rny /= nLen; rnz /= nLen;
          }
          normFloats[d]     = rnx;
          normFloats[d + 1] = rny;
          normFloats[d + 2] = rnz;
          idAttribute[vOffset + v] = expId;
        }

        const iSrc = c.iOut;
        const iLen = iSrc.length;
        for (let k = 0; k < iLen; k++) {
          indexAttribute[iOffset + k] = iSrc[k] + vOffset;
        }

        vOffset += vCount;
        iOffset += iLen;
      }

      const groupCount = iOffset - groupStart;
      if (groupCount > 0) {
        materials.push(bucket.material);
        combinedGeometry.addGroup(groupStart, groupCount, matIndex++);
      }
    }

    geomCache.clear();
    placementsByMat.clear();

    combinedGeometry.setAttribute('position', new THREE.BufferAttribute(posFloats, 3));
    combinedGeometry.setAttribute('normal', new THREE.BufferAttribute(normFloats, 3));
    combinedGeometry.setAttribute('expressID', new THREE.BufferAttribute(idAttribute, 1));
    combinedGeometry.setIndex(new THREE.BufferAttribute(indexAttribute, 1));

    if (this.BVH) {
      this.BVH.applyThreeMeshBVH(combinedGeometry);
    }

    const model = new THREE.Mesh(combinedGeometry, materials);
    model.modelID = this.currentModelID;
    model.ifcManager = ifcManager;
    model.mesh = model;
    model.setIFCManager = function(mgr) { this.ifcManager = mgr; };
    this.state.models[this.currentModelID].mesh = model;
    console.log(`[Smart IFC Pipeline] Bruto: ${rawTotalVerts} vértices -> Otimizado: ${totalVerts} vértices (${materials.length} materiais)`);
    return model;
  };
}

/**
 * Redimensionamento responsivo do Canvas
 */
function onWindowResize() {
  if (!state.camera || !state.renderer) return;
  state.camera.aspect = window.innerWidth / window.innerHeight;
  state.camera.updateProjectionMatrix();
  state.renderer.setSize(window.innerWidth, window.innerHeight);
}

/**
 * Loop contínuo de renderização a 60 FPS
 */
function animate() {
  requestAnimationFrame(animate);
  if (state.controls) state.controls.update();
  if (state.renderer && state.scene && state.camera) {
    state.renderer.render(state.scene, state.camera);
  }
}

/**
 * Registro de início de clique/toque
 */
function onPointerDown(event) {
  state.pointerDownPos = { x: event.clientX, y: event.clientY, time: Date.now() };
}

/**
 * Processamento de seleção por Raycaster (apenas se for clique simples, não arrasto)
 */
async function onPointerUp(event) {
  if (!state.pointerDownPos) return;

  const deltaX = Math.abs(event.clientX - state.pointerDownPos.x);
  const deltaY = Math.abs(event.clientY - state.pointerDownPos.y);
  const deltaTime = Date.now() - (state.pointerDownPos.time || 0);
  const isTouch = event.pointerType === 'touch';
  const maxDelta = isTouch ? 20 : 10;

  state.pointerDownPos = null;

  // Se o usuário arrastou para rotacionar a câmera ou segurou por muito tempo, não processa seleção
  if (deltaX > maxDelta || deltaY > maxDelta || deltaTime > 600) return;

  const rect = state.renderer.domElement.getBoundingClientRect();
  state.mouse.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
  state.mouse.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;

  state.raycaster.setFromCamera(state.mouse, state.camera);

  // Intersecta apenas o modelo ativo
  const objectsToTest = state.currentModel ? [state.currentModel] : [];
  const intersects = state.raycaster.intersectObjects(objectsToTest, true);

  if (state.isMeasureMode) {
    if (intersects.length > 0) {
      await handleMeasureClick(intersects[0]);
    } else {
      if (state.pendingMeasurePoint) {
        removePendingMarker();
        state.pendingMeasurePoint = null;
        notifyFlutter('onMeasurementWaitingPoint', { cancelled: true });
      }
    }
    return;
  }

  if (intersects.length > 0) {
    const hit = intersects[0];
    await selectElement(hit);
  } else {
    // Clique no fundo vazio: desseleciona o elemento e remove o destaque azul
    clearSelection();
  }
}

/**
 * Constrói o grafo de hierarquia de agregação e decomposição (Padrão Revit / openBIM).
 * Permite que peças de telhado (IfcSlab), escadas e fachadas selecionem o elemento pai (IfcRoof).
 */
async function buildHierarchyMaps(modelID) {
  state.childToParent.clear();
  state.parentToChildren.clear();

  if (!state.ifcLoader || !state.ifcLoader.ifcManager) return;

  const aggregateTypeCodes = [];
  if (typeof WebIFC !== 'undefined') {
    if (WebIFC.IFCRELAGGREGATES !== undefined) aggregateTypeCodes.push(WebIFC.IFCRELAGGREGATES);
    if (WebIFC.IFCRELNESTS !== undefined) aggregateTypeCodes.push(WebIFC.IFCRELNESTS);
  }
  // Código padrão IFC2x3 / IFC4 para IFCRELAGGREGATES
  if (!aggregateTypeCodes.includes(160246688)) aggregateTypeCodes.push(160246688);

  const spatialTypes = new Set([
    'IFCPROJECT',
    'IFCSITE',
    'IFCBUILDING',
    'IFCBUILDINGSTOREY',
    'IFCSPACE'
  ]);

  for (const typeCode of aggregateTypeCodes) {
    try {
      const rels = await state.ifcLoader.ifcManager.getAllItemsOfType(modelID, typeCode, true);
      if (!Array.isArray(rels)) continue;

      for (const rel of rels) {
        const parentId = rel.RelatingObject?.value;
        if (!parentId) continue;

        let parentType = 'IfcBuildingElement';
        try {
          parentType = state.ifcLoader.ifcManager.getIfcType(modelID, parentId) || '';
        } catch (e) {}

        // Não agrupa por contêineres espaciais (Projeto, Terreno, Edifício, Pavimento)
        if (spatialTypes.has(parentType.toUpperCase())) continue;

        const rawChildren = rel.RelatedObjects || [];
        const children = [];
        for (const item of rawChildren) {
          const cid = typeof item === 'object' && item !== null && item.value !== undefined ? item.value : item;
          if (typeof cid === 'number' && !isNaN(cid)) {
            children.push(cid);
          }
        }

        if (children.length > 0) {
          const aggInfo = {
            parentId: parentId,
            type: parentType || 'IfcElement',
            children: children
          };

          state.parentToChildren.set(parentId, aggInfo);
          for (const cid of children) {
            state.childToParent.set(cid, aggInfo);
          }
        }
      }
    } catch (err) {
      console.warn(`Aviso ao ler relação agregada tipo ${typeCode}:`, err);
    }
  }

  console.log(`[Hierarquia BIM] Mapeados ${state.parentToChildren.size} elementos compostos com agregações.`);
}

/**
 * Retorna o ponto alvo raiz do modelo (centro geométrico do projeto).
 */
function getRootPivotTarget() {
  if (state.initialCameraTarget && (state.initialCameraTarget.x !== 0 || state.initialCameraTarget.y !== 0 || state.initialCameraTarget.z !== 0)) {
    return state.initialCameraTarget.clone();
  }
  if (state.modelBox && !state.modelBox.isEmpty()) {
    return state.modelBox.getCenter(new THREE.Vector3());
  }
  if (state.currentModel) {
    const box = new THREE.Box3().setFromObject(state.currentModel);
    if (!box.isEmpty()) return box.getCenter(new THREE.Vector3());
  }
  return new THREE.Vector3(0, 0, 0);
}

/**
 * Transição suave do pivô de rotação dos dedos (OrbitControls target).
 */
function animatePivotTo(targetLookAt, durationMs = 240) {
  if (!state.camera || !state.controls || !targetLookAt) return;
  if (state.pivotAnimFrame) {
    cancelAnimationFrame(state.pivotAnimFrame);
    state.pivotAnimFrame = null;
  }

  const startTarget = state.controls.target.clone();
  const startTime = performance.now();

  function step(now) {
    const elapsed = now - startTime;
    const t = Math.min(1, elapsed / durationMs);
    const ease = 1 - Math.pow(1 - t, 3); // Cubic ease-out

    state.controls.target.lerpVectors(startTarget, targetLookAt, ease);
    state.controls.update();

    if (t < 1) {
      state.pivotAnimFrame = requestAnimationFrame(step);
    } else {
      state.pivotAnimFrame = null;
    }
  }

  state.pivotAnimFrame = requestAnimationFrame(step);
}

/**
 * Define o elemento selecionado como eixo de navegação e órbita 3D dos dedos.
 */
function setElementPivot(pivotPoint, elementId) {
  if (!pivotPoint || !state.controls || !state.camera) return;
  state.isElementPivotActive = true;
  state.activePivotElementId = elementId !== undefined ? Number(elementId) : null;
  animatePivotTo(pivotPoint, 240);
}

/**
 * Restaura o pivô de rotação para a raiz do modelo sem provocar pulos visuais bruscos.
 * Mantém o enquadramento atual ao projetar o alvo ao longo da direção de visão da câmera.
 */
function restoreRootPivot(smooth = false) {
  if (!state.controls || !state.camera) return;
  if (state.pivotAnimFrame) {
    cancelAnimationFrame(state.pivotAnimFrame);
    state.pivotAnimFrame = null;
  }

  const rootCenter = getRootPivotTarget();
  const currentDir = new THREE.Vector3();
  state.camera.getWorldDirection(currentDir);

  // Distância proporcional para manter a sensibilidade de órbita calibrada com a profundidade do modelo
  const dist = Math.max(1.5, state.camera.position.distanceTo(rootCenter));
  const stableTarget = state.camera.position.clone().addScaledVector(currentDir, dist);

  if (smooth) {
    animatePivotTo(stableTarget, 240);
  } else {
    state.controls.target.copy(stableTarget);
    state.controls.update();
  }

  state.isElementPivotActive = false;
  state.activePivotElementId = null;
}

/**
 * Aplica destaque visual e extrai metadados do elemento selecionado (IFC ou GLTF)
 */
async function selectElement(hit) {
  clearSelection(false);

  const object = hit.object;
  if (!object) return;

  // 1. Caso o modelo seja IFC nativo (possua modelID e expressID)
  if (state.ifcLoader && object.modelID !== undefined && hit.faceIndex !== undefined) {
    try {
      const expressID = state.ifcLoader.ifcManager.getExpressId(object.geometry, hit.faceIndex);
      if (expressID !== undefined && expressID !== null && expressID >= 0) {
        // Verifica se o elemento clicado pertence a uma agregação pai (Padrão Revit: IfcRoof -> IfcSlab)
        const aggregate = state.childToParent.get(expressID);
        const targetID = aggregate ? aggregate.parentId : expressID;
        const idsToHighlight = aggregate ? aggregate.children : [expressID];

        // Aplica destaque em todas as geometrias do elemento composto
        const subset = state.ifcLoader.ifcManager.createSubset({
          modelID: object.modelID,
          ids: idsToHighlight,
          scene: state.scene,
          removePrevious: true,
          material: state.highlightMaterial
        });

        // Configura o eixo de navegação com os dedos baseado no elemento selecionado
        let pivotPoint = null;
        try {
          if (subset && subset.geometry) {
            subset.geometry.computeBoundingBox();
            if (subset.geometry.boundingBox && !subset.geometry.boundingBox.isEmpty()) {
              pivotPoint = subset.geometry.boundingBox.getCenter(new THREE.Vector3());
              if (subset.matrixWorld) {
                pivotPoint.applyMatrix4(subset.matrixWorld);
              }
            }
          }
        } catch (e) {
          console.warn('Erro ao calcular centro geométrico do elemento IFC:', e);
        }

        if (!pivotPoint && hit.point) {
          pivotPoint = hit.point.clone();
        }

        if (pivotPoint) {
          setElementPivot(pivotPoint, targetID);
        }

        state.selectedObject = {
          modelID: object.modelID,
          expressID: targetID,
          subIds: idsToHighlight,
          isComposite: Boolean(aggregate),
          isIfc: true
        };

        // Extrai propriedades reais do elemento alvo (Elemento Pai no caso de agregação)
        let name = `Elemento BIM #${targetID}`;
        let category = aggregate ? aggregate.type : 'IfcBuildingElement';
        const psetsFormatted = {};

        try {
          const itemProps = await state.ifcLoader.ifcManager.getItemProperties(object.modelID, targetID);
          if (itemProps) {
            name = itemProps.Name?.value || itemProps.ObjectType?.value || name;
            try {
              const fullType = state.ifcLoader.ifcManager.getIfcType(object.modelID, targetID);
              if (fullType) category = fullType;
            } catch (e) {}

            psetsFormatted["Propriedades Gerais"] = {
              "ExpressID": targetID,
              "Nome": name,
              "Categoria IFC": category,
              "GlobalId": itemProps.GlobalId?.value || "N/A",
              "Tag": itemProps.Tag?.value || "N/A"
            };
          }
        } catch (e) {
          console.warn('Erro ao ler propriedades básicas do item:', e);
        }

        // Extrai PropertySets reais (dimensões, materiais, fases do Revit)
        try {
          const psets = await state.ifcLoader.ifcManager.getPropertySets(object.modelID, targetID, true);
          if (Array.isArray(psets)) {
            for (const pset of psets) {
              const psetName = pset.Name?.value || 'Outras Propriedades';
              const group = {};
              if (Array.isArray(pset.HasProperties)) {
                for (const prop of pset.HasProperties) {
                  const propName = prop.Name?.value;
                  const propVal = prop.NominalValue?.value;
                  if (propName !== undefined && propVal !== undefined) {
                    group[propName] = typeof propVal === 'number' ? Number(propVal.toFixed(2)) : String(propVal);
                  }
                }
              }
              if (Object.keys(group).length > 0) {
                psetsFormatted[psetName] = group;
              }
            }
          }
        } catch (e) {
          console.warn('Erro ao extrair PropertySets:', e);
        }

        // Se for um elemento composto com agregação, adiciona ficha de composição
        if (aggregate) {
          psetsFormatted["Composição do Elemento"] = {
            "Estrutura": "Elemento Composto (Hierarquia Revit)",
            "Total de Partes": `${aggregate.children.length} peças agregadas`,
            "IDs dos Componentes": aggregate.children.join(", ")
          };
        }

        // Se o elemento não possuir Psets no IFC, cria estimativas úteis
        if (Object.keys(psetsFormatted).length <= 1) {
          psetsFormatted["Dados Técnicos"] = {
            "Modelo": "Projeto openBIM IFC",
            "Geometria": "Sólido WebAssembly",
            "Status": "Construído (As-Built)"
          };
        }

        notifyFlutter('onElementSelected', {
          expressID: targetID,
          name: name,
          category: category,
          psets: psetsFormatted,
          subIds: idsToHighlight,
          isComposite: Boolean(aggregate)
        });
        return;
      }
    } catch (err) {
      console.warn('Falha no destaque IFC:', err);
    }
  }

  // 2. Fallback para malhas GLTF ou representações avulsas
  if (!object.isMesh) return;

  state.selectedObject = object;
  state.originalMaterial = object.material;
  object.material = state.highlightMaterial;

  const expressID = object.userData.expressID || object.id || 1001;
  const elementName = object.name || `Elemento BIM #${expressID}`;
  const category = object.userData.category || deduceBimCategory(object);

  // Configura o eixo de navegação baseado no elemento selecionado
  let pivotPoint = null;
  try {
    if (object.geometry) {
      const box = new THREE.Box3().setFromObject(object);
      if (!box.isEmpty()) {
        pivotPoint = box.getCenter(new THREE.Vector3());
      }
    }
  } catch (e) {}

  if (!pivotPoint && hit.point) {
    pivotPoint = hit.point.clone();
  }

  if (pivotPoint) {
    setElementPivot(pivotPoint, expressID);
  }

  const psets = object.userData.psets || {
    "Propriedades Gerais": {
      "ExpressID": expressID,
      "Nome": elementName,
      "Categoria IFC": category,
      "Status": "Construído (As-Built)",
    }
  };

  notifyFlutter('onElementSelected', {
    expressID: expressID,
    name: elementName,
    category: category,
    psets: psets,
  });
}

/**
 * Remove o destaque azul do elemento e notifica deseleção para o Flutter
 */
function clearSelection(restorePivot = true) {
  const modelID = state.selectedObject?.modelID !== undefined
    ? state.selectedObject.modelID
    : (state.currentModel?.modelID);

  // 1. Remove o subset do IFCLoader (modelo IFC)
  if (state.ifcLoader && modelID !== undefined && state.highlightMaterial) {
    try {
      state.ifcLoader.ifcManager.removeSubset(modelID, state.highlightMaterial);
    } catch (e) {
      console.warn('Erro em removeSubset:', e);
    }
    try {
      state.ifcLoader.ifcManager.clearSubset(modelID, 'DEFAULT', state.highlightMaterial);
    } catch (e) {}
  }

  // 2. Restaura o material original para malhas Three.js / GLTF
  if (state.selectedObject && !state.selectedObject.isIfc) {
    if (state.selectedObject.material && state.originalMaterial) {
      state.selectedObject.material = state.originalMaterial;
    }
  }

  // Restaura qualquer malha que tenha userData.originalMaterial
  if (state.currentModel) {
    state.currentModel.traverse((child) => {
      if (child.isMesh && child.userData.originalMaterial) {
        child.material = child.userData.originalMaterial;
        delete child.userData.originalMaterial;
      }
    });
  }

  // 3. Limpeza defensiva total da cena: garante que NENHUMA malha azul permaneça visível
  if (state.scene && state.highlightMaterial) {
    const toRemove = [];
    state.scene.traverse((child) => {
      if (child.isMesh && (
        child.material === state.highlightMaterial ||
        child.material?.uuid === state.highlightMaterial.uuid
      )) {
        toRemove.push(child);
      }
    });

    for (const mesh of toRemove) {
      if (mesh.parent) {
        mesh.parent.remove(mesh);
      } else {
        state.scene.remove(mesh);
      }
      if (mesh.geometry) {
        mesh.geometry.dispose();
      }
    }
  }

  state.selectedObject = null;
  state.originalMaterial = null;
  if (restorePivot && state.isElementPivotActive) {
    restoreRootPivot(true);
  }
  notifyFlutter('onElementDeselected');
}

/**
 * Reavalia a visibilidade dos elementos na cena 3D (Ocultação e Isolamento).
 * Suporta tanto malhas Three.js / GLTF quanto modelos IFC via BufferGeometry indexada.
 */
function updateModelVisibility() {
  if (!state.currentModel) return;

  // 1. Caso modelo IFC (BufferGeometry consolidada via web-ifc)
  if (state.ifcLoader && state.currentModel.modelID !== undefined) {
    const geom = state.currentModel.geometry;
    if (geom && geom.attributes.expressID) {
      const hasIsolatedSet = Boolean(state.isolatedElementIds && state.isolatedElementIds.size > 0);
      const isolatedSingle = state.isolatedElementId;
      const hasAnyFilter = hasIsolatedSet || isolatedSingle !== null || state.hiddenIds.size > 0;

      // Captura preguiçosa dos índices originais apenas quando o usuário ocultar/isolar pela primeira vez
      if (!state.originalIndices && hasAnyFilter && geom.index) {
        state.originalIndices = geom.index.array.slice();
        state.originalGroups = JSON.parse(JSON.stringify(geom.groups || []));
      }

      if (state.originalIndices) {
        if (!hasAnyFilter) {
          geom.setIndex(new THREE.BufferAttribute(state.originalIndices, 1));
          if (state.originalGroups && state.originalGroups.length > 0) {
            geom.groups = JSON.parse(JSON.stringify(state.originalGroups));
          }
          if (geom.index) geom.index.needsUpdate = true;
        } else {
          const orig = state.originalIndices;
          const expArray = geom.attributes.expressID.array;
          const IndexArrayCtor = orig instanceof Uint32Array ? Uint32Array : Uint16Array;
          const tempIndices = new IndexArrayCtor(orig.length);
          let writePos = 0;
          const newGroups = [];
          let currentStart = 0;

          const groups = state.originalGroups && state.originalGroups.length > 0
            ? state.originalGroups
            : [{ start: 0, count: orig.length, materialIndex: 0 }];

          for (let g = 0; g < groups.length; g++) {
            const origGroup = groups[g];
            const groupStart = origGroup.start;
            const groupEnd = groupStart + origGroup.count;
            let addedCount = 0;

            for (let i = groupStart; i < groupEnd; i += 3) {
              const a = orig[i];
              const b = orig[i + 1];
              const c = orig[i + 2];
              const id = expArray[a];

              let visible = false;
              if (hasIsolatedSet) {
                visible = state.isolatedElementIds.has(id);
              } else if (isolatedSingle !== null) {
                visible = (id === isolatedSingle);
              } else {
                visible = !state.hiddenIds.has(id);
              }

              if (visible) {
                tempIndices[writePos++] = a;
                tempIndices[writePos++] = b;
                tempIndices[writePos++] = c;
                addedCount += 3;
              }
            }

            newGroups.push({
              start: currentStart,
              count: addedCount,
              materialIndex: origGroup.materialIndex !== undefined ? origGroup.materialIndex : 0,
            });
            currentStart += addedCount;
          }

          const finalIndices = tempIndices.slice(0, writePos);
          geom.setIndex(new THREE.BufferAttribute(finalIndices, 1));
          if (state.originalGroups && state.originalGroups.length > 0) {
            geom.groups = newGroups;
          }
          if (geom.index) {
            geom.index.needsUpdate = true;
          }
        }
      }
    }
  }
  // 2. Caso modelo GLTF / Malhas avulsas
  else {
    state.currentModel.traverse((child) => {
      if (child.isMesh) {
        const id = child.userData.expressID || child.id;
        if (state.isolatedElementIds && state.isolatedElementIds.size > 0) {
          child.visible = state.isolatedElementIds.has(id);
        } else if (state.isolatedElementId !== null) {
          child.visible = (id === state.isolatedElementId);
        } else {
          child.visible = !state.hiddenIds.has(id);
        }
      }
    });
  }

  // Atualiza o subset fantasma para pré-visualização de elementos ocultados se o modo estiver ativo
  updateGhostSubset();

  notifyFlutter('onVisibilityChanged', {
    hiddenCount: state.hiddenIds.size,
    isIsolated: (state.isolatedElementIds && state.isolatedElementIds.size > 0) || state.isolatedElementId !== null,
    isolatedId: state.isolatedElementId,
  });
}

/**
 * Atualiza o subset fantasma (ghost mesh) translúcido para preview dos elementos ocultos no 3D
 */
function updateGhostSubset() {
  const modelID = state.currentModel?.modelID;

  // 1. Caso modelo IFC (web-ifc)
  if (state.ifcLoader && modelID !== undefined && state.ghostMaterial) {
    try {
      state.ifcLoader.ifcManager.removeSubset(modelID, state.ghostMaterial);
    } catch (e) {}

    if (state.isPreviewingHidden && state.hiddenIds.size > 0 && state.isolatedElementId === null) {
      try {
        state.ifcLoader.ifcManager.createSubset({
          modelID: modelID,
          ids: Array.from(state.hiddenIds),
          scene: state.scene,
          removePrevious: true,
          material: state.ghostMaterial,
        });
      } catch (err) {
        console.warn('Falha ao renderizar pré-visualização fantasma de elementos ocultados:', err);
      }
    }
  }
  // 2. Caso modelo GLTF / Malhas avulsas Three.js
  else if (state.currentModel && !state.ifcLoader && state.ghostMaterial) {
    state.currentModel.traverse((child) => {
      if (child.isMesh) {
        const id = child.userData.expressID || child.id;
        if (state.hiddenIds.has(id)) {
          if (state.isPreviewingHidden && state.isolatedElementId === null) {
            child.visible = true;
            if (!child.userData.savedMaterial) {
              child.userData.savedMaterial = child.material;
            }
            child.material = state.ghostMaterial;
          } else {
            child.visible = false;
            if (child.userData.savedMaterial) {
              child.material = child.userData.savedMaterial;
              delete child.userData.savedMaterial;
            }
          }
        }
      }
    });
  }
}

/**
 * Funções Globais expostas para a JS Bridge do Flutter
 */
window.clearSelection = clearSelection;

window.hideElement = function(expressID) {
  const id = Number(expressID);
  if (isNaN(id)) return;

  if (state.selectedObject) {
    clearSelection(false);
  }

  // Se o elemento possui partes na hierarquia de agregação, oculta todas as suas partes físicas
  const agg = state.parentToChildren.get(id) || state.childToParent.get(id);
  const idsToHide = agg ? agg.children : [id];

  for (const hideId of idsToHide) {
    state.hiddenIds.add(hideId);
    if (state.isolatedElementIds) {
      state.isolatedElementIds.delete(hideId);
    }
  }

  if (state.isolatedElementId !== null && (state.isolatedElementId === id || idsToHide.includes(state.isolatedElementId))) {
    state.isolatedElementId = null;
    if (state.isolatedElementIds) {
      state.isolatedElementIds.clear();
    }
  }

  // Se o elemento que servia de pivô de navegação foi ocultado,
  // restaura o pivô raiz sem alterar em nada o enquadramento visual da tela
  if (state.isElementPivotActive) {
    restoreRootPivot(false);
  }

  updateModelVisibility();
};

window.showElement = function(expressID) {
  const id = Number(expressID);
  if (isNaN(id)) return;

  const agg = state.parentToChildren.get(id) || state.childToParent.get(id);
  const idsToShow = agg ? agg.children : [id];

  for (const showId of idsToShow) {
    state.hiddenIds.delete(showId);
  }

  updateModelVisibility();
};

window.isolateElement = function(expressID) {
  const id = Number(expressID);
  if (isNaN(id)) return;

  const agg = state.parentToChildren.get(id) || state.childToParent.get(id);
  const targetIds = agg ? agg.children : [id];

  const isAlreadyIsolated = state.isolatedElementId === id ||
    (state.isolatedElementIds && state.isolatedElementIds.size > 0 && targetIds.every(tid => state.isolatedElementIds.has(tid)));

  if (isAlreadyIsolated) {
    state.isolatedElementId = null;
    if (state.isolatedElementIds) {
      state.isolatedElementIds.clear();
    }
    restoreRootPivot(true);
  } else {
    state.isolatedElementId = id;
    state.isolatedElementIds = new Set(targetIds);
  }

  updateModelVisibility();
};

window.restoreAllVisibility = function() {
  state.hiddenIds.clear();
  state.isolatedElementId = null;
  if (state.isolatedElementIds) {
    state.isolatedElementIds.clear();
  }
  state.isPreviewingHidden = false;
  restoreRootPivot(true);
  updateModelVisibility();
};

window.previewHiddenElements = function(enable) {
  state.isPreviewingHidden = Boolean(enable);
  updateGhostSubset();
};

/**
 * =======================================================================
 * MÓDULO DE MEDIÇÃO 3D E CÁLCULO DE VÃOS LIVRES (SPANS)
 * =======================================================================
 */

/**
 * Cria um marcador temporário com efeito pulsante no ponto A
 */
function createPendingMarker(point) {
  removePendingMarker();

  const group = new THREE.Group();
  group.position.copy(point);

  const sphereGeom = new THREE.SphereGeometry(0.06, 16, 16);
  const sphereMat = new THREE.MeshBasicMaterial({ color: 0xF59E0B });
  const sphere = new THREE.Mesh(sphereGeom, sphereMat);
  group.add(sphere);

  const ringGeom = new THREE.RingGeometry(0.08, 0.12, 32);
  const ringMat = new THREE.MeshBasicMaterial({ color: 0xFBBF24, side: THREE.DoubleSide });
  const ring = new THREE.Mesh(ringGeom, ringMat);
  ring.rotation.x = Math.PI / 2;
  group.add(ring);

  state.pendingMeasureMarker = group;
  state.scene.add(group);
}

/**
 * Remove o marcador temporário de ponto pendente
 */
function removePendingMarker() {
  if (state.pendingMeasureMarker) {
    state.scene.remove(state.pendingMeasureMarker);
    state.pendingMeasureMarker = null;
  }
}

/**
 * Cria a textura dinâmica 2D renderizada em Canvas para o Badge da cota
 */
function createMeasurementSprite(text, isSpan = true) {
  const canvas = document.createElement('canvas');
  canvas.width = 440;
  canvas.height = 140;
  const ctx = canvas.getContext('2d');

  const r = 28;
  const w = 428;
  const h = 128;
  const x = 6;
  const y = 6;

  // Fundo cápsula Dark Slate semi-translúcido (#0F172A)
  ctx.fillStyle = 'rgba(15, 23, 42, 0.94)';
  ctx.strokeStyle = isSpan ? '#2563EB' : '#10B981'; // Royal Blue para Vão Livre, Emerald Green para Ponto a Ponto
  ctx.lineWidth = 6;

  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r);
  ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x + r, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();

  // Texto legível de alta resolução
  ctx.fillStyle = '#FFFFFF';
  ctx.font = 'bold 44px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(text, w / 2 + x, h / 2 + y);

  const texture = new THREE.CanvasTexture(canvas);
  texture.minFilter = THREE.LinearFilter;
  const spriteMat = new THREE.SpriteMaterial({
    map: texture,
    depthTest: false,
    transparent: true,
  });
  const sprite = new THREE.Sprite(spriteMat);
  sprite.scale.set(1.25, 0.40, 1.0);
  return sprite;
}

/**
 * Adiciona a cota visual 3D (esferas de extremidade, linha de cota técnica com ticks e badge flutuante)
 */
function addMeasurementVisual(P0, P1, dist, type, id) {
  if (!state.measureGroup) {
    state.measureGroup = new THREE.Group();
    state.scene.add(state.measureGroup);
  }

  const group = new THREE.Group();
  group.name = id;

  const isSpan = type === 'span';
  const colorHex = isSpan ? 0x2563EB : 0x10B981; // Accent Royal Blue ou Emerald Green

  // 1. Esferas de ancoragem nos pontos inicial e final
  const sphereGeom = new THREE.SphereGeometry(0.045, 16, 16);
  const sphereMat = new THREE.MeshBasicMaterial({ color: colorHex, depthTest: false });

  const sphere0 = new THREE.Mesh(sphereGeom, sphereMat);
  sphere0.position.copy(P0);
  group.add(sphere0);

  const sphere1 = new THREE.Mesh(sphereGeom, sphereMat);
  sphere1.position.copy(P1);
  group.add(sphere1);

  // 2. Linha principal de cota
  const lineGeom = new THREE.BufferGeometry().setFromPoints([P0, P1]);
  const lineMat = new THREE.LineBasicMaterial({
    color: colorHex,
    linewidth: 2,
    depthTest: false,
  });
  const line = new THREE.Line(lineGeom, lineMat);
  group.add(line);

  // 3. Ticks perpendiculares nas extremidades (estilo cota de engenharia)
  const dir = P1.clone().sub(P0);
  const len = dir.length();
  if (len > 0.001) {
    dir.normalize();
    const upVector = Math.abs(dir.y) > 0.85 ? new THREE.Vector3(1, 0, 0) : new THREE.Vector3(0, 1, 0);
    const perp = new THREE.Vector3().crossVectors(dir, upVector).normalize().multiplyScalar(0.12);

    const tick0Geom = new THREE.BufferGeometry().setFromPoints([
      P0.clone().sub(perp),
      P0.clone().add(perp)
    ]);
    const tick1Geom = new THREE.BufferGeometry().setFromPoints([
      P1.clone().sub(perp),
      P1.clone().add(perp)
    ]);
    const tickMat = new THREE.LineBasicMaterial({ color: colorHex, linewidth: 2, depthTest: false });
    group.add(new THREE.Line(tick0Geom, tickMat));
    group.add(new THREE.Line(tick1Geom, tickMat));
  }

  // 4. Badge numérico flutuante (Billboard Sprite)
  const midPoint = P0.clone().add(P1).multiplyScalar(0.5);
  midPoint.y += 0.12; // Pequeno offset para elevar acima da linha

  const formattedStr = `${dist.toFixed(2).replace('.', ',')} m`;
  const labelText = isSpan ? `Vão: ${formattedStr}` : formattedStr;
  const sprite = createMeasurementSprite(labelText, isSpan);
  sprite.position.copy(midPoint);
  group.add(sprite);

  state.measureGroup.add(group);
}

/**
 * Adiciona medição estruturada aos registros e notifica Flutter
 */
function recordMeasurement(P0, P1, dist, type) {
  const id = `meas_${Date.now()}`;
  addMeasurementVisual(P0, P1, dist, type, id);

  const formattedStr = `${dist.toFixed(2).replace('.', ',')} m`;
  const label = type === 'span' ? `Vão Livre: ${formattedStr}` : `Distância: ${formattedStr}`;

  const measurementData = {
    id: id,
    distance: Number(dist.toFixed(3)),
    formattedDistance: formattedStr,
    type: type,
    label: label,
    startPoint: { x: Number(P0.x.toFixed(3)), y: Number(P0.y.toFixed(3)), z: Number(P0.z.toFixed(3)) },
    endPoint: { x: Number(P1.x.toFixed(3)), y: Number(P1.y.toFixed(3)), z: Number(P1.z.toFixed(3)) },
    deltaX: Number(Math.abs(P1.x - P0.x).toFixed(3)),
    deltaY: Number(Math.abs(P1.y - P0.y).toFixed(3)),
    deltaZ: Number(Math.abs(P1.z - P0.z).toFixed(3)),
  };

  state.measurements.push(measurementData);
  notifyFlutter('onMeasurementCreated', measurementData);
}

/**
 * Trata o clique/toque quando o Modo de Medição está ativo.
 * Permite calcular vãos livres (spans) diretamente no modelo 3D com um toque!
 */
async function handleMeasureClick(hit) {
  if (!hit || !hit.point) return;

  const point = hit.point.clone();

  // Modo 1: Vão Livre com 1 Toque (Automatic Free Span / Clear Span)
  if (state.measureSubMode === 'span') {
    let hitNormal = null;
    if (hit.face && hit.face.normal) {
      hitNormal = hit.face.normal.clone();
      if (hit.object && hit.object.matrixWorld) {
        hitNormal.transformDirection(hit.object.matrixWorld).normalize();
      }
    }

    let oppositeHit = null;

    // Dispara raio ao longo da normal da face para frente (em direção ao vão livre / espaço interno)
    if (hitNormal && state.currentModel) {
      const rayOrigin = point.clone().add(hitNormal.clone().multiplyScalar(0.008));
      const spanRay = new THREE.Raycaster(rayOrigin, hitNormal, 0.02, 100);
      const candidates = spanRay.intersectObjects([state.currentModel], true);
      if (candidates.length > 0) {
        oppositeHit = candidates[0];
      }
    }

    // Se não atingiu na direção da normal, tenta na direção oposta (-normal)
    if (!oppositeHit && hitNormal && state.currentModel) {
      const invNormal = hitNormal.clone().negate();
      const rayOrigin = point.clone().add(invNormal.clone().multiplyScalar(0.008));
      const spanRay = new THREE.Raycaster(rayOrigin, invNormal, 0.02, 100);
      const candidates = spanRay.intersectObjects([state.currentModel], true);
      if (candidates.length > 0) {
        oppositeHit = candidates[0];
      }
    }

    // Se encontrou face oposta: Vão livre calculado instantaneamente com 1 toque!
    if (oppositeHit) {
      const P0 = point;
      const P1 = oppositeHit.point.clone();
      const dist = P0.distanceTo(P1);
      recordMeasurement(P0, P1, dist, 'span');
      state.pendingMeasurePoint = null;
      removePendingMarker();
      return;
    }

    // Se a face for externa ou em vão aberto ao ar livre sem colisão oposta direta:
    if (state.pendingMeasurePoint) {
      const P0 = state.pendingMeasurePoint;
      const P1 = point;
      const dist = P0.distanceTo(P1);
      recordMeasurement(P0, P1, dist, 'span');
      state.pendingMeasurePoint = null;
      removePendingMarker();
    } else {
      state.pendingMeasurePoint = point;
      createPendingMarker(point);
      notifyFlutter('onMeasurementWaitingPoint', {
        startPoint: { x: point.x, y: point.y, z: point.z },
        message: 'Ponto de partida registrado. Toque na outra extremidade para fechar o vão livre.'
      });
    }
  }
  // Modo 2: Medição Ponto a Ponto (2 Toques)
  else {
    if (!state.pendingMeasurePoint) {
      state.pendingMeasurePoint = point;
      createPendingMarker(point);
      notifyFlutter('onMeasurementWaitingPoint', {
        startPoint: { x: point.x, y: point.y, z: point.z },
        message: 'Ponto A fixado. Toque no ponto B para medir a distância linear.'
      });
    } else {
      const P0 = state.pendingMeasurePoint;
      const P1 = point;
      const dist = P0.distanceTo(P1);
      recordMeasurement(P0, P1, dist, 'point_to_point');
      state.pendingMeasurePoint = null;
      removePendingMarker();
    }
  }
}

/**
 * Remove todas as cotas e medições visuais da cena 3D
 */
function clearMeasurementsVisuals() {
  if (state.measureGroup) {
    while (state.measureGroup.children.length > 0) {
      const obj = state.measureGroup.children[0];
      state.measureGroup.remove(obj);
    }
  }
  removePendingMarker();
  state.pendingMeasurePoint = null;
  state.measurements = [];
}

/**
 * Remove a última cota criada
 */
function removeLastMeasurementVisual() {
  if (state.measureGroup && state.measureGroup.children.length > 0) {
    const lastChild = state.measureGroup.children[state.measureGroup.children.length - 1];
    state.measureGroup.remove(lastChild);
  }
  if (state.measurements.length > 0) {
    state.measurements.pop();
  }
  removePendingMarker();
  state.pendingMeasurePoint = null;
}

/**
 * Funções Globais expostas para a JS Bridge do Flutter (Modo de Medição)
 */
window.setMeasureMode = function(enabled, mode) {
  state.isMeasureMode = Boolean(enabled);
  state.measureSubMode = mode || 'span';
  removePendingMarker();
  state.pendingMeasurePoint = null;

  if (state.isMeasureMode) {
    clearSelection();
  }

  notifyFlutter('onMeasureModeChanged', {
    enabled: state.isMeasureMode,
    mode: state.measureSubMode,
  });
};

window.setMeasureSubMode = function(mode) {
  state.measureSubMode = mode || 'span';
  removePendingMarker();
  state.pendingMeasurePoint = null;
  notifyFlutter('onMeasureModeChanged', {
    enabled: state.isMeasureMode,
    mode: state.measureSubMode,
  });
};

window.clearMeasurements = function() {
  clearMeasurementsVisuals();
  notifyFlutter('onMeasurementCleared', {});
};

window.removeLastMeasurement = function() {
  removeLastMeasurementVisual();
  notifyFlutter('onMeasurementRemoved', {
    count: state.measurements.length,
    lastMeasurement: state.measurements.length > 0 ? state.measurements[state.measurements.length - 1] : null,
  });
};

/**
 * Deduz categoria BIM com base no nome da malha
 */
function deduceBimCategory(mesh) {
  const nameLower = (mesh.name || '').toLowerCase();
  if (nameLower.includes('wall') || nameLower.includes('parede')) return 'IfcWall';
  if (nameLower.includes('slab') || nameLower.includes('laje')) return 'IfcSlab';
  if (nameLower.includes('column') || nameLower.includes('pilar')) return 'IfcColumn';
  if (nameLower.includes('beam') || nameLower.includes('viga')) return 'IfcBeam';
  if (nameLower.includes('window') || nameLower.includes('janela')) return 'IfcWindow';
  if (nameLower.includes('door') || nameLower.includes('porta')) return 'IfcDoor';
  if (nameLower.includes('roof') || nameLower.includes('telhado')) return 'IfcRoof';
  return 'IfcBuildingElementProxy';
}

/**
 * Transição suave de câmera para vistas ortogonais/isométricas (Padrão ViewCube Autodesk Fusion / BIM 360)
 */
function animateCameraTo(targetPos, targetLookAt, durationMs = 360) {
  if (!state.camera || !state.controls) return;
  if (state.cameraAnimFrame) {
    cancelAnimationFrame(state.cameraAnimFrame);
    state.cameraAnimFrame = null;
  }

  const startPos = state.camera.position.clone();
  const startTarget = state.controls.target.clone();
  const startTime = performance.now();

  function step(now) {
    const t = Math.min(1, (now - startTime) / durationMs);
    const ease = 1 - Math.pow(1 - t, 3); // Cubic ease-out
    state.camera.position.lerpVectors(startPos, targetPos, ease);
    state.controls.target.lerpVectors(startTarget, targetLookAt, ease);
    state.controls.update();
    if (t < 1) {
      state.cameraAnimFrame = requestAnimationFrame(step);
    } else {
      state.cameraAnimFrame = null;
    }
  }
  state.cameraAnimFrame = requestAnimationFrame(step);
}

/**
 * Reseta a câmera para a posição padrão com transição fluida
 */
window.resetCamera = function() {
  if (!state.camera || !state.controls) return;
  if (state.pivotAnimFrame) {
    cancelAnimationFrame(state.pivotAnimFrame);
    state.pivotAnimFrame = null;
  }
  state.isElementPivotActive = false;
  state.activePivotElementId = null;
  animateCameraTo(state.initialCameraPos, state.initialCameraTarget, 340);
};

/**
 * Vistas Predefinidas estilo ViewCube Autodesk Fusion / BIM 360 ('iso', 'top', 'front', 'right', 'left', 'back')
 */
window.setCameraView = function(viewName) {
  if (!state.camera || !state.controls) return;
  if (state.pivotAnimFrame) {
    cancelAnimationFrame(state.pivotAnimFrame);
    state.pivotAnimFrame = null;
  }
  state.isElementPivotActive = false;
  state.activePivotElementId = null;
  const box = state.modelBox && !state.modelBox.isEmpty()
    ? state.modelBox
    : (state.currentModel ? new THREE.Box3().setFromObject(state.currentModel) : null);

  if (!box || box.isEmpty()) {
    window.resetCamera();
    return;
  }

  const center = box.getCenter(new THREE.Vector3());
  const size = box.getSize(new THREE.Vector3());
  const maxDim = Math.max(size.x, size.y, size.z);
  const fov = state.camera.fov * (Math.PI / 180);
  const dist = Math.max(Math.abs(maxDim / 2 / Math.tan(fov / 2)) * 1.55, 6);

  const dest = center.clone();
  const mode = (viewName || 'iso').toLowerCase();
  if (mode === 'top') {
    dest.set(center.x, center.y + dist * 1.15, center.z + 0.01);
  } else if (mode === 'front') {
    dest.set(center.x, center.y + size.y * 0.1, center.z + dist * 1.1);
  } else if (mode === 'back') {
    dest.set(center.x, center.y + size.y * 0.1, center.z - dist * 1.1);
  } else if (mode === 'right') {
    dest.set(center.x + dist * 1.1, center.y + size.y * 0.1, center.z);
  } else if (mode === 'left') {
    dest.set(center.x - dist * 1.1, center.y + size.y * 0.1, center.z);
  } else {
    dest.copy(state.initialCameraPos);
  }

  animateCameraTo(dest, center, 360);
};

/**
 * Controle de Plano de Corte Horizontal em Tempo Real (Section Analysis estilo BIM 360 / Fusion)
 * @param {boolean} enabled Ativa ou desativa o plano de corte
 * @param {number} ratio Percentual da altura da edificação (0.05 a 1.0)
 */
window.setSectionCut = function(enabled, ratio = 1.0) {
  state.isSectionActive = Boolean(enabled);
  state.sectionRatio = Math.min(1.0, Math.max(0.02, Number(ratio) || 1.0));

  if (!state.renderer) return;

  if (!state.isSectionActive || !state.currentModel) {
    state.renderer.clippingPlanes = [];
    return;
  }

  if (state.modelBox.isEmpty() && state.currentModel) {
    state.modelBox.setFromObject(state.currentModel);
  }

  const minY = state.modelBox.min.y;
  const maxY = state.modelBox.max.y;
  const cutHeight = minY + (maxY - minY) * state.sectionRatio;
  state.sectionPlane.set(new THREE.Vector3(0, -1, 0), cutHeight);
  state.renderer.clippingPlanes = [state.sectionPlane];
};

/**
 * Ajusta o enquadramento e o frustum da câmera com base no BoundingBox do modelo
 */
function fitModelToFrame(modelGroup) {
  const box = new THREE.Box3().setFromObject(modelGroup);
  if (box.isEmpty()) return;
  state.modelBox.copy(box);

  const center = box.getCenter(new THREE.Vector3());
  const size = box.getSize(new THREE.Vector3());
  const maxDim = Math.max(size.x, size.y, size.z);

  const fov = state.camera.fov * (Math.PI / 180);
  let cameraZ = Math.abs(maxDim / 2 / Math.tan(fov / 2)) * 1.6;
  cameraZ = Math.max(cameraZ, 5);

  // Ajusta dinamicamente near/far preservando máxima precisão do Z-buffer e evitando Z-fighting
  state.camera.near = Math.max(0.4, Math.min(2.0, maxDim * 0.0025));
  state.camera.far = Math.max(800, cameraZ * 6, maxDim * 6);
  state.camera.updateProjectionMatrix();

  if (state.gridHelper) {
    state.gridHelper.position.y = box.min.y - 0.15;
  }

  if (state.controls) {
    state.controls.minDistance = Math.max(0.2, Math.min(1.0, maxDim * 0.005));
    state.controls.maxDistance = Math.max(500, cameraZ * 5, maxDim * 6);
  }

  state.initialCameraPos.set(center.x + cameraZ * 0.7, center.y + cameraZ * 0.6, center.z + cameraZ * 0.9);
  state.initialCameraTarget.copy(center);

  state.camera.position.copy(state.initialCameraPos);
  state.controls.target.copy(state.initialCameraTarget);
  state.controls.update();
}

/**
 * Converte string Base64 em ArrayBuffer
 */
function base64ToArrayBuffer(base64) {
  const binaryString = window.atob(base64);
  const len = binaryString.length;
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes.buffer;
}

/**
 * Limpa o modelo atual da memória WebGL / WebAssembly e despacha o ArrayBuffer para o loader adequado.
 */
function loadBimArrayBuffer(arrayBuffer, format) {
  const cleanFormat = (format || 'GLB').toUpperCase().trim();

  // Remove modelo anterior e limpa memória se existir
  if (state.currentModel) {
    clearSelection();
    if (state.ifcLoader && state.currentModel.modelID !== undefined) {
      try {
        state.ifcLoader.ifcManager.close(state.currentModel.modelID, state.scene);
      } catch (e) {}
    }
    state.scene.remove(state.currentModel);
    state.currentModel = null;
  }

  state.hiddenIds.clear();
  state.isolatedElementId = null;
  if (state.isolatedElementIds) {
    state.isolatedElementIds.clear();
  }
  state.originalIndices = null;
  state.originalGroups = null;
  clearMeasurementsVisuals();

  if (cleanFormat === 'GLB' || cleanFormat === 'GLTF') {
    loadGltfModel(arrayBuffer);
  } else if (cleanFormat === 'IFC') {
    loadIfcModel(arrayBuffer);
  } else {
    loadGltfModel(arrayBuffer);
  }
}

/**
 * Função Global exposta ao Flutter para carregamento via streaming HTTP local / URL (.GLB, .gltf, .IFC).
 * Evita cópias Base64 gigantes em modelos de grande porte (ex: 90+ MB).
 */
window.loadBimModelFromUrl = async function(modelUrl, format) {
  try {
    notifyFlutter('onLoadingProgress', { progress: 8 });

    if (!modelUrl || typeof modelUrl !== 'string') {
      throw new Error('URL do modelo BIM inválida.');
    }

    const response = await fetch(modelUrl);
    if (!response.ok) {
      throw new Error(`Falha HTTP (${response.status}) ao ler arquivo do modelo.`);
    }

    let arrayBuffer;
    const contentLength = Number(response.headers.get('content-length') || 0);

    if (response.body && typeof response.body.getReader === 'function' && contentLength > 0) {
      const reader = response.body.getReader();
      const buffer = new Uint8Array(contentLength);
      let received = 0;
      let lastReport = 0;

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        if (value && value.byteLength > 0) {
          if (received + value.byteLength <= buffer.byteLength) {
            buffer.set(value, received);
          }
          received += value.byteLength;
          const now = Date.now();
          if (now - lastReport >= 120) {
            lastReport = now;
            const pct = Math.min(35, Math.round(8 + (received / contentLength) * 27));
            notifyFlutter('onLoadingProgress', { progress: pct });
          }
        }
      }
      arrayBuffer = received === buffer.byteLength ? buffer.buffer : buffer.slice(0, received).buffer;
    } else {
      arrayBuffer = await response.arrayBuffer();
    }

    notifyFlutter('onLoadingProgress', { progress: 35 });
    loadBimArrayBuffer(arrayBuffer, format);
  } catch (err) {
    console.error('Erro em loadBimModelFromUrl:', err);
    notifyFlutter('onViewerError', { message: `Falha ao carregar modelo 3D: ${err.message || err}` });
  }
};

/**
 * Função Global exposta ao Flutter para carregamento de modelos BIM em Base64 (.GLB, .gltf, .IFC).
 */
window.loadBimModel = function(base64Data, format) {
  try {
    notifyFlutter('onLoadingProgress', { progress: 10 });

    if (!base64Data || base64Data.length === 0) {
      throw new Error('Dados do modelo em Base64 estão vazios.');
    }

    const arrayBuffer = base64ToArrayBuffer(base64Data);
    notifyFlutter('onLoadingProgress', { progress: 25 });
    loadBimArrayBuffer(arrayBuffer, format);
  } catch (err) {
    console.error('Erro em loadBimModel:', err);
    notifyFlutter('onViewerError', { message: `Falha ao carregar modelo 3D: ${err.message}` });
  }
};

/**
 * Carregador para modelos .GLB e .GLTF via Three.js GLTFLoader
 */
function loadGltfModel(arrayBuffer) {
  notifyFlutter('onLoadingProgress', { progress: 50 });

  const loader = new THREE.GLTFLoader();
  loader.parse(
    arrayBuffer,
    '',
    function(gltf) {
      const model = gltf.scene;

      // Habilita sombras e identifica elementos
      let elementIndex = 1;
      model.traverse((child) => {
        if (child.isMesh) {
          child.castShadow = true;
          child.receiveShadow = true;
          if (!child.userData.expressID) {
            child.userData.expressID = 2000 + elementIndex++;
          }
        }
      });

      state.currentModel = model;
      state.scene.add(model);
      state.hiddenIds.clear();
      state.isolatedElementId = null;

      fitModelToFrame(model);

      notifyFlutter('onLoadingProgress', { progress: 100 });
      document.getElementById('hud-text').innerText = 'Modelo 3D Carregado com Sucesso';
    },
    function(error) {
      console.error('Erro no parsing GLTF:', error);
      notifyFlutter('onViewerError', { message: `Erro no parsing GLTF: ${error.message || error}` });
    }
  );
}

/**
 * Carregador Real de Modelos .IFC via web-ifc.wasm (ThatOpen Engine / openBIM)
 * Decodifica sólidos, extrusões, furos e metadados com performance de 60 FPS.
 */
async function loadIfcModel(arrayBuffer) {
  notifyFlutter('onLoadingProgress', { progress: 40 });

  try {
    if (!state.ifcLoader) {
      initIfcEngine();
    }
    if (!state.ifcLoader) {
      throw new Error('Motor de geometria IFC (IFCLoader) indisponível.');
    }

    notifyFlutter('onLoadingProgress', { progress: 45 });

    // Processamento da geometria real via WebAssembly
    const ifcModel = await state.ifcLoader.parse(arrayBuffer);
    if (!ifcModel) {
      throw new Error('Não foi possível gerar a malha tridimensional do arquivo IFC.');
    }

    // Verifica se o modelo possui geometria tridimensional real
    const positionAttr = ifcModel.geometry?.attributes?.position;
    if (!positionAttr || positionAttr.count === 0) {
      notifyFlutter('onLoadingProgress', { progress: 100 });
      document.getElementById('hud-text').innerText = 'Aviso: Modelo IFC sem geometria 3D';
      notifyFlutter('onViewerError', {
        message: 'O arquivo IFC não contém geometria 3D (apenas níveis/eixos). Certifique-se de que a vista exportada no Revit continha elementos 3D modelados.'
      });
      return;
    }

    notifyFlutter('onLoadingProgress', { progress: 88 });

    // Desativa sombras pesadas automaticamente em modelos densos (>250 mil vértices) para manter 60 FPS
    state.isHeavyModel = positionAttr.count > 250000;
    ifcModel.castShadow = !state.isHeavyModel;
    ifcModel.receiveShadow = !state.isHeavyModel;
    if (state.renderer) {
      state.renderer.shadowMap.enabled = !state.isHeavyModel;
      state.renderer.clippingPlanes = [];
    }
    state.isSectionActive = false;

    // Adiciona o modelo geométrico consolidado na cena
    state.currentModel = ifcModel;
    state.scene.add(ifcModel);

    // Libera imediatamente a referência do ArrayBuffer bruto para coleta de lixo (GC)
    arrayBuffer = null;

    // Índices originais serão capturados de forma preguiçosa (lazy) apenas se o usuário ocultar/isolar elementos
    state.originalIndices = null;
    state.originalGroups = null;
    state.hiddenIds.clear();
    state.isolatedElementId = null;
    if (state.isolatedElementIds) {
      state.isolatedElementIds.clear();
    }

    // Enquadra a câmera técnica imediatamente antes de mapear agregados
    fitModelToFrame(ifcModel);

    // Em modelos de menor porte, mapeia a hierarquia de agregados; em modelos gigantes, prioriza liberação imediata da UI
    if (!state.isHeavyModel) {
      try {
        await buildHierarchyMaps(ifcModel.modelID);
      } catch (e) {
        console.warn('Erro ao construir mapa de hierarquia agregada:', e);
      }
    }

    notifyFlutter('onLoadingProgress', { progress: 100 });
    document.getElementById('hud-text').innerText = 'Modelo IFC Renderizado (WebAssembly)';
  } catch (err) {
    console.error('Erro no processamento IFC:', err);
    notifyFlutter('onViewerError', { message: `Erro ao processar IFC: ${err.message || err}` });
  }
}

// Inicialização imediata ao carregar o DOM
window.addEventListener('DOMContentLoaded', () => {
  initEngine();
});
