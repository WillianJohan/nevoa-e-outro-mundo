# Névoa fluida (mod3) — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A névoa do mod3 se comporta como um líquido: contorna parede, árvore e carro, acumula nos abertos, escorre por porta e janela abertas e é empurrada por quem anda, deixando rastro. De quebra, o visual fica mais denso no chão, mais cinza e suave em cima, e envolve a base das árvores.

**Architecture:** Um núcleo puro em Java (`FlowGrid`, sem API do jogo) roda uma simulação 2D de fluido numa grade de 128×128 tiles em volta do personagem da câmera. A grade é escalonada: a velocidade mora nas faces entre tiles, então uma parede fina (borda N/W do square) é só uma face fechada. A densidade anda por **fluxo nas faces** (upwind conservativo), então nada atravessa face fechada, por construção. Um adaptador (`Flow`) monta a máscara na thread principal (poucas linhas por quadro), injeta vento e impulsos, avança a 20 Hz e publica uma textura RGBA8, que a thread de render sobe e o `NOM_VolFog` amostra.

**Tech Stack:** Java 25 (`--release 25`, openjdk do brew), LWJGL 3 do jogo (GL 3.3), GLSL 330, Python 3 (testes de contrato), `glslangValidator` (compila o shader no teste).

**Spec:** [docs/HANDOFF.md](../../HANDOFF.md), seção "Próximo: névoa fluida no mod3"; [spike da volumétrica](../spike-volumetrica/README.md).

## Evidência (bytecode B42.21, `projectzomboid.jar`, `javap -c`)

- `IsoGridSquare.isBlockedTo(IsoGridSquare)` = `isBlockedTo(o, cellGetSquare)` = `isWallTo || isWindowBlockedTo || isDoorBlockedTo || isStairBlockedTo` (0–40).
- `isWallTo`, `isWindowBlockedTo` e `isDoorBlockedTo` passam por `isEdgeElementTo` (0–158): para vizinho a oeste testa a borda `WEST` deste square **e** a `EAST` do vizinho; idem N/S. Os predicados são `isWall(edge)`, `isBlockedWindow(edge)` e `isBlockedDoor(edge)` (BootstrapMethods 6, 14, 16).
- `isWall(GridSquareEdgeFacingDirection)` 0–82: `collideN`/`collideW` **e não** `isWindow`. Batente de porta não tem `collideN`/`collideW` (o jogador passa).
- `IsoDoor.isBlocked()` 0–19: `!isOpen() || isBarricaded()`. `IsoWindow.isBlocked()` 0–26: bloqueia se não está quebrada e fechada, ou se está barricada. Ou seja: porta e janela **abertas** (ou quebradas) passam; fechadas ou barricadas bloqueiam.
- `IsoGridSquare.isSolid()` = flag `solid`; `isOutside()` = flag `exterior`; `HasTree()` = campo `hasTree`.
- `IsoGridSquare.getVehicleContainer()` 0–207: varre os chunks em ±4 tiles e chama `BaseVehicle.isIntersectingSquare(x, y, z)`. Custo O(carros no chunk).
- `IsoCell.getGridSquare(int, int, int)`: `null` fora do que está carregado.
- `GameTime.isGamePaused()` (estático); `ClimateManager.getWindAngleRadians()`, `getWindIntensity()`.
- `org.lwjgl.BufferUtils` está no `projectzomboid.jar`.

## Global Constraints

- Nada no mod3 pode derrubar o jogo: todo caminho chamado do patch ou da thread de render captura `Throwable`, loga `[NOM-Render] ERRO` e se desliga (o fluido se desliga sozinho, sem levar a névoa junto).
- Método do mod3 chamado de dentro de `@Patch` é `public` (`tests/test_mod3_depth.py`).
- Meta de custo: passo da simulação < 1 ms na CPU em 128×128; 20 Hz, desacoplado do FPS.
- Nada copiado de outros mods. Comentários e docs em português BR.
- O jar é assinado por `scripts/build-mod3.sh` (chave em `~/.signing/`, fora do repo).

