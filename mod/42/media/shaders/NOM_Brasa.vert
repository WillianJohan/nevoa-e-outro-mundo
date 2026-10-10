#version 330
// NOM: Noise of Mist — brasa permanente (sprint 0067), vértice skinned.
// Tremida de ar quente ≤ 0,6% da altura, só cintura pra cima; fase via TintColour.r.
// Código original, licença MIT. Interface idêntica ao NOM_Dissolve.vert.

layout (location = 0) in vec4 vertex;
layout (location = 1) in vec4 normal;
layout (location = 2) in vec4 boneWeights;
layout (location = 3) in vec4 boneIndices;
layout (location = 4) in vec2 uv;

out vec3 nomNormal;
out vec2 nomUv;

uniform mat4 ModelViewProjection;
uniform mat4 MatrixPalette[60];
uniform vec2 UVScale = vec2(1.0, 1.0);
uniform float FinalScale = 1.0;
uniform float targetDepth = 0.5;
uniform float HighResDepthMultiplier = 0.0;
uniform float Alpha;
uniform vec3 TintColour;

mat4 nomBone(float index, float weight)
{
    return MatrixPalette[int(clamp(index, 0.0, 59.0))] * weight;
}

vec4 nomProject(vec4 p)
{
    vec4 o = ModelViewProjection * vec4(p.xyz * FinalScale, p.w);
    float pivot = (ModelViewProjection * vec4(0.0, 0.0, 0.0, 1.0)).z;
    o.z = mix(o.z, pivot, HighResDepthMultiplier) + 2.0 * targetDepth - 1.0;
    return o;
}

void main()
{
    mat4 skin = nomBone(boneIndices.x, boneWeights.x) + nomBone(boneIndices.y, boneWeights.y)
        + nomBone(boneIndices.z, boneWeights.z) + nomBone(boneIndices.w, boneWeights.w);
    nomUv = uv * UVScale;
    vec4 local = vec4(vertex.xyz, 1.0);
    // y local alto = torso/cabeça; 0,006 ≈ 0,6% da altura do corpo
    float upper = smoothstep(0.35, 0.75, clamp(vertex.y * 0.5 + 0.5, 0.0, 1.0));
    float wave = sin(uv.y * 38.0 + TintColour.r * 62.0) * 0.006 * upper;
    local.xyz += normalize(normal.xyz + vec3(0.001)) * wave;
    nomNormal = (skin * vec4(normal.xyz, 0.0)).xyz;
    gl_Position = nomProject(skin * local);
}
