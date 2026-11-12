/**
 * ThatOpen Engine & Three.js 3D BIM Viewport - Módulo de Análise Espacial, Pavimentos (Storeys),
 * Quantitativos por Nível, Especificações openBIM e Câmera da Visualização Dinâmica.
 */

window.BimEngine = window.BimEngine || {};

/**
 * Decodifica sequências STEP ISO-10303-21 (\X\XX e \X2\XXXX\X0\) para UTF-8 legível.
 */
function decodeIfcStepText(raw) {
  if (raw === null || raw === undefined) return '';
  let str = String(raw);
  if (!str.includes('\\X')) return str;

  // 1. Sequências UTF-16 (\X2\00ED00E3...\X0\)
  str = str.replace(/\\X2\\([0-9A-Fa-f]+)\\X0\\/g, (_, hexSeq) => {
    let out = '';
    for (let i = 0; i + 3 < hexSeq.length; i += 4) {
      const code = parseInt(hexSeq.substring(i, i + 4), 16);
      if (!isNaN(code)) out += String.fromCharCode(code);
    }
    return out;
  });

  // 2. Sequências ISO-8859-1 de 1 byte (\X\E7 -> ç, \X\ED -> í)
  str = str.replace(/\\X\\([0-9A-Fa-f]{2})/g, (_, hexByte) => {
    const code = parseInt(hexByte, 16);
    return !isNaN(code) ? String.fromCharCode(code) : _;
  });

  return str;
}

let _dynamicResizeTimer = null;

/**
 * Aguarda o próximo ciclo de renderização WebGL (requestAnimationFrame + flush do frame)
 * garantindo que geometria, materiais e câmera terminaram de ser desenhados antes de aceitar nova ação.
 */
function waitForNextRenderedFrame() {
  return new Promise((resolve) => {
    if (typeof requestAnimationFrame === 'function') {
      requestAnimationFrame(() => {
        try {
          if (state.controls) state.controls.update();
          if (state.renderer && state.scene && state.camera) {
            state.renderer.render(state.scene, state.camera);
          }
        } catch (e) {}
        requestAnimationFrame(() => resolve());
      });
    } else {
      setTimeout(resolve, 16);
    }
  });
}

/**
 * Limpa todo o índice espacial, caches O(1) e analítico ao carregar novo modelo.
 */
function resetBimAnalyticsState() {
  if (_dynamicResizeTimer) {
    clearTimeout(_dynamicResizeTimer);
    _dynamicResizeTimer = null;
  }
  state.elementBounds.clear();
  state.storeys = [];
  state.elementToStorey.clear();
  state.storeyToElements.clear();
  state.elementToType.clear();
  state.typeToElements.clear();
  state.elementMetaIndex.clear();
  state.elementCategoryMap.clear();
  state.elementToPsetIds.clear();
  state.elementToMaterialIds.clear();
  state.relationIndexesReady = false;
  state.relationIndexPromise = null;
  state.psetPropsCache.clear();
  state.materialPropsCache.clear();
  state.typePropsCache.clear();
  state.pieceAnalyticsCache.clear();
  state.enrichedPayloadCache.clear();
  state.bimProjectSpecs = null;
  state.lengthUnitScale = 0.001;
  state.isDynamicViewActive = false;
  state.isTransitioningElement = false;
  state.isDynamicXrayActive = false;
  state.dynamicXrayKeepIds.clear();
  state.similarHighlightedIds = [];
  state.similarSubsetSignature = '';
  state.preDynamicViewSnapshot = null;
  clearSimilarHighlights();
  if (typeof clearProximityDimensionLine === 'function') {
    clearProximityDimensionLine();
  }
  if (typeof restoreOccludedGhostMaterials === 'function') {
    restoreOccludedGhostMaterials();
  }
  state.dynamicProximityGroup = null;
  state.showDynamicProximity = true;
  state.lastProximityData = null;
  state.occludedGhostIds.clear();
  state.occludedSavedMaterials.clear();
}

/**
 * Constrói uma única vez (em fatias não-bloqueantes) o índice reverso O(1) de PropertySets
 * (IFCRELDEFINESBYPROPERTIES) e Materiais (IFCRELASSOCIATESMATERIAL) por ExpressID.
 * Elimina a varredura linear de dezenas de milhares de linhas STEP a cada clique em peça!
 */
async function ensureRelationIndexes(modelID) {
  if (state.relationIndexesReady) return;
  if (state.relationIndexPromise) {
    await state.relationIndexPromise;
    return;
  }

  state.relationIndexPromise = (async () => {
    const mgr = state.ifcLoader?.ifcManager;
    const api = mgr?.state?.api;
    if (!api || typeof api.GetLineIDsWithType !== 'function' || typeof WebIFC === 'undefined') {
      state.relationIndexesReady = true;
      return;
    }

    const addMapping = (map, targetId, relValueId) => {
      let arr = map.get(targetId);
      if (!arr) {
        arr = [relValueId];
        map.set(targetId, arr);
      } else if (!arr.includes(relValueId)) {
        arr.push(relValueId);
      }
    };

    // 1. Índice reverso de IFCRELDEFINESBYPROPERTIES (elemento -> psetIds[])
    try {
      if (WebIFC.IFCRELDEFINESBYPROPERTIES !== undefined) {
        const linesMaybe = api.GetLineIDsWithType(modelID, WebIFC.IFCRELDEFINESBYPROPERTIES);
        const lines = (linesMaybe && typeof linesMaybe.then === 'function') ? await linesMaybe : linesMaybe;
        const count = lines && typeof lines.size === 'function' ? lines.size() : 0;

        for (let i = 0; i < count; i++) {
          if (i > 0 && i % 450 === 0) {
            await new Promise((r) => setTimeout(r, state.activePointers.size > 0 ? 40 : 0));
          }
          const relId = lines.get(i);
          const relMaybe = api.GetLine(modelID, relId, false);
          const rel = (relMaybe && typeof relMaybe.then === 'function') ? await relMaybe : relMaybe;
          if (!rel) continue;

          const psetId = Number(rel.RelatingPropertyDefinition?.value);
          if (isNaN(psetId)) continue;

          const related = rel.RelatedObjects;
          if (Array.isArray(related)) {
            for (let j = 0; j < related.length; j++) {
              const rawItem = related[j];
              const eid = Number(rawItem?.value !== undefined ? rawItem.value : rawItem);
              if (isNaN(eid)) continue;
              addMapping(state.elementToPsetIds, eid, psetId);
              const agg = state.childToParent.get(eid);
              if (agg && agg.parentId) {
                addMapping(state.elementToPsetIds, agg.parentId, psetId);
              }
            }
          } else if (related?.value !== undefined) {
            const eid = Number(related.value);
            if (!isNaN(eid)) addMapping(state.elementToPsetIds, eid, psetId);
          }
        }
      }
    } catch (err) {
      console.warn('Aviso ao indexar IFCRELDEFINESBYPROPERTIES:', err);
    }

    // 2. Índice reverso de IFCRELASSOCIATESMATERIAL (elemento/tipo -> matIds[])
    try {
      if (WebIFC.IFCRELASSOCIATESMATERIAL !== undefined) {
        const linesMaybe = api.GetLineIDsWithType(modelID, WebIFC.IFCRELASSOCIATESMATERIAL);
        const lines = (linesMaybe && typeof linesMaybe.then === 'function') ? await linesMaybe : linesMaybe;
        const count = lines && typeof lines.size === 'function' ? lines.size() : 0;

        for (let i = 0; i < count; i++) {
          if (i > 0 && i % 450 === 0) {
            await new Promise((r) => setTimeout(r, state.activePointers.size > 0 ? 40 : 0));
          }
          const relId = lines.get(i);
          const relMaybe = api.GetLine(modelID, relId, false);
          const rel = (relMaybe && typeof relMaybe.then === 'function') ? await relMaybe : relMaybe;
          if (!rel) continue;

          const matId = Number(rel.RelatingMaterial?.value);
          if (isNaN(matId)) continue;

          const related = rel.RelatedObjects;
          if (Array.isArray(related)) {
            for (let j = 0; j < related.length; j++) {
              const rawItem = related[j];
              const eid = Number(rawItem?.value !== undefined ? rawItem.value : rawItem);
              if (isNaN(eid)) continue;
              addMapping(state.elementToMaterialIds, eid, matId);
              const agg = state.childToParent.get(eid);
              if (agg && agg.parentId) {
                addMapping(state.elementToMaterialIds, agg.parentId, matId);
              }
            }
          } else if (related?.value !== undefined) {
            const eid = Number(related.value);
            if (!isNaN(eid)) addMapping(state.elementToMaterialIds, eid, matId);
          }
        }
      }
    } catch (err) {
      console.warn('Aviso ao indexar IFCRELASSOCIATESMATERIAL:', err);
    }

    state.relationIndexesReady = true;
  })();

  try {
    await state.relationIndexPromise;
  } finally {
    state.relationIndexPromise = null;
  }
}

/**
 * Busca em O(1) todos os PropertySets e ElementQuantities associados ao elemento (com cache LRU simples).
 */
async function getElementPropertySetsFast(modelID, targetID) {
  const mgr = state.ifcLoader?.ifcManager;
  if (!mgr) return [];

  await ensureRelationIndexes(modelID);

  // Se o ambiente não possuir API WASM direta (ex: mock de teste), faz fallback seguro
  if (!mgr.state?.api || typeof mgr.state.api.GetLineIDsWithType !== 'function') {
    try {
      return (await mgr.getPropertySets(modelID, targetID, true)) || [];
    } catch (e) {
      return [];
    }
  }

  const psetIds = state.elementToPsetIds.get(targetID);
  if (!psetIds || psetIds.length === 0) return [];

  const results = [];
  for (let i = 0; i < psetIds.length; i++) {
    const pid = psetIds[i];
    let psetObj = state.psetPropsCache.get(pid);
    if (!psetObj) {
      try {
        psetObj = await mgr.getItemProperties(modelID, pid, true);
        if (psetObj) {
          if (state.psetPropsCache.size > 1500) {
            const oldestKey = state.psetPropsCache.keys().next().value;
            state.psetPropsCache.delete(oldestKey);
          }
          state.psetPropsCache.set(pid, psetObj);
        }
      } catch (e) {}
    }
    if (psetObj) results.push(psetObj);
  }
  return results;
}

/**
 * Busca em O(1) os materiais e camadas construtivas associados ao elemento ou ao seu Tipo IFC.
 */
async function getElementMaterialsFast(modelID, targetID) {
  const mgr = state.ifcLoader?.ifcManager;
  if (!mgr) return [];

  await ensureRelationIndexes(modelID);

  if (!mgr.state?.api || typeof mgr.state.api.GetLineIDsWithType !== 'function') {
    try {
      return (await mgr.getMaterialsProperties(modelID, targetID, true)) || [];
    } catch (e) {
      return [];
    }
  }

  const directMatIds = state.elementToMaterialIds.get(targetID) || [];
  const typeInfo = state.elementToType.get(targetID);
  const typeMatIds = (typeInfo && typeInfo.typeId) ? (state.elementToMaterialIds.get(typeInfo.typeId) || []) : [];

  const combinedIds = directMatIds.length > 0 ? directMatIds.slice() : [];
  for (const tid of typeMatIds) {
    if (!combinedIds.includes(tid)) combinedIds.push(tid);
  }
  if (combinedIds.length === 0) return [];

  const results = [];
  for (let i = 0; i < combinedIds.length; i++) {
    const mid = combinedIds[i];
    let matObj = state.materialPropsCache.get(mid);
    if (!matObj) {
      try {
        matObj = await mgr.getItemProperties(modelID, mid, true);
        if (matObj) {
          state.materialPropsCache.set(mid, matObj);
        }
      } catch (e) {}
    }
    if (matObj) results.push(matObj);
  }
  return results;
}

/**
 * Registra o BoundingBox 3D (em metros, espaço de mundo Three.js) de uma instância de elemento
 * transformando apenas os 8 vértices da caixa local (custo O(1) durante o carregamento).
 */
