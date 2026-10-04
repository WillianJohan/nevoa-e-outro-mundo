# Sprint 0002 — Eco

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0002-eco` |
| Plano | [plan.md](plan.md) |
| GDD | [monsters.md#eco](../../gdd/monsters.md#eco), [ADR-003](../../architecture/adr-003-eco-spawnado.md) |

## Objetivo

À noite, os corpos perto do jogador soltam Ecos, que somem ao morrer e ao amanhecer.

## Critérios de aceite

- [ ] **Spike primeiro:** escolhida a técnica de "morrer sem cadáver", testada em solo **e** MP. Resultado registrado em Aprendizados — técnica escolhida por bytecode (Aprendizado 3); falta rodar no jogo: Roteiro passos 4 e 8
- [x] Corpo a até `EcoRadius` de um jogador solta um Eco durante a noite (checagem periódica, não só no início) — `eco_spawns_one_per_body_at_night`, `eco_periodic_scan_catches_new_bodies`, `eco_body_out_of_radius_ignored`, `eco_nothing_by_day`, `rules_pick_respects_radius_circle`. No jogo: Roteiro passo 2
- [x] Cada corpo solta Eco uma única vez (`NOM_ecoReleased`), inclusive depois de salvar e recarregar — `eco_spawns_one_per_body_at_night` (segunda varredura), `eco_released_flag_survives_restart`, `eco_two_players_share_bodies_once`; o `modData` do corpo vai pro save: bytecode `IsoDeadBody.save` → `IsoMovingObject.save` grava `KahluaTable` (offsets 104–133) e `load` relê (89–118). No jogo: Roteiro passo 6
- [x] Corpo queimado ou enterrado não solta Eco — deixa de ser `IsoDeadBody`, sem regra extra: enterrar chama `removeCorpse` (`shared/TimedActions/ISBuryCorpse.lua:73`), queimar troca o corpo por `burnedCorpse` e chama `removeCorpse` (bytecode `IsoDeadBody.Burn` 142–204)
- [x] Teto `EcoMaxPerPlayer` respeitado — testado com uma pilha de 60+ corpos: `eco_cap_respected_with_60_bodies` (60 corpos, teto 30, repõe só o que morreu), `eco_overlapping_players_share_nearby_ecos_in_cap`, `rules_pick_nearest_first_up_to_quota`. No jogo: Roteiro passo 3
- [ ] Eco morto não deixa cadáver nem loot — lógica coberta (`eco_death_clears_inventory_and_removes_corpse`, `eco_corpse_on_neighbor_square_is_removed`, `eco_corpse_is_swept_and_never_releases`, `eco_normal_zombie_keeps_corpse`); falta o jogo: Roteiro passos 4 e 8
- [ ] Ao amanhecer, todos os Ecos somem — lógica coberta (`eco_dawn_removes_all`, `eco_dawn_mp_sends_ids`, `eco_dawn_mp_skips_unassigned_online_id`, `eco_reloaded_by_day_is_removed_next_tick`, `eco_reloaded_on_later_night_is_removed`, `eco_restart_mid_night_keeps_same_night`, `eco_twin_death_keeps_unloaded_twin`, `eco_twin_dawn_removal_keeps_unloaded_twin_known`, `eco_twin_later_night_keeps_both_nights`, `client_removes_ghosts_by_online_id`, `client_skips_unassigned_online_id`); falta o jogo, principalmente o fantasma no cliente de MP: Roteiro passos 5, 7 e 9
- [ ] Textura fantasmagórica aplicada (final ou placeholder registrado em Pendências) — placeholder: outfit `NOM_Eco` (camisola de hospital + véu de noiva vanilla), registrado em Pendências; falta ver no jogo: Roteiro passo 2
- [x] Toggle e números do Eco no sandbox — `EcoEnabled`, `EcoMaxPerPlayer`, `EcoRadius`: `config_eco_defaults`, `config_every_option_has_default_and_translations` (PTBR e EN), `eco_disabled_spawns_nothing`. No jogo: Roteiro passo 1
- [x] `./run-tests.sh` cobre a elegibilidade do corpo (raio, já liberado, teto) — `tests/test_eco_rules.lua` (9 testes) e `tests/test_eco.lua` (inclui `eco_overlapping_players_scan_each_square_once`); `total=86 passou=86 falhou=0`

## Roteiro in-game

Jogo em `-debug`, mod ativo, save novo com defaults. Log em `~/Zomboid/console.txt`
(solo) ou no console do **servidor** (MP). Toda linha do mod começa com `[NOM] eco`.

1. Sandbox → página "Névoa e Outro Mundo": aparecem "Ecos", "Máximo de Ecos por jogador" (30) e "Raio dos Ecos (tiles)" (40, máximo 60), com tooltip. **Esperado no `console.txt`:** nenhum `ERROR`/`WARN` com `NOM_Eco` ou `clothing.xml`.
2. Spawnar uns 5 zumbis perto (menu de debug → Spawn Horde), matar todos de dia. Debug → Time: pular pra 22:00 e esperar 10 minutos de jogo. **Esperado:** `[NOM] eco spawn=5`; os Ecos aparecem em cima dos corpos, de camisola de hospital e véu; os corpos continuam no chão. Um golpe derruba (vida 0.3). **Se** aparecer `[NOM] eco outfit NOM_Eco não carregou (persistentOutfitID 0)`: o `clothing.xml` do mod não foi lido — registrar em Aprendizados.
3. Pilha de 60+ corpos (Spawn Horde com 60 e matar, ou repetir). À noite: **esperado** `[NOM] eco spawn=30` e nada mais nas próximas varreduras enquanto os 30 estiverem vivos perto. Matar 5 → na varredura seguinte `[NOM] eco spawn=5`.
4. Matar um Eco. **Esperado:** `[NOM] eco cadaveres=1` alguns segundos depois; nenhum corpo novo no chão, nada pra saquear no lugar.
5. Debug → Time: pular pra 07:00 com Ecos vivos. **Esperado:** `[NOM] eco removidos=N` e nenhum Eco na tela.
6. À noite, com Ecos já liberados: salvar, sair, carregar. Esperar 10 minutos de jogo. **Esperado:** nenhum `spawn=` vindo dos mesmos corpos.
7. À noite, com um Eco vivo: andar pra longe (uns 150 tiles, até o chunk descarregar), pular pra 09:00, voltar. **Esperado:** `[NOM] eco removidos=1` quando o chunk recarrega; o Eco não aparece. Repetir pulando pra 22:00 do dia seguinte em vez de 09:00: **esperado** o mesmo (Eco de outra noite some).
8. **MP** (servidor dedicado local + 1 cliente, `Mods=\NevoaEOutroMundo`): repetir 2 e 4. **Esperado no console do servidor:** as mesmas linhas; no cliente o Eco aparece (spawn do servidor chega ao cliente) e, morto, o cadáver some (`RemoveCorpseFromMap`).
9. **MP:** repetir 5. **Esperado:** os Ecos somem também no cliente. Se ficarem "congelados" na tela do cliente (fantasma), registrar: o `ecoGone` não chegou ou o cliente dono recriou o zumbi.
10. **MP:** conferir se o Eco no cliente cai com um golpe (a vida baixa vale lá também).

## Checkpoints

- **04/10/2026** — Pesquisa no bytecode do B42.20.4 antes do plano: ordem do `OnZombieCreate` no spawn, formato do `persistentOutfitID`, `modData` do corpo salvo, `OnDeadBodySpawn` mudo no dedicado. Plano escrito.
- **04/10/2026** — Tasks 1–4 na branch: sandbox (3 opções, PTBR/EN), `NOM_EcoRules`, borda de flag no `NOM_World`, `server/NOM_Eco.lua`, outfit `NOM_Eco`, `client/NOM_EcoClient.lua`. 73 testes passando, com um jogo falso que imita o bytecode. Falta o roteiro in-game e o MP.

- **04/10/2026** — Rodada de review: Eco reconhecido pelo ID exato + noite em que nasceu (Eco de outra noite some ao voltar, regra do GDD), `onlineID -1` fora do `ecoGone`, varredura lê cada square uma vez e conta os Ecos numa passada, `EcoRadius` máximo 60. 84 testes.
- **04/10/2026** — Review 2: IDs exatos colidem (semente 1..500, ~19% das noites com gêmeos). Lista virou conjunto de noites por ID; morte e remoção não apagam mais o ID. 86 testes.

## Aprendizados

1. **`modData` de zumbi morre com o chunk, e o `getOutfitName()` também mente.** Zumbi que volta do virtual é objeto novo (`createZombieOutsideWorld`): visual limpo, só o `persistentOutfitID` setado, e vestir é preguiçoso (`ModelManager.dressInRandomOutfit`). No `OnZombieCreate`, `getOutfitName()` volta `nil`. O que identifica o Eco é o `persistentOutfitID`: bit 31 = sexo, bits 16–30 = índice do outfit na lista ordenada por nome, bits 0–15 = semente (`PersistentOutfits.pickOutfitMale/getOutfit`). O mod guarda o ID **exato** (com a semente) de cada Eco no `ModData` global, junto do número da noite em que nasceu. O índice muda se a lista de outfits muda, então um ID guardado pode passar a apontar pra outro outfit: por isso o mod confirma vestindo pelo próprio ID (`dressInPersistentOutfitID`, o mesmo que o jogo faria) e descarta o ID que não bate.
2. **No spawn, `OnZombieCreate` dispara antes de vestir.** `addZombiesInOutfit` → `createRealZombieAlways` (evento) → só depois `dressInPersistentOutfit(nome)` e `setHealth`. Quem marca o Eco é o código que spawna, não o evento. E não dá pra remover zumbi dentro do `OnZombieCreate`: o jogo põe ele na lista da célula depois do evento.
3. **`OnDeadBodySpawn` não dispara no servidor dedicado** (`IsoDeadBody.<init>`: `if (... && !GameServer.server)`). A técnica de "morrer sem cadáver" ficou: `OnZombieDead` limpa o inventário (o `DoZombieInventory` já rodou) e o `OnTick` procura no 3×3 o corpo com `modData.NOM_eco` (o construtor do corpo copia o `modData` do zumbi) e chama `removeCorpse(body, false)`, que no servidor manda `RemoveCorpseFromMap`. A varredura periódica é a rede de segurança.
4. **`removeFromWorld` no servidor não avisa o cliente.** O comando de admin usa `NetworkZombiePacker.deleteZombie`, que o Lua não alcança. O servidor manda `ecoGone` com os `onlineID`s e o cliente remove o local (`removeFromWorld` no cliente limpa o cache de zumbis do `GameClient`).
5. **Outfit de mod com nome próprio evita uma armadilha e abre outra.** Outfit vanilla pode ser trocado pelo "estágio" do apocalipse (`ZombiesStageDefinitions.getAdvancedOutfitName`); um nome nosso não. Mas o outfit entra no sorteio de fallback: quando uma definição de zona nomeia um outfit que não existe pro sexo sorteado, `ZombiesZoneDefinition.applyDefinition` cai em `OutfitManager.GetRandomOutfit`, que sorteia entre **todos** os outfits (bytecode `applyDefinition` 16–45). No vanilla isso acontece com `Hunter`, `GuitarGuy` e `Stripclub`: um punhado de zumbis por mundo pode nascer de camisola e véu. Eles **não** viram Eco: o reconhecimento é pelo ID exato (com semente), que só o spawn do mod grava (`eco_random_outfit_zombie_is_not_eco`).
6. **Noite se conta pelo estado salvo, não pela borda.** A primeira leitura do clima depois de subir o servidor já é uma borda `night → true`; contar noite pela borda faria um reinício no meio da noite abrir noite nova e apagar os Ecos dela. O mod salva `inNight` no `ModData` e só conta noite nova quando ele estava `false` (`rules_night_counts_once_per_night`, `eco_restart_mid_night_keeps_same_night`).
7. **ID "exato" não é único.** A semente do `persistentOutfitID` é `Rand.Next(500)+1` (bytecode `PersistentOutfits.pickOutfitMale`): com 30 Ecos do mesmo sexo numa noite, a chance de dois dividirem o ID é ~19%. Apagar o ID quando um morre deixava o gêmeo descarregado virar zumbi comum. A lista guarda um conjunto de noites por ID e só a poda apaga (`eco_twin_death_keeps_unloaded_twin`, `eco_twin_later_night_keeps_both_nights`). O fake dos testes tem semente sequencial, mais gentil que o jogo; `G.fixedSeed` força os gêmeos.

## Pendências que a próxima sprint herda

- **Roteiro in-game e MP inteiros** (passos 1–10 acima).
- **Eco lento e de dano baixo:** só a vida é baixa. Velocidade e força pedem o swap de `ZombieLore` + `DoZombieStats` (pz-api-notes §2.1), que a sprint 0003 cria pra noite agressiva; reaproveitar no Eco.
- **Textura do Eco é placeholder:** outfit `NOM_Eco` com `Gown_Hospital` + `Hat_WeddingVeil` vanilla. Textura própria fica pra quando houver arte.
- Varredura só no andar do jogador: corpo no porão ou no andar de cima não solta Eco enquanto o jogador não estiver no mesmo `z`.
- Corpo pego no colo e largado de novo (`ISGrabCorpseAction`) pode virar `IsoDeadBody` novo sem o `NOM_ecoReleased`: conferir no jogo se o `modData` sobrevive.
- Cadáver de Eco cuja remoção falhou só é varrido à noite.
- ID de Eco fica guardado 7 noites (`NOM_EcoRules.KEEP_NIGHTS`): Eco descarregado que volta depois disso é zumbi comum de camisola e véu.
- Mudar a lista de outfits (outro mod, update do jogo) desloca o índice do `NOM_Eco`: Ecos virtuais naquele momento voltam como zumbis comuns (ver ADR-003).
- Gêmeos (mesmo ID): um gêmeo de noite passada que volta na noite em que o outro nasceu conta como da noite atual e só some no amanhecer.
- Contador de noites salvo no `ModData` global: se o servidor cair entre gravar o contador e salvar o mundo, a mesma noite pode ser contada duas vezes, e os Ecos dela que voltarem de chunk descarregado somem como se fossem de outra noite.

## Sessões

- 2026-10-04 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — pesquisa no bytecode, plano e implementação da sprint (tasks 1–4)
