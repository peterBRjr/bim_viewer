/**
 * ThatOpen Engine & Three.js 3D BIM Viewport - Módulo de Visibilidade (Ocultação, Isolamento e Preview Fantasma)
 */

window.BimEngine = window.BimEngine || {};

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
function hideElement(expressID) {
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
}

function showElement(expressID) {
  const id = Number(expressID);
  if (isNaN(id)) return;

  const agg = state.parentToChildren.get(id) || state.childToParent.get(id);
  const idsToShow = agg ? agg.children : [id];

  for (const showId of idsToShow) {
    state.hiddenIds.delete(showId);
  }

  updateModelVisibility();
}

function isolateElement(expressID) {
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
}

function restoreAllVisibility() {
  state.hiddenIds.clear();
  state.isolatedElementId = null;
  if (state.isolatedElementIds) {
    state.isolatedElementIds.clear();
  }
  state.isPreviewingHidden = false;
  restoreRootPivot(true);
  updateModelVisibility();
}

function previewHiddenElements(enable) {
  state.isPreviewingHidden = Boolean(enable);
  updateGhostSubset();
}

// Exportações
window.BimEngine.updateModelVisibility = updateModelVisibility;
window.BimEngine.updateGhostSubset = updateGhostSubset;
window.BimEngine.hideElement = hideElement;
window.BimEngine.showElement = showElement;
window.BimEngine.isolateElement = isolateElement;
window.BimEngine.restoreAllVisibility = restoreAllVisibility;
window.BimEngine.previewHiddenElements = previewHiddenElements;

window.updateModelVisibility = updateModelVisibility;
window.updateGhostSubset = updateGhostSubset;
window.hideElement = hideElement;
window.showElement = showElement;
window.isolateElement = isolateElement;
window.restoreAllVisibility = restoreAllVisibility;
window.previewHiddenElements = previewHiddenElements;

