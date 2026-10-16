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

  // 3. Renderizador WebGL de Alta Performance
  state.renderer = new THREE.WebGLRenderer({
    antialias: true,
    alpha: false,
    powerPreference: 'high-performance',
    precision: 'highp'
  });
  state.renderer.setSize(window.innerWidth, window.innerHeight);
  state.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  state.renderer.shadowMap.enabled = true;
  state.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  state.renderer.toneMapping = THREE.ACESFilmicToneMapping;
  state.renderer.toneMappingExposure = 1.15;
  container.appendChild(state.renderer.domElement);

  // 4. Controles de Câmera (OrbitControls)
  state.controls = new THREE.OrbitControls(state.camera, state.renderer.domElement);
  state.controls.enableDamping = true;
  state.controls.dampingFactor = 0.08;
  state.controls.screenSpacePanning = true;
  state.controls.minDistance = 0.5;
  state.controls.maxDistance = 500;
  state.controls.target.copy(state.initialCameraTarget);

  // 5. Iluminação Técnica para Arquitetura e Engenharia
  const ambientLight = new THREE.AmbientLight(0xffffff, 0.75);
  state.scene.add(ambientLight);

  const mainDirLight = new THREE.DirectionalLight(0xffffff, 0.85);
  mainDirLight.position.set(20, 40, 25);
  mainDirLight.castShadow = true;
  mainDirLight.shadow.mapSize.width = 2048;
  mainDirLight.shadow.mapSize.height = 2048;
  mainDirLight.shadow.bias = -0.0001;
  state.scene.add(mainDirLight);

  const fillLight = new THREE.DirectionalLight(0x94A3B8, 0.45);
  fillLight.position.set(-20, 20, -20);
  state.scene.add(fillLight);

  // 6. Grid Técnico de Canteiro de Obras
  const gridHelper = new THREE.GridHelper(40, 40, 0x2563EB, 0x1E293B);
  gridHelper.position.y = -0.01;
  state.scene.add(gridHelper);

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

  // 9. Inicialização da Engine de IFC (IFCLoader + web-ifc.wasm)
  initIfcEngine();

  // 10. Event Listeners para redimensionamento e seleção
  window.addEventListener('resize', onWindowResize);
  state.renderer.domElement.addEventListener('pointerdown', onPointerDown);
  state.renderer.domElement.addEventListener('pointerup', onPointerUp);

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
      console.log('Engine IFC (web-ifc.wasm) configurada com sucesso.');
    } else {
      console.warn('IFCLoader não encontrado no escopo global.');
    }
  } catch (err) {
    console.error('Falha ao instanciar IFCLoader:', err);
  }
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
  state.pointerDownPos = { x: event.clientX, y: event.clientY };
}

/**
 * Processamento de seleção por Raycaster (apenas se for clique simples, não arrasto)
 */
async function onPointerUp(event) {
  const deltaX = Math.abs(event.clientX - state.pointerDownPos.x);
  const deltaY = Math.abs(event.clientY - state.pointerDownPos.y);

  // Ignora se o usuário estava rotacionando ou movendo a câmera
  if (deltaX > 6 || deltaY > 6) return;

  const rect = state.renderer.domElement.getBoundingClientRect();
  state.mouse.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
  state.mouse.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;

  state.raycaster.setFromCamera(state.mouse, state.camera);

  // Intersecta apenas o modelo ativo
  const objectsToTest = state.currentModel ? [state.currentModel] : [];
  const intersects = state.raycaster.intersectObjects(objectsToTest, true);

  if (intersects.length > 0) {
    const hit = intersects[0];
    await selectElement(hit);
  } else {
    // Clique no fundo limpa a seleção
    clearSelection();
  }
}

/**
 * Aplica destaque visual e extrai metadados do elemento selecionado (IFC ou GLTF)
 */
