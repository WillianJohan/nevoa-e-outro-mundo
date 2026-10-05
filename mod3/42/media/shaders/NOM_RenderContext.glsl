#version 330
// Contrato do "NOM render context" (mod3/java/nom/render/RenderContext.java).
// O Java põe este cabeçalho na frente de todo passe registrado. Saída pré-multiplicada:
// fragColor = vec4(cor * a, a), misturada com ONE, ONE_MINUS_SRC_ALPHA por cima da cena.

uniform sampler2D uDepth;      // profundidade da cena (cópia do FBO do jogador), em .r
uniform vec4 uViewport;        // retângulo do jogador no FBO (x, y, w, h), em pixels
uniform vec2 uDepthSize;       // tamanho de uDepth (potência de 2)
// Posições de mundo são RELATIVAS a uOrigin (inteiro, perto da câmera): float32 não aguenta
// coordenada absoluta (x+y ~ 2e4) na conta da reconstrução. Absoluto = P.xy + uOrigin.
uniform vec2 uOrigin;
uniform vec4 uCam;             // offX, offY (menos a tela de uOrigin), zoom, tileScale
uniform vec4 uDepthRef;        // d0, s0 = x+y (relativo), z0 do personagem da câmera; k = profundidade por tile de x+y
uniform float uTime;           // segundos
uniform vec4 uFog;             // intensidade da névoa do clima (0..1), cor final da névoa rgb (COLOR_NEW_FOG)
uniform int uCharCount;
uniform vec4 uChars[8];        // x, y (relativos), z, raio: jogadores locais e zumbis mais perto
uniform vec4 uParams[4];       // o que o Lua empurrou com NOMRender_setParam(i, v)
// Névoa fluida (Flow.java / FlowGrid.java): grade n x n de tiles, 1 texel por tile, linear.
// r = densidade (0..1), gb = velocidade (128 ± 127·v/NOM_FLOW_VMAX, tiles/s), a = flags (texelFetch).
uniform sampler2D uFlowTex;
uniform vec4 uFlow;            // x0, y0 da grade (relativos a uOrigin), n, 1 = simulação ligada

const float NOM_FLOW_VMAX = 4.0;
const int NOM_FLOW_SOLID = 1;
const int NOM_FLOW_TREE = 2;
const int NOM_FLOW_INDOOR = 4;
const int NOM_FLOW_WALL_W = 8;
const int NOM_FLOW_WALL_N = 16;

out vec4 fragColor;

float nomDepth() {
    return texture(uDepth, gl_FragCoord.xy / uDepthSize).r;
}

// Pixel da tela iso (o mesmo espaço do IsoUtils.XToScreen/YToScreen - offX/offY).
vec2 nomIsoScreen() {
    vec2 p = gl_FragCoord.xy - uViewport.xy;
    return vec2(p.x * uCam.z + uCam.x, (uViewport.w - p.y) * uCam.z + uCam.y);
}

// Mundo (x, y em tiles; z em andares) a partir da tela + profundidade.
//   XToScreen = 32T(x - y);  YToScreen = 16T(x + y) - 96T z         (IsoUtils)
//   d = d0 - k((x + y) - s0) - 2k(z - z0)                             (IsoDepthHelper: SQUARE_DEPTH = LEVEL_DEPTH = 2k)
vec3 nomWorldPos(vec2 iso, float d) {
    float T = uCam.w, k = uDepthRef.w;
    float u = iso.x / (32.0 * T);
    float a = iso.y / (16.0 * T);                         // = s - 6z
    float b = uDepthRef.y + 2.0 * uDepthRef.z - (d - uDepthRef.x) / k; // = s + 2z
    float z = (b - a) / 8.0;
    float s = a + 6.0 * z;
    return vec3((s + u) * 0.5, (s - u) * 0.5, z);
}

// Mundo num andar fixo (pra onde não há profundidade: vazio, céu).
vec3 nomWorldPosAtZ(vec2 iso, float z) {
    float T = uCam.w;
    float u = iso.x / (32.0 * T);
    float s = iso.y / (16.0 * T) + 6.0 * z;
    return vec3((s + u) * 0.5, (s - u) * 0.5, z);
}

// Direção do raio da câmera iso no mundo, rumo à câmera: com a tela fixa, ds = 6 dz e x - y fixo.
const vec3 NOM_TO_CAMERA = vec3(3.0, 3.0, 1.0);

bool nomFlowOn() { return uFlow.w > 0.5; }

vec2 nomFlowUV(vec2 xy) { return (xy - uFlow.xy) / uFlow.z; }

// Densidade do fluido em xy (mundo relativo); 1 com a simulação desligada. Perto da borda da
// grade volta pro ambiente, pra não aparecer o quadrado.
float nomFlowDensity(vec2 xy) {
    if (!nomFlowOn()) return 1.0;
    vec2 uv = nomFlowUV(xy);
    vec2 e = smoothstep(vec2(0.0), vec2(0.06), uv) * smoothstep(vec2(0.0), vec2(0.06), 1.0 - uv);
    return mix(1.0, texture(uFlowTex, uv).r, e.x * e.y);
}

// Velocidade do fluido em tiles/s; `fallback` com a simulação desligada ou fora da grade.
vec2 nomFlowVel(vec2 xy, vec2 fallback) {
    if (!nomFlowOn()) return fallback;
    vec2 uv = nomFlowUV(xy);
    if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return fallback;
    return (texture(uFlowTex, uv).gb * 255.0 - 128.0) / 127.0 * NOM_FLOW_VMAX;
}

// Flags do tile que contém xy (NOM_FLOW_*); 0 fora da grade ou desligada.
int nomFlowFlags(vec2 xy) {
    if (!nomFlowOn()) return 0;
    ivec2 c = ivec2(floor(xy - uFlow.xy));
    int n = int(uFlow.z);
    if (c.x < 0 || c.y < 0 || c.x >= n || c.y >= n) return 0;
    return int(texelFetch(uFlowTex, c, 0).a * 255.0 + 0.5);
}

// Quanto de árvore há em volta de xy (0..1, interpolado entre os 4 tiles mais perto).
float nomFlowTree(vec2 xy) {
    vec2 g = xy - 0.5;
    vec2 f = fract(g);
    vec2 b = floor(g) + 0.5;
    float t00 = (nomFlowFlags(b) & NOM_FLOW_TREE) != 0 ? 1.0 : 0.0;
    float t10 = (nomFlowFlags(b + vec2(1, 0)) & NOM_FLOW_TREE) != 0 ? 1.0 : 0.0;
    float t01 = (nomFlowFlags(b + vec2(0, 1)) & NOM_FLOW_TREE) != 0 ? 1.0 : 0.0;
    float t11 = (nomFlowFlags(b + vec2(1, 1)) & NOM_FLOW_TREE) != 0 ? 1.0 : 0.0;
    return mix(mix(t00, t10, f.x), mix(t01, t11, f.x), f.y);
}
