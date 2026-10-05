# Sprint 0011 — Carpideira (o monstro do grito)

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0011-carpideira` |
| Plano | [plan.md](plan.md) |
| GDD | [monsters.md](../../gdd/monsters.md#carpideira), [sandbox.md](../../gdd/sandbox.md), [Overview.md](../../gdd/Overview.md#decisões-do-autor) |
| ADR | [ADR-011](../../architecture/adr-011-carpideira.md) (nova); emenda ADR-006 e ADR-010 |

## Objetivo

Na névoa, parte dos zumbis vira Carpideira: parada, soluçando baixinho. Chegou perto,
apontou a lanterna ou atirou por perto, ela solta um grito que chama a horda de longe e
corre atrás de quem a acordou.

Pedido do Johan (05/10/2026): um monstro que "grita muito alto, tipo a Witch do L4D ou
quando vem horda no Back 4 Blood". Inspirado, não copiado. Decisões:

1. Variante da névoa (todo monstro, menos o Eco, só na névoa), no mesmo sorteio, com faixa
   própria no fim; na névoa vermelha, 1/4 de cada tipo.
2. Calma, parada no lugar (sem perambular nem perseguir), soluçando (som procedural, perto).
3. Acorda com: jogador a `CarpideiraTriggerRadius` (4); lanterna acesa apontada pra ela a
   até ~10 tiles; barulho alto perto (tiro).
4. Grito ensurdecedor, ouvido de longe, com chamado da horda a `CarpideiraScreamRadius`
   (60, audição compensada); depois, corredora caçando quem a acordou. Um grito por névoa
   por Carpideira, decidido e validado pelo servidor.
5. Sandbox: `CarpideiraEnabled` (true), `CarpideiraChance` (3, decisão do Johan),
   `CarpideiraTriggerRadius` (4), `CarpideiraScreamRadius` (60).

## Critérios de aceite

- [x] Carpideira no sorteio da névoa, faixa própria sem sobreposição, 15% somados com o
      padrão (5 + 2 + 5 + 3) — `variant_rules_default_total_15` (20 000 IDs no formato do
      jogo, 3 períodos: total 15 ± 1,5; quem era Estalador, Corredor ou Sem-rosto continua
      sendo; `KINDS[4] == "carpideira"`), `variant_rules_default_chances` (3% ± 1,5),
      `variant_rules_config_reads_sandbox`.
- [x] Na névoa vermelha, 1/4 de cada tipo — `variant_rules_red_fog_splits_evenly` (cada
      tipo a menos de 2 pontos de 1/4), `stats_red_fog_every_zombie_is_variant` (90 zumbis,
      nenhum comum, 10–35 de cada).
- [ ] Calma, fica parada — **por código:** `ai_carpideira_still_while_calm` (jogador em pé
      à vista a 6 tiles e um som a 20: ela não sai do lugar; controle: o Corredor vem e
      morde, no fake que modela o spot, o spot forçado e o `RespondToSound` do jogo),
      `ai_carpideira_remote_untouched` (a cópia remota nasce useless, como no jogo; o novo dono a assume),
      `ai_carpideira_inherited_after_fog_is_released`, `ai_carpideira_inherited_after_scream_is_released`,
      `stats_pass_offers_every_zombie_to_unstick` (useless herdado pela rede é solto: fim da
      névoa, depois do grito, reaproveitamento; o do jogo, o remoto e o deste processo ficam),
      `ai_carpideira_released_when_fog_ends`; alavanca `setUseless` por bytecode
      (pz-api-notes §3.2, §13.2). **Falta o jogo:** roteiro passo 2.
- [ ] Soluço audível perto, local, em quem a tem carregada — **por código:**
      `carpideira_sobs_locally_while_calm` (`playSoundLocal` no zumbi, um loop só, volta se
      cortado), `carpideira_sob_only_near_a_local_player` (só a até 15 tiles de um jogador
      local), `carpideira_sob_stops_on_scream_fog_end_and_unload` (inclusive quem foi pro
      virtual: `removeFromWorld` não para o emitter, §13.3), `config_fog_sounds_loop`
      (`loop = true`, `distanceMax` 12, volume 0.5). **Falta o jogo:** passo 2.
- [ ] Acorda por proximidade, lanterna e barulho — **por código:**
      `carpideira_reports_proximity` (até 4, mesmo de costas; outro andar não),
      `carpideira_reports_light_only_when_lit_and_seen` (acesa e vista a 8: sim; apagada,
      de costas ou a 12: não), `carpideira_noise_wakes` (tiro a 5 tiles sim; tiro a 15,
      tarefa de raio 20, fonte zumbi, chamado do mod de raio 30 de dia e andar de baixo: não),
      `carpideira_rules_*`; `OnWorldSound` por bytecode (§13.1). **Falta o jogo:**
      passos 3–5.
- [ ] Um grito, que chama a horda — **por código:** `carpideira_sp_scream_once_per_period`
      (grito local, `addSound` com alcance efetivo 60 à noite, segundo aviso nada, névoa
      seguinte pode), `carpideira_scream_survives_reload` (`ModData`), `carpideira_report_gap`,
      `carpideira_furious_is_silent`, `carpideira_furia_is_per_fog`, `carpideira_sp_reload_keeps_furious`
      (solo: lista refeita do `ModData` ao carregar e na borda da névoa),
      `carpideira_one_report_per_scan`. **Falta o jogo:** passos 3 e 6.
- [ ] Depois do grito, corredora atrás de quem a acordou — **por código:**
      `ai_carpideira_scream_hunts_trigger_player` (solta, `spotted(p, true)`, morde),
      `ai_carpideira_reloaded_after_scream_stays_furious`, `night_rules_wanted_carpideira_sprints`;
      spot forçado por bytecode (`spottedNew` 1114–1120, 1909–1950). **Falta o jogo:**
      passo 3.
- [x] Servidor decide e valida no MP (proximidade, lanterna, limite) — `carpideira_mp_validates_report`
      (variante, névoa, andar, distância com folga de 2, lanterna acesa no servidor, Eco,
      morto, motivo desconhecido), `carpideira_rate_limit_per_player` (1 por segundo por
      jogador, contando inválidos), `carpideira_joiner_gets_list`,
      `variants_client_reports_carpideira`, `variants_client_scream_applies_to_the_zombie`,
      `variants_client_takes_carpideira_list`. MP no jogo: passo 7.
- [x] Sandbox com PT-BR e EN, sem `%` sozinho — `config_carpideira_defaults`,
      `config_sandbox_defaults_match_lua`, `config_every_option_has_default`, `translations_*`.
- [x] `NOM_Debug.variant("carpideira")` funciona e o status conta — `debug_rules_parse_rejects_garbage`
      (aceita `"carpideira"`, recusa tipo desconhecido), `debug_status_prints_local_and_server` (`carpideiras=1`).
- [x] Compatível com o Kahlua — `test_kahlua_compat` varre os arquivos novos (sem `next`,
      `//`, `goto`, `table.unpack`).
