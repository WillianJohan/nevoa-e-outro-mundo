# Sprint 0005 — Sem-rosto e atmosfera da névoa

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0005-sem-rosto-e-nevoa` |
| Plano | [plan.md](plan.md) |
| GDD | [monsters.md#sem-rosto](../../gdd/monsters.md#sem-rosto), [atmosphere.md](../../gdd/atmosphere.md), [ADR-007](../../architecture/adr-007-sem-rosto-e-atmosfera-local.md) |

## Objetivo

Quando a névoa sobe, o Outro Mundo acorda: o som muda, o rádio chia, o chão se cobre de sangue e o Sem-rosto caça.

## Critérios de aceite

- [x] Sem-rosto só existe com névoa ≥ `FogThreshold` e volta a ser zumbi comum quando ela baixa — sorteio por período de névoa (ADR-006/ADR-007): `semrosto_rules_deterministic_and_needs_period`, `semrosto_rules_rate_matches_chance`, `semrosto_only_in_fog` (sem névoa, sem período e depois da névoa: nada), `fog_server_rejects_bad_move` (névoa acabou: o servidor recusa), `fog_period_counts_once_per_fog`, `fog_mp_broadcasts_edge_with_period`, `fog_client_follows_server`, `fog_client_asks_state_on_join`; o Sem-rosto não tem stats, então não há o que desfazer. A flag `fog` é a da sprint 0001. No jogo: Roteiro passos 2 e 8
- [ ] Olhado ou iluminado, some e reaparece mais perto, fora do campo de visão — lógica coberta contra fake com visão e luz por jogador: `semrosto_seen_moves_closer_out_of_view` (com controle: zumbi comum fica), `semrosto_unseen_stays` (de costas não; no escuro só com lanterna), `semrosto_cooldown_no_flicker`, `semrosto_no_spot_no_move`, `semrosto_eco_never`, `fog_sp_seen_moves_zombie`, `fog_server_rejects_bad_move`, `fog_server_relays_move`, `fog_client_only_owner_moves`, `fog_client_reports_by_online_id`, `fog_server_fallback_replaces_stuck`, `client_removes_replaced_semrosto`. Escolha do caminho por bytecode (`NetworkZombiePacker.parseZombie` 64–88 e `applyZombie` 41–97: o servidor aceita a posição do dono; `NetworkZombieAI.parse` 51–80: a cópia remota anda até ela). Falta o jogo: `isCanSee` como "visto", `teleportTo` no dono, deslize nos outros clientes — Roteiro passos 3, 4, 9 e 10
- [ ] Rádio chia mais forte quanto mais perto, sem exigir rádio no inventário — `sound_static_follows_distance`, `semrosto_nearest`, `semrosto_rules_static_volume`, todos os testes de som rodam num fake que explode em `emitter:playSound`/`stopSound` (vão pra rede), `sound_restarts_dead_loop`; som original declarado (`config_sound_scripts_point_to_files`, `config_fog_sounds_loop`). Falta ouvir: `setVolume` no som do mod e o loop de arquivo — Roteiro passo 5
- [ ] Ambiente troca para drone + ruídos metálicos na névoa, com transição — `sound_drone_fades_in_and_out` (8 s de entrada e de saída, um loop só), `sound_metal_spread_in_fog`, `sound_toggles`. Falta ouvir — Roteiro passos 2 e 8
- [ ] Overlays de sangue/ferrugem surgem aos poucos perto do jogador e somem com a névoa, sem sobrar sprite no mapa depois de salvar e recarregar — "sem sobrar no save" resolvido por bytecode: `IsoMarkers` não tem `save`/`load` e o marcador não é objeto do square (pz-api-notes §5); `overlays_never_touch_the_map` (square falso explode em escrita, `addBloodSplat` também), `overlays_grow_slowly`, `overlays_capped`, `overlays_fade_out_and_removed_on_fog_end`, `overlays_far_ones_removed`. Falta ver o sprite de tile achado pelo nome — Roteiro passos 6 e 7
- [x] Overlays são locais: em MP, cada cliente vê os seus — `addIsoMarker` volta `nil` no servidor e não manda pacote (bytecode `IsoMarkers.addIsoMarker` offset 0, sem rede na classe); o código só roda fora do dedicado (`overlays_inert_on_dedicated`). No jogo: Roteiro passo 10
- [x] Noite + névoa juntas: todos os sistemas ativos ao mesmo tempo sem conflito — `night_and_fog_together` (solo com Night, Variants, Fog, som, vinheta e overlays carregados juntos: o mesmo zumbi é Estalador cego e Sem-rosto que some; ao amanhecer com névoa o Estalador volta a comum e a névoa segue; a névoa baixa e a noite segue), `semrosto_rules_independent_of_night_variant` (P(as duas) ≈ produto). No jogo: Roteiro passo 8
- [x] Toggles no sandbox — `SemRostoEnabled`, `SemRostoChance`, `FogAmbience`, `FogOverlays`, `FogVignette`, `FogVignetteIntensity`: `config_fog_defaults`, `config_every_option_has_default_and_translations` (PTBR e EN), `semrosto_disabled`, `sound_toggles`, `overlays_toggle_and_missing_sprites`, `vignette_off_toggle`. No jogo: Roteiro passo 1
- [ ] Vinheta na névoa (do spike de shader), sem atrapalhar o forrageamento — `vignette_on_in_fog_survives_update_overlay`, `vignette_yields_to_foraging`, `vignette_restores_on_fog_end` (inclusive se o vanilla não rodar o `updateOverlay`), `vignette_keeps_foreign_override`, `vignette_inert_on_dedicated`. Falta o probe do spike no jogo — Roteiro passo 11

`./run-tests.sh`: `total=244 passou=244 falhou=0`.

## Roteiro in-game

Jogo em `-debug`, mod ativo. Log em `~/Zomboid/console.txt` (solo; no MP,
`[NOM] nevoa …` sai no console do **servidor** e `[NOM] semrosto visto …` no do
cliente). Névoa forçada pelo painel de clima do admin **não** liga o estado de
névoa (sprint 0001): use o sandbox "Ciclo de névoa" = "Névoa eterna" num save de
teste. Pra ligar e desligar a névoa no console Lua (solo, muda o sandbox do save):
`getSandboxOptions():getOptionByName("FogCycle"):setValue(2); getSandboxOptions():toLua()`
(sem névoa) e `setValue(3)` (eterna). A flag muda no minuto de jogo seguinte.
Pra achar Sem-rosto rápido: `SemRostoChance` = 100.

1. Sandbox → "Névoa e Outro Mundo": aparecem "Sem-rosto", "Chance de Sem-rosto (%)" (5), "Névoa: som ambiente", "Névoa: sangue e ferrugem no chão", "Névoa: vinheta na tela", "Intensidade da vinheta da névoa" (1.0), com tooltip; em inglês "Faceless". **Esperado:** nenhum `ERROR`/`WARN` com `NOM_` ou `NOM_sounds` no `console.txt`.
2. Save novo, "Névoa eterna", de dia, ao ar livre. **Esperado:** `[NOM] nevoa fog=true periodo=1`; em ~8 s o drone grave entra; um baque metálico distante a cada 20–60 s. Desligar a névoa (console): `[NOM] nevoa fog=false periodo=1`, o drone some em ~8 s.
3. **Sem-rosto visto:** `SemRostoChance` = 100, névoa, Spawn Horde com 3 zumbis a ~15 tiles à frente. **Esperado:** cada um, ao aparecer na tela, some e reaparece ~3 tiles mais perto, atrás ou do lado do jogador, fora da vista; `[NOM] semrosto visto x=… y=… para x=… y=…` e `[NOM] nevoa semrosto some x=… y=…`. Não pisca (no máximo um sumiço a cada 4 s por zumbi). **Se** ele reaparecer à vista ou não sumir: registrar (o `isCanSee` do square não é "visto").
4. **Iluminado:** mesmo save, 23:00 (Debug → Time), sem lanterna, zumbi Sem-rosto a ~8 tiles à frente no escuro. **Esperado:** não some enquanto não é visto; acender a lanterna apontada pra ele: some.
5. **Rádio:** com um Sem-rosto atrás do jogador (de costas), aproximar e afastar. **Esperado:** chiado de rádio que sobe perto (máximo a ≤ 3 tiles) e some a ≥ 30 tiles; sem rádio no inventário. **Se** o volume não mudar: `setVolume` não pega no som do mod (registrar). **Se** o chiado tiver um corte a cada ~4 s: o `loop = true` não vale pra `file` e o mod está tocando de novo.
6. **Overlays:** névoa, parado ao ar livre 1 minuto. **Esperado:** manchas de sangue e de ferrugem aparecem uma a uma, com fade, a 3–12 tiles, até umas 40; andando 30 tiles, as de trás somem. **Se** não aparecer nada: procurar `[NOM] overlays: nenhum sprite encontrado` (o `getTexture` não acha o sprite de tile pelo nome).
7. **Save:** com manchas no chão, salvar, sair, carregar o save com a névoa já desligada (sandbox "Normal"). **Esperado:** nenhuma mancha no chão. Carregar de novo com névoa: as manchas recomeçam do zero.
8. **Noite + névoa:** névoa eterna, 23:00, `EstaladorChance` = 100, `SemRostoChance` = 100. **Esperado:** `[NOM] noite night=true` e névoa ligada; os zumbis são Estaladores cegos (agachado, passa) **e** somem quando vistos; drone, rádio, manchas e vinheta ao mesmo tempo. 07:00: os Estaladores voltam a comum, a névoa continua. Desligar a névoa: o Sem-rosto vira zumbi comum (olhar pra ele não faz nada).
9. **MP** (servidor dedicado local + 1 cliente): repetir 2, 3 e 5. **Esperado:** `[NOM] nevoa fog=true` no servidor; no cliente o Sem-rosto some ao ser visto e não volta pro lugar antigo. **Se** ele voltar (snap-back): o dono não aplicou; na próxima vez que for visto ali deve sair `[NOM] nevoa semrosto substituido` no servidor (fallback) e o zumbi novo aparece no destino.
10. **MP com 2 clientes:** A olha o Sem-rosto, B olha A de longe. **Esperado:** em A ele some; em B ele desliza até o ponto novo (registrar como fica). Overlays: cada cliente vê manchas diferentes, só em volta de si.
11. **Vinheta (probe do spike):** névoa, de dia, ao ar livre. **Esperado:** bordas escuras e desfocadas entram com fade, sem ícones nem UI de forrageamento; continuam depois de 1–2 min andando e entrando em casa. Apertar a tecla de forragear: o forrageamento funciona (com a vinheta dele); soltar: a vinheta da névoa volta. Desligar a névoa: a vinheta sai com fade. `FogVignetteIntensity` = 2: mais escura; 0: nenhuma.
    - Probe manual do spike, sem o mod tocar no SearchMode (névoa desligada), no console:
      ```lua
      local pn = 0
      local sm = getSearchMode()
      local p = sm:getSearchModeForPlayer(pn)
      ISSearchManager.getManager(getPlayer()).isOverride = true
      p:getBlur():setTargets(0.2, 0.2)
      p:getDesat():setTargets(0.3, 0.3)
      p:getRadius():setTargets(6, 6)
      p:getDarkness():setTargets(0.7, 0.7)
      p:getGradientWidth():setTargets(3, 3)
      sm:setEnabled(pn, true)
      ```
      **Esperado:** vinheta com fade, sem UI de forrageamento; `sm:setEnabled(pn, false)` + `isOverride = false` desliga. Repetir sem a linha do `isOverride`: se a vinheta sumir sozinha, a ressalva do spike é real (o mod já trata).

## Checkpoints

- **04/10/2026** — Pesquisa no bytecode do B42.20.4 antes do plano: o servidor aceita a posição do dono do zumbi e as cópias remotas andam até ela (teleporte vai no dono); "visto" é `square:isCanSee(pn)` do cliente; `emitter:playSound` manda pacote no cliente de MP e `playSoundLocal` não; `IsoMarkers` não tem save nem rede. Plano escrito; ADR-007.
- **04/10/2026** — Tasks 1–8 na branch: sandbox (6 opções, PTBR/EN), regras puras (`NOM_SemRostoRules`, `NOM_AtmosphereRules`, sorteio do Sem-rosto no `NOM_VariantRules`), período de névoa e flag `fog` (`server/NOM_Fog.lua`, `NOM_FogState`, `client/NOM_FogClient.lua`), Sem-rosto (`NOM_SemRosto`, fallback por substituição), som (`client/NOM_FogSound.lua` + 3 sons procedurais), vinheta (`client/NOM_FogVignette.lua`), overlays (`client/NOM_FogOverlays.lua`), teste de noite + névoa. 244 testes passando. Falta o roteiro in-game e o MP.

## Aprendizados

1. **`emitter:playSound` não é local no cliente de MP.** `FMODSoundEmitter.playSound(String)` manda `PacketType.PlaySound` quando o emitter é de um `IsoMovingObject` (jogador ou zumbi), e `stopSound` manda `sendStopSound`. Som "só pra mim" é `player:playSoundLocal` (= `playSoundImpl(nome, nil)`) e `stopSoundLocal`. `playUISound` também é local, mas o Lua não controla o volume dele.
2. **Posição de zumbi no MP é do dono.** O servidor joga fora o pacote de quem não é dono e aplica a posição do dono sem conferir distância; teleporte feito só no servidor volta no pacote seguinte. A cópia remota não teleporta: anda até a posição nova, até 2× mais rápido. Qualquer "sumir" no MP tem que ser feito no dono, e os outros veem deslizar.
3. **"Visto" só existe no cliente, e inclui a luz.** `square:isCanSee(pn)` é linha de visão + cone + luz, calculado pelo `LightingJNI` do cliente; `player:CanSee(obj)` é só linha reta (no escuro "vê" tudo). O teste completo do jogo (`TestIfSeen`) é protegido. O servidor não tem como conferir "visto": confere distância e confia no resto.
4. **Overlay seguro é o que o jogo não salva.** `addBloodSplat` grava no chunk; sprite no objeto do square vai pro save e pra rede. `IsoMarkers` é lista em memória, sem save/load, e devolve `nil` no servidor: o único jeito de pintar o chão "só pra mim".
5. **Devolver o SearchMode pela fórmula, não pela memória.** O estado `enabled` lembrado no começo da névoa pode estar velho (o forrageamento ligou e desligou no meio). No fim, o mod põe o que o `updateOverlay` vanilla poria (`isSearchMode or isEffectOverlay`), sem depender de ele rodar.

## Pendências que a próxima sprint herda

- **Roteiro in-game e MP inteiros** (passos 1–11 acima).
- **Estalo do Estalador sai pra rede no MP** (achado nesta sprint, código da 0004): `z:getEmitter():playSound` em toda cópia local de cada cliente manda `PlaySound` ao servidor, que repassa: o estalo pode tocar várias vezes. Trocar por `z:getEmitter():playSoundImpl(nome, nil)` (local, posicional) na 0006, depois de confirmar no jogo.
- No MP, outro jogador pode ver o Sem-rosto deslizar até o ponto novo (cópia remota anda até a posição do dono). Só quem viu tem a garantia de "fora da vista" (ADR-007).
- O servidor confere o destino só por distância: um cliente malicioso consegue puxar um Sem-rosto pra perto de si (um a cada 4 s por zumbi).
- O servidor aceita um aviso `semRostoSeen` a cada 250 ms por jogador: dois Sem-rosto vistos no mesmo instante, o segundo só some na próxima tentativa (4 s depois).
- Fallback por substituição: depende de `addZombiesInOutfit` no dedicado (o Eco já usa) e de `dressInPersistentOutfitID`; o zumbi novo perde vida e alvo do antigo.
- Sem visual próprio do Sem-rosto (como as variantes da noite, ADR-006): o aviso é o rádio.
- Som e overlays seguem só o primeiro jogador local (`getPlayer()`); em tela dividida, o segundo ouve e vê os do primeiro. A vinheta é por jogador.
- `loop = true` em som de arquivo é UNKNOWN; se não valer, o mod toca de novo e pode haver um corte audível (Roteiro passo 5). Drone e rádio usam o volume "Ambiente" do jogo (`master = Ambient`).
- Sprite de tile por nome no `addIsoMarker` é UNKNOWN (Roteiro passo 6); o mod valida 124 nomes com `getTexture` na primeira mancha.
- `moved` (servidor) e o cooldown do cliente ficam chaveados pelo objeto do zumbi até a névoa acabar.

## Sessões

- 2026-10-04 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — pesquisa no bytecode, plano e implementação da sprint
