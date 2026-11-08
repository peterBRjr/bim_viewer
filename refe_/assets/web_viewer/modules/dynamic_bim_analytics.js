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

/**
 * Limpa todo o índice espacial e analítico ao carregar novo modelo.
 */
function resetBimAnalyticsState() {
  state.elementBounds.clear();
  state.storeys = [];
  state.elementToStorey.clear();
  state.storeyToElements.clear();
  state.elementToType.clear();
  state.typeToElements.clear();
  state.elementMetaIndex.clear();
  state.bimProjectSpecs = null;
  state.lengthUnitScale = 0.001;
  state.isDynamicXrayActive = false;
  state.dynamicXrayKeepIds.clear();
  state.similarHighlightedIds = [];
  clearSimilarHighlights();
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
        for (const rel of typeRels) {
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
  for (const eid of uniqueCanonicalElements) {
    let cat = 'IfcBuildingElement';
    try {
      cat = mgr.getIfcType(modelID, eid) || cat;
    } catch (e) {}
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
 * Extrai especificações completas do elemento IFC (incluindo Tipo, Quantitativos Qto, Materiais,
 * Geometria Real e Contagem de Peças por Nível) seguindo boas práticas openBIM.
 */
async function enrichIfcElementPayload(modelID, targetID, baseName, baseCategory, psetsFormatted, idsToHighlight, isComposite) {
  const mgr = state.ifcLoader?.ifcManager;
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
        globalId = decodeIfcStepText(itemProps.GlobalId?.value || '');
        tag = decodeIfcStepText(itemProps.Tag?.value || '');
        predefinedType = decodeIfcStepText(itemProps.PredefinedType?.value || '');
        objectType = decodeIfcStepText(itemProps.ObjectType?.value || '');
        description = decodeIfcStepText(itemProps.Description?.value || '');

        const genGroup = psetsFormatted['Propriedades Gerais'] || {};
        if (objectType && objectType !== baseName) genGroup['ObjectType'] = objectType;
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

    // 2. Extração de IfcElementQuantity (Quantities) que o loop simples de HasProperties não lê
    try {
      const psets = await mgr.getPropertySets(modelID, targetID, true);
      if (Array.isArray(psets)) {
        for (const pset of psets) {
          const psetName = decodeIfcStepText(pset.Name?.value || 'Quantitativos BIM');
          if (Array.isArray(pset.Quantities) && pset.Quantities.length > 0) {
            const qGroup = psetsFormatted[psetName] || {};
            for (const q of pset.Quantities) {
              const qName = decodeIfcStepText(q.Name?.value || '');
              const rawVal =
                q.LengthValue?.value ??
                q.AreaValue?.value ??
                q.VolumeValue?.value ??
                q.WeightValue?.value ??
                q.CountValue?.value;
              if (qName && rawVal !== undefined) {
                let num = Number(rawVal);
                // Comprimentos em IfcQuantityLength seguem a unidade linear do arquivo
                if (q.LengthValue?.value !== undefined && isFinite(num)) {
                  num = num * state.lengthUnitScale;
                }
                qGroup[qName] = isFinite(num) ? Number(num.toFixed(3)) : decodeIfcStepText(rawVal);
              }
            }
            if (Object.keys(qGroup).length > 0) {
              psetsFormatted[psetName] = qGroup;
            }
          }
        }
      }
    } catch (e) {}

    // 3. Propriedades do Tipo (IfcTypeObject / IFCRELDEFINESBYTYPE)
    const typeInfo = state.elementToType.get(targetID);
    if (typeInfo && typeInfo.typeId) {
      try {
        const typeProps = await mgr.getItemProperties(modelID, typeInfo.typeId, true);
        if (typeProps) {
          const tGroup = {};
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
                const subGroup = tpName ? (psetsFormatted[tpName] || {}) : tGroup;
                for (const p of tpset.HasProperties) {
                  const k = decodeIfcStepText(p?.Name?.value || '');
                  const v = p?.NominalValue?.value;
                  if (k && v !== undefined && subGroup[k] === undefined) {
                    subGroup[k] = typeof v === 'number' ? Number(v.toFixed(3)) : decodeIfcStepText(v);
                  }
                }
                if (tpName && Object.keys(subGroup).length > 0) {
                  psetsFormatted[tpName] = subGroup;
                }
              }
            }
          }

          if (Object.keys(tGroup).length > 0) {
            psetsFormatted['Especificação de Tipo (openBIM)'] = tGroup;
          }
        }
      } catch (e) {}
    }

    // 4. Materiais e Camadas Construtivas (IFCRELASSOCIATESMATERIAL)
    try {
      const mats = await mgr.getMaterialsProperties(modelID, targetID, true);
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
    // Dimensões horizontais ordenadas (maior = comprimento, menor = largura/espessura) e vertical (Y = altura)
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

  // 6. Análise Quantitativa de Peças Idênticas por Nível (Storey)
  const analytics = await computePieceStoreyAnalytics(modelID, targetID, baseName, baseCategory);

  return {
    expressID: targetID,
    name: decodeIfcStepText(baseName),
    category: baseCategory,
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
}

/**
 * Calcula quantas unidades desta mesma peça/tipo existem no projeto inteiro e em cada pavimento (IfcBuildingStorey),
 * incluindo soma estimada de comprimento, área e volume por nível para tomada de decisão em obra.
 */
async function computePieceStoreyAnalytics(modelID, targetID, rawName, category) {
  const mgr = state.ifcLoader?.ifcManager;
  const hostStoreyId = state.elementToStorey.get(targetID) ?? null;
  const hostStoreyObj = state.storeys.find((s) => s.expressID === hostStoreyId);
  const hostStoreyName = hostStoreyObj ? hostStoreyObj.name : null;

  const typeInfo = state.elementToType.get(targetID);
  let matchingIds = [];
  let cleanTypeName = decodeIfcStepText(rawName || '');
  let ifcTypeClass = typeInfo?.typeIfcClass || '';

  if (typeInfo && state.typeToElements.has(typeInfo.typeKey)) {
    cleanTypeName = typeInfo.typeName || cleanTypeName;
    matchingIds = Array.from(state.typeToElements.get(typeInfo.typeKey));
  } else {
    // Fallback por assinatura normalizada Família:Tipo + Categoria IFC
    const targetSig = normalizeFamilyTypeSignature(rawName, category);
    const candidateIds = new Set([targetID]);
    for (const list of state.storeyToElements.values()) {
      for (const eid of list) candidateIds.add(eid);
    }

    for (const eid of candidateIds) {
      if (eid === targetID) {
        matchingIds.push(eid);
        continue;
      }
      let cached = state.elementMetaIndex.get(eid);
      if (!cached && mgr && modelID !== undefined) {
        try {
          const eCat = mgr.getIfcType(modelID, eid) || '';
          if (eCat.toUpperCase() !== String(category).toUpperCase()) {
            state.elementMetaIndex.set(eid, { cat: eCat, sig: '' });
            continue;
          }
          const props = await mgr.getItemProperties(modelID, eid, false);
          const eName = props?.Name?.value || props?.ObjectType?.value || '';
          cached = { cat: eCat, sig: normalizeFamilyTypeSignature(eName, eCat) };
          state.elementMetaIndex.set(eid, cached);
        } catch (e) {}
      } else if (!cached && state.currentModel && state.currentModel.modelID === undefined) {
        // GLTF fallback
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

  // Contagem da mesma categoria IFC por pavimento
  let totalCategoryInProject = 0;
  const targetCatUpper = String(category || '').toUpperCase();
  for (const st of state.storeys) {
    const key = String(st.expressID);
    const elems = state.storeyToElements.get(st.expressID) || [];
    let catCount = 0;
    for (const eid of elems) {
      let eCat = '';
      if (mgr && modelID !== undefined) {
        try {
          eCat = (mgr.getIfcType(modelID, eid) || '').toUpperCase();
        } catch (e) {}
      } else {
        eCat = targetCatUpper;
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
      const hMin = Math.min(sz.x, sz.z);
      instLen = hMax;
      // Para paredes/janelas/portas, área principal é elevação vertical (comprimento * altura); para lajes/pisos/telhados é projeção horizontal (x * z)
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

  return {
    typeName: cleanTypeName,
    ifcTypeClass: ifcTypeClass,
    hostStoreyId: hostStoreyId,
    hostStoreyName: hostStoreyName,
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
}

/**
 * Posiciona e enquadra a câmera 3D de forma inteligente sobre o elemento na obra
 * para a Visualização Dinâmica (respeitando o aspect ratio da janela esquerda).
 */
function focusElementForDynamicView(expressID, durationMs = 460) {
  if (!state.camera || !state.controls) return;

  // Atualiza tamanho do renderer caso o container tenha mudado (ex: rotação horizontal / divisória)
  onWindowResize();

  const id = Number(expressID ?? state.selectedObject?.expressID);
  if (isNaN(id)) return;

  const elemBox = getElementWorldBox(id);
  if (elemBox.isEmpty()) return;

  const elemCenter = elemBox.getCenter(new THREE.Vector3());
  const elemSize = elemBox.getSize(new THREE.Vector3());
  const maxElemDim = Math.max(elemSize.x, elemSize.y, elemSize.z, 0.6);

  // Calcula distância ideal considerando FOV vertical E horizontal (aspect ratio do painel esquerdo)
  const vFovRad = THREE.MathUtils.degToRad(state.camera.fov || 45);
  const aspect = Math.max(0.35, state.camera.aspect || (window.innerWidth / Math.max(1, window.innerHeight)));
  const hFovRad = 2 * Math.atan(Math.tan(vFovRad / 2) * aspect);
  const limitingFov = Math.min(vFovRad, hFovRad);

  // Multiplicador 1.75x mostra o elemento em destaque mantendo o contexto imediato dele na obra
  let dist = (maxElemDim / (2 * Math.tan(limitingFov / 2))) * 1.75;
  dist = Math.max(2.1, Math.min(dist, 120));

  // Ajusta near plane dinamicamente para não cortar elementos pequenos em close-up
  state.camera.near = Math.max(0.05, Math.min(0.4, dist * 0.04));
  state.camera.updateProjectionMatrix();

  // Escolhe direção de observação arquitetônica de fora da obra olhando para a peça (evita ficar atrás de paredes externas)
  const modelCenter = getRootPivotTarget();
  const outwardHoriz = new THREE.Vector3(
    elemCenter.x - modelCenter.x,
    0,
    elemCenter.z - modelCenter.z
  );

  if (outwardHoriz.lengthSq() < 0.04) {
    // Se o elemento estiver bem no centro da obra, usa ângulo isométrico clássico
    outwardHoriz.set(0.72, 0, 0.69);
  } else {
    outwardHoriz.normalize();
    // Leve rotação azimutal (~24°) para visão 3/4 tridimensional (nunca chapada 90°)
    const angle = 0.42;
    const cosA = Math.cos(angle);
    const sinA = Math.sin(angle);
    const rx = outwardHoriz.x * cosA - outwardHoriz.z * sinA;
    const rz = outwardHoriz.x * sinA + outwardHoriz.z * cosA;
    outwardHoriz.set(rx, 0, rz).normalize();
  }

  const viewDir = new THREE.Vector3(
    outwardHoriz.x * 0.86,
    0.50, // Elevação suave de 30° olhando levemente de cima para a peça na obra
    outwardHoriz.z * 0.86
  ).normalize();

  const targetCamPos = elemCenter.clone().addScaledVector(viewDir, dist);

  state.isElementPivotActive = true;
  state.activePivotElementId = id;
  animateCameraTo(targetCamPos, elemCenter, durationMs);

  // Re-sincroniza após o término da rotação da tela para landscape no Android/iOS (~300ms)
  setTimeout(() => {
    if (!state.camera || !state.controls) return;
    onWindowResize();
  }, 320);
}

/**
 * Seleciona programaticamente uma peça pelo seu ExpressID (ex: navegar entre as instâncias do mesmo nível)
 * e posiciona a câmera nela na obra.
 */
async function selectElementByExpressId(expressID, focusCamera = true) {
  const id = Number(expressID);
  if (isNaN(id) || !state.currentModel) return;

  // Caso modelo IFC
  if (state.ifcLoader && state.currentModel.modelID !== undefined) {
    const modelID = state.currentModel.modelID;
    const mgr = state.ifcLoader.ifcManager;

    clearSelection(false);

    const aggregate = state.parentToChildren.get(id) || state.childToParent.get(id);
    const targetID = aggregate ? aggregate.parentId : id;
    const idsToHighlight = aggregate ? aggregate.children : [targetID];

    try {
      mgr.createSubset({
        modelID: modelID,
        ids: idsToHighlight,
        scene: state.scene,
        removePrevious: true,
        material: state.highlightMaterial,
      });
    } catch (e) {}

    state.selectedObject = {
      modelID: modelID,
      expressID: targetID,
      subIds: idsToHighlight,
      isComposite: Boolean(aggregate),
      isIfc: true,
    };

    let name = `Elemento BIM #${targetID}`;
    let category = aggregate ? aggregate.type : 'IfcBuildingElement';
    const psetsFormatted = {};

    try {
      const itemProps = await mgr.getItemProperties(modelID, targetID, false);
      if (itemProps) {
        name = itemProps.Name?.value || itemProps.ObjectType?.value || name;
        const fullType = mgr.getIfcType(modelID, targetID);
        if (fullType) category = fullType;

        psetsFormatted['Propriedades Gerais'] = {
          'ExpressID': targetID,
          'Nome': decodeIfcStepText(name),
          'Categoria IFC': category,
          'GlobalId': itemProps.GlobalId?.value || 'N/A',
          'Tag': itemProps.Tag?.value || 'N/A',
        };
      }
    } catch (e) {}

    try {
      const psets = await mgr.getPropertySets(modelID, targetID, true);
      if (Array.isArray(psets)) {
        for (const pset of psets) {
          const psetName = decodeIfcStepText(pset.Name?.value || 'Outras Propriedades');
          const group = {};
          if (Array.isArray(pset.HasProperties)) {
            for (const prop of pset.HasProperties) {
              const propName = decodeIfcStepText(prop.Name?.value || '');
              const propVal = prop.NominalValue?.value;
              if (propName && propVal !== undefined) {
                group[propName] = typeof propVal === 'number' ? Number(propVal.toFixed(2)) : decodeIfcStepText(propVal);
              }
            }
          }
          if (Object.keys(group).length > 0) {
            psetsFormatted[psetName] = group;
          }
        }
      }
    } catch (e) {}

    const payload = await enrichIfcElementPayload(
      modelID,
      targetID,
      name,
      category,
      psetsFormatted,
      idsToHighlight,
      Boolean(aggregate)
    );

    // Reaplica destaque de peças similares caso estivesse ativo
    if (state.similarHighlightedIds && state.similarHighlightedIds.length > 0) {
      highlightSimilarElements(state.similarHighlightedIds, targetID);
    }
    if (state.isDynamicXrayActive) {
      const keep = state.similarHighlightedIds.length > 0 ? state.similarHighlightedIds : [targetID];
      setDynamicXrayContext(true, keep);
    }

    if (focusCamera) {
      focusElementForDynamicView(targetID, 420);
    }

    notifyFlutter('onElementSelected', payload);
    return;
  }

  // Fallback GLTF
  let targetMesh = null;
  state.currentModel.traverse((child) => {
    if (child.isMesh && (child.userData.expressID === id || child.id === id)) {
      targetMesh = child;
    }
  });
  if (targetMesh) {
    await selectElement({ object: targetMesh });
    if (focusCamera) focusElementForDynamicView(id, 420);
  }
}

/**
 * Destaca em Verde Esmeralda (#10B981) todas as peças similares do nível selecionado no 3D,
 * mantendo a peça ativa principal em Azul Royal (#2563EB).
 */
function highlightSimilarElements(idsList, activeExpressID) {
  clearSimilarHighlights(false);
  if (!Array.isArray(idsList) || idsList.length === 0 || !state.currentModel) {
    state.similarHighlightedIds = [];
    return;
  }

  state.similarHighlightedIds = idsList.map(Number).filter((n) => !isNaN(n));
  const activeId = Number(activeExpressID ?? state.selectedObject?.expressID);

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

  if (siblingGeometryIds.length === 0) return;

  if (state.ifcLoader && state.currentModel.modelID !== undefined && state.secondaryHighlightMaterial) {
    try {
      state.ifcLoader.ifcManager.createSubset({
        modelID: state.currentModel.modelID,
        ids: siblingGeometryIds,
        scene: state.scene,
        removePrevious: true,
        material: state.secondaryHighlightMaterial,
        customID: 'SIMILAR_PIECES_SUBSET',
      });
    } catch (e) {
      console.warn('Falha ao criar subset de peças similares:', e);
    }
  }
}

/**
 * Remove o destaque secundário de peças similares da cena 3D.
 */
function clearSimilarHighlights(resetList = true) {
  if (resetList) {
    state.similarHighlightedIds = [];
  }
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
      if (child.isMesh && child.material === state.secondaryHighlightMaterial) {
        toRemove.push(child);
      }
    });
    for (const m of toRemove) {
      if (m.parent) m.parent.remove(m);
      if (m.geometry) m.geometry.dispose();
    }
  }
}

/**
 * Ativa/Desativa o modo Contexto Raio-X na obra: torna o restante do edifício translúcido (14% opacidade)
 * para enxergar claramente onde a peça (e suas irmãs do pavimento) estão posicionadas por dentro da obra!
 */
function setDynamicXrayContext(enabled, keepExpressIds = []) {
  if (!state.currentModel) return;
  state.isDynamicXrayActive = Boolean(enabled);
  state.dynamicXrayKeepIds.clear();

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

    if (!state.currentModel.userData.savedMaterialsBeforeXray) {
      state.currentModel.userData.savedMaterialsBeforeXray = state.currentModel.material;
    }
    state.currentModel.material = state.xrayContextMaterial;
  } else {
    if (state.currentModel.userData.savedMaterialsBeforeXray) {
      state.currentModel.material = state.currentModel.userData.savedMaterialsBeforeXray;
      delete state.currentModel.userData.savedMaterialsBeforeXray;
    }
  }
}

// Exportações Globais para JS Bridge e Módulos
window.BimEngine.decodeIfcStepText = decodeIfcStepText;
window.BimEngine.resetBimAnalyticsState = resetBimAnalyticsState;
window.BimEngine.recordElementInstanceBounds = recordElementInstanceBounds;
window.BimEngine.getElementWorldBox = getElementWorldBox;
window.BimEngine.extractModelBimMetadataAndSpatialIndex = extractModelBimMetadataAndSpatialIndex;
window.BimEngine.buildGltfFallbackSpecs = buildGltfFallbackSpecs;
window.BimEngine.enrichIfcElementPayload = enrichIfcElementPayload;
window.BimEngine.computePieceStoreyAnalytics = computePieceStoreyAnalytics;
window.BimEngine.focusElementForDynamicView = focusElementForDynamicView;
window.BimEngine.selectElementByExpressId = selectElementByExpressId;
window.BimEngine.highlightSimilarElements = highlightSimilarElements;
window.BimEngine.clearSimilarHighlights = clearSimilarHighlights;
window.BimEngine.setDynamicXrayContext = setDynamicXrayContext;

window.decodeIfcStepText = decodeIfcStepText;
window.resetBimAnalyticsState = resetBimAnalyticsState;
window.recordElementInstanceBounds = recordElementInstanceBounds;
window.getElementWorldBox = getElementWorldBox;
window.extractModelBimMetadataAndSpatialIndex = extractModelBimMetadataAndSpatialIndex;
window.buildGltfFallbackSpecs = buildGltfFallbackSpecs;
window.enrichIfcElementPayload = enrichIfcElementPayload;
window.computePieceStoreyAnalytics = computePieceStoreyAnalytics;
window.focusElementForDynamicView = focusElementForDynamicView;
window.selectElementByExpressId = selectElementByExpressId;
window.highlightSimilarElements = highlightSimilarElements;
window.clearSimilarHighlights = clearSimilarHighlights;
window.setDynamicXrayContext = setDynamicXrayContext;
window.notifyViewportResized = onWindowResize;

