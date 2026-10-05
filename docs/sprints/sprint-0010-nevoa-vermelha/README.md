# Sprint 0010 — Névoa Vermelha

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0010-nevoa-vermelha` |
| Plano | [plan.md](plan.md) |
| GDD | [atmosphere.md](../../gdd/atmosphere.md), [monsters.md](../../gdd/monsters.md), [sandbox.md](../../gdd/sandbox.md) |
| ADR | [ADR-010](../../architecture/adr-010-nevoa-vermelha.md) (nova) |

## Objetivo

Às vezes a névoa vem vermelha: sirene própria, mais grave e rasgada, névoa e luz
vermelhas, e todo zumbi dentro dela é monstro.

Decisões do Johan (05/10/2026):

1. A cada evento de névoa (sprint 0009), `RedFogChance`% (padrão 10, 0–100) de vir
   vermelha. Sorteio determinístico pelo número do período (recarregar não re-sorteia;
   servidor e clientes concordam). O servidor decide e espalha no comando `fog`
   (`{on, period, red}`).
2. Na vermelha, **todo** zumbi é variante, dividido por igual entre os tipos (hoje 1/3
   cada; a Carpideira da 0011 entra na lista), pelo `persistentOutfitID` + período.
   Ecos continuam Ecos. Cada tipo com o comportamento de sempre.
3. Sirene própria (mais grave, distorcida, mais longa) no lugar da normal, no mesmo
   momento (30 s reais antes), tocada local em cada cliente. Névoa e luz vermelhas pelo
   clima (servidor, `OnClimateTick`, valor absoluto, interpolate 1). Vinheta vermelha só
   com evidência de que o `SearchMode` aceita cor (não aceita: §12.2).

## Critérios de aceite

- [x] `RedFogChance`% dos eventos vêm vermelhos, sorteio determinístico por período —
      `variant_rules_red_fog_deterministic_per_period` (2000 períodos: 150–250 com 10%,
      0% e 100% exatos, desligada nunca, mesmo período mesma resposta),
      `fog_event_red_matches_pure_roll` (o servidor bate com o sorteio puro em 6
      períodos com 50%), `fog_event_red_chance_zero_or_disabled_is_normal`.
- [x] Recarregar no meio da névoa vermelha mantém vermelha — `fog_event_red_reload_mid_fog_stays_red`
      (`data.fog.red` no `ModData`, mesmo período, sem sirene de novo, mesmo com o
      sandbox mudado pra 0%); `fog_event_rules_start_stores_red`.
- [x] Servidor decide e espalha; quem entra recebe — `fog_event_red_mp_broadcast`
      (`siren {red}`, `fog {on, period, red}`, `fogState` durante a contagem e no meio
      do evento), `fog_client_plays_red_siren_once`, `world_red_flag_edges`,
      `fog_server_red_fog_accepts_red_semrosto`.
- [x] Na vermelha todo zumbi é variante, ~1/3 de cada, Ecos fora —
      `variant_rules_red_fog_splits_evenly` (20 000 IDs no formato do jogo: cada tipo a
      menos de 2 pontos de 1/3; períodos seguidos não correlacionados),
      `variant_rules_red_fog_disabled_kind_stays_normal`, `variant_rules_red_fog_keeps_forced_and_id0`,
      `variant_rules_red_flag_off_is_normal_roll`, `stats_red_fog_every_zombie_is_variant`
      (90 zumbis: nenhum comum, 18–42 de cada, Eco sem variante, volta ao normal),
      `semrosto_red_fog_counts_red_split`, `variants_red_fog_corredor_screams`.
- [ ] Sirene vermelha toca uma vez por névoa vermelha em cada cliente, no lugar da
      normal, 30 s reais antes — **por código:** `fog_event_red_decided_at_siren`,
      `fog_client_plays_red_siren_once`, `fog_event_red_ends_clean` (uma vermelha e
      depois uma normal), `config_sound_scripts_point_to_files` (`NOM_SirenRed`
      declarado com arquivo). **Falta o jogo** (som audível, distinto da normal):
      roteiro passos 1 e 6.
- [ ] Névoa e luz vermelhas pelo clima, sem acumular, e de volta ao vanilla no fim —
      **por código e bytecode:** `look_red_fog_tints_without_compounding` (K = 1, 10,
      150 frames por minuto, contra o `ClimateColor` falso que faz o lerp no próprio
      interno), `look_red_fog_color_ramps`, `look_red_fog_color_restored_after` (o
      interno da cor da névoa não volta sozinho, `setup()` 324–361 (chamado pelo `<init>` no 525)), `look_red_fog_color_wins_storm_override`
      (`WeatherPeriod` 909–957), `look_normal_fog_touches_no_fog_color`,
      `look_red_fog_color_without_dark`; cor da névoa lida pelo `ImprovedFog.update`
      132–174 (pz-api-notes §12.1). **Falta o jogo:** roteiro passos 2–5.
- [x] A névoa vermelha é mais escura que a vanilla em todo caminho —
      `rules_red_fog_darker_than_vanilla_on_every_path` (contra as três luzes de névoa e
      as duas noites vanilla da ADR-008, `DarkIntensity` 1 e 2, meio da rampa e cheia:
      ≥ 15% em todo canal, verde/azul ≥ 15 pontos a mais que o vermelho; com a noite,
      ≥ 30%; cor da névoa mais escura que a branca vanilla), `rules_mix_red_zero_is_normal`.
- [x] Vinheta: sem cor no `SearchMode` (só blur, desat, radius, gradientWidth,
      darkness; bytecode, pz-api-notes §12.2), fica a da névoa normal.
- [x] Sandbox `RedFogEnabled` (true) e `RedFogChance` (10), PT-BR e EN — `config_red_fog_defaults`,
      `config_sandbox_defaults_match_lua`, `variant_rules_config_reads_red_fog`,
      `translations_*` (sem `%` sozinho).
- [x] `NOM_Debug.redFog(true|false)` com a mesma porta dos outros — `debug_rules_parse_red_fog`,
      `debug_red_fog_forwards_to_event` (sem permissão no dedicado não passa),
      `debug_status_shows_red`, `fog_event_set_red_starts_red_event`,
      `fog_event_set_red_flips_open_event`, `fog_event_set_red_during_siren`.
- [x] Docs: GDD (atmosphere, monsters, sandbox com presets, Overview), ADR-010 nova e
      indexada, ADR-006/009 emendadas, pz-api-notes §12, teste in-game, README,
      Workshop, CREDITS.

`./run-tests.sh`: `total=381 passou=381 falhou=0` (Lua) e `build total=22 passou=22 falhou=0`.

## Roteiro in-game

Jogo em `-debug`, **save descartável** (o evento avança o contador de névoas salvo).
Console em `~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt` (Flatpak). O Lua
novo só carrega ao recarregar o save.

1. **Sirene vermelha.** Dia, ao ar livre, sem névoa: `NOM_Debug.redFog(true)`.
   **Esperado:** `[NOM] debug nevoa vermelha=true` e
   `[NOM] nevoa sirene contagem=30000 vermelha=true`; toca a sirene **vermelha** (mais
   grave e rasgada que a normal, ~28 s), não a normal. ~30 s reais depois:
   `[NOM] nevoa evento inicio periodo=N fim=H vermelha=true` e
   `[NOM] nevoa fog=true periodo=N vermelha=true`.
2. **Névoa e luz vermelhas.** Esperar ~20 min de jogo (rampa). **Esperado:** a névoa
   desenhada vermelha escura e a cena tingida de vermelho, mais escura que uma névoa
   normal. Na borda da rampa: `[NOM] nightRamp=… nevoa=0.85 vermelha=1.00` e
   `[NOM] clima corNevoa final=0.55,0.06,0.05,1.00 vermelha=1.00`. Anotar o
   `PerformanceSettings` de névoa do jogo (Opções → Tela → qualidade da névoa): se com
   a "legada" a névoa ficar branca (só a luz vermelha), é o UNKNOWN da §12.1.
3. **Todo zumbi é monstro.** Perto de uns 10 zumbis: `NOM_Debug.status()`. **Esperado:**
   `[NOM] debug local … vermelha=true …` com `estaladores` + `corredores` ≈ 2/3 dos
   zumbis carregados (a contagem é de todos os carregados), e os outros somem quando
   olhados (Sem-rosto). Eco (de noite,
   `NOM_Debug.spawnEco()`) continua Eco.
4. **Fim.** `NOM_Debug.fog(false)` e esperar ~20 min de jogo. **Esperado:**
   `[NOM] clima corNevoa final=0.90,0.90,0.95,1.00 vermelha=0.00`. Depois
   `NOM_Debug.fog(true, true)`: névoa **branca**, zumbis voltam ao sorteio normal
   (poucos monstros). Se essa sair vermelha também (10% de chance, o log diz
   `vermelha=true`), `NOM_Debug.redFog(false)` e conferir que volta a branca.
5. **Salvar e carregar.** Numa vermelha aberta: salvar, sair, carregar. **Esperado:**
   continua vermelha (`NOM_Debug.status()` com `vermelha=true` e o mesmo `nevoaN`), sem
   sirene. Com tempestade (Debug → Climate, Trigger storm) durante a vermelha: a névoa
   segue vermelha.
6. **MP (dedicado + 2 clientes).** `NOM_Debug.redFog(true)` como admin: os dois ouvem a
   sirene vermelha; névoa e luz vermelhas nos dois. Um terceiro cliente entra no meio:
   névoa vermelha e `vermelha=true` no `NOM_Debug.status()` dele.

## Checkpoints

- **04/10/2026** — Sprint aberta (decisões do Johan de 05/10). Pesquisa no bytecode: a
  cor da névoa é o `COLOR_NEW_FOG` (id 1) lido pelo `ImprovedFog`; o interno dela não
  volta sozinho; a tempestade põe override nela; vai pros clientes no pacote de clima;
  `SearchMode` sem cor. Plano escrito.
- **04/10/2026** — Sorteio puro (vermelho e divisão), evento decidindo/salvando/espalhando,
  consumidores do sorteio, clima vermelho, debug, sirene procedural.
- **04/10/2026** — Docs: ADR-010, GDD, pz-api-notes §12, roteiro. Em teste.

## Aprendizados

1. **Cor do clima que o jogo não recalcula fica presa.** O `COLOR_NEW_FOG` só é escrito
   no `setup()` do construtor, e o `calculate` aplica a camada modded no próprio interno. Com
   interpolate 1, desligar a camada deixa o último valor escrito até recarregar o
   save. Antes de desligar uma camada modded, confira se o jogo reescreve o interno
   todo minuto (`updateValues`); se não, escreva o vanilla antes.
2. **`ClimateManager.COLOR_NEW_FOG` não existe no Lua.** Só `COLOR_GLOBAL_LIGHT` e
   `COLOR_MAX` são campos; o id 1 vem do construtor e do painel de admin vanilla.

## Pendências que a próxima sprint herda

- Roteiro in-game acima (passos 1–6) e marcar os dois critérios abertos.
- Calibrar no jogo: `LOOKS.redFog.tint` e `RED_FOG_COLOR` (vermelho demais ou de menos;
  a cena tem que ficar jogável).
- Carpideira (0011) entra no fim de `KINDS`: a vermelha vira 1/4 de cada
  automaticamente.
- Com a qualidade de névoa "legada" a cor da névoa pode não valer (só a luz fica
  vermelha). Se for o caso, aceitar ou procurar o caminho do render legado.

## Sessões

- 2026-10-05 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — pesquisa no bytecode, plano e implementação
