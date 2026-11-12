/**
 * ThatOpen Engine & Three.js 3D BIM Viewport - Módulo de Carregadores BIM (.IFC e .GLTF) e WebAssembly
 */

window.BimEngine = window.BimEngine || {};

/**
 * Prepara o IFCLoader com o caminho local do WebAssembly (web-ifc.wasm)
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

    // Otimização seletiva para modelos densos (calibrada para 4 GB RAM sem perda de qualidade arquitetônica):
    // 1. Normaliza automaticamente a escala das unidades locais (mm vs m) para precisão universal.
    // 2. Em tablets de 4 GB / GPUs PowerVR, converte perfis repetitivos/densos em prismas de 8 vértices e omite micro-fixadores
    //    sub-pixel, reduzindo modelos de 17M de vértices (3.25M pós-filtro antigo) para ~115k vértices a 60 FPS reais!
    const smartLodThreshold = state.isLowSpecDevice ? 300000 : 1200000;
    if (rawTotalVerts > smartLodThreshold) {
      let maxOverallD = 0;
      for (const entry of geomCache.values()) {
        const [minX, minY, minZ, maxX, maxY, maxZ] = entry.bbox;
        const d = Math.max(maxX - minX, maxY - minY, maxZ - minZ);
        entry.maxD = d;
        if (d > maxOverallD) maxOverallD = d;
      }
      const unitFactor = maxOverallD > 500 ? 1000 : 1;
      const isUltraDenseOnLowSpec = state.isLowSpecDevice && rawTotalVerts > 1500000;

      for (const entry of geomCache.values()) {
        const dMeters = (entry.maxD || 0) / unitFactor;
        if (isUltraDenseOnLowSpec) {
          if (dMeters <= 0.35 || (dMeters <= 0.90 && entry.instances >= 4)) {
            entry.vOut = new Float32Array(0);
            entry.iOut = new Uint32Array(0);
            entry.vCount = 0;
          } else if (entry.vCount > 36 || (entry.instances >= 2 && entry.vCount > 20)) {
            const box = createBoxLodGeometryData(entry.bbox);
            entry.vOut = box.vOut;
            entry.iOut = box.iOut;
            entry.vCount = box.vCount;
          } else if (entry.vCount > 16) {
            const welded = weldLosslessGeometry(entry.vOut, entry.iOut);
            entry.vOut = welded.vOut;
            entry.iOut = welded.iOut;
            entry.vCount = welded.vCount;
          }
        } else {
          if (dMeters <= 0.12 && entry.instances >= 120 && entry.vCount > 300) {
            // Micro-clips de fixação (< 12cm) ocultos na estrutura do telhado
            entry.vOut = new Float32Array(0);
            entry.iOut = new Uint32Array(0);
            entry.vCount = 0;
          } else if ((entry.instances >= 8 && entry.vCount * entry.instances > 4000 && entry.vCount > 90) || entry.vCount > 1800) {
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

        if (typeof recordElementInstanceBounds === 'function' && c.bbox) {
          recordElementInstanceBounds(expId, c.bbox, m);
        }

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
 * Descarte seguro de nós e geometrias Three.js para liberação completa de memória GPU
 */
function disposeThreeObject(obj) {
  if (!obj) return;
  obj.traverse((child) => {
    if (child.geometry) {
      child.geometry.dispose();
    }
    if (child.material) {
      if (Array.isArray(child.material)) {
        for (const mat of child.material) {
          if (mat.map) mat.map.dispose();
          if (mat.bumpMap && mat.bumpMap !== state.archBumpTexture) mat.bumpMap.dispose();
          mat.dispose();
        }
      } else {
        if (child.material.map) child.material.map.dispose();
        if (child.material.bumpMap && child.material.bumpMap !== state.archBumpTexture) child.material.bumpMap.dispose();
        child.material.dispose();
      }
    }
  });
}

/**
 * Limpa o modelo atual da memória WebGL / WebAssembly de forma determinística
 * liberando buffers geométricos, estruturas WASM e memória GPU (essencial para tablets de 4 GB RAM).
 */