## Arquivos

| Arquivo | Papel |
|---|---|
| `mod3/java/nom/render/FlowGrid.java` (novo) | núcleo puro: grade, máscara, passo, rolagem, impulso, textura |
| `mod3/java/nom/render/Flow.java` (novo) | adaptador: máscara do `IsoCell`, vento, impulsos, 20 Hz, publicação; upload GL |
| `mod3/java/nom/render/RenderContext.java` | chama o `Flow` no quadro e no render; uniforms novos |
| `mod3/42/media/shaders/NOM_RenderContext.glsl` | contrato: `uFlowTex`, `uFlow`, helpers `nomFlow*` |
| `mod3/42/media/shaders/NOM_VolFog.frag` | densidade do fluido, flow map, visual novo, debug 5–7 |
| `tests/java/FlowGridTest.java` (novo) | testes do núcleo |
| `tests/test_mod3_flow.sh` (novo) | compila e roda o teste Java; compila os shaders com `glslangValidator` |
| `tests/test_mod3_depth.py` | contrato Java ↔ GLSL (flags e escala da velocidade) |
| `run-tests.sh` | inclui `tests/test_mod3_flow.sh` |

## Interfaces

`FlowGrid` (público, `nom.render`):

- `FlowGrid(int n)`; `int n`; `int x0, y0` (tile do mundo da célula (0,0)).
- Flags: `F_SOLID = 1`, `F_TREE = 2`, `F_INDOOR = 4`; na textura, mais `T_WALL_W = 8`, `T_WALL_N = 16`. `VEL_MAX = 4f` (tiles/s, escala da velocidade na textura).
- `reset(int x0, int y0)`: densidade = ambiente, faces abertas, velocidade e pressão zeradas, toda célula "nova".
- `setCell(int i, int j, int flags)`: se a célula era nova e é interior, a densidade vai a 0.
- `setOpenW(int i, int j, boolean)`, `setOpenN(int i, int j, boolean)`: faces oeste e norte da célula.
- `scroll(int newX0, int newY0)`: rola preservando o que já estava no mundo.
- `impulse(float wx, float wy, float vx, float vy, float radius)`: coordenadas de mundo.
- `step(float dt)`; `density(i, j)`, `setDensity(i, j, v)`, `faceU(i, j)`, `faceV(i, j)`, `totalMass()`.
- Parâmetros públicos: `ambient`, `windX`, `windY`, `windRelax`, `outdoorRefill`, `indoorDecay`, `edgeRefill`, `diffusion`, `iterations`.
- `writeRGBA(byte[] out)`: `r` densidade, `gb` velocidade no centro (128 ± 127·v/`VEL_MAX`), `a` flags.

GLSL (cabeçalho): `uniform sampler2D uFlowTex` (unidade 6); `uniform vec4 uFlow` = (x0, y0 relativos a `uOrigin`, n, 1 = ligado); `nomFlowDensity(xy)`, `nomFlowVel(xy)`, `nomFlowFlags(xy)`, `nomFlowTree(xy)`.

Console: `NOMRender_setParam(4, 0)` desliga a simulação, `(4, 1)` liga (padrão). Debug: `NOMRender_setParam(1, 5)` obstáculos, `(1, 6)` densidade, `(1, 7)` velocidade.

## Tarefas

### Tarefa 1: núcleo `FlowGrid` (TDD)

**Files:** criar `mod3/java/nom/render/FlowGrid.java`, `tests/java/FlowGridTest.java`, `tests/test_mod3_flow.sh`; mudar `run-tests.sh`.

