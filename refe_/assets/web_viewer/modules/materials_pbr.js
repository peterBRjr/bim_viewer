/**
 * ThatOpen Engine & Three.js 3D BIM Viewport - Módulo de Materiais PBR e Geometrias
 */

window.BimEngine = window.BimEngine || {};

/**
 * Gera textura procedural arquitetônica 100% offline (micro-grão suave de concreto/acabamento fosco)
 * com filtro anisotrópico e mipmaps para evitar qualquer serrilhado ou falha de pixel.
 */
function getArchitecturalBumpTexture() {
  if (state.archBumpTexture) return state.archBumpTexture;
  try {
    if (typeof document === 'undefined' || typeof document.createElement !== 'function') return null;
    const canvas = document.createElement('canvas');
    if (!canvas || typeof canvas.getContext !== 'function') return null;
    canvas.width = 128;
    canvas.height = 128;
    const ctx2d = canvas.getContext('2d');
    if (!ctx2d) return null;

    const imgData = ctx2d.createImageData(128, 128);
    const data = imgData.data;
    // Ruído determinístico suave (hash senoidal) para acabamento de maquete técnica limpa
    for (let i = 0; i < 128 * 128; i++) {
      const n = Math.sin(i * 12.9898 + 78.233) * 43758.5453;
      const frac = n - Math.floor(n);
      const shade = 122 + Math.floor(frac * 12); // Variação sutil (122..134) sem granulação agressiva
      const idx = i * 4;
      data[idx] = shade;
      data[idx + 1] = shade;
      data[idx + 2] = shade;
      data[idx + 3] = 255;
    }
    ctx2d.putImageData(imgData, 0, 0);

    const texture = new THREE.CanvasTexture(canvas);
    texture.wrapS = THREE.RepeatWrapping;
    texture.wrapT = THREE.RepeatWrapping;
    texture.repeat.set(4, 4);
    texture.minFilter = THREE.LinearMipmapLinearFilter;
    texture.magFilter = THREE.LinearFilter;
    if (state.renderer && state.renderer.capabilities) {
      texture.anisotropy = Math.min(4, state.renderer.capabilities.getMaxAnisotropy() || 1);
    }
    texture.needsUpdate = true;
    state.archBumpTexture = texture;
    return texture;
  } catch (e) {
    return null;
  }
}

/**
 * Cria material PBR técnico (estilo Autodesk BIM 360 / Fusion) calibrado para leitura clara em obra,
 * com offset de profundidade escalonado para impedir Z-fighting (falhas de pixels entre faces coplanares).
 */
function createBimArchitecturalMaterial(color, matBucketIndex) {
  const col = new THREE.Color().setRGB(color.x, color.y, color.z, 'srgb');
  const isTransparent = color.w < 0.96;

  // Detecta se a cor é metálica/neutra (ex: estruturas metálicas, alumínio, aço) ou alvenaria/concreto
  const maxC = Math.max(color.x, color.y, color.z);
  const minC = Math.min(color.x, color.y, color.z);
  const saturation = maxC > 0.01 ? (maxC - minC) / maxC : 0;
  const isMetallicTone = !isTransparent && saturation < 0.14 && maxC > 0.22 && maxC < 0.82;

  const bumpTex = (!isTransparent && !state.isLowSpecDevice) ? getArchitecturalBumpTexture() : null;
  const offsetSlot = (matBucketIndex % 7) + 1;

  const material = new THREE.MeshStandardMaterial({
    color: col,
    roughness: isTransparent ? 0.15 : (isMetallicTone ? 0.45 : 0.68),
    metalness: isTransparent ? 0.18 : (isMetallicTone ? 0.28 : 0.06),
    bumpMap: bumpTex,
    bumpScale: isMetallicTone ? 0.004 : 0.008,
    side: THREE.DoubleSide,
    transparent: isTransparent,
    opacity: isTransparent ? Math.max(0.28, color.w) : 1.0,
    depthWrite: !isTransparent,
    polygonOffset: true,
    polygonOffsetFactor: offsetSlot * 0.18,
    polygonOffsetUnits: offsetSlot * 0.45,
  });

  return material;
}

/**
 * Solda vértices duplicados na mesma coordenada e normal (100% sem perdas visuais)
 * garantindo sombreamento suave e reduzindo o consumo de memória.
 */
function weldLosslessGeometry(vArr, iArr) {
  const vCount = vArr.length / 6;
  const remap = new Uint32Array(vCount);
  const map = new Map();
  const kept = [];
  let uniqueCount = 0;

  for (let v = 0; v < vCount; v++) {
    const s = v * 6;
    const px = Math.round(vArr[s] * 1000);
    const py = Math.round(vArr[s + 1] * 1000);
    const pz = Math.round(vArr[s + 2] * 1000);
    const nx = Math.round(vArr[s + 3] * 40);
    const ny = Math.round(vArr[s + 4] * 40);
    const nz = Math.round(vArr[s + 5] * 40);
    const key = `${px},${py},${pz},${nx},${ny},${nz}`;
    let nv = map.get(key);
    if (nv === undefined) {
      nv = uniqueCount++;
      map.set(key, nv);
      kept.push(s);
    }
    remap[v] = nv;
  }

  const iOut = new Uint32Array(iArr.length);
  for (let k = 0; k < iArr.length; k++) {
    iOut[k] = remap[iArr[k]];
  }

  const vOut = new Float32Array(uniqueCount * 6);
  for (let nv = 0; nv < uniqueCount; nv++) {
    const s = kept[nv];
    const d = nv * 6;
    vOut[d]     = vArr[s];     vOut[d + 1] = vArr[s + 1]; vOut[d + 2] = vArr[s + 2];
    vOut[d + 3] = vArr[s + 3]; vOut[d + 4] = vArr[s + 4]; vOut[d + 5] = vArr[s + 5];
  }
  return { vOut, iOut, vCount: uniqueCount };
}

