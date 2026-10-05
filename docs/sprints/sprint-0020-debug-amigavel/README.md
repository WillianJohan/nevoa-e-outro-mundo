# Sprint 0020 — Debug amigável (NOM.* + painel)

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0020-debug-amigavel` |
| Plano | [plan.md](plan.md) |
| GDD | nenhum sistema de jogo novo (ferramenta de teste); roteiro em [teste-in-game.md](../../teste-in-game.md#atalhos-de-debug-console-lua-do-modo-debug) |
| API | [pz-api-notes §18](../../architecture/pz-api-notes.md#18-debug-amigável-sprint-0020) |

## Objetivo

Com o jogo em `-debug`, o Johan testa o mod com comandos curtos no console (`NOM.fog()`,
`NOM.spawn(5)`, `NOM.help()`) ou pelo painel de botões aberto com Insert, sem decorar os
`NOM_Debug.*` (que continuam valendo).

Pedido do Johan: "coloca os comandos mais user-friendly (`NOM_Debug.setFog(true)` →
`NOM.setFog(true)`)" e "autocomplete no console". O autocomplete não dá: o console do debug
é Java (`zombie/ui/UIDebugConsole`) e o `SuggestionEngine` só sugere métodos Java do
`GlobalObject` por reflexão; função Lua nunca aparece e mod não estende
([pz-api-notes §18](../../architecture/pz-api-notes.md#18-debug-amigável-sprint-0020)). No lugar:
`NOM.help()` e o painel.

## Critérios de aceite

- [x] `NOM` só existe no cliente com `-debug` (nada sem `-debug`, nada no servidor dedicado)
      — `nom_absent_without_debug`, `nom_absent_on_server`.
- [x] Atalhos: `NOM.fog(on, skip)`, `NOM.redFog(on)`, `NOM.night(on)`, `NOM.time(h)`,
      `NOM.spawn(n, outfit)`, `NOM.variant(kind)`, `NOM.eco()`, `NOM.god(on)`, `NOM.noclip(on)`,
      `NOM.invisible(on)`, `NOM.status()`, `NOM.help()`, `NOM.panel()`; toggle sem argumento
      inverte — `nom_fog_toggle_goes_to_server`, `nom_fog_explicit_is_old_fog`,
      `nom_red_and_night_flip_local_state`, `nom_time_wraps_hour`,
      `nom_spawn_clamps_and_aims_ahead`, `nom_variant_eco_status_alias`,
      `nom_cheats_toggle_and_sync`, `nom_panel_calls_panel_toggle`.
- [x] `NOM.fog()` durante a sirene cancela, e `NOM.redFog()` com a vermelha aberta ou na
      sirene desfaz (o servidor decide os dois toggles, ele sabe da contagem) —
      `debug_fog_toggle_cancels_siren`, `debug_rules_parse_fog_toggle`,
      `nom_red_and_night_flip_local_state`, `debug_rules_parse_red_fog`.
- [x] `NOM.time` muda o relógio pelo servidor, com a mesma porta (`-debug`, permissão no
      dedicado); 25 vira 1, -1 vira 23; infinito e NaN dão a linha de uso; **nunca pra trás**:
      hora que já passou vai como `h + 24` e o jogo avança o dia (idade do mundo só cresce) —
      `debug_time_sets_clock`, `debug_time_never_goes_back`, `debug_rules_parse_time`,
      `nom_time_wraps_hour`.
- [x] `NOM.spawn` espalha os zumbis num 3×3 centrado 3 tiles na frente do jogador
      (`addZombiesInOutfitArea` no servidor; tile sem square fica sem zumbi); 1 a 50; o
      servidor recusa tile a mais de 10 tiles ou de um andar de quem pede, outfit fora do
      `getAllOutfits` (`spawn outfit desconhecido=…`) e quem não tem permissão —
      `debug_server_spawn_in_front`, `debug_server_spawn_rejects_far`,
      `debug_server_spawn_rejects_unknown_outfit`, `debug_rules_spawn_clamps`,
      `debug_rules_parse_spawn`.
- [x] `NOM.help()` lista todo comando com uma linha em PT-BR, e só o que existe —
      `nom_help_lists_every_command`.
- [x] `NOM_Debug.*` intactos — os 19 testes antigos do `test_debug.lua` sem mudança de
      expectativa (os fakes da sirene, do relógio e do spawn ficaram mais fiéis: contagem,
      dia que vira com hora ≥ 24, lista vazia pra square nil ou outfit desconhecido).
- [x] Painel (`ISCollapsableWindow`) com névoa (inverte, já, fim), vermelha, noite / dia /
      relógio, horas 0/6/12/18/22, spawn 1/5/10, Eco, as quatro variantes no mais perto, deus,
      noclip, invisível (com "sim/não") e linha de estado a cada segundo — 
      `debug_panel_buttons_call_nom` (todo botão testado), `debug_panel_toggle_titles_show_state`,
      `debug_panel_status_refreshes_each_second`.
- [x] Abre pela tecla das opções do mod (`PZAPI.ModOptions:addKeyBind`, padrão Insert, só com
      `-debug`) e por `NOM.panel()`; fechado sai do UIManager; posição pelo `ISLayoutManager`
      — `screenfx_options_debug_key_only_in_debug`, `screenfx_options_debug_key_follows_rebind`,
      `debug_panel_key_toggles`, `debug_panel_close_removes_from_ui`,
      `debug_panel_remembers_position`, `debug_panel_absent_without_debug`,
      `debug_panel_needs_player`.
- [x] Textos do painel e da tecla em PT-BR e EN, sem `%` sozinho (o teste agora olha o
      `UI.json` também) — `translations_lua_keys_defined`, `translations_no_lone_percent`.
- [ ] O painel abre com Insert no jogo, os botões fazem o que dizem e fechado não atrapalha
      clique nem tecla — **falta o jogo:** roteiro, passos 1–5.
- [ ] A tecla aparece em Opções > Mods só com `-debug` e a troca vale sem reiniciar —
      **falta o jogo:** passo 6.
- [ ] MP (dedicado): spawn, hora e truques como admin — **falta o jogo:** passo 7.

`./run-tests.sh`: `total=680 passou=680 falhou=0` (Lua), `contraste total=4 passou=4`,
`build total=25 passou=25`.

## Roteiro in-game

Jogo em `-debug`, **save descartável** (noite e névoa forçadas avançam os contadores salvos,
[teste-in-game.md](../../teste-in-game.md)). Console em
`~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt` (Flatpak).

1. **Console.** No save, console Lua: `NOM.help()`. **Esperado:** 13 linhas
   `[NOM] NOM.fog(on, skip) - névoa: …` até `[NOM] NOM.help() - esta lista`. `NOM.status()`
   imprime `[NOM] debug local …` e `[NOM] debug servidor …`.
2. **Abrir.** Apertar **Insert**. **Esperado:** janela "Névoa e Outro Mundo: debug" com 6 linhas
   de botões e a linha "Noite: … Névoa: … Vermelha: … Hora: HH:MM Monstros aqui: N" mudando
   a hora sozinha. Insert de novo fecha. Nenhuma ação do jogo dispara junto com o Insert (se disparar:
   trocar a tecla nas opções e anotar). **Não usar F7**: em `-debug` é o editor de veículos do
   jogo. Sem `-debug`, Insert não faz nada e `NOM` é `nil`.
3. **Névoa.** "Névoa (liga/desliga)": `[NOM] debug nevoa sirene=true` e a sirene. Clicar de
   novo **antes dos 30 s**: `[NOM] debug nevoa fim=true`, sem névoa depois. "Névoa já":
   névoa no próximo tick. "Vermelha (liga/desliga)": `[NOM] debug nevoa vermelha=true`, fica
   vermelha. "Fim da névoa": `[NOM] debug nevoa fim=true`.
4. **Hora e noite.** "22h": `[NOM] debug hora=22.00`, o céu escurece e a linha diz `Hora: 22:00`;
   em até um minuto de jogo `Noite: sim`. "06h" vai pro **dia seguinte** às 06:00 (o relógio
   nunca volta; a data no canto avança um dia). "Noite"/"Dia"/"Relógio":
   `[NOM] debug noite forcada=true/false/nil`.
5. **Spawn, variantes, truques.** "5 zumbis": `[NOM] debug spawn n=5 criados=5 outfit=-` e 5
   zumbis espalhados num 3×3 ~3 tiles na frente de onde o personagem olha (`criados` menor perto
   de parede é esperado). `NOM.spawn(2, "Polcie")`: `[NOM] debug spawn outfit desconhecido=Polcie`. Com a névoa aberta, "Vira Corredor":
   `[NOM] debug variante id=… forcada=corredor` e o mais perto vira Corredor. "Deus": título
   vira "Deus: sim", `[NOM] debug god=true`, zumbi não machuca. "Noclip": atravessa parede.
   "Invisível": zumbis não te veem. "Eco aqui" à noite: `[NOM] debug eco spawn=true`.
   Fechar o painel e clicar no mundo onde ele estava: o clique vai pro jogo.
   Reabrir: a janela volta no mesmo lugar (também depois de sair e carregar o save).
6. **Tecla.** Opções > Mods > Névoa e Outro Mundo: "Painel de debug do mod (só com -debug)"
   com Insert. Trocar pra Home, aplicar: Home abre, Insert não. Sem `-debug` a linha não aparece.
7. **MP** (dedicado com `-debug`, cliente admin com `-debug`): `NOM.spawn(3)` → linha
   `[NOM] debug spawn n=3 criados=3` no console do **servidor** e os 3 zumbis aparecem no
   cliente; `NOM.time(22)` → o céu do cliente muda em segundos e a data do cliente bate com a do
   servidor depois de `NOM.time(6)` (dia seguinte); `NOM.god()` vale no
   cliente. Cliente sem permissão: `[NOM] debug negado` no servidor e nada acontece.

## Rulings do Claude

1. **Toggle da névoa decidido pelo servidor.** `NOM.fog()` manda `toggle` e o servidor olha
   névoa aberta **ou sirene contando**; o cliente não sabe da contagem e inverteria pelo
   `NOM_FogState.on` (tocaria outra sirene em vez de cancelar). A vermelha também (review:
   `NOM_World.red` ou `status().sirenRed`). A noite inverte pelo estado local
   (`NOM_NightStats.night`), que o cliente tem. Custo se errado: nenhum conhecido.
2. **`NOM.night()` sem argumento inverte, não devolve pro relógio.** O brief manda inverter;
   o relógio fica no `NOM_Debug.night()` (e no botão "Relógio"), citado no `help`. Custo se
   errado: quem quer o relógio digita o comando antigo.
3. **Spawn mirado no cliente, conferido no servidor.** O cliente sabe pra onde o próprio
   personagem olha; o servidor recebe x/y/z e recusa a mais de 10 tiles do jogador (e NaN,
   e infinito) ou a mais de um andar. Outfit até 64 letras e conferido no `getAllOutfits`
   (masculino ou feminino). Espalhado num 3×3 pelo `addZombiesInOutfitArea` (review). Custo
   se errado: nenhum conhecido.
4. **God, noclip e invisível são locais**, como o painel de admin do vanilla
   (`setX` + `sendPlayerExtraInfo`); não passam pelo servidor do mod. No MP quem barra é o
   jogo. Custo se errado: num dedicado o truque pode valer só na tela de quem pediu (passo 7).
5. **Tecla na página de opções do mod que já existe** (`NOM_ScreenFxOptions`), criada só
   com `-debug`; padrão **Insert** (a review achou F7 = editor de veículos do vanilla em
   `-debug`, `IngameState.updateInternal` 547–606; F2/F8/F9 também do debug; nenhuma das 46
   classes que leem teclado usa Insert). Sem a API, Insert fixo. Custo se errado: o jogador
   troca na hora em Opções > Mods.
6. **Fechar tira do UIManager** (o `close` do vanilla só esconde). Reabrir põe de novo
   (`AddUI` não duplica). Custo se errado: nenhum conhecido.
7. **Hora com `NOM_Math.mod`** (25 → 1, -1 → 23) e "HH:MM" sem `%d` (concatenação de
   `math.floor`). **Sempre pra frente** (review): hora menor que a de agora vira `h + 24` e o
   `GameTime.update` (938–972) avança o dia e marca o sync. Custo: não dá pra voltar uma hora
   no mesmo dia (pra isso, o Debug → Time do vanilla). Botões de hora em vez de slider.
8. **Sem ADR nova:** é ferramenta de teste, a arquitetura (servidor decide, porta do
   `-debug`) é a da sprint 0006. Evidência nova toda na §18 do pz-api-notes.

## Checkpoints

- **04/10/2026** — Sprint aberta a partir do pedido do Johan; autocomplete descartado pelo
  bytecode (`UIDebugConsole.InitSuggestionEngine`). Plano escrito.
- **04/10/2026** — Regras (`time`, `spawn`, toggle da névoa) e servidor; `NOM_Debug.send`. Verde.
- **04/10/2026** — `NOM` (`client/NOM_Console.lua`) com toggles, truques e `help`. Verde.
- **04/10/2026** — Tecla nas opções do mod e painel (`client/NOM_DebugPanel.lua`). Verde.
- **04/10/2026** — Docs: este README, roadmap, teste-in-game, README, pz-api-notes §18,
  estrutura na arquitetura. Em teste.
- **04/10/2026** — Review: tecla padrão Insert (F7 é o editor de veículos do vanilla em
  `-debug`), hora só pra frente, spawn em 3×3 com outfit e andar conferidos, toggle da
  vermelha no servidor, `NOM.time(math.huge)` com a linha de uso, fakes mais duros. Main
  mesclada. Verde.

## Aprendizados

- **F-key livre no Lua não quer dizer livre no jogo.** F7 em `-debug` abre o editor de
  veículos pelo Java (`IngameState.updateInternal`), invisível pra quem só lê o Lua vanilla.
  Tecla padrão de mod: varrer as classes que leem o teclado no bytecode.
- **`setTimeOfDay` pra trás quebra o relógio:** no dedicado a data dos clientes dessincroniza e
  o `getWorldAgeHours` volta. Hora nova menor que a atual vai como `h + 24`; o `GameTime.update`
  vira o dia sozinho.

- **O autocomplete do console do debug não é extensível por mod.** É Java, lista os métodos
  do `GlobalObject` por reflexão uma vez; tabela Lua global nunca aparece. Ajuda de mod no
  console = função `help` que imprime.
- **`ISCollapsableWindow:close()` só esconde.** Painel de mod que deve sumir de vez (não pegar
  clique) tem de sobrescrever com `removeFromUIManager`. E o `createChildren` do vanilla posiciona
  as alças de redimensionar pela altura do momento: acertar a altura antes de chamar o pai.
- **Chave de tradução montada por concatenação escapa do teste de traduções** (ele procura
  `"UI_NOM_..."` literal no código). Chave sempre literal.

## Pendências que a próxima sprint herda

- Tudo do roteiro acima.
- `addZombiesInOutfit` no servidor dedicado continua UNKNOWN (o mesmo risco do Eco,
  pz-api-notes "Testes in-game prioritários", item 2).
- O `test_translations` só olha `Sandbox.json` e `UI.json` atrás de `%` sozinho; arquivo novo
  de tradução tem de entrar lá.

## Sessões

- 2026-10-05 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — plano, NOM.*, servidor (hora, spawn, toggle), painel e tecla, docs
