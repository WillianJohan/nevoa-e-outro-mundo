# Dissolve e bloom — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A peça da variante se forma e se desfaz queimando (ruído, borda laranja) quando o zumbi vira monstro e quando volta; o Eco queima e some com brasas ao morrer; com o mod do shader, a tela ganha bloom, mais forte na névoa. Tudo com opção do jogador.

**Architecture:** Um shader de peça novo, `NOM_Dissolve` (`.vert`, `_static.vert`, `.frag`, código original com a interface do item-model do jogo), entra por `<m_Shader>` em itens **gêmeos** `*Fx` das peças (as originais ficam sem shader: opção desligada = sprint 0017 exata, e é o fallback se o shader não compilar). O limiar vem do `Alpha` por personagem: `client/NOM_Dissolve.lua` faz `setAlpha(pn, min(a, atual))` no `OnTick`, com regras puras em `shared/NOM_DissolveRules.lua` (faixa 0,85–1, teto de efeitos). O `NOM_VariantLook` dissolve pra dentro no `put` e pra fora antes do `strip`. A morte do Eco (`client/NOM_EcoFx.lua`) troca o véu pelo gêmeo e veste a casca (Hazmat vanilla com as máscaras do `HazmatSuit.xml`) pelo `WornItems`, dissolve até o corpo nascer, esconde o corpo e solta brasas pelo overlay da 0013 (`client/NOM_Embers.lua`, regras em `shared/NOM_EmberRules.lua`). O bloom é uma passada no `screen.frag` do mod2; a intensidade do jogador vai no marcador do gradiente do canal (`13 + bloom/4`).

**Tech Stack:** Lua 5.1 (Kahlua no jogo, luajit nos testes), GLSL 330 (e a reescrita do jogo pra 120), `glslangValidator`, `./run-tests.sh`.

**Spec:** brief da sprint 0018 (pedido do Johan, 2026-10-05), [spike-dissolve](../spike-dissolve/README.md), [spike-motor-visual](../spike-motor-visual/README.md), [README da sprint](README.md).

## Evidência (bytecode B42.21, `projectzomboid.jar`)

- Shader novo por nome: `ClothingItemXML.m_Shader` → `ClothingItemAssetManager.onFileTaskFinished` 170–173 → `PopTemplateManager.addClothingItem` 100–157 → `ShaderManager.getOrCreateShader` 86–110 (`new Shader(nome, static, instanced)`; caixa diferente de um existente lança `IllegalArgumentException`). Arquivos: `ShaderProgram.getRootVertFileName` (`<nome>[_static].vert`), `getRootFragFileName` (`<nome>.frag`), lidos pelo `activeFileMap` (`ZomboidFileSystem.loadMod` 216).
- Falha de compilação: `ShaderProgram.compile` 147–308 marca `compileFailed`, chama `destroy()` (programa 0) e loga `DebugType.Shader.error` com o log do driver. Nada confere isso no desenho: `Model.DrawSolid` 141–160 chama `effect.Start()` → `glUseProgramObjectARB(0)` (pipeline fixa). O motor não tem fallback; o do mod é a opção.
- Reescrita GL 2.1 (`ShaderUnit.processShaderSyntax`, linhas com `trim`): `#version 330` → `120`; no `.vert`, `^layout\s*\(\s*location\s*=\s*([0-9]+)\s*\)\s*in\s*([A-Za-z0-9]+)\s*([A-Za-z0-9]+)\s*;\s*$` → `attribute`, `^out\s*(\S+)\s*(\S+)\s*;` → `varying`; no `.frag`, `^in\s*(\S+)\s*(\S+)\s*;` → `varying`, `out vec4 colour` some, `colour = X;` → `gl_FragColor`. Só `texture2DLod` vira `texture2D`.
- Uniforms do `skinnedmodel.Shader.onProgramCompiled`: `MatrixPalette`, `transform`, `HueChange`, `LightingAmount`, `Light0..4Colour/Direction`, `TintColour`, `Alpha`, `Texture`, mais os de veículo; `setScale` → `FinalScale`, `setTargetDepth` → `targetDepth`, `setDepthBias` → `DepthBias`; `ModelViewProjection` pelo `VertexBufferObject.setModelViewProjection`; atributos por índice do elemento (`VertexBufferObject.BeginDraw`), daí o `layout (location = N)`.
- `IsoObject.setAlpha(IF)` (sai no servidor; clamp 0..1), `getAlpha(I)`, públicos. `IsoGameCharacter.isUpdateAlphaDuringRender` = false: o valor do `OnTick` vale pro quadro. `updateAlpha(IFF)` anda `0.28·multiplicador` por update em direção ao alvo.
- Morte: `IsoGameCharacter.Kill` 35–50 roda `onKilled` (inventário, `OnZombieDead`) e só depois `setOnKillDone(true)`; `IsoZombie.isUsingWornItems` = `isOnKillDone || isOnDeathDone || …` e então `getItemVisuals` sai do `WornItems` (0–38): durante a animação de morte o modelo é feito do `WornItems`. `WornItems.setItem(ItemBodyLocation, InventoryItem)`, `InventoryItem.getBodyLocation()`, `getVisual()` públicos.
- Corpo: `IsoDeadBody.getOutfitName()` (`HumanVisual.getOutfit().name`), `setDoRender(Z)` (+ `setInvalidateNextRender`), públicos. Cliente de MP: `dieNetwork` 0–10 = `Kill` e logo `becomeCorpse` (§14.4): sem janela.

