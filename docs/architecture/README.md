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
| [adr-008-noite-pela-luz-global.md](adr-008-noite-pela-luz-global.md) | A noite escurece pela cor e força da luz global, os canais que o render usa (emenda a ADR-004) |
| [adr-009-nevoa-evento-do-mod.md](adr-009-nevoa-evento-do-mod.md) | A névoa é um evento do mod (sirene, hora aleatória, 2–6 h) e o mod é dono do canal de névoa |
| [adr-010-nevoa-vermelha.md](adr-010-nevoa-vermelha.md) | Névoa vermelha: decidida na sirene pelo número do período, salva, espalhada no comando `fog`; todo zumbi variante; luz e cor da névoa vermelhas |
| [adr-011-carpideira.md](adr-011-carpideira.md) | Carpideira: o dono a deixa parada (useless), quem vê avisa (perto, lanterna), o servidor ouve o barulho (`OnWorldSound`), decide o grito e guarda quem gritou no `ModData` |
| [adr-012-visual-das-variantes.md](adr-012-visual-das-variantes.md) | Visual das variantes: pele e peça na cópia local de quem renderiza, pela passada do `NightStats`, sem mexer no outfit; tira no fim da névoa, no reaproveitamento e na morte; o Eco muda só no outfit. Emenda da 0016: a roupa vanilla some na variante e volta (loot exato na morte) |
| [adr-013-efeitos-de-tela.md](adr-013-efeitos-de-tela.md) | Efeitos de tela: overlay Lua num elemento de 1 px atrás da UI (grão, vinheta, chiado, pulso), opção do jogador; shader original opcional num segundo mod, alimentado pelo `SearchMode` |
| [adr-015-outro-mundo-sangrento.md](adr-015-outro-mundo-sangrento.md) | Outro Mundo sangrento: chão por `IsoMarker` com camadas, paredes desenhadas no quadro (`RenderGhostTileColor`), só parede limpa, de frente e à vista; regra pura por square e período; densidade do jogador |

Design de jogo fica em [../gdd/Overview.md](../gdd/Overview.md). Conflito
entre ADR e GDD: o GDD manda no **quê**, o ADR manda no **como**.

## Estrutura do mod

