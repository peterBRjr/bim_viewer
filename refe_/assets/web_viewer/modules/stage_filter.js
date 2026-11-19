/**
 * ThatOpen Engine & Three.js 3D BIM Viewport - Módulo de Filtro por Etapas da Obra
 * Classifica e isola elementos em:
 * 1. Fundação (Sapatas, Blocos, Estacas, Baldrames, Radiers)
 * 2. Pré-Moldado (Pilares, Vigas, Lajes alveolares, Painéis de concreto pré-fabricado)
 * 3. Estrutura Metálica (Tesouras, Treliças, Terças metálicas, Contraventamentos, Chapas/Gussets)
 */

window.BimEngine = window.BimEngine || {};

// Inicializa estado no state global
state.stageToElements = {
  foundation: new Set(),
  precast: new Set(),
  steel: new Set(),
  other: new Set(),
};
state.elementToStage = new Map();
state.activeStageFilters = {
  foundation: true,
  precast: true,
  steel: true,
  other: true,
};

/**
 * Limpa o índice de etapas ao carregar um novo modelo
 */
function resetStageFilterState() {
  state.stageToElements.foundation.clear();
  state.stageToElements.precast.clear();
  state.stageToElements.steel.clear();
  state.stageToElements.other.clear();
  state.elementToStage.clear();
  state.activeStageFilters = {
    foundation: true,
    precast: true,
    steel: true,
    other: true,
  };
}

/**
 * Classificador Heurístico em 4 Camadas para Etapas da Obra (openBIM / IFC / Industrial Sheds)
 */
function classifyElementStage(expressId, category, name, typeName, materialName, storeyName, elevation, bbox) {
  const cat = String(category || '').toUpperCase().trim();
  const n = String(name || '').toLowerCase();
  const t = String(typeName || '').toLowerCase();
  const mat = String(materialName || '').toLowerCase();
  const st = String(storeyName || '').toLowerCase();
  const fullText = `${cat} ${n} ${t} ${mat} ${st}`;

  // =========================================================================
  // CAMADA 1: Entidades Nativas IFC Inequívocas
  // =========================================================================
  if (cat.includes('FOOTING') || cat.includes('PILE') || cat.includes('DEEPFOUNDATION')) {
    return 'foundation';
  }
  if (cat.includes('PLATE') || cat.includes('FASTENER') || cat.includes('MECHANICALFASTENER') || cat.includes('DISCRETEACCESSORY')) {
    return 'steel';
  }

  // =========================================================================
  // CAMADA 2: Regex Semântico Específico de Fundação (Sapatas, Estacas, Baldrame)
  // =========================================================================
  const foundationRegex = /\b(sapata|bloco|estaca|baldrame|radier|c[aá]lice|tubul[aã]o|footing|pile|grade[- ]?beam|fundac[aã]o|fundação|subsolo)\b/i;
  if (foundationRegex.test(fullText)) {
    return 'foundation';
  }

  // Se o pavimento for expressamente de fundação/subsolo e o elemento for estrutural concreto
  if ((st.includes('fund') || st.includes('baldrame') || st.includes('subsolo')) &&
      (cat.includes('BEAM') || cat.includes('COLUMN') || cat.includes('SLAB'))) {
    return 'foundation';
  }

  // =========================================================================
  // CAMADA 3: Regex Semântico de Estrutura Metálica (Aço, Perfis, Treliças, Terças)
  // =========================================================================
  const steelRegex = /\b(treli[cç]a|tesoura|ter[cç]a(\s+met[aá]lica)?|contraventamento|tirante|gusset|chapa(\s+de\s+liga[cç][aã]o)?|banzo|diagonal|montante|platibanda|telha(\s+met[aá]lica)?|calha(\s+met[aá]lica)?|aço|aco|steel|astm|metal|perfil(\s+met[aá]lico|\s+[whuic]|[- ][whuic])|viga(\s+[whuic]|[- ][whuic])|pilar(\s+[whuic]|[- ][whuic]))\b/i;
  
  // Se o material é expressamente aço ou o texto contém termos metálicos
  const isSteelMaterial = mat.includes('aço') || mat.includes('aco') || mat.includes('steel') || mat.includes('metal') || mat.includes('astm');
  if (isSteelMaterial || steelRegex.test(fullText)) {
    return 'steel';
  }

  // =========================================================================
  // CAMADA 4: Regex Semântico de Pré-Moldado (Concreto Pré-fabricado, Pilares, Vigas)
  // =========================================================================
  const precastRegex = /\b(pr[eé][- ]?moldado|precast|alveolar|painel(\s+alveolar|\s+de\s+concreto)?|consolo|m[ií]sula|pilar(\s+pr[eé]|[- ]pr[eé])|viga(\s+pr[eé]|[- ]pr[eé])|calha(\s+pr[eé]|[- ]pr[eé])|ter[cç]a(\s+de\s+concreto|\s+conc)|placa(\s+pr[eé])?)\b/i;
  const isConcreteMaterial = mat.includes('concreto') || mat.includes('concrete') || mat.includes('c25') || mat.includes('c30') || mat.includes('c35') || mat.includes('c40') || mat.includes('c50') || mat.includes('fck');

  if (precastRegex.test(fullText)) {
    return 'precast';
  }

  // Elementos estruturais de concreto acima do solo em galpões industriais
  if (isConcreteMaterial && (cat.includes('COLUMN') || cat.includes('BEAM') || cat.includes('SLAB') || cat.includes('WALL') || cat.includes('MEMBER'))) {
    // Se cota de elevação <= 0.05 e for laje ou viga de fundação, atribui à fundação
    if (elevation !== undefined && elevation <= 0.05 && (cat.includes('SLAB') || n.includes('viga'))) {
      return 'foundation';
    }
    return 'precast';
  }

  // Fallback por Entidade e Cota
  if (cat.includes('COLUMN') || cat.includes('BEAM') || cat.includes('SLAB') || cat.includes('WALL')) {
    if (elevation !== undefined && elevation <= 0.0) {
      return 'foundation';
    }
    return 'precast';
  }

  if (cat.includes('MEMBER') || cat.includes('ROOF') || cat.includes('COVERING')) {
    return 'steel';
  }

  return 'other';
}

