/**
 * ThatOpen Engine & Three.js 3D BIM Viewport - Módulo de Câmera, OrbitControls e Pivô Dinâmico
 */

window.BimEngine = window.BimEngine || {};

/**
 * Inicializa a Câmera Perspectiva Técnica e Controles de Órbita com Damping
 */
function initCameraAndControls(container) {
  const aspect = window.innerWidth / window.innerHeight;
  state.camera = new THREE.PerspectiveCamera(45, aspect, 0.1, 1000);
  state.camera.position.copy(state.initialCameraPos);

  state.controls = new THREE.OrbitControls(state.camera, state.renderer.domElement);
  state.controls.enableDamping = true;
  state.controls.dampingFactor = 0.08;
  state.controls.screenSpacePanning = true;
  state.controls.minDistance = 0.5;
  state.controls.maxDistance = 500;
  state.controls.target.copy(state.initialCameraTarget);

  // Cancela animações em curso imediatamente ao toque para dar resposta instantânea ao usuário
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
function resetCamera() {
  if (!state.camera || !state.controls) return;
  if (state.pivotAnimFrame) {
    cancelAnimationFrame(state.pivotAnimFrame);
    state.pivotAnimFrame = null;
  }
  state.isElementPivotActive = false;
  state.activePivotElementId = null;
  animateCameraTo(state.initialCameraPos, state.initialCameraTarget, 340);
}

/**
 * Vistas Predefinidas estilo ViewCube Autodesk Fusion / BIM 360 ('iso', 'top', 'front', 'right', 'left', 'back')
 */
function setCameraView(viewName) {
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
    resetCamera();
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
}

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

// Exportações
window.BimEngine.initCameraAndControls = initCameraAndControls;
window.BimEngine.getRootPivotTarget = getRootPivotTarget;
window.BimEngine.animatePivotTo = animatePivotTo;
window.BimEngine.setElementPivot = setElementPivot;
window.BimEngine.restoreRootPivot = restoreRootPivot;
window.BimEngine.animateCameraTo = animateCameraTo;
window.BimEngine.resetCamera = resetCamera;
window.BimEngine.setCameraView = setCameraView;
window.BimEngine.fitModelToFrame = fitModelToFrame;

window.initCameraAndControls = initCameraAndControls;
window.getRootPivotTarget = getRootPivotTarget;
window.animatePivotTo = animatePivotTo;
window.setElementPivot = setElementPivot;
window.restoreRootPivot = restoreRootPivot;
window.animateCameraTo = animateCameraTo;
window.resetCamera = resetCamera;
window.setCameraView = setCameraView;
window.fitModelToFrame = fitModelToFrame;