## Global Constraints

- Kahlua: sem `//`, `goto`, bit ops, `next`, `table.unpack`; `%` em tempo real só por `NOM_Math.mod` (lint `kahlua_percent_safe`).
- Tudo do efeito é local (ADR-012, ADR-013): nada vai pela rede nem pro save; o servidor dedicado não carrega os arquivos de cliente (`if isServer() then return end`).
- Shaders **originais**: nenhuma linha do vanilla (heurística da 0013 contra os arquivos instalados), só a interface (nomes, tipos, `layout`).
- Prefixo `NOM_` em todo nome de shader e item (nome em caixa diferente de um existente derruba o carregamento).
- Texto visível por chave de tradução, PTBR e EN (`UI.json`, `ItemName.json`).
- Opção desligada = comportamento da sprint 0017, sem shader nenhum nas peças.
- Comentários e docs em português do Brasil.

## Review Focus

- Zumbi que **não** está à vista (alvo de alfa 0) durante o efeito não pode aparecer: o efeito nunca sobe o alfa acima do que o jogo deixou. Teste: `dissolve_never_reveals_unseen_zombie` (Task 2).
- Névoa que volta (ou passada que pede a mesma variante) no meio do "dissolver pra fora": a peça volta a se formar, não some. Teste: `dissolve_look_leave_cancelled_by_same_look` (Task 3).
- Variante que morre ou objeto reaproveitado no meio do efeito: loot exato e nada de alfa preso. Testes: `dissolve_look_dead_mid_leave_loot_exact`, `dissolve_look_reuse_mid_effect` (Task 3).
- Névoa vermelha com horda: o teto de efeitos simultâneos vale e o resto fica instantâneo, sem engasgar o fim (os `strip` continuam espalhados). Teste: `dissolve_look_red_fog_cap` (Task 3).
- Opção de bloom com o forrageamento: o canal fora da névoa (só pelo bloom) solta pro forrageamento e volta. Teste: `vignette_channel_bloom_yields_to_foraging` (Task 6).

---

### Task 1: Regras puras do dissolve e das brasas

**Files:** Create `mod/42/media/lua/shared/NOM_DissolveRules.lua`, `mod/42/media/lua/shared/NOM_EmberRules.lua`; Test `tests/test_dissolve_rules.lua`, `tests/test_ember_rules.lua` (registrar em `tests/run.lua`).

**Produces:** `NOM_DissolveRules.{BAND=0.85, MS, FADE_MS, CAP}`, `alpha(t)`, `start(mode, now, from)` (mode `"in"|"out"|"death"`), `threshold(e, now)`, `step(e, now) → alpha, done`. `NOM_EmberRules.{COUNT, LIFE_MS, CAP}`, `burst(seed) → partículas`, `at(p, ms) → dx, dy, a, r, g, b, size | nil`.

- [ ] Testes: faixa (0 → 0,85, 1 → 1), "in" de 0 a 1 em `MS`, "out" de 1 a 0, partida do limiar atual (troca no meio), morte = limiar até 0 e depois alfa de 0,85 a 0 em `FADE_MS`; brasas determinísticas pela semente, sobem, apagam no fim da vida, cor de laranja pra cinza.
- [ ] Rodar `./run-tests.sh` (falha), implementar, passar, commit.

### Task 2: Driver do alfa (`client/NOM_Dissolve.lua`) e opções

**Files:** Create `mod/42/media/lua/client/NOM_Dissolve.lua`; Modify `client/NOM_ScreenFxOptions.lua` (tickbox `Dissolve`, slider `Bloom` 0–2), `Translate/*/UI.json`; Test `tests/test_dissolve.lua`, `tests/test_screen_fx_options.lua`.

**Produces:** `NOM_Dissolve.enabled()`, `run(z, mode, done) → bool` (false = desligado ou teto), `stop(z)`, `busy(z)`, `count()`. `NOM_ScreenFxOptions.dissolve()`, `bloom()`.

- [ ] Testes contra zumbi falso com o alfa do jogo (alfa por jogador, `updateAlpha` anda 0,28 pro alvo a cada tick, `setAlpha` com clamp, servidor sem alfa): alfa por quadro na faixa, `min` com o atual (`dissolve_never_reveals_unseen_zombie`), dois jogadores locais, teto, callback no fim, zumbi fora do mundo (`getCurrentSquare` nil) limpa, `OnZombieCreate` e `OnMainMenuEnter` limpam, desligado não faz nada, orçamento (`dissolve_budget`: ≤ 1 + 2·P chamadas por efeito por tick, zero sem efeito).
- [ ] Implementar, passar, commit.

