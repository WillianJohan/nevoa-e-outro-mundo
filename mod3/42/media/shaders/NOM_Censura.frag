// Rosto censurado do Sem-rosto (sprint 0044, ideia do Johan de 2026-10-05): um quadrado na tela sobre a
// cabeça, com o que está atrás borrado em mosaico e chiando como TV. Some onde a cena está na frente da
// cabeça (parede, poste) e com o zumbi fora da vista do jogador (alfa dele, Censor.java). Vem antes do
// NOM_VolFog em RenderContext.PASSES: a névoa cobre o quadrado como cobre o zumbi.

const float HALF = 9.0;        // meio lado do quadrado, em pixels iso por tileScale (a cabeça com folga)
const float BLOCK = 3.0;       // lado do bloco do mosaico, idem
const float OCCLUDE = 0.6;     // folga em (x + y) + 2z: a própria cabeça e o ombro não escondem o quadrado
const float FPS = 12.0;        // o chiado troca 12 vezes por segundo
const float STATIC = 0.6;      // quanto do bloco é chiado (o resto é a cena borrada)

float censorHash(vec3 p) {
    return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

vec3 sceneAt(vec2 iso) {
    return texture(uScene, nomIsoToFrag(iso) / uDepthSize).rgb;
}

void main() {
    float scale = uParams[3].y;                   // PARAM_CENSOR = 13 (0 desliga)
    if (uCensorCount == 0 || scale <= 0.0) discard;
    vec2 iso = nomIsoScreen();
    float d = nomDepth();
    float side = HALF * uCam.w * scale, block = BLOCK * uCam.w * scale;
    for (int i = 0; i < uCensorCount; i++) {
        vec4 c = uCensor[i];
        vec2 head = nomWorldToIso(c.xyz);
        vec2 q = (iso - head) / side;
        float m = max(abs(q.x), abs(q.y));
        if (m > 1.0) continue;
        if (d < nomDepthOf(c.xyz) - OCCLUDE * uDepthRef.w) continue;
        vec2 cell = floor((iso - head) / block);
        vec2 mid = head + (cell + 0.5) * block;
        float o = 0.25 * block;
        vec3 blur = 0.25 * (sceneAt(mid + vec2(-o, -o)) + sceneAt(mid + vec2(o, -o))
                          + sceneAt(mid + vec2(-o, o)) + sceneAt(mid + vec2(o, o)));
        float n = censorHash(vec3(cell, floor(uTime * FPS)));
        float scan = 0.8 + 0.2 * step(0.5, fract((iso.y - head.y) / block + uTime * 2.0));
        vec3 col = mix(blur, vec3(n) * scan, STATIC);
        float a = c.w * (1.0 - smoothstep(0.94, 1.0, m));
        fragColor = vec4(col * a, a);
        return;
    }
    discard;
}
