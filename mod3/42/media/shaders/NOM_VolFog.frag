// Névoa volumétrica. Cabeçalho: NOM_RenderContext.glsl.
// uParams[0]: x = densidade forçada (0 = usa a névoa do clima), y = modo debug
//             (1 = grade do mundo, 2 = profundidade, 3 = andar, 4 = erro de andar: chão preto liso,
//              5 = obstáculos do fluido, 6 = densidade do fluido, 7 = velocidade do fluido),
//             z = altura da base em andares (sprint 0047: padrão 0,45; 0 = 0,45),
//             w = altura no bolsão (padrão 1,2)
// uParams[1].x: simulação de fluido (lida no Java; aqui chega como uFlow.w)
// uParams[1].y: visual (1 = rolos com sombra própria, padrão; 0 = camada antiga)
// uParams[1].z: qualidade (0 baixa, 1 média, 2 alta): passos do raio no visual novo
// uParams[1].w: escala do véu de fundo (sprint 0047: fraco na base; 0 = só rolos); param 8 = 1 devolve vanilla
// uPocket / uPocketShape: bolsões viajantes (FogPockets)

const int STEPS = 12;
const float LEVEL_TILES = 2.5;   // um andar ~ 2,5 tiles, pra o ruído e a distância não ficarem esticados em z
const float WARP_S = 0.8;        // s: o ruído dobra onde o fluido desvia do vento (atrás de prédio, rastro)
const float MORPH = 0.06;        // forma mudando devagar (unidades de ruído por s)

vec3 gP;        // ponto visível do pixel (mundo relativo)
float gTree;    // árvore em volta de gP (0..1)
float gLow;     // carro em volta de gP (0..1): o raio que passa por cima dele sai de perto de gP