/**
 * Gera um prisma 3D enxuto com leve recuo (inset de 1.5%) para evitar Z-fighting.
 * Em tablets de 4 GB RAM (isLowSpecDevice), utiliza 8 vértices compartilhados nos cantos (reduzindo 3x os vértices na GPU)
 * mantendo todas as 6 faces (12 triângulos / 36 índices) e seleção exata por ExpressID.
 */
function createBoxLodGeometryData(bbox) {
  let [minX, minY, minZ, maxX, maxY, maxZ] = bbox;
  const dx = (maxX - minX) * 0.015;
  const dy = (maxY - minY) * 0.015;
  const dz = (maxZ - minZ) * 0.015;
  minX += dx; maxX -= dx;
  minY += dy; maxY -= dy;
  minZ += dz; maxZ -= dz;

  if (state && state.isLowSpecDevice) {
    const inv = 0.57735;
    const corners = [
      [minX, minY, maxZ, -inv, -inv,  inv],
      [maxX, minY, maxZ,  inv, -inv,  inv],
      [maxX, maxY, maxZ,  inv,  inv,  inv],
      [minX, maxY, maxZ, -inv,  inv,  inv],
      [minX, minY, minZ, -inv, -inv, -inv],
      [maxX, minY, minZ,  inv, -inv, -inv],
      [maxX, maxY, minZ,  inv,  inv, -inv],
      [minX, maxY, minZ, -inv,  inv, -inv],
    ];
    const vOut = new Float32Array(8 * 6);
    for (let i = 0; i < 8; i++) {
      const o = i * 6;
      const c = corners[i];
      vOut[o] = c[0]; vOut[o + 1] = c[1]; vOut[o + 2] = c[2];
      vOut[o + 3] = c[3]; vOut[o + 4] = c[4]; vOut[o + 5] = c[5];
    }
    const iOut = new Uint32Array([
      0, 1, 2,  0, 2, 3, // frente (+Z)
      5, 4, 7,  5, 7, 6, // trás (-Z)
      3, 2, 6,  3, 6, 7, // topo (+Y)
      4, 5, 1,  4, 1, 0, // base (-Y)
      1, 5, 6,  1, 6, 2, // direita (+X)
      4, 0, 3,  4, 3, 7  // esquerda (-X)
    ]);
    return { vOut, iOut, vCount: 8 };
  }

  const faces = [
    { n: [0, 0, 1],  v: [[minX, minY, maxZ], [maxX, minY, maxZ], [maxX, maxY, maxZ], [minX, maxY, maxZ]] },
    { n: [0, 0, -1], v: [[maxX, minY, minZ], [minX, minY, minZ], [minX, maxY, minZ], [maxX, maxY, minZ]] },
    { n: [0, 1, 0],  v: [[minX, maxY, maxZ], [maxX, maxY, maxZ], [maxX, maxY, minZ], [minX, maxY, minZ]] },
    { n: [0, -1, 0], v: [[minX, minY, minZ], [maxX, minY, minZ], [maxX, minY, maxZ], [minX, minY, maxZ]] },
    { n: [1, 0, 0],  v: [[maxX, minY, maxZ], [maxX, minY, minZ], [maxX, maxY, minZ], [maxX, maxY, maxZ]] },
    { n: [-1, 0, 0], v: [[minX, minY, minZ], [minX, minY, maxZ], [minX, maxY, maxZ], [minX, maxY, minZ]] }
  ];
  const vOut = new Float32Array(24 * 6);
  const iOut = new Uint32Array(36);
  let vo = 0, io = 0;
  for (let f = 0; f < 6; f++) {
    const base = f * 4;
    const { n, v } = faces[f];
    for (let k = 0; k < 4; k++) {
      vOut[vo++] = v[k][0]; vOut[vo++] = v[k][1]; vOut[vo++] = v[k][2];
      vOut[vo++] = n[0];    vOut[vo++] = n[1];    vOut[vo++] = n[2];
    }
    iOut[io++] = base; iOut[io++] = base + 1; iOut[io++] = base + 2;
    iOut[io++] = base; iOut[io++] = base + 2; iOut[io++] = base + 3;
  }
  return { vOut, iOut, vCount: 24 };
}

// Exportações
window.BimEngine.getArchitecturalBumpTexture = getArchitecturalBumpTexture;
window.BimEngine.createBimArchitecturalMaterial = createBimArchitecturalMaterial;
window.BimEngine.weldLosslessGeometry = weldLosslessGeometry;
window.BimEngine.createBoxLodGeometryData = createBoxLodGeometryData;

window.getArchitecturalBumpTexture = getArchitecturalBumpTexture;
window.createBimArchitecturalMaterial = createBimArchitecturalMaterial;
window.weldLosslessGeometry = weldLosslessGeometry;
window.createBoxLodGeometryData = createBoxLodGeometryData;

