# Sprint 0013 — Efeitos de tela

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0013-efeitos-tela` |
| Plano | [plan.md](plan.md) |
| GDD | [atmosphere.md](../../gdd/atmosphere.md#efeitos-de-tela-só-na-névoa), [art-direction.md](../../gdd/art-direction.md#a-tela-na-névoa-sprint-0013), [Overview.md](../../gdd/Overview.md#decisões-do-autor) |
| ADR | [ADR-013](../../architecture/adr-013-efeitos-de-tela.md) (nova); emenda ADR-004 e ADR-007 |

## Objetivo

Na névoa a tela vira filme velho: grão animado, vinheta que respira (vermelha e mais forte na
névoa vermelha), linhas de chiado que crescem perto do Sem-rosto e um pulso vermelho quando uma
Carpideira grita perto. Pra quem não usa ShadowZ, um segundo mod opcional troca o shader de
tela por um próprio, com aberração cromática, grão de verdade e distorção.

Decisão do Johan (05/10/2026), depois de ver a névoa no jogo ("LINDA", mas falta efeito de
tela): opção 3 — overlay Lua por padrão + shader opcional.

## Critérios de aceite

- [x] Camadas por estado: nada fora da névoa, fade de entrada e saída, vermelha mais forte e
      vermelha, linhas pela distância do Sem-rosto (o volume do rádio), pulso do grito que decai,
      intensidade 0–2 — `tests/test_screen_fx_rules.lua` (9 testes: `screenfx_rules_*`).
- [x] Overlay por cima do mundo e por baixo do HUD, sem pegar clique nem roda nem forçar o
      cursor — `screenfx_created_behind_hud`, `screenfx_corner_click_passes` (fake do
      `UIManager` com a ordem e o clique do bytecode: `update` 389–454, `render` 240–426,
      `updateMouseButtons` 54–206, `UIElement.onMouseDown` 644–667; padrão do
      `ISSleepingUI.lua:70-82`).
- [x] Grão animado e vinheta na névoa, linhas com o Sem-rosto perto, pulso no grito perto e não
      longe, vermelha — `screenfx_fog_draws_grain_and_vignette`, `screenfx_lines_with_semrosto_distance`,
      `screenfx_carpideira_scream_flash`, `screenfx_red_fog_red_and_stronger`; erro do efeito não
      para o grito — `screenfx_scream_listener_error_does_not_break_scream`.
- [x] Resolução, tela dividida (jogador 0), menu, morte e volta ao menu principal —
      `screenfx_follows_resolution_change`, `screenfx_menu_and_death_hide`,
      `screenfx_main_menu_removes_and_new_game_recreates`; dedicado não carrega —
      `screenfx_inert_on_dedicated`.
- [x] Opção de cliente (B42 tem `PZAPI.ModOptions`): liga/desliga e intensidade, lidas a cada uso;
      sem a API, padrão — `screenfx_options_*`, `screenfx_option_off_mid_fog`,
      `screenfx_intensity_scales`; traduções EN/PTBR em `UI.json` (`translations_lua_keys_defined`
      agora conta as chaves `UI_NOM_*` passadas ao `ModOptions`).
- [x] Orçamento — `screenfx_nothing_outside_fog_cheap` (1 chamada por quadro fora da névoa),
      `screenfx_fog_draws_grain_and_vignette` (≤ 4 desenhos, ≤ 12 chamadas); tabela no
      [architecture/README.md](../../architecture/README.md#orçamento-por-sistema).
- [x] Texturas originais e determinísticas, RGBA, no CREDITS — `screenfx_assets_*`
      (`scripts/gen_textures.py`, gerador próprio: as texturas das sprints anteriores não mudam).
- [x] Shader original com a interface do jogo, sem texto do vanilla, compilando —
      `shader_declares_game_interface` (uniforms ⊆ os 24 do `WeatherShader.onCompileSuccess`, com
      os tipos do `glUniform*`), `shader_has_no_vanilla_text` (contra o `screen.frag` instalado),
      `shader_compiles` (`glslangValidator`, também em 120 à mão), `shader_marker_matches_lua`.
- [x] Canal Lua → shader sem brigar com a vinheta — `vignette_channel_*` (um dono só do
      `SearchMode`; override sem `enabled`; espera o fade do forrageamento; solta zerado),
      `vignette_no_channel_without_shader_mod`.
- [x] Segundo mod no mesmo item do Workshop, no build e no dev-sync — `build_ships_shader_mod`,
      `build_refuses_uncommitted_change_in_mod2`, `dev_sync_copies_both_mods`,
      `build_excludes_repo_only` (`Contents/mods` com os dois; `validateModsFolder` valida cada
      pasta), `shader_modinfo`, `shader_mod_translations`.
- [ ] Os efeitos aparecem no jogo, por baixo do HUD e sem atrapalhar clique — **falta o jogo:**
      roteiro, passos 1–4.
- [ ] Linhas do Sem-rosto e pulso da Carpideira no jogo — **falta o jogo:** passos 5–6.
- [ ] Opções > Mods mostra e aplica as opções — **falta o jogo:** passo 7.
- [ ] Menu, morte, resolução, sair e voltar — **falta o jogo:** passo 8.
- [ ] Shader opcional compila e aparece (sem ShadowZ) — **falta o jogo:** passo 9.

`./run-tests.sh`: `total=499 passou=499 falhou=0` (Lua) e `build total=25 passou=25 falhou=0`.

## Roteiro in-game

**Antes:** `scripts/dev-sync.sh` (copia `mod/` e `mod2/` pra pasta de mods do jogo; não use
symlink) e **recarregue o save** (o Lua novo só entra ao carregar). Jogo em `-debug`, save
descartável. Console em `~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt`.
Passos 1–8 **sem** o mod do shader ativo (o ShadowZ pode continuar).

1. **Carregou.** Abrir o save. **Esperado:** no console `[NOM] tela: overlay criado (shader=false)`
   e nenhuma linha com `NOM_` e `ERROR`.
2. **Névoa.** `NOM_Debug.fog(true, true)`. **Esperado:** em ~4 s a tela ganha grão fino (mais
   visível no escuro) e as bordas escurecem e clareiam devagar (~7 s por ciclo), por cima da
   vinheta de desfoque que já existia. HUD, barra de itens e menus por cima do efeito, nítidos.
   **Se** o grão ou a vinheta não aparecerem: a textura do mod não foi achada pelo `getTexture`
   (registrar). **Se** aparecerem por cima do HUD: o `backMost` não pôs o elemento no fundo.
3. **Clique.** Na névoa, clicar no mundo (andar, atacar), arrastar item no inventário, rolar o
   zoom, clicar bem no canto de cima à esquerda da tela. **Esperado:** tudo funciona como sem o
   mod; o cursor some sozinho como sempre.
4. **Vermelha.** `NOM_Debug.fog(false)`, esperar sumir (~4 s), `NOM_Debug.redFog(true)`.
   **Esperado:** a vinheta fica vermelha escura e mais fechada.
5. **Sem-rosto.** Na névoa, `NOM_Debug.variant("semrosto")` num zumbi a ~20 tiles, ir chegando
   perto. **Esperado:** linhas horizontais claras, pulando, mais fortes quanto mais perto (junto
   com o rádio chiando).
6. **Carpideira.** `NOM_Debug.variant("carpideira")` num zumbi, chegar a 4 tiles. **Esperado:** no
   grito, um pulso vermelho na tela que some em menos de 1 s. Outra Carpideira acordada a mais
   de 30 tiles: sem pulso.
7. **Opções.** Esc > Opções > aba Mods > "Névoa e Outro Mundo". **Esperado:** "Efeitos de tela na
   névoa" (ligado) e "Intensidade dos efeitos de tela" (1.0). Intensidade 2: mais forte; 0 ou
   desligado: some no quadro seguinte. Fechar o jogo e abrir: o valor ficou.
8. **Menu, morte, resolução.** Com a névoa: Esc (o efeito some atrás do menu), trocar a resolução
   ou a janela de tamanho (o efeito cobre a tela nova), morrer (some; no personagem novo, entra
   com fade), sair pro menu principal e carregar o save de novo (`overlay criado` uma vez só).
9. **Shader (opcional, só sem ShadowZ).** Desativar o ShadowZ, ativar "Névoa e Outro Mundo — Shader"
   no save, **fechar e abrir o jogo** (o shader compila no primeiro mundo da sessão), carregar.
   **Esperado:** console com `[NOM] tela: overlay criado (shader=true)` e sem erro de compilação
   do `screen`; fora da névoa a tela igual à vanilla (cores, forrageamento com o círculo, óculos
   de visão noturna verdes); na névoa, bordas desfocadas e sem cor, cores separando nas bordas
   (aberração), grão forte, onda leve; com o Sem-rosto perto, faixas escorregando; na vermelha,
   bordas avermelhadas. Forragear na névoa: o círculo de busca normal; parar: o efeito volta.
   **Se** a tela ficar preta ou rosa: erro de compilação (copiar as linhas do console).

## Checkpoints

- **04/10/2026** — Sprint aberta (decisão do Johan de 05/10, opção 3). Bytecode: ordem de render e
  de clique da UI, `backMost`, `PZAPI.ModOptions`, uniforms e `vars` do `WeatherShader`, override do
  `SearchMode`, multi-mod no Workshop. Plano escrito.
- **04/10/2026** — Regras puras, texturas, opções de cliente, overlay de 1 px, canal do shader no
  `NOM_FogVignette`, mod2 com `screen.frag` original, build e dev-sync. Docs: ADR-013,
  pz-api-notes §15, GDD, orçamento. Em teste.

## Aprendizados

- **Elemento de UI do tamanho da tela "está sob o mouse" o tempo todo.** Mesmo sem consumir
  clique, o `UIManager.isForceCursorVisible` mantém o cursor ligado e a roda passa por ele. Um
  elemento de 1×1 px que desenha fora da própria caixa (o `ISSleepingUI` faz isso) não toca no
  mouse.
- **`backMost()` não move nada na hora:** só liga um flag; o `UIManager.update` é que põe o
  elemento no índice 0, a cada update.
- **Override do `SearchMode` no meio de um fade o congela pra sempre.** `isShaderEnabled` fica
  `true` e o shader lê o círculo de busca. Tomar só com `isShaderEnabled()` falso.
- **O `luajit` dos testes não acha `client/` pelo `require`** (o `package.path` só tinha shared e
  server); o jogo acha. `tests/run.lua` agora inclui `client/`.
- **Global de teste vaza entre arquivos** (`NOM_ShaderMod` ligado num teste quebrou outro, na
  ordem aleatória do `pairs`): `tests/run.lua` zera a flag antes de cada teste.

## Pendências que a próxima sprint herda

- Tudo do roteiro acima; em especial os UNKNOWNs do [pz-api-notes §15](../../architecture/pz-api-notes.md#15-efeitos-de-tela-sprint-0013):
  texturas pelo `getTexture`, a página de opções, o shader no driver.
- Tela dividida: só o jogador 0 tem o efeito.
- `incompatible=\ShadowZ` no `mod.info` do mod2 (id `ShadowZ`, passado pelo coordenador no review):
  falta ver no jogo que a lista de mods recusa os dois juntos (roteiro, passo 9).
- Antes de subir pro Workshop: decidir se o mod2 vai no mesmo item (como está no build) ou num
  item separado; o build manda os dois.

## Sessões

- 2026-10-05 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — plano, overlay, opções, canal, shader, build, docs
