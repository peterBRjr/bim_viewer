/**
 * ThatOpen Engine & Three.js 3D BIM Viewport - Módulo de Seleção, Raycasting e Hierarquia BIM
 */

window.BimEngine = window.BimEngine || {};

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
 * Aplica destaque visual e extrai metadados do elemento selecionado (IFC ou GLTF)
 * com bloqueio mútuo para impedir leituras WASM e subsets concorrentes.
 */
async function selectElement(hit) {
  if (state.isTransitioningElement) return;
  const object = hit?.object;
  if (!object) return;

  state.isTransitioningElement = true;
  try {
    // 1. Caso o modelo seja IFC nativo (possua modelID e expressID)
    if (state.ifcLoader && object.modelID !== undefined && hit.faceIndex !== undefined) {
      try {
        const expressID = state.ifcLoader.ifcManager.getExpressId(object.geometry, hit.faceIndex);
        if (expressID !== undefined && expressID !== null && expressID >= 0) {
          // Se a seleção anterior era uma malha avulsa GLTF, limpa apenas o material dela sem emitir deseleção
          if (state.selectedObject && !state.selectedObject.isIfc) {
            clearSelection(false, false);
          }

          // Verifica se o elemento clicado pertence a uma agregação pai (Padrão Revit: IfcRoof -> IfcSlab)
          const aggregate = state.childToParent.get(expressID);
          const targetID = aggregate ? aggregate.parentId : expressID;
          const idsToHighlight = aggregate ? aggregate.children : [expressID];

          // Aplica destaque em todas as geometrias do elemento composto (atualiza subset in-place)
          const subset = state.ifcLoader.ifcManager.createSubset({
            modelID: object.modelID,
            ids: idsToHighlight,
            scene: state.scene,
            removePrevious: true,
            material: state.highlightMaterial
          });
          if (subset) subset.renderOrder = 2;

          // Configura o eixo de navegação com os dedos baseado no elemento selecionado
          let pivotPoint = null;
          if (typeof getElementWorldBox === 'function') {
            const wBox = getElementWorldBox(targetID);
            if (!wBox.isEmpty()) {
              pivotPoint = wBox.getCenter(new THREE.Vector3());
            }
          }
          if (!pivotPoint) {
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

          // Extrai propriedades básicas da linha principal em O(1)
          let name = `Elemento BIM #${targetID}`;
          let category = aggregate ? aggregate.type : 'IfcBuildingElement';
          const psetsFormatted = {};

          try {
            const itemProps = await state.ifcLoader.ifcManager.getItemProperties(object.modelID, targetID, false);
            if (itemProps) {
              name = itemProps.Name?.value || itemProps.ObjectType?.value || name;
              try {
                const fullType = state.ifcLoader.ifcManager.getIfcType(object.modelID, targetID);
                if (fullType) category = fullType;
              } catch (e) {}

              psetsFormatted["Propriedades Gerais"] = {
                "ExpressID": targetID,
                "Nome": typeof decodeIfcStepText === 'function' ? decodeIfcStepText(name) : name,
                "Categoria IFC": category,
                "GlobalId": itemProps.GlobalId?.value || "N/A",
                "Tag": itemProps.Tag?.value || "N/A"
              };
            }
          } catch (e) {
            console.warn('Erro ao ler propriedades básicas do item:', e);
          }

          // Se for um elemento composto com agregação, adiciona ficha de composição
          if (aggregate) {
            psetsFormatted["Composição do Elemento"] = {
              "Estrutura": "Elemento Composto (Hierarquia Revit)",
              "Total de Partes": `${aggregate.children.length} peças agregadas`,
              "IDs dos Componentes": aggregate.children.join(", ")
            };
          }

          // Enriquecimento openBIM O(1) indexado: Psets, Qto, Tipo, Materiais, Dimensões 3D e Quantitativo por Pavimento
          if (typeof enrichIfcElementPayload === 'function') {
            const richPayload = await enrichIfcElementPayload(
              object.modelID,
              targetID,
              name,
              category,
              psetsFormatted,
              idsToHighlight,
              Boolean(aggregate)
            );
            if (state.similarHighlightedIds && state.similarHighlightedIds.length > 0 && typeof highlightSimilarElements === 'function') {
              highlightSimilarElements(richPayload.analytics?.allInstanceIds || [], targetID);
            }
            if (typeof waitForNextRenderedFrame === 'function') {
              await waitForNextRenderedFrame();
            }
            notifyFlutter('onElementSelected', richPayload);
            return;
          }

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

    clearSelection(false, false);

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

    let gltfAnalytics = null;
    let gltfDims = {};
    if (typeof computePieceStoreyAnalytics === 'function') {
      try {
        gltfAnalytics = await computePieceStoreyAnalytics(undefined, expressID, elementName, category);
        const box = getElementWorldBox(expressID);
        if (!box.isEmpty()) {
          const sz = box.getSize(new THREE.Vector3());
          gltfDims = {
            length: Number(Math.max(sz.x, sz.z).toFixed(3)),
            width: Number(Math.min(sz.x, sz.z).toFixed(3)),
            height: Number(sz.y.toFixed(3)),
            minElevation: Number(box.min.y.toFixed(3)),
            maxElevation: Number(box.max.y.toFixed(3)),
          };
        }
      } catch (e) {}
    }

    if (typeof waitForNextRenderedFrame === 'function') {
      await waitForNextRenderedFrame();
    }

    notifyFlutter('onElementSelected', {
      expressID: expressID,
      name: elementName,
      category: category,
      psets: psets,
      geometricDimensions: gltfDims,
      analytics: gltfAnalytics,
    });
  } finally {
    state.isTransitioningElement = false;
  }
}

/**
 * Remove o destaque azul do elemento e notifica deseleção para o Flutter (quando aplicável)
 */
function clearSelection(restorePivot = true, notifyDeselect = true) {
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

  // Restaura qualquer malha que tenha userData.originalMaterial (apenas em modelos não-IFC consolidados)
  if (state.currentModel && state.currentModel.modelID === undefined) {
    state.currentModel.traverse((child) => {
      if (child.isMesh && child.userData.originalMaterial) {
        child.material = child.userData.originalMaterial;
        delete child.userData.originalMaterial;
      }
    });
  }

  // 3. Limpeza defensiva segura da cena sem descartar BufferAttributes compartilhados do modelo principal
  if (state.scene && state.highlightMaterial) {
    const toRemove = [];
    state.scene.traverse((child) => {
      if (child.isMesh && child !== state.currentModel && (
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
        mesh.geometry.attributes = {};
        mesh.geometry.index = null;
        mesh.geometry.dispose();
      }
    }
  }

  state.selectedObject = null;
  state.originalMaterial = null;
  if (restorePivot && state.isElementPivotActive) {
    restoreRootPivot(true);
  }
  if (notifyDeselect) {
    notifyFlutter('onElementDeselected');
  }
}

// Exportações
window.BimEngine.buildHierarchyMaps = buildHierarchyMaps;
window.BimEngine.deduceBimCategory = deduceBimCategory;
window.BimEngine.selectElement = selectElement;
window.BimEngine.clearSelection = clearSelection;

window.buildHierarchyMaps = buildHierarchyMaps;
window.deduceBimCategory = deduceBimCategory;
window.selectElement = selectElement;
window.clearSelection = clearSelection;

