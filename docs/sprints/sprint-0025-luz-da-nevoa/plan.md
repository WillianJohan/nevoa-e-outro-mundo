# Luz e volume na névoa (mod3) — Plano

**Goal:** A névoa do mod3 deixa de parecer uma placa chapada: vira rolos com silhueta, topo claro e
barriga escura (sombra própria) e bordas desfiadas. É o teste barato antes de decidir pela simulação 3D
na GPU: se com luz e rolos ainda parecer chapado, o problema é a simulação.

**Origem:** o Johan mandou a comparação do Batman Arkham Knight (GameWorks, fumaça interativa) e pediu
uma névoa "viva", com física convincente. Discutimos três caminhos (engrossar a simulação 2D, simulação
na GPU, volume 3D); ele quis primeiro ver uma melhoria rápida de luz e sombra, pra comparar.

**Architecture:** Só shader (`NOM_VolFog.frag`), sem mexer na simulação. A densidade de cada ponto do
raio passa a ter:

- **altura local da camada** tirada de um ruído "fofo" (estilo cúmulo) levado pela velocidade do
  fluido; onde o fluido acumula (densidade > 1), os rolos sobem mais;
- **sombra própria:** de cada amostra, 2 passos curtos rumo ao céu medem a névoa por cima; a luz cai
  com `exp(-profundidade óptica)`, com um mínimo de luz ambiente;
- **fiapos:** uma terceira oitava de ruído (1–2 tiles) corroendo a borda dos rolos.

O visual antigo continua no shader, atrás do `NOMRender_setParam(5, 0)`; `(5, 1)` é o novo e o padrão
(`RenderContext`: `luaParams[PARAM_LOOK] = 1`).

**Tech Stack:** GLSL 330, Java 25, Python 3 (contrato), `glslangValidator`.

## Global Constraints

- Nada no mod3 pode derrubar o jogo (a mudança é só de shader e de um valor padrão).
- A cor continua vindo do clima (`uFog.yzw`): a névoa vermelha segue vermelha.
- Custo: ~3× as contas de densidade por pixel (1 da densidade + 2 da sombra). Medir no jogo pelo FPS
  com o param 5 em 0 e 1.

## Tarefas

- [x] **Contrato (teste primeiro):** `tests/test_mod3_depth.py` confere que `PARAM_LOOK = 5` no Java,
      que o padrão é 1 e que o shader lê o componente certo de `uParams` (`uParams[1].y`).
- [x] **Java:** `RenderContext.PARAM_LOOK = 5`, padrão 1.
- [x] **Shader:** `densityLook` (rolos + fiapos), `shadowOD` (2 passos rumo à luz), laço de luz com
      topo claro e barriga escura; o caminho antigo intacto quando `uParams[1].y < 0.5`.
- [x] **Testes verdes** (`./run-tests.sh`, o shader compila no `glslangValidator`), build, merge, push,
      `dev-sync`.
- [x] **Docs:** README da sprint com o roteiro de comparação; HANDOFF e `docs/sprints/README.md`.
