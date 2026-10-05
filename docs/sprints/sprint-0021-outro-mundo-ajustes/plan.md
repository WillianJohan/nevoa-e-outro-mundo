# Outro Mundo: correções vistas no jogo — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O chão do Outro Mundo deixa de cobrir o jogador, de flutuar em cima do telhado e de ler como xadrez; as paredes ficam desligadas com o porquê escrito.

**Architecture:** Sem sistema novo. (1) `NOM_DressingRules` perde o musgo (todo `d_plants_1_*` é planta em pé) e fica só com decalques chatos que, no deslocamento do `IsoMarker`, não alcançam um personagem de tile vizinho (tabela medida no pack por `scripts/audit_floor_sprites.py`, só leitura). (2) Sujeira sai das camadas: vem de um ruído em manchas, de sprites parciais, num marcador próprio com alfa menor. (3) `NOM_FogOverlays` só veste square que o jogador vê no andar dele: fora de prédio, só square de fora e fora da sombra de prédio; dentro, o prédio dele e o de fora. Muda o contexto → fade pela reserva. (4) O tile do jogador fica sem marcador (todo tick). (5) Paredes: ficam desligadas; ADR-015 emendada com a evidência.

**Tech Stack:** Lua 5.1 (Kahlua no jogo, luajit nos testes), Python 3 + Pillow (só o script de auditoria, leitura do pack), `./run-tests.sh`.

