# Sprint 0003 — Noite agressiva

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0003-noite-agressiva` |
| Plano | [plan.md](plan.md) |
| GDD | [night.md](../../gdd/night.md), [sandbox.md](../../gdd/sandbox.md), [ADR-005](../../architecture/adr-005-quem-simula-aplica.md) |

## Objetivo

À noite, todo zumbi fica mais rápido, mais forte, percebe mais longe e caça o jogador.

## Critérios de aceite

- [ ] Velocidade e dano sobem à noite pelos multiplicadores do sandbox e voltam ao normal ao amanhecer — **velocidade**: lógica coberta (`stats_night_boosts_speed_and_senses`, `stats_dawn_restores_day`, `stats_shambler_sandbox_still_promotes`, `stats_random_speed_keeps_own_tier`, `night_rules_wanted_night_default`); falta o jogo: Roteiro passos 2, 3 e 11. **Dano: não existe por zumbi no jogo** (bytecode `AddRandomDamageFromZombie` lê o `ZombieLore.Strength` global; `strength` do zumbi só é sorteado antes do `OnZombieCreate`), fica em Pendências; sem opção `NightDamageMult`
- [ ] Alcance de audição e visão maior à noite; lanterna ligada ao ar livre atrai zumbis de mais longe que de dia — lógica coberta (`stats_night_boosts_speed_and_senses`, `stats_remote_speed_not_fought`, `torch_outside_at_night_attracts`, `torch_needs_outside_light_night_and_toggle`); lanterna é aproximação por som (`addSound` de `20 × NightSenseMult`), registrada no [GDD](../../gdd/night.md); falta o jogo: Roteiro passos 4 e 5
- [ ] Caça ativa: a cada `HuntIntervalMinutes`, zumbis no raio vão até o jogador sem vê-lo — lógica coberta (`hunt_every_interval_at_night`, `hunt_resets_by_day_and_toggle`); `addSound` no dedicado chega aos clientes por bytecode (`WorldSoundManager.addSound` → `GameServer.sendWorldSound`); falta o jogo: Roteiro passos 6 e 11
- [x] Cada um dos 3 comportamentos desliga sozinho pelo toggle — `stats_toggles_respected` (velocidade e sentidos, um de cada vez e os dois), `hunt_resets_by_day_and_toggle`, `torch_needs_outside_light_night_and_toggle`, `night_rules_wanted_toggles_off_is_day`. No jogo: Roteiro passo 7
- [x] Salvar à noite e recarregar de dia não deixa zumbi com stat noturno preso — nada noturno é salvo: o `modData` do zumbi não vai pro save e o jogo re-sorteia os stats do sandbox ao recarregar (`createZombieOutsideWorld` → `DoZombieStats`, offset 421); a troca do sandbox volta na mesma chamada e `setValue` não salva nem sincroniza (bytecode `IntegerConfigOption.setValue`). Testes: `stats_reload_by_day_is_untouched`, `stats_sandbox_restored_after_apply`, `stats_sandbox_restored_when_stats_throw`, `stats_day_writes_nothing`. No jogo: Roteiro passo 8
- [ ] Loop em lotes por tick: sem queda perceptível de FPS numa horda de ~200 zumbis (medido e registrado) — trabalho por tick limitado e medido no teste: `stats_batch_bounded_with_200` (no máximo `BATCH` = 20 aplicações e 40 leituras de velocidade por tick; a horda inteira converge em 10 ticks; zero reaplicação depois). FPS falta medir: Roteiro passo 10
- [x] `./run-tests.sh` cobre o cálculo dos multiplicadores — `tests/test_night_rules.lua` (11 testes: degraus, teto, base aleatória, perfis, caça, raio da lanterna); `total=127 passou=127 falhou=0`

## Roteiro in-game

Jogo em `-debug`, mod ativo, save novo com defaults (velocidade vanilla "Rápidos").
Log em `~/Zomboid/console.txt` (solo). No MP, `night=` sai no console do
**servidor** e `stats aplicados=` no console do **cliente** (é ele quem aplica).
Toda linha do mod começa com `[NOM] noite`.

1. Sandbox → página "Névoa e Outro Mundo": aparecem "Noite: zumbis mais rápidos", "Noite: sentidos aguçados", "Noite: caça ativa", os dois multiplicadores (1.5), "Intervalo da caça" (60) e "Raio da caça" (30), com tooltip. **Esperado:** nenhum `ERROR`/`WARN` com `NOM_` no `console.txt`.
2. De dia, Spawn Horde com 20 zumbis a uns 15 tiles. Debug → Time: 22:00. **Esperado:** `[NOM] noite night=true` e, em menos de um segundo, `[NOM] noite stats aplicados=20 zumbis=20 noite=true` (o número pode incluir outros zumbis carregados); os zumbis passam a correr.
3. Debug → Time: 07:00. **Esperado:** `[NOM] noite night=false`, depois `[NOM] noite stats aplicados=N zumbis=M noite=false`; os zumbis voltam ao passo de dia.
4. Sentidos: de dia, parado a ~20 tiles de um grupo virado de costas, gritar (Q) e anotar se reagem; repetir à noite na mesma distância. **Esperado:** à noite reagem de mais longe (audição apurada = ×3 no alcance).
5. Lanterna: à noite, ao ar livre, ligar a lanterna. **Esperado:** `[NOM] noite lanterna jogadores=1 raio=30`; zumbis a 20–30 tiles vêm. Desligar: `[NOM] noite lanterna jogadores=0 raio=30`. Entrar numa casa com ela ligada: a contagem cai pra 0.
6. Caça: sandbox `HuntIntervalMinutes` = 10. À noite, escondido e parado. **Esperado:** a cada 10 minutos de jogo `[NOM] noite caca jogadores=1 raio=30` e os zumbis do raio vêm até a posição.
7. Desligar cada toggle (um save por vez). **Esperado:** velocidade off → zumbis à noite no passo do dia; sentidos off → sem linha de lanterna; caça off → sem linha de caça.
8. À noite, com zumbis correndo: salvar, sair, carregar. Debug → Time: 08:00. **Esperado:** zumbis no passo do dia; Debug → Sandbox options (ou o painel de admin) mostra `Speed`, `Sight`, `Hearing` iguais aos do início.
9. Eco: à noite, matar uns zumbis e esperar o Eco (sprint 0002). **Esperado:** o Eco anda arrastado enquanto os outros correm.
10. FPS: ligar o contador de FPS do debug, Spawn Horde com 200 zumbis, anotar o FPS de dia, pular pra 22:00 e anotar o FPS nos 5 segundos seguintes. **Esperado:** sem queda perceptível; registrar os números aqui.
11. **MP** (servidor dedicado local + 1 cliente): repetir 2, 3, 6. **Esperado:** `night=true` no console do servidor, `stats aplicados=` no do cliente, e os zumbis correm na tela do cliente. Se não correrem, a aplicação no cliente dono não está valendo: registrar (risco nº 1).
12. **MP**, cliente entrando no meio da noite: o servidor já está à noite; conectar. **Esperado:** `stats aplicados=` no cliente logo depois de entrar (resposta ao `nightState`).
13. **MP com 2 clientes:** um zumbi perseguindo o cliente B corre também na tela do A (o `walkType` do dono viaja).

## Checkpoints

- **04/10/2026** — Pesquisa no bytecode do B42.20.4 antes do plano: `DoZombieStats`, `doZombieSpeed(t)` com o sandbox vencendo o argumento, `setValue` sem sync nem save, força só sorteada antes do `OnZombieCreate`, dano global, visão presa em 10–20, `walkType` do dono no MP. Plano escrito.
- **04/10/2026** — Tasks 1–6 na branch: sandbox (7 opções, PTBR/EN), `NOM_NightRules`, `NOM_NightStats` (troca do sandbox com `pcall`, lotes de 20), `NOM_Players` extraído do `NOM_Eco`, `server/NOM_Night.lua` (flag, caça, lanterna), `client/NOM_NightClient.lua`, ADR-005. 127 testes passando. Falta o roteiro in-game e o MP.

## Aprendizados

1. **Em `doZombieSpeed(t)` o sandbox vence o argumento.** `doZombieSpeedInternal` testa `lore.speed == 3 ou t == 3` primeiro, e o `lore.speed == 2` antes do `t == 1`. Com sandbox "Arrastados", nenhum `t` promove; com "Rápidos", pedir corredor dá corredor só nos 2/3 que caem no `doFakeShambler(t)`. Tem que trocar `ZombieLore.Speed` junto do argumento.
2. **Força e dano não são do zumbi.** `strength` só é sorteado com o campo em -1, e o jogo chama `DoZombieStats` antes do `OnZombieCreate`: quando o Lua vê o zumbi, já era. E o campo só serve pra porta, janela, barricada e carro. O dano no jogador sai do `ZombieLore.Strength` global, lido no golpe (`AddRandomDamageFromZombie`), sem evento Lua com o zumbi.
3. **Visão do zumbi lê o sandbox global também, e é presa em 10–20 tiles.** `getVisionRadiusAdjusted` aplica ×1.75 se o campo **ou o sandbox** for águia, ×0.35 se o campo **ou o sandbox** for ruim. Com sandbox "Águia" todo zumbi é águia, não importa o campo. A audição (×3/×1/×0.45) é só do campo, e rende mais.
4. **Trocar o sandbox é seguro só dentro da mesma chamada.** `setValue` não sincroniza nem salva (só grava o campo; callback só existe pras opções do `Core`), mas o sandbox vai pro save quando o jogo salva. Volta garantida com `pcall` (o `pcall` do Kahlua pega `Throwable`).
5. **`DoZombieStats` tem efeitos colaterais além do que se pede:** re-sorteia `canCrawlUnderVehicle` e, com cognição aleatória (4), a cognição. O mod devolve o primeiro e põe `Cognition = 2` durante a troca (2 não mexe no campo).
6. **No MP, velocidade é do dono e sentidos são de cada cópia.** O remoto copia `walkType`/`speedMod` do pacote; o servidor aceita o `walkType` do dono. Aplicar no servidor não adianta: por isso a ADR-005.

## Pendências que a próxima sprint herda

- **Roteiro in-game e MP inteiros** (passos 1–13 acima), inclusive a medição de FPS.
- **Dano e força noturnos** (e "dano baixo" do Eco): não há caminho por zumbi. Ideias, todas com custo: (a) do lado da vítima, detectar o golpe (`getAttackedBy()` é setado logo antes do dano) e somar `BodyDamage:AddDamage` — esbarra em quem calcula o dano no MP; (b) trocar `ZombieLore.Strength` global durante a noite só na máquina que simula — vaza pros Ecos e pro save.
- Velocidade e sentidos andam em degraus (o jogo só tem 3); multiplicador contínuo não existe.
- Lanterna é aproximação por som a cada minuto, não alcance de visão.
- Servidor dedicado não aplica stats nos zumbis que ele mesmo simula (sem dono, longe de jogadores).
- Sandbox com velocidade "Aleatória": zumbi remoto que vira local à noite pode tomar como base o degrau já promovido pelo antigo dono (degrau a mais, limitado a corredor).
- Opção vanilla "Ativos só de dia/noite" (`ZombieLore.ActiveOnly`): o `makeInactive` do jogo desfaz o ajuste na troca de fase; o laço reaplica, mas os dois podem brigar com zumbi inativo.
- No cliente de MP o Eco é reconhecido pelo outfit: zumbi vanilla que sorteou `NOM_Eco` no fallback de zona (raro, ADR-003) fica lento só no cliente.

## Sessões

- 2026-10-04 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — pesquisa no bytecode, plano e implementação da sprint (tasks 1–6)
