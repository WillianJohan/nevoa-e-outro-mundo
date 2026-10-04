# Spike — Shader próprio na névoa

| Campo | Valor |
|-------|-------|
| Status | backlog — precisa do jogo instalado |
| Branch | `spike/shader` (descartável) |
| GDD | [atmosphere.md#shader-spike](../../gdd/atmosphere.md#shader-spike), [ADR-004](../../architecture/adr-004-clima-antes-de-shader.md) |

## Pergunta

O Project Zomboid B42 carrega um shader GLSL vindo da pasta de um mod?

## Probe

1. Achar os shaders do jogo (`media/shaders/`) e como são carregados (log, decompilação para leitura).
2. Colocar um shader de vinheta + grão no mod, com mesmo nome/caminho, e ver se substitui.
3. Se substituir: ativar só na névoa.

Orçamento: ~2h. Passou disso sem resposta, a resposta é "não".

## Resultado

<sim / não, com evidência — e recomendação: promover a sprint ou arquivar>

## Sessões