```
mod/
  42/mod.info                       poster, ícone, versionMin=42.20 (pz-api-notes §9)
  42/poster.png, 42/icon.png        gerados por scripts/gen_images.py
  42/media/
    sandbox-options.txt
    lua/shared/NOM_Rules.lua        lógica pura (sem API do jogo), testável
    lua/shared/NOM_Config.lua       sandbox + defaults
    lua/shared/NOM_World.lua        flags night (relógio) e fog (evento do mod, setFog)
    lua/shared/Translate/<LANG>/    traduções em JSON (B42.20): Sandbox.json e Mod.json (nome/descrição do mod)
    lua/shared/NOM_EcoRules.lua     elegibilidade do corpo e chave de outfit (puro)
    lua/server/NOM_ClimateLook.lua  clima sombrio (OnClimateTick), só no servidor; dono do canal de névoa (ADR-009); log canal a canal em -debug (ADR-008)
    lua/shared/NOM_FogEventRules.lua   intervalo, duração e contagem da sirene do evento de névoa (puro)
    lua/server/NOM_FogEvent.lua     agenda o evento de névoa (ModData global), conta a sirene em tempo real, liga a flag
    lua/shared/NOM_Siren.lua        toca a sirene (normal ou vermelha) no jogador local (solo e cliente)
    lua/server/NOM_Eco.lua          spawn, morte sem cadáver e amanhecer dos Ecos
    lua/client/NOM_EcoClient.lua    apaga o fantasma do Eco removido (só MP)
    lua/shared/NOM_NightRules.lua   degraus de velocidade/sentidos, perfil, caça (puro)
    lua/shared/NOM_NightStats.lua   aplica stats noturnos e perfis das variantes da névoa em lotes (onde o zumbi é simulado)
    lua/server/NOM_Players.lua      jogadores do lado do servidor (solo e dedicado)
    lua/server/NOM_Night.lua        decide a noite, caça e lanterna; avisa os clientes
    lua/client/NOM_NightClient.lua  cliente de MP segue a flag e aplica os stats
    lua/shared/NOM_VariantRules.lua sorteio único das variantes por período de névoa, névoa vermelha e a divisão dela, cooldown do grito (puro)
    lua/shared/NOM_VariantAI.lua    Estalador cego e estalando, Corredor visto, Carpideira parada (onde o zumbi é simulado)
    lua/shared/NOM_CarpideiraRules.lua  o que acorda a Carpideira e quem já gritou no período (puro)
    lua/shared/NOM_Carpideira.lua   Carpideira parada, soluço local, aviso de quem a acorda, efeitos do grito (solo e cliente)
    lua/server/NOM_NightCount.lua   número e hora de início da noite (ModData global), do Eco
    lua/server/NOM_Variants.lua     decide os gritos do Corredor e da Carpideira (som + chamado da horda), ouve o barulho que a acorda
    lua/client/NOM_VariantsClient.lua  cliente de MP roda o NOM_VariantAI e o NOM_Carpideira, avisa o servidor e aplica o grito
    lua/shared/NOM_SemRostoRules.lua   destino, cooldown, validação e volume do rádio (puro)
    lua/shared/NOM_AtmosphereRules.lua fade e valores da vinheta (puro)
    lua/shared/NOM_FogState.lua     flag e período de névoa do lado de quem vê
    lua/shared/NOM_SemRosto.lua     quem vê o Sem-rosto e pra onde ele pode ir (solo e cliente)
    lua/server/NOM_Fog.lua          flag e período de névoa pros clientes, decide o sumiço do Sem-rosto
    lua/client/NOM_FogClient.lua    cliente de MP: flag de névoa, sirene, avisa que viu, dono move
    lua/client/NOM_FogSound.lua     drone, metal e rádio chiando (só local)
    lua/client/NOM_FogVignette.lua  vinheta da névoa via SearchMode; com o mod do shader, o canal Lua → shader (só local)
    lua/shared/NOM_DressingRules.lua   o que cada square ganha na névoa: camadas de chão, sprite de parede N/W, poças e rastros (puro, sprint 0015)
    lua/client/NOM_FogOverlays.lua  Outro Mundo sangrento: chão por IsoMarker, paredes desenhadas no quadro (só local, sem save; ADR-015)
    lua/shared/NOM_ScreenFxRules.lua   alfas das camadas da tela, fade, pulso do grito, canal do shader (puro)
    lua/client/NOM_ScreenFxOptions.lua opções de cliente dos efeitos de tela e da densidade do Outro Mundo (PZAPI.ModOptions)
    lua/client/NOM_ScreenFx.lua     overlay de tela na névoa: elemento de 1 px atrás da UI (só local)
    lua/client/NOM_VariantLook.lua  pele e peça da variante na cópia local, enquanto a névoa dura (gancho do NightStats; não no dedicado)
    lua/shared/NOM_DebugRules.lua   confere os comandos de debug e formata a linha de status (puro)
    lua/client/NOM_Debug.lua        comandos de console pro teste in-game (só com -debug)
    lua/server/NOM_DebugServer.lua  aplica os comandos de debug (só com -debug; permissão no dedicado)
    clothing/clothing.xml           outfit NOM_Eco (itens do mod por GUID: cinza e véu de fumaça)
    clothing/clothingItems/NOM_*.xml   itens de roupa do visual: modelo vanilla pelo nome, textura do mod
    fileGuidTable.xml               GUIDs dos itens de roupa do mod (o jogo junta com a vanilla)
    scripts/NOM_clothing.txt        itens de script do visual (Base.NOM_*, sem ChanceToFall)
    textures/Body/NOM_*.png, textures/NOM/*.png, textures/NOM/ScreenFx/*.png   geradas por scripts/gen_textures.py (CREDITS.md)
    scripts/NOM_sounds.txt          sons do mod (estalo, gritos, soluço, drone, metal, rádio, sirene, sirene vermelha)
    sound/*.ogg                     gerados por scripts/gen_sounds.py (CREDITS.md)
  common/                           exigida pelo B42
mod2/                               mod opcional NevoaEOutroMundo_Shader (ADR-013), no mesmo item do Workshop
  42/mod.info                       require=NevoaEOutroMundo
  42/media/shaders/screen.frag      pós-processo de tela original (interface do WeatherShader)
  42/media/lua/shared/NOM_ShaderFlag.lua   NOM_ShaderMod = true (o mod principal passa a usar o canal)
  common/
tests/                              asserts de lua puro (./run-tests.sh, luajit), contraste das texturas (test_look_contrast.py) e teste do build
scripts/                            gen_sounds.py, gen_images.py, gen_textures.py, preview_textures.py (folha de contato das texturas, sprint 0014), build-workshop.sh (pasta de upload, só o mod/ commitado)
docs/workshop/                      descrições do Workshop (BBCode), preview.png e workshop-id.txt (ID do item, depois do 1º envio)
```

