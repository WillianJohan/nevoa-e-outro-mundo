# Sprint 0004 — Estalador e Corredor noturno

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0004-estalador-corredor` |
| Plano | [plan.md](plan.md) |
| GDD | [monsters.md](../../gdd/monsters.md#estalador), [ADR-006](../../architecture/adr-006-variantes-deterministicas.md) (substitui o mecanismo da [ADR-001](../../architecture/adr-001-variantes-por-moddata.md)) |

## Objetivo

À noite, parte dos zumbis vira Estalador ou Corredor, e cada um obriga o jogador a jogar diferente.

## Critérios de aceite

- [x] Sorteio preguiçoso: cada zumbi é sorteado uma vez por noite, inclusive os de chunks carregados depois — o sorteio virou conta, não marca ([ADR-006](../../architecture/adr-006-variantes-deterministicas.md)): `variant_rules_deterministic`, `variant_rules_rerolls_each_night`, `stats_variant_follows_outfit_id` (o laço recalcula a cada passada com o ID atual, então zumbi de chunk novo entra na primeira passada), `stats_reload_at_night_reapplies`, `night_number_survives_restart`, `night_mp_sends_night_number`, `night_client_takes_night_number`; o cliente recebe o mesmo `persistentOutfitID` (bytecode `ZombiePacket.set` → `NetworkZombieSimulator.parseZombie` 140–152). No jogo: Roteiro passos 2 e 6
- [x] Desmarcar restaura `NOM_orig` — nenhum zumbi fica Estalador/Corredor de dia, nem depois de salvar e recarregar — não há `NOM_orig`: nada é guardado, o perfil volta a "dia" e o jogo fica com o sandbox. `stats_corredor_sprints_at_night_and_returns`, `stats_estalador_blind_and_sharp_ears` (voltam de dia, sandbox intacto), `stats_reload_by_day_is_untouched`, `stats_dead_variant_forgets`, `ai_day_does_nothing`, `variants_server_rejects_non_corredor_and_day`. No jogo: Roteiro passos 3 e 7
- [ ] Estalador ignora visão: jogador agachado e em silêncio passa do lado dele — lógica coberta contra um fake na ordem do jogo, inclusive o spot forçado que desfazia a primeira versão (spot com `bonusSpotTime` → `OnZombieUpdate` → `spotted(spottedLast, true)` → máquina de estados; caminhada até a última posição vista; useless surdo): `ai_estalador_ignores_silent_crouched` (com controle: zumbi comum no mesmo lugar morde), `ai_estalador_releases_when_player_makes_noise`, `ai_estalador_window_is_short`, `ai_estalador_useless_never_outlives_night`, `ai_estalador_hit_releases_now`, `ai_reuse_releases`, `ai_foreign_useless_untouched`, `ai_estalador_hears_walking_player`, `ai_estalador_follows_sound`, `ai_estalador_hit_wakes_it`, `ai_remote_untouched`; alavanca por bytecode (`setUseless` → `spottedNew` 191–208). Falta o jogo: Roteiro passos 4 e 9
- [ ] Estalador emite estalo periódico e tem agarrão letal rápido — estalo: `ai_click_only_estalador`, `ai_click_is_spread`, som declarado (`config_sound_scripts_point_to_files`); falta ouvir no jogo: Roteiro passo 5. **Agarrão letal: pendência** — não existe caminho de dano por golpe de zumbi (ver Pendências)
- [x] Corredor é comum de dia e sprinter à noite — `stats_corredor_sprints_at_night_and_returns` (sandbox "Arrastados": vira corredor à noite e volta), `night_rules_wanted_corredor` (sprinter mesmo com `NightFaster` desligado). No jogo: Roteiro passo 6
- [ ] Corredor grita ao ver o jogador e atrai zumbis num raio de `CorredorScreamRadius` — lógica coberta: `ai_corredor_reports_once_per_acquire`, `variants_sp_scream_sound_and_call`, `variants_mp_command_finds_zombie`, `variants_client_reports_by_online_id`, `variants_scream_cooldown`, `variants_scream_reach_is_radius` (alcance efetivo = raio, com o ×3 da audição compensado), `variants_server_ignores_eco`, `variants_rejects_far_sender`, `variants_rate_limit_per_player`. Falta o jogo: Roteiro passos 6, 8 e 10
- [ ] Outfit/textura e sons de cada um (finais ou placeholders registrados em Pendências) — sons: originais procedurais (`scripts/gen_sounds.py`, `CREDITS.md`), placeholder aceitável; **sem outfit**: vestir outro outfit troca o `persistentOutfitID` e, com ele, a variante (ADR-006). Visual registrado em Pendências; falta ouvir os sons no jogo (Roteiro passos 5 e 6)
- [x] Toggles e chances no sandbox — `EstaladorEnabled`, `CorredorEnabled`, `EstaladorChance`, `CorredorChance`, `CorredorScreamRadius`: `config_variant_defaults`, `config_every_option_has_default_and_translations` (PTBR e EN), `variant_rules_chance_bounds_and_toggles`, `variant_rules_config_reads_sandbox`, `variants_server_rejects_non_corredor_and_day` (toggle). No jogo: Roteiro passo 1
- [x] `./run-tests.sh` cobre o sorteio por período — `tests/test_variant_rules.lua` (8 testes: determinismo, ID 0 e noite desconhecida, limites e toggles, taxa ≈ chance em 20 000 IDs no formato do jogo, re-sorteio por noite, noites independentes (P(as duas) ≈ p²), cooldown); `total=187 passou=187 falhou=0`

## Roteiro in-game

Jogo em `-debug`, mod ativo, save novo com defaults. Log em `~/Zomboid/console.txt`
(solo). No MP, `[NOM] variantes grito` sai no console do **servidor**. Pra
achar variantes rápido: sandbox `EstaladorChance` = 50 e `CorredorChance` = 50
(um save por vez, ou 100 de um e 0 do outro).

1. Sandbox → página "Névoa e Outro Mundo": aparecem "Estaladores", "Corredores", "Chance de Estalador (%)" (5), "Chance de Corredor (%)" (10) e "Raio do grito do Corredor (tiles)" (40), com tooltip; em inglês "Clickers"/"Runners". **Esperado:** nenhum `ERROR`/`WARN` com `NOM_` ou `NOM_sounds` no `console.txt`.
2. `EstaladorChance` = 100, `CorredorChance` = 0. De dia, Spawn Horde com 10 zumbis a ~15 tiles. Debug → Time: 22:00. **Esperado:** `[NOM] noite night=true`, `[NOM] noite stats aplicados=10 …`; nenhum zumbi corre atrás do jogador parado e agachado a 15 tiles.
3. Debug → Time: 07:00. **Esperado:** `[NOM] noite night=false`, `stats aplicados=` de novo; os zumbis voltam a reagir à visão (em pé, a ~8 tiles, eles vêm).
4. **Estalador cego:** à noite (passo 2), agachar (C) e andar devagar até ficar do lado de um Estalador, dar a volta nele, ficar uns 10 segundos e ir embora. **Esperado:** ele não ataca (pode dar um passo até onde o jogador foi visto pela última vez: `WalkTowardState` segue sem alvo). Levantar e andar do lado: ele ataca em até um segundo. Agachado, correr (Shift): ele ataca. **Se** ele atacar o jogador agachado: o useless não segurou o spot forçado (registrar).
   - Surdez da janela: agachado do lado dele, um segundo jogador (ou um tiro de longe com outro personagem/arma barulhenta jogada) faz barulho a ~15 tiles. **Esperado:** ele vai até o som em no máximo ~1 segundo de atraso (a janela de useless fecha e abre a cada `BLIND_FRAMES` = 60 updates).
5. **Estalo:** parado perto de um Estalador, à noite. **Esperado:** um estalo seco (três cliques) vindo da posição dele, em média a cada 2 minutos de jogo, mais baixo de longe, inaudível a ~25 tiles. **Se** não tocar: procurar `NOM_EstaladorClick` no `console.txt` (som não carregou: `file =` do mod não resolvido).
6. **Corredor:** `EstaladorChance` = 0, `CorredorChance` = 100, sandbox de velocidade vanilla "Arrastados". De dia: zumbis arrastados. 22:00. **Esperado:** correm; ao ver o jogador, um grito e `[NOM] variantes grito x=… y=… raio=40`; zumbis comuns a 30–40 tiles (spawnar outro grupo com `CorredorChance` = 0 num save à parte, ou contar os que chegam) vêm até o Corredor.
7. À noite, com Corredores e Estaladores: salvar, sair, carregar ainda de noite. **Esperado:** os mesmos zumbis continuam variantes (mesmo número da noite). Pular pra 08:00: todos comuns.
8. **Cooldown:** perto de um Corredor, sair da vista dele e voltar várias vezes em menos de 30 minutos de jogo. **Esperado:** só um `[NOM] variantes grito` por Corredor nesse intervalo.
9. **Golpe acorda:** agachado do lado de um Estalador, bater nele. **Esperado:** ele passa a atacar mesmo com o jogador agachado.
10. **MP** (servidor dedicado local + 1 cliente): repetir 2, 4, 5 e 6. **Esperado:** o Estalador ignora o jogador agachado na tela do cliente; o estalo toca no cliente; o grito sai no console do **servidor** e toca no cliente; os zumbis vêm. **Se** o grito não sair: o `corredorSaw` não chegou ou o `onlineID` não casou (registrar).
11. **MP com 2 clientes:** um Estalador dono do cliente A, jogador B agachado do lado. **Esperado:** B passa. Registrar se o golpe de B acorda o Estalador (o `OnHitZombie` dispara em quem bate, que pode não ser o dono).
12. **Cliente entra no meio da noite:** servidor já à noite, conectar. **Esperado:** variantes valem logo depois de entrar (a resposta ao `nightState` traz o número da noite).
13. **Ecos:** à noite, com `EstaladorChance` = 100, esperar um Eco. **Esperado:** o Eco anda arrastado, não estala nem grita.

## Checkpoints

- **04/10/2026** — Pesquisa no bytecode do B42.20.4 antes do plano: o `persistentOutfitID` chega igual ao cliente (`ZombiePacket`), `OnZombieUpdate` antes da máquina de estados, o spot é só `setTarget`, nenhum evento Lua no golpe do zumbi, `require` roda cada arquivo uma vez. Plano escrito; ADR-001 vira ADR-006 (variante determinística).
- **04/10/2026** — Tasks 1–8 na branch: sandbox (5 opções, PTBR/EN), `NOM_VariantRules`, `NOM_NightCount` (contador do Eco compartilhado, número da noite na mensagem `night`), perfil das variantes no `NOM_NightStats`, `NOM_VariantAI` (cego, estalo, aviso do Corredor), `server/NOM_Variants.lua` (grito + chamado), `client/NOM_VariantsClient.lua`, sons procedurais (`scripts/gen_sounds.py`), ADR-006. 175 testes passando. Falta o roteiro in-game e o MP.
- **04/10/2026** — Review: a primeira cegueira (`setTarget(nil)`) era desfeita pelo spot forçado do jogo (`bonusSpotTime`/`spottedLast`, `updateInternal` 956–991). Trocada por `setUseless(true)` em janela curta, solta no barulho, amanhecer, troca de variante, golpe e reaproveitamento. `corredorSaw` só de jogador a até 25 tiles e um a cada 2 s por jogador. Sorteio trocado por mistura não linear (noites seguidas estavam correlacionadas: 24,7% contra 15%). Amanhecer limpa alerta/caça. `OnZombieUpdate` sai sem chamada Java pro zumbi comum. 187 testes.

## Aprendizados

1. **Visão "ruim" não cega, e tirar o alvo não basta.** `updateVisionRadius` prende o raio entre 10 e 20 tiles: o pior degrau ainda vê a 10. `setTarget(nil)` no `OnZombieUpdate` parece certo (o evento vem antes da máquina de estados), mas o spot deixa `bonusSpotTime = 720` e `spottedLast`, e o `updateInternal` refaz o spot forçado **entre** o evento e a máquina de estados: o alvo volta no mesmo frame. Só `setUseless(true)` corta, porque o `spottedNew` zera `spottedLast` de zumbi useless. Preço: useless é surdo, então a cegueira tem que ser janela curta. Fake de teste que não modela o spot forçado aprova o código errado.
2. **O `persistentOutfitID` é o único estado do zumbi que todo mundo vê igual.** O popman guarda, o `ZombiePacket` leva, o cliente recria o zumbi com ele. Qualquer coisa "por zumbi" que precise sobreviver a reload e valer no MP sem rede tem que ser função dele. Corolário: trocar o outfit do zumbi troca a identidade dele.
3. **Não existe golpe de zumbi visível pelo Lua.** `AttackState` → `AddRandomDamageFromZombie` não dispara evento, e `OnPlayerGetDamage` só sai de fome/sede/veneno/doença/sangramento, arma, queda, fogo e carro. Dano por variante não dá; só observar a vida do jogador depois.
4. **O alvo do zumbi não existe no servidor do MP.** O `target` não viaja no pacote; só quem simula sabe quem o zumbi está caçando. Decisão que depende do alvo (grito) precisa de aviso do dono, e o servidor confere o resto.
5. **Contador lido por dois arquivos: conte pelo estado, não pela borda.** O `NOM_NightCount` lê o `inNight` salvo; a ordem em que o Eco e a Noite reagem ao anoitecer não importa, e a poda do Eco virou "uma vez por noite nova", guardada em memória.

## Pendências que a próxima sprint herda

- **Roteiro in-game e MP inteiros** (passos 1–13 acima).
- **Agarrão letal rápido do Estalador:** não feito. O jogo não tem dano por zumbi nem evento no golpe do zumbi (pz-api-notes §2.2, §3.2). Caminho possível, a decidir com o autor: no dono do jogador, observar a queda de vida e `player:getAttackedBy()` e, se for Estalador, aplicar dano extra — é aproximação, não golpe de verdade, e conflita com a decisão "sem dano a mais".
- **Visual das variantes:** nenhum. Outfit troca o `persistentOutfitID` (e a variante); `addVisualBandage` não tem remoção e ficaria de dia. Precisa de outra alavanca visual (textura por cima, partícula, overlay local) — sprint 0005/arte.
- **Sons são placeholders procedurais** (`scripts/gen_sounds.py`); trocar por som final quando houver.
- Cegueira por `setUseless` em janela de 60 updates: enquanto useless o Estalador é surdo (`RespondToSound`), e ele ainda anda até a última posição em que viu o jogador (`WalkTowardState`, sem ataque). Calibrar `NOM_VariantAI.BLIND_FRAMES` no jogo (Roteiro passo 4).
- No MP o `OnHitZombie` dispara em quem bate; se não for o dono, o Estalador não "acorda" (Roteiro passo 11).
- Estalador alertado por golpe fica alerta até ir pro virtual ou amanhecer.
- Estalador sempre com audição apurada: com `NightSharperSenses` desligado, ouve caça, lanterna e grito a 3× o alcance (registrado no [night.md](../../gdd/night.md)).
- Zumbis com o mesmo `persistentOutfitID` têm a mesma variante na mesma noite (ADR-006).
- O servidor confere `corredorSaw` pela variante, a noite, o cooldown, a distância (25 tiles) e um aviso a cada 2 s por jogador; um cliente malicioso perto de um Corredor ainda consegue o grito dele (um a cada meia hora). A tabela do limite por jogador só esvazia quando o servidor reinicia.

## Sessões

- 2026-10-04 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — pesquisa no bytecode, plano e implementação da sprint (tasks 1–8)
