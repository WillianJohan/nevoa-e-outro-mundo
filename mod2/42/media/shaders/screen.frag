#version 330
// Névoa e Outro Mundo — Shader (mod NevoaEOutroMundo_Shader, sprint 0013).
//
// Substitui o pós-processo de tela do jogo (programa "screen", WeatherShader).
// Código original deste repositório, licença MIT. Do jogo vem só a interface: os
// nomes e tipos dos uniforms que o WeatherShader manda (bytecode
// WeatherShader.onCompileSuccess/startRenderThread), a entrada vUV do screen.vert
// vanilla e a saída gl_FragColor. O que o jogo espera desta etapa foi refeito à mão:
// a dessaturação do clima, o círculo do modo de busca (forrageamento), a visão
// noturna, o efeito de bêbado, o desfoque de quem não enxerga bem e o tom de base.
//
// Na névoa o mod principal escreve no SearchMode do jogador, com o modo de busca
// desligado (VarInfo.x = 0) e o gradiente valendo NOM_MARKER (ADR-013):
//   SearchMode.x = névoa, SearchMode.y = chiado do Sem-rosto,
//   ParamInfo.w = névoa vermelha, VarInfo.y = pulso do grito da Carpideira (0..2).
// Com isso: aberração cromática, grão de verdade, distorção e bordas desfocadas.
// Sprint 0018 (ADR-016): o gradiente vale NOM_MARKER + bloom·NOM_BLOOM_SCALE, com o bloom
// da opção do jogador (0..2); o canal fica tomado também fora da névoa quando há bloom.
// Bloom de uma passada: o claro da cena num anel em volta, somado por cima, mais forte e
// com o limiar mais baixo na névoa, avermelhado na vermelha. Curto (uma passada só).
//
// Limite: o jogo compila este arquivo uma vez por sessão, na primeira carga de
// mundo (spike do shader). Ligou ou desligou o mod: reinicie o jogo.

uniform sampler2D DIFFUSE;
uniform vec2 TextureSize;
uniform float timer;
uniform float timerWrap;
uniform float NightValue;
uniform float NightVisionGoggles;
uniform float DesaturationVal;
uniform vec4 SearchMode;
uniform vec4 ScreenInfo;
uniform vec4 ParamInfo;
uniform vec4 VarInfo;
uniform float DrunkFactor;
uniform float BlurFactor;

in vec2 vUV;

const float NOM_MARKER = 13.0;
const float NOM_BLOOM_SCALE = 0.25;
const vec3 NOM_REC709 = vec3(0.2126, 0.7152, 0.0722);
const float NOM_TAU = 6.2831853;

// Tamanho da textura da cena em texels: TextureSize é o tamanho real do FBO
// (Core.getOffscreenTrueWidth/Height). O bgl_RenderedTexture* do jogo é a área do
// jogador, que muda com o zoom: não serve pro texel.
vec2 nomSceneSize()
{
    return max(TextureSize, vec2(1.0));
}

