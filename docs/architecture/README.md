# Arquitetura

| Doc | Assunto |
|-----|---------|
| [adr-001-variantes-por-moddata.md](adr-001-variantes-por-moddata.md) | Monstros = zumbis existentes marcados (mecanismo substituído pela ADR-006) |
| [adr-002-autoridade-servidor.md](adr-002-autoridade-servidor.md) | Lógica no servidor, cliente só renderiza |
| [adr-003-eco-spawnado.md](adr-003-eco-spawnado.md) | Eco é a exceção: spawnado |
| [adr-004-clima-antes-de-shader.md](adr-004-clima-antes-de-shader.md) | Visual dark via clima, shader é spike |
| [adr-005-quem-simula-aplica.md](adr-005-quem-simula-aplica.md) | O servidor decide, quem simula o zumbi aplica (emenda a ADR-002) |
| [adr-006-variantes-deterministicas.md](adr-006-variantes-deterministicas.md) | Variante = função do ID do outfit e da noite (substitui o mecanismo da ADR-001) |
| [adr-007-sem-rosto-e-atmosfera-local.md](adr-007-sem-rosto-e-atmosfera-local.md) | Sem-rosto: quem vê avisa, o servidor confere, o dono move; som, chão e tela da névoa só locais |

Design de jogo fica em [../gdd/Overview.md](../gdd/Overview.md). Conflito
entre ADR e GDD: o GDD manda no **quê**, o ADR manda no **como**.

## Estrutura do mod

```
mod/
  42/mod.info
  42/media/
    sandbox-options.txt
    lua/shared/NOM_Rules.lua        lógica pura (sem API do jogo), testável
    lua/shared/NOM_Config.lua       sandbox + defaults
    lua/shared/NOM_World.lua        flags night/fog derivadas do clima vanilla
    lua/shared/Translate/<LANG>/    traduções em JSON (B42.20)
    lua/shared/NOM_EcoRules.lua     elegibilidade do corpo e chave de outfit (puro)
    lua/server/NOM_ClimateLook.lua  clima sombrio (OnClimateTick), só no servidor
    lua/server/NOM_Eco.lua          spawn, morte sem cadáver e amanhecer dos Ecos
    lua/client/NOM_EcoClient.lua    apaga o fantasma do Eco removido (só MP)
    lua/shared/NOM_NightRules.lua   degraus de velocidade/sentidos, perfil, caça (puro)
    lua/shared/NOM_NightStats.lua   aplica stats noturnos em lotes (onde o zumbi é simulado)
    lua/server/NOM_Players.lua      jogadores do lado do servidor (solo e dedicado)
    lua/server/NOM_Night.lua        decide a noite, caça e lanterna; avisa os clientes
    lua/client/NOM_NightClient.lua  cliente de MP segue a flag e aplica os stats
    lua/shared/NOM_VariantRules.lua sorteio determinístico da variante, cooldown do grito (puro)
    lua/shared/NOM_VariantAI.lua    Estalador cego e estalando, Corredor visto (onde o zumbi é simulado)
    lua/server/NOM_NightCount.lua   número da noite (ModData global), do Eco e das variantes
    lua/server/NOM_Variants.lua     decide o grito do Corredor (som + chamado da horda)
    lua/client/NOM_VariantsClient.lua  cliente de MP roda o NOM_VariantAI e avisa o servidor
    lua/shared/NOM_SemRostoRules.lua   destino, cooldown, validação e volume do rádio (puro)
    lua/shared/NOM_AtmosphereRules.lua fade e valores da vinheta (puro)
    lua/shared/NOM_FogState.lua     flag e período de névoa do lado de quem vê
    lua/shared/NOM_SemRosto.lua     quem vê o Sem-rosto e pra onde ele pode ir (solo e cliente)
    lua/server/NOM_Fog.lua          período de névoa, flag pros clientes, decide o sumiço do Sem-rosto
    lua/client/NOM_FogClient.lua    cliente de MP: flag de névoa, avisa que viu, dono move
    lua/client/NOM_FogSound.lua     drone, metal e rádio chiando (só local)
    lua/client/NOM_FogVignette.lua  vinheta da névoa via SearchMode (só local)
    lua/client/NOM_FogOverlays.lua  sangue/ferrugem no chão via IsoMarkers (só local, sem save)
    lua/shared/NOM_DebugRules.lua   confere os comandos de debug e formata a linha de status (puro)
    lua/client/NOM_Debug.lua        comandos de console pro teste in-game (só com -debug)
    lua/server/NOM_DebugServer.lua  aplica os comandos de debug (só com -debug; permissão no dedicado)
    clothing/clothing.xml           outfit NOM_Eco (itens vanilla por GUID)
    scripts/NOM_sounds.txt          sons do mod (estalo, grito, drone, metal, rádio)
    sound/*.ogg                     gerados por scripts/gen_sounds.py (CREDITS.md)
  common/                           exigida pelo B42
tests/                              asserts de lua puro (./run-tests.sh, luajit)
```