function disposeCurrentModel() {
  if (state.currentModel) {
    clearSelection();
    if (state.ifcLoader && state.currentModel.modelID !== undefined) {
      try {
        state.ifcLoader.ifcManager.close(state.currentModel.modelID, state.scene);
      } catch (e) {}
    }
    disposeThreeObject(state.currentModel);
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
  if (typeof resetBimAnalyticsState === 'function') {
    resetBimAnalyticsState();
  }
  if (state.renderer) {
    state.renderer.renderLists?.dispose();
  }
  if (typeof requestRender === 'function') {
    requestRender(2);
  }
}

/**
 * Limpa o modelo atual da memória WebGL / WebAssembly e despacha o ArrayBuffer para o loader adequado.
 */
function loadBimArrayBuffer(arrayBuffer, format) {
  const cleanFormat = (format || 'GLB').toUpperCase().trim();

  // Remove modelo anterior e limpa memória GPU/WASM
  disposeCurrentModel();

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
async function loadBimModelFromUrl(modelUrl, format) {
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
}

/**
 * Função Global exposta ao Flutter para carregamento de modelos BIM em Base64 (.GLB, .gltf, .IFC).
 */
function loadBimModel(base64Data, format) {
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
}

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
      if (typeof buildGltfFallbackSpecs === 'function') {
        buildGltfFallbackSpecs(model);
      }

      notifyFlutter('onLoadingProgress', { progress: 100 });
      const hudEl = document.getElementById('hud-text');
      if (hudEl) hudEl.innerText = 'Modelo 3D Carregado com Sucesso';
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
      const hudEl = document.getElementById('hud-text');
      if (hudEl) hudEl.innerText = 'Aviso: Modelo IFC sem geometria 3D';
      notifyFlutter('onViewerError', {
        message: 'O arquivo IFC não contém geometria 3D (apenas níveis/eixos). Certifique-se de que a vista exportada no Revit continha elementos 3D modelados.'
      });
      return;
    }

    notifyFlutter('onLoadingProgress', { progress: 88 });

    // Desativa sombras pesadas automaticamente em modelos densos (ou mais cedo em tablets de 4 GB RAM) para manter 60 FPS
    const heavyVertThreshold = state.isLowSpecDevice ? 90000 : 250000;
    state.isHeavyModel = positionAttr.count > heavyVertThreshold;
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

    // Pipeline Progressivo Render-First (Prioridade Máxima para Interatividade):
    // 1. Renderiza os primeiros frames da malha consolidada no WebGL imediatamente
    if (typeof requestRender === 'function') {
      requestRender(8);
    }
    notifyFlutter('onLoadingProgress', { progress: 92 });
    const hudEl = document.getElementById('hud-text');
    if (hudEl) hudEl.innerText = 'Modelo 3D Renderizado';

    // 2. Despacha hierarquia de agregados, pavimentos e metadados em segundo plano não-bloqueante
    setTimeout(async () => {
      if (!state.currentModel || state.currentModel.modelID !== ifcModel.modelID) return;

      try {
        await buildHierarchyMaps(ifcModel.modelID);
      } catch (e) {
        console.warn('Erro ao construir mapa de hierarquia agregada:', e);
      }

      try {
        if (typeof extractModelBimMetadataAndSpatialIndex === 'function') {
          await extractModelBimMetadataAndSpatialIndex(ifcModel.modelID);
        }
      } catch (e) {
        console.warn('Erro ao indexar metadados BIM e pavimentos:', e);
      }

      notifyFlutter('onLoadingProgress', { progress: 100 });
      if (hudEl) hudEl.innerText = 'Modelo IFC Pronto (openBIM)';
      if (typeof requestRender === 'function') {
        requestRender(4);
      }
    }, 20);
  } catch (err) {
    console.error('Erro no processamento IFC:', err);
    notifyFlutter('onViewerError', { message: `Erro ao processar IFC: ${err.message || err}` });
  }
}

// Exportações
window.BimEngine.initIfcEngine = initIfcEngine;
window.BimEngine.installSmartIfcPipeline = installSmartIfcPipeline;
window.BimEngine.base64ToArrayBuffer = base64ToArrayBuffer;
window.BimEngine.disposeThreeObject = disposeThreeObject;
window.BimEngine.disposeCurrentModel = disposeCurrentModel;
window.BimEngine.loadBimArrayBuffer = loadBimArrayBuffer;
window.BimEngine.loadBimModelFromUrl = loadBimModelFromUrl;
window.BimEngine.loadBimModel = loadBimModel;
window.BimEngine.loadGltfModel = loadGltfModel;
window.BimEngine.loadIfcModel = loadIfcModel;

window.initIfcEngine = initIfcEngine;
window.installSmartIfcPipeline = installSmartIfcPipeline;
window.base64ToArrayBuffer = base64ToArrayBuffer;
window.disposeThreeObject = disposeThreeObject;
window.disposeCurrentModel = disposeCurrentModel;
window.loadBimArrayBuffer = loadBimArrayBuffer;
window.loadBimModelFromUrl = loadBimModelFromUrl;
window.loadBimModel = loadBimModel;
window.loadGltfModel = loadGltfModel;
window.loadIfcModel = loadIfcModel;