float hash(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
    vec3 i = floor(x), f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
                   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
               mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
                   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm2(vec3 p) {
    return 0.62 * noise(p) + 0.38 * noise(p * 2.07 + 7.1);
}

// Ponto do ruído em tiles: o mundo levado pelo vento acumulado (uDrift.xy, o mesmo dos bancos),
// dobrado onde o fluido desvia do vento e torcido por um ruído largo que muda devagar. Nada recomeça
// (o flow map de duas fases recomeçava a cada 2 s e a altura dos rolos ia e voltava junto na tela).
vec2 driftXY(vec2 xy, vec2 vel) {
    vec2 q = xy + uDrift.xy - (vel - uDrift.zw) * WARP_S;
    vec2 c = q * 0.07;
    float tz = 0.02 * uTime + dot(c, vec2(0.61, 0.43));
    vec2 curl = vec2(noise(vec3(c, tz)), noise(vec3(c + 31.7, tz + 5.3))) - 0.5;
    return q + curl * 3.0;
}

// O tempo entra inclinado no espaço: cada lugar muda de forma num momento diferente. Ruído de valor
// perde contraste entre os nós; se a tela toda passasse pelo meio junto, pulsaria.
float morphZ(vec2 q, float z) { return MORPH * uTime + dot(q, vec2(0.6, 0.45)) + z; }

// Ruído levado pelo vento (fbm, ~1/scale tiles por tufo). m = (x, y em tiles, altura em tiles).
float flowNoise(vec3 m, vec2 vel, float scale) {
    vec2 q = driftXY(m.xy, vel) * scale;
    return fbm2(vec3(q, morphZ(q, m.z * scale)));
}

// Densidade em w e, em `wisp`, o quanto ela é tufo de ruído (0) ou camada lisa do chão (1).
float density(vec3 w, float ground, float top, out float wisp) {
    vec2 vel = nomFlowVel(w.xy, uDrift.zw);
    float fd = nomFlowDensity(w.xy);
    vec3 m = vec3(w.xy, w.z * LEVEL_TILES);
    float n = smoothstep(0.22, 0.78, flowNoise(m, vel, 0.18));
    float h = clamp((w.z - ground) / max(top - ground, 0.01), 0.0, 1.0);
    float tufts = n * exp(-2.8 * h);                 // tufos, mais finos subindo
    float floorLayer = 0.45 * exp(-10.0 * h);        // camada lisa e densa rente ao chão
    float hug = gTree * 0.9 * exp(-5.0 * h) * max(0.0, 1.0 - length(w.xy - gP.xy) / 1.5); // envolve a base da árvore
    float d = fd * (tufts + floorLayer) + hug;
    wisp = n;
    for (int i = 0; i < uCharCount; i++) {          // abre em volta de quem anda nela
        vec4 c = uChars[i];
        float r = length(w.xy - c.xy);
        float sameFloor = 1.0 - smoothstep(0.5, 1.0, abs(w.z - c.z));
        d *= mix(1.0, smoothstep(c.w * 0.4, c.w, r), sameFloor);
    }
    return d * nomClearing(w.xy);                   // o tiro abre tudo, véu de fundo inclusive
}

// ---------- visual novo: rolos com silhueta e sombra própria ----------
const vec3 SUN_STEP = vec3(-0.7, -0.5, 0.3);  // um passo rumo à luz (tiles, tiles, andares)
const float ROLL_SOFT = 0.14;                 // andares: borda do topo (0047b: mais afiada = fiapos, menos bolha)
const float HAZE = 0.18;                      // véu de fundo: ~40% de cobertura no chão com a névoa cheia
const float PILE = 0.5;                       // quanto o rolo sobe onde o ar para contra a parede
const float ROLL_STRETCH = 2.2;               // anisotropia ao longo do vento: fitas, não esferas
const float ROLL_WARP = 1.8;                  // dobra o domínio (curvas/fiapos; playtest 0047)

// Ar mais lento que o vento livre (freando contra a parede) empurra a névoa pra cima; o que acelera
// na quina, pra baixo (pressão pela velocidade, Bernoulli). Fração de altura a somar no rolo.
// Só sobe com obstáculo logo à frente no vento: na esteira o ar também é lento, mas ali a névoa
// assenta (sprint 0031).
const int PILE_BLOCK = NOM_FLOW_SOLID | NOM_FLOW_INDOOR | NOM_FLOW_LOW;
float pileUp(vec2 xy, vec2 vel) {
    float w2 = dot(uDrift.zw, uDrift.zw);
    if (w2 < 0.04) return 0.0;
    float s = clamp(1.0 - dot(vel, vel) / w2, -1.0, 1.0);
    if (s <= 0.0) return 0.5 * PILE * s;
    vec2 ahead = uDrift.zw * inversesqrt(w2);
    float block = (nomFlowFlags(xy + ahead) & PILE_BLOCK) != 0 ? 1.0
                : (nomFlowFlags(xy + 2.5 * ahead) & PILE_BLOCK) != 0 ? 0.6 : 0.0;
    return PILE * s * block;
}

// Altura do topo do rolo na coluna xy, em andares acima do chão. Onde o fluido acumula, sobe mais.
// Em cima do carro, a névoa que passa por cima (a densidade de lá) começa no teto dele (sprint 0032).
// `q` = ponto do ruído em tiles, pros fiapos reaproveitarem.
// 0047b (playtest Johan): menos “algodão redondo” — ruído anisotrópico no vento + ridge + warp
// (curvas/fiapos tipo gelo seco); mantém o mar baixo (layerEff / C-lite).
float rollTop(vec2 xy, float layer, out vec2 q) {
    float fd = nomFlowDensity(xy);
    vec2 vel = nomFlowVel(xy, uDrift.zw);
    q = driftXY(xy, vel);
    // eixo longo = vento (ou deriva); transversal comprimida → fitas curvas, não bolhas
    float w2 = dot(uDrift.zw, uDrift.zw);
    vec2 along = w2 > 0.04 ? uDrift.zw * inversesqrt(w2) : vec2(1.0, 0.0);
    vec2 across = vec2(-along.y, along.x);
    vec2 local = vec2(dot(q, along), dot(q, across));
    vec2 r = vec2(local.x * 0.16, local.y * 0.16 * ROLL_STRETCH); // ~6 tiles no vento, ~2,8 de lado
    float wz = morphZ(r, 0.0);
    vec2 warp = vec2(noise(vec3(r * 0.5, wz + 2.1)), noise(vec3(r * 0.5 + 19.3, wz + 5.7))) - 0.5;
    r += warp * ROLL_WARP;
    float n = fbm2(vec3(r, wz));
    float ridge = 1.0 - abs(2.0 * n - 1.0);                       // dobras / cristas, não cúmulo
    ridge *= ridge;
    float shape = smoothstep(0.12, 0.88, mix(n, ridge, 0.58));    // sem pow^2 de “bola”
    float onCar = NOM_FLOW_LOW_H * gLow * smoothstep(0.0, 0.2, fd);
    return onCar + layer * min(fd, 1.5) * (0.28 + 0.72 * shape) * (1.0 + pileUp(xy, vel));
}

// Bolsão no shader: mesmo espírito do FogPockets (offset+morph+limiar), ruído float do
// shader (evita overflow de int do hash Java no GLSL). Cobertura ~rara pelo limiar.
float pocketSample(vec2 xyRel) {
    if (uPocket.w <= 0.001 || uPocketShape.x < 1.0) return 0.0;
    vec2 w = xyRel + uOrigin - uPocket.xy;
    float sc = max(uPocketShape.x, 1.0);
    float n = fbm2(vec3(w / sc, uPocket.z * 0.15));
    float soft = max(uPocketShape.z, 0.001);
    float t = (n - uPocketShape.y + soft) / (2.0 * soft);
    t = clamp(t, 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

float baseLayer() {
    return uParams[0].z > 0.0 ? uParams[0].z : 0.45;
}

float pocketLayer() {
    return uParams[0].w > 0.0 ? uParams[0].w : 1.2;
}

float layerAt(vec2 xyRel) {
    float pk = pocketSample(xyRel);
    float boost = clamp(uPocket.w, 0.0, 3.0);
    return mix(baseLayer(), pocketLayer() * max(boost, 1.0), pk);
}

// Densidade em w; `shade` = 0 no topo iluminado, cresce pra dentro e pra baixo do rolo.
// C-lite (sprint 0047): na base o perfil corta alto (chão denso); no bolsão sobe como antes.
float densityLook(vec3 w, float ground, float layer, out float shade) {
    float hz = w.z - ground;
    float pk = pocketSample(w.xy);
    float layerEff = mix(baseLayer(), pocketLayer() * max(uPocket.w, 1.0), pk);
    vec2 q, qs;
    float top = rollTop(w.xy, layerEff, q);
    // fiapos alongados no vento (0047b): quebram a silhueta circular das bordas
    float w2f = dot(uDrift.zw, uDrift.zw);
    vec2 alongF = w2f > 0.04 ? uDrift.zw * inversesqrt(w2f) : vec2(1.0, 0.0);
    vec2 acrossF = vec2(-alongF.y, alongF.x);
    vec2 fLoc = vec2(dot(q, alongF), dot(q, acrossF));
    vec2 f = vec2(fLoc.x * 0.55, fLoc.y * 1.4);                               // tendril fino transversal
    float fiapo = noise(vec3(f, morphZ(f, w.z * LEVEL_TILES * 0.9) * 1.7)) - 0.5;
    float d = smoothstep(0.0, ROLL_SOFT, top - hz + 0.55 * fiapo);
    // C-lite: base = queda rápida com a altura (mar no piso); bolsão = perfil antigo
    float fall = mix(8.0, 1.0, pk);
    d *= 1.15 - 0.45 * clamp(hz / max(layerEff, 0.01), 0.0, 1.0);
    d *= mix(exp(-fall * hz / max(layerEff, 0.01)), 1.0, pk);              // corta o peito na base
    d += gTree * 0.9 * exp(-5.0 * hz / max(layerEff, 0.01)) * max(0.0, 1.0 - length(w.xy - gP.xy) / 1.5);
    bool indoor = (nomFlowFlags(w.xy) & NOM_FLOW_INDOOR) != 0;
    float hazeScale = mix(uParams[1].w, min(uParams[1].w + 0.7, 1.2), pk); // véu sobe no bolsão
    d += indoor ? 0.0 : HAZE * hazeScale * exp(-1.5 * hz / max(layerEff, 0.01));
    vec3 s = w + SUN_STEP;
    shade = max(0.0, top - hz) + 0.6 * max(0.0, rollTop(s.xy, layerEff, qs) - (s.z - ground));
    for (int i = 0; i < uCharCount; i++) {
        vec4 c = uChars[i];
        float r = length(w.xy - c.xy);
        float sameFloor = 1.0 - smoothstep(0.5, 1.0, abs(w.z - c.z));
        d *= mix(1.0, smoothstep(c.w * 0.4, c.w, r), sameFloor);
    }
    return d * nomClearing(w.xy);                   // o tiro abre tudo, véu de fundo inclusive
}

// Luz das lanternas e faróis em w (0 fora dos fachos); `open` = o quanto o facho abre a névoa ali.
vec3 torchLight(vec3 w, out float open) {
    vec3 acc = vec3(0.0);
    open = 0.0;
    for (int k = 0; k < uTorchCount; k++) {
        vec4 P = uTorchPos[k], D = uTorchDir[k], C = uTorchColor[k];
        vec3 dv = vec3(w.xy - P.xy, (w.z - P.z) * LEVEL_TILES);
        float dist = length(dv);
        if (dist > P.w || dist < 1e-3) continue;
        float cone = D.w <= -0.99 ? 1.0 : smoothstep(D.w, mix(D.w, 1.0, 0.5), dot(dv / dist, D.xyz));
        float fall = 1.0 - dist / P.w;
        float b = cone * fall * fall * (dist / (dist + 0.6)) * clamp(C.w, 0.0, 2.0); // sem estouro na mão
        acc += C.rgb * b;
        open += b;
    }
    open = clamp(open, 0.0, 1.0);
    return acc;
}

vec4 fogLook(vec3 P, float amount) {
    float ground = floor(uDepthRef.z);
    float layer = layerAt(P.xy);                    // base baixa; sobe no bolsão (sprint 0047)
    float top = ground + max(layer, pocketLayer()) * 1.6;
    if (P.z >= top) return vec4(0.0);
    gP = P;
    gTree = nomFlowTree(P.xy);
    gLow = nomFlowLow(P.xy);

    int steps = uParams[1].z < 0.5 ? 8 : (uParams[1].z < 1.5 ? 12 : 16);
    float span = top - max(P.z, ground - 0.25);
    vec3 start = vec3(P.xy, max(P.z, ground - 0.25));
    vec3 stepW = NOM_TO_CAMERA * (span / float(steps));
    float stepLen = length(vec3(stepW.xy, stepW.z * LEVEL_TILES));
    float jitter = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));

    // topo claro na cor do clima; barriga escura, mais cinza e um pouco mais fria
    vec3 base = uFog.yzw;
    vec3 lit = base * 1.08;
    vec3 dark = mix(base, vec3(dot(base, vec3(0.299, 0.587, 0.114))) * vec3(0.92, 0.96, 1.05), 0.5) * 0.38;
    float sigma = 0.9 * amount;
    float trans = 1.0;
    vec3 light = vec3(0.0);
    for (int i = 0; i < 16; i++) {                      // da câmera pro chão: a frente cobre o fundo
        if (i >= steps) break;
        vec3 w = start + stepW * (float(steps - 1 - i) + jitter);
        float shade;
        float dens = densityLook(w, ground, layer, shade);
        if (dens <= 0.001) continue;
        float open;
        vec3 torch = torchLight(w, open);
        dens *= 1.0 - 0.55 * open;                      // a luz abre a névoa
        float absorb = 1.0 - exp(-sigma * dens * stepLen);
        float sun = exp(-1.6 * shade * LEVEL_TILES * amount);
        light += trans * absorb * (mix(dark, lit, sun) + torch * 1.6); // o facho aceso dentro da névoa
        trans *= 1.0 - absorb;
        if (trans < 0.02) break;
    }
    float a = 1.0 - trans;
    const float MAX_A = 0.9;
    if (a > MAX_A) { light *= MAX_A / a; a = MAX_A; }
    return vec4(light, a);
}

void main() {
    float amount = uParams[0].x > 0.0 ? uParams[0].x : uFog.x;
    int dbg = int(uParams[0].y + 0.5);
    vec2 iso = nomIsoScreen();
    float d = nomDepth();
    bool sky = d >= 0.99999;
    vec3 P = sky ? nomWorldPosAtZ(iso, floor(uDepthRef.z)) : nomWorldPos(iso, d);

    if (dbg == 1) { // grade: as linhas têm que grudar nas bordas dos tiles ao andar
        vec2 g = abs(fract(P.xy) - 0.5);
        float line = step(0.46, max(g.x, g.y));
        fragColor = vec4(vec3(line, fract(P.z + 0.5), 0.0) * 0.6, 0.6); // chão = verde 0,5 liso
        return;
    }
    if (dbg == 2) { fragColor = vec4(vec3(fract(d * 200.0)), 1.0); return; }
    if (dbg == 4) { // distância ao andar inteiro mais perto, x10: chão e telhado retos pretos; parede rampa
        fragColor = vec4(vec3(clamp(abs(P.z - floor(P.z + 0.5)) * 10.0, 0.0, 1.0)), 1.0);
        return;
    }
    if (dbg == 3) { fragColor = vec4(fract(P.z + 0.5), 0.0, 1.0 - fract(P.z + 0.5), 1.0) * 0.5; return; }
    if (dbg >= 5 && dbg <= 7 && !nomFlowOn()) { fragColor = vec4(1.0, 0.0, 1.0, 1.0); return; } // magenta: o shader acha a simulação desligada
    if (dbg >= 5 && dbg <= 7) {
        vec2 uv = nomFlowUV(P.xy);
        if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) { fragColor = vec4(0.0, 0.0, 0.35, 1.0); return; } // fora da grade
    }
    if (dbg == 5) { // obstáculos: sólido vermelho, árvore verde, interior azul, carro laranja, parede/porta fechada branca, cerca baixa amarela
        int f = nomFlowFlags(P.xy);
        vec2 e = fract(P.xy);
        vec3 c = vec3((f & NOM_FLOW_SOLID) != 0 ? 0.8 : 0.0, (f & NOM_FLOW_TREE) != 0 ? 0.8 : 0.0,
                      (f & NOM_FLOW_INDOOR) != 0 ? 0.6 : 0.0);
        if ((f & NOM_FLOW_LOW) != 0) c = vec3(0.9, 0.5, 0.0);   // carro, laranja
        if (((f & NOM_FLOW_WALL_W) != 0 && e.x < 0.12) || ((f & NOM_FLOW_WALL_N) != 0 && e.y < 0.12)) c = vec3(1.0);
        if (((f & NOM_FLOW_FENCE_W) != 0 && e.x < 0.12) || ((f & NOM_FLOW_FENCE_N) != 0 && e.y < 0.12)) c = vec3(1.0, 0.9, 0.1);
        fragColor = vec4(c * 0.7, 0.7);
        return;
    }
    if (dbg == 6) { fragColor = vec4(vec3(texture(uFlowTex, nomFlowUV(P.xy)).r), 1.0); return; } // preto vazio, cinza 1,0, branco 1,5
    if (dbg == 7) { // velocidade, saturando em 1 tile/s: vermelho = +x, verde = +y, cinza = parado
        vec2 v = clamp(nomFlowVel(P.xy, vec2(0.0)), -1.0, 1.0);
        fragColor = vec4(0.5 + 0.5 * v.x, 0.5 + 0.5 * v.y, 0.5, 1.0);
        return;
    }
    if (amount <= 0.001) { fragColor = vec4(0.0); return; }
    if (uParams[1].y > 0.5) { fragColor = fogLook(P, amount); return; }

    float ground = floor(uDepthRef.z);
    float top = ground + layerAt(P.xy);
    if (P.z >= top) { fragColor = vec4(0.0); return; }
    gP = P;
    gTree = nomFlowTree(P.xy);
    gLow = nomFlowLow(P.xy);

    // do ponto visível até sair pelo topo da camada, rumo à câmera
    float span = top - max(P.z, ground - 0.25);
    vec3 start = vec3(P.xy, max(P.z, ground - 0.25));
    vec3 stepW = NOM_TO_CAMERA * (span / float(STEPS));
    float stepLen = length(vec3(stepW.xy, stepW.z * LEVEL_TILES));
    float jitter = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));

    // a cor vem do clima (vermelha na névoa vermelha); embaixo mais clara, em cima mais cinza e escura,
    // e os tufos mais grossos um pouco mais escuros, pra não ficar chapada
    vec3 base = uFog.yzw;
    vec3 grey = vec3(dot(base, vec3(0.299, 0.587, 0.114)));
    float sigma = 0.9 * amount;   // extinção por tile
    float trans = 1.0;
    vec3 light = vec3(0.0);
    for (int i = 0; i < STEPS; i++) {
        vec3 w = start + stepW * (float(i) + jitter);
        float wisp;
        float dens = density(w, ground, top, wisp);
        float absorb = 1.0 - exp(-sigma * dens * stepLen);
        float h = clamp((w.z - ground) / max(top - ground, 0.01), 0.0, 1.0);
        vec3 col = mix(base, grey, 0.3 * h) * mix(0.82, 0.62, h) * mix(1.0, 0.85, wisp);
        light += trans * absorb * col;
        trans *= 1.0 - absorb;
        if (trans < 0.02) break;
    }
    float a = 1.0 - trans;
    const float MAX_A = 0.9;      // nunca tampa tudo
    if (a > MAX_A) { light *= MAX_A / a; a = MAX_A; }
    fragColor = vec4(light, a);
}