- [x] Orçamento da vermelha com a Carpideira contado — `ai_red_fog_budget_per_frame` (4
      tipos; Carpideira 2 chamadas por frame), `carpideira_scan_budget` (zero no zumbi
      comum, ≤ 10 por Carpideira calma), `carpideira_noise_scan_one_call_per_common_zombie`;
      tabela no [architecture/README.md](../../architecture/README.md#orçamento-por-sistema).
      FPS com horda: [teste in-game, parte 3](../../teste-in-game.md#parte-3--medições-15-min).
- [x] Sons originais procedurais — `scripts/gen_sounds.py` (`sob`, `wail`; os sons antigos
      saem byte a byte iguais), `CREDITS.md`, `credits_*`, `config_sound_scripts_point_to_files`.

`./run-tests.sh`: `total=426 passou=426 falhou=0` (Lua) e `build total=22 passou=22 falhou=0`.

## Roteiro in-game

Jogo em `-debug`, **save descartável** (o evento avança o contador de névoas salvo).
Console em `~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt` (Flatpak). O Lua novo
só carrega ao recarregar o save. Pra achar Carpideiras rápido: sandbox `CarpideiraChance`
= 100 e as outras chances 0, ou `NOM_Debug.variant("carpideira")` no zumbi mais perto.

1. **Menu.** Sandbox → "Névoa e Outro Mundo": "Carpideiras", "Chance de Carpideira (%)"
   (3), "Distância que acorda a Carpideira (tiles)" (4), "Raio do grito da Carpideira
   (tiles)" (60), com tooltip; em inglês "Mourners". **Esperado:** nenhum `ERROR` com
   `NOM_` no console.
2. **Calma.** De dia, Spawn Horde com 5 zumbis a ~15 tiles, `NOM_Debug.fog(true, true)`.
   Ficar a ~8 tiles, em pé, sem lanterna. **Esperado:** `NOM_Debug.status()` com
   `carpideiras=5`; elas não andam nem vêm (podem dar uns passos até onde viram o jogador
   antes da névoa); chegando a ~10 tiles ouve-se um choro baixo, que some a ~12.
   **Se** andarem atrás do jogador: o useless não segurou (registrar).
3. **Proximidade.** Agachado, chegar a 3 tiles de uma. **Esperado:**
   `[NOM] carpideira acordada por=near` e `[NOM] variantes carpideira grito por=near x=… y=… raio=60`;
   um grito agudo e longo, audível de longe; o choro dela para; ela corre direto pro
   jogador; zumbis comuns a 40–60 tiles vêm até ela. Afastar e voltar: **nenhum** grito
   novo dela.
4. **Lanterna.** De noite (`NOM_Debug.night(true)`) e na névoa, outra Carpideira a ~8
   tiles, lanterna acesa apontada pra ela. **Esperado:** `por=light` e o grito. Com a
   lanterna apagada, ou apontada pro outro lado, a 8 tiles: nada.
5. **Barulho.** Outra Carpideira a ~7 tiles, atrás de uma parede (sem vê-la): um tiro.
   **Esperado:** `[NOM] variantes carpideira grito por=noise`. Um tiro a ~15 tiles dela:
   nada. Quebrar uma janela ou cortar mato perto dela: nada.
6. **Recarregar.** Depois de um grito, salvar, sair e carregar ainda na névoa. **Esperado:**
   a que gritou não chora nem grita de novo (corre ou anda como corredora); as calmas
   continuam chorando. `NOM_Debug.fog(false)`: todas andam como zumbi comum e o choro para.
7. **MP** (dedicado + 2 clientes). Repetir 2–5 com o cliente A. **Esperado:** o grito sai
   no console do **servidor** (`por=near|light|noise`) e toca nos dois clientes; o choro
   toca no cliente B se ele estiver perto dela. Cliente B entra depois de um grito: a que
   gritou não chora pra ele. Tiro do cliente B perto de uma calma: ela acorda e caça o B.
8. **Vermelha.** `NOM_Debug.redFog(true)` com ~20 zumbis perto: `NOM_Debug.status()` com
   `carpideiras` ≈ 1/4 dos carregados. Medir o FPS (parte 3 do teste in-game).

## Checkpoints

- **04/10/2026** — Sprint aberta a partir do pedido do Johan (05/10). Pesquisa no bytecode:
  `OnWorldSound` sai de todo `addSound`, inclusive o som de cliente refeito no servidor;
  `spotted(p, true)` é o spot forçado do jogo; `removeFromWorld` não para os sons do
  emitter. Plano escrito.
- **04/10/2026** — Sorteio, regras e sandbox; perfil corredor; parada, soluço e aviso no
  cliente; grito decidido pelo servidor (aviso, barulho, `ModData`); cliente de MP; sons
  procedurais; debug.
- **04/10/2026** — Docs: GDD, ADR-011, pz-api-notes §13, orçamento, roteiro. Em teste.
- **04/10/2026** — Review: useless herdado pela rede ficava preso (fim da névoa, troca de
  posse, reaproveitamento, furiosa herdada): `unstick` na passada do `NightStats` e no
  `OnZombieCreate`, e a furiosa se solta. Solo: lista de quem gritou refeita do `ModData`
  ao recarregar. Teste da marca `NOM_Night.calling` de dia (raio 30). Soluço só a até 15
  tiles de um jogador; um aviso por varredura; fúria pelo período.

## Aprendizados

1. **Todo `addSound` dispara `OnWorldSound`, inclusive os do próprio mod.** A caça e a
   lanterna da noite chamam `addSound` com o jogador de fonte: pro evento, é barulho do
   jogador. Quem ouve o evento precisa saber separar (aqui, `NOM_Night.calling` durante a
   chamada). O evento é síncrono: a flag em volta da chamada basta.
2. **`removeFromWorld` não cala o zumbi.** Ele só para um som pelo nome; um loop tocado
   pelo mod no emitter continua quando o zumbi vai pro virtual. Loop em zumbi precisa de
   alguém que confira a lista e pare o de quem sumiu.
3. **Useless é estado de rede, não do processo.** Ele viaja no pacote do zumbi e o
   `resetForReuse` não limpa: quem liga useless precisa de um caminho que solte o
   herdado em todo dono futuro, independente de variante (passada periódica + criação).
   Fake que cria a cópia remota com useless falso esconde o bug: a cópia nasce com o
   useless do dono.
4. **Variante nova num sandbox de teste com 100%: todo ID é dela.** Teste que procura um
   "zumbi comum" com `idFor(nil, ...)` num sandbox diferente do do servidor falso acha um
   ID que, pro servidor, é variante. Use o mesmo sandbox (ou um de 50%) pra achar o comum.

## Pendências que a próxima sprint herda

- Roteiro in-game acima (passos 1–8) e os critérios abertos.
- **Visual:** nenhum. Vestir outro outfit troca o `persistentOutfitID` e, com ele, a
  variante (ADR-006); o aviso é o soluço. Precisa de outra alavanca visual (a mesma
  pendência das outras variantes).
- No dedicado, a cópia que o servidor simula sozinha (sem dono) fica no último useless
  que recebeu: parada se o dono saiu com ela calma, até alguém virar dono (e a passada do
  `NightStats` soltar, se a névoa já acabou); andando se nunca teve dono.
- Zumbi herdado useless de dia espera a passada de conferência (borda da névoa ou de hora
  em hora) pra ser solto: até uma hora de jogo parado. O `letGo`/`unstick` derrubam também
  o useless do tutorial e do menu de debug.
- Ao virar Carpideira com uma caminhada em andamento, ela segue até a última posição vista
  antes de parar (`WalkTowardState`).
- Lanterna aproximada: com a lanterna acesa na mão, ela vista por outra luz também acorda.
  A direção do jogador no servidor (UNKNOWN, §13.4) daria uma conferência melhor.
- Barulho só de jogador: alarme de carro ou de casa não acorda (não há quem caçar).
- Zumbis com o mesmo `persistentOutfitID` gritam como uma: as outras ficam furiosas sem
  gritar.
- Calibrar no jogo: `ALERT_RANGE` (10), `LOUD_RADIUS` (30), volume e alcance do soluço
  (`distanceMax` 12, volume 0.5) e do grito (`distanceMax` 150).
- A tabela do limite de avisos por jogador só esvazia quando o servidor reinicia (como a
  do Corredor).

## Sessões

- 2026-10-05 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — pesquisa no bytecode, plano e implementação
