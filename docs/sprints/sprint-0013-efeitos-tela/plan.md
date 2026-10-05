# Efeitos de tela — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Na névoa a tela vira filme velho: grão animado, vinheta que respira (vermelha e mais forte na névoa vermelha), linhas de chiado que crescem perto do Sem-rosto e um pulso vermelho quando uma Carpideira grita perto. Opcional, um segundo mod troca o `screen.frag` por um shader original com aberração cromática, grão de verdade e distorção.

**Architecture:** (A) `client/NOM_ScreenFx.lua` cria no `OnGameStart` um `ISUIElement` de 1×1 px, `backMost()` e sem consumir mouse (o padrão do `ISSleepingUI` vanilla), que no `render()` desenha até quatro camadas por cima do mundo e por baixo do resto da UI, no retângulo de tela do jogador 0 lido a cada quadro. As alfas saem de regras puras (`shared/NOM_ScreenFxRules.lua`); a intensidade é opção de cliente (`PZAPI.ModOptions`, `client/NOM_ScreenFxOptions.lua`). (B) `mod2/` = mod `NevoaEOutroMundo_Shader`: `screen.frag` original com a mesma interface do vanilla + uma flag Lua; com a flag, o `NOM_FogVignette` (único dono do `SearchMode`) passa a usar os floats do `SearchMode` como canal Lua→shader (override ligado, enabled desligado) em vez da vinheta.

**Tech Stack:** Lua 5.1 (Kahlua no jogo, luajit nos testes), GLSL 330 do jogo, Python + numpy + Pillow pras texturas, bash pro build.

**Spec:** [brief da sprint 0013](README.md) (decisão do Johan, opção 3: overlay Lua por padrão + shader opcional pra quem não usa ShadowZ), [atmosphere.md](../../gdd/atmosphere.md), [spike do shader](../spike-shader/README.md).

## Global Constraints

- Kahlua: sem `//`, `goto`, bit ops, `next()`; `unpack`; nada de `%d` com float.
- Overlay só no cliente (`if isServer() then return end`); nada vai pra rede nem pro save.
- Toda chamada com evidência (Lua vanilla arquivo:linha ou bytecode); UNKNOWN vira fallback + linha no roteiro.
- Nada copiado: texturas por `scripts/gen_textures.py` (semente fixa), shader original; **nenhuma linha do `screen.frag` vanilla no repo**.
- Texto do jogador por chave, PTBR e EN (`UI.json`, `Mod.json`).
- Orçamento: fora da névoa ~1 chamada Java por quadro; na névoa ≤ 4 chamadas de desenho por quadro.

## Evidência (bytecode do B42.21 instalado)