Fluxo: `World` deriva o estado do clima vanilla → `ClimateLook` escurece o
clima, que o jogo sincroniza → `NightCount` conta a noite, `Eco` spawna, `Night`
chama os zumbis e avisa os clientes (flag + número da noite) → quem simula o
zumbi (o próprio processo no solo, o cliente dono no MP) aplica os stats e o
perfil da variante em lotes por tick ([ADR-005](adr-005-quem-simula-aplica.md),
[ADR-006](adr-006-variantes-deterministicas.md)) e roda o `VariantAI`; o
servidor decide o grito do Corredor (`Variants`). Na névoa, `Fog` conta o
período e avisa quem vê (`FogState`); o cliente vê o Sem-rosto (`SemRosto`), o
servidor confere e o dono do zumbi move ([ADR-007](adr-007-sem-rosto-e-atmosfera-local.md));
som, vinheta e overlays são locais (`FogSound`, `FogVignette`, `FogOverlays`).

## Robustez

- Nada da variante é guardado: ela é recalculada do `persistentOutfitID` e da noite ([ADR-006](adr-006-variantes-deterministicas.md)); ao amanhecer o perfil volta a "dia".
- Mod removido do save: nada quebra. `ModData` global órfão é carregado e nunca lido,
  opções de sandbox desconhecidas são puladas, Eco virtual com índice de outfit fora da
  lista volta sem roupa (`getOutfit` devolve 0). Clima, stats, overlays e vinheta não vão
  pro save. Detalhe e bytecode em [pz-api-notes §8](pz-api-notes.md#8-remover-o-mod-de-um-save-sprint-0006).
- Loop de comportamento processa zumbis em lotes por tick, não todos de uma vez.
- Teto de Ecos por jogador evita travar servidor em vala comum.
- Comandos de debug (`NOM_Debug`) não existem nem agem fora do `-debug`; no dedicado
  exigem a permissão de debug do jogo. O forçado em si fica em memória, **mas a noite
  e a névoa forçadas avançam os contadores salvos de noites e de névoas** (ModData
  global), o que muda o sorteio das variantes e a noite dos Ecos daquele save: usar
  um save descartável.

## Orçamento por sistema

Trabalho com muitos zumbis, jogadores e corpos (sprint 0006). "Chamada" = ida ao Java
num zumbi; `list:get(i)` pra percorrer a lista não conta. Cada linha tem teste que
falha se o caminho quente passar a tocar zumbi irrelevante ou a crescer com o mapa.

| Sistema | Quando roda | Trabalho | Teste |
|---|---|---|---|
| `NightStats.tick` | todo tick à noite e na passada do amanhecer | ≤ `BATCH` (20) zumbis + 5 leituras de sandbox por tick | `stats_batch_bounded_with_200` |
| `NightStats.tick` de dia | depois de uma passada sem nada a devolver | **zero** (dorme até a próxima flag ou a próxima hora de jogo, quando faz uma passada de conferência) | `stats_day_idle_only_after_clean_pass`, `stats_day_idle_wakes_at_night`, `stats_day_idle_wakes_every_hour` |
| `VariantAI` (`OnZombieUpdate`) | todo frame, todo zumbi | zumbi comum: 2 consultas de tabela Lua, zero chamada | `ai_common_zombie_no_java_calls` |
| Estalo do Estalador | 1/min de jogo à noite | zero chamada em zumbi que não é Estalador | `ai_click_touches_only_estaladores` |
| Varredura do Sem-rosto | a cada 10 ticks, só na névoa | 1 chamada (o ID) por zumbi comum | `semrosto_scan_one_call_per_common_zombie` |
| Varredura do Eco | começa a cada 10 min de jogo, à noite; **um jogador por tick** | por tick: até `(2·EcoRadius+1)²` squares (os já lidos pra outro jogador da mesma varredura, 0) e 1 chamada por zumbi | `eco_scan_one_player_per_tick`, `eco_scan_budget_independent_of_horde`, `eco_overlapping_players_scan_each_square_once` |
| Som, vinheta, overlays | a cada 10 ticks, no cliente | por jogador local; overlays ≤ 40 marcadores | — |
| Clima, caça, lanterna | 1/min de jogo, servidor | constante / por jogador | — |
| Avisos de cliente (`corredorSaw`, `semRostoSeen`) | por pedido, limitado por jogador (2 s / 250 ms) | uma volta na lista de zumbis (`getOnlineID`) | `variants_rate_limit_per_player` |

Ponto de atenção: a varredura do Eco, com `EcoRadius` 40, ainda lê até 6 561
squares num tick (o raio de um jogador), a cada 10 minutos de jogo. É o maior pico do
mod. Medir no jogo ([roteiro](../teste-in-game.md#parte-3--medições-15-min)); se pesar,
fatiar também o raio de um jogador.

## Testes

- `NOM_Rules.lua` (máquina de estado, sorteio, elegibilidade do Eco) roda no
  `lua` puro do terminal: `./run-tests.sh`.
- In-game: checklist da sprint no modo `-debug` (forçar hora, névoa, spawn).
- MP: servidor local + dois clientes.
