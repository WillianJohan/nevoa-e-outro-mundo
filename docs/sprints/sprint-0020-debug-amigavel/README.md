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
`NOM.spawn(5)`, `NOM.help()`) ou pelo painel de botões aberto com F7, sem decorar os
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
- [x] `NOM.fog()` durante a sirene cancela (o servidor decide o toggle, ele sabe da contagem)
      — `debug_fog_toggle_cancels_siren`, `debug_rules_parse_fog_toggle`.
- [x] `NOM.time` muda o relógio pelo servidor, com a mesma porta (`-debug`, permissão no
      dedicado); 25 vira 1, -1 vira 23 — `debug_time_sets_clock`, `debug_rules_parse_time`,
      `nom_time_wraps_hour`.
- [x] `NOM.spawn` põe os zumbis 3 tiles na frente do jogador pelo `addZombiesInOutfit` do
      servidor; 1 a 50; o servidor recusa tile a mais de 10 tiles de quem pede e quem não tem
      permissão — `debug_server_spawn_in_front`, `debug_server_spawn_rejects_far`,
      `debug_rules_spawn_clamps`, `debug_rules_parse_spawn`.
- [x] `NOM.help()` lista todo comando com uma linha em PT-BR, e só o que existe —
      `nom_help_lists_every_command`.
- [x] `NOM_Debug.*` intactos — os 19 testes antigos do `test_debug.lua` sem mudança de
      expectativa (só o fake da sirene passou a modelar a contagem).
- [x] Painel (`ISCollapsableWindow`) com névoa (inverte, já, fim), vermelha, noite / dia /
      relógio, horas 0/6/12/18/22, spawn 1/5/10, Eco, as quatro variantes no mais perto, deus,
      noclip, invisível (com "sim/não") e linha de estado a cada segundo — 
      `debug_panel_buttons_call_nom` (todo botão testado), `debug_panel_toggle_titles_show_state`,
      `debug_panel_status_refreshes_each_second`.
- [x] Abre pela tecla das opções do mod (`PZAPI.ModOptions:addKeyBind`, padrão F7, só com
      `-debug`) e por `NOM.panel()`; fechado sai do UIManager; posição pelo `ISLayoutManager`
      — `screenfx_options_debug_key_only_in_debug`, `screenfx_options_debug_key_follows_rebind`,
      `debug_panel_key_toggles`, `debug_panel_close_removes_from_ui`,
      `debug_panel_remembers_position`, `debug_panel_absent_without_debug`,
      `debug_panel_needs_player`.
- [x] Textos do painel e da tecla em PT-BR e EN, sem `%` sozinho (o teste agora olha o
      `UI.json` também) — `translations_lua_keys_defined`, `translations_no_lone_percent`.
- [ ] O painel abre com F7 no jogo, os botões fazem o que dizem e fechado não atrapalha
      clique nem tecla — **falta o jogo:** roteiro, passos 1–5.
- [ ] A tecla aparece em Opções > Mods só com `-debug` e a troca vale sem reiniciar —
      **falta o jogo:** passo 6.
- [ ] MP (dedicado): spawn, hora e truques como admin — **falta o jogo:** passo 7.

`./run-tests.sh`: `total=676 passou=676 falhou=0` (Lua), `contraste total=4 passou=4`,
`build total=25 passou=25`.

## Roteiro in-game

Jogo em `-debug`, **save descartável** (noite e névoa forçadas avançam os contadores salvos,
[teste-in-game.md](../../teste-in-game.md)). Console em
`~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt` (Flatpak).

1. **Console.** No save, console Lua: `NOM.help()`. **Esperado:** 13 linhas
   `[NOM] NOM.fog(on, skip) - névoa: …` até `[NOM] NOM.help() - esta lista`. `NOM.status()`
   imprime `[NOM] debug local …` e `[NOM] debug servidor …`.
2. **Abrir.** Apertar **F7**. **Esperado:** janela "Névoa e Outro Mundo: debug" com 6 linhas
   de botões e a linha "Noite: … Névoa: … Vermelha: … Hora: HH:MM Monstros aqui: N" mudando
   a hora sozinha. F7 de novo fecha. Nenhuma ação do jogo dispara junto com o F7 (se disparar:
   trocar a tecla nas opções e anotar). Sem `-debug`, F7 não faz nada e `NOM` é `nil`.
3. **Névoa.** "Névoa (liga/desliga)": `[NOM] debug nevoa sirene=true` e a sirene. Clicar de
   novo **antes dos 30 s**: `[NOM] debug nevoa fim=true`, sem névoa depois. "Névoa já":
   névoa no próximo tick. "Vermelha (liga/desliga)": `[NOM] debug nevoa vermelha=true`, fica
   vermelha. "Fim da névoa": `[NOM] debug nevoa fim=true`.