function recordElementInstanceBounds(expressID, localBbox, flatMatrix) {
  if (expressID === undefined || expressID === null || !localBbox || !flatMatrix) return;
  const [minX, minY, minZ, maxX, maxY, maxZ] = localBbox;
  if (!isFinite(minX) || !isFinite(maxX)) return;

  const m00 = flatMatrix[0], m01 = flatMatrix[1], m02 = flatMatrix[2];
  const m10 = flatMatrix[4], m11 = flatMatrix[5], m12 = flatMatrix[6];
  const m20 = flatMatrix[8], m21 = flatMatrix[9], m22 = flatMatrix[10];
  const tx = flatMatrix[12], ty = flatMatrix[13], tz = flatMatrix[14];

  let wMinX = Infinity, wMinY = Infinity, wMinZ = Infinity;
  let wMaxX = -Infinity, wMaxY = -Infinity, wMaxZ = -Infinity;

  const xs = [minX, maxX];
  const ys = [minY, maxY];
  const zs = [minZ, maxZ];

  for (let ix = 0; ix < 2; ix++) {
    const x = xs[ix];
    for (let iy = 0; iy < 2; iy++) {
      const y = ys[iy];
      for (let iz = 0; iz < 2; iz++) {
        const z = zs[iz];
        const wx = m00 * x + m10 * y + m20 * z + tx;
        const wy = m01 * x + m11 * y + m21 * z + ty;
        const wz = m02 * x + m12 * y + m22 * z + tz;
        if (wx < wMinX) wMinX = wx;
        if (wx > wMaxX) wMaxX = wx;
        if (wy < wMinY) wMinY = wy;
        if (wy > wMaxY) wMaxY = wy;
        if (wz < wMinZ) wMinZ = wz;
        if (wz > wMaxZ) wMaxZ = wz;
      }
    }
  }

  const prev = state.elementBounds.get(expressID);
  if (!prev) {
    state.elementBounds.set(expressID, [wMinX, wMinY, wMinZ, wMaxX, wMaxY, wMaxZ]);
  } else {
    if (wMinX < prev[0]) prev[0] = wMinX;
    if (wMinY < prev[1]) prev[1] = wMinY;
    if (wMinZ < prev[2]) prev[2] = wMinZ;
    if (wMaxX > prev[3]) prev[3] = wMaxX;
    if (wMaxY > prev[4]) prev[4] = wMaxY;
    if (wMaxZ > prev[5]) prev[5] = wMaxZ;
  }
}

/**
 * Retorna o BoundingBox 3D consolidado (THREE.Box3) de um elemento (incluindo subIds agregados).
 */
function getElementWorldBox(expressID) {
  const id = Number(expressID);
  const box = new THREE.Box3();
  if (isNaN(id)) return box;

  const ids = [id];
  const agg = state.parentToChildren.get(id) || state.childToParent.get(id);
  if (agg && Array.isArray(agg.children)) {
    for (const cid of agg.children) {
      if (!ids.includes(cid)) ids.push(cid);
    }
  }

  for (const eid of ids) {
    const b = state.elementBounds.get(eid);
    if (b) {
      box.expandByPoint(new THREE.Vector3(b[0], b[1], b[2]));
      box.expandByPoint(new THREE.Vector3(b[3], b[4], b[5]));
    }
  }

  // Fallback para modelos GLTF ou malhas individuais
  if (box.isEmpty() && state.currentModel && state.currentModel.modelID === undefined) {
    state.currentModel.traverse((child) => {
      if (child.isMesh && (child.userData.expressID === id || child.id === id)) {
        const meshBox = new THREE.Box3().setFromObject(child);
        if (!meshBox.isEmpty()) box.union(meshBox);
      }
    });
  }

  return box;
}

/**
 * Normaliza a assinatura Família:Tipo de nomes exportados pelo Revit / Archicad (remove :TagID numérico final).
 */
function normalizeFamilyTypeSignature(rawName, category) {
  const decoded = decodeIfcStepText(rawName || '').trim();
  const catUpper = String(category || 'IFCELEMENT').toUpperCase();
  if (!decoded) return `${catUpper}::PADRAO`;

  let cleaned = decoded.replace(/\s*\[\d+\]$/, '');
  const parts = cleaned.split(':').map((s) => s.trim()).filter(Boolean);
  if (parts.length >= 3 && /^\d+$/.test(parts[parts.length - 1])) {
    parts.pop();
    cleaned = parts.join(':');
  } else if (parts.length === 2 && /^\d+$/.test(parts[1])) {
    cleaned = parts[0];
  }
  return `${catUpper}::${cleaned.toLowerCase()}`;
}

/**
 * Extrai metadados globais openBIM do arquivo IFC (Header, Projeto, Unidades, Autor, Pavimentos e Tipos).
 */
async function extractModelBimMetadataAndSpatialIndex(modelID) {
  if (!state.ifcLoader || !state.ifcLoader.ifcManager || typeof WebIFC === 'undefined') return;
  const mgr = state.ifcLoader.ifcManager;
  const api = mgr.state?.api;

  let schema = 'IFC2X3';
  let viewDefinition = 'CoordinationView';
  let coordinateSystem = 'Coordenadas Locais BIM';
  let exchangeRequirement = '';
  let exportDate = '';
  let authoringApp = '';
  let author = '';
  let organization = '';
  let projectName = '';
  let projectNumber = '';
  let projectPhase = '';
  let siteName = '';
  let buildingName = '';
  let addressText = '';
  let lengthUnitLabel = 'Milímetros (mm)';
  let areaUnitLabel = 'Metros quadrados (m²)';
  let volumeUnitLabel = 'Metros cúbicos (m³)';
  let lengthScale = 0.001;

  // 1. Leitura defensiva do Cabeçalho STEP (FILE_SCHEMA, FILE_NAME, FILE_DESCRIPTION)
  if (api && typeof api.GetHeaderLine === 'function') {
    try {
      if (WebIFC.FILE_SCHEMA !== undefined) {
        const schemaHeader = api.GetHeaderLine(modelID, WebIFC.FILE_SCHEMA);
        const rawSchema = schemaHeader?.arguments?.[0]?.[0]?.value || schemaHeader?.arguments?.[0]?.value;
        if (rawSchema) schema = decodeIfcStepText(rawSchema);
      }
    } catch (e) {}

    try {
      if (WebIFC.FILE_NAME !== undefined) {
        const nameHeader = api.GetHeaderLine(modelID, WebIFC.FILE_NAME);
        const args = nameHeader?.arguments || [];
        if (args[1]?.value) {
          exportDate = decodeIfcStepText(args[1].value);
        }
        if (args[5]?.value) {
          authoringApp = decodeIfcStepText(args[5].value);
        }
      }
    } catch (e) {}

    try {
      if (WebIFC.FILE_DESCRIPTION !== undefined) {
        const descHeader = api.GetHeaderLine(modelID, WebIFC.FILE_DESCRIPTION);
        const descList = descHeader?.arguments?.[0] || [];
        if (Array.isArray(descList)) {
          for (const item of descList) {
            const txt = decodeIfcStepText(item?.value || item || '');
            if (txt.includes('ViewDefinition')) {
              const m = txt.match(/\[([^\]]+)\]/);
              if (m) viewDefinition = m[1];
            } else if (txt.includes('CoordinateReference')) {
              const m = txt.match(/CoordinateBase:\s*([^,\]]+)/i);
              if (m) coordinateSystem = m[1].trim();
            } else if (txt.includes('ExchangeRequirement')) {
              const m = txt.match(/\[([^\]]+)\]/);
              if (m) exchangeRequirement = m[1].trim();
            }
          }
        }
      }
    } catch (e) {}
  }

  // 2. Unidades do Modelo (IFCSIUNIT)
  try {
    if (WebIFC.IFCSIUNIT !== undefined) {
      const units = await mgr.getAllItemsOfType(modelID, WebIFC.IFCSIUNIT, true);
      if (Array.isArray(units)) {
        for (const u of units) {
          const uType = String(u.UnitType?.value || '').toUpperCase();
          const prefix = String(u.Prefix?.value || '').toUpperCase();
          const name = String(u.Name?.value || '').toUpperCase();
          if (uType === 'LENGTHUNIT') {
            if (prefix === 'MILLI') {
              lengthScale = 0.001;
              lengthUnitLabel = 'Milímetros (mm)';
            } else if (prefix === 'CENTI') {
              lengthScale = 0.01;
              lengthUnitLabel = 'Centímetros (cm)';
            } else if (name.includes('METRE') || name.includes('METER')) {
              lengthScale = 1.0;
              lengthUnitLabel = 'Metros (m)';
            }
          } else if (uType === 'AREAUNIT') {
            areaUnitLabel = 'Metros quadrados (m²)';
          } else if (uType === 'VOLUMEUNIT') {
            volumeUnitLabel = 'Metros cúbicos (m³)';
          }
        }
      }
    }
  } catch (e) {}
  state.lengthUnitScale = lengthScale;

  // 3. Entidades Globais (IFCPROJECT, IFCAPPLICATION, IFCPERSON, IFCORGANIZATION, IFCSITE, IFCBUILDING, IFCPOSTALADDRESS)
  try {
    if (WebIFC.IFCPROJECT !== undefined) {
      const projects = await mgr.getAllItemsOfType(modelID, WebIFC.IFCPROJECT, true);
      if (Array.isArray(projects) && projects.length > 0) {
        const p = projects[0];
        const pNum = decodeIfcStepText(p.Name?.value || '');
        const pLong = decodeIfcStepText(p.LongName?.value || '');
        projectNumber = pNum;
        projectName = pLong || pNum || 'Projeto BIM';
        projectPhase = decodeIfcStepText(p.Phase?.value || exchangeRequirement || '');
      }
    }
  } catch (e) {}

  try {
    if (WebIFC.IFCAPPLICATION !== undefined) {
      const apps = await mgr.getAllItemsOfType(modelID, WebIFC.IFCAPPLICATION, true);
      if (Array.isArray(apps) && apps.length > 0) {
        const app = apps[0];
        const fullName = decodeIfcStepText(app.ApplicationFullName?.value || '');
        const ver = decodeIfcStepText(app.Version?.value || '');
        if (fullName) {
          authoringApp = ver && !fullName.includes(ver) ? `${fullName} (${ver})` : fullName;
        }
      }
    }
  } catch (e) {}

  try {
    if (WebIFC.IFCPERSON !== undefined) {
      const persons = await mgr.getAllItemsOfType(modelID, WebIFC.IFCPERSON, true);
      if (Array.isArray(persons) && persons.length > 0) {
        const per = persons[0];
        author = decodeIfcStepText(per.GivenName?.value || per.FamilyName?.value || per.Identification?.value || '');
      }
    }
  } catch (e) {}

  try {
    if (WebIFC.IFCORGANIZATION !== undefined) {
      const orgs = await mgr.getAllItemsOfType(modelID, WebIFC.IFCORGANIZATION, true);
      if (Array.isArray(orgs)) {
        for (const o of orgs) {
          const oName = decodeIfcStepText(o.Name?.value || '').trim();
          if (oName) {
            organization = oName;
            break;
          }
        }
      }
    }
  } catch (e) {}

  try {
    if (WebIFC.IFCSITE !== undefined) {
      const sites = await mgr.getAllItemsOfType(modelID, WebIFC.IFCSITE, true);
      if (Array.isArray(sites) && sites.length > 0) {
        siteName = decodeIfcStepText(sites[0].Name?.value || sites[0].LongName?.value || '');
      }
    }
  } catch (e) {}

  try {
    if (WebIFC.IFCBUILDING !== undefined) {
      const bldgs = await mgr.getAllItemsOfType(modelID, WebIFC.IFCBUILDING, true);
      if (Array.isArray(bldgs) && bldgs.length > 0) {
        buildingName = decodeIfcStepText(bldgs[0].Name?.value || bldgs[0].LongName?.value || '');
      }
    }
  } catch (e) {}

  try {
    if (WebIFC.IFCPOSTALADDRESS !== undefined) {
      const addrs = await mgr.getAllItemsOfType(modelID, WebIFC.IFCPOSTALADDRESS, true);
      if (Array.isArray(addrs) && addrs.length > 0) {
        const a = addrs[0];
        const parts = [];
        if (Array.isArray(a.AddressLines)) {
          for (const line of a.AddressLines) {
            const lv = decodeIfcStepText(line?.value || line || '').trim();
            if (lv && !lv.toLowerCase().includes('insira aqui')) parts.push(lv);
          }
        }
        const town = decodeIfcStepText(a.Town?.value || '').trim();
        const region = decodeIfcStepText(a.Region?.value || '').trim();
        const country = decodeIfcStepText(a.Country?.value || '').trim();
        if (town) parts.push(town);
        if (region) parts.push(region);
        if (country) parts.push(country);
        addressText = parts.join(' • ');
      }
    }
  } catch (e) {}

  // 4. Pavimentos / Níveis do Edifício (IFCBUILDINGSTOREY)
  const storeyMap = new Map();
  try {
    if (WebIFC.IFCBUILDINGSTOREY !== undefined) {
      const rawStoreys = await mgr.getAllItemsOfType(modelID, WebIFC.IFCBUILDINGSTOREY, true);
      if (Array.isArray(rawStoreys)) {
        for (const st of rawStoreys) {
          const sid = Number(st.expressID);
          if (isNaN(sid)) continue;
          const sName = decodeIfcStepText(st.Name?.value || st.LongName?.value || `Nível #${sid}`).trim();
          const rawElev = Number(st.Elevation?.value || 0);
          let elevMeters = isFinite(rawElev) ? rawElev * lengthScale : 0;
          if (Math.abs(elevMeters) < 1e-4) elevMeters = 0;

          storeyMap.set(sid, {
            expressID: sid,
            name: sName,
            elevationMeters: Number(elevMeters.toFixed(3)),
            elementIds: [],
          });
          state.storeyToElements.set(sid, []);
        }
      }
    }
  } catch (e) {
    console.warn('Aviso ao extrair IFCBUILDINGSTOREY:', e);
  }

  // 5. Relação de Contenção Espacial (IFCRELCONTAINEDINSPATIALSTRUCTURE)
  try {
    if (WebIFC.IFCRELCONTAINEDINSPATIALSTRUCTURE !== undefined) {
      const spatialRels = await mgr.getAllItemsOfType(modelID, WebIFC.IFCRELCONTAINEDINSPATIALSTRUCTURE, true);
      if (Array.isArray(spatialRels)) {
        for (const rel of spatialRels) {
          const structureId = Number(rel.RelatingStructure?.value);
          if (isNaN(structureId)) continue;
          const related = rel.RelatedElements || [];
          const bucket = state.storeyToElements.get(structureId);

          for (const item of related) {
            const eid = Number(item?.value !== undefined ? item.value : item);
            if (isNaN(eid)) continue;
            if (storeyMap.has(structureId)) {
              state.elementToStorey.set(eid, structureId);
              if (bucket) bucket.push(eid);

              // Propaga nível para sub-elementos agregados (ex: partes de telhado, escada ou curtain wall)
              const agg = state.parentToChildren.get(eid);
              if (agg && Array.isArray(agg.children)) {
                for (const cid of agg.children) {
                  if (!state.elementToStorey.has(cid)) {
                    state.elementToStorey.set(cid, structureId);
                  }
                }
              }
            }
          }
        }
      }
    }
  } catch (e) {
    console.warn('Aviso ao extrair IFCRELCONTAINEDINSPATIALSTRUCTURE:', e);
  }

  // Ordena níveis por cota de elevação crescente
  const sortedStoreys = Array.from(storeyMap.values()).sort((a, b) => a.elevationMeters - b.elevationMeters);
  for (const s of sortedStoreys) {
    s.elementIds = state.storeyToElements.get(s.expressID) || [];
    s.totalElements = s.elementIds.length;
  }
  state.storeys = sortedStoreys;

  // Fallback: associa elementos geométricos órfãos ao nível mais próximo abaixo de sua cota mínima (minY)
  if (sortedStoreys.length > 0) {
    for (const [eid, bbox] of state.elementBounds.entries()) {
      const parentAgg = state.childToParent.get(eid);
      const rootId = parentAgg ? parentAgg.parentId : eid;
      if (!state.elementToStorey.has(rootId)) {
        const minY = bbox[1];
        let bestStorey = sortedStoreys[0];
        for (const st of sortedStoreys) {
          if (st.elevationMeters <= minY + 0.35) {
            bestStorey = st;
          }
        }
        state.elementToStorey.set(rootId, bestStorey.expressID);
        state.elementToStorey.set(eid, bestStorey.expressID);
        const list = state.storeyToElements.get(bestStorey.expressID);
        if (list && !list.includes(rootId)) {
          list.push(rootId);
          bestStorey.totalElements = list.length;
        }
      }
    }
  }

  // 6. Mapeamento de Tipos de Peça (IFCRELDEFINESBYTYPE) para contagem instantânea de peças idênticas
  try {
    if (WebIFC.IFCRELDEFINESBYTYPE !== undefined) {
      const typeRels = await mgr.getAllItemsOfType(modelID, WebIFC.IFCRELDEFINESBYTYPE, true);
      if (Array.isArray(typeRels)) {
        let typeIdx = 0;
        for (const rel of typeRels) {
          if (++typeIdx % 80 === 0) {
            await new Promise((r) => setTimeout(r, state.activePointers.size > 0 ? 40 : 0));
          }
          const typeId = Number(rel.RelatingType?.value);
          if (isNaN(typeId)) continue;

          let typeName = `Tipo #${typeId}`;
          let typeIfcClass = '';
          try {
            const typeLine = await mgr.getItemProperties(modelID, typeId, false);
            if (typeLine) {
              typeName = decodeIfcStepText(typeLine.Name?.value || typeName);
            }
            typeIfcClass = mgr.getIfcType(modelID, typeId) || '';
          } catch (e) {}

          const typeKey = `TYPE_${typeId}`;
          let set = state.typeToElements.get(typeKey);
          if (!set) {
            set = new Set();
            state.typeToElements.set(typeKey, set);
          }

          const related = rel.RelatedObjects || [];
          for (const item of related) {
            const eid = Number(item?.value !== undefined ? item.value : item);
            if (isNaN(eid)) continue;
            // Se pertence a um elemento pai composto (ex: IfcRoof), contabiliza a peça pai para não inflar sub-partes
            const parentAgg = state.childToParent.get(eid);
            const canonicalId = parentAgg ? parentAgg.parentId : eid;

            state.elementToType.set(eid, { typeId, typeKey, typeName, typeIfcClass });
            state.elementToType.set(canonicalId, { typeId, typeKey, typeName, typeIfcClass });
            set.add(canonicalId);
          }
        }
      }
    }
  } catch (e) {
    console.warn('Aviso ao extrair IFCRELDEFINESBYTYPE:', e);
  }

  // 7. Contagem global de elementos físicos e resumo por categoria IFC
  const uniqueCanonicalElements = new Set();
  for (const list of state.storeyToElements.values()) {
    for (const eid of list) uniqueCanonicalElements.add(eid);
  }
  if (uniqueCanonicalElements.size === 0) {
    for (const eid of state.elementBounds.keys()) {
      const p = state.childToParent.get(eid);
      uniqueCanonicalElements.add(p ? p.parentId : eid);
    }
  }

  const categorySummary = {};
  let catIndex = 0;
  for (const eid of uniqueCanonicalElements) {
    if (++catIndex % 200 === 0) {
      // Libera brevemente a thread (e dá prioridade total ao toque caso o usuário esteja girando a câmera)
      await new Promise((r) => setTimeout(r, state.activePointers.size > 0 ? 40 : 0));
    }
    let cat = 'IfcBuildingElement';
    try {
      cat = mgr.getIfcType(modelID, eid) || cat;
    } catch (e) {}
    state.elementCategoryMap.set(eid, String(cat).toUpperCase());
    categorySummary[cat] = (categorySummary[cat] || 0) + 1;
  }

  state.bimProjectSpecs = {
    schema: schema || 'IFC2X3',
    viewDefinition: viewDefinition || 'CoordinationView V2.0',
    authoringApp: authoringApp || 'Software BIM openBIM',
    author: author || '',
    organization: organization || '',
    projectName: projectName || 'Projeto BIM',
    projectNumber: projectNumber || '',
    projectPhase: projectPhase || '',
    siteName: siteName || '',
    buildingName: buildingName || '',
    address: addressText || '',
    exportDate: exportDate || '',
    coordinateSystem: coordinateSystem || 'Coordenadas Compartilhadas',
    lengthUnit: lengthUnitLabel,
    areaUnit: areaUnitLabel,
    volumeUnit: volumeUnitLabel,
    totalElements: uniqueCanonicalElements.size,
    storeys: sortedStoreys.map((s) => ({
      expressID: s.expressID,
      name: s.name,
      elevationMeters: s.elevationMeters,
      totalElementsInStorey: s.totalElements,
    })),
    categorySummary: categorySummary,
  };

  notifyFlutter('onBimProjectSpecsLoaded', state.bimProjectSpecs);
}