### Task 3: Peças gêmeas com shader e o `NOM_VariantLook`

**Files:** Create `clothing/clothingItems/NOM_{EstaladorVenda,CorredorBoca,SemRostoEstatica,CarpideiraCabelo,EcoVeu}Fx.xml` (mesmo modelo e textura, `<m_Shader>NOM_Dissolve</m_Shader>`), `NOM_EcoCasca.xml` (Bob/Kate_Hazmat, máscaras do `HazmatSuit.xml`, `NOM\NOM_EcoCinza`, shader); Modify `scripts/NOM_clothing.txt`, `fileGuidTable.xml`, `ItemName.json` (EN/PTBR), `client/NOM_VariantLook.lua`; Test `tests/test_variant_look.lua`, `tests/test_look_assets.lua`.

- [ ] `LOOKS[k].fx`; `put` usa o gêmeo com o dissolve ligado e chama `run(z, "in")`; fim da variante (`sync` com nil) chama `leave`: `run(z, "out", fim)` e o `strip` real só no fim; mesma variante de volta cancela o `leave` (`run(z, "in")` do limiar atual); troca de tipo, morte e reaproveitamento fazem `strip` na hora com `stop`.
- [ ] Testes (opção ligada no fake): forma na mutação, desfaz e só então devolve a roupa, cancelamento, morte no meio com loot exato, reaproveitamento, teto na vermelha, desligado = peça sem shader e instantâneo (testes antigos rodam com a opção desligada). Assets: 12 itens, gêmeos com o mesmo modelo/textura e shader, casca com as máscaras.
- [ ] Implementar, passar, commit.

### Task 4: Shader `NOM_Dissolve`

**Files:** Create `mod/42/media/shaders/NOM_Dissolve.vert`, `NOM_Dissolve_static.vert`, `NOM_Dissolve.frag`; Modify `CREDITS.md`; Test `tests/test_dissolve_shader.lua`.

- [ ] Testes: uniforms ⊆ os que o jogo manda (tipos), atributos com o `layout` do jogo, `NOM_BAND` = `NOM_DissolveRules.BAND`, sem `#include`, sem linha do vanilla (`basicEffect*.vert/.frag` instalados), compila no `glslangValidator` em 330 **e** depois da reescrita GL 2.1 do jogo (a mesma regex do `ShaderUnit`, feita no teste), pula sem o validador.
- [ ] Implementar, passar, commit.

### Task 5: Morte do Eco e brasas

**Files:** Create `client/NOM_EcoFx.lua`, `client/NOM_Embers.lua`; Modify `client/NOM_ScreenFx.lua` (lista `NOM_ScreenFx.extra` de desenhos por quadro, fora do teste da névoa); Test `tests/test_eco_fx.lua`, `tests/test_screen_fx.lua`.

- [ ] Testes contra o jogo falso: solo (`OnZombieDead` com o `WornItems` cheio, `onKillDone` depois, o modelo pelo `WornItems`): véu vira o gêmeo, casca no `WornItems` (`SHELL`), `resetModelNextFrame`, efeito "death", brasas; corpo que nasce com o outfit do Eco fica com `setDoRender(false)`; cliente de MP (corpo no mesmo tick): corpo escondido e brasas; opção desligada não toca em nada; zumbi comum ignorado; brasas desenhadas pelo overlay sem névoa, com teto, e o quadro sem brasa continua 1 chamada.
- [ ] Implementar, passar, commit.

### Task 6: Bloom no `screen.frag` do mod2 e o canal

**Files:** Modify `mod2/42/media/shaders/screen.frag`, `shared/NOM_ScreenFxRules.lua` (`BLOOM_SCALE`, `channel(s, now, i, bloom)`), `client/NOM_FogVignette.lua` (canal também fora da névoa quando o bloom > 0); Test `tests/test_shader.lua`, `tests/test_fog_vignette.lua`, `tests/test_screen_fx_rules.lua`.

- [ ] Testes: marcador e escala iguais ao shader, `gradient = 13 + bloom·0,25`, canal tomado fora da névoa só com bloom, solta pro forrageamento, bloom 0 fora da névoa = sem canal (0013 igual), shader compila e não copia o vanilla.
- [ ] Implementar, passar, commit.

### Task 7: Docs

- [ ] README da sprint (status `em teste`, critérios com evidência, roteiro com os probes 1–5 adaptados), roadmap, ADR-016 + índice, pz-api-notes §6 e §17, GDD (atmosphere, art-direction, monsters, Overview 2026-10-05), orçamento, correção do spike-motor-visual. Commit.
