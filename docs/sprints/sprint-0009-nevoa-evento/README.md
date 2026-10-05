# Sprint 0009 — Névoa como evento: sirene e hora aleatória

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0009-nevoa-evento` |
| Plano | [plan.md](plan.md) |
| GDD | [world-states.md](../../gdd/world-states.md), [atmosphere.md](../../gdd/atmosphere.md), [monsters.md](../../gdd/monsters.md), [sandbox.md](../../gdd/sandbox.md) |
| ADR | [ADR-009](../../architecture/adr-009-nevoa-evento-do-mod.md) (nova) |

## Objetivo

A névoa deixa de ser clima: é um evento do mod, numa hora qualquer do dia, uma vez a
cada ~3 dias de jogo, anunciado por uma sirene 30 segundos reais antes, e dura de 2 a 6
horas de jogo. Fora do evento, não existe névoa nenhuma.

Decisões do Johan (05/10/2026), que **revertem** a decisão do brainstorm "gatilho =
névoa natural do clima":

1. Névoa é evento do mod, em hora aleatória, independente da hora do dia; em média
   uma a cada ~3 dias de jogo (`FogEventEveryDays`, padrão 3).
2. Uma sirene toca 30 segundos **reais** antes da névoa, em todo cliente, alta e
   audível em qualquer lugar.
3. Duração aleatória, 2 a 6 horas de jogo (`FogMinHours`, `FogMaxHours`).
4. Névoa natural vanilla não existe: o mod é dono do canal de névoa (0 fora do
   evento, densa durante, com rampa).

## Critérios de aceite

- [x] Próximo evento sorteado entre 0,5× e 1,5× de `FogEventEveryDays` depois do fim do
      anterior (média = o valor), e a duração entre `FogMinHours` e `FogMaxHours` —
      `fog_event_rules_gap_within_bounds` (limites e média exata em 1000 amostras),
      `fog_event_rules_duration_within_bounds` (min > max troca),
      `fog_event_ends_after_duration_and_reschedules` (servidor: dura 4 h com rand 0,5 e
      agenda a 72 h do fim).
- [ ] A sirene toca 30 s reais antes da névoa, em todo jogador (solo e MP); pausa não
      consome a contagem — **por código:** `fog_event_siren_30_real_seconds_before`
      (29,9 s sem névoa, 30,1 s com), `fog_event_mp_broadcasts_siren_and_fog`,
      `fog_event_siren_once_while_counting`, `fog_event_paused_holds_countdown`,
      `fog_event_rules_countdown_pauses_and_caps`, `fog_client_plays_siren`; pausa por
      bytecode (`GameTime.isGamePaused` 0–63). **Falta o jogo** (som audível, volume):
      roteiro passos 1, 2 e 6.
- [ ] Fora do evento a névoa final é 0, inclusive com névoa natural, com o
      `WeatherPeriod` (chuva/tempestade) e com o `FogCycle` do sandbox; durante o
      evento é densa, com rampa de entrada e saída — **por código e bytecode:**
      `look_fog_zero_outside_event`, `look_fog_zero_under_weather_period_override`,
      `look_fog_zero_under_fog_cycle_override` (FogCycle 2, 3, 4 e nevasca eterna),
      `look_event_fog_ramps_in_and_out`, `look_event_fog_wins_over_overrides`,
      `look_admin_fog_still_wins`, contra um `ClimateFloat` falso que imita o
      `calculate`, o `updateSandboxOverrides` e o `WeatherPeriod` (pz-api-notes §11.1).
      **Falta o jogo:** roteiro passos 3 e 4.
- [x] Flag de névoa (`NOM_World.fog`) e número do período vêm do evento; Sem-rosto,
      variantes, som, overlays, vinheta e debug seguem funcionando — `world_set_fog_fires_only_on_edges`,
      `world_update_never_touches_fog`, todos os `fog_*` de `test_fog.lua` (Sem-rosto),
      `night_and_fog_together` (variantes, stats, som, vinheta, overlays no solo),
      `variants_*` (grito do Corredor pelo período do evento), `debug_*`.
- [x] Próximo evento, fim do evento atual e número do período ficam no `ModData`
      global e sobrevivem a salvar/carregar; o período conta uma vez por evento —
      `fog_event_state_survives_reload`, `fog_event_reload_during_siren_restarts`,
      `fog_event_rules_period_once_per_event`, `fog_event_no_compounding_after_long_skip`,
      `fog_event_stale_0008_save_closes`, `fog_period_counts_once_per_fog`.
- [x] MP: o servidor decide e avisa; quem entra no meio do evento recebe o estado —
      `fog_event_mp_broadcasts_siren_and_fog`, `fog_event_mp_join_mid_event_gets_state`, `fog_event_mp_join_during_siren_hears_it`,
      `fog_client_follows_server`, `fog_client_asks_state_on_join`. (Falta o dedicado de
      verdade: roteiro passo 7.)
- [x] `NOM_Debug.fog(true[, pular])` começa um evento (com ou sem a espera da
      sirene), `NOM_Debug.fog(false)` termina — `debug_fog_starts_and_stops_event`,
      `debug_rules_parse_accepts_known_ops`, `debug_rules_parse_rejects_garbage`,
      `fog_event_stop_and_skip`, `fog_event_stop_cancels_scheduled_siren`, `debug_status_prints_local_and_server` (`proxima`, `fim`, `sirene`).
- [x] Textos do menu (PT-BR e EN) das opções novas; `FogThreshold` removida —
      `config_fog_event_defaults`, `config_sandbox_defaults_match_lua`,
      `config_every_option_has_default`, `translations_*` (chave usada sem tradução, EN
      em ASCII). Save antigo com `FogThreshold`: o jogo pula opção desconhecida (pz-api-notes §8).
- [x] Docs: GDD revisado (world-states, atmosphere, monsters, sandbox com presets,
      Overview com a decisão de 05/10 revertendo a de 04/10), ADR-009 nova e indexada,
      ADR-004/008 emendadas, pz-api-notes §11, teste in-game, README, Workshop, CREDITS.

`./run-tests.sh`: `total=347 passou=347 falhou=0` (Lua) e `build total=22 passou=22 falhou=0`.

## Roteiro in-game

Jogo em `-debug`, **save descartável** (o evento avança o contador de névoas salvo).
Console em `~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt` (Flatpak). O Lua
novo só carrega ao recarregar o save.

1. **Sirene e névoa forçadas.** Dia, ao ar livre: `NOM_Debug.fog(true)`. **Esperado:**
   `[NOM] debug nevoa sirene=true` e `[NOM] nevoa sirene contagem=30000`; a sirene
   toca alta (sobe e cai duas vezes, ~24 s). ~30 s reais depois:
   `[NOM] nevoa evento inicio periodo=N fim=H` e `[NOM] nevoa fog=true periodo=N`; a
   névoa entra em ~20 min de jogo (~50 s com o dia de 1 h). `NOM_Debug.status()`:
   `nevoa=true`, `fim=H`, `sirene=-`.
2. **Pausa na contagem.** `NOM_Debug.fog(false)`, depois `NOM_Debug.fog(true)` e pausar
   (velocidade 0) por 1 minuto real. **Esperado:** a névoa só vem ~30 s depois de
   despausar. Anotar se a sirene pausa junto (UNKNOWN, pz-api-notes §11.3).
3. **Névoa natural não existe.** Sem evento (`NOM_Debug.fog(false)`), Debug → Climate:
   subir a névoa pelo "WeatherPeriod"/tempestade (Trigger storm) e esperar uns minutos
   de jogo. **Esperado:** sem névoa na tela. Pro log, fazer de noite (Debug → Time
   23:00): o bloco `[NOM] clima …` sai a cada hora de jogo à noite, com
   `[NOM] clima fog vanilla=… escrito=0.00 final=0.00`. Anotar se o céu fica cinza sem
   névoa de dia (resíduo aceito, ADR-009).
4. **Evento com chuva.** Com a tempestade ainda rodando, `NOM_Debug.fog(true, true)`.
   **Esperado:** névoa densa mesmo na chuva; `[NOM] clima fog … escrito=0.85 final=0.85`
   com a rampa cheia. Sandbox com "Névoa: Sem névoa" (outro save): o mesmo.
5. **Salvar e carregar.** No meio do evento: salvar, sair, carregar. **Esperado:** a
   névoa volta (rampa de novo), `NOM_Debug.status()` com o mesmo `nevoaN` e o mesmo
   `fim`. No meio da sirene (`NOM_Debug.fog(true)`, salvar antes dos 30 s): ao
   carregar, a sirene toca de novo e a névoa vem 30 s depois.
6. **Agenda natural.** Novo save descartável, `FogEventEveryDays` 0.5, dia de 1 h,
   velocidade máxima. **Esperado:** em `-debug`, `[NOM] nevoa proxima=H` logo no
   início, a sirene em até ~18 h de jogo, a névoa por 2–6 h de jogo e o fim
   `[NOM] nevoa evento fim proxima=…`. Dormir no meio de uma sirene: a névoa vem 30 s
   reais depois (muitas horas de jogo dormindo), sem erro.
7. **MP (dedicado + 2 clientes).** `NOM_Debug.fog(true)` como admin: os **dois**
   clientes ouvem a sirene; a névoa chega pros dois. Um terceiro cliente entra no meio
   do evento: névoa, drone e vinheta nele (comando `fog` na entrada).

## Checkpoints

- **04/10/2026** — Sprint aberta (decisões do Johan de 05/10). Pesquisa no bytecode:
  ordem do `ClimateManager.update` (overrides do sandbox → `updateValues` →
  `WeatherPeriod.update` → `OnClimateTick` → `calculate`), quem liga o override da
  névoa e quando, `GameTime.isGamePaused`. Plano escrito.
- **04/10/2026** — Regra pura do evento, servidor do evento (agenda, sirene em tempo
  real, `ModData`), `NOM_ClimateLook` dono do canal de névoa, debug, sirene
  procedural. `FogThreshold` removida.
- **04/10/2026** — Docs: ADR-009, GDD revisado, pz-api-notes §11. Em teste.
- **04/10/2026** — Review (sem Critical): `NOM_Debug.fog(false)` não cancelava a sirene
  da agenda (o `next` ficava no passado e tocava de novo); quem entra durante a
  contagem agora ouve a sirene; log da contagem inteiro; nota do `PauseEmpty` no §11.2.

## Aprendizados

1. **"Natural" não some zerando o final da névoa.** O `updateValues` calcula a névoa
   do dia e, com ela, puxa a luz pra cor de névoa e dessatura **antes** de qualquer
   camada modded. Zerar o canal apaga a névoa da tela, não o cinza. O mesmo vale pro
   `FogCycle` "Sem névoa" da vanilla.
2. **Override de névoa é religado todo minuto, por dois donos, antes do
   `OnClimateTick`.** O `WeatherPeriod` chama `setOverride` a cada minuto de chuva, e
   `setOverride` liga o `isOverride` sozinho; o sandbox liga o de valor só na troca.
   Desligar uma vez não basta, e desligar no `OnTick` é tarde: tem que ser no
   `OnClimateTick`, entre eles e o `calculate`.
3. **Tempo real no servidor:** `getTimestampMs()` no `OnTick`, parado com
   `isGamePaused()` (que no dedicado é "vazio com PauseEmpty") e com teto por frame;
   senão a volta de uma pausa come a contagem inteira de uma vez.

## Pendências que a próxima sprint herda

- Roteiro in-game acima (passos 1–7) e marcar os dois critérios abertos.
- Calibrar no jogo: a densidade (`NOM_FogEventRules.DENSITY` 0.85) e se o resíduo cinza
  da névoa natural (ADR-009) incomoda; se incomodar, compensar a luz global fora do
  evento (o mod sabe o interno da névoa natural no `OnClimateTick`).
- A sirene não tem toggle nem volume próprio (usa o volume de efeitos). Se pedirem, uma
  opção de sandbox.

## Sessões

- 2026-10-05 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — pesquisa no bytecode, plano e implementação