/**
 * Gera especificações básicas quando o arquivo carregado é GLB / GLTF.
 */
function buildGltfFallbackSpecs(modelGroup) {
  const elementIds = [];
  const catSummary = {};
  modelGroup.traverse((child) => {
    if (child.isMesh) {
      const id = child.userData.expressID || child.id;
      elementIds.push(id);
      const cat = deduceBimCategory(child);
      state.elementCategoryMap.set(id, String(cat).toUpperCase());
      catSummary[cat] = (catSummary[cat] || 0) + 1;
      const box = new THREE.Box3().setFromObject(child);
      if (!box.isEmpty()) {
        state.elementBounds.set(id, [
          box.min.x, box.min.y, box.min.z,
          box.max.x, box.max.y, box.max.z
        ]);
      }
    }
  });

  const defaultStoreyId = 1;
  state.storeys = [{
    expressID: defaultStoreyId,
    name: 'Pavimento Principal',
    elevationMeters: 0,
    elementIds: elementIds,
    totalElements: elementIds.length,
  }];
  state.storeyToElements.set(defaultStoreyId, elementIds);
  for (const id of elementIds) {
    state.elementToStorey.set(id, defaultStoreyId);
  }

  state.bimProjectSpecs = {
    schema: 'glTF 2.0 / GLB',
    viewDefinition: 'Malha 3D PBR Otimizada',
    authoringApp: 'Exportador 3D BIM',
    author: '',
    organization: '',
    projectName: 'Modelo Tridimensional',
    projectNumber: '',
    projectPhase: 'Executivo',
    siteName: '',
    buildingName: '',
    address: '',
    exportDate: '',
    coordinateSystem: 'Origem Local (Metros)',
    lengthUnit: 'Metros (m)',
    areaUnit: 'Metros quadrados (m²)',
    volumeUnit: 'Metros cúbicos (m³)',
    totalElements: elementIds.length,
    storeys: [{
      expressID: defaultStoreyId,
      name: 'Pavimento Principal',
      elevationMeters: 0,
      totalElementsInStorey: elementIds.length,
    }],
    categorySummary: catSummary,
  };

  notifyFlutter('onBimProjectSpecsLoaded', state.bimProjectSpecs);
}

/**
 * Extrai especificações completas do elemento IFC (incluindo Psets, Quantitativos Qto, Tipo, Materiais,
 * Geometria Real e Contagem de Peças por Nível) em tempo O(1) indexado e com cache de instância/tipo.
 */