4. **Hora e noite.** "22h": `[NOM] debug hora=22.00`, o céu escurece e a linha diz `Hora: 22:00`;
   em até um minuto de jogo `Noite: sim`. "06h" volta. "Noite"/"Dia"/"Relógio":
   `[NOM] debug noite forcada=true/false/nil`.
5. **Spawn, variantes, truques.** "5 zumbis": `[NOM] debug spawn n=5 criados=5 outfit=-` e 5
   zumbis ~3 tiles na frente de onde o personagem olha. Com a névoa aberta, "Vira Corredor":
   `[NOM] debug variante id=… forcada=corredor` e o mais perto vira Corredor. "Deus": título
   vira "Deus: sim", `[NOM] debug god=true`, zumbi não machuca. "Noclip": atravessa parede.
   "Invisível": zumbis não te veem. "Eco aqui" à noite: `[NOM] debug eco spawn=true`.
   Fechar o painel e clicar no mundo onde ele estava: o clique vai pro jogo.
   Reabrir: a janela volta no mesmo lugar (também depois de sair e carregar o save).
6. **Tecla.** Opções > Mods > Névoa e Outro Mundo: "Painel de debug do mod (só com -debug)"
   com F7. Trocar pra F9, aplicar: F9 abre, F7 não. Sem `-debug` a linha não aparece.
7. **MP** (dedicado com `-debug`, cliente admin com `-debug`): `NOM.spawn(3)` → linha
   `[NOM] debug spawn n=3 criados=3` no console do **servidor** e os 3 zumbis aparecem no
   cliente; `NOM.time(22)` → o céu do cliente muda em segundos; `NOM.god()` vale no
   cliente. Cliente sem permissão: `[NOM] debug negado` no servidor e nada acontece.

## Rulings do Claude

1. **Toggle da névoa decidido pelo servidor.** `NOM.fog()` manda `toggle` e o servidor olha
   névoa aberta **ou sirene contando**; o cliente não sabe da contagem e inverteria pelo
   `NOM_FogState.on` (tocaria outra sirene em vez de cancelar). Vermelha e noite invertem
   pelo estado local (`NOM_FogState.red`, `NOM_NightStats.night`), que o cliente tem.
   Custo se errado: nenhum conhecido; um campo a mais no `parse`.
2. **`NOM.night()` sem argumento inverte, não devolve pro relógio.** O brief manda inverter;
   o relógio fica no `NOM_Debug.night()` (e no botão "Relógio"), citado no `help`. Custo se
   errado: quem quer o relógio digita o comando antigo.
3. **Spawn mirado no cliente, conferido no servidor.** O cliente sabe pra onde o próprio
   personagem olha; o servidor recebe x/y/z e recusa a mais de 10 tiles do jogador (e NaN,
   e infinito). Outfit vai como texto até 64 letras; outfit com nome errado fica por conta
   do `addZombiesInOutfit` (não conferido: escrever certo, ex.: `"Police"`). Todos nascem no mesmo tile. Custo se errado:
   pilha de zumbis num tile só; espalhar é um laço como o do `ISSpawnHordeUI`.
4. **God, noclip e invisível são locais**, como o painel de admin do vanilla
   (`setX` + `sendPlayerExtraInfo`); não passam pelo servidor do mod. No MP quem barra é o
   jogo. Custo se errado: num dedicado o truque pode valer só na tela de quem pediu (passo 7).
5. **Tecla na página de opções do mod que já existe** (`NOM_ScreenFxOptions`), criada só
   com `-debug`; padrão F7 (nenhum Lua vanilla usa). Sem a API, F7 fixo. Custo se errado:
   F7 colide com algo do Java em `-debug`; o jogador troca na hora em Opções > Mods.
6. **Fechar tira do UIManager** (o `close` do vanilla só esconde). Reabrir põe de novo
   (`AddUI` não duplica). Custo se errado: nenhum conhecido.
7. **Hora com `NOM_Math.mod`** (25 → 1, -1 → 23) e "HH:MM" sem `%d` (concatenação de
   `math.floor`). Botões de hora em vez de slider: menos peça, mesmo uso.
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

## Aprendizados

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
- F7 em `-debug`: conferir que o Java não usa (passo 2); se usar, trocar o padrão.
- `addZombiesInOutfit` no servidor dedicado continua UNKNOWN (o mesmo risco do Eco,
  pz-api-notes "Testes in-game prioritários", item 2).
- O `test_translations` só olha `Sandbox.json` e `UI.json` atrás de `%` sozinho; arquivo novo
  de tradução tem de entrar lá.

## Sessões

- 2026-10-05 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — plano, NOM.*, servidor (hora, spawn, toggle), painel e tecla, docs
