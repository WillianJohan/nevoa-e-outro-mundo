# Sem-rosto e atmosfera da névoa — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Com névoa ≥ `FogThreshold`, o Sem-rosto caça (some quando visto e volta mais perto, fora da vista), o rádio chia na cabeça do jogador conforme a distância dele, o ambiente vira drone + metal, o chão ganha sangue e ferrugem locais e a tela ganha vinheta; tudo some quando a névoa baixa.

**Architecture:** O servidor conta os períodos de névoa (`ModData` global, igual ao contador de noites) e manda `fog { on, period }` aos clientes (a flag nasce agora, com o primeiro consumidor de cliente, como previa a ADR-002). O Sem-rosto é sorteio determinístico do `persistentOutfitID` com o **período de névoa** (ADR-006), independente das variantes da noite. Quem **vê** é o cliente (luz e visão são do cliente); quem **move** é o dono do zumbi (o servidor aceita a posição do dono, bytecode abaixo), e o servidor valida e repassa (ADR-007). Som, overlays e vinheta são locais ao cliente e nunca tocam o mundo, a rede ou o save.

**Tech Stack:** Lua 5.1 (Kahlua) do Project Zomboid B42.20.4; testes com luajit (`./run-tests.sh`); sons gerados com Python (numpy) + ffmpeg.

