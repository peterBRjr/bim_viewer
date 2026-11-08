/**
 * ThatOpen Engine & Three.js 3D BIM Viewport - Módulo de Medição 3D e Vãos Livres (Clear Spans)
 */

window.BimEngine = window.BimEngine || {};

/**
 * Cria um marcador temporário com efeito pulsante no ponto A
 */
function createPendingMarker(point) {
  removePendingMarker();

  const group = new THREE.Group();
  group.position.copy(point);

  const sphereGeom = new THREE.SphereGeometry(0.06, 16, 16);
  const sphereMat = new THREE.MeshBasicMaterial({ color: 0xF59E0B });
  const sphere = new THREE.Mesh(sphereGeom, sphereMat);
  group.add(sphere);

  const ringGeom = new THREE.RingGeometry(0.08, 0.12, 32);
  const ringMat = new THREE.MeshBasicMaterial({ color: 0xFBBF24, side: THREE.DoubleSide });
  const ring = new THREE.Mesh(ringGeom, ringMat);
  ring.rotation.x = Math.PI / 2;
  group.add(ring);

  state.pendingMeasureMarker = group;
  state.scene.add(group);
}

/**
 * Remove o marcador temporário de ponto pendente
 */
function removePendingMarker() {
  if (state.pendingMeasureMarker) {
    state.scene.remove(state.pendingMeasureMarker);
    state.pendingMeasureMarker = null;
  }
}

/**
 * Cria a textura dinâmica 2D renderizada em Canvas para o Badge da cota
 */
function createMeasurementSprite(text, isSpan = true) {
  const canvas = document.createElement('canvas');
  canvas.width = 440;
  canvas.height = 140;
  const ctx = canvas.getContext('2d');

  const r = 28;
  const w = 428;
  const h = 128;
  const x = 6;
  const y = 6;

  // Fundo cápsula Dark Slate semi-translúcido (#0F172A)
  ctx.fillStyle = 'rgba(15, 23, 42, 0.94)';
  ctx.strokeStyle = isSpan ? '#2563EB' : '#10B981'; // Royal Blue para Vão Livre, Emerald Green para Ponto a Ponto
  ctx.lineWidth = 6;

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
  ctx.font = 'bold 44px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
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
  sprite.scale.set(1.25, 0.40, 1.0);
  return sprite;
}

/**
 * Adiciona a cota visual 3D (esferas de extremidade, linha de cota técnica com ticks e badge flutuante)
 */
function addMeasurementVisual(P0, P1, dist, type, id) {
  if (!state.measureGroup) {
    state.measureGroup = new THREE.Group();
    state.scene.add(state.measureGroup);
  }

  const group = new THREE.Group();
  group.name = id;

  const isSpan = type === 'span';
  const colorHex = isSpan ? 0x2563EB : 0x10B981; // Accent Royal Blue ou Emerald Green

  // 1. Esferas de ancoragem nos pontos inicial e final
  const sphereGeom = new THREE.SphereGeometry(0.045, 16, 16);
  const sphereMat = new THREE.MeshBasicMaterial({ color: colorHex, depthTest: false });

  const sphere0 = new THREE.Mesh(sphereGeom, sphereMat);
  sphere0.position.copy(P0);
  group.add(sphere0);

  const sphere1 = new THREE.Mesh(sphereGeom, sphereMat);
  sphere1.position.copy(P1);
  group.add(sphere1);

  // 2. Linha principal de cota
  const lineGeom = new THREE.BufferGeometry().setFromPoints([P0, P1]);
  const lineMat = new THREE.LineBasicMaterial({
    color: colorHex,
    linewidth: 2,
    depthTest: false,
  });
  const line = new THREE.Line(lineGeom, lineMat);
  group.add(line);

  // 3. Ticks perpendiculares nas extremidades (estilo cota de engenharia)
  const dir = P1.clone().sub(P0);
  const len = dir.length();
  if (len > 0.001) {
    dir.normalize();
    const upVector = Math.abs(dir.y) > 0.85 ? new THREE.Vector3(1, 0, 0) : new THREE.Vector3(0, 1, 0);
    const perp = new THREE.Vector3().crossVectors(dir, upVector).normalize().multiplyScalar(0.12);

    const tick0Geom = new THREE.BufferGeometry().setFromPoints([
      P0.clone().sub(perp),
      P0.clone().add(perp)
    ]);
    const tick1Geom = new THREE.BufferGeometry().setFromPoints([
      P1.clone().sub(perp),
      P1.clone().add(perp)
    ]);
    const tickMat = new THREE.LineBasicMaterial({ color: colorHex, linewidth: 2, depthTest: false });
    group.add(new THREE.Line(tick0Geom, tickMat));
    group.add(new THREE.Line(tick1Geom, tickMat));
  }

  // 4. Badge numérico flutuante (Billboard Sprite)
  const midPoint = P0.clone().add(P1).multiplyScalar(0.5);
  midPoint.y += 0.12; // Pequeno offset para elevar acima da linha

  const formattedStr = `${dist.toFixed(2).replace('.', ',')} m`;
  const labelText = isSpan ? `Vão: ${formattedStr}` : formattedStr;
  const sprite = createMeasurementSprite(labelText, isSpan);
  sprite.position.copy(midPoint);
  group.add(sprite);

  state.measureGroup.add(group);
}