async function enrichIfcElementPayload(modelID, targetID, baseName, baseCategory, psetsFormatted, idsToHighlight, isComposite) {
  const cachedPayload = state.enrichedPayloadCache.get(targetID);
  if (cachedPayload) {
    return {
      ...cachedPayload,
      subIds: idsToHighlight,
      isComposite: Boolean(isComposite),
    };
  }

  const mgr = state.ifcLoader?.ifcManager;
  let resolvedName = baseName || `Elemento BIM #${targetID}`;
  let resolvedCategory = baseCategory || 'IfcBuildingElement';
  let globalId = '';
  let tag = '';
  let predefinedType = '';
  let objectType = '';
  let description = '';
  const materialsList = [];

  if (mgr) {
    // 1. Atributos diretos da entidade IFC (OverallHeight, OverallWidth, PredefinedType, ObjectType, Tag, GlobalId)
    try {
      const itemProps = await mgr.getItemProperties(modelID, targetID, false);
      if (itemProps) {
        resolvedName = itemProps.Name?.value || itemProps.ObjectType?.value || resolvedName;
        try {
          const fullType = mgr.getIfcType(modelID, targetID);
          if (fullType) resolvedCategory = fullType;
        } catch (e) {}

        globalId = decodeIfcStepText(itemProps.GlobalId?.value || '');
        tag = decodeIfcStepText(itemProps.Tag?.value || '');
        predefinedType = decodeIfcStepText(itemProps.PredefinedType?.value || '');
        objectType = decodeIfcStepText(itemProps.ObjectType?.value || '');
        description = decodeIfcStepText(itemProps.Description?.value || '');

        const genGroup = psetsFormatted['Propriedades Gerais'] || {
          'ExpressID': targetID,
          'Nome': decodeIfcStepText(resolvedName),
          'Categoria IFC': resolvedCategory,
          'GlobalId': globalId || 'N/A',
          'Tag': tag || 'N/A',
        };
        if (objectType && objectType !== decodeIfcStepText(resolvedName)) genGroup['ObjectType'] = objectType;
        if (predefinedType && predefinedType !== 'NOTDEFINED') genGroup['PredefinedType'] = predefinedType;
        if (description) genGroup['Description'] = description;
        if (itemProps.OverallHeight?.value !== undefined) {
          const oh = Number(itemProps.OverallHeight.value) * state.lengthUnitScale;
          if (isFinite(oh) && oh > 0) genGroup['OverallHeight'] = Number(oh.toFixed(3));
        }
        if (itemProps.OverallWidth?.value !== undefined) {
          const ow = Number(itemProps.OverallWidth.value) * state.lengthUnitScale;
          if (isFinite(ow) && ow > 0) genGroup['OverallWidth'] = Number(ow.toFixed(3));
        }
        psetsFormatted['Propriedades Gerais'] = genGroup;
      }
    } catch (e) {}

    // 2. Extração O(1) unificada de IfcPropertySet (HasProperties) e IfcElementQuantity (Quantities)
    try {
      const psets = await getElementPropertySetsFast(modelID, targetID);
      if (Array.isArray(psets)) {
        for (const pset of psets) {
          const psetName = decodeIfcStepText(pset.Name?.value || 'Outras Propriedades');
          const group = psetsFormatted[psetName] ? { ...psetsFormatted[psetName] } : {};

          if (Array.isArray(pset.HasProperties)) {
            for (const prop of pset.HasProperties) {
              const propName = decodeIfcStepText(prop?.Name?.value || '');
              const propVal = prop?.NominalValue?.value;
              if (propName && propVal !== undefined) {
                group[propName] = typeof propVal === 'number'
                  ? Number(propVal.toFixed(3))
                  : decodeIfcStepText(propVal);
              }
            }
          }

          if (Array.isArray(pset.Quantities) && pset.Quantities.length > 0) {
            for (const q of pset.Quantities) {
              const qName = decodeIfcStepText(q?.Name?.value || '');
              const rawVal =
                q?.LengthValue?.value ??
                q?.AreaValue?.value ??
                q?.VolumeValue?.value ??
                q?.WeightValue?.value ??
                q?.CountValue?.value;
              if (qName && rawVal !== undefined) {
                let num = Number(rawVal);
                if (q?.LengthValue?.value !== undefined && isFinite(num)) {
                  num = num * state.lengthUnitScale;
                }
                group[qName] = isFinite(num) ? Number(num.toFixed(3)) : decodeIfcStepText(rawVal);
              }
            }
          }

          if (Object.keys(group).length > 0) {
            psetsFormatted[psetName] = group;
          }
        }
      }
    } catch (e) {}

    // 3. Propriedades do Tipo (IfcTypeObject / IFCRELDEFINESBYTYPE) com cache O(1) por typeId
    const typeInfo = state.elementToType.get(targetID);
    if (typeInfo && typeInfo.typeId) {
      let cachedTypeSpec = state.typePropsCache.get(typeInfo.typeId);
      if (!cachedTypeSpec) {
        try {
          const typeProps = await mgr.getItemProperties(modelID, typeInfo.typeId, true);
          if (typeProps) {
            const tGroup = {};
            const extraTypePsets = {};
            if (typeInfo.typeName) tGroup['TypeName'] = typeInfo.typeName;
            if (typeInfo.typeIfcClass) tGroup['TypeClass'] = typeInfo.typeIfcClass;
            if (typeProps.ApplicableOccurrence?.value) {
              tGroup['ApplicableOccurrence'] = decodeIfcStepText(typeProps.ApplicableOccurrence.value);
            }
            if (typeProps.ElementType?.value) {
              tGroup['ElementType'] = decodeIfcStepText(typeProps.ElementType.value);
            }
            if (typeProps.ConstructionType?.value) {
              tGroup['ConstructionType'] = decodeIfcStepText(typeProps.ConstructionType.value);
            }
            if (typeProps.OperationType?.value && typeProps.OperationType.value !== 'NOTDEFINED') {
              tGroup['OperationType'] = decodeIfcStepText(typeProps.OperationType.value);
            }

            if (Array.isArray(typeProps.HasPropertySets)) {
              for (const tpset of typeProps.HasPropertySets) {
                const tpName = decodeIfcStepText(tpset?.Name?.value || '');
                if (Array.isArray(tpset?.HasProperties)) {
                  const subGroup = tpName ? (extraTypePsets[tpName] || {}) : tGroup;
                  for (const p of tpset.HasProperties) {
                    const k = decodeIfcStepText(p?.Name?.value || '');
                    const v = p?.NominalValue?.value;
                    if (k && v !== undefined && subGroup[k] === undefined) {
                      subGroup[k] = typeof v === 'number' ? Number(v.toFixed(3)) : decodeIfcStepText(v);
                    }
                  }
                  if (tpName && Object.keys(subGroup).length > 0) {
                    extraTypePsets[tpName] = subGroup;
                  }
                }
              }
            }

            cachedTypeSpec = { tGroup, extraTypePsets };
            state.typePropsCache.set(typeInfo.typeId, cachedTypeSpec);
          }
        } catch (e) {}
      }

      if (cachedTypeSpec) {
        for (const [tpName, tpGroup] of Object.entries(cachedTypeSpec.extraTypePsets)) {
          psetsFormatted[tpName] = { ...tpGroup, ...(psetsFormatted[tpName] || {}) };
        }
        if (Object.keys(cachedTypeSpec.tGroup).length > 0) {
          psetsFormatted['Especificação de Tipo (openBIM)'] = { ...cachedTypeSpec.tGroup };
        }
      }
    }

    // 4. Materiais e Camadas Construtivas O(1) (IFCRELASSOCIATESMATERIAL)
    try {
      const mats = await getElementMaterialsFast(modelID, targetID);
      if (Array.isArray(mats) && mats.length > 0) {
        const matGroup = {};
        let layerIdx = 1;

        for (const m of mats) {
          if (m.Name?.value) {
            const mName = decodeIfcStepText(m.Name.value);
            if (mName && !materialsList.includes(mName)) materialsList.push(mName);
            matGroup['Material Principal'] = mName;
          }
          const layerSet = m.ForLayerSet || m;
          if (layerSet?.LayerSetName?.value) {
            matGroup['Conjunto de Camadas'] = decodeIfcStepText(layerSet.LayerSetName.value);
          }
          const layers = layerSet?.MaterialLayers || m.Materials || m.MaterialConstituents || [];
          if (Array.isArray(layers)) {
            for (const layer of layers) {
              const lMatName = decodeIfcStepText(
                layer?.Material?.Name?.value || layer?.Name?.value || ''
              ).trim();
              const rawThick = layer?.LayerThickness?.value;
              let thickLabel = '';
              if (rawThick !== undefined) {
                const thickM = Number(rawThick) * state.lengthUnitScale;
                if (isFinite(thickM) && thickM > 0) {
                  const thickMm = Math.round(thickM * 1000);
                  thickLabel = `${thickMm} mm (${thickM.toFixed(2).replace('.', ',')} m)`;
                }
              }
              if (lMatName) {
                const entryLabel = thickLabel ? `${lMatName} • ${thickLabel}` : lMatName;
                if (!materialsList.includes(entryLabel)) materialsList.push(entryLabel);
                matGroup[`Camada ${layerIdx++}`] = entryLabel;
              }
            }
          }
        }

        if (Object.keys(matGroup).length > 0) {
          psetsFormatted['Materiais e Camadas (IfcMaterial)'] = matGroup;
        }
      }
    } catch (e) {}
  }

  // 5. Dimensões Físicas Reais 3D (BoundingBox em Metros)
  const worldBox = getElementWorldBox(targetID);
  const geometricDimensions = {};
  if (!worldBox.isEmpty()) {
    const size = worldBox.getSize(new THREE.Vector3());
    const horizMax = Math.max(size.x, size.z);
    const horizMin = Math.min(size.x, size.z);
    geometricDimensions.length = Number(horizMax.toFixed(3));
    geometricDimensions.width = Number(horizMin.toFixed(3));
    geometricDimensions.height = Number(size.y.toFixed(3));
    geometricDimensions.minElevation = Number(worldBox.min.y.toFixed(3));
    geometricDimensions.maxElevation = Number(worldBox.max.y.toFixed(3));

    psetsFormatted['Geometria Física 3D (Canteiro)'] = {
      'Length': geometricDimensions.length,
      'Width': geometricDimensions.width,
      'Height': geometricDimensions.height,
      'BaseElevation': `${geometricDimensions.minElevation >= 0 ? '+' : ''}${geometricDimensions.minElevation.toFixed(2).replace('.', ',')} m`,
      'TopElevation': `${geometricDimensions.maxElevation >= 0 ? '+' : ''}${geometricDimensions.maxElevation.toFixed(2).replace('.', ',')} m`,
    };
  }

  if (Object.keys(psetsFormatted).length <= 1) {
    psetsFormatted['Dados Técnicos'] = {
      'Modelo': 'Projeto openBIM IFC',
      'Geometria': 'Sólido WebAssembly',
      'Status': 'Construído (As-Built)',
    };
  }

  // 6. Análise Quantitativa de Peças Idênticas por Nível (Storey) com cache instantâneo por Tipo
  const analytics = await computePieceStoreyAnalytics(modelID, targetID, resolvedName, resolvedCategory);

  const resultPayload = {
    expressID: targetID,
    name: decodeIfcStepText(resolvedName),
    category: resolvedCategory,
    globalId: globalId,
    tag: tag,
    predefinedType: predefinedType,
    typeName: analytics.typeName,
    hostStoreyId: analytics.hostStoreyId,
    hostStoreyName: analytics.hostStoreyName,
    materials: materialsList,
    geometricDimensions: geometricDimensions,
    analytics: analytics,
    psets: psetsFormatted,
    subIds: idsToHighlight,
    isComposite: Boolean(isComposite),
  };

  if (state.enrichedPayloadCache.size >= 300) {
    const oldestKey = state.enrichedPayloadCache.keys().next().value;
    state.enrichedPayloadCache.delete(oldestKey);
  }
  state.enrichedPayloadCache.set(targetID, resultPayload);

  return resultPayload;
}

/**
 * Calcula quantas unidades desta mesma peça/tipo existem no projeto inteiro e em cada pavimento (IfcBuildingStorey),
 * reutilizando em O(1) o cache analítico quando o usuário navega entre dezenas/centenas de peças do mesmo tipo.
 */
