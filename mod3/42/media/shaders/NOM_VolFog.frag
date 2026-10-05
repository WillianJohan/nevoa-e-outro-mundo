// Névoa volumétrica (spike). Cabeçalho: NOM_RenderContext.glsl.
// uParams[0]: x = densidade forçada (0 = usa a névoa do clima), y = modo debug
//             (1 = grade do mundo, 2 = profundidade, 3 = andar, 4 = erro de andar: chão preto liso), z = altura da camada em andares (0 = 1.0)

const int STEPS = 12;
const float LEVEL_TILES = 2.5;   // um andar ~ 2,5 tiles, pra o ruído e a distância não ficarem esticados em z

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

float fbm(vec3 p) {
    return 0.55 * noise(p) + 0.3 * noise(p * 2.03 + 7.1) + 0.15 * noise(p * 4.1 + 3.7);
}

float density(vec3 w, float ground, float top) {
    vec3 m = vec3(w.xy, w.z * LEVEL_TILES);
    vec3 wind = vec3(0.35, 0.15, 0.04) * uTime;
    float d = fbm(m * 0.18 + wind) ;
    d = smoothstep(0.25, 0.8, d);
    float h = clamp((w.z - ground) / max(top - ground, 0.01), 0.0, 1.0);
    d *= exp(-2.5 * h);                                    // mais densa rente ao chão
    for (int i = 0; i < uCharCount; i++) {                  // abre em volta de quem anda nela
        vec4 c = uChars[i];
        float r = length(w.xy - c.xy);
        float sameFloor = 1.0 - smoothstep(0.5, 1.0, abs(w.z - c.z));
        d *= mix(1.0, smoothstep(c.w * 0.4, c.w, r), sameFloor);
    }
    return d;
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
    if (amount <= 0.001) { fragColor = vec4(0.0); return; }

    float ground = floor(uDepthRef.z);
    float top = ground + (uParams[0].z > 0.0 ? uParams[0].z : 1.0);
    if (P.z >= top) { fragColor = vec4(0.0); return; }

    // do ponto visível até sair pelo topo da camada, rumo à câmera
    float span = top - max(P.z, ground - 0.25);
    vec3 start = vec3(P.xy, max(P.z, ground - 0.25));
    vec3 stepW = NOM_TO_CAMERA * (span / float(STEPS));
    float stepLen = length(vec3(stepW.xy, stepW.z * LEVEL_TILES));
    float jitter = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));

    float sigma = 0.9 * amount;   // extinção por tile
    float trans = 1.0;
    for (int i = 0; i < STEPS; i++) {
        vec3 w = start + stepW * (float(i) + jitter);
        trans *= exp(-sigma * density(w, ground, top) * stepLen);
        if (trans < 0.02) break;
    }
    float a = 1.0 - trans;
    vec3 col = uFog.yzw;           // a cor do clima já vem vermelha na névoa vermelha
    fragColor = vec4(col * a, a);
}
