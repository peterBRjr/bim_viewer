/**
 * ThatOpen Engine & Three.js 3D BIM Viewport - Módulo de Plano de Corte Horizontal (Section Cut)
 */

window.BimEngine = window.BimEngine || {};

/**
 * Controle de Plano de Corte Horizontal em Tempo Real (Section Analysis estilo BIM 360 / Fusion)
 * @param {boolean} enabled Ativa ou desativa o plano de corte
 * @param {number} ratio Percentual da altura da edificação (0.05 a 1.0)
 */
function setSectionCut(enabled, ratio = 1.0) {
  state.isSectionActive = Boolean(enabled);
  state.sectionRatio = Math.min(1.0, Math.max(0.02, Number(ratio) || 1.0));

  if (!state.renderer) return;

  if (!state.isSectionActive || !state.currentModel) {
    state.renderer.clippingPlanes = [];
    if (typeof requestRender === 'function') requestRender(4);
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
  if (typeof requestRender === 'function') requestRender(4);
}

// Exportações
window.BimEngine.setSectionCut = setSectionCut;
window.setSectionCut = setSectionCut;