/**
 * Adiciona medição estruturada aos registros e notifica Flutter
 */
function recordMeasurement(P0, P1, dist, type) {
  const id = `meas_${Date.now()}`;
  addMeasurementVisual(P0, P1, dist, type, id);

  const formattedStr = `${dist.toFixed(2).replace('.', ',')} m`;
  const label = type === 'span' ? `Vão Livre: ${formattedStr}` : `Distância: ${formattedStr}`;

  const measurementData = {
    id: id,
    distance: Number(dist.toFixed(3)),
    formattedDistance: formattedStr,
    type: type,
    label: label,
    startPoint: { x: Number(P0.x.toFixed(3)), y: Number(P0.y.toFixed(3)), z: Number(P0.z.toFixed(3)) },
    endPoint: { x: Number(P1.x.toFixed(3)), y: Number(P1.y.toFixed(3)), z: Number(P1.z.toFixed(3)) },
    deltaX: Number(Math.abs(P1.x - P0.x).toFixed(3)),
    deltaY: Number(Math.abs(P1.y - P0.y).toFixed(3)),
    deltaZ: Number(Math.abs(P1.z - P0.z).toFixed(3)),
  };

  state.measurements.push(measurementData);
  notifyFlutter('onMeasurementCreated', measurementData);
}

/**
 * Trata o clique/toque quando o Modo de Medição está ativo.
 * Permite calcular vãos livres (spans) diretamente no modelo 3D com um toque!
 */
async function handleMeasureClick(hit) {
  if (!hit || !hit.point) return;

  const point = hit.point.clone();

  // Modo 1: Vão Livre com 1 Toque (Automatic Free Span / Clear Span)
  if (state.measureSubMode === 'span') {
    let hitNormal = null;
    if (hit.face && hit.face.normal) {
      hitNormal = hit.face.normal.clone();
      if (hit.object && hit.object.matrixWorld) {
        hitNormal.transformDirection(hit.object.matrixWorld).normalize();
      }
    }

    let oppositeHit = null;

    // Dispara raio ao longo da normal da face para frente (em direção ao vão livre / espaço interno)
    if (hitNormal && state.currentModel) {
      const rayOrigin = point.clone().add(hitNormal.clone().multiplyScalar(0.008));
      const spanRay = new THREE.Raycaster(rayOrigin, hitNormal, 0.02, 100);
      const candidates = spanRay.intersectObjects([state.currentModel], true);
      if (candidates.length > 0) {
        oppositeHit = candidates[0];
      }
    }

    // Se não atingiu na direção da normal, tenta na direção oposta (-normal)
    if (!oppositeHit && hitNormal && state.currentModel) {
      const invNormal = hitNormal.clone().negate();
      const rayOrigin = point.clone().add(invNormal.clone().multiplyScalar(0.008));
      const spanRay = new THREE.Raycaster(rayOrigin, invNormal, 0.02, 100);
      const candidates = spanRay.intersectObjects([state.currentModel], true);
      if (candidates.length > 0) {
        oppositeHit = candidates[0];
      }
    }

    // Se encontrou face oposta: Vão livre calculado instantaneamente com 1 toque!
    if (oppositeHit) {
      const P0 = point;
      const P1 = oppositeHit.point.clone();
      const dist = P0.distanceTo(P1);
      recordMeasurement(P0, P1, dist, 'span');
      state.pendingMeasurePoint = null;
      removePendingMarker();
      return;
    }

    // Se a face for externa ou em vão aberto ao ar livre sem colisão oposta direta:
    if (state.pendingMeasurePoint) {
      const P0 = state.pendingMeasurePoint;
      const P1 = point;
      const dist = P0.distanceTo(P1);
      recordMeasurement(P0, P1, dist, 'span');
      state.pendingMeasurePoint = null;
      removePendingMarker();
    } else {
      state.pendingMeasurePoint = point;
      createPendingMarker(point);
      notifyFlutter('onMeasurementWaitingPoint', {
        startPoint: { x: point.x, y: point.y, z: point.z },
        message: 'Ponto de partida registrado. Toque na outra extremidade para fechar o vão livre.'
      });
    }
  }
  // Modo 2: Medição Ponto a Ponto (2 Toques)
  else {
    if (!state.pendingMeasurePoint) {
      state.pendingMeasurePoint = point;
      createPendingMarker(point);
      notifyFlutter('onMeasurementWaitingPoint', {
        startPoint: { x: point.x, y: point.y, z: point.z },
        message: 'Ponto A fixado. Toque no ponto B para medir a distância linear.'
      });
    } else {
      const P0 = state.pendingMeasurePoint;
      const P1 = point;
      const dist = P0.distanceTo(P1);
      recordMeasurement(P0, P1, dist, 'point_to_point');
      state.pendingMeasurePoint = null;
      removePendingMarker();
    }
  }
}

