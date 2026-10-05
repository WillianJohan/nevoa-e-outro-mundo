# Outro Mundo anexado — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Na névoa, o sangue, a sujeira, a rachadura, o chão queimado e o mato do Outro Mundo saem **anexados** aos `IsoObject` de piso e de parede de verdade (o caminho da erosão vanilla), desenhados no FBO do chunk embaixo dos personagens, com a luz e o recorte do jogo; as paredes voltam (trepadeira, rachadura, sujeira e sangue). Nada disso fica no save.

**Architecture:** `shared/NOM_DressingRules.lua` (puro) continua decidindo o que cada square ganha, agora sabendo se o square é de fora (mato) ou de dentro (chão queimado). `client/NOM_FogOverlays.lua` é reescrito: anexa com `obj:addAttachedAnimSpriteByName(nome)`, guarda **cada instância que pôs** num registro (chave do alvo → objeto, square, instâncias e nomes) e tira **só essas** (`RemoveAttachedAnim(i)` de trás pra frente, conferindo instância e nome). A segurança do save é o centro: tudo sai no `OnSave` (antes do `IsoCell.save` gravar os chunks) e volta na atualização seguinte; nada fica além de 15 tiles do jogador (o chunk descarrega a ≥ 48); o fim da névoa tira tudo; o `LoadGridsquare` limpa qualquer `floors_burnt_01_*` anexado (nome que só o mod anexa); a ação do jogador em curso segura o square dela limpo. Saem o `IsoMarker`, o chão apagado debaixo de personagem, a visibilidade por prédio, o fade, a luz e as paredes por fantasma.

**Tech Stack:** Lua 5.1 (Kahlua no jogo, luajit nos testes), Python 3 + Pillow (auditoria do pack, só leitura), `./run-tests.sh`.

