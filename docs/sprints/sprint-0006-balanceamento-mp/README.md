# Sprint 0006 — Balanceamento, multiplayer e performance

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0006-balanceamento-mp` |
| Plano | [plan.md](plan.md) |
| GDD | [sandbox.md](../../gdd/sandbox.md) |

## Objetivo

O mod inteiro aguenta uma sessão real: defaults divertidos, MP estável e sem derrubar FPS.

Sem o jogo aqui, a sprint fez tudo o que dá pra fazer antes de jogar e preparou uma
sessão só de teste pro Johan: [docs/teste-in-game.md](../../teste-in-game.md).

## Critérios de aceite

- [ ] Sessão de MP com 2+ jogadores por pelo menos 3 noites de jogo, sem erro no `console.txt` do servidor nem dos clientes — falta o jogo: [roteiro, Parte 2](../../teste-in-game.md#parte-2--multiplayer-30-min) (2.3)
- [ ] Defaults do sandbox revisados depois de jogar (o que mudou e por quê, registrado em Checkpoints) — revisão de coerência feita sem jogar, nenhum default mudou ([sandbox.md](../../gdd/sandbox.md#revisão-dos-defaults-2026-10-04-sem-jogar)); falta jogar: [roteiro, Balanceamento](../../teste-in-game.md#balanceamento)
- [x] Preset "leve" e "pesadelo" documentados no GDD de sandbox — [sandbox.md#presets](../../gdd/sandbox.md#presets), valores das 24 opções e um motivo por preset. Não vão no mod: `GlobalObject.getSandboxPresets()` (bytecode 0–104) só lista `*.cfg` da pasta do usuário e os vanilla são 5 nomes fixos (`client/OptionScreens/SandboxOptions.lua:891-895`)
- [ ] FPS e tick do servidor medidos com e sem o mod numa cidade (Louisville/Muldraugh), números registrados — orçamento estático por sistema feito e travado por teste ([architecture/README.md#orçamento-por-sistema](../../architecture/README.md#orçamento-por-sistema): `stats_day_idle_only_after_clean_pass`, `stats_day_idle_wakes_at_night`, `stats_day_idle_wakes_every_hour`, `ai_click_touches_only_estaladores`, `semrosto_scan_one_call_per_common_zombie`, `eco_scan_budget_independent_of_horde`, `eco_scan_one_player_per_tick`); falta medir: [roteiro, Parte 3](../../teste-in-game.md#parte-3--medições-15-min)
- [ ] Remover o mod de um save em andamento não quebra o save — por bytecode nada quebra e não houve o que corrigir ([pz-api-notes §8](../../architecture/pz-api-notes.md#8-remover-o-mod-de-um-save-sprint-0006): `GlobalModData.load` 125–183, `SandboxOptions.load` 95–110, `readLuaFile` 235–272, `PersistentOutfits.getOutfit` 40–58, `ClimateManager.save` só admin); falta o jogo: [roteiro, Parte 4](../../teste-in-game.md#parte-4--remover-o-mod-5-min)
- [x] Todas as pendências herdadas das sprints 0001-0005 resolvidas ou promovidas a `later` — tabela [abaixo](#pendências-herdadas-0001-0005): 2 resolvidas por teste (`look_blizzard_override_uses_final`, `ai_click_is_local_on_mp_client`), as que dependem do jogo no roteiro consolidado, o resto `later` com motivo

`./run-tests.sh`: `total=286 passou=286 falhou=0`.

## Pendências herdadas (0001-0005)

**Roteiro** = vai pro [teste in-game consolidado](../../teste-in-game.md); **later** = fora
do escopo até alguém promover, com o motivo.

| Origem | Pendência | Destino |
|---|---|---|
| 0001–0005 | Roteiros in-game e MP inteiros | **Roteiro** (todas as partes) |
| 0001 | Teste do ramo `ClimateCycle == 6` | **Resolvida:** `look_blizzard_override_uses_final` (falha sem o ramo) |
| 0001 | Névoa do mod no combate à distância | **Roteiro** 1.6 (tiro na névoa) |
| 0002 | Eco "dano baixo" | **later:** o jogo não tem dano por zumbi (decisão do autor, [night.md](../../gdd/night.md#sem-força-e-sem-dano-à-noite)) |
| 0002 | Textura do Eco é placeholder | **later:** depende de arte (sprint 0007 decide o que publica) |
| 0002 | Varredura só no andar do jogador | **later:** porão/andar de cima custaria outra varredura inteira por andar; esperar o jogo mostrar falta |
| 0002 | Corpo pego no colo perde `NOM_ecoReleased`? | **Roteiro** (observação no 1.4); se perder, um corpo solta dois Ecos, sem crash |
| 0002 | Cadáver de Eco que escapou só é varrido à noite | **later:** inofensivo (corpo sem loot), a varredura da noite limpa |
| 0002 | ID de Eco guardado 7 noites; mudança na lista de outfits desloca o índice; gêmeos; contador contado 2× se o servidor cair | **later:** limites aceitos na ADR-003/sprint 0002, sem crash |
| 0003 | Degraus de velocidade/sentidos, lanterna por som | **later:** limite do jogo (só 3 degraus, visão presa em 20) |
| 0003 | Dedicado não aplica stats nos zumbis sem dono | **later:** sem dono = longe de todo jogador |
| 0003 | Velocidade "Aleatória" + troca de dono: degrau a mais | **later:** raro, limitado a corredor |
| 0003 | `ActiveOnly` na fase inativa | **Roteiro** ([0003 passo 14](../sprint-0003-noite-agressiva/README.md#roteiro-in-game)); fora da sessão principal |
| 0003 | Alcance compensado ignora roupa e clima; bote fica ligado | **later:** o jogo não expõe |
| 0003 | Eco no cliente reconhecido pelo outfit | **later:** só zumbi de fallback de zona (raro, ADR-003) |
| 0004 | Agarrão letal do Estalador | **later:** sem caminho no jogo e conflita com "sem dano a mais" (decisão do autor) |
| 0004 | Visual das variantes | **later:** outfit troca a variante (ADR-006); o aviso é o som |
| 0004 | Sons placeholders | **later:** sprint 0007 / arte |
| 0004 | Janela de cegueira (`BLIND_FRAMES`), useless herdado, golpe de quem não é dono, alerta até o virtual | **Roteiro** 1.5 e 2.2 (calibrar com o jogo) |
| 0004 | Audição apurada do Estalador sem `NightSharperSenses`; zumbis com o mesmo ID | **later:** de propósito / ADR-006 |
| 0004 | `corredorSaw`: cliente malicioso perto consegue o grito; tabela por jogador cresce até reiniciar | **later:** limitado a um grito por meia hora por Corredor; um número por jogador |
| 0004/0005 | Estalo do Estalador duplicado no MP | **Resolvida na 0005** (`playSoundLocal`), conferida: `ai_click_is_local_on_mp_client`; ouvir no **Roteiro** 2.1 |
| 0005 | Terceiro jogador vê o Sem-rosto deslizar; dono vendo o destino não move | **Roteiro** 2.2 |
| 0005 | Servidor confere destino só por distância; limite de 250 ms por jogador; fallback por substituição | **later:** limites aceitos na ADR-007; o fallback é conferido no Roteiro 2.1 |
| 0005 | Sem visual do Sem-rosto | **later:** como as variantes |
| 0005 | Som e overlays só do jogador 0 (tela dividida); drone no volume "Ambiente" | **later:** tela dividida fora do escopo de teste |
| 0005 | Calibrar `ATTACK_DIST`/`MIN_DIST` | **Roteiro** 1.6 |
| 0005 | Sprite de tile por nome no `addIsoMarker` | **Roteiro** 1.6 |
| 0005 | `moved` e cooldown chaveados pelo objeto até a névoa acabar | **later:** limpa no fim da névoa |

Comentários `ponytail:` no código (dívida deliberada): todos acima ou já com o teto
escrito no próprio comentário (camada modded do clima, andar do Eco, lanterna por som,
tabelas por jogador, `moved`, alerta do Estalador e, novo, o zumbi pulado na passada
do dia do `NightStats`).

## Roteiro in-game

Um só, pra todas as sprints: [docs/teste-in-game.md](../../teste-in-game.md). Desta
sprint:

0. **Save descartável:** a noite e a névoa forçadas avançam os contadores salvos
   (`debug_forced_night_advances_saved_counter`).
1. **Comandos de debug** (seção "Antes de começar"): `NOM_Debug.status()` imprime
   `[NOM] debug local …` e `[NOM] debug servidor …`; sem `-debug`, `NOM_Debug` é `nil`.
2. **3 noites de MP** (Parte 2.3): nenhum erro com `NOM_` nos três consoles.
3. **Medições** (Parte 3): FPS e tick com e sem o mod, horda de 200 numa cidade, e o
   pico a cada 10 minutos de jogo (varredura do Eco).
4. **Remoção** (Parte 4): save de noite com Ecos e névoa, mod desligado, carrega e
   joga; esperado só linha de opção desconhecida no console.
5. **Balanceamento** (seção final): 5 perguntas que decidem os defaults.

## Checkpoints

- **04/10/2026** — Pendências 0001–0005 colhidas (tabela acima). Teste do ramo
  `ClimateCycle == 6`. Estalo local da 0005 conferido.
- **04/10/2026** — Performance estática: `NightStats` dorme de dia depois de uma passada
  limpa (antes, 20 zumbis por tick o dia inteiro); estalo e varredura do Sem-rosto olham
  tabela/ID antes de chamar o zumbi. Orçamento por sistema no
  [architecture/README.md](../../architecture/README.md#orçamento-por-sistema), cada linha
  com teste.
- **04/10/2026** — Comandos de debug: `client/NOM_Debug.lua` + `server/NOM_DebugServer.lua`,
  estados forçados em `NOM_World.forced` e `NOM_VariantRules.forced`, `NOM_Eco.spawnAt`.
- **04/10/2026** — Remoção do mod analisada no bytecode: nada a corrigir.
- **04/10/2026** — Presets leve/pesadelo e revisão dos defaults. **Nenhum default
  mudou** (sem jogar, trocar número é chute). Achado principal: com o sandbox Apocalypse
  (velocidade aleatória), `NightSpeedMult` 1.5 faz ~60% dos zumbis correrem à noite e o
  Corredor quase só se distingue pelo grito; se o jogo confirmar, o ajuste é
  `NightFaster` desligado por padrão. Roteiro in-game consolidado.
- **04/10/2026** — Review (sem Critical): a noite/névoa forçadas **não** são só memória,
  avançam os contadores salvos (docs corrigidos, aviso no topo do roteiro, teste com o
  `NOM_NightCount` de verdade); quem entra depois recebe as variantes forçadas (resposta
  ao `nightState`); `NightStats` ocioso acorda a cada hora de jogo; varredura do Eco
  espalhada, um jogador por tick; NaN recusado; linha de "negado"; §8 corrigida (tirar ou
  pôr o `NOM_Eco` desloca o índice dos outfits seguintes); roteiro: save/load de noite
  depois da névoa (1.7), corpo carregado no 1.4, "Fora desta sessão" (terceiro cliente,
  `ActiveOnly`). 286 testes.

## Aprendizados

1. **`sendClientCommand` de 3 argumentos chega no solo sem jogador.** Fora do MP,
   `GlobalObject.sendClientCommand(module, command, args)` passa `null` e o
   `SinglePlayerClient` grava `playerIndex = -1`: o `OnClientCommand` local recebe
   `player = nil`. Quem precisa do jogador no servidor usa a forma de 4 argumentos
   com `getSpecificPlayer(0)`.
2. **Preset de sandbox não vem de mod.** `getSandboxPresets()` só lista `.cfg` da pasta
   do usuário e os 5 vanilla são nomes fixos no Lua do menu.
3. **Remover mod é seguro pelo lado do jogo:** opção de sandbox desconhecida é pulada,
   `ModData` global sem dono é carregado e esquecido, e `persistentOutfitID` com índice
   fora da lista de outfits vira "sem outfit" (`getOutfit` devolve 0), não exceção.
4. **"Só em memória" não basta olhar a tabela.** O forçado do debug vive em memória,
   mas alimenta o `NOM_World`, que alimenta os contadores salvos (`syncNight` no
   ModData global). Teste com o contador de verdade, não com registrador, pegou isso.
5. **Teste de "não chama o zumbi" precisa separar o jogo do mod.** O fake do
   `NightStats` chama `makeInactive` em todo zumbi a cada tick (o `updateActiveState`
   do jogo); contar tudo dava falso positivo. `tests/calls.lua` aceita uma lista do que
   é do jogo.

## Pendências que a próxima sprint herda

- **Rodar o [teste in-game consolidado](../../teste-in-game.md)** e fechar os critérios
  1, 2, 4 e 5 desta sprint e os das 0001–0005 com o `console.txt`.
- Decidir os defaults com as respostas do Balanceamento (principalmente `NightFaster`
  e `SemRostoChance`).
- Se a medição mostrar pico a cada 10 minutos de jogo: a varredura do Eco já anda um
  jogador por tick; o próximo passo é fatiar o raio de um jogador.
- Forçado do debug é por `persistentOutfitID`: gêmeos (mesmo ID) viram juntos.
- Debug só em save descartável: noite e névoa forçadas avançam os contadores salvos.

## Sessões

- 2026-10-04 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — plano e implementação da sprint (sem o jogo)
