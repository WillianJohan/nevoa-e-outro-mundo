# Sprint 0003 — Noite agressiva

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0003-noite-agressiva` |
| Plano | [plan.md](plan.md) |
| GDD | [night.md](../../gdd/night.md), [sandbox.md](../../gdd/sandbox.md), [ADR-005](../../architecture/adr-005-quem-simula-aplica.md) |

## Objetivo

À noite, todo zumbi fica mais rápido, percebe mais longe e caça o jogador.

Sem força nem dano a mais: decisão do autor de 2026-10-04 ([Overview](../../gdd/Overview.md#decisões-do-autor), [night.md](../../gdd/night.md#sem-força-e-sem-dano-à-noite)).

## Critérios de aceite

- [x] Velocidade sobe à noite pelo multiplicador do sandbox e volta ao normal ao amanhecer — `stats_night_boosts_speed_and_senses`, `stats_dawn_restores_day`, `stats_shambler_sandbox_still_promotes`, `stats_random_speed_keeps_own_tier`, `stats_inactive_phase_night_keeps_shamble`, `stats_inactive_phase_dawn_keeps_shamble`, `night_rules_wanted_night_default`. No jogo: Roteiro passos 2, 3 e 11. (Dano saiu do critério: decisão do autor, ver Objetivo.)
- [ ] Alcance de audição e visão maior à noite; lanterna ligada ao ar livre atrai zumbis de mais longe que de dia — lógica coberta (`stats_night_boosts_speed_and_senses`, `stats_remote_speed_not_fought`, `stats_phase_end_reapplies_night`, `torch_outside_at_night_attracts`, `torch_needs_outside_light_night_and_toggle`, `night_rules_sound_radius`); lanterna é aproximação por som (`addSound` com alcance efetivo `20 × NightSenseMult`, a cada 5 minutos), registrada no [GDD](../../gdd/night.md); falta o jogo: Roteiro passos 4 e 5
- [ ] Caça ativa: a cada `HuntIntervalMinutes`, zumbis no raio vão até o jogador sem vê-lo — lógica coberta (`hunt_every_interval_at_night`, `hunt_resets_by_day_and_toggle`, `hunt_effective_reach_is_hunt_radius`: o alcance efetivo, com o ×3 da audição apurada aplicado pelo fake como o `getSoundAttract`, é o `HuntRadius`); `addSound` no dedicado chega aos clientes por bytecode (`WorldSoundManager.addSound` → `GameServer.sendWorldSound`); falta o jogo: Roteiro passos 6 e 11
- [x] Cada um dos 3 comportamentos desliga sozinho pelo toggle — `stats_toggles_respected` (`NightFaster` e `NightSharperSenses`, um de cada vez e os dois), `hunt_resets_by_day_and_toggle`, `torch_needs_outside_light_night_and_toggle`, `night_rules_wanted_toggles_off_is_day`. No jogo: Roteiro passo 7
- [x] Salvar à noite e recarregar de dia não deixa zumbi com stat noturno preso — nada noturno é salvo: o `modData` do zumbi não vai pro save e o jogo re-sorteia os stats do sandbox ao recarregar (`createZombieOutsideWorld` → `DoZombieStats`, offset 421); a troca do sandbox volta na mesma chamada e `setValue` não salva nem sincroniza (bytecode `IntegerConfigOption.setValue`). Testes: `stats_reload_by_day_is_untouched`, `stats_sandbox_restored_after_apply`, `stats_sandbox_restored_when_stats_throw`, `stats_memory_not_rerolled`, `stats_day_writes_nothing`. No jogo: Roteiro passo 8
- [ ] Loop em lotes por tick: sem queda perceptível de FPS numa horda de ~200 zumbis (medido e registrado) — trabalho por tick limitado e medido no teste: `stats_batch_bounded_with_200` (no máximo `BATCH` = 20 aplicações e 40 leituras de velocidade por tick; a horda inteira converge em 10 ticks; zero reaplicação depois). FPS falta medir: Roteiro passo 10
- [x] `./run-tests.sh` cobre o cálculo dos multiplicadores — `tests/test_night_rules.lua` (12 testes: degraus, teto, base aleatória, perfis, contador, raio da lanterna, raio compensado pela audição); `total=133 passou=133 falhou=0`

## Roteiro in-game

Jogo em `-debug`, mod ativo, save novo com defaults (velocidade vanilla "Rápidos").
Log em `~/Zomboid/console.txt` (solo). No MP, `night=` sai no console do
**servidor** e `stats aplicados=` no console do **cliente** (é ele quem aplica).
Toda linha do mod começa com `[NOM] noite`.

1. Sandbox → página "Névoa e Outro Mundo": aparecem "Noite: zumbis mais rápidos" (`NightFaster`), "Noite: sentidos aguçados", "Noite: caça ativa", os dois multiplicadores (1.5), "Intervalo da caça" (60) e "Raio da caça" (30), com tooltip. **Esperado:** nenhum `ERROR`/`WARN` com `NOM_` no `console.txt`.
2. De dia, Spawn Horde com 20 zumbis a uns 15 tiles. Debug → Time: 22:00. **Esperado:** `[NOM] noite night=true` e, em menos de um segundo, `[NOM] noite stats aplicados=20 zumbis=20 noite=true` (o número pode incluir outros zumbis carregados); os zumbis passam a correr.
3. Debug → Time: 07:00. **Esperado:** `[NOM] noite night=false`, depois `[NOM] noite stats aplicados=N zumbis=M noite=false`; os zumbis voltam ao passo de dia.
4. Sentidos: de dia, parado a ~20 tiles de um grupo virado de costas, gritar (Q) e anotar se reagem; repetir à noite na mesma distância. **Esperado:** à noite reagem de mais longe (audição apurada = ×3 no alcance).
5. Lanterna: à noite, ao ar livre, ligar a lanterna. **Esperado:** em até 5 minutos de jogo `[NOM] noite lanterna jogadores=1 raio=30` (o raio do log é o alcance efetivo); zumbis a 20–30 tiles vêm, os de 35+ não. Desligar: `[NOM] noite lanterna jogadores=0 raio=30`. Entrar numa casa com ela ligada: a contagem cai pra 0.
6. Caça: sandbox `HuntIntervalMinutes` = 10. À noite, escondido e parado. **Esperado:** a cada 10 minutos de jogo `[NOM] noite caca jogadores=1 raio=30` e os zumbis a até ~30 tiles vêm até a posição; os de 40+ não (se vierem de ~90, a compensação da audição não valeu).
7. Desligar cada toggle (um save por vez). **Esperado:** velocidade off → zumbis à noite no passo do dia; sentidos off → sem linha de lanterna; caça off → sem linha de caça.
8. À noite, com zumbis correndo: salvar, sair, carregar. Debug → Time: 08:00. **Esperado:** zumbis no passo do dia; Debug → Sandbox options (ou o painel de admin) mostra `Speed`, `Sight`, `Hearing` iguais aos do início.
9. Eco: à noite, matar uns zumbis e esperar o Eco (sprint 0002). **Esperado:** o Eco anda arrastado enquanto os outros correm.
10. FPS: ligar o contador de FPS do debug, Spawn Horde com 200 zumbis, anotar o FPS de dia, pular pra 22:00 e anotar o FPS nos 5 segundos seguintes. **Esperado:** sem queda perceptível; registrar os números aqui.
11. **MP** (servidor dedicado local + 1 cliente): repetir 2, 3, 6. **Esperado:** `night=true` no console do servidor, `stats aplicados=` no do cliente, e os zumbis correm na tela do cliente. Se não correrem, a aplicação no cliente dono não está valendo: registrar (risco nº 1).
12. **MP**, cliente entrando no meio da noite: o servidor já está à noite; conectar. **Esperado:** `stats aplicados=` no cliente logo depois de entrar (resposta ao `nightState`).
13. **MP com 2 clientes:** um zumbi perseguindo o cliente B corre também na tela do A (o `walkType` do dono viaja).
14. **ActiveOnly:** save novo com "Ativos só de dia" (zumbis inativos à noite). À noite. **Esperado:** os zumbis continuam arrastados (o mod não acorda), sem linhas de `stats aplicados=` repetidas a cada passada.

## Checkpoints

- **04/10/2026** — Pesquisa no bytecode do B42.20.4 antes do plano: `DoZombieStats`, `doZombieSpeed(t)` com o sandbox vencendo o argumento, `setValue` sem sync nem save, força só sorteada antes do `OnZombieCreate`, dano global, visão presa em 10–20, `walkType` do dono no MP. Plano escrito.
- **04/10/2026** — Tasks 1–6 na branch: sandbox (7 opções, PTBR/EN), `NOM_NightRules`, `NOM_NightStats` (troca do sandbox com `pcall`, lotes de 20), `NOM_Players` extraído do `NOM_Eco`, `server/NOM_Night.lua` (flag, caça, lanterna), `client/NOM_NightClient.lua`, ADR-005. 127 testes passando. Falta o roteiro in-game e o MP.
- **04/10/2026** — Review: `ActiveOnly` vanilla não é mais sobrescrito (velocidade fica com o jogo na fase inativa), alcance da caça e da lanterna compensado pela audição (o jogo multiplica por ×3), farol a cada 5 minutos, `Memory` neutro na troca, `NightFasterStronger` virou `NightFaster`. Johan decidiu: sem força nem dano à noite. 133 testes.

## Aprendizados

1. **Em `doZombieSpeed(t)` o sandbox vence o argumento.** `doZombieSpeedInternal` testa `lore.speed == 3 ou t == 3` primeiro, e o `lore.speed == 2` antes do `t == 1`. Com sandbox "Arrastados", nenhum `t` promove; com "Rápidos", pedir corredor dá corredor só nos 2/3 que caem no `doFakeShambler(t)`. Tem que trocar `ZombieLore.Speed` junto do argumento.
2. **Força e dano não são do zumbi.** `strength` só é sorteado com o campo em -1, e o jogo chama `DoZombieStats` antes do `OnZombieCreate`: quando o Lua vê o zumbi, já era. E o campo só serve pra porta, janela, barricada e carro. O dano no jogador sai do `ZombieLore.Strength` global, lido no golpe (`AddRandomDamageFromZombie`), sem evento Lua com o zumbi.
3. **Visão do zumbi lê o sandbox global também, e é presa em 10–20 tiles.** `getVisionRadiusAdjusted` aplica ×1.75 se o campo **ou o sandbox** for águia, ×0.35 se o campo **ou o sandbox** for ruim. Com sandbox "Águia" todo zumbi é águia, não importa o campo. A audição (×3/×1/×0.45) é só do campo, e rende mais.
4. **Trocar o sandbox é seguro só dentro da mesma chamada.** `setValue` não sincroniza nem salva (só grava o campo; callback só existe pras opções do `Core`), mas o sandbox vai pro save quando o jogo salva. Volta garantida com `pcall` (o `pcall` do Kahlua pega `Throwable`).
5. **`DoZombieStats` tem efeitos colaterais além do que se pede:** re-sorteia `canCrawlUnderVehicle` e, com cognição aleatória (4), a cognição. O mod devolve o primeiro e põe `Cognition = 2` durante a troca (2 não mexe no campo).
6. **No MP, velocidade é do dono e sentidos são de cada cópia.** O remoto copia `walkType`/`speedMod` do pacote; o servidor aceita o `walkType` do dono. Aplicar no servidor não adianta: por isso a ADR-005.

7. **`DoZombieStats` também re-sorteia a memória** quando o sandbox é aleatório (5/6), mesmo com o campo já setado: só a força é "uma vez só". A troca põe `Memory = 2`.
8. **O `ActiveOnly` vanilla não reafirma.** `updateActiveState` chama `makeInactive(isZombieInactivityPhase())`, que volta cedo se nada mudou; `makeInactive(true)` põe arrastado uma vez. E `doZombieSpeed(t)` ignora o `inactive` com `t ≠ -1`: qualquer ajuste de velocidade acorda o zumbi inativo pra sempre.
9. **Todo som é multiplicado pela audição do zumbi.** `getSoundAttract` usa `raio × getHearingMultiplier(zumbi)` (×3 apurada). Aguçar a audição triplica o alcance de qualquer `addSound` do mod; o raio passado tem que ser dividido.
10. **Velocidade deixa rastro: o bote.** `doFastShambler`/`doSprinter` ligam `lunger`, que nada desliga e o Lua não lê. Arrastado promovido à noite segue dando bote depois do amanhecer, até ir pro virtual.
11. **Sentido aleatório (sandbox 4/5) re-sorteia a cada aplicação.** É o jogo sorteando no `DoZombieStats`: no anoitecer e no amanhecer o zumbi pode trocar de visão/audição dentro do sorteio vanilla.

## Pendências que a próxima sprint herda

- **Roteiro in-game e MP inteiros** (passos 1–14 acima), inclusive a medição de FPS.
- Velocidade e sentidos andam em degraus (o jogo só tem 3); multiplicador contínuo não existe.
- Lanterna é aproximação por som a cada 5 minutos, não alcance de visão.
- Servidor dedicado não aplica stats nos zumbis que ele mesmo simula (sem dono, longe de jogadores).
- Sandbox com velocidade "Aleatória": zumbi remoto que vira local à noite pode tomar como base o degrau já promovido pelo antigo dono (degrau a mais, limitado a corredor).
- `ActiveOnly`: na fase inativa a velocidade fica com o jogo (arrastado); conferir no jogo (Roteiro passo 14).
- Alcance compensado da caça e da lanterna não considera roupa nem clima, que o jogo também multiplica.
- Bote (`lunger`) fica ligado no zumbi promovido depois do amanhecer, até ir pro virtual (não há como desligar).
- No cliente de MP o Eco é reconhecido pelo outfit: zumbi vanilla que sorteou `NOM_Eco` no fallback de zona (raro, ADR-003) fica lento só no cliente.

## Sessões

- 2026-10-04 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — pesquisa no bytecode, plano e implementação da sprint (tasks 1–6)
