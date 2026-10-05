# Sprint 0008 — Ajustes do primeiro teste in-game

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0008-ajustes-teste` |
| Plano | [plan.md](plan.md) |
| GDD | [monsters.md](../../gdd/monsters.md), [night.md](../../gdd/night.md), [atmosphere.md](../../gdd/atmosphere.md#clima), [sandbox.md](../../gdd/sandbox.md) |
| ADR | [ADR-008](../../architecture/adr-008-noite-pela-luz-global.md) (nova), [ADR-006](../../architecture/adr-006-variantes-deterministicas.md) (emendada) |

## Objetivo

Depois da primeira sessão no jogo: a noite fica claramente mais escura e fria que a
vanilla, os monstros (menos o Eco) vivem só na névoa, e o Eco não nasce do zumbi que
acabou de morrer.

Pedidos do Johan (05/10/2026, depois do teste):

1. ~~"a probabilidade dos bixos a noite e na nevoa devem ser grandes ... algo em torno
   de 15% em cada tipo de bixo"~~ — **trocado no meio da sprint** pela decisão:
   todos os monstros, exceto os Ecos, só na névoa; chances 5/2/3/5 (Estalador,
   Corredor, Carpideira da sprint 0010, Sem-rosto).
2. "o echo só pode nascer no próximo entardecer. se eu matar o zombie e logo em
   seguida ele nascer, é ruim"
3. "a noite parece clara igual dia", e nenhum efeito visível, com `[NOM] nightRamp=1.00`
   no console.

## Critérios de aceite

- [x] Estalador, Corredor e Sem-rosto só na névoa, de dia ou de noite, com padrão
      5/2/5 num sorteio só por período de névoa (faixas contíguas, total = soma, pronto
      pra uma 4ª variante no fim) — `variant_rules_default_chances`,
      `variant_rules_kinds_exclusive_and_add_up`, `variant_rules_toggle_keeps_other_ranges`,
      `config_sandbox_defaults_match_lua` (menu = Lua).
- [x] Perfis e comportamentos acompanham a névoa: Corredor corre e grita de dia na
      névoa; Estalador cego e estalando só na névoa; noite sem névoa não tem variante;
      noite com névoa põe a variante por cima dos stats da noite; a névoa que baixa
      devolve o zumbi (à noite, aos stats da noite) — `stats_corredor_sprints_in_fog_by_day_and_returns`,
      `stats_night_without_fog_has_no_variant`, `stats_estalador_in_fog_by_day`,
      `stats_estalador_on_top_of_night`, `stats_day_idle_wakes_with_fog`,
      `ai_night_without_fog_does_nothing`, `variants_scream_by_day_in_fog`,
      `variants_server_rejects_non_corredor_and_day` (sem névoa não grita),
      `night_and_fog_together` (solo, tudo junto). Falta ver no jogo: roteiro passos 4–5.
- [x] Corpo de quem morreu durante a noite atual não solta Eco nesta noite; solta na
      próxima. Corpo de quem morreu antes do anoitecer solta nesta noite —
      `eco_killed_tonight_waits_next_night`, `eco_died_before_dusk_releases_tonight`,
      `eco_forced_night_counts_from_forcing`, `eco_restart_keeps_night_start`,
      `rules_sync_night_*`, `rules_died_before_night`; hora da morte do jogo por
      bytecode (`IsoDeadBody` `<init>` 1333–1341, `save` 444–449, `load` 593–598). Falta
      ver no jogo: roteiro passo 3.
- [ ] A noite escurece pelos canais que o jogo de fato usa pra luz, com peso visível:
      mais escura e mais fria que a vanilla com `DarkIntensity` 1, muito escura com 2 —
      **por código e bytecode:** canais escolhidos pelo render (pz-api-notes §10,
      ADR-008). Contra a noite vanilla **real** (`ClimateMain.lua`: sem lua 0.25, lua
      cheia 0.33, alfa 0.8), a luz do céu cai com 1: sem lua R −46% G −42% B −39%, lua
      cheia R −46% G −43% B −40%; com 2: sem lua −87/−80/−73%, lua cheia −89/−83/−77%
      (`rules_night_darker_and_colder_than_vanilla` trava ≥ 35% e ≥ 60% em todo canal
      nas duas luas; `rules_sky_mod_matches_render`; `look_does_not_compound_between_climate_ticks`
      com o alfa). **Falta o jogo:** roteiro passos 1–2.
- [ ] Névoa continua forte (dessaturação de dia, névoa mais densa, mundo mais escuro e
      sépia) — contra as três cores vanilla de névoa (alfa 0.8), a luz do céu cai com
      `DarkIntensity` 1: `colFogNew` −40/−42/−46%, `colFogLegacy` −34/−37/−41%, `colFog`
      −29/−33/−38% (R/G/B); com 2, −49 a −80%; noite + névoa −39 a −46%
      (`rules_fog_darker_than_vanilla_on_every_path`, `rules_night_and_fog_together_still_dark`).
      Falta ver: roteiro passo 6.
- [x] Log só de `-debug` na borda da rampa e uma vez por hora de jogo à noite, com
      vanilla, escrito e `getFinalValue()` de cada canal (e o multiplicador da luz) —
      `look_debug_log_on_edges_and_hourly`, `look_debug_log_silent_without_debug`.
- [x] Docs: GDD (monsters, night, atmosphere, sandbox com presets, world-states,
      Overview com as decisões de 05/10), pz-api-notes §10, ADR-008 nova e indexada,
      ADR-006/004/003/007 emendadas, teste in-game, README, Workshop (EN/PT-BR).
- [x] Texto do menu (EN e PT-BR): Estalador e Corredor "na névoa, de dia ou de noite",
      chances "a cada névoa" e avisando que acima de 100 somados quem vem depois fica
      espremido, Eco "só de quem morreu antes do anoitecer"; nenhum `%` sozinho —
      `translations_variants_say_fog_and_eco_says_dusk`, `translations_no_lone_percent`.

`./run-tests.sh`: `total=325 passou=325 falhou=0` (Lua) e `build total=22 passou=22 falhou=0`.

## Roteiro in-game

Jogo em `-debug`, **save descartável** (noite e névoa forçadas avançam os contadores
salvos). Console em `~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt`
(Flatpak). Sandbox vanilla "Escuridão à noite" em **Normal** (o do save do teste).
O Lua novo só carrega ao recarregar o save.

> **Vinheta, manchas no chão, drone e rádio só aparecem com névoa forte**
> (névoa ≥ `FogThreshold`, 0.5), nunca só de noite. Pra testar sem esperar o clima:
> `NOM_Debug.fog(0.8)` no console Lua, ou o painel Debug → Climate (névoa alta).
> `NOM_Debug.fog()` devolve pro clima.

1. **Noite escura (DarkIntensity 1).** Debug → Time: 20:30, deixar correr até depois
   das 23:00. **Esperado no console:** `[NOM] nightRamp=1.00 fogRamp=0.00` seguido de
   um bloco `[NOM] clima …`, e um bloco novo a cada hora de jogo. De madrugada:
   - `[NOM] clima ambient vanilla=0.00 escrito=0.00 final=0.00` — o jogo já põe 0; é
     o esperado (o clareado vem do piso do sandbox, que o clima não muda).
   - `[NOM] clima tint vanilla=0.33,0.33,0.33,0.80 escrito=0.15,0.17,0.18,0.88
     final=0.15,0.17,0.18,0.88 luz=0.25,0.26,0.28 peso=0.55` com lua cheia; sem lua,
     `vanilla=0.25,0.25,0.25,0.80 escrito=0.11,0.13,0.15,0.88 luz=0.22,0.23,0.25`. O
     vanilla fica entre 0.25 e 0.33 com alfa 0.80 (a lua mistura as duas); o que
     importa é **final = escrito** e `luz` ≈ 0.22–0.28 (a vanilla daria 0.40–0.46).
   - **Se `final` ≠ `escrito`:** outra camada está por cima (admin do painel de clima
     ligado, chuva, outro mod). Anotar a linha.
   - **Na tela:** visivelmente mais escuro e azulado que antes; lanterna e postes
     iguais. Comparar: `DarkEnabled` desligado no sandbox (outro save) na mesma hora.
   - **Prova do canal, sem o mod:** Debug → Climate (painel de admin), ligar "Light"
     exterior e levar A pra 255 e R/G/B pra 0: a tela tem que escurecer muito. Se não
     escurecer, o render não usa esse canal como o bytecode diz (avisar).
2. **DarkIntensity 2** (outro save, ou mudar e recarregar): `escrito=0.00,0.03,0.06,0.95`,
   `luz=0.05,0.08,0.11`; muito escuro, só lanterna mostra o caminho. Anotar se ainda dá pra jogar com 1.
3. **Eco do morto antigo.** De dia: matar 3 zumbis perto de casa e deixar os corpos.
   Anoitecer (20:30): em até 10 min de jogo, `[NOM] eco spawn=3`. Então matar 1 zumbi
   comum perto. **Esperado** na varredura seguinte: `[NOM] eco esperando a proxima
   noite=1` e nenhum Eco dele. Amanhecer (07:00) e anoitecer de novo: `[NOM] eco spawn=1`
   dele.
4. **Monstros só na névoa, de dia.** Debug → Time: 12:00. `NOM_Debug.fog(0.8)`
   (`[NOM] nevoa fog=true periodo=N`). Do lado de um zumbi, `NOM_Debug.variant("estalador")`:
   `NOM_Debug.status()` com `estaladores=1`; agachado do lado, ele não ataca; estalo a
   cada ~2 min. Outro zumbi, `NOM_Debug.variant("corredor")`: ao te ver corre e grita,
   `[NOM] variantes grito x=… y=… raio=40`. `NOM_Debug.fog()` e esperar 1 min: os dois
   comuns, `estaladores=0`.
5. **Noite sem névoa não tem monstro.** 23:00, sem névoa: `NOM_Debug.variant("estalador")`
   não tem efeito (`estaladores=0`); Ecos e noite agressiva seguem. Com
   `NOM_Debug.fog(0.8)`: vira Estalador e corre como os da noite.
6. **Névoa forte de dia:** com `NOM_Debug.fog(0.8)` ao meio-dia, a tela fica
   dessaturada, sépia e **mais escura que a névoa vanilla**, com névoa densa, vinheta,
   manchas, drone. Bloco `[NOM] clima` na borda (`fogRamp=1.00`):
   `desaturation … escrito≈0.6+`, `ambient` menor que o vanilla, e o tint:
   - **Névoa natural forte** (o jogo também puxa a luz pra cor de névoa dele, alfa
     0.80): `vanilla` perto de `0.50,0.50,0.55,0.80` (o mais comum, `colFogNew`),
     `0.30,…` ou `0.20,…`; `escrito≈0.28,0.27,0.27,0.89` com o primeiro; `luz` sempre
     **menor** que a do vanilla (≈ 0.36 contra 0.60). Se `luz` subir com a névoa, avisar.
   - **Só o `NOM_Debug.fog`** (a névoa vanilla continua fraca): o `vanilla` é a luz do
     dia, não a de névoa; conferir só `final = escrito` e `luz` menor que antes.
   - Noite + névoa (23:00 com `NOM_Debug.fog(0.8)`): `luz` ≈ 0.24–0.27, como a noite
     sozinha.

## Checkpoints

- **04/10/2026** — Sprint aberta a partir do primeiro teste no jogo. Pesquisa no
  bytecode: quem lê cada canal do clima no render (`PlayerRenderSettings`,
  `GameTime.getSkyLightLevel`, `screen.frag`), piso do `NightDarkness`, hora da morte
  do `IsoDeadBody` salva no corpo. Plano escrito.
- **04/10/2026** — Chances 15/15/15 implementadas (pedido 1 original) e regra pura do
  início da noite.
- **04/10/2026** — Johan mudou o pedido 1: todo monstro, menos o Eco, só na névoa,
  5/2/5, um sorteio por período de névoa. Implementado no lugar dos 15%.
- **04/10/2026** — Eco só de quem morreu antes do anoitecer; noite pela cor e alfa da
  luz global; log canal a canal. Docs, ADR-008. Em teste.
- **04/10/2026** — Review (sem Critical): a noite vanilla real é a do
  `ClimateMain.lua` (alfa 0.8, `mod` 0.40–0.46), não a do construtor; o look antigo
  quase não escurecia contra ela. Retunado e medido nas duas luas. Tooltips das
  variantes falando da névoa e do Eco falando do anoitecer.
- **04/10/2026** — Verificação: o tint da névoa tinha o mesmo erro (as três cores
  vanilla de névoa têm alfa 0.8; o tint antigo clareava até 32%). Retunado e medido
  nos três caminhos e junto com a noite.

## Aprendizados

1. **A noite vanilla não é a do construtor do `ClimateManager`.** O
   `server/Climate/ClimateMain.lua` reescreve as cores no `OnClimateManagerInit`
   (sem lua 0.25, lua cheia 0.33, alfa 0.8). Medir o mod contra o construtor deu um
   teste verde e uma noite que quase não escurecia. Procure Lua vanilla que mexa no
   objeto antes de confiar nos valores do bytecode.
2. **"Luz global" no clima do B42 é a COR e o ALFA, não o float de intensidade.**
   `FLOAT_GLOBAL_LIGHT_INTENSITY` só é lido pelo relâmpago. A luz do céu é
   `2 × (1 − alfa × (1 − cor)) × ambient`. Tint "azulado" claro com o alfa vanilla
   **clareia** a noite. Custou a primeira sessão de teste.
3. **De madrugada o clima vanilla já está no fundo:** `ambient` 0, `dayLight` 0,
   `night` 1. O que deixa a noite clara é o piso do sandbox `NightDarkness` (0.15 no
   "Normal" + luar), somado no render **depois** do clima. A camada modded só
   consegue multiplicar esse piso, pela cor da luz global.
4. **Dessaturação do clima some de noite:** o render faz `desat × (1 − darkness)`.
   Efeito de cor à noite só pela cor da luz global.
5. **`getFinalValue()` no `OnClimateTick` é o do minuto anterior:** o evento roda
   antes do `calculate()` do frame. Pra conferir se o valor chegou, compare com o
   escrito com a rampa parada.
6. **`IsoDeadBody` já guarda a hora da morte** (`getDeathTime()`, horas de mundo, salvo
   com o corpo): não precisa de marca em `OnZombieDead` pra saber quando alguém morreu.

## Pendências que a próxima sprint herda

- Roteiro in-game acima (passos 1–6) e marcar os dois critérios abertos.
- Calibrar no jogo: a força da noite (`LOOKS.night.tint`) e da névoa, se 1 ficar
  escuro demais ou pouco.
- Corpo carregado no colo e largado mantém a hora da morte e o `modData` (corpo humano,
  `InventoryItem.tryLoadCorpseFromByteData` 101–114; review). Corpo de cenário nasce com
  a hora em que o chunk foi gerado: área explorada pela primeira vez de noite só solta
  Ecos na noite seguinte (aceito).
- Com "Ativos só à noite" (`ActiveOnly`), o Corredor da névoa de dia não corre na fase
  inativa: a regra vanilla vence (aceito).
- A Carpideira (sprint 0010) entra no fim de `NOM_VariantRules.KINDS` com
  `CarpideiraChance` 3: as faixas de hoje não mudam.
- Save que já estava aberto de noite antes desta versão: o início da noite vira a
  hora da carga; quem morreu entre o anoitecer e a carga pode soltar Eco naquela noite.
  Uma vez só.

## Sessões

- 2026-10-04 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — investigação no bytecode (render da noite, `deathTime`), plano e implementação; troca do pedido 1 pra "monstros só na névoa"