/**
 * Remove todas as cotas e medições visuais da cena 3D
 */
function clearMeasurementsVisuals() {
  if (state.measureGroup) {
    while (state.measureGroup.children.length > 0) {
      const obj = state.measureGroup.children[0];
      state.measureGroup.remove(obj);
    }
  }
  removePendingMarker();
  state.pendingMeasurePoint = null;
  state.measurements = [];
}

/**
 * Remove a última cota criada
 */
function removeLastMeasurementVisual() {
  if (state.measureGroup && state.measureGroup.children.length > 0) {
    const lastChild = state.measureGroup.children[state.measureGroup.children.length - 1];
    state.measureGroup.remove(lastChild);
  }
  if (state.measurements.length > 0) {
    state.measurements.pop();
  }
  removePendingMarker();
  state.pendingMeasurePoint = null;
}

/**
 * Funções Globais expostas para a JS Bridge do Flutter (Modo de Medição)
 */
function setMeasureMode(enabled, mode) {
  state.isMeasureMode = Boolean(enabled);
  state.measureSubMode = mode || 'span';
  removePendingMarker();
  state.pendingMeasurePoint = null;

  if (state.isMeasureMode) {
    clearSelection();
  }

  notifyFlutter('onMeasureModeChanged', {
    enabled: state.isMeasureMode,
    mode: state.measureSubMode,
  });
}

function setMeasureSubMode(mode) {
  state.measureSubMode = mode || 'span';
  removePendingMarker();
  state.pendingMeasurePoint = null;
  notifyFlutter('onMeasureModeChanged', {
    enabled: state.isMeasureMode,
    mode: state.measureSubMode,
  });
}

function clearMeasurements() {
  clearMeasurementsVisuals();
  notifyFlutter('onMeasurementCleared', {});
}

function removeLastMeasurement() {
  removeLastMeasurementVisual();
  notifyFlutter('onMeasurementRemoved', {
    count: state.measurements.length,
    lastMeasurement: state.measurements.length > 0 ? state.measurements[state.measurements.length - 1] : null,
  });
}

// Exportações
window.BimEngine.createPendingMarker = createPendingMarker;
window.BimEngine.removePendingMarker = removePendingMarker;
window.BimEngine.createMeasurementSprite = createMeasurementSprite;
window.BimEngine.addMeasurementVisual = addMeasurementVisual;
window.BimEngine.recordMeasurement = recordMeasurement;
window.BimEngine.handleMeasureClick = handleMeasureClick;
window.BimEngine.clearMeasurementsVisuals = clearMeasurementsVisuals;
window.BimEngine.removeLastMeasurementVisual = removeLastMeasurementVisual;
window.BimEngine.setMeasureMode = setMeasureMode;
window.BimEngine.setMeasureSubMode = setMeasureSubMode;
window.BimEngine.clearMeasurements = clearMeasurements;
window.BimEngine.removeLastMeasurement = removeLastMeasurement;

window.createPendingMarker = createPendingMarker;
window.removePendingMarker = removePendingMarker;
window.createMeasurementSprite = createMeasurementSprite;
window.addMeasurementVisual = addMeasurementVisual;
window.recordMeasurement = recordMeasurement;
window.handleMeasureClick = handleMeasureClick;
window.clearMeasurementsVisuals = clearMeasurementsVisuals;
window.removeLastMeasurementVisual = removeLastMeasurementVisual;
window.setMeasureMode = setMeasureMode;
window.setMeasureSubMode = setMeasureSubMode;
window.clearMeasurements = clearMeasurements;
window.removeLastMeasurement = removeLastMeasurement;
