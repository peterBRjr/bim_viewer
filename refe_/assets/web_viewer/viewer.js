/**
 * ThatOpen Engine & Three.js 3D BIM Viewport - Orquestrador Principal e Ponto de Entrada
 * Conecta os módulos de renderização, câmera, seleção, medições e carregadores com a JS Bridge do Flutter.
 */

window.BimEngine = window.BimEngine || {};

/**
 * Inicializa a Engine WebGL, Câmera, Luzes, Controles de Órbita e Parser IFC.
 */
function initEngine() {
  const container = document.getElementById('viewer-container');
  if (!container) {
    console.error('Container de renderização 3D não encontrado.');
    return;
  }

  // 1. Inicializa cena, iluminação e materiais
  initScene(container);

  // 2. Inicializa câmera e OrbitControls
  initCameraAndControls(container);

  // 3. Inicializa parser IFC com WebAssembly
  initIfcEngine();

  // 4. Registra ouvintes de redimensionamento, bloqueio de gestos nativos do WebKit e toque/clique
  window.addEventListener('resize', onWindowResize);
  const domEl = state.renderer.domElement;
  domEl.addEventListener('pointerdown', onPointerDown);
  domEl.addEventListener('pointerup', onPointerUp);
  domEl.addEventListener('pointercancel', onPointerCancel);
  window.addEventListener('blur', resetPointerTracking);

  // Bloqueia interceptação nativa de pinça/rotação do iOS WKWebView/Safari para entregar 100% dos 2 dedos ao WebGL
  const preventNativeGesture = (e) => e.preventDefault();
  document.addEventListener('gesturestart', preventNativeGesture, { passive: false });
  document.addEventListener('gesturechange', preventNativeGesture, { passive: false });
  document.addEventListener('gestureend', preventNativeGesture, { passive: false });
  domEl.addEventListener('dblclick', preventNativeGesture, { passive: false });

  // 5. Inicia o loop de animação contínuo
  animate();

  // 6. Notifica o Flutter que a Viewport 3D está pronta para carregar projetos
  notifyFlutter('onViewerReady');
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
 * Loop contínuo de renderização a 60 FPS com damping
 */
function animate() {
  requestAnimationFrame(animate);
  if (state.controls) state.controls.update();
  if (state.renderer && state.scene && state.camera) {
    state.renderer.render(state.scene, state.camera);
  }
}

/**
 * Limpa rastreamento de ponteiros ativos (ex.: perda de foco ou cancelamento do SO)
 */
function resetPointerTracking() {
  state.activePointers.clear();
  state.multiTouchGestureOccurred = false;
  state.pointerDownPos = null;
}

/**
 * Cancelamento de ponteiro (notificação do sistema, gesto multitouch abortado)
 */
function onPointerCancel(event) {
  state.activePointers.delete(event.pointerId);
  if (state.activePointers.size === 0) {
    state.multiTouchGestureOccurred = false;
  }
  state.pointerDownPos = null;
}

/**
 * Registro de início de clique/toque com bloqueio contra falso clique em gestos de 2 dedos
 */
function onPointerDown(event) {
  state.activePointers.add(event.pointerId);

  if (state.activePointers.size > 1) {
    state.multiTouchGestureOccurred = true;
    state.pointerDownPos = null;
    return;
  }

  if (!state.multiTouchGestureOccurred) {
    state.pointerDownPos = {
      x: event.clientX,
      y: event.clientY,
      time: Date.now(),
      pointerId: event.pointerId,
    };
  }
}

/**
 * Processamento de seleção por Raycaster (apenas se for toque simples de 1 dedo, sem arrasto nem multi-touch)
 */
async function onPointerUp(event) {
  state.activePointers.delete(event.pointerId);

  // Se houve gesto de 2+ dedos, ignora seleção até todos os dedos saírem da tela
  if (state.multiTouchGestureOccurred) {
    if (state.activePointers.size === 0) {
      state.multiTouchGestureOccurred = false;
    }
    state.pointerDownPos = null;
    return;
  }

  if (!state.pointerDownPos || state.pointerDownPos.pointerId !== event.pointerId) return;

  const deltaX = Math.abs(event.clientX - state.pointerDownPos.x);
  const deltaY = Math.abs(event.clientY - state.pointerDownPos.y);
  const deltaTime = Date.now() - (state.pointerDownPos.time || 0);
  const isTouch = event.pointerType === 'touch';
  const maxDelta = isTouch ? 18 : 10;

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

// Inicialização imediata ao carregar o DOM
window.addEventListener('DOMContentLoaded', () => {
  initEngine();
});

// Exportações
window.BimEngine.initEngine = initEngine;
window.initEngine = initEngine;
