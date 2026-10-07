#version 330
// NOM: Noise of Mist — dissolve das peças (sprint 0018, ADR-016), vértice da peça com
// esqueleto (m_Static=false: véu, balaclava, cabelo, casca do Eco).
//
// Código original deste repositório, licença MIT. Do jogo vem só a interface: os atributos
// pelo índice do elemento (VertexBufferObject.BeginDraw), a paleta de 60 ossos
// (Shader.setMatrixPalette) e os uniforms que o Java manda (ModelViewProjection, UVScale,
// FinalScale, targetDepth, HighResDepthMultiplier). Carregado pelo nome do <m_Shader> da
// peça (ShaderManager.getOrCreateShader); o _static.vert é o das peças presas a osso.

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

// Peso de um osso; índice fora da paleta (peso zero com lixo) fica no último.
mat4 nomBone(float index, float weight)
{
    return MatrixPalette[int(clamp(index, 0.0, 59.0))] * weight;
}

// Projeção do jogo: escala final, profundidade puxada pro pivô no desenho em textura de
// chunk de resolução dobrada, e o deslocamento de profundidade do personagem.
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
    nomNormal = (skin * vec4(normal.xyz, 0.0)).xyz;
    gl_Position = nomProject(skin * vec4(vertex.xyz, 1.0));
}