**Spec:** [README da sprint](README.md), brief de 05/10 (prints 6, 7, 9 e 10 do Johan), [ADR-015](../../architecture/adr-015-outro-mundo-sangrento.md), [pz-api-notes §16](../../architecture/pz-api-notes.md#16-outro-mundo-sangrento-sprint-0015).

## Evidência (bytecode B42.21, pz-api-notes §16.5)

- `IsoMarker.setPos(III)`: `x = i + 0.5`, `y = j + 0.5`, `z = k + 0.01`; é o único setter de posição
  (o `init` chama ele). `IsoSprite.renderTextureWithDepth`: quad do tamanho **recortado** da textura,
  `XToScreen − w/2`, `YToScreen − h` (base do recorte no centro do tile). Sem deslocamento em float
  pelo Lua: compensar exato é impossível; dá pra escolher sprite.
- `FBORenderCell.performRenderTiles`: `renderPlayers` (241) → `renderOpaqueObjectsEvent` (374) →
  `renderMovingObjects` (387) → por andar: … `IsoMarkers.renderIsoMarkers` (784) → translúcidos.
  O marcador sai **depois** de jogador e zumbis. Os prints mostram que a profundidade dele não tapa
  nada do mundo (telhado, parede, jogador): tratar como overlay.
- Pack `Tiles2x`: quadro 128×256, diamante do chão com centro em (64, 224). `tiledefinitions_erosion`:
  todo `d_plants_1_*` tem `MoveWithWind`/`BlocksPlacement` (planta em pé); `d_streetcracks_1_*` tem
  `FloorOverlay`.
- `IsoGridSquare.getPlayerCutawayFlag(pn, ms)`: bit 1 = parede N cortada, 2 = W
  (`FBORenderCutaways.doCutawayVisitSquares` 612–716). `renderPlayers` antes do evento de parede.
- Lua vanilla: `square:isOutside()` (`server/Farming/SFarmingSystem.lua:295`),
  `square:getBuilding() ~= playerObj:getBuilding()` (`client/ISUI/ISWorldObjectContextMenu.lua:1679`).

## Global Constraints

- Kahlua: sem `//`, `goto`, operador de bit; `unpack`; sem `next`; resto pelo `NOM_Math.mod`.
- Cliente só: `NOM_FogOverlays` começa com `if isServer() then return end`; nada no mapa, save ou rede.
- Nada copiado de mod nem do jogo: sprites vanilla por nome; o script só mede o alfa do pack.
- Todo texto do jogador por chave, PT-BR e EN.
- Teste de API do jogo contra fake que imita o jogo (`tests/fog_world.lua`).

## Review Focus

1. Jogador parado na porta, entrando e saindo do prédio a cada passo: nada pisca (fade, a reserva fica) — `overlays_building_doorway_no_flicker`.
2. Square de fora sem chunk ao lado (borda carregada) na conta da sombra de prédio: conta como livre, sem erro — `overlays_shadow_missing_square`.
3. Jogador andando por cima do sangue: o tile dele nunca fica com marcador visível, nem entre duas atualizações — `overlays_player_tile_clear_every_tick`.
4. Densidade trocada com sujeira no marcador próprio: os dois marcadores saem e voltam juntos — `overlays_grime_marker_follows_entry`.
5. Escada (z quebrado) e andar de cima: a regra de prédio usa o andar do jogador — coberto por `overlays_teleport_and_floor_change` (já existe), conferido de novo.

---

### Task 1: Chão só com decalque chato e seguro

**Files:**
- Create: `scripts/audit_floor_sprites.py`, `tests/floor_sprites.lua` (gerado)
- Modify: `mod/42/media/lua/shared/NOM_DressingRules.lua`, `tests/test_dressing_rules.lua`

**Interfaces:**
- Produces: `R.SETS` sem `mossFloor`; `bloodFloor`, `grimeFloor`, `cracksFloor` só com índices
  `flat = true, zone = 0` da tabela; `tests/floor_sprites.lua` = `{ [nome] = { flat, zone, cov, spill } }`.

- [ ] **Step 1:** script lê o pack (PZPK v1) e o `tiledefinitions_erosion.tiles.txt`, mede por nome:
  `flat` (≥ 95% do alfa ≥ 32 dentro do diamante na posição do jogo e sem `MoveWithWind`),
  `zone` (pixels que o marcador põe na zona de um personagem em pé nos tiles N, W ou NW: ±24 px
  em volta dos centros (−64,−32), (64,−32), (0,−64), do pé (+6) pra cima), `cov` (alfa / 4096) e
  `spill` (fração fora do diamante do próprio tile como o marcador desenha). Escreve a tabela Lua.
- [ ] **Step 2:** testes `dressing_rules_floor_pool_flat_only`, `dressing_rules_floor_pool_reaches_no_character`,
  `dressing_rules_no_plants` falham com o pool de hoje.
- [ ] **Step 3:** pool novo nas regras; `MOSS` sai.
- [ ] **Step 4:** verde (os testes de densidade continuam com folga). Commit.

### Task 2: Sujeira em manchas, parcial e mais leve

**Files:**
- Modify: `NOM_DressingRules.lua`, `client/NOM_FogOverlays.lua`, `tests/test_dressing_rules.lua`, `tests/test_fog_overlays.lua`

**Interfaces:**
- Produces: `R.floor(...)` devolve a lista (rachadura + sangue) com o campo `grime = { "grimeFloor", i }` ou nil;
  `R.GRIME_ALPHA` (0,5); `R.grimeNoise(x, y, z, period)` ∈ [0, 1].
  Entrada do cliente: `{ m = marcador ou nil, g = marcador da sujeira ou nil, ... }`.

- [ ] **Step 1:** testes: `dressing_rules_grime_partial_only` (todo índice de sujeira com `cov < 0,5` e
  `spill < 0,9`), `dressing_rules_grime_clusters` (transições sujo/limpo entre vizinhos < 60% do
  sorteio por tile com a mesma fração), `dressing_rules_grime_no_checkerboard` (vizinhos com o mesmo
  sprite de sujeira < 15% dos pares sujos; nenhum par com sprite de cobertura cheia),
  `dressing_rules_grime_rarer` (fração 10–35% na densidade 1); `overlays_grime_own_marker_lighter`,
  `overlays_grime_marker_follows_entry`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** ruído de valor (rede de 4 tiles, cantos pelo hash, bilinear com smoothstep, guardado como as poças);
  sujeira quando `ruído ≥ 1 − chance(GRIME, d)` e um tile em 7 falha (borda irregular); sprite sorteado
  que não repete o do vizinho N/W. Cliente: segundo marcador com `a × GRIME_ALPHA`, mesmo fade e luz.
- [ ] **Step 4:** verde; commit.

### Task 3: Chão só onde o jogador vê

**Files:**
- Modify: `client/NOM_FogOverlays.lua`, `tests/fog_world.lua` (square com `isOutside`, `getBuilding`; jogador com `getBuilding`), `tests/test_fog_overlays.lua`

**Interfaces:**
- Produces: `NOM_FogOverlays.SHADOW = 3` (tiles na diagonal de trás que um prédio de 1 andar cobre na tela);
  entrada ganha `out` (square de fora) e `b` (prédio do square ou nil).

- [ ] **Step 1:** testes: `overlays_outside_player_skips_interior` (fora: nenhum marcador visível em square
  de dentro), `overlays_outside_player_skips_building_shadow` (fora: nenhum em square de fora com prédio
  a até 3 tiles na diagonal SE), `overlays_inside_player_sees_own_building` (dentro: o prédio dele e o de
  fora; o outro prédio não), `overlays_building_doorway_no_flicker`, `overlays_shadow_missing_square`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** regra `visible(e, pb) = (e.out and not e.shadow) or (e.b ~= nil and e.b == pb)` com
  `shadow` = algum dos `SHADOW` squares em `(x+k, y+k)` é de dentro e de prédio ≠ do jogador
  (dentro do prédio dele o jogo corta as paredes e o telhado). Lido uma vez por square (cache por
  âncora), contexto (`p:getBuilding()`) relido a cada atualização; mudou → `seenF` zera e o fade
  esconde/mostra.
- [ ] **Step 4:** verde; budget ajustado só se o teste de orçamento acusar. Commit.

### Task 4: Pé do jogador limpo

**Files:**
- Modify: `client/NOM_FogOverlays.lua`, `tests/test_fog_overlays.lua`

- [ ] **Step 1:** `overlays_player_tile_clear_every_tick`: andando 1 tile por vez em sangue, a cada tick o
  marcador do tile do jogador tem alfa 0; o que ele deixou volta.
- [ ] **Step 2:** FAIL. **Step 3:** `taken[k]` guarda a entrada; no `OnTick`, tile mudou → o marcador do
  tile novo vai a alfa 0 na hora (`setColor`), o velho volta no alfa da entrada. **Step 4:** verde; commit.

### Task 5: Paredes — decisão e docs

**Files:**
- Modify: `docs/architecture/adr-015-outro-mundo-sangrento.md`, `docs/architecture/pz-api-notes.md` (§16.5),
  GDD (`atmosphere.md`, `art-direction.md`, `Overview.md`), traduções (tooltips sem musgo/trepadeira),
  `README.md`, `docs/sprints/README.md`, `docs/sprints/sprint-0021-outro-mundo-ajustes/README.md`.

- [ ] **Step 1:** emenda da ADR-015 com o porquê de as paredes ficarem desligadas (evento depois do
  `renderPlayers`, fantasma sem profundidade, recorte dá pra ler mas objeto de outro square e outro
  jogador não). **Step 2:** tooltips e teste de tradução. **Step 3:** README da sprint com critérios,
  evidência, roteiro in-game, checkpoints, aprendizados, pendências. Commit.