- [ ] Escrever `tests/test_mod3_flow.sh` (javac `--release 25` do `FlowGrid.java` + teste num diretório temporário, `java -ea`) e os testes:
  - **caixa fechada**: caixa 6×6 com as quatro bordas fechadas, interior 0, vento forte e impulsos em volta, 400 passos → interior < 1e-6 e velocidade nas faces fechadas = 0;
  - **fresta de 1 tile**: a mesma caixa com uma face aberta e o vento entrando → densidade média do interior > 0,2;
  - **rolagem**: densidade aleatória, `scroll(+5, −3)` → célula de mundo igual; célula nova = ambiente; rolagem maior que a grade = `reset`;
  - **impulso**: bolha de densidade sem vento, impulso +x → centróide anda > 0,3 tile em x e < 0,1 em y; quem anda em densidade uniforme deixa rastro (densidade atrás < ambiente);
  - **massa**: domínio fechado (bordas da grade fechadas), sem fonte → massa total conservada (erro relativo < 1e-3);
  - **estável**: velocidade aleatória forte → densidade em [0, 1,5], sem NaN;
  - **interior novo**: célula nova marcada interior começa em 0; célula já simulada não zera;
  - **contorna**: bloco sólido no meio, vento +x → velocidade nas faces do bloco = 0 e o fluxo ao lado do bloco é mais rápido que o vento;
  - **textura**: `writeRGBA` codifica densidade, velocidade e flags; célula sólida recebe a média dos vizinhos abertos;
  - **custo**: 128×128 com obstáculos, 200 passos depois de aquecer → média impressa; falha acima de 3 ms (meta 1 ms).
- [ ] Rodar e ver falhar (classe não existe).
- [ ] Implementar o mínimo que passa.
- [ ] Rodar `./run-tests.sh`: tudo verde. Commit.

### Tarefa 2: contrato GLSL e shader

**Files:** `NOM_RenderContext.glsl`, `NOM_VolFog.frag`, `tests/test_mod3_depth.py`, `tests/test_mod3_flow.sh`.

- [ ] Teste de contrato em `test_mod3_depth.py`: `VEL_MAX` e as flags do `FlowGrid.java` iguais às constantes `NOM_FLOW_*` do cabeçalho; `tests/test_mod3_flow.sh` compila cabeçalho + cada passe com `glslangValidator` (como o Java monta: cabeçalho, `#line 1`, passe). Ver falhar.
- [ ] Cabeçalho: uniforms e helpers. Shader: densidade × fluido, flow map de duas fases, camada densa no chão e mais cinza e fina em cima (cor do clima), teto de opacidade, envelope das árvores, debug 5–7.
- [ ] Testes verdes. Commit.

### Tarefa 3: adaptador `Flow` e ligação no `RenderContext`

**Files:** criar `mod3/java/nom/render/Flow.java`; mudar `RenderContext.java`.

- [ ] `Flow.update(IsoCell, IsoCamera.FrameState)` (thread principal, só `playerIndex == 0`): liga/desliga por `luaParams[4]`, rola ou reseta (mudou de andar), monta 8 linhas da máscara por quadro, vento do clima, impulsos de jogadores e zumbis a até 40 tiles (velocidade pela posição anterior de cada um), passos de 1/20 s (no máximo 2 por quadro; pausa congela), publica sob trava. Log de custo a cada 600 passos.
- [ ] `Flow.prepare()` (thread de render): cria a textura, sobe a versão nova com `GL_PIXEL_UNPACK_BUFFER` desligado, prende na unidade 6. `RenderContext` salva e restaura a unidade 6 e passa `uFlowTex`/`uFlow`.
- [ ] Erro no `Flow` desliga só o fluido (`[NOM-Render] ERRO no fluido`); a névoa segue com densidade 1.
- [ ] `scripts/build-mod3.sh` compila e assina. Testes verdes. Commit.

### Tarefa 4: docs, merge e sync

- [ ] README da sprint (critérios, roteiro no jogo), roadmap, HANDOFF (tabela de comandos e próximo passo).
- [ ] `./run-tests.sh` verde, merge na `main`, push, `scripts/build-mod3.sh && scripts/dev-sync.sh`.