**Spec:** [README da sprint](README.md), [monsters.md#sem-rosto](../../gdd/monsters.md#sem-rosto), [atmosphere.md](../../gdd/atmosphere.md), [spike de shader](../spike-shader/README.md), [ADR-002](../../architecture/adr-002-autoridade-servidor.md), [ADR-005](../../architecture/adr-005-quem-simula-aplica.md), [ADR-006](../../architecture/adr-006-variantes-deterministicas.md), [pz-api-notes](../../architecture/pz-api-notes.md).

## Global Constraints

- Kahlua: sem `//`, sem `goto`, sem operadores de bit; `unpack`, não `table.unpack`; nada de `string.format("%d")` com float.
- Lógica de jogo no servidor (`lua/server/`, começa com `if isClient() then return end`); lógica pura em `lua/shared/` sem API do jogo, testada com luajit.
- Código com API do jogo testado contra fakes que imitam o comportamento real (como `tests/test_climate_look.lua`).
- Toda chamada de API com evidência (Lua vanilla arquivo:linha ou bytecode).
- Nada copiado de outro mod nem do jogo; visual por **nome** de sprite vanilla; sons gerados por `scripts/gen_sounds.py`, registrados no `CREDITS.md` como originais.
- Todo texto visível por chave de tradução, PTBR e EN; sandbox no namespace `NevoaEOutroMundo`.
- Overlay que vaza pro save é pior que nenhum: só mecanismo sem save e sem rede.
- Sem override de `screen.frag` (arquivado no spike).
- Ecos nunca são Sem-rosto.

## Pesquisa (bytecode B42.20.4) que decide o desenho

- **Mover o Sem-rosto: no dono.** `NetworkZombiePacker.parseZombie` (servidor) ignora pacote de quem não é dono (offsets 64–88) e `applyZombie` aplica `realX/realY/realZ` do dono direto (`setX/setNextX/setLastX`, 41–97), sem conferir distância. Então teleporte feito só no servidor é sobrescrito no próximo pacote do dono, e teleporte feito no dono é aceito. Cópias remotas recebem a posição como alvo (`NetworkZombieAI.parse` 51–80: `targetX/targetY`, ou `pathToLocationF` com `usePathFind`) e andam até ela com até 2× a velocidade (`IsoZombie.moveUnmodded` 181–283, `smoothstep(0.5, 1.5, dist)`): **deslizam**, não somem. `IsoGameCharacter.teleportTo(III)` faz só `setX/Y/Z`, `setLastX/Y`, `ensureOnTile`, sem rede.
- **Remover + spawnar** troca o `persistentOutfitID` (identidade, ADR-006) a menos que se vista o substituto com `dressInPersistentOutfitID(id)` (bytecode: grava `persistentOutfitId` e veste), e precisa avisar os clientes (`removeFromWorld` no servidor não avisa, ADR-003). Fica de **fallback**: se o servidor nota que o último movimento não pegou (zumbi visto de novo a ≤ 1,5 tile do ponto antigo), substitui.
- **"Visto ou iluminado":** `square:isCanSee(pn)` é o bit 2 do `vis` da luz do cliente (`LightingJNI$JNILighting.bCanSee`), o mesmo que o jogo usa pra "o jogador vê este zumbi" (`IsoZombie.checkZombieEntersPlayerBuilding` 26–44, `canSeeHeadSquare`). Depende de luz: no escuro só é visto se iluminado. "Fora da vista" = `not square:isCouldSee(pn)` (bit 4, linha de visão/cone sem luz; CONFIRMED `server/FireFighting/ISExtinguishCursor.lua:48`).
- **Som local:** `FMODSoundEmitter.playSound(String)` em cliente MP **manda pacote** `PlaySound` (offsets 0–104): os outros ouvem. `IsoGameCharacter.playSoundLocal(name)` = `getEmitter():playSoundImpl(name, nil)`, sem pacote (CONFIRMED `client/ISUI/Maps/ISMap.lua:210`). Volume: `emitter:setVolume(id, v)` (EXISTS, `CharacterSoundEmitter.setVolume(JF)` → `FMODSoundEmitter.setVolume`). Parar sem rede: `emitter:stopSoundLocal(id)` (EXISTS; `stopSound` chama `sendStopSound`). `isPlaying(id)` EXISTS.
- **Overlays:** `getIsoMarkers():addIsoMarker(nome, square, r, g, b, a)` (CONFIRMED `client/Foraging/ISBaseIcon.lua:577`) volta `nil` no servidor (offset 0, `GameServer.server`), guarda o marcador numa lista Java em memória (`IsoMarkers.markers`), sem `save`/`load` na classe e sem pacote; o sprite é achado por `Texture.trygetTexture(nome)` (`IsoMarker.init`). `marker:setAlpha(a)`, `marker:remove()` EXISTS. Não toca o square nem os objetos do mapa.
- **Vinheta:** igual ao spike. `getSearchMode():getSearchModeForPlayer(pn)`, `setEnabled(pn, b)`, `isEnabled(pn)` (bytecode `SearchMode`), `ISSearchManager.getManager(player)` (`client/Foraging/ISSearchManager.lua:68`), `manager.isOverride` (`:1056`, `:1389`), `manager.isSearchMode` é o forrageamento (`:1416-1428`).

## Review Focus

1. Sem-rosto visto pelo jogador A mas dono no cliente B (MP): só o dono move; o servidor repassa a todos (`fog_client_only_owner_moves`).
2. Jogador começa a forragear durante a névoa: a vinheta sai da frente e volta quando o forrageamento termina (`vignette_yields_to_foraging`).
3. Salvar e recarregar com névoa: nenhum overlay toca o mapa; o fake de square explode se o código chamar qualquer coisa nele além de leitura (`overlays_never_touch_the_map`), e o cliente pede o estado ao entrar (`fog_client_asks_state_on_join`).
4. Nenhum square livre e fora da vista atrás do jogador (corredor, porão): sem movimento, sem relatório, sem erro (`semrosto_no_spot_no_move`).
5. A névoa acaba com o rádio no máximo, a vinheta ligada e manchas no chão: tudo para, volta e some (`fog_end_restores_everything`).

---

### Task 1: Sandbox

**Files:** `mod/42/media/sandbox-options.txt`, `shared/NOM_Config.lua`, `Translate/PTBR|EN/Sandbox.json`, `tests/test_config.lua`.

Opções: `SemRostoEnabled` (true), `SemRostoChance` (5, inteiro 0–100), `FogAmbience` (true), `FogOverlays` (true), `FogVignette` (true), `FogVignetteIntensity` (1.0, 0–2).

- [ ] Teste `config_fog_defaults`; rodar: falha. Opções + defaults + rótulo/tooltip PTBR/EN (`config_every_option_has_default_and_translations` cobre). Verde, commit.

### Task 2: Regras puras

**Files:** Modify `shared/NOM_VariantRules.lua`; Create `shared/NOM_SemRostoRules.lua`, `shared/NOM_AtmosphereRules.lua`; tests `test_variant_rules.lua`, `test_semrosto_rules.lua`, `test_atmosphere_rules.lua`.

**Produces:**
- `NOM_VariantRules.semRosto(id, period, cfg) -> bool`, cfg = `{ semRostoOn, semRostoChance }`; `NOM_VariantRules.semRostoConfig(get)`. Mistura com sal próprio: independente do sorteio da noite.
- `NOM_SemRostoRules.spots(px, py, faceAngle, r) -> { {x, y}, … }`: pontos inteiros no círculo de raio `r`, começando atrás do jogador (`faceAngle + π`) e abrindo ±30° até ±150°.
- `NOM_SemRostoRules.nextRadius(d) -> r`: `max(MIN_DIST, d - STEP)` (MIN_DIST 3, STEP 3).
- `NOM_SemRostoRules.ready(lastMs, nowMs) -> bool` (`COOLDOWN_MS` 4000).
- `NOM_SemRostoRules.validMove(sx, sy, zx, zy, tx, ty) -> bool`: destino mais perto do jogador que o zumbi, a ≥ MIN_DIST − 1 e ≤ `REPORT_RANGE` (30).
- `NOM_SemRostoRules.staticVolume(d) -> 0..1`: 1 a ≤ 3 tiles, 0 a ≥ 30, linear entre.
- `NOM_AtmosphereRules.approach(cur, target, dtMs, fadeMs) -> v` (fade linear, preso no alvo).
- `NOM_AtmosphereRules.vignette(intensity) -> { blur, desat, radius, darkness, gradient }` (intensidade 0..2, valores presos nas faixas do `SearchModeFloat`).

- [ ] Testes: determinismo, ID 0/período nil, taxa ≈ chance, independência do sorteio noturno, spots atrás primeiro, raio mínimo, cooldown, validMove (mais longe/longe demais/perto demais), volume nas pontas e monotônico, approach não passa do alvo, vinheta 0 = nada. Falha → implementar → verde → commit.

### Task 3: Período de névoa no servidor e flag no cliente

**Files:** Create `server/NOM_Fog.lua`, `shared/NOM_FogState.lua`, `client/NOM_FogClient.lua`; tests `test_fog.lua`, `test_fog_client.lua`.

**Produces:**
- `NOM_FogState = { on, period }`, `NOM_FogState.set(on, period)`, `NOM_FogState.onChange(fn)` (fn(on) só na borda).
- Servidor: período em `ModData["NevoaEOutroMundo"].fog.{night,inNight}` via `NOM_EcoRules.syncNight` (conta por estado). Borda `fog` do `NOM_World`: dedicado manda `sendServerCommand(MODULE, "fog", { on, period })`; solo chama `NOM_FogState.set`. Responde `fogState`.
- Cliente MP: segue `fog`; pede `fogState` no `OnCreatePlayer`.

- [ ] Testes: `fog_sp_sets_state`, `fog_mp_broadcasts_edge_with_period`, `fog_period_counts_once_per_fog`, `fog_answers_state`, `fog_client_follows_server`, `fog_client_asks_state_on_join`. Verde, commit.

### Task 4: Sem-rosto

**Files:** Create `shared/NOM_SemRosto.lua`; Modify `server/NOM_Fog.lua`, `client/NOM_FogClient.lua`, `client/NOM_EcoClient.lua` (aceita `semRostoGone`); tests `test_semrosto.lua`, `test_fog.lua`, `test_fog_client.lua`, `test_eco_client.lua`.

**Produces:** `NOM_SemRosto.install(report)`; `report(z, x, y, z)` quando um jogador local vê um Sem-rosto e há destino. `NOM_SemRosto.isSemRosto(z) -> bool` (Eco nunca). `NOM_SemRosto.move(z, x, y, z)` = `z:teleportTo(x, y, z)`. `NOM_SemRosto.nearest(player) -> distância | nil` (pro rádio).

- Varredura a cada `SCAN_TICKS` (10) com névoa e `SemRostoEnabled`: jogadores locais vivos × zumbis da célula que são Sem-rosto; visto = `z:getCurrentSquare():isCanSee(pn)` a ≤ 30 tiles; cooldown local por zumbi; destino = primeiro `spot` com square existente, `isFree(false)` e `not isCouldSee(pn)` no andar do jogador.
- Servidor (`handleSeen(player, z, x, y, zz)`): névoa, Sem-rosto pelo próprio sorteio, `validMove`, cooldown por zumbi; solo: `move`; dedicado: `move` na cópia do servidor (vale se ninguém é dono) + `sendServerCommand("semRostoMove", { id, x, y, z })`. Fallback: visto de novo a ≤ 1,5 tile do ponto de antes do último movimento → substitui (`addZombiesInOutfit` no destino com o outfit do original, `dressInPersistentOutfitID(id)`, remove o original e manda `semRostoGone`).
- Cliente MP: report = `sendClientCommand("semRostoSeen", { id, x, y, z })`; `semRostoMove` só move a cópia **local** (`not isRemoteZombie()`).

- [ ] Testes contra fake (luz/visão por jogador, dono/remoto, posição do dono vence no servidor): `semrosto_seen_moves_closer_out_of_view`, `semrosto_unseen_stays`, `semrosto_cooldown_no_flicker`, `semrosto_no_spot_no_move`, `semrosto_only_in_fog`, `semrosto_eco_never`, `semrosto_disabled`, `fog_server_rejects_bad_move`, `fog_server_relays_move`, `fog_server_fallback_replaces_stuck`, `fog_client_only_owner_moves`, `fog_client_reports_by_online_id`. Verde, commit.

### Task 5: Som da névoa

**Files:** Create `client/NOM_FogSound.lua`, `tests/test_fog_sound.lua`; Modify `scripts/gen_sounds.py`, `media/scripts/NOM_sounds.txt`, `CREDITS.md`, `tests/test_config.lua`; gerar `NOM_RadioStatic.ogg`, `NOM_FogDrone.ogg`, `NOM_FogMetal.ogg`.

- Drone em loop (`FogAmbience`) com fade de 8 s reais; metal one-shot a cada 20–60 s reais; estática em loop com volume = `staticVolume(nearest)` (fade curto), só com `SemRostoEnabled`. Tudo por `player:playSoundLocal` + `getEmitter():setVolume/stopSoundLocal/isPlaying`; se o loop parou (arquivo sem loop), toca de novo.
- Fim da névoa: fade a 0 e `stopSoundLocal`.

- [ ] Testes contra fake de emitter (ids, volume, parar local, rede nunca): `sound_drone_fades_in_and_out`, `sound_static_follows_distance`, `sound_never_networked`, `sound_restarts_dead_loop`, `sound_toggles`. Sons declarados (`config_sound_scripts_point_to_files`). Verde, commit.

### Task 6: Vinheta

**Files:** Create `client/NOM_FogVignette.lua`, `tests/test_fog_vignette.lua`.

- Névoa + `FogVignette` + jogador não forrageando: guarda `isOverride` e `isEnabled(pn)`, liga `isOverride = true`, alvos de `vignette(intensity)`, `setEnabled(pn, true)`. Forrageou: devolve `isOverride` e larga (o vanilla assume). Parou de forragear com névoa: retoma. Névoa acabou: devolve `isOverride` e o `enabled` de antes.

- [ ] Testes contra fake do `ISSearchManager` (com o `updateOverlay` que desliga sem `isOverride`): `vignette_on_in_fog_survives_update_overlay`, `vignette_yields_to_foraging`, `vignette_restores_on_fog_end`, `vignette_off_toggle`, `vignette_keeps_foreign_override`. Verde, commit.

### Task 7: Overlays

**Files:** Create `client/NOM_FogOverlays.lua`, `tests/test_fog_overlays.lua`.

- Névoa + `FogOverlays`: a cada 1,5 s real, um `IsoMarker` num square livre aleatório a 3–12 tiles do jogador (andar dele), sprite sorteado entre `overlay_blood_floor_01_0..27` e `overlay_grime_floor_01_0..95` (os que `getTexture` acha), alpha sobe até 0,8 em 6 s; teto 40; marcador a mais de 20 tiles sai. Fim da névoa: alpha desce em 6 s e `remove()`.

- [ ] Testes (square fake que falha em qualquer escrita): `overlays_grow_slowly`, `overlays_capped`, `overlays_fade_out_and_removed_on_fog_end`, `overlays_never_touch_the_map`, `overlays_far_ones_removed`, `overlays_toggle`. Verde, commit.

### Task 8: Noite + névoa juntas

**Files:** `tests/test_night_and_fog.lua`.

- [ ] Teste `night_and_fog_together`: servidor solo com noite e névoa; Estalador e Sem-rosto no mesmo zumbi (variantes independentes): o Estalador continua cego e o Sem-rosto continua sumindo; Night, Fog e o clima não se atrapalham (flags, comandos, uma borda cada). Verde, commit.

### Task 9: Documentação

ADR-007 (Sem-rosto: quem vê avisa, o dono move; atmosfera local), índice; `pz-api-notes` §3.4, §4.3, §5, §6; GDD `monsters.md`, `atmosphere.md`, `sandbox.md`, `world-states.md`; `docs/architecture/README.md` (estrutura); README da sprint (critérios com evidência, Roteiro in-game com o probe do spike, Checkpoints, Aprendizados, Pendências, Sessões); `docs/sprints/README.md` → `em teste`. Commit.
