# Outro Mundo sangrento — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Na névoa, num raio de 25 tiles do jogador, chão e paredes ganham muito sangue e a erosão no máximo (sujeira, rachadura, musgo, trepadeira), mais na névoa vermelha, só na tela de quem vê, sem nada no save nem na rede.

**Architecture:** Regras puras (`shared/NOM_DressingRules.lua`) dizem, por square e período, o que ele ganha (camadas de chão; um sprite por parede N/W), com poças e rastros por célula de 7×7 e hash do `NOM_VariantRules`. O cliente (`client/NOM_FogOverlays.lua`, reescrito) varre os squares em volta em lotes (mais perto primeiro), põe o chão como **um `IsoMarker` por square com uma tabela de texturas** (forma vanilla de `ISBaseIcon.lua:579`) e guarda as paredes numa lista desenhada a cada quadro no `Events.RenderOpaqueObjectsInWorld` com `IsoSprite:RenderGhostTileColor` (o mesmo desenho do fantasma de construção). Nada fica em objeto do mapa: marcador é lista em memória, a parede é desenho imediato.

**Tech Stack:** Lua 5.1 (Kahlua no jogo, luajit nos testes).

**Spec:** [README da sprint](README.md) (pedido do Johan de 05/10), brief do coordenador (raio 25–30, densidade 0–2, regras de persistência).

## Global Constraints

- Kahlua: sem `//`, `goto`, bit ops, `next()`; `unpack`; nada de `%d` com float.
- Só no cliente (`if isServer() then return end`); **nada no save nem na rede**: proibidos `addBlood*`, `IsoFloorBloodSplat`, objetos de erosão, `setOverlaySprite`, `AttachedAnimSprite`, `AddSpecialObject`/`AddTileObject` (bytecode §16.1: todos salvos ou sincronizados).
- Toda chamada com evidência (Lua vanilla arquivo:linha ou bytecode); UNKNOWN vira fallback + linha no roteiro.
- Nada copiado: sprites vanilla só pelo nome.
- Texto do jogador por chave, PTBR e EN. `FogOverlays` (sandbox) continua o liga/desliga; densidade é opção do jogador `FogOverlayDensity` (0–2, padrão 1) na página do `PZAPI.ModOptions` da sprint 0013.
- Teto: ≤ 600 marcadores de chão ativos, ≤ 120 paredes desenhadas por quadro.

## Evidência (bytecode do B42.21 instalado; detalhe no pz-api-notes §16)

- `IsoMarkers.addIsoMarker(KahluaTable, sq, r, g, b, a)`: uma textura por item da tabela (`Texture.trygetTexture`), todas no mesmo ponto. `renderIsoMarkers` (FBO): `IsoSprite.renderTextureWithDepth`, quad centrado no meio do tile com a base no meio, profundidade do ponto, teste de profundidade ligado, **sem luz** (só a cor do marcador). Só desenha no andar do jogador. `IngameState.exit` → `IsoMarkers.reset()`.
- `FBORenderCell.performRenderTiles` chama `renderOpaqueObjectsEvent(pn)` todo quadro, depois dos itens e antes dos personagens → `LuaEventManager.triggerEvent("RenderOpaqueObjectsInWorld", pn, x, y, z, sq)` (o `PickedTile` nunca é nil: criado no `<clinit>` do `UIManager`). Uso vanilla do evento: `ISBuildingObject.lua:721-741`.
- `IsoSprite.RenderGhostTileColor(x, y, z, r, g, b, a)` → `IsoSprite.render(inst, nil, x, y, z, N, 32·escala, 96·escala, branco, true)`: posição de tile de verdade (parede no lugar certo). Com `setRenderingGhostTile(true)` o `renderCurrentAnim` **desliga o teste de profundidade**. Cor branca cheia: sem luz do square. Uso vanilla: `ISFarmingCursorMouse.lua:21`.
- `IsoObject.save` grava `attachedAnimSprite`, `wallBloodSplats` e `overlaySprite` (flag 256); `setOverlaySprite(..., true)` manda `UpdateOverlaySprite`; `IsoGridSquare.save` grava todo objeto da lista. → proibidos.
- `square:getWall(true|false)` (N/W pelo `cutN`/`cutW` do sprite; `ISDestroyStuffAction.lua:141-142`), `square:getLightLevel(pn)` (máx. de r,g,b da luz do square; `forageSystem.lua:1889`), `square:isCouldSee(pn)` (já usado), `square:isFree(false)` (`ISWorldObjectContextMenu.lua:2199`), `getSprite(nome)` (`server/ClientCommands.lua:195`, nome que existe; nome desconhecido cria sprite vazio, `IsoSpriteManager.getSprite` → validar com `getTexture` antes), `square:getProperties():has(IsoFlagType.DoorWallN …)` (`ISBuildIsoEntity.lua:195-198`).
- Sprites (pack `Tiles2x`, lado pelo recorte da textura e pelas profundidades de `tileDepthTextureAssignments.txt`): `overlay_blood_floor_01` 37 de chão, `overlay_grime_floor_01` 82, `d_streetcracks_1` 118, `d_plants_1` 33 de chão; parede W/N: `overlay_blood_wall_01` 11/9, `overlay_grime_wall_01` 9/9, `d_wallcracks_1` 24/24, `f_wallvines_1` 24/24.