/**
 * Constrói o índice espacial de etapas e notifica o Flutter via JS Bridge
 */
async function buildConstructionStageIndex(modelID) {
  resetStageFilterState();

  const uniqueElements = new Set();
  for (const list of state.storeyToElements.values()) {
    for (const eid of list) uniqueElements.add(eid);
  }
  if (uniqueElements.size === 0) {
    for (const eid of state.elementBounds.keys()) {
      const p = state.childToParent.get(eid);
      uniqueElements.add(p ? p.parentId : eid);
    }
  }

  let processed = 0;
  for (const eid of uniqueElements) {
    if (++processed % 250 === 0) {
      await new Promise((r) => setTimeout(r, 0));
    }

    const cat = state.elementCategoryMap.get(eid) || '';
    const typeInfo = state.elementToType.get(eid);
    const typeName = typeInfo ? typeInfo.typeName : '';
    const storeyId = state.elementToStorey.get(eid);
    let storeyName = '';
    let elevation = 0;
    if (storeyId) {
      const stObj = state.storeys.find((s) => s.expressID === storeyId);
      if (stObj) {
        storeyName = stObj.name;
        elevation = stObj.elevationMeters;
      }
    }
    const bbox = state.elementBounds.get(eid);

    // Nome individual do elemento
    let elementName = '';
    if (state.ifcLoader && modelID !== undefined) {
      try {
        const line = await state.ifcLoader.ifcManager.getItemProperties(modelID, eid, false);
        if (line && line.Name?.value) {
          elementName = decodeIfcStepText(line.Name.value);
        }
      } catch (e) {}
    }

    const stage = classifyElementStage(eid, cat, elementName, typeName, '', storeyName, elevation, bbox);
    state.elementToStage.set(eid, stage);
    if (state.stageToElements[stage]) {
      state.stageToElements[stage].add(eid);
    }

    // Propaga classificação para filhos de agregação
    const agg = state.parentToChildren.get(eid);
    if (agg && Array.isArray(agg.children)) {
      for (const cid of agg.children) {
        state.elementToStage.set(cid, stage);
        if (state.stageToElements[stage]) {
          state.stageToElements[stage].add(cid);
        }
      }
    }
  }

  const summary = {
    foundationCount: state.stageToElements.foundation.size,
    precastCount: state.stageToElements.precast.size,
    steelCount: state.stageToElements.steel.size,
    otherCount: state.stageToElements.other.size,
    totalCount: uniqueElements.size,
  };

  console.log('[StageFilter] Etapas indexadas com sucesso:', summary);
  notifyFlutter('onConstructionStagesLoaded', summary);
}

