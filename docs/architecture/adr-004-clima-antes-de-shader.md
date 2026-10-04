# ADR-004 — Visual dark via clima; shader é spike

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-04 |

## Contexto

O PZ renderiza em OpenGL. No Linux nativo, ReShade e vkBasalt não funcionam
(vkBasalt é só Vulkan). Mod do Workshop não consegue instalar ReShade no PC do
jogador. Não há confirmação de que o B42 carregue GLSL vindo da pasta de um mod.

## Decisão

A base do visual dark é o **`ClimateManager` via Lua**: luz global,
dessaturação, tint e densidade de névoa. Funciona pra todo mundo e acompanha o
estado do servidor.

Shader próprio (vinheta + grão na névoa) é um **spike separado**, que não
bloqueia nenhuma sprint. Se funcionar, vira camada extra.

## Alternativas recusadas

| Alternativa | Por que não |
|---|---|
| Preset ReShade | Fora do controle do mod; não funciona no Linux nativo. |
| Trocar texturas na névoa | Muito asset, e o clima resolve a maior parte. |

## Consequências

- O mod nunca depende de shader pra ter o tom certo.
- O spike precisa do jogo instalado na máquina de desenvolvimento.
