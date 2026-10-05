// Névoa volumétrica. Cabeçalho: NOM_RenderContext.glsl.
// uParams[0]: x = densidade forçada (0 = usa a névoa do clima), y = modo debug
//             (1 = grade do mundo, 2 = profundidade, 3 = andar, 4 = erro de andar: chão preto liso,
//              5 = obstáculos do fluido, 6 = densidade do fluido, 7 = velocidade do fluido),
//             z = altura da camada em andares (0 = 1.2)
// uParams[1].x: simulação de fluido (lida no Java; aqui chega como uFlow.w)
// uParams[1].y: visual (1 = rolos com sombra própria, padrão; 0 = camada antiga)

const int STEPS = 12;
const float LEVEL_TILES = 2.5;   // um andar ~ 2,5 tiles, pra o ruído e a distância não ficarem esticados em z
const float FLOW_PERIOD = 2.0;   // s: ciclo do flow map (o ruído é levado pela velocidade e recomeça)
const vec2 CALM_WIND = vec2(0.35, 0.15); // tiles/s, sem a simulação

vec3 gP;        // ponto visível do pixel (mundo relativo)
float gTree;    // árvore em volta de gP (0..1)

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

// Ruído levado pela velocidade do fluido: duas fases defasadas, cada uma recomeça quando o peso dela é 0.
float flowNoise(vec3 m, vec2 vel) {
    float a = fract(uTime / FLOW_PERIOD);
    float b = fract(uTime / FLOW_PERIOD + 0.5);
    vec3 rise = vec3(0.0, 0.0, 0.04 * uTime);
    vec3 p1 = m - vec3(vel * (a * FLOW_PERIOD), 0.0);
    vec3 p2 = m - vec3(vel * (b * FLOW_PERIOD), 0.0) + vec3(5.2, 1.3, 0.0);
    return mix(fbm2(p1 * 0.18 + rise), fbm2(p2 * 0.18 + rise), abs(2.0 * a - 1.0));
}

// Densidade em w e, em `wisp`, o quanto ela é tufo de ruído (0) ou camada lisa do chão (1).
float density(vec3 w, float ground, float top, out float wisp) {
    vec2 vel = nomFlowVel(w.xy, CALM_WIND);
    float fd = nomFlowDensity(w.xy);
    vec3 m = vec3(w.xy, w.z * LEVEL_TILES);
    float n = smoothstep(0.22, 0.78, flowNoise(m, vel));
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
    return d;
}

// ---------- visual novo: rolos com silhueta e sombra própria ----------
const vec3 SUN_STEP = vec3(-0.7, -0.5, 0.3);  // um passo rumo à luz (tiles, tiles, andares)
const float ROLL_SOFT = 0.22;                 // andares: borda macia do topo do rolo

float ruido2Fases(vec3 m, vec2 vel, float scale) {
    float a = fract(uTime / FLOW_PERIOD);
    float b = fract(uTime / FLOW_PERIOD + 0.5);
    vec3 p1 = m - vec3(vel * (a * FLOW_PERIOD), 0.0);
    vec3 p2 = m - vec3(vel * (b * FLOW_PERIOD), 0.0) + vec3(5.2, 1.3, 0.0);
    return mix(noise(p1 * scale), noise(p2 * scale), abs(2.0 * a - 1.0));
}

// Altura do topo do rolo na coluna xy, em andares acima do chão. Onde o fluido acumula, sobe mais.
float rollTop(vec2 xy, float layer) {
    vec2 vel = nomFlowVel(xy, CALM_WIND);
    float fd = nomFlowDensity(xy);
    float n = flowNoise(vec3(xy * 1.55, 0.0), vel * 1.55);       // ~3,5 tiles por rolo, andando com o fluido
    float puff = 1.0 - pow(1.0 - smoothstep(0.2, 0.8, n), 2.0);  // topo arredondado, tipo cúmulo
    return layer * min(fd, 1.5) * (0.25 + 0.8 * puff);
}

