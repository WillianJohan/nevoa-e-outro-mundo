#version 330
// Névoa e Outro Mundo — dissolve das peças (sprint 0018, ADR-016), vértice da peça presa a
// um osso (m_Static=true: venda do Estalador, boca do Corredor).
//
// Código original deste repositório, licença MIT. Do jogo vem só a interface: os atributos
// pelo índice do elemento (VertexBufferObject.BeginDraw), a matriz do osso (transform) e os
// uniforms que o Java manda (ModelViewProjection, UVScale, FinalScale, targetDepth,
// HighResDepthMultiplier). O ShaderProgram monta "<nome>_static.vert" pras peças estáticas.

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
    nomUv = uv * UVScale;
    nomNormal = (transform * vec4(normal.xyz, 0.0)).xyz;
    gl_Position = nomProject(transform * vec4(vertex.xyz, 1.0));
}