Fluxo: `World` deriva a noite do relógio; `FogEvent` agenda a névoa, toca a sirene e
liga a flag de névoa 30 s reais depois ([ADR-009](adr-009-nevoa-evento-do-mod.md)),
decidindo na sirene se ela é vermelha ([ADR-010](adr-010-nevoa-vermelha.md)) →
`ClimateLook` escurece o clima e escreve a névoa do mod (0 fora do evento), que o jogo sincroniza → `NightCount` conta a noite (e guarda quando ela
abriu), `Eco` spawna dos corpos de antes dela, `Night` chama os zumbis e avisa os
clientes → na névoa, `Fog` conta o período e avisa (`FogState`) → quem simula o
zumbi (o próprio processo no solo, o cliente dono no MP) aplica os stats da noite
e, na névoa, o perfil da variante sorteada pelo período, em lotes por tick
([ADR-005](adr-005-quem-simula-aplica.md),
[ADR-006](adr-006-variantes-deterministicas.md)) e roda o `VariantAI`; o
servidor decide os gritos do Corredor e da Carpideira (`Variants`;
a Carpideira, [ADR-011](adr-011-carpideira.md)). O cliente vê o Sem-rosto (`SemRosto`), o
servidor confere e o dono do zumbi move ([ADR-007](adr-007-sem-rosto-e-atmosfera-local.md));
som, vinheta, overlays e efeitos de tela são locais (`FogSound`, `FogVignette`, `FogOverlays`,
`ScreenFx`; o shader opcional, [ADR-013](adr-013-efeitos-de-tela.md)).

## Robustez

- Nada da variante é guardado: ela é recalculada do `persistentOutfitID` e da noite ([ADR-006](adr-006-variantes-deterministicas.md)); ao amanhecer o perfil volta a "dia".
- O visual da variante (pele e peça, [ADR-012](adr-012-visual-das-variantes.md)) é só da cópia local: não viaja no pacote do zumbi, não vai pro popman e sai antes do corpo nascer (sem loot nem pele no save). O Eco veste itens do mod pelo outfit, mas o corpo dele é removido e o inventário limpo ([ADR-003](adr-003-eco-spawnado.md)); um corpo de Eco que escapasse ficaria com `Base.NOM_EcoCinza`/`NOM_EcoVeu` no save.
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
- Evento de névoa: próximo evento, fim e período no `ModData` global (`fog.next`,
  `fog.endAt`, `fog.night`); a contagem da sirene não é salva (recarregar toca de novo).
  Sem o mod, o jogo volta a fazer a névoa dele: o override desligado e a camada modded
  não vão pro save.

## Orçamento por sistema

Trabalho com muitos zumbis, jogadores e corpos (sprint 0006). "Chamada" = ida ao Java
num zumbi; `list:get(i)` pra percorrer a lista não conta. Cada linha tem teste que
falha se o caminho quente passar a tocar zumbi irrelevante ou a crescer com o mapa.