// Densidade em w; `shade` = 0 no topo iluminado, cresce pra dentro e pra baixo do rolo.
float densityLook(vec3 w, float ground, float layer, out float shade) {
    float hz = w.z - ground;
    float top = rollTop(w.xy, layer);
    vec2 vel = nomFlowVel(w.xy, CALM_WIND);
    float fiapo = ruido2Fases(vec3(w.xy, w.z * LEVEL_TILES), vel, 0.9) - 0.5; // fiapos de ~1 tile
    float d = smoothstep(0.0, ROLL_SOFT, top - hz + 0.35 * fiapo);
    d *= 1.15 - 0.45 * clamp(hz / layer, 0.0, 1.0);                         // mais densa embaixo
    d += gTree * 0.9 * exp(-5.0 * hz / layer) * max(0.0, 1.0 - length(w.xy - gP.xy) / 1.5);
    vec3 s = w + SUN_STEP;
    shade = max(0.0, top - hz) + 0.6 * max(0.0, rollTop(s.xy, layer) - (s.z - ground));
    for (int i = 0; i < uCharCount; i++) {
        vec4 c = uChars[i];
        float r = length(w.xy - c.xy);
        float sameFloor = 1.0 - smoothstep(0.5, 1.0, abs(w.z - c.z));
        d *= mix(1.0, smoothstep(c.w * 0.4, c.w, r), sameFloor);
    }
    return d;
}

vec4 fogLook(vec3 P, float amount) {
    float ground = floor(uDepthRef.z);
    float layer = uParams[0].z > 0.0 ? uParams[0].z : 1.2;
    float top = ground + layer * 1.3;
    if (P.z >= top) return vec4(0.0);
    gP = P;
    gTree = nomFlowTree(P.xy);

    float span = top - max(P.z, ground - 0.25);
    vec3 start = vec3(P.xy, max(P.z, ground - 0.25));
    vec3 stepW = NOM_TO_CAMERA * (span / float(STEPS));
    float stepLen = length(vec3(stepW.xy, stepW.z * LEVEL_TILES));
    float jitter = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));

    // topo claro na cor do clima; barriga escura, mais cinza e um pouco mais fria
    vec3 base = uFog.yzw;
    vec3 lit = base * 1.08;
    vec3 dark = mix(base, vec3(dot(base, vec3(0.299, 0.587, 0.114))) * vec3(0.92, 0.96, 1.05), 0.5) * 0.38;
    float sigma = 0.9 * amount;
    float trans = 1.0;
    vec3 light = vec3(0.0);
    for (int i = 0; i < STEPS; i++) {
        vec3 w = start + stepW * (float(i) + jitter);
        float shade;
        float dens = densityLook(w, ground, layer, shade);
        if (dens <= 0.001) continue;
        float absorb = 1.0 - exp(-sigma * dens * stepLen);
        float sun = exp(-1.6 * shade * LEVEL_TILES * amount);
        light += trans * absorb * mix(dark, lit, sun);
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
    if (dbg == 5) { // obstáculos: sólido vermelho, árvore verde, interior azul, parede/porta fechada branca
        int f = nomFlowFlags(P.xy);
        vec2 e = fract(P.xy);
        vec3 c = vec3((f & NOM_FLOW_SOLID) != 0 ? 0.8 : 0.0, (f & NOM_FLOW_TREE) != 0 ? 0.8 : 0.0,
                      (f & NOM_FLOW_INDOOR) != 0 ? 0.6 : 0.0);
        if (((f & NOM_FLOW_WALL_W) != 0 && e.x < 0.12) || ((f & NOM_FLOW_WALL_N) != 0 && e.y < 0.12)) c = vec3(1.0);
        fragColor = vec4(c * 0.7, 0.7);
        return;
    }
    if (dbg == 6) { fragColor = vec4(vec3(texture(uFlowTex, nomFlowUV(P.xy)).r), 1.0); return; } // preto vazio, branco cheio
    if (dbg == 7) { // velocidade, saturando em 1 tile/s: vermelho = +x, verde = +y, cinza = parado
        vec2 v = clamp(nomFlowVel(P.xy, vec2(0.0)), -1.0, 1.0);
        fragColor = vec4(0.5 + 0.5 * v.x, 0.5 + 0.5 * v.y, 0.5, 1.0);
        return;
    }
    if (amount <= 0.001) { fragColor = vec4(0.0); return; }
    if (uParams[1].y > 0.5) { fragColor = fogLook(P, amount); return; }

    float ground = floor(uDepthRef.z);
    float top = ground + (uParams[0].z > 0.0 ? uParams[0].z : 1.2);
    if (P.z >= top) { fragColor = vec4(0.0); return; }
    gP = P;
    gTree = nomFlowTree(P.xy);

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