// Leitura suave da cena: B-spline cúbica com quatro leituras bilineares
// (pesos da spline juntados de dois em dois). Com zoom a cena é ampliada e a
// leitura simples serrilha.
vec3 nomSample(vec2 uv)
{
    vec2 size = nomSceneSize();
    vec2 p = uv * size - 0.5;
    vec2 f = fract(p);
    vec2 base = p - f;
    vec2 f2 = f * f;
    vec2 f3 = f2 * f;
    vec2 wa = (1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0;
    vec2 wb = (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0;
    vec2 wc = (1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0;
    vec2 wd = f3 / 6.0;
    vec2 lo = wa + wb;
    vec2 hi = wc + wd;
    vec2 at0 = (base - 0.5 + wb / lo) / size;
    vec2 at1 = (base + 1.5 + wd / hi) / size;
    vec3 s00 = texture2D(DIFFUSE, vec2(at0.x, at0.y)).rgb;
    vec3 s10 = texture2D(DIFFUSE, vec2(at1.x, at0.y)).rgb;
    vec3 s01 = texture2D(DIFFUSE, vec2(at0.x, at1.y)).rgb;
    vec3 s11 = texture2D(DIFFUSE, vec2(at1.x, at1.y)).rgb;
    return mix(mix(s00, s10, hi.x), mix(s01, s11, hi.x), hi.y);
}

vec3 nomGrey(vec3 c, float k)
{
    return mix(c, vec3(dot(c, NOM_REC709)), clamp(k, 0.0, 1.0));
}

// Contraste em torno de 0.4, o meio-tom em que o jogo apoia o dele.
vec3 nomPunch(vec3 c, float k)
{
    return (c - vec3(0.4)) * k + vec3(0.4);
}

// Ruído por pixel, sem textura: hash de ponto flutuante.
float nomHash(vec2 p)
{
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

// Média da cena num anel de 12 pontos em dois raios em volta de uv, misturada
// em c pela quantidade k.
vec3 nomSoft(vec3 c, vec2 uv, float k)
{
    if (k <= 0.0) {
        return c;
    }
    vec2 px = 1.0 / nomSceneSize();
    vec3 acc = c;
    for (int i = 0; i < 12; i++) {
        float a = float(i) * (NOM_TAU / 12.0);
        float r = (i - (i / 2) * 2 == 0) ? 5.0 : 11.0;
        acc += texture2D(DIFFUSE, uv + vec2(cos(a), sin(a)) * r * px).rgb;
    }
    return mix(c, acc / 13.0, clamp(k, 0.0, 1.0));
}

// Claro da cena acima do limiar num anel de 16 pontos em dois raios em volta de uv.
vec3 nomBloom(vec2 uv, float threshold)
{
    vec2 px = 1.0 / nomSceneSize();
    vec3 acc = vec3(0.0);
    for (int i = 0; i < 16; i++) {
        float a = float(i) * (NOM_TAU / 16.0) + 0.3;
        float r = (i - (i / 2) * 2 == 0) ? 7.0 : 16.0;
        vec3 c = texture2D(DIFFUSE, uv + vec2(cos(a), sin(a)) * r * px).rgb;
        float l = dot(c, NOM_REC709);
        acc += c * (max(l - threshold, 0.0) / max(l, 0.001));
    }
    return acc / 16.0;
}

// Máscara do modo de busca: 0 dentro do raio (em tiles) em volta do personagem,
// 1 fora, com borda de largura feather (px). O centro segue a câmera deslocada
// pelo clique direito (ScreenInfo.zw) e sobe ~56 px de tela (a altura do
// personagem), como o jogo faz.
float nomRing(float radiusTiles, float feather)
{
    float zoom = max(ParamInfo.x, 0.0001);
    vec2 fromCorner = gl_FragCoord.xy - SearchMode.zw;
    fromCorner.y += 56.0 / zoom;
    vec2 q = fromCorner * zoom / max(ScreenInfo.xy, vec2(1.0));
    vec2 centre = vec2(0.5 - ScreenInfo.z / max(ScreenInfo.x, 1.0), 0.5 + ScreenInfo.w / max(ScreenInfo.y, 1.0));
    float d = length(q - centre) * ScreenInfo.x;
    float r = radiusTiles * ParamInfo.y;
    return smoothstep(max(0.0, r - feather), r + feather, d);
}

// Distância do centro da tela, corrigida pela proporção (0 no meio, ~0.9 no canto).
float nomEdge(vec2 uv)
{
    float aspect = ScreenInfo.x / max(ScreenInfo.y, 1.0);
    return length((uv - 0.5) * vec2(aspect, 1.0));
}

vec3 nomNightVision(vec3 c, float grain)
{
    float l = pow(clamp(dot(c, NOM_REC709), 0.0, 1.0), 0.6);
    l = clamp(l * (1.0 + 0.6 * NightValue) * 0.5 + 0.3 + grain * 0.08, 0.0, 1.0);
    return vec3(0.04, clamp(l * 1.5, 0.0, 1.0), 0.04);
}

void main()
{
    vec2 uv = vUV;
    float frame = floor(timer);
    float clock = timer / 30.0;

    float tag = ParamInfo.z * 2.0 / max(ParamInfo.y, 1.0);
    bool ours = VarInfo.x == 0.0 && tag > NOM_MARKER - 0.01 && tag < NOM_MARKER + 2.0 * NOM_BLOOM_SCALE + 0.01;
    float bloom = ours ? clamp((tag - NOM_MARKER) / NOM_BLOOM_SCALE, 0.0, 2.0) : 0.0;
    float fog = ours ? clamp(SearchMode.x, 0.0, 2.0) : 0.0;
    float hiss = ours ? clamp(SearchMode.y, 0.0, 2.0) : 0.0;
    float red = ours ? clamp(ParamInfo.w, 0.0, 2.0) : 0.0;
    float pulse = ours ? clamp(VarInfo.y, 0.0, 2.0) : 0.0;

    // distorção: faixas de 3 px que escorregam com o chiado; onda lenta na névoa
    float band = floor(gl_FragCoord.y / 3.0);
    float slip = (nomHash(vec2(band, frame)) - 0.5) * step(0.93, nomHash(vec2(band * 0.37, floor(frame * 0.5))));
    uv.x += slip * 0.006 * hiss + sin(uv.y * 23.0 + clock * 1.7) * 0.0012 * fog;

    // bêbado: a cena balança devagar, mais forte com o zoom de perto
    if (0.0 < DrunkFactor) {
        float zoom = max(ParamInfo.x, 0.0001);
        float t = timer / max(timerWrap * 9.0, 0.0001);
        uv += vec2(cos(t * 0.8), sin(t * 0.47)) * (0.005 * DrunkFactor / zoom);
    }

    // aberração cromática: vermelho pra fora, azul pra dentro, maior nas bordas
    float split = 0.0025 * fog + 0.005 * hiss + 0.002 * red + 0.006 * pulse;
    vec3 col;
    if (split > 0.0) {
        vec2 away = (uv - 0.5) * split;
        col = vec3(nomSample(uv + away).r, nomSample(uv).g, nomSample(uv - away).b);
    } else {
        col = nomSample(uv);
    }

    if (0.0 < DrunkFactor) {
        col = nomSoft(col, uv, DrunkFactor * smoothstep(0.25, 0.75, nomEdge(vUV)));
    }
    if (0.0 < BlurFactor) {
        col = nomSoft(col, uv, BlurFactor * smoothstep(0.12, 0.42, nomEdge(vUV)));
    }

    float grain = nomHash(gl_FragCoord.xy + vec2(frame * 17.0, frame * 31.0)) - 0.5;

    if (NightVisionGoggles >= 0.5) {
        gl_FragColor = vec4(nomNightVision(col, grain), 1.0);
        return;
    }

    if (VarInfo.x != 0.0) {
        // modo de busca do jogo (forrageamento, ou a vinheta da névoa do mod sem este
        // shader): desfoque, cinza e escuro fora do círculo
        float ring = nomRing(SearchMode.y, ParamInfo.z);
        col = nomSoft(col, uv, ring * SearchMode.x);
        col = nomGrey(col, max(DesaturationVal, ring * ParamInfo.w));
        col *= 1.0 - VarInfo.y * ring;
    } else {
        col = nomGrey(col, DesaturationVal);
        if (fog > 0.0) {
            // bordas da névoa: desfocam e perdem cor (o escuro é a vinheta do overlay)
            float rim = smoothstep(0.30, 0.85, nomEdge(vUV)) * min(fog, 1.0);
            col = nomSoft(col, uv, rim * 0.5);
            col = nomGrey(col, rim * 0.45 * (1.0 - 0.6 * min(red, 1.0)));
            col = mix(col, col * vec3(1.2, 0.5, 0.45), rim * min(red, 1.0) * 0.7);
        }
    }

    if (bloom > 0.0) {
        float thick = min(fog, 1.0);
        float reddish = min(red, 1.0);
        vec3 glow = nomBloom(uv, mix(0.72, 0.55, thick));
        glow = mix(glow, glow * vec3(1.3, 0.55, 0.45), reddish * 0.6);
        col += glow * bloom * (0.35 + 0.45 * thick + 0.25 * reddish);
    }

    col = nomPunch(nomGrey(clamp(col, 0.0, 1.0), 0.1), 1.2);
    float shade = 1.0 - clamp(dot(col, NOM_REC709), 0.0, 1.0);
    col += grain * (0.0015 + 0.06 * min(fog, 1.0) + 0.03 * min(hiss, 1.0)) * (0.4 + shade * shade);

    gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
