#version 330
// NOM: Noise of Mist — brasa permanente (sprint 0067), vértice static (preso a osso).
// Mesma tremida sutil do NOM_Brasa.vert. Código original, licença MIT.

layout (location = 0) in vec4 vertex;
layout (location = 1) in vec4 normal;
layout (location = 2) in vec2 uv;

out vec3 nomNormal;
out vec2 nomUv;

uniform mat4 ModelViewProjection;
uniform mat4 transform;
uniform vec2 UVScale = vec2(1.0, 1.0);
uniform float FinalScale = 1.0;
uniform float targetDepth = 0.5;
uniform float HighResDepthMultiplier = 0.0;
uniform float Alpha;
uniform vec3 TintColour;

vec4 nomProject(vec4 p)
{
    vec4 o = ModelViewProjection * vec4(p.xyz * FinalScale, p.w);
    float pivot = (ModelViewProjection * vec4(0.0, 0.0, 0.0, 1.0)).z;
    o.z = mix(o.z, pivot, HighResDepthMultiplier) + 2.0 * targetDepth - 1.0;
    return o;
}

void main()
{
    nomUv = uv * UVScale;
    vec4 local = vec4(vertex.xyz, 1.0);
    float upper = smoothstep(0.35, 0.75, clamp(vertex.y * 0.5 + 0.5, 0.0, 1.0));
    float wave = sin(uv.y * 38.0 + TintColour.r * 62.0) * 0.006 * upper;
    local.xyz += normalize(normal.xyz + vec3(0.001)) * wave;
    nomNormal = (transform * vec4(normal.xyz, 0.0)).xyz;
    gl_Position = nomProject(transform * local);
}
