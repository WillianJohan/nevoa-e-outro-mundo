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