async function computePieceStoreyAnalytics(modelID, targetID, rawName, category) {
  const mgr = state.ifcLoader?.ifcManager;
  const hostStoreyId = state.elementToStorey.get(targetID) ?? null;
  const hostStoreyObj = state.storeys.find((s) => s.expressID === hostStoreyId);
  const hostStoreyName = hostStoreyObj ? hostStoreyObj.name : null;

  const typeInfo = state.elementToType.get(targetID);
  const hasTypeBucket = Boolean(typeInfo && state.typeToElements.has(typeInfo.typeKey));
  const targetSig = hasTypeBucket ? null : normalizeFamilyTypeSignature(rawName, category);
  const cacheKey = hasTypeBucket ? `TYPE::${typeInfo.typeKey}` : `SIG::${targetSig}`;

  const cachedBase = state.pieceAnalyticsCache.get(cacheKey);
  if (cachedBase) {
    return {
      ...cachedBase,
      hostStoreyId: hostStoreyId,
      hostStoreyName: hostStoreyName,
    };
  }

  let matchingIds = [];
  let cleanTypeName = decodeIfcStepText(rawName || '');
  let ifcTypeClass = typeInfo?.typeIfcClass || '';

  if (hasTypeBucket) {
    cleanTypeName = typeInfo.typeName || cleanTypeName;
    matchingIds = Array.from(state.typeToElements.get(typeInfo.typeKey));
  } else {
    // Fallback por assinatura normalizada Família:Tipo + Categoria IFC
    const candidateIds = new Set([targetID]);
    for (const list of state.storeyToElements.values()) {
      for (const eid of list) candidateIds.add(eid);
    }

    const expectedCatUpper = String(category || '').toUpperCase();
    for (const eid of candidateIds) {
      if (eid === targetID) {
        matchingIds.push(eid);
        continue;
      }
      let cached = state.elementMetaIndex.get(eid);
      if (!cached && mgr && modelID !== undefined) {
        try {
          const eCat = state.elementCategoryMap.get(eid) || (mgr.getIfcType(modelID, eid) || '').toUpperCase();
          if (eCat.toUpperCase() !== expectedCatUpper) {
            state.elementMetaIndex.set(eid, { cat: eCat, sig: '' });
            continue;
          }
          const props = await mgr.getItemProperties(modelID, eid, false);
          const eName = props?.Name?.value || props?.ObjectType?.value || '';
          cached = { cat: eCat, sig: normalizeFamilyTypeSignature(eName, eCat) };
          state.elementMetaIndex.set(eid, cached);
        } catch (e) {}
      } else if (!cached && state.currentModel && state.currentModel.modelID === undefined) {
        state.currentModel.traverse((child) => {
          if (child.isMesh && (child.userData.expressID === eid || child.id === eid)) {
            const eCat = deduceBimCategory(child);
            cached = { cat: eCat, sig: normalizeFamilyTypeSignature(child.name, eCat) };
          }
        });
      }
      if (cached && cached.sig === targetSig) {
        matchingIds.push(eid);
      }
    }
  }

  if (!matchingIds.includes(targetID)) {
    matchingIds.unshift(targetID);
  }

  // Agrupa instâncias da peça e contagem da categoria por Nível (Storey)
  const countByStorey = {};
  const instanceIdsByStorey = {};
  const categoryCountByStorey = {};
  const metricsByStorey = {};

  for (const st of state.storeys) {
    countByStorey[String(st.expressID)] = 0;
    instanceIdsByStorey[String(st.expressID)] = [];
    categoryCountByStorey[String(st.expressID)] = 0;
    metricsByStorey[String(st.expressID)] = { lengthM: 0, areaM2: 0, volumeM3: 0 };
  }

  // Contagem instantânea da mesma categoria IFC por pavimento via mapa em memória (zero WASM GetIfcType repetido)
  let totalCategoryInProject = 0;
  const targetCatUpper = String(category || '').toUpperCase();
  for (const st of state.storeys) {
    const key = String(st.expressID);
    const elems = state.storeyToElements.get(st.expressID) || [];
    let catCount = 0;
    for (const eid of elems) {
      let eCat = state.elementCategoryMap.get(eid);
      if (eCat === undefined) {
        if (mgr && modelID !== undefined) {
          try {
            eCat = String(mgr.getIfcType(modelID, eid) || '').toUpperCase();
          } catch (e) {
            eCat = '';
          }
        } else {
          eCat = targetCatUpper;
        }
        state.elementCategoryMap.set(eid, eCat);
      }
      if (eCat === targetCatUpper) catCount++;
    }
    categoryCountByStorey[key] = catCount;
    totalCategoryInProject += catCount;
  }

  // Métricas geométricas acumuladas por pavimento e totais do projeto
  let totalLengthM = 0;
  let totalAreaM2 = 0;
  let totalVolumeM3 = 0;

  for (const eid of matchingIds) {
    const sid = state.elementToStorey.get(eid);
    const box = getElementWorldBox(eid);
    let instLen = 0, instArea = 0, instVol = 0;

    if (!box.isEmpty()) {
      const sz = box.getSize(new THREE.Vector3());
      const hMax = Math.max(sz.x, sz.z);
      instLen = hMax;
      if (targetCatUpper.includes('SLAB') || targetCatUpper.includes('ROOF') || targetCatUpper.includes('COVERING')) {
        instArea = sz.x * sz.z;
      } else {
        instArea = hMax * sz.y;
      }
      instVol = sz.x * sz.y * sz.z;
    }

    totalLengthM += instLen;
    totalAreaM2 += instArea;
    totalVolumeM3 += instVol;

    if (sid !== undefined && sid !== null) {
      const key = String(sid);
      countByStorey[key] = (countByStorey[key] || 0) + 1;
      if (!instanceIdsByStorey[key]) instanceIdsByStorey[key] = [];
      instanceIdsByStorey[key].push(eid);

      if (!metricsByStorey[key]) {
        metricsByStorey[key] = { lengthM: 0, areaM2: 0, volumeM3: 0 };
      }
      metricsByStorey[key].lengthM = Number((metricsByStorey[key].lengthM + instLen).toFixed(2));
      metricsByStorey[key].areaM2 = Number((metricsByStorey[key].areaM2 + instArea).toFixed(2));
      metricsByStorey[key].volumeM3 = Number((metricsByStorey[key].volumeM3 + instVol).toFixed(3));
    }
  }

  const baseAnalytics = {
    typeName: cleanTypeName,
    ifcTypeClass: ifcTypeClass,
    totalInProject: matchingIds.length,
    totalCategoryInProject: Math.max(totalCategoryInProject, matchingIds.length),
    allInstanceIds: matchingIds,
    countByStorey: countByStorey,
    instanceIdsByStorey: instanceIdsByStorey,
    categoryCountByStorey: categoryCountByStorey,
    totalMetrics: {
      lengthM: Number(totalLengthM.toFixed(2)),
      areaM2: Number(totalAreaM2.toFixed(2)),
      volumeM3: Number(totalVolumeM3.toFixed(3)),
    },
    metricsByStorey: metricsByStorey,
  };

  state.pieceAnalyticsCache.set(cacheKey, baseAnalytics);

  return {
    ...baseAnalytics,
    hostStoreyId: hostStoreyId,
    hostStoreyName: hostStoreyName,
  };
}

/**
 * Converte categoria bruta openBIM (ex: IFCWALLSTANDARDCASE) para rótulo legível em português.
 */
function getFriendlyBimCategoryName(cat) {
  const c = String(cat || '').toUpperCase();
  if (c.includes('WALL')) return 'Parede';
  if (c.includes('WINDOW')) return 'Janela';
  if (c.includes('DOOR')) return 'Porta';
  if (c.includes('COLUMN')) return 'Pilar';
  if (c.includes('BEAM')) return 'Viga';
  if (c.includes('SLAB')) return 'Laje';
  if (c.includes('FLOWTERMINAL')) return 'Ponto Sanitário';
  if (c.includes('FURNISHING')) return 'Mobiliário';
  if (c.includes('ROOF')) return 'Cobertura';
  if (c.includes('STAIR')) return 'Escada';
  if (c.includes('RAILING')) return 'Guarda-corpo';
  if (c.includes('COVERING')) return 'Revestimento';
  return 'Elemento';
}

/**
 * Calcula a distância euclidiana exata mínima face-a-face entre duas caixas 3D (THREE.Box3)
 * e retorna os dois pontos mais próximos nas superfícies das respectivas caixas.
 */
function getBoxesMinDistanceAndPoints(boxA, boxB) {
  const pA = new THREE.Vector3();
  const pB = new THREE.Vector3();
  let distSq = 0;

  // Eixo X
  if (boxA.max.x < boxB.min.x) {
    const d = boxB.min.x - boxA.max.x;
    distSq += d * d;
    pA.x = boxA.max.x;
    pB.x = boxB.min.x;
  } else if (boxB.max.x < boxA.min.x) {
    const d = boxA.min.x - boxB.max.x;
    distSq += d * d;
    pA.x = boxA.min.x;
    pB.x = boxB.max.x;
  } else {
    const mid = (Math.max(boxA.min.x, boxB.min.x) + Math.min(boxA.max.x, boxB.max.x)) * 0.5;
    pA.x = mid;
    pB.x = mid;
  }

  // Eixo Y
  if (boxA.max.y < boxB.min.y) {
    const d = boxB.min.y - boxA.max.y;
    distSq += d * d;
    pA.y = boxA.max.y;
    pB.y = boxB.min.y;
  } else if (boxB.max.y < boxA.min.y) {
    const d = boxA.min.y - boxB.max.y;
    distSq += d * d;
    pA.y = boxA.min.y;
    pB.y = boxB.max.y;
  } else {
    const mid = (Math.max(boxA.min.y, boxB.min.y) + Math.min(boxA.max.y, boxB.max.y)) * 0.5;
    pA.y = mid;
    pB.y = mid;
  }

  // Eixo Z
  if (boxA.max.z < boxB.min.z) {
    const d = boxB.min.z - boxA.max.z;
    distSq += d * d;
    pA.z = boxA.max.z;
    pB.z = boxB.min.z;
  } else if (boxB.max.z < boxA.min.z) {
    const d = boxA.min.z - boxB.max.z;
    distSq += d * d;
    pA.z = boxA.min.z;
    pB.z = boxB.max.z;
  } else {
    const mid = (Math.max(boxA.min.z, boxB.min.z) + Math.min(boxA.max.z, boxB.max.z)) * 0.5;
    pA.z = mid;
    pB.z = mid;
  }

  return {
    distance: Math.sqrt(distSq),
    pointA: pA,
    pointB: pB,
  };
}

/**
 * Cria a textura dinâmica 2D renderizada em Canvas para o Badge de cota de proximidade da Visão Dinâmica
 */
function createProximitySprite(text) {
  const canvas = document.createElement('canvas');
  canvas.width = 540;
  canvas.height = 130;
  const ctx = canvas.getContext('2d');

  const r = 24;
  const w = 528;
  const h = 118;
  const x = 6;
  const y = 6;

  // Fundo cápsula Dark Slate (#0F172A) com borda Sky Blue (#38BDF8)
  ctx.fillStyle = 'rgba(15, 23, 42, 0.94)';
  ctx.strokeStyle = '#38BDF8';
  ctx.lineWidth = 5;

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
  ctx.font = 'bold 36px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
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
  sprite.scale.set(1.45, 0.35, 1.0);
  return sprite;
}

/**
 * Descarta recursos de GPU (geometria, texturas e materiais) do grupo de cota de proximidade
 */
function clearProximityDimensionGroupOnly() {
  if (!state.dynamicProximityGroup) return;
  while (state.dynamicProximityGroup.children.length > 0) {
    const child = state.dynamicProximityGroup.children[0];
    state.dynamicProximityGroup.remove(child);
    if (child.traverse) {
      child.traverse((obj) => {
        if (obj.geometry) obj.geometry.dispose();
        if (obj.material) {
          if (Array.isArray(obj.material)) {
            obj.material.forEach((m) => {
              if (m.map) m.map.dispose();
              m.dispose();
            });
          } else {
            if (obj.material.map) obj.material.map.dispose();
            obj.material.dispose();
          }
        }
      });
    }
  }
}

/**
 * Remove a cota tridimensional de proximidade do 3D e reseta o cache
 */
function clearProximityDimensionLine() {
  clearProximityDimensionGroupOnly();
  state.lastProximityData = null;
  if (typeof requestRender === 'function') requestRender(2);
}

/**
 * Localiza o elemento vizinho mais próximo logicamente relevante num raio máximo de 6.0 metros
 * (restringindo estritamente aos elementos do mesmo nível/pavimento para máxima fluidez).
 */
function findNearestLogicalNeighbor(targetId, maxRadius = 6.0) {
  const id = Number(targetId);
  if (isNaN(id) || !state.currentModel) return null;

  const targetBox = getElementWorldBox(id);
  if (targetBox.isEmpty()) return null;

  const targetAgg = state.parentToChildren.get(id) || state.childToParent.get(id);
  const excludedIds = new Set([id]);
  if (targetAgg) {
    excludedIds.add(targetAgg.parentId);
    if (Array.isArray(targetAgg.children)) {
      for (const cid of targetAgg.children) excludedIds.add(cid);
    }
  }

  const targetCat = (state.elementCategoryMap.get(id) || '').toUpperCase();
  const targetMeta = state.elementMetaIndex.get(id);
  const targetSig = (targetMeta?.sig || '').toLowerCase();

  const isFixture = targetCat.includes('FLOWTERMINAL') || targetCat.includes('FURNISHING') ||
    /patente|vaso|sanit|toilet|bacia|bide|lavat|pia|chuveiro/.test(targetSig);
  const isOpening = targetCat.includes('WINDOW') || targetCat.includes('DOOR');

  // Restringe a busca aos elementos do mesmo pavimento (reduz de milhares para poucas dezenas)
  const storeyId = state.elementToStorey.get(id);
  let candidateIds = null;
  if (storeyId !== undefined && state.storeyToElements.has(storeyId)) {
    candidateIds = state.storeyToElements.get(storeyId);
  } else {
    candidateIds = Array.from(state.elementBounds.keys());
  }

  const searchBox = targetBox.clone().expandByScalar(maxRadius);
  let bestPriority = null;
  let bestOverall = null;

  for (const cid of candidateIds) {
    if (excludedIds.has(cid)) continue;

    const candBox = getElementWorldBox(cid);
    if (candBox.isEmpty()) continue;
    if (!searchBox.intersectsBox(candBox)) continue;

    const { distance, pointA, pointB } = getBoxesMinDistanceAndPoints(targetBox, candBox);
    if (distance > maxRadius) continue;

    const candCat = (state.elementCategoryMap.get(cid) || '').toUpperCase();
    const candMeta = state.elementMetaIndex.get(cid);
    const candSig = (candMeta?.sig || '').toLowerCase();

    // Prioridade lógica:
    // - Para louças/patentes: Parede ou divisória de fundo
    // - Para janelas/portas: Paredes de apoio ou pilares
    // - Para paredes: Outras paredes, pilares ou lajes
    let isPriority = false;
    if (isFixture) {
      isPriority = (candCat.includes('WALL') || /parede|divis|alvenaria|drywall|gesso/.test(candSig)) &&
        !candCat.includes('SLAB');
    } else if (isOpening) {
      isPriority = candCat.includes('WALL') || candCat.includes('COLUMN');
    } else {
      isPriority = candCat.includes('WALL') || candCat.includes('COLUMN') || candCat.includes('SLAB');
    }

    const typeLabel = getFriendlyBimCategoryName(candCat);
    const friendlyName = candMeta?.name
      ? decodeIfcStepText(candMeta.name)
      : `${typeLabel} #${cid}`;

    const candRecord = {
      targetExpressId: id,
      neighborExpressId: cid,
      neighborType: typeLabel,
      neighborName: friendlyName,
      distanceMeters: Number(distance.toFixed(3)),
      formattedDistance: `${distance.toFixed(2).replace('.', ',')} m`,
      pointTarget: pointA,
      pointNeighbor: pointB,
      hasNeighbor: true,
    };

    if (isPriority) {
      if (!bestPriority || distance < bestPriority.distanceMeters) {
        bestPriority = candRecord;
      }
    }
    if (!bestOverall || distance < bestOverall.distanceMeters) {
      bestOverall = candRecord;
    }
  }

  const chosen = bestPriority || bestOverall;
  if (chosen) {
    return chosen;
  }

  return {
    targetExpressId: id,
    neighborExpressId: null,
    neighborType: null,
    neighborName: null,
    distanceMeters: null,
    formattedDistance: 'Sem elementos a menos de 6 m',
    hasNeighbor: false,
  };
}

