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
// Névoa fluida (Flow.java / FlowGrid.java): grade de uFlow.z x uFlow.z tiles, 1 a 3 texels por tile, linear.
// r = densidade / NOM_FLOW_DMAX, gb = velocidade (128 ± 127·v/NOM_FLOW_VMAX, tiles/s), a = flags (texelFetch).
uniform sampler2D uFlowTex;
uniform vec4 uFlow;            // x0, y0 da grade (relativos a uOrigin), tiles por lado, 1 = simulação ligada
uniform vec4 uDrift;           // xy = uOrigin menos o quanto o vento já levou a névoa (o mesmo dos bancos); zw = vento agora (tiles/s)
// Lanternas e faróis perto (RenderContext.collectTorches), pro facho na névoa.
uniform int uTorchCount;
uniform vec4 uTorchPos[4];     // x, y (relativos a uOrigin), z (andares), alcance (tiles)
uniform vec4 uTorchDir[4];     // direção unitária (em tiles), cos do meio-ângulo do cone (-1 = luz em volta)
uniform vec4 uTorchColor[4];   // r, g, b, força
// Clareiras dos tiros e explosões (Blasts.java): a névoa inteira abre no raio e fecha em ~4 s.
uniform int uClearCount;
uniform vec4 uClears[8];       // x, y (relativos a uOrigin), raio (tiles), força (0..1)
// Rosto censurado do Sem-rosto (Censor.java, sprint 0044).
uniform sampler2D uScene;      // cor da cena (cópia do FBO do jogador); só vale com uCensorCount > 0
uniform int uCensorCount;
uniform vec4 uCensor[4];       // x, y (relativos a uOrigin), z do meio da cabeça (andares), alfa do zumbi pro jogador

const float NOM_FLOW_VMAX = 4.0;
const float NOM_FLOW_DMAX = 1.5;      // a densidade acumula até 1,5 contra o obstáculo (FlowGrid.D_MAX)
const int NOM_FLOW_SOLID = 1;
const int NOM_FLOW_TREE = 2;
const int NOM_FLOW_INDOOR = 4;
const int NOM_FLOW_WALL_W = 8;
const int NOM_FLOW_WALL_N = 16;
const int NOM_FLOW_LOW = 64;          // carro: obstáculo baixo, o ar passa freado
const int NOM_FLOW_FENCE_W = 32;      // cerca baixa na borda oeste / norte da célula (sprint 0032)
const int NOM_FLOW_FENCE_N = 128;
const float NOM_FLOW_LOW_H = 0.55;    // altura do carro em andares (FlowGrid.H_LOW): a névoa passa por cima

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
// grade vai pra média dos bancos (~70% coberto), pra não aparecer o quadrado nem uma parede de névoa.
float nomFlowDensity(vec2 xy) {
    if (!nomFlowOn()) return 1.0;
    vec2 uv = nomFlowUV(xy);
    vec2 e = smoothstep(vec2(0.0), vec2(0.06), uv) * smoothstep(vec2(0.0), vec2(0.06), 1.0 - uv);
    return mix(0.7, texture(uFlowTex, uv).r * NOM_FLOW_DMAX, e.x * e.y);
}

// Velocidade do fluido em tiles/s; `fallback` com a simulação desligada ou fora da grade.
vec2 nomFlowVel(vec2 xy, vec2 fallback) {
    if (!nomFlowOn()) return fallback;
    vec2 uv = nomFlowUV(xy);
    if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return fallback;
    return (texture(uFlowTex, uv).gb * 255.0 - 128.0) / 127.0 * NOM_FLOW_VMAX;
}

// Flags da célula que contém xy (NOM_FLOW_*); 0 fora da grade ou desligada. A textura tem
// textureSize / uFlow.z células por tile (sprint 0030: NOMRender_setParam(9, s)).
int nomFlowFlags(vec2 xy) {
    if (!nomFlowOn()) return 0;
    int n = textureSize(uFlowTex, 0).x;
    ivec2 c = ivec2(floor((xy - uFlow.xy) * (float(n) / uFlow.z)));
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

// Quanto da névoa sobra em xy depois das clareiras dos tiros (1 = nada aberto). Miolo limpo até
// metade do raio, borda macia até o raio.
float nomClearing(vec2 xy) {
    float keep = 1.0;
    for (int i = 0; i < uClearCount; i++) {
        vec4 c = uClears[i];
        keep *= 1.0 - c.w * (1.0 - smoothstep(c.z * 0.5, c.z, length(xy - c.xy)));
    }
    return keep;
}

// Quanto de carro há em volta de xy (0..1, interpolado como nomFlowTree).
float nomFlowLow(vec2 xy) {
    vec2 g = xy - 0.5;
    vec2 f = fract(g);
    vec2 b = floor(g) + 0.5;
    float t00 = (nomFlowFlags(b) & NOM_FLOW_LOW) != 0 ? 1.0 : 0.0;
    float t10 = (nomFlowFlags(b + vec2(1, 0)) & NOM_FLOW_LOW) != 0 ? 1.0 : 0.0;
    float t01 = (nomFlowFlags(b + vec2(0, 1)) & NOM_FLOW_LOW) != 0 ? 1.0 : 0.0;
    float t11 = (nomFlowFlags(b + vec2(1, 1)) & NOM_FLOW_LOW) != 0 ? 1.0 : 0.0;
    return mix(mix(t00, t10, f.x), mix(t01, t11, f.x), f.y);
}

// Mundo (relativo) → tela iso: o inverso do nomIsoScreen sem a profundidade (IsoUtils.XToScreen/YToScreen).
vec2 nomWorldToIso(vec3 p) {
    float T = uCam.w;
    return vec2(32.0 * T * (p.x - p.y), 16.0 * T * (p.x + p.y) - 96.0 * T * p.z);
}

// Tela iso → gl_FragCoord deste jogador (pra amostrar uScene/uDepth noutro ponto).
vec2 nomIsoToFrag(vec2 iso) {
    return vec2((iso.x - uCam.x) / uCam.z, uViewport.w - (iso.y - uCam.y) / uCam.z) + uViewport.xy;
}

// Profundidade que o jogo daria a um ponto do mundo (a conta do nomWorldPos ao contrário): menor = mais perto.
float nomDepthOf(vec3 p) {
    return uDepthRef.x - uDepthRef.w * ((p.x + p.y) - uDepthRef.y) - 2.0 * uDepthRef.w * (p.z - uDepthRef.z);
}