## Review Focus

1. Andar devagar na névoa: o que está perto não pode piscar nem trocar de desenho (mesma tabela de texturas no mesmo square) — `overlays_stable_while_walking`.
2. Período de névoa novo (ou desconhecido no MP, `period` nil): desenho novo, sem herdar o velho e sem erro — `overlays_new_period_new_layout`.
3. Andar ou subir escada: só o andar do jogador, nada flutuando de outro andar — `overlays_only_player_floor`.
4. Square sem chunk (borda do mundo carregado): pular e tentar de novo depois, sem guardar como "vazio" — `overlays_missing_square_retried`.
5. Opção de densidade 0 no meio da névoa: tudo some com fade; nada nasce — `overlays_density_zero`.

---

### Task 1: Regras puras do Outro Mundo

**Files:**
- Create: `mod/42/media/lua/shared/NOM_DressingRules.lua`
- Modify: `mod/42/media/lua/shared/NOM_VariantRules.lua` (expor `hash` e `Q`)
- Test: `tests/test_dressing_rules.lua` (registrar em `tests/run.lua`)

**Interfaces:**
- Produces: `NOM_DressingRules.SETS[nome] = { prefix = "...", idx = { ... } }`; `R.density(option, red) -> d` (0..3.2); `R.floor(x, y, z, period, d) -> { {set, i}, ... } | nil` (até 4 camadas, sangue primeiro); `R.wall(x, y, z, period, d, north) -> {set, i} | nil`; `R.OFFSETS` = `{ {dx, dy}, ... }` no raio, mais perto primeiro; constantes `RADIUS, MAX_FLOOR, MAX_WALL`.

- [x] Testes: determinismo (mesma entrada, mesma saída; período diferente muda), poças (alguma célula com 3 camadas de sangue em 60×60), densidade (vermelha > normal > 0; `d = 0` nada), paredes N só de sets N e W só de W, índices dentro do que o pack tem, `OFFSETS` ordenado e dentro do raio.
- [x] Implementar com o hash do `NOM_VariantRules` (quadrados módulo primo, exato em double).
- [x] `./run-tests.sh`, commit.

### Task 2: Cliente — chão por marcador, paredes por desenho

**Files:**
- Modify: `mod/42/media/lua/client/NOM_FogOverlays.lua` (reescrita)
- Modify: `mod/42/media/lua/client/NOM_ScreenFxOptions.lua` (slider `FogOverlayDensity`, `O.overlayDensity()`)
- Modify: `tests/fog_world.lua` (square: `getWall`, `getObjects`, `getLightLevel`; contador de chamadas)
- Modify: `tests/test_fog_overlays.lua` (reescrito), `tests/test_screen_fx_options.lua`
- Modify: traduções `UI.json`/`Sandbox.json` PTBR/EN

**Interfaces:**
- Consumes: Task 1.
- Produces: `NOM_FogOverlays.count() -> floor, walls` (pro `NOM_Debug.status`), `NOM_FogOverlays.reach() -> floorReach, wallReach`, `NOM_FogOverlays.clear()`; `NOM_DressingRules.WITHIN[r]`.