/**
 * Renderiza a linha de cota BIM 3D contínua (#38BDF8 Sky Blue) com traços perpendiculares
 * de terminação e badge flutuante em metros conectado ao ponto mais próximo.
 */
function renderProximityDimensionLine(proxData) {
  if (!state.scene) return;

  if (!state.dynamicProximityGroup) {
    state.dynamicProximityGroup = new THREE.Group();
    state.dynamicProximityGroup.name = 'DynamicProximityGroup';
    state.scene.add(state.dynamicProximityGroup);
  }

  clearProximityDimensionGroupOnly();

  if (!state.showDynamicProximity || !proxData || !proxData.hasNeighbor || !proxData.pointTarget || !proxData.pointNeighbor) {
    if (typeof requestRender === 'function') requestRender(2);
    if (proxData) {
      notifyFlutter('onProximityDimensionCalculated', {
        targetExpressId: proxData.targetExpressId,
        neighborExpressId: null,
        neighborType: null,
        neighborName: null,
        distanceMeters: null,
        formattedDistance: 'Sem elementos a menos de 6 m',
        hasNeighbor: false,
      });
    }
    return;
  }

  const P0 = proxData.pointTarget;
  const P1 = proxData.pointNeighbor;
  const dist = proxData.distanceMeters;
  const colorHex = 0x38BDF8;

  const group = new THREE.Group();
  group.name = 'ProximityActiveVisual';

  // 1. Esferas de ancoragem nos pontos inicial e final
  const sphereGeom = new THREE.SphereGeometry(0.038, 16, 16);
  const sphereMat = new THREE.MeshBasicMaterial({ color: colorHex, depthTest: false });

  const s0 = new THREE.Mesh(sphereGeom, sphereMat);
  s0.position.copy(P0);
  s0.renderOrder = 10;
  group.add(s0);

  const s1 = new THREE.Mesh(sphereGeom, sphereMat);
  s1.position.copy(P1);
  s1.renderOrder = 10;
  group.add(s1);

  // 2. Linha contínua técnica de cota
  const lineGeom = new THREE.BufferGeometry().setFromPoints([P0, P1]);
  const lineMat = new THREE.LineBasicMaterial({
    color: colorHex,
    linewidth: 3,
    depthTest: false,
    transparent: true,
    opacity: 0.95,
  });
  const line = new THREE.Line(lineGeom, lineMat);
  line.renderOrder = 10;
  group.add(line);

  // 3. Ticks perpendiculares nas extremidades
  const dir = P1.clone().sub(P0);
  const len = dir.length();
  if (len > 0.01) {
    dir.normalize();
    const up = Math.abs(dir.y) > 0.85 ? new THREE.Vector3(1, 0, 0) : new THREE.Vector3(0, 1, 0);
    const perp = new THREE.Vector3().crossVectors(dir, up).normalize().multiplyScalar(0.09);

    const tick0Geom = new THREE.BufferGeometry().setFromPoints([
      P0.clone().sub(perp),
      P0.clone().add(perp),
    ]);
    const tick1Geom = new THREE.BufferGeometry().setFromPoints([
      P1.clone().sub(perp),
      P1.clone().add(perp),
    ]);
    const tickMat = new THREE.LineBasicMaterial({ color: colorHex, linewidth: 2, depthTest: false });
    const tick0 = new THREE.Line(tick0Geom, tickMat);
    const tick1 = new THREE.Line(tick1Geom, tickMat);
    tick0.renderOrder = 10;
    tick1.renderOrder = 10;
    group.add(tick0);
    group.add(tick1);
  }

  // 4. Badge numérico flutuante (Billboard Sprite)
  const midPoint = P0.clone().add(P1).multiplyScalar(0.5);
  midPoint.y += 0.10;
  const labelText = `↔ ${dist.toFixed(2).replace('.', ',')} m • ${proxData.neighborName}`;
  const sprite = createProximitySprite(labelText);
  sprite.position.copy(midPoint);
  sprite.renderOrder = 11;
  group.add(sprite);

  state.dynamicProximityGroup.add(group);
  if (typeof requestRender === 'function') requestRender(3);

  // Notifica o Flutter para atualizar o painel de especificações
  notifyFlutter('onProximityDimensionCalculated', {
    targetExpressId: proxData.targetExpressId,
    neighborExpressId: proxData.neighborExpressId,
    neighborType: proxData.neighborType,
    neighborName: proxData.neighborName,
    distanceMeters: proxData.distanceMeters,
    formattedDistance: proxData.formattedDistance,
    hasNeighbor: true,
  });
}

/**
 * Ativa ou desativa a exibição da cota 3D de proximidade na viewport
 */
function setProximityDimensionEnabled(enabled) {
  state.showDynamicProximity = Boolean(enabled);
  if (!state.showDynamicProximity) {
    clearProximityDimensionGroupOnly();
  } else {
    const id = state.selectedObject?.expressID;
    if (id !== undefined && !isNaN(id)) {
      const proximityData = findNearestLogicalNeighbor(id, 6.0);
      state.lastProximityData = proximityData;
      renderProximityDimensionLine(proximityData);
    }
  }
  if (typeof requestRender === 'function') requestRender(2);
}

/**
 * Testa se há obstruções (elementos intervenientes) entre a posição da câmera e o centro do elemento
 */
function testSightlineHasOcclusion(targetCenter, cameraPos, targetId) {
  if (!state.currentModel) return false;
  const dir = targetCenter.clone().sub(cameraPos);
  const distance = dir.length();
  if (distance < 0.35) return false;
  dir.normalize();

  const ray = new THREE.Raycaster(cameraPos, dir, 0.15, Math.max(0.2, distance - 0.20));
  const hits = ray.intersectObjects([state.currentModel], true);
  if (!Array.isArray(hits) || hits.length === 0) return false;

  const targetAgg = state.parentToChildren.get(targetId) || state.childToParent.get(targetId);
  const excludedIds = new Set([targetId]);
  if (targetAgg) {
    excludedIds.add(targetAgg.parentId);
    if (Array.isArray(targetAgg.children)) {
      for (const cid of targetAgg.children) excludedIds.add(cid);
    }
  }

  for (const hit of hits) {
    let hitId = null;
    if (state.ifcLoader && hit.object?.geometry && hit.faceIndex !== undefined) {
      try {
        hitId = state.ifcLoader.ifcManager.getExpressId(hit.object.geometry, hit.faceIndex);
      } catch (e) {}
    } else if (hit.object) {
      hitId = hit.object.userData?.expressID || hit.object.id;
    }
    if (hitId !== null && hitId !== undefined && !excludedIds.has(hitId)) {
      return true;
    }
  }
  return false;
}

/**
 * Restaura materiais originais modificados pelo auto-ghosting de linha de visada
 */
function restoreOccludedGhostMaterials() {
  if (state.occludedGhostIds.size === 0 && state.occludedSavedMaterials.size === 0) return;

  // 1. Caso IFC (remove o subset translúcido sobreposto)
  if (state.ifcLoader && state.currentModel?.modelID !== undefined && state.xrayContextMaterial) {
    try {
      state.ifcLoader.ifcManager.removeSubset(state.currentModel.modelID, state.xrayContextMaterial);
    } catch (e) {}
  }

  // 2. Caso GLTF / Malhas avulsas
  if (state.occludedSavedMaterials.size > 0) {
    for (const [mesh, savedMat] of state.occludedSavedMaterials.entries()) {
      if (mesh && savedMat) {
        mesh.material = savedMat;
      }
    }
  }

  state.occludedGhostIds.clear();
  state.occludedSavedMaterials.clear();
  if (typeof requestRender === 'function') requestRender(2);
}

/**
 * Identifica e torna translúcidos (14% de opacidade) apenas os elementos que bloqueiam a visada da câmera
 */
function resolveSightlineOcclusions(targetCenter, cameraPos, targetId) {
  restoreOccludedGhostMaterials();
  if (!state.currentModel || !state.scene || state.isDynamicXrayActive) return;

  const dir = targetCenter.clone().sub(cameraPos);
  const distance = dir.length();
  if (distance < 0.35) return;
  dir.normalize();

  const ray = new THREE.Raycaster(cameraPos, dir, 0.15, Math.max(0.2, distance - 0.20));
  const hits = ray.intersectObjects([state.currentModel], true);
  if (!Array.isArray(hits) || hits.length === 0) return;

  const targetAgg = state.parentToChildren.get(targetId) || state.childToParent.get(targetId);
  const excludedIds = new Set([targetId]);
  if (targetAgg) {
    excludedIds.add(targetAgg.parentId);
    if (Array.isArray(targetAgg.children)) {
      for (const cid of targetAgg.children) excludedIds.add(cid);
    }
  }

  const occludingIds = new Set();
  const occludingMeshes = [];

  for (const hit of hits) {
    let hitId = null;
    if (state.ifcLoader && hit.object?.geometry && hit.faceIndex !== undefined) {
      try {
        hitId = state.ifcLoader.ifcManager.getExpressId(hit.object.geometry, hit.faceIndex);
      } catch (e) {}
    } else if (hit.object) {
      hitId = hit.object.userData?.expressID || hit.object.id;
    }

    if (hitId !== null && hitId !== undefined && !excludedIds.has(hitId)) {
      occludingIds.add(hitId);
      if (hit.object && hit.object.isMesh && !state.ifcLoader) {
        occludingMeshes.push(hit.object);
      }
    }
  }

  if (occludingIds.size === 0) return;

  if (state.ifcLoader && state.currentModel.modelID !== undefined && state.xrayContextMaterial) {
    try {
      state.ifcLoader.ifcManager.createSubset({
        modelID: state.currentModel.modelID,
        ids: Array.from(occludingIds),
        scene: state.scene,
        removePrevious: true,
        material: state.xrayContextMaterial,
      });
      state.occludedGhostIds = occludingIds;
    } catch (e) {}
  } else if (occludingMeshes.length > 0 && state.xrayContextMaterial) {
    for (const mesh of occludingMeshes) {
      if (!state.occludedSavedMaterials.has(mesh)) {
        state.occludedSavedMaterials.set(mesh, mesh.material);
      }
      mesh.material = state.xrayContextMaterial;
    }
    state.occludedGhostIds = occludingIds;
  }
}

/**
 * Calcula a pose e enquadramento ideal da câmera 3D de acordo com a categoria semântica do elemento IFC
 */