| Sistema | Quando roda | Trabalho | Teste |
|---|---|---|---|
| `NightStats.tick` | todo tick à noite e na passada do amanhecer | ≤ `BATCH` (20) zumbis + 5 leituras de sandbox por tick; +2 chamadas por zumbi da passada (`unstick` do useless herdado, sprint 0011) | `stats_batch_bounded_with_200` |
| `NightStats.tick` de dia | depois de uma passada sem nada a devolver | **zero** (dorme até a próxima flag ou a próxima hora de jogo, quando faz uma passada de conferência) | `stats_day_idle_only_after_clean_pass`, `stats_day_idle_wakes_at_night`, `stats_day_idle_wakes_every_hour` |
| `VariantAI` (`OnZombieUpdate`) | todo frame, todo zumbi | zumbi comum: 3 consultas de tabela Lua, zero chamada | `ai_common_zombie_no_java_calls` |
| Varredura da Carpideira (sprint 0011) | a cada 10 ticks, na névoa, no solo e em cada cliente | zero chamada no zumbi que não é Carpideira; ~8 por Carpideira calma com um jogador local (+3 por jogador a mais, +1 com lanterna perto); soluço só a até 15 tiles de um jogador local; um aviso por varredura | `carpideira_scan_budget` |
| Barulho que acorda a Carpideira | por `addSound` com raio ≥ 30 de jogador, na névoa, servidor | uma volta na lista, 1 chamada por zumbi (o ID); barulho baixo ou fora da névoa, zero | `carpideira_noise_scan_one_call_per_common_zombie` |
| Estalo do Estalador | 1/min de jogo na névoa | zero chamada em zumbi que não é Estalador | `ai_click_touches_only_estaladores` |
| Varredura do Sem-rosto | a cada 10 ticks, só na névoa | 1 chamada (o ID) por zumbi comum | `semrosto_scan_one_call_per_common_zombie` |
| Varredura do Eco | começa a cada 10 min de jogo, à noite; **um jogador por tick** | por tick: até `(2·EcoRadius+1)²` squares (os já lidos pra outro jogador da mesma varredura, 0) e 1 chamada por zumbi | `eco_scan_one_player_per_tick`, `eco_scan_budget_independent_of_horde`, `eco_overlapping_players_scan_each_square_once` |
| Som, vinheta | a cada 10 ticks, no cliente | por jogador local | — |
| **Outro Mundo sangrento** (sprint 0015, [ADR-015](adr-015-outro-mundo-sangrento.md)) | atualização a cada 10 ticks na névoa; desenho das paredes todo quadro; solo e cada cliente | por quadro: **1 chamada por parede desenhada** (≤ 120), zero fora da névoa; marcadores de chão (≤ 600, ≤ 4 texturas) sem Lua por quadro. Por atualização: varredura de 80 squares (a regra pura antes do Java), ≤ ~1040 chamadas enquanto enche, ~180 parado (luz em rodízio de 30, 12 paredes conferidas, visão das paredes); 1ª vez +404 `getTexture` | `overlays_budget`, `overlays_capped` |
| Clima, caça, lanterna | 1/min de jogo, servidor | constante / por jogador | — |
| Evento de névoa | agenda 1/min de jogo; contagem da sirene todo tick, só nos 30 s dela | constante, zero chamada em zumbi | — |
| Avisos de cliente (`corredorSaw`, `semRostoSeen`, `carpideiraWoke`) | por pedido, limitado por jogador (2 s / 250 ms / 1 s; o cliente espaça os `semRostoSeen` em 300 ms, e o que ficou de fora vai na varredura seguinte) | uma volta na lista de zumbis (`getOnlineID`) | `variants_rate_limit_per_player`, `semrosto_second_report_waits_rate_not_cooldown`, `carpideira_rate_limit_per_player` |
| **Névoa vermelha** (sprint 0010; 1/4 de cada desde a 0011): ninguém é comum | a névoa toda | com N zumbis carregados localmente: **por frame** (`VariantAI`) Estalador 4 chamadas, Corredor 3, Sem-rosto 0, Carpideira 2 (calma ou furiosa; 3 a mais no primeiro frame) → ~2,25·N; **por varredura do Sem-rosto** (a cada 10 ticks) Sem-rosto 7, os outros 1 → ~2,5·N; **por varredura da Carpideira** (a cada 10 ticks) ~8 por Carpideira calma → ~2·N; as duas varreduras somam ~0,45·N por frame; **estalo** 1/min, ≤ 3 por Estalador; `NightStats` reaplica todo mundo uma vez, nos lotes de 20 por tick de sempre. Com 300 zumbis, ~810 chamadas por frame. Contra a névoa normal (15% variantes): ~0,4·N por frame | `ai_red_fog_budget_per_frame`, `semrosto_scan_budget_red_fog`, `carpideira_scan_budget`, `stats_batch_bounded_with_200` |
| **Visual das variantes** (sprint 0012) | na passada do `NightStats` (lotes de 20 por tick), solo e cada cliente | sem troca: **zero** chamada (uma consulta de tabela Lua por zumbi da passada); pôr: ≤ 11 + 3·N chamadas por zumbi (N = itens vanilla dele, que somem na variante, sprint 0016), uma vez por névoa; tirar: ≤ 5 + 2·N, também na passada em lotes do fim da névoa (0016; antes, todos na borda); na morte, + ~4 + 3 por vestido (o loot refeito pelo `WornItems`). Cada troca refaz a textura do modelo daquele zumbi (`resetModelNextFrame`): na vermelha, todo zumbi carregado entra no 1º giro dos lotes (300 zumbis ≈ 15 ticks; com N ≈ 6, ≤ ~580 chamadas por tick) e sai nos lotes do mesmo jeito | `look_budget`, `look_common_zombie_untouched`, `nude_fog_end_spread_in_batches` |
| **Efeitos de tela** (sprint 0013, [ADR-013](adr-013-efeitos-de-tela.md)) | todo quadro (render da UI), solo e cada cliente; distância do Sem-rosto a cada 10 ticks | fora da névoa: **1** chamada (a hora) e nada desenhado; na névoa: ≤ 4 desenhos (grão em ladrilhos = 1 chamada, ~40 quads no Java a 1080p; vinheta, linhas, pulso) e ≤ 12 chamadas; com o mod do shader, +11 chamadas por tick enquanto o canal está tomado | `screenfx_nothing_outside_fog_cheap`, `screenfx_fog_draws_grain_and_vignette` |