- `UIManager.render`: `OnPreUIDraw` (170) → lista `UI` na ordem (240–426) → `OnPostUIDraw` (668). `UIManager.update` 389–454 move todo `isBackMost()` pro índice 0 (desenhado primeiro); `UIElement.backMost()` só liga `alwaysBack`.
- Clique: `updateMouseButtons` 54–206 percorre do topo pra baixo, `isOverElement` (caixa do elemento) e `onConsumeMouseButtonDown` → `UIElement.onMouseDown`: com `onMouseDown` no Lua, vale o retorno (nil → `consumeMouseEvents`). Roda (`update` 867–979): `isPointOver` + `onConsumeMouseWheel`. `isForceCursorVisible` (UIManager) liga o cursor com o mouse sobre qualquer elemento visível: 1×1 px evita.
- `ISSleepingUI.lua:70-82` (1×1, `setConsumeMouseEvents(false)`, desenha fora da caixa), `:16-17,60-61` (`getPlayerScreenWidth/Height/Left/Top`), `:49` (`MainScreen.instance:isReallyVisible()`), `:14` (`getTexture`); `FishingManager.lua:41` (`backMost`); `ISUIElement.lua:1032-1041` (`drawTextureScaled` com cor), `:1109-1117` (`drawTextureTiled`, uma chamada; `UIElement.DrawTextureTiled` laça `DrawSubTextureRGBA` no Java).
- `PZAPI/ModOptions.lua` (create, addTickBox, addSlider, getOptions/getOption/getValue); `MainOptions.lua:2795-2796` carrega o `ModOptions.ini` ao montar a tela, e o `MainScreen` in-game nasce no `OnGameStart` (`MainScreen.lua:2180`, `:694`). Nomes passam por `getText` (`MainOptions.lua:2805+`); `Translator$1` tem a categoria `UI`.
- Shader: `WeatherShader.onCompileSuccess` busca 24 uniforms (lista no teste); `startMainThread`/`startRenderThread`: `SearchMode = (blur, radius, offLeft, offTop)`, `ScreenInfo = (offW, offH, rcX, rcY)`, `ParamInfo = (zoom, tile, gradient·tile/2, desat)`, `VarInfo = (isShaderEnabled, darkness, -, -)`. `SearchMode.setOverride` só grava o flag; `PlayerSearchMode.update` sai na 1ª linha com override; `setEnabled` igual é no-op; `SearchModeFloat.setAll` grava atual e alvo, exterior e interior.
- Workshop: `SteamWorkshopItem.validateModsFolder` valida cada pasta de `Contents/mods/` (vários mods num item). `readModInfoAux`: `require=` tira `\` e separa por vírgula.

## Review Focus

1. Clique, roda e arrasto no canto (0,0) da tela, onde fica o elemento de 1 px: tem que passar pro jogo — teste `screenfx_corner_click_passes`.
2. Voltar ao menu e carregar outro save na mesma sessão: o elemento antigo sai da UI e não duplica — `screenfx_main_menu_removes_and_new_game_recreates`.
3. Trocar a resolução (ou entrar/sair da tela dividida) no meio da névoa: cobre a tela nova no quadro seguinte — `screenfx_follows_resolution_change`.
4. Forragear na névoa com o mod do shader: o canal sai da frente e a vinheta de busca do jogo volta normal — `vignette_channel_releases_for_foraging`.
5. Opção de intensidade 0 ou desligada no meio da névoa: some na hora, sem quadro preso — `screenfx_option_off_mid_fog`.

---

### Task 1: Regras puras (`NOM_ScreenFxRules`)

**Files:** Create `mod/42/media/lua/shared/NOM_ScreenFxRules.lua`; Test `tests/test_screen_fx_rules.lua` (registrar em `tests/run.lua`).

**Interfaces — Produces:**
- `R.FADE_MS, R.FLASH_MS, R.FLASH_NEAR, R.FLASH_FAR, R.BREATH_MS, R.GRAIN_FRAMES, R.GRAIN_FRAME_MS, R.MARKER`
- `R.step(s, want, dtMs)` → `s` com `fog`/`red` aproximados (0..1) por `NOM_AtmosphereRules.approach`; `want = {fog=bool, red=bool}`.
- `R.screamStrength(d)` → 0..1 (1 até `FLASH_NEAR`, 0 a partir de `FLASH_FAR`, nil → 0).
- `R.flash(nowMs, atMs, strength)` → 0..1, cai a 0 em `FLASH_MS`.
- `R.layers(s, now, i)` → `{grain, vignette, vr, vg, vb, lines, flash}` (alfas presas em 0..1; `i` intensidade 0..2).
- `R.grainFrame(now)` → 1..`GRAIN_FRAMES`.
- `R.channel(s, now, i)` → `{blur, radius, desat, darkness, gradient}` pros floats do SearchMode (gradient = `MARKER`).

- [ ] Testes: fora da névoa tudo 0; névoa sobe em `FADE_MS`; vermelha mais forte e vermelha (`vr > vg`); linhas crescem com o Sem-rosto perto (`staticVolume`); pulso decai e termina; longe não pulsa; `i=0` zera; `i=2` dobra preso em 1; vinheta respira dentro de limites; quadro de grão cicla; canal carrega o marcador.
- [ ] Implementar, rodar `./run-tests.sh`, commit.

### Task 2: Texturas

**Files:** Modify `scripts/gen_textures.py`, `CREDITS.md`; Create `mod/42/media/textures/NOM/ScreenFx/*.png`; Test `tests/test_look_assets.lua` (ou novo `test_screen_fx_assets` dentro de `test_screen_fx.lua`).

- `NOM_Grain1..4.png` 256² (branco, alfa = ruído em blocos de 2 px), `NOM_Vignette.png` 512² (branco, alfa radial), `NOM_Lines.png` 512×256 (branco, linhas horizontais), `NOM_White.png` 8².
- [ ] Teste: arquivos existem, tamanho certo (cabeçalho PNG), citados no CREDITS; rodar o gerador duas vezes dá os mesmos bytes. Commit.

### Task 3: Opções de cliente (`NOM_ScreenFxOptions`)

**Files:** Create `mod/42/media/lua/client/NOM_ScreenFxOptions.lua`, `Translate/{EN,PTBR}/UI.json`; Modify `tests/test_translations.lua` (literais `"UI_NOM_..."` contam como usadas).

**Produces:** `NOM_ScreenFxOptions.enabled()` → bool, `.intensity()` → 0..2. Sem `PZAPI.ModOptions`: true / 1.0.

- [ ] Teste contra um `PZAPI.ModOptions` falso que imita o vanilla (create/addTickBox/addSlider/getOption/getValue; valor trocado depois, como o `load()` faz). Commit.

### Task 4: Overlay (`NOM_ScreenFx`)

**Files:** Create `mod/42/media/lua/client/NOM_ScreenFx.lua`, `tests/test_screen_fx.lua`; Modify `mod/42/media/lua/shared/NOM_Carpideira.lua` (`C.onScream(fn)`; `C.scream` avisa).

**Consumes:** Task 1, Task 3, `NOM_FogState`, `NOM_SemRosto.nearest(p)`, `NOM_SemRostoRules.staticVolume(d)`.
**Produces:** `NOM_ScreenFx.state` (`fog, red, static, flashAt, flashStrength`), `NOM_ScreenFx.ui`.

- [ ] Fake de UI: `ISUIElement:derive`, `UIManager` com lista, `backMost` → índice 0, render na ordem, clique/roda como o bytecode acima; `getPlayerScreen*`, `MainScreen.instance`, `getTexture`.
- [ ] Testes: nasce no `OnGameStart` atrás de tudo; nada fora da névoa (1 chamada Java por quadro); grão + vinheta na névoa (≤ 4 desenhos); vermelha; linhas perto do Sem-rosto; grito perto pisca e some, longe não; menu visível/morte não desenha (morte zera); menu principal remove; resolução e tela dividida; opção desligada/0; modo shader sem grão; Review Focus 1–3, 5; dedicado inerte. Commit.

### Task 5: Canal do shader no `NOM_FogVignette`

**Files:** Modify `mod/42/media/lua/client/NOM_FogVignette.lua`, `tests/test_fog_vignette.lua`.

**Consumes:** `NOM_ShaderMod` (global da flag do mod2), `R.channel`, `NOM_ScreenFx.state`, `NOM_ScreenFxOptions`.

- [ ] Testes (fake do SearchMode com override/enabled/fade como o bytecode): com a flag nunca liga `enabled`, liga override, escreve o canal todo tick, espera o fade do forrageamento acabar, solta pro forrageamento (Review Focus 4) e no fim da névoa zera e devolve; sem a flag o comportamento antigo continua. Commit.

### Task 6: Mod do shader (`mod2/`) e build

**Files:** Create `mod2/42/mod.info`, `mod2/common/.gitkeep`, `mod2/42/media/shaders/screen.frag`, `mod2/42/media/lua/shared/NOM_ShaderFlag.lua`, `mod2/42/media/lua/shared/Translate/{EN,PTBR}/Mod.json`, `tests/test_shader.lua`; Modify `scripts/build-workshop.sh`, `scripts/dev-sync.sh`, `tests/test_build_workshop.sh`, `tests/test_kahlua_compat.lua`, `tests/test_credits.lua`, `CREDITS.md`, `docs/workshop/description-*.txt`.

- [ ] `test_shader.lua`: uniforms declarados ⊆ lista do `onCompileSuccess` (+`DIFFUSE`) e os necessários presentes; `in vec2 vUV`; `#version 330`; marcador do shader = `R.MARKER`; nenhuma linha (normalizada, ≥ 16 caracteres, fora declaração) igual ao vanilla instalado (pula se ausente); `mod.info` do mod2 (id, require, chaves no lugar certo).
- [ ] Build: `Contents/mods/NevoaEOutroMundo_Shader/` sai do commit; dev-sync copia os dois; testes do shell. Commit.

### Task 7: Docs

README da sprint (`em teste`, critérios com evidência, roteiro in-game com `scripts/dev-sync.sh` + recarregar), roadmap, GDD (atmosphere, art-direction, Overview), ADR-013 + índice, orçamento, pz-api-notes §15, README do projeto. Commit.