function computeOptimalCameraPose(expressID, aspect, limitingFov) {
  const id = Number(expressID ?? state.selectedObject?.expressID);
  if (isNaN(id)) return null;

  const elemBox = getElementWorldBox(id);
  if (elemBox.isEmpty()) return null;

  const elemCenter = elemBox.getCenter(new THREE.Vector3());
  const elemSize = elemBox.getSize(new THREE.Vector3());
  const maxElemDim = Math.max(elemSize.x, elemSize.y, elemSize.z, 0.6);

  const modelCenter = getRootPivotTarget();
  const rawCat = (state.elementCategoryMap.get(id) || '').toUpperCase();
  const meta = state.elementMetaIndex.get(id);
  const sig = (meta?.sig || '').toLowerCase();

  const isWall = rawCat.includes('WALL');
  const isOpening = rawCat.includes('WINDOW') || rawCat.includes('DOOR');
  const isFixture = rawCat.includes('FLOWTERMINAL') || rawCat.includes('FURNISHING') ||
    /patente|vaso|sanit|toilet|bacia|bide|lavat|pia|chuveiro/.test(sig);
  const isColumn = rawCat.includes('COLUMN');
  const isBeam = rawCat.includes('BEAM');

  let viewDir = new THREE.Vector3();
  let distMargin = 1.65;
  let minDist = 2.0;
  let maxDist = 90.0;

  if (isWall) {
    // Paredes: Perpendicular à face principal com 18º de inclinação isométrica e 15º de elevação
    const isRunningX = elemSize.x >= elemSize.z;
    if (isRunningX) {
      const signZ = elemCenter.z >= modelCenter.z ? 1 : -1;
      viewDir.set(0.28, 0.32, signZ * 0.90).normalize();
    } else {
      const signX = elemCenter.x >= modelCenter.x ? 1 : -1;
      viewDir.set(signX * 0.90, 0.32, 0.28).normalize();
    }
    distMargin = 1.45;
    minDist = 2.2;
  } else if (isFixture) {
    // Louças / Patentes: Visão frontal limpa elevada (26º) orientada para fora da parede de fundo
    const nearest = findNearestLogicalNeighbor(id, 6.0);
    let frontDir = null;
    if (nearest && nearest.hasNeighbor && nearest.pointNeighbor) {
      frontDir = new THREE.Vector3(
        elemCenter.x - nearest.pointNeighbor.x,
        0,
        elemCenter.z - nearest.pointNeighbor.z
      );
    }
    if (!frontDir || frontDir.lengthSq() < 0.01) {
      frontDir = new THREE.Vector3(elemCenter.x - modelCenter.x, 0, elemCenter.z - modelCenter.z);
    }
    if (frontDir.lengthSq() < 0.01) {
      frontDir.set(0.707, 0, 0.707);
    } else {
      frontDir.normalize();
    }
    viewDir.set(frontDir.x * 0.88, 0.46, frontDir.z * 0.88).normalize();
    distMargin = 1.70;
    minDist = 1.6;
    maxDist = 4.8;
  } else if (isOpening) {
    // Janelas / Portas: Face livre do vão
    const isRunningX = elemSize.x >= elemSize.z;
    if (isRunningX) {
      const signZ = elemCenter.z >= modelCenter.z ? 1 : -1;
      viewDir.set(0.12, 0.22, signZ * 0.96).normalize();
    } else {
      const signX = elemCenter.x >= modelCenter.x ? 1 : -1;
      viewDir.set(signX * 0.96, 0.22, 0.12).normalize();
    }
    distMargin = 1.50;
    minDist = 1.8;
    maxDist = 18.0;
  } else {
    // Pilares, Vigas e outros: 3/4 estrutural
    let horiz = new THREE.Vector3(elemCenter.x - modelCenter.x, 0, elemCenter.z - modelCenter.z);
    if (horiz.lengthSq() < 0.04) {
      horiz.set(0.707, 0, 0.707);
    } else {
      horiz.normalize();
      const angle = 0.52;
      const rx = horiz.x * Math.cos(angle) - horiz.z * Math.sin(angle);
      const rz = horiz.x * Math.sin(angle) + horiz.z * Math.cos(angle);
      horiz.set(rx, 0, rz).normalize();
    }
    viewDir.set(horiz.x * 0.86, 0.50, horiz.z * 0.86).normalize();
    distMargin = 1.65;
    minDist = 2.0;
  }

  let dist = (maxElemDim / (2 * Math.tan(limitingFov / 2))) * distMargin;
  dist = Math.max(minDist, Math.min(dist, maxDist));

  // Testa ângulo oposto caso a visada principal esteja obstruída em paredes ou esquadrias
  if ((isWall || isOpening) && state.currentModel) {
    const primaryCamPos = elemCenter.clone().addScaledVector(viewDir, dist);
    const altViewDir = new THREE.Vector3(-viewDir.x, viewDir.y, -viewDir.z).normalize();
    const altCamPos = elemCenter.clone().addScaledVector(altViewDir, dist);

    const primaryOccluded = testSightlineHasOcclusion(elemCenter, primaryCamPos, id);
    if (primaryOccluded) {
      const altOccluded = testSightlineHasOcclusion(elemCenter, altCamPos, id);
      if (!altOccluded) {
        viewDir.copy(altViewDir);
      }
    }
  }

  const targetCamPos = elemCenter.clone().addScaledVector(viewDir, dist);
  return {
    cameraPos: targetCamPos,
    targetCenter: elemCenter,
    dist: dist,
  };
}

/**
 * Posiciona e enquadra a câmera 3D com orientação semântica e anti-obstrução para a Visualização Dinâmica.
 */
function focusElementForDynamicView(expressID, durationMs = 460) {
  if (!state.camera || !state.controls) return;

  onWindowResize();

  const id = Number(expressID ?? state.selectedObject?.expressID);
  if (isNaN(id)) return;

  const vFovRad = THREE.MathUtils.degToRad(state.camera.fov || 45);
  const aspect = Math.max(0.35, state.camera.aspect || (window.innerWidth / Math.max(1, window.innerHeight)));
  const hFovRad = 2 * Math.atan(Math.tan(vFovRad / 2) * aspect);
  const limitingFov = Math.min(vFovRad, hFovRad);

  const pose = computeOptimalCameraPose(id, aspect, limitingFov);
  if (!pose) return;

  state.camera.near = Math.max(0.05, Math.min(0.4, pose.dist * 0.04));
  state.camera.updateProjectionMatrix();

  // Resolve qualquer elemento que obstrua a linha de visada
  resolveSightlineOcclusions(pose.targetCenter, pose.cameraPos, id);

  // Calcula e desenha a cota de proximidade em 3D (raio <= 6m)
  const proximityData = findNearestLogicalNeighbor(id, 6.0);
  state.lastProximityData = proximityData;
  renderProximityDimensionLine(proximityData);

  // Anima a câmera para a posição ideal
  state.isElementPivotActive = true;
  state.activePivotElementId = id;
  animateCameraTo(pose.cameraPos, pose.targetCenter, durationMs);

  if (_dynamicResizeTimer) clearTimeout(_dynamicResizeTimer);
  _dynamicResizeTimer = setTimeout(() => {
    _dynamicResizeTimer = null;
    if (!state.camera || !state.controls) return;
    onWindowResize();
  }, 320);
}

/**
 * Seleciona programaticamente uma peça pelo seu ExpressID (ex: navegar entre 146 pilares no mesmo nível)
 * de forma estritamente serializada: bloqueia novas chamadas até concluir leitura O(1) e renderização do frame WebGL.
 */
async function selectElementByExpressId(expressID, focusCamera = true) {
  const id = Number(expressID);
  if (isNaN(id) || !state.currentModel) return false;

  if (state.isTransitioningElement) {
    notifyFlutter('onElementTransitionBusy', { expressID: id });
    return false;
  }

  state.isTransitioningElement = true;
  try {
    // Caso modelo IFC
    if (state.ifcLoader && state.currentModel.modelID !== undefined) {
      const modelID = state.currentModel.modelID;
      const mgr = state.ifcLoader.ifcManager;

      if (state.selectedObject && !state.selectedObject.isIfc) {
        clearSelection(false, false);
      }

      const aggregate = state.parentToChildren.get(id) || state.childToParent.get(id);
      const targetID = aggregate ? aggregate.parentId : id;
      const idsToHighlight = aggregate ? aggregate.children : [targetID];

      // Atualiza o subset principal in-place sem disparar onElementDeselected nem recriar BufferGeometry
      try {
        const subset = mgr.createSubset({
          modelID: modelID,
          ids: idsToHighlight,
          scene: state.scene,
          removePrevious: true,
          material: state.highlightMaterial,
        });
        if (subset) subset.renderOrder = 2;
      } catch (e) {}

      state.selectedObject = {
        modelID: modelID,
        expressID: targetID,
        subIds: idsToHighlight,
        isComposite: Boolean(aggregate),
        isIfc: true,
      };

      const psetsFormatted = {};
      if (aggregate) {
        psetsFormatted['Composição do Elemento'] = {
          'Estrutura': 'Elemento Composto (Hierarquia Revit)',
          'Total de Partes': `${aggregate.children.length} peças agregadas`,
          'IDs dos Componentes': aggregate.children.join(', '),
        };
      }

      const payload = await enrichIfcElementPayload(
        modelID,
        targetID,
        `Elemento BIM #${targetID}`,
        aggregate ? aggregate.type : 'IfcBuildingElement',
        psetsFormatted,
        idsToHighlight,
        Boolean(aggregate)
      );

      // Reaplica destaque de peças similares apenas quando ativo
      if (state.similarHighlightedIds && state.similarHighlightedIds.length > 0) {
        highlightSimilarElements(state.similarHighlightedIds, targetID);
      }
      if (state.isDynamicXrayActive) {
        const keep = state.similarHighlightedIds.length > 0 ? state.similarHighlightedIds : [targetID];
        setDynamicXrayContext(true, keep);
      }

      if (focusCamera) {
        focusElementForDynamicView(targetID, 320);
      }

      // Aguarda o frame WebGL ser efetivamente desenhado na GPU antes de destravar nova transição
      await waitForNextRenderedFrame();

      notifyFlutter('onElementSelected', {
        ...payload,
        alreadyFocusedInJs: Boolean(focusCamera),
      });
      return true;
    }

    // Fallback GLTF
    let targetMesh = null;
    state.currentModel.traverse((child) => {
      if (child.isMesh && (child.userData.expressID === id || child.id === id)) {
        targetMesh = child;
      }
    });
    if (targetMesh) {
      clearSelection(false, false);
      state.selectedObject = targetMesh;
      state.originalMaterial = targetMesh.material;
      targetMesh.material = state.highlightMaterial;

      const elementName = targetMesh.name || `Elemento BIM #${id}`;
      const category = targetMesh.userData.category || deduceBimCategory(targetMesh);
      const gltfAnalytics = await computePieceStoreyAnalytics(undefined, id, elementName, category);
      const box = getElementWorldBox(id);
      const gltfDims = {};
      if (!box.isEmpty()) {
        const sz = box.getSize(new THREE.Vector3());
        gltfDims.length = Number(Math.max(sz.x, sz.z).toFixed(3));
        gltfDims.width = Number(Math.min(sz.x, sz.z).toFixed(3));
        gltfDims.height = Number(sz.y.toFixed(3));
        gltfDims.minElevation = Number(box.min.y.toFixed(3));
        gltfDims.maxElevation = Number(box.max.y.toFixed(3));
      }

      if (focusCamera) {
        focusElementForDynamicView(id, 320);
      }
      await waitForNextRenderedFrame();

      notifyFlutter('onElementSelected', {
        expressID: id,
        name: elementName,
        category: category,
        psets: targetMesh.userData.psets || {
          'Propriedades Gerais': {
            'ExpressID': id,
            'Nome': elementName,
            'Categoria IFC': category,
            'Status': 'Construído (As-Built)',
          },
        },
        geometricDimensions: gltfDims,
        analytics: gltfAnalytics,
        alreadyFocusedInJs: Boolean(focusCamera),
      });
      return true;
    }
    return false;
  } finally {
    state.isTransitioningElement = false;
  }
}

/**
 * Destaca em Verde Esmeralda (#10B981) todas as peças similares do nível selecionado no 3D,
 * atualizando o subset in-place e evitando reconstrução redundante caso a assinatura seja idêntica.
 */