async function selectElement(hit) {
  clearSelection();

  const object = hit.object;
  if (!object) return;

  // 1. Caso o modelo seja IFC nativo (possua modelID e expressID)
  if (state.ifcLoader && object.modelID !== undefined && hit.faceIndex !== undefined) {
    try {
      const expressID = state.ifcLoader.ifcManager.getExpressId(object.geometry, hit.faceIndex);
      if (expressID !== undefined && expressID !== null && expressID >= 0) {
        // Aplica destaque no elemento IFC
        state.ifcLoader.ifcManager.createSubset({
          modelID: object.modelID,
          ids: [expressID],
          scene: state.scene,
          removePrevious: true,
          material: state.highlightMaterial
        });

        state.selectedObject = { modelID: object.modelID, expressID: expressID, isIfc: true };

        // Extrai propriedades reais do elemento no IFC
        let name = `Elemento BIM #${expressID}`;
        let category = 'IfcBuildingElement';
        const psetsFormatted = {};

        try {
          const itemProps = await state.ifcLoader.ifcManager.getItemProperties(object.modelID, expressID);
          if (itemProps) {
            name = itemProps.Name?.value || itemProps.ObjectType?.value || name;
            category = itemProps.__proto__?.constructor?.name || deduceBimCategory(object) || 'IfcBuildingElement';

            psetsFormatted["Propriedades Gerais"] = {
              "ExpressID": expressID,
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
          const psets = await state.ifcLoader.ifcManager.getPropertySets(object.modelID, expressID, true);
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

        // Se o elemento não possuir Psets no IFC, cria estimativas úteis
        if (Object.keys(psetsFormatted).length <= 1) {
          psetsFormatted["Dados Técnicos"] = {
            "Modelo": "Projeto openBIM IFC",
            "Geometria": "Sólido WebAssembly",
            "Status": "Construído (As-Built)"
          };
        }

        notifyFlutter('onElementSelected', {
          expressID: expressID,
          name: name,
          category: category,
          psets: psetsFormatted
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
 * Remove o destaque e notifica deseleção
 */
function clearSelection() {
  if (state.selectedObject) {
    if (state.selectedObject.isIfc && state.ifcLoader) {
      try {
        state.ifcLoader.ifcManager.removeSubset(state.selectedObject.modelID, state.scene, state.highlightMaterial);
      } catch (e) {}
    } else if (state.selectedObject.material && state.originalMaterial) {
      state.selectedObject.material = state.originalMaterial;
    }
  }
  state.selectedObject = null;
  state.originalMaterial = null;
}

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
 * Reseta a câmera para a posição padrão
 */
window.resetCamera = function() {
  if (!state.camera || !state.controls) return;
  state.controls.reset();
  state.camera.position.copy(state.initialCameraPos);
  state.controls.target.copy(state.initialCameraTarget);
  state.controls.update();
};

/**
 * Ajusta o enquadramento da câmera com base no BoundingBox do modelo
 */
function fitModelToFrame(modelGroup) {
  const box = new THREE.Box3().setFromObject(modelGroup);
  if (box.isEmpty()) return;

  const center = box.getCenter(new THREE.Vector3());
  const size = box.getSize(new THREE.Vector3());
  const maxDim = Math.max(size.x, size.y, size.z);

  const fov = state.camera.fov * (Math.PI / 180);
  let cameraZ = Math.abs(maxDim / 2 / Math.tan(fov / 2)) * 1.6;
  cameraZ = Math.max(cameraZ, 5);

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
 * Função Global exposta ao Flutter para carregamento de modelos BIM (.GLB, .gltf, .IFC).
 */
window.loadBimModel = function(base64Data, format) {
  try {
    notifyFlutter('onLoadingProgress', { progress: 10 });

    if (!base64Data || base64Data.length === 0) {
      throw new Error('Dados do modelo em Base64 estão vazios.');
    }

    const cleanFormat = (format || 'GLB').toUpperCase().trim();
    const arrayBuffer = base64ToArrayBuffer(base64Data);

    notifyFlutter('onLoadingProgress', { progress: 25 });

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

    if (cleanFormat === 'GLB' || cleanFormat === 'GLTF') {
      loadGltfModel(arrayBuffer);
    } else if (cleanFormat === 'IFC') {
      loadIfcModel(arrayBuffer);
    } else {
      // Fallback para GLTF
      loadGltfModel(arrayBuffer);
    }
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
  notifyFlutter('onLoadingProgress', { progress: 35 });

  try {
    if (!state.ifcLoader) {
      initIfcEngine();
    }
    if (!state.ifcLoader) {
      throw new Error('Motor de geometria IFC (IFCLoader) indisponível.');
    }

    notifyFlutter('onLoadingProgress', { progress: 55 });

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

    notifyFlutter('onLoadingProgress', { progress: 85 });

    // Habilita projeção e recepção de sombras
    ifcModel.castShadow = true;
    ifcModel.receiveShadow = true;

    // Adiciona o modelo geométrico consolidado na cena
    state.currentModel = ifcModel;
    state.scene.add(ifcModel);

    // Enquadra a câmera técnica perfeitamente na casinha/edificação
    fitModelToFrame(ifcModel);

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
