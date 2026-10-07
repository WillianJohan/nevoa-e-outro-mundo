#version 330
// NOM: Noise of Mist — dissolve das peças (sprint 0018, ADR-016), fragmento (o mesmo pras
// peças com esqueleto e as presas a osso).
//
// Código original deste repositório, licença MIT. Do jogo vem só a interface: o sampler
// Texture (o único ligado, Shader.startCharacter), Alpha, TintColour, AmbientColour e as
// cinco luzes (Shader.onProgramCompiled), e a saída gl_FragColor.
//
// O limiar do ruído é o Alpha do personagem, por jogador e por quadro (o único canal Lua →
// shader de peça): limiar = (Alpha − NOM_BAND) / (1 − NOM_BAND), igual ao
// shared/NOM_DissolveRules.lua. Com 1 a peça está inteira e sai como a do basicEffect; com
// 0 sumiu. A borda do que está queimando brilha em laranja, somada depois da luz. O Alpha
// não multiplica a cor (a peça fica opaca enquanto se desfaz).
//
// Sem fallback no motor: se isto não compilar, o ShaderProgram destrói o programa e a peça
// desenha com o programa 0. O fallback é a opção "Dissolve" desligada, que veste a peça sem
// shader (client/NOM_VariantLook.lua).

uniform sampler2D Texture;
uniform float Alpha;
uniform vec3 TintColour;
uniform vec3 AmbientColour;
uniform vec3 Light0Direction;
uniform vec3 Light0Colour;
uniform vec3 Light1Direction;
uniform vec3 Light1Colour;
uniform vec3 Light2Direction;
uniform vec3 Light2Colour;
uniform vec3 Light3Direction;
uniform vec3 Light3Colour;
uniform vec3 Light4Direction;
uniform vec3 Light4Colour;

in vec3 nomNormal;
in vec2 nomUv;

const float NOM_BAND = 0.85;
const float NOM_EDGE = 0.07;
const vec3 NOM_EMBER = vec3(1.0, 0.42, 0.08);

// Ruído sem textura: hash de ponto flutuante e ruído de valor suave.
float nomHash(vec2 p)
{
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

float nomNoise(vec2 p)
{
    vec2 cell = floor(p);
    vec2 f = fract(p);
    vec2 s = f * f * (3.0 - 2.0 * f);
    float a = nomHash(cell);
    float b = nomHash(cell + vec2(1.0, 0.0));
    float c = nomHash(cell + vec2(0.0, 1.0));
    float d = nomHash(cell + vec2(1.0, 1.0));
    return mix(mix(a, b, s.x), mix(c, d, s.x), s.y);
}

// 0..0,999 espalhado pela faixa toda: manchas grandes com borda picada.
float nomBurn(vec2 p)
{
    float v = 0.65 * nomNoise(p * 9.0) + 0.35 * nomNoise(p * 31.0 + 7.3);
    return smoothstep(0.18, 0.82, v) * 0.999;
}

vec3 nomDiffuse(vec3 n, vec3 dir, vec3 tint)
{
    return tint * max(dot(n, normalize(dir)), 0.0);
}

void main()
{
    vec4 tex = texture2D(Texture, nomUv);
    float t = clamp((Alpha - NOM_BAND) / (1.0 - NOM_BAND), 0.0, 1.0);
    float n = nomBurn(nomUv);
    if (tex.a < 0.01 || n >= t) {
        discard;
    }
    vec3 nrm = normalize(nomNormal);
    vec3 light = AmbientColour + nomDiffuse(nrm, Light0Direction, Light0Colour)
        + nomDiffuse(nrm, Light1Direction, Light1Colour) + nomDiffuse(nrm, Light2Direction, Light2Colour)
        + nomDiffuse(nrm, Light3Direction, Light3Colour) + nomDiffuse(nrm, Light4Direction, Light4Colour);
    vec3 col = tex.rgb * TintColour * min(light, vec3(1.0));
    float edge = (1.0 - smoothstep(0.0, NOM_EDGE, t - n)) * (1.0 - step(1.0, t));
    col = mix(col, NOM_EMBER * 1.4, edge);
    gl_FragColor = vec4(clamp(col, 0.0, 1.0), tex.a);
}