function highlightSimilarElements(idsList, activeExpressID) {
  if (!Array.isArray(idsList) || idsList.length === 0 || !state.currentModel) {
    clearSimilarHighlights(true);
    return;
  }

  state.similarHighlightedIds = idsList.map(Number).filter((n) => !isNaN(n));
  const activeId = Number(activeExpressID ?? state.selectedObject?.expressID);
  const nextSignature = `${activeId}::${state.similarHighlightedIds.join(',')}`;

  if (state.similarSubsetSignature === nextSignature) {
    return;
  }

  const siblingGeometryIds = [];
  for (const rawId of state.similarHighlightedIds) {
    if (rawId === activeId) continue;
    const agg = state.parentToChildren.get(rawId) || state.childToParent.get(rawId);
    if (agg && Array.isArray(agg.children)) {
      for (const cid of agg.children) siblingGeometryIds.push(cid);
    } else {
      siblingGeometryIds.push(rawId);
    }
  }

  if (siblingGeometryIds.length === 0) {
    clearSimilarHighlights(false);
    return;
  }

  if (state.ifcLoader && state.currentModel.modelID !== undefined && state.secondaryHighlightMaterial) {
    try {
      const subset = state.ifcLoader.ifcManager.createSubset({
        modelID: state.currentModel.modelID,
        ids: siblingGeometryIds,
        scene: state.scene,
        removePrevious: true,
        material: state.secondaryHighlightMaterial,
        customID: 'SIMILAR_PIECES_SUBSET',
      });
      if (subset) subset.renderOrder = 1;
      state.similarSubsetSignature = nextSignature;
      if (typeof requestRender === 'function') requestRender(4);
    } catch (e) {
      console.warn('Falha ao criar subset de peças similares:', e);
    }
  }
}

/**
 * Remove o destaque secundário de peças similares da cena 3D com segurança de atributos WebGL.
 */
function clearSimilarHighlights(resetList = true) {
  if (resetList) {
    state.similarHighlightedIds = [];
  }
  state.similarSubsetSignature = '';
  if (typeof requestRender === 'function') requestRender(4);

  if (state.ifcLoader && state.currentModel?.modelID !== undefined && state.secondaryHighlightMaterial) {
    try {
      state.ifcLoader.ifcManager.removeSubset(
        state.currentModel.modelID,
        state.secondaryHighlightMaterial,
        'SIMILAR_PIECES_SUBSET'
      );
    } catch (e) {}
    try {
      state.ifcLoader.ifcManager.removeSubset(state.currentModel.modelID, state.secondaryHighlightMaterial);
    } catch (e) {}
  }

  if (state.scene && state.secondaryHighlightMaterial) {
    const toRemove = [];
    state.scene.traverse((child) => {
      if (child.isMesh && child !== state.currentModel && child.material === state.secondaryHighlightMaterial) {
        toRemove.push(child);
      }
    });
    for (const m of toRemove) {
      if (m.parent) m.parent.remove(m);
      if (m.geometry) {
        m.geometry.attributes = {};
        m.geometry.index = null;
        m.geometry.dispose();
      }
    }
  }
}

/**
 * Entra no modo de Visualização Dinâmica salvando o estado exato da câmera, frustum e isolamento anteriores
 * para restauração fiel quando o usuário sair do modo dinâmico.
 */
function enterDynamicViewMode(expressID) {
  state.isDynamicViewActive = true;
  if (state.camera && state.controls && !state.preDynamicViewSnapshot) {
    state.preDynamicViewSnapshot = {
      cameraPos: state.camera.position.clone(),
      controlsTarget: state.controls.target.clone(),
      cameraNear: state.camera.near,
      cameraFar: state.camera.far,
      isElementPivotActive: state.isElementPivotActive,
      activePivotElementId: state.activePivotElementId,
      selectedExpressId: state.selectedObject?.expressID ?? Number(expressID),
      isolatedElementId: state.isolatedElementId,
      isolatedElementIds: new Set(state.isolatedElementIds || []),
    };
  }
  focusElementForDynamicView(expressID, 460);
}

/**
 * Sai do modo de Visualização Dinâmica restaurando exatamente a câmera, o near/far plane,
 * o isolamento anterior, os materiais originais (sem Raio-X) e removendo destaques secundários.
 */
function exitDynamicViewMode() {
  state.isDynamicViewActive = false;
  clearSimilarHighlights(true);
  setDynamicXrayContext(false, []);
  clearProximityDimensionLine();
  restoreOccludedGhostMaterials();

  const snap = state.preDynamicViewSnapshot;
  state.preDynamicViewSnapshot = null;

  onWindowResize();

  if (snap) {
    // 1. Se o usuário navegou entre outras instâncias durante a vista dinâmica, restaura o destaque na peça original
    if (snap.selectedExpressId !== undefined &&
        state.selectedObject &&
        state.selectedObject.expressID !== snap.selectedExpressId) {
      if (state.ifcLoader && state.currentModel?.modelID !== undefined) {
        const modelID = state.currentModel.modelID;
        const agg = state.parentToChildren.get(snap.selectedExpressId) || state.childToParent.get(snap.selectedExpressId);
        const targetID = agg ? agg.parentId : snap.selectedExpressId;
        const idsToHighlight = agg ? agg.children : [targetID];
        try {
          const subset = state.ifcLoader.ifcManager.createSubset({
            modelID: modelID,
            ids: idsToHighlight,
            scene: state.scene,
            removePrevious: true,
            material: state.highlightMaterial,
          });
          if (subset) subset.renderOrder = 2;
          state.selectedObject = {
            modelID: modelID,
            expressID: targetID,
            subIds: idsToHighlight,
            isComposite: Boolean(agg),
            isIfc: true,
          };
        } catch (e) {}
      } else {
        selectElementByExpressId(snap.selectedExpressId, false);
      }
    }

    // 2. Restaura estado de isolamento caso tenha sido alterado dentro da Visualização Dinâmica
    const isolationChanged =
      state.isolatedElementId !== snap.isolatedElementId ||
      (state.isolatedElementIds?.size ?? 0) !== snap.isolatedElementIds.size;

    if (isolationChanged) {
      state.isolatedElementId = snap.isolatedElementId;
      state.isolatedElementIds = new Set(snap.isolatedElementIds);
      if (typeof updateModelVisibility === 'function') {
        updateModelVisibility();
      }
    }

    // 3. Restaura frustum (near/far), pivô e anima a câmera de volta para a posição exata anterior
    if (state.camera && state.controls) {
      state.camera.near = snap.cameraNear;
      state.camera.far = snap.cameraFar;
      state.camera.updateProjectionMatrix();

      state.isElementPivotActive = snap.isElementPivotActive;
      state.activePivotElementId = snap.activePivotElementId;
      animateCameraTo(snap.cameraPos, snap.controlsTarget, 360);

      if (_dynamicResizeTimer) clearTimeout(_dynamicResizeTimer);
      _dynamicResizeTimer = setTimeout(() => {
        _dynamicResizeTimer = null;
        onWindowResize();
      }, 320);
    }
  }
}

/**
 * Ativa/Desativa o modo Contexto Raio-X na obra: torna o restante do edifício translúcido (14% opacidade)
 * suportando tanto malha única consolidada (.IFC) quanto grupos de malhas (.GLB/.GLTF).
 */
function setDynamicXrayContext(enabled, keepExpressIds = []) {
  if (!state.currentModel) return;
  state.isDynamicXrayActive = Boolean(enabled);
  state.dynamicXrayKeepIds.clear();

  const isIfcConsolidatedMesh = Boolean(state.ifcLoader && state.currentModel.modelID !== undefined);

  if (state.isDynamicXrayActive) {
    const baseIds = Array.isArray(keepExpressIds) && keepExpressIds.length > 0
      ? keepExpressIds
      : (state.selectedObject ? [state.selectedObject.expressID] : []);

    for (const rawId of baseIds) {
      const id = Number(rawId);
      if (isNaN(id)) continue;
      state.dynamicXrayKeepIds.add(id);
      const agg = state.parentToChildren.get(id) || state.childToParent.get(id);
      if (agg && Array.isArray(agg.children)) {
        for (const cid of agg.children) state.dynamicXrayKeepIds.add(cid);
      }
    }

    if (isIfcConsolidatedMesh) {
      if (!state.currentModel.userData.savedMaterialsBeforeXray) {
        state.currentModel.userData.savedMaterialsBeforeXray = state.currentModel.material;
      }
      state.currentModel.material = state.xrayContextMaterial;
    } else {
      state.currentModel.traverse((child) => {
        if (child.isMesh) {
          const cid = child.userData.expressID || child.id;
          if (!state.dynamicXrayKeepIds.has(cid)) {
            if (!child.userData.savedMatBeforeXray) {
              child.userData.savedMatBeforeXray = child.material;
            }
            child.material = state.xrayContextMaterial;
          }
        }
      });
    }
  } else {
    if (isIfcConsolidatedMesh) {
      if (state.currentModel.userData.savedMaterialsBeforeXray) {
        state.currentModel.material = state.currentModel.userData.savedMaterialsBeforeXray;
        delete state.currentModel.userData.savedMaterialsBeforeXray;
      }
    } else {
      state.currentModel.traverse((child) => {
        if (child.isMesh && child.userData.savedMatBeforeXray) {
          child.material = child.userData.savedMatBeforeXray;
          delete child.userData.savedMatBeforeXray;
        }
      });
    }
  }
  if (typeof requestRender === 'function') requestRender(4);
}

// Exportações Globais para JS Bridge e Módulos
window.BimEngine.decodeIfcStepText = decodeIfcStepText;
window.BimEngine.waitForNextRenderedFrame = waitForNextRenderedFrame;
window.BimEngine.ensureRelationIndexes = ensureRelationIndexes;
window.BimEngine.resetBimAnalyticsState = resetBimAnalyticsState;
window.BimEngine.recordElementInstanceBounds = recordElementInstanceBounds;
window.BimEngine.getElementWorldBox = getElementWorldBox;
window.BimEngine.extractModelBimMetadataAndSpatialIndex = extractModelBimMetadataAndSpatialIndex;
window.BimEngine.buildGltfFallbackSpecs = buildGltfFallbackSpecs;
window.BimEngine.enrichIfcElementPayload = enrichIfcElementPayload;
window.BimEngine.computePieceStoreyAnalytics = computePieceStoreyAnalytics;
window.BimEngine.focusElementForDynamicView = focusElementForDynamicView;
window.BimEngine.enterDynamicViewMode = enterDynamicViewMode;
window.BimEngine.exitDynamicViewMode = exitDynamicViewMode;
window.BimEngine.selectElementByExpressId = selectElementByExpressId;
window.BimEngine.highlightSimilarElements = highlightSimilarElements;
window.BimEngine.clearSimilarHighlights = clearSimilarHighlights;
window.BimEngine.setDynamicXrayContext = setDynamicXrayContext;
window.BimEngine.createProximitySprite = createProximitySprite;
window.BimEngine.clearProximityDimensionLine = clearProximityDimensionLine;
window.BimEngine.setProximityDimensionEnabled = setProximityDimensionEnabled;
window.BimEngine.findNearestLogicalNeighbor = findNearestLogicalNeighbor;
window.BimEngine.renderProximityDimensionLine = renderProximityDimensionLine;
window.BimEngine.restoreOccludedGhostMaterials = restoreOccludedGhostMaterials;
window.BimEngine.resolveSightlineOcclusions = resolveSightlineOcclusions;
window.BimEngine.computeOptimalCameraPose = computeOptimalCameraPose;

window.decodeIfcStepText = decodeIfcStepText;
window.waitForNextRenderedFrame = waitForNextRenderedFrame;
window.ensureRelationIndexes = ensureRelationIndexes;
window.resetBimAnalyticsState = resetBimAnalyticsState;
window.recordElementInstanceBounds = recordElementInstanceBounds;
window.getElementWorldBox = getElementWorldBox;
window.extractModelBimMetadataAndSpatialIndex = extractModelBimMetadataAndSpatialIndex;
window.buildGltfFallbackSpecs = buildGltfFallbackSpecs;
window.enrichIfcElementPayload = enrichIfcElementPayload;
window.computePieceStoreyAnalytics = computePieceStoreyAnalytics;
window.focusElementForDynamicView = focusElementForDynamicView;
window.enterDynamicViewMode = enterDynamicViewMode;
window.exitDynamicViewMode = exitDynamicViewMode;
window.selectElementByExpressId = selectElementByExpressId;
window.highlightSimilarElements = highlightSimilarElements;
window.clearSimilarHighlights = clearSimilarHighlights;
window.setDynamicXrayContext = setDynamicXrayContext;
window.createProximitySprite = createProximitySprite;
window.clearProximityDimensionLine = clearProximityDimensionLine;
window.setProximityDimensionEnabled = setProximityDimensionEnabled;
window.findNearestLogicalNeighbor = findNearestLogicalNeighbor;
window.renderProximityDimensionLine = renderProximityDimensionLine;
window.restoreOccludedGhostMaterials = restoreOccludedGhostMaterials;
window.resolveSightlineOcclusions = resolveSightlineOcclusions;
window.computeOptimalCameraPose = computeOptimalCameraPose;
window.notifyViewportResized = function() {
  if (typeof onWindowResize === 'function') onWindowResize();
};