Ponto de atenção da névoa vermelha: o caminho por frame cresce de ~0,4·N pra ~2,7·N
chamadas (cada uma barata: getters de campo). Não otimizado de propósito; medir com a
horda no jogo ([roteiro, parte 3](../teste-in-game.md#parte-3--medições-15-min)).

Ponto de atenção do visual (sprint 0012): ~~o fim da névoa refaz o modelo de todo zumbi
com visual no mesmo tick~~ desde a sprint 0016 o fim devolve 20 zumbis por tick, como o
começo. A conta de chamadas é pequena; o custo de verdade é o do jogo recompor a textura de
cada modelo. Medir o engasgo no fim de
uma névoa vermelha com horda ([roteiro da sprint](../sprints/sprint-0012-visual-variantes/README.md#roteiro-in-game)).

Ponto de atenção: a varredura do Eco, com `EcoRadius` 40, ainda lê até 6 561
squares num tick (o raio de um jogador), a cada 10 minutos de jogo. É o maior pico do
mod. Medir no jogo ([roteiro](../teste-in-game.md#parte-3--medições-15-min)); se pesar,
fatiar também o raio de um jogador.

## Testes

- `NOM_Rules.lua` (máquina de estado, sorteio, elegibilidade do Eco) roda no
  `lua` puro do terminal: `./run-tests.sh`.
- In-game: checklist da sprint no modo `-debug` (forçar hora, névoa, spawn).
- MP: servidor local + dois clientes.
- Traduções e créditos: `test_translations.lua`, `test_credits.lua` (chave usada sem
  tradução, EN fora do ASCII, asset sem origem no `CREDITS.md`, linha do `mod.info`
  lida como outra chave).
- Build do Workshop: `tests/test_build_workshop.sh`, com `HOME` temporário.