/**
 * Aplica o filtro de visibilidade das 3 etapas no modelo 3D
 */
function setConstructionStageFilter(filter) {
  if (!filter || typeof filter !== 'object') return;

  const showFoundation = filter.showFoundation !== false;
  const showPrecast = filter.showPrecast !== false;
  const showSteel = filter.showSteel !== false;
  const showOther = filter.showOther !== false;
  const autoFocusFoundation = Boolean(filter.autoFocusFoundation);

  state.activeStageFilters = {
    foundation: showFoundation,
    precast: showPrecast,
    steel: showSteel,
    other: showOther,
  };

  const isAllActive = showFoundation && showPrecast && showSteel && showOther;
  const isAllInactive = !showFoundation && !showPrecast && !showSteel && !showOther;

  if (isAllActive || isAllInactive) {
    if (state.isolatedElementIds) {
      state.isolatedElementIds.clear();
    }
    state.isolatedElementId = null;
    updateModelVisibility();
    return;
  }

  const allowedIds = new Set();
  if (showFoundation) {
    for (const id of state.stageToElements.foundation) allowedIds.add(id);
  }
  if (showPrecast) {
    for (const id of state.stageToElements.precast) allowedIds.add(id);
  }
  if (showSteel) {
    for (const id of state.stageToElements.steel) allowedIds.add(id);
  }
  if (showOther) {
    for (const id of state.stageToElements.other) allowedIds.add(id);
  }

  state.isolatedElementIds = allowedIds;
  state.isolatedElementId = null;
  updateModelVisibility();

  // Se apenas a fundação estiver visível e solicitado enquadramento, foca na fundação sob o solo
  if (showFoundation && !showPrecast && !showSteel && autoFocusFoundation) {
    focusFoundationView();
  }
}

/**
 * Enquadra a câmera especificamente na fundação no nível do solo
 */
function focusFoundationView() {
  if (!state.currentModel || state.stageToElements.foundation.size === 0) return;

  const box = new THREE.Box3();
  for (const id of state.stageToElements.foundation) {
    const b = state.elementBounds.get(id);
    if (b) {
      box.expandByPoint(new THREE.Vector3(b[0], b[1], b[2]));
      box.expandByPoint(new THREE.Vector3(b[3], b[4], b[5]));
    }
  }

  if (box.isEmpty()) return;

  const center = new THREE.Vector3();
  const size = new THREE.Vector3();
  box.getCenter(center);
  box.getSize(size);

  const maxDim = Math.max(size.x, size.y, size.z, 5);
  const fov = (state.camera?.fov || 45) * (Math.PI / 180);
  const distance = Math.abs(maxDim / Math.sin(fov / 2)) * 0.75;

  const targetPos = new THREE.Vector3(
    center.x + distance * 0.75,
    center.y + distance * 0.55,
    center.z + distance * 0.75
  );

  if (typeof animateCameraTo === 'function') {
    animateCameraTo(targetPos, center, 450);
  } else if (state.camera && state.controls) {
    state.camera.position.copy(targetPos);
    state.controls.target.copy(center);
    state.controls.update();
  }
}

// Exportações Globais
window.BimEngine.classifyElementStage = classifyElementStage;
window.BimEngine.buildConstructionStageIndex = buildConstructionStageIndex;
window.BimEngine.setConstructionStageFilter = setConstructionStageFilter;
window.BimEngine.focusFoundationView = focusFoundationView;
window.BimEngine.resetStageFilterState = resetStageFilterState;

window.setConstructionStageFilter = setConstructionStageFilter;
window.focusFoundationView = focusFoundationView;

