#version 330
// NOM: Noise of Mist — brasa permanente na casca BoilerSuit (sprint 0067).
// Textura já traz fissuras com alfa; o Alpha do personagem (0,92–1,0) modula o
// brilho do pulso. Núcleo quente só no pico. Código original, licença MIT.

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

const float NOM_A0 = 0.92;
const float NOM_A1 = 1.0;
const vec3 NOM_DEEP = vec3(0.369, 0.102, 0.055); // #5E1A0E
const vec3 NOM_LIVE = vec3(0.761, 0.282, 0.110); // #C2481C
const vec3 NOM_CORE = vec3(1.0, 0.690, 0.376);   // #FFB060

vec3 nomDiffuse(vec3 n, vec3 dir, vec3 tint)
{
    return tint * max(dot(n, normalize(dir)), 0.0);
}

void main()
{
    vec4 tex = texture2D(Texture, nomUv);
    // ≥70% transparente: só fissuras/costuras pintadas
    if (tex.a < 0.08) {
        discard;
    }
    float pulse = clamp((Alpha - NOM_A0) / (NOM_A1 - NOM_A0), 0.0, 1.0);
    // 0 → 55%, 1 → 100%
    float inten = 0.55 + 0.45 * pulse;
    vec3 nrm = normalize(nomNormal);
    vec3 light = AmbientColour + nomDiffuse(nrm, Light0Direction, Light0Colour)
        + nomDiffuse(nrm, Light1Direction, Light1Colour) + nomDiffuse(nrm, Light2Direction, Light2Colour)
        + nomDiffuse(nrm, Light3Direction, Light3Colour) + nomDiffuse(nrm, Light4Direction, Light4Colour);
    vec3 base = tex.rgb * TintColour * min(light, vec3(1.0));
    // Gradiente da fissura: carvão (tex) → funda → viva; núcleo só no pico
    float hot = smoothstep(0.25, 0.95, tex.a) * inten;
    vec3 col = mix(base, NOM_DEEP, hot * 0.55);
    col = mix(col, NOM_LIVE, hot * hot * 0.85);
    if (inten >= 0.85) {
        float core = smoothstep(0.85, 1.0, inten) * smoothstep(0.7, 1.0, tex.a);
        col = mix(col, NOM_CORE, core * 0.9);
    }
    gl_FragColor = vec4(clamp(col, 0.0, 1.0), tex.a);
}