**Spec:** brief da sprint 0023 (2026-10-05) e o [README da sprint](README.md); [ADR-015](../../architecture/adr-015-outro-mundo-sangrento.md), [ADR-017](../../architecture/adr-017-outro-mundo-anexado.md) (nova); [pz-api-notes §16.6](../../architecture/pz-api-notes.md#166-anexado-ao-objeto-sprint-0023).

## Evidência (bytecode B42.21, `projectzomboid.jar`, só leitura)

- `FBORenderCell.performRenderTiles`: `renderOneChunk` 157 (FBO do chunk: piso e anexos) → `renderPlayers` 241 → `renderOpaqueObjectsEvent` 374 → `renderMovingObjects` 387 → `IsoMarkers.renderIsoMarkers` 784.
- `IsoObject.addAttachedAnimSpriteByName(String)` 0–22: nome vazio sai; `IsoSprite.getSprite(manager, nome, 0)` lê o `namedMap` e volta `null` pra nome desconhecido (0–17), e `addAttachedAnimSprite(null)` sai (0–4): **não cria sprite vazio**. Com sprite, `IsoSpriteInstance.get(sprite)` (do pool) → `addAttachedAnimSpriteInstance` (cria a lista se nula, `add`, `invalidateRenderChunkLevel`). Sem `flagForHotSave`.
- `IsoObject.RemoveAttachedAnim(I)` 0–76: índice fora sai; `Dispose`, `remove(i)` (os de trás andam um), `IsoSpriteInstance.add` (**volta pro pool**), invalida o nível. `RemoveAttachedAnims()` limpa tudo (vanilla usa pra tirar blend: `ISShovelGround.lua:63`).
- `IsoObject.renderAttachedSprites` 0–450: alfa do anexo = `IsoSpriteInstance.alpha` (146–149); `CutawayAttachedModifier` corta o anexo da parede com ela (158–178); posição do objeto (`IsoSprite.render(inst, obj, x, y, z, …)`, 404–438). `renderAttachedAndOverlaySpritesInternal` 0–151: prédio apagado (`isBlackedOutBuildingSquare`, `getBlackedOutRoomFadeRatio`) vale pro anexo. `IsoSpriteInstance.SetAlpha(F)`, `SetTargetAlpha(F)` existem; `update()` é vazio.
- `IsoObject.save` 64–187: grava a lista de anexos inteira (ID do sprite pai), sem filtro.
- `GameWindow.save(Z)`: `OnSave` (302) **antes** de `IsoCell.save` (364); no cliente de MP só `OnSave` (68) e sai. `IsoCell.save` espera o `ChunkSaveWorker` e chama `IsoChunkMap.Save` → `IsoChunk.Save(Z)` em todo chunk carregado, **na mesma thread**. `IsoChunk.Save(Z)` 5–47: `Core.isNoSave()` ou `GameClient.client` → não grava. Quem chama `GameWindow.save`: `GameWindow.exit`, `IngameState.updateInternal` (sair), `SleepingEvent.wakeUp` (acordar no solo), `ModalDialog.Clicked`, `GameLoadingState$1.runInner`, `LuaManager$GlobalObject.save`.
- `OnPostSave`: só em `GameWindow.exit` 127/156 e `IngameState.updateInternal` 207 e 1557 (saída). **Não sai depois do save de acordar.** O mod não depende dele: volta na atualização seguinte ao `OnSave`.
- Chunk que sai do mapa: `IsoChunkMap.Up/Down/Left/Right` → `IsoChunk.removeFromWorld` → `ChunkSaveWorker.Add` (fila; grava depois, noutra thread). `chunkGridWidth` = 13 (`<clinit>` 74): o chunk que sai está a ≥ 48 tiles do jogador.
- Hot save (só solo: `IsoChunkMap.updateInternal` 323–350): chunk com `requiresHotSave` (posto por `IsoObject.flagForHotSave`: `addToWorld`, `removeFromWorld`, `transmitModData`, contêineres) é serializado **na hora** (`ChunkSaveWorker.AddHotSave` 42 → `IsoChunk.Save(ByteBuffer…)`), com o que estiver anexado. Só fica no disco se o jogo cair antes do próximo save daquele chunk.
- `IsoChunk.doLoadGridsquare` dispara `LoadGridsquare` (vanilla: `client/DebugUIs/DebugScenarios.lua:101`).
- Quem anexa o quê no vanilla: `CellLoader.DoTileObjectCreation` anexa `FloorOverlay` ao piso (2018–2061), `WallOverlay`/`attachedN/W/SE` à parede (1673–1970), tampo (1602–1630); piso sólido novo **troca** o sprite do piso (134–265, `setSprite`), não anexa. Erosão: `ErosionObjOverlay.setOverlay` (anexa) / `removeOverlay` (tira por ID). `floors_burnt_01_*` tem `solidfloor`/`diamondFloor`, sem `FloorOverlay` (`newtiledefinitions.tiles.txt:71445`); o vanilla usa como sprite de piso (`IsoGridSquare.BurnWalls` 1488), objeto de cinza (`TimedActionsTests.lua:593`) e chão do worldgen (`server/WorldGen/features/ground/burnt.lua`). **Ninguém anexa `floors_burnt_01_*`**: é o nome só do mod.
- Ações do jogador que mexem nos anexos: `ISDestroyStuffAction.lua:313-321` (no solo, a parede de canto nova copia os anexos), `ISShovelGround.lua:63` (limpa tudo), `ISRemoveBush.lua:100-137` (trepadeira por prefixo), `ISMoveableSpriteProps.lua:1456-1474`, `ISDismantleAction.lua:86` (no cliente de MP, `transmitUpdatedSpriteToServer`, que manda a lista de anexos: `IsoObject.transmitUpdatedSpriteToServer` 88–138). A fila: `ISTimedActionQueue.queues[jogador].queue[1]` (`client/TimedActions/ISTimedActionQueue.lua:138-155`); as ações guardam o alvo em `square`, `object`, `item`, `thumpable` (`ISMoveablesAction.lua:274-280`, `ISDismantleAction.lua:107`, `ISDestroyStuffAction.lua:362`, `ISRemoveBush.lua:187`).

## Global Constraints

- Kahlua: sem `//`, `goto`, bit ops, `next`, `table.unpack`; `%` só por `NOM_Math.mod`.
- Cliente: `if isServer() then return end`. Nada pela rede: nunca `transmitUpdatedSpriteToClients`, `transmitUpdatedSpriteToServer`, `transmitCompleteItemToServer`; nunca `RemoveAttachedAnims()` nem `AttachExistingAnim`.
- Só piso (`sq:getFloor()`) e parede (`sq:getWall(north)`) que não são `IsoThumpable`, `IsoDoor` nem `IsoWindow`; square sem batente de porta/janela no lado da parede; sem água.
- Raio 15 tiles; lote de 80 squares por atualização (10 ticks); o que sai do raio sai em lotes de 80; `OnSave`, morte e salto saem na hora, sem lote.
- Nenhum arquivo do jogo ou de outro mod copiado; sprites vanilla pelo nome; a auditoria só mede.
- Texto visível por chave, PTBR e EN. Comentários e docs em português do Brasil.

## Review Focus

- **Anexo vanilla no mesmo objeto** (blend de grama, sujeira do mapa com o **mesmo nome** que a nossa): sobrevive a todo caminho de retirada (sair do raio, fim da névoa, `OnSave`, ação, re-aplicação). Teste: `overlays_vanilla_attachments_survive_every_path` (Task 3) e `overlays_same_name_vanilla_decal_survives` (Task 3).
- **A lista mexida por baixo** (`RemoveAttachedAnims` da pá, objeto trocado pelo servidor no MP): nada explode, o mod re-aplica sem duplicar. Teste: `overlays_reapply_after_list_wiped`, `overlays_reapply_after_object_replaced` (Task 3).
- **Instância nossa que voltou pro pool e foi reusada pelo vanilla** no mesmo objeto: nunca é tirada. Teste: `overlays_pool_reuse_never_removes_vanilla` (Task 3).
- **Save no meio do lote** (fim da névoa tirando em lotes, ou enchendo): nada nosso no snapshot do save. Teste: `overlays_save_mid_batch_clean` (Task 4).
- **Nome sem textura** (pack diferente): nenhum erro, nenhum sprite vazio, nada registrado. Teste: `overlays_missing_sprites` (Task 3).

---

### Task 1: Auditoria e regras (pools novos, dentro/fora, chão queimado, mato, paredes de volta)

**Files:**
- Modify: `scripts/audit_floor_sprites.py` (geometria do anexo: `inside`, `cov`, `rise`, `wind`; + `d_floorleaves_1_`, `floors_burnt_01_`)
- Modify: `tests/floor_sprites.lua` (gerado)
- Modify: `mod/42/media/lua/shared/NOM_DressingRules.lua`
- Test: `tests/test_dressing_rules.lua`

**Interfaces:**
- Produces: `R.floor(x, y, z, period, d, outside)` → `nil` ou `{ {set, idx}, ..., grime = {set, idx} }` (camadas de baixo pra cima: queimado/mato, rachadura, sangue); `R.wall(x, y, z, period, d, north, outside)` → `{set, idx}` ou `nil` (trepadeira só com `outside`); `R.name(layer)` → `"prefixo" .. idx`; `R.OWN_PREFIX = "floors_burnt_01_"`; `R.own(name)` → bool; `R.RADIUS = 15`; `R.GRIME_ALPHA`; `R.OFFSETS`, `R.WITHIN`, `R.density` como hoje. Somem `MAX_FLOOR`, `MAX_WALL`, `WALLS`.

Pools (medidos, `tests/floor_sprites.lua`): sangue = os 43 deitados (`inside ≥ 0,95`); rachadura = os 59 deitados de `d_streetcracks_1_`; sujeira = as 11 parciais de hoje; queimado: pequeno `16–23, 28–31`, médio `1, 9–12, 24–27`, cheio `0, 8, 13–15`; mato (`inside ≥ 0,8` e `rise ≤ 8`): `d_plants_1_` `0, 1, 3, 4, 6, 7, 8, 11, 14, 23, 38, 39, 49–53, 55, 57–59` e `d_floorleaves_1_0..11`.

- [ ] **Step 1: testes que falham** — em `tests/test_dressing_rules.lua`: `dressing_rules_floor_pools_lie_on_floor` (decalques com `inside ≥ 0,95`; mato `inside ≥ 0,8` e `rise ≤ 8`), `dressing_rules_burnt_only_inside_plants_only_outside`, `dressing_rules_burnt_patches` (manchas: troca vizinho < 60% do sorteio por tile; miolo cheio, borda pequena), `dressing_rules_own_prefix_only_burnt` (todo nome de `SETS` com `OWN_PREFIX` é do set queimado e vice-versa), `dressing_rules_vines_only_outside`, e ajustar os que usam `zone`/`spill` (saem) e `R.floor(..)` sem `outside` (dentro = `false`).
- [ ] **Step 2:** `luajit tests/run.lua` → falham os novos.
- [ ] **Step 3:** implementar em `NOM_DressingRules.lua`: sets `burntFloorS/M/F`, `plantsFloor`, `leavesFloor`; ruído do queimado (`noise(..., R.BURNT_CELL, 56)`, passa de `1 − min(BURNT·d, BURNT_MAX)`; faixa +0,15 cheio, +0,07 médio, senão pequeno); mato por ruído (`57`) fora; `R.name`, `R.own`; `R.wall` com `outside`.
- [ ] **Step 4:** testes verdes.
- [ ] **Step 5: Commit** `regras do Outro Mundo anexado: chão queimado dentro, mato fora, pools medidos pro anexo`.

### Task 2: Mundo falso com anexos

**Files:**
- Create: `tests/attached_world.lua`
- Modify: `tests/fog_world.lua` (square: `getFloor`, `getWall` delegam a `G.floorOf`/`G.wallOf`)

**Interfaces:**
- Produces: `A.install(G)` acrescenta em `G`: `G.obj(x, y, z, kind, opts)` (kind `"F"`, `"N"`, `"W"`; `opts.class` = `"IsoObject"`/`"IsoThumpable"`/`"IsoDoor"`; `opts.attached` = nomes vanilla já anexados), `G.attachedNames(obj)`, `G.saveSnapshot()` (dispara `OnSave` e lê a lista de todo objeto carregado: o que o `IsoChunk.Save` gravaria), `G.loadSquare(x, y, z, {floor = nomes, N = nomes, W = nomes})` (cria os objetos e dispara `LoadGridsquare`), `G.replace(x, y, z, kind)` (objeto novo, só os anexos vanilla), `G.wipe(obj)` (`RemoveAttachedAnims`), `G.unknown[nome] = true`, `G.invalidations`, `G.java`. `instanceof(o, classe)` global (IsoThumpable/IsoDoor/IsoWindow herdam de IsoObject; IsoPlayer de IsoMovingObject). Instâncias vêm de um **pool** (a retirada devolve, o próximo `add` reusa a mesma tabela). `ISTimedActionQueue.queues`.

- [ ] Escrever o fake com o comportamento do bytecode acima (lista `nil` até o 1º `add`; `RemoveAttachedAnim(i)` desloca; nome desconhecido não muda nada; `RemoveAttachedAnims`, `transmit*` e `AttachExistingAnim` explodem quando vindos do mod — o teste chama `G.wipe` por fora).
- [ ] Commit junto com a Task 3 (o fake só existe pros testes dela).

### Task 3: Cliente anexando (registro, varredura, retirada só do nosso, re-aplicação)

**Files:**
- Rewrite: `mod/42/media/lua/client/NOM_FogOverlays.lua`
- Rewrite: `tests/test_fog_overlays.lua`

**Interfaces:**
- Consumes: Task 1, Task 2.
- Produces: `NOM_FogOverlays.count()` → `chão, paredes` (alvos com anexo nosso); `NOM_FogOverlays.clear()`; `NOM_FogOverlays.stripAll()`; constantes `UPDATE_TICKS = 10`, `SCAN_BUDGET = 80`, `STRIP_BUDGET = 80`, `VERIFY_BUDGET = 20`, `RESEEN_TILES = 8`, `DENSITY_MS = 1000`.

Registro: `reg[k]` com `k = "x,y,z" .. "F"|"N"|"W"` → `{ obj, sq, x, y, z, kind, gen, list = { {inst, name}, ... } }`. Tirar: `for i = size − 1, 0, −1`, se `list:get(i) == e.inst` **e** o nome confere → `RemoveAttachedAnim(i)`.

- [ ] **Step 1: testes que falham** (`tests/test_fog_overlays.lua`): `overlays_attach_floor_and_walls` (piso e paredes N/W ganham os nomes da regra; anexo pelo nome), `overlays_vanilla_attachments_survive_every_path`, `overlays_same_name_vanilla_decal_survives`, `overlays_pool_reuse_never_removes_vanilla`, `overlays_targets_only_plain_objects` (thumpable, porta, janela, batente, água: nada), `overlays_grime_lighter` (`SetAlpha` e `SetTargetAlpha` = `GRIME_ALPHA`), `overlays_burnt_inside_plants_outside`, `overlays_leaving_radius_strips` (andar 30+ tiles: nada nosso a mais de 15; tudo dentro de 48), `overlays_fog_end_strips_all` (em lotes, tudo sai), `overlays_period_and_density_redraw`, `overlays_density_debounced`, `overlays_reapply_after_list_wiped`, `overlays_reapply_after_object_replaced`, `overlays_missing_sprites`, `overlays_inert_on_dedicated`, `overlays_never_touch_the_network`, `overlays_deterministic_and_stable_while_walking`, `overlays_other_floor_stripped`, `overlays_budget` (chamadas Java por atualização e invalidações por lote limitadas).
- [ ] **Step 2:** falham.
- [ ] **Step 3:** reescrever `NOM_FogOverlays.lua` (o que sai: `IsoMarker`, `underfoot`/personagens, telhados/sombra, luz, fade, teto e raio efetivo, paredes por fantasma).
- [ ] **Step 4:** verdes.
- [ ] **Step 5: Commit** `Outro Mundo anexado ao piso e à parede: registro do que o mod pôs, tira só o nosso`.

### Task 4: Segurança do save

**Files:**
- Modify: `mod/42/media/lua/client/NOM_FogOverlays.lua`
- Test: `tests/test_fog_overlays.lua`

- [ ] **Step 1: testes que falham:** `overlays_on_save_nothing_ours` (snapshot do `OnSave`: só os anexos vanilla), `overlays_back_after_save` (na atualização seguinte volta igual; `OnPostSave` sozinho não é preciso), `overlays_save_mid_batch_clean` (fim da névoa no meio do lote + save), `overlays_jump_strips_now` (teleporte de 200 tiles: tudo sai no mesmo tick), `overlays_death_strips_now`, `overlays_load_scrub_removes_own_prefix` (`LoadGridsquare` com `floors_burnt_01_*` vazado: sai, com ou sem névoa; vanilla do mesmo square fica; `overlay_blood_floor_01_*` vazado fica — custo da ADR-017), `overlays_timed_action_holds_square` (ação na fila com `square`/`object`/`thumpable`: o square fica limpo enquanto ela é a atual e volta depois; o personagem da ação não conta).
- [ ] **Step 2:** falham. **Step 3:** `Events.OnSave` → `stripAll()`; salto (> `RADIUS` desde o tick anterior) no `OnTick`; morte → `stripAll()`; `Events.LoadGridsquare`; ação atual lida a cada atualização. **Step 4:** verdes.
- [ ] **Step 5: Commit** `save seguro: tira tudo no OnSave, no salto e na morte, limpa o queimado vazado no LoadGridsquare, segura o square da ação`.

### Task 5: Limpeza e textos

**Files:** `tests/test_translations.lua`, `mod/42/media/lua/shared/Translate/{EN,PTBR}/{Sandbox,UI}.json`, `tests/test_debug.lua` (se preciso), `README.md`.

- [ ] Teste `translations_overlays_promise_floor_and_walls` (tooltip fala de parede/trepadeira e de queimado; continua "nada fica no save"); textos novos; `NOM_Debug.status` segue com `chao`/`paredes` (agora alvos com anexo).
- [ ] `./run-tests.sh` verde. **Commit** `textos do Outro Mundo: paredes de volta`.

### Task 6: Docs

- [ ] pz-api-notes §16.6 (tabela de evidência acima, CONFIRMED/EXISTS/UNKNOWN); ADR-017 nova + aviso na ADR-015 + índice em `docs/architecture/README.md` (estrutura e orçamento); GDD `atmosphere.md`, `art-direction.md`, `Overview.md` (decisão datada); `docs/sprints/README.md` (linha `em teste`); README da sprint (critérios com evidência, roteiro, checkpoints, aprendizados, pendências, rulings). **Commit** `docs da sprint 0023`.