Comportamento (depois do review):
- A cada 10 ticks: `on = névoa e FogOverlays e jogador vivo e densidade > 0`. Morte → `clear()` na hora; menu (`OnMainMenuEnter`) e `OnGameStart` → `clear()`.
- `gen = período:densidade`; mudou (período novo, nil → conhecido, opção, vermelha forçada) → tudo sai na hora e redesenha.
- Duas reservas com teto (`MAX_FLOOR` 600, `MAX_WALL` 120), cada uma com um **raio efetivo**: cheia, encolhe pra antes do anel que não coube; o que fica fora dele ou em outro andar sai na hora (`prune`); numa volta inteira com menos de 80% do teto, cresce um tile. O teto serve o mais perto.
- Varredura: cursor em `OFFSETS` até `WITHIN[maior raio efetivo]`, `SCAN_BUDGET` (80) squares por atualização; `taken` antes da regra, a regra antes do Java; `seen` evita reolhar (zerado ao andar 8 tiles da âncora, com o cursor de volta ao mais perto; entrada que sai limpa o seu). Square nil, fora de um raio efetivo ou recusado pelo teto não entra em `seen`.
- Chão: regra → `getGridSquare` → `isFree(false)` → `addIsoMarker(nomes, sq, luz, 0)`.
- Parede: regra (por lado) → `cleanWall(sq, north)`: `getWall` do lado, sem batente (`DoorWall*`, `Window*`, `door*`, `window*` nas propriedades), e `getObjects():size()` = piso + paredes (o outro lado só é lido com 3 objetos). O lado (de frente) e a vista (`isCouldSee(0)`) só mudam o alvo do fade: a parede fica na reserva, apagada, e volta ao virar.
- Fade por entrada (`FADE_MS` 4000): chão alvo 1 na névoa; fim da névoa → tudo a 0 e sai.
- Rodízio: luz de 30 marcadores (`setColor` só quando muda) e 12 paredes (`cleanWall` de novo; falhou, sai) por atualização.
- Quadro: `RenderOpaqueObjectsInWorld(pn, x, y, z)`: só `pn == 0`; sem paredes, zero chamada; senão `sprite:RenderGhostTileColor(x, y, z, l, l, l, a)` por parede com `a > 0` no andar `z`, até `MAX_WALL`. O jogo pula o evento com o mouse fora do mundo.

- [x] Testes contra o mundo falso (o square explode em escrita; `addBloodSplat`, `getSprite` sem textura e qualquer método de objeto do mapa explodem): inerte no dedicado; nasce na névoa e enche em poucos segundos; vermelha > normal; teto; paredes desenhadas por quadro só no evento, no andar, de frente e visíveis; fade de saída e remoção no fim da névoa; morte e menu limpam na hora; determinismo e estabilidade ao andar; período novo; andar; square ausente; densidade 0; orçamento por atualização e por quadro (contador de chamadas).
- [x] Implementar.
- [x] `./run-tests.sh`, commit.

### Task 3: Debug, docs e roteiro

**Files:**
- Modify: `mod/42/media/lua/client/NOM_Debug.lua` (`chao`, `paredes` no status)
- Modify: `docs/architecture/pz-api-notes.md` (§16), `docs/architecture/README.md` (estrutura, orçamento, ADR-015), `docs/architecture/adr-015-outro-mundo-sangrento.md` (nova), `docs/gdd/atmosphere.md`, `docs/gdd/art-direction.md` (só um bloco no fim), `docs/gdd/Overview.md`, `docs/gdd/sandbox.md`, `docs/sprints/README.md` (uma linha), README da sprint (critérios com evidência, roteiro).

- [x] Docs, `./run-tests.sh`, commit.

### Task 4: Review

- [x] Teto a serviço do perto (raio efetivo, `prune`), redesenho por `gen`, paredes apagadas em vez de removidas, batentes, parede conferida em rodízio, `sqId` com andar de -32 a 31, chave numérica nas poças, evento do quadro só com o mouse no mundo (fake). Testes: `overlays_walk_keeps_nearby_covered`, `overlays_teleport_and_floor_change`, `overlays_period_known_after_nil`, `overlays_density_change_redresses`, `overlays_walls_door_closed_then_opened`, `overlays_walls_survive_turning_around`, `overlays_walls_skip_door_and_window_frames`, `overlays_stale_wall_dropped`, `dressing_rules_z_independent`, `dressing_rules_offsets_within`.
- [x] Merge da main (sprint 0014), `./run-tests.sh`.
