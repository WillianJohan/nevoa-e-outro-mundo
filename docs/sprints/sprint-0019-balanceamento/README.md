# Sprint 0019 — Balanceamento do PO e curva de tensão

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0019-balanceamento` |
| Plano | [plan.md](plan.md) |
| GDD | [sandbox.md](../../gdd/sandbox.md#curva-de-tensão-sprint-0019) (defaults, presets, curva), [world-states.md](../../gdd/world-states.md), [monsters.md](../../gdd/monsters.md#regra-geral), [night.md](../../gdd/night.md), [atmosphere.md](../../gdd/atmosphere.md#som), [Overview](../../gdd/Overview.md#decisões-do-autor) |
| ADR | [ADR-009](../../architecture/adr-009-nevoa-evento-do-mod.md#emenda-de-2026-10-05--sprint-0019-curva-de-tensão) (emenda), [ADR-010](../../architecture/adr-010-nevoa-vermelha.md#emenda-de-2026-10-05--sprint-0019-carência-escalada-e-cor-salva-na-sirene) (emenda) |

## Objetivo

Num save novo com o sandbox padrão, a primeira semana tem névoa a cada ~3 dias e nenhuma
vermelha; com os dias a névoa fica mais seguida (~1,5 dia a partir do dia 45) e a vermelha
mais comum (até o dobro no dia 90). Os defaults e os presets são os da análise do PO, aprovada
integralmente pelo Johan em 05/10/2026.

## Critérios de aceite

- [x] Defaults do PO nos dois lugares (`sandbox-options.txt` e `NOM_Config.DEFAULTS`):
      névoa 2 dias, 3–6 h; Eco 20/30; caça 90/25; Corredor 3; Sem-rosto 3; grito da
      Carpideira 50; o resto igual — `config_*_defaults`, `config_sandbox_defaults_match_lua`.
      Monstros somados 14% — `variant_rules_default_chances`, `variant_rules_default_total_14`.
- [x] **Critério 1** — `FogEscalation` ligado, base 2: save com 0 dias → intervalo entre 1,5 e
      4,5 dias; dia 45 em diante → entre 0,75 e 2,25 — `fog_event_rules_interval_curve` (dias
      0, 45 e 300), `fog_event_interval_follows_curve` (servidor: `next` do evento do dia 45 =
      fim + 18 h com `rand` 0), `fog_event_defaults_start_slow` (sandbox do jogo: primeira
      sirene em 36 h). Saturação em meses de sono — `fog_event_rules_escalation_clamps`.
- [x] **Critério 2** — `RedFogGraceDays` 7, chance 100: 50 névoas forçadas antes do dia 7,
      nenhuma vermelha (e a do dia 7 vem) — `fog_event_grace_no_red_in_50_forced_fogs`.
- [x] **Critério 3** — sirene vermelha salva e recarregada continua vermelha mesmo com a
      chance mudada (pelo sandbox ou pela carência) — `fog_event_red_saved_at_siren_survives_reload`;
      sirene cancelada esquece a cor — `fog_event_cancelled_siren_forgets_red`.
- [x] **Critério 4** — `FogEscalation` desligado = comportamento de hoje com os valores do
      sandbox — `fog_event_rules_escalation_off_is_flat`, `fog_event_escalation_off_is_today`
      (dia 90: média 2 e chance 100 intactas), e todos os testes de mecanismo da 0009/0010
      rodando com a escalada desligada e carência 0. Ver ruling 1 (a carência vale sozinha).
- [x] **Critério 5** — opções novas com PT-BR e EN, tooltip com a fórmula em palavras, sem `%`
      sozinho — `config_new_options_defaults` (default, tipo, faixa 0–60),
      `translations_*` (toda chave nas duas línguas, JSON estrito, `translations_no_lone_percent`).
      Os tooltips não usam `%`: "uma vez e meia o configurado … três quartos dele do dia 45 …
      sobe até o dobro no dia 90".
- [x] `data.fog.bornAt` gravado uma vez; save novo nasce agora, save veterano (já tem agenda)
      nasce no ponto neutro da curva (30 dias antes) — `fog_event_born_at_saved_once`; sem
      carência e com intervalo ~1× da base pro veterano — `fog_event_veteran_no_grace_no_change`;
      bornAt no futuro vira agora — `fog_event_born_at_clamped_to_now`.
- [x] Log da sirene: na recarga durante a sirene a cor salva é reaproveitada e sai `chance=-`
      — `fog_event_siren_log_reused_colour`.
- [x] Tooltip da chance de vermelha fala da carência e da escalada (até o dobro), sem `%` —
      `config_red_chance_tooltip_mentions_curve`.
- [x] Debug passa por cima da carência — `fog_event_debug_red_ignores_grace`.
- [x] Tooltip do Eco diz que a mordida infecta igual — `config_eco_tooltip_says_bite_infects`.
- [x] Presets revistos (Leve "primeira visita", Padrão "o mundo tem horário", Pesadelo "a
      cidade é proibida") em [sandbox.md](../../gdd/sandbox.md#presets); as 5 mudanças nas
      decisões do Johan no [Overview](../../gdd/Overview.md#decisões-do-autor); playtest do PO
      no [teste-in-game.md](../../teste-in-game.md#balanceamento) — revisão dos docs.
- [ ] As duas opções aparecem no menu do sandbox com nome e tooltip legíveis nas duas línguas,
      sem `UnknownFormatConversionException` no console — **falta o jogo:** roteiro, passo 1.
- [ ] A sirene loga dias e chance da curva, e um save antigo entra no ponto neutro (dia 30)
      com o próprio sandbox — **falta o jogo:** passos 2–4.
- [ ] Playtest dos 10 itens do PO — **falta o jogo:** [teste-in-game.md](../../teste-in-game.md#balanceamento).

`./run-tests.sh`: `total=583 passou=583 falhou=0` (Lua), `contraste total=4 passou=4`,
`build total=25 passou=25`.

## Roteiro in-game

Jogo em `-debug`, **save descartável**, sandbox padrão. Console em
`~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt` (Flatpak).

1. **Menu.** Novo jogo > Sandbox > página "Névoa e Outro Mundo", em PT-BR e em EN.
   **Esperado:** "Névoa: tensão que cresce com os dias" (ligado) depois da duração máxima, e
   "Névoa vermelha: dias de carência" (7, de 0 a 60) depois da chance da vermelha; tooltips
   inteiros; os números novos (2 / 3 / 6, Eco 20 / 30, caça 90 / 25, Corredor 3, Sem-rosto 3,
   grito 50). Nenhuma linha `UnknownFormatConversionException` nem `NOM_` com `ERROR`.
2. **Save novo, dia 0.** Carregar, `NOM_Debug.status()`. **Esperado:** `proxima=` entre ~36 e
   ~108 horas depois da hora atual (`getWorldAgeHours`). `NOM_Debug.fog(true)`: linha
   `[NOM] nevoa sirene contagem=30000 vermelha=false dias=0.00 chance=0.00` (carência; `dias=`
   é o tempo desde o carregamento, perto de 0).
3. **Fim da carência.** Avançar o relógio 7 dias (admin/sono), `NOM_Debug.fog(false)` e
   `NOM_Debug.fog(true)`. **Esperado:** `dias=7.xx chance=10.00`. Repetir com `fog(false)`
   até sair `vermelha=true` (1 em 10, em média).
4. **Save antigo** (o do Johan serve). Carregar um save da sprint 0017 com dias de jogo e
   `NOM_Debug.fog(true)` logo depois. **Esperado:** `dias=30.0x chance=10.00` (ponto neutro:
   ruling 2), sem carência. **O save antigo guarda o próprio sandbox:** continua com
   `FogEventEveryDays` 3 e `FogMinHours` 2 (e Eco 30/40, caça 60/30, Corredor 2, Sem-rosto 5,
   grito 60) até alguém mudar à mão ou começar um save novo; só `FogEscalation` e
   `RedFogGraceDays` chegam com o default. Conferir na página do sandbox do save.
5. **Recarga na sirene vermelha.** `NOM_Debug.redFog(true)`, salvar e sair durante os 30 s,
   carregar. **Esperado:** a sirene **vermelha** toca de novo e a névoa abre vermelha.
6. **Playtest do PO** (10 itens com limiares): [teste-in-game.md](../../teste-in-game.md#balanceamento).

## Riscos de produto (do PO)

- **Carpideira atrás de porta:** o jogador abre e já está a 4 tiles; acorda sem ter ouvido o
  soluço (item 5 do playtest mede).
- **Sem-rosto a 3 tiles num corredor:** sem tile fora da vista ele fica parado à vista ou
  reaparece perto demais (herdado da 0017).
- **Noite 1 com ~60% correndo** (`NightSpeedMult` 1.5 sobe um degrau): a caça mais espaçada
  (90/25) é a resposta desta sprint; se não bastar, `NightFaster` desligado como padrão.
- **Sono e fast-forward:** a sirene toca 30 s reais antes, mas quem dorme pode acordar no meio
  de uma vermelha sem ter ouvido (ADR-009, decisão 2). A carência adia o problema, não resolve.

## Rulings do Claude

1. **A carência vale com ou sem a escalada.** É opção própria (0 desliga) e o critério 2 não
   cita a escalada. Com `FogEscalation` desligado e `RedFogGraceDays` 7 (padrão), a primeira
   semana continua sem vermelha; "comportamento de hoje" (critério 4) exige também carência 0.
   Custo se errado: quem desliga a escalada esperando o jogo antigo fica 7 dias sem vermelha,
   até zerar a carência; trocar é um `if` no `R.redChance`.
2. **Save veterano nasce no ponto neutro da curva** (ruling do coordenador na review,
   substitui o "começa no primeiro carregamento" da primeira versão). Save que já tem agenda
   (`night` ou `next`) e não tem `bornAt` ganha `bornAt = agora − 30 dias`
   (`NOM_FogEventRules.born`, `NEUTRAL_DAYS`): intervalo 1×, vermelha 1×, carência vencida
   (30 ≥ 7; só uma carência acima de 30 no sandbox ainda pegaria o veterano). Quem já jogava não
   sente mudança; a curva aperta dali pra frente. Save novo nasce agora. `bornAt` no futuro vira
   agora. **E o save antigo guarda o próprio sandbox:** `SandboxOptions.load(ByteBuffer)` só faz
   `parse` das opções que estão no `map_sand.bin` (bytecode 81–122: acha pelo nome, opção
   ausente fica com o valor que tinha); opção nova (`FogEscalation`, `RedFogGraceDays`) fica com
   o default. Os defaults novos valem pra save novo. Custo se errado: o veterano sem a pressão
   inicial da curva; mudar o ponto é o `NEUTRAL_DAYS`.
3. **Intervalo sorteado no fim do evento** (com o `d` daquele momento) e salvo; mudar o sandbox
   ou o dia avançar não reagenda o `next` já marcado. Custo se errado: no máximo um intervalo
   "velho" depois de trocar o sandbox.
4. **Cor salva na sirene** (`data.fog.red` desde a sirene, não só com o evento aberto). Antes, a
   recarga na contagem re-sorteava; com a chance andando com os dias o re-sorteio podia trocar
   a cor. Custo se errado: nenhum conhecido; `setFog` continua dando `red` falso sem névoa.
5. **Testes do mecanismo fixam a agenda antiga** (3 dias, 2–6 h, sem curva, carência 0) no
   `setup` do `test_fog_event.lua`; os da curva ligam o que medem e um usa o sandbox do jogo
   (`defaults = true`). Testes que mediam o default (teto do Eco, alcance do grito) passaram pro
   número novo. O grito da Carpideira a 50 sai 51 (raio arredondado `17 × 3`: comportamento
   que já existia; o teste aceita ±1).
6. **Textos do Overview e do sandbox.md não inventam motivo do PO:** onde a análise só dá o
   número, a justificativa registrada é o limiar de volta do playtest.

## Checkpoints

- **04/10/2026** — Sprint aberta a partir da análise do PO aprovada pelo Johan. Plano escrito.
- **04/10/2026** — Defaults do PO e tooltip do Eco; testes que mediam número velho fixam o
  sandbox. Verde.
- **04/10/2026** — Curva pura (`days`, `everyDays`, `redChance`) no `NOM_FogEventRules`;
  `bornAt`, cor salva na sirene, `FogEscalation` e `RedFogGraceDays` no servidor. Verde.
- **04/10/2026** — Docs: sandbox.md (defaults, presets, curva, revisão do PO), Overview,
  world-states/monsters/night/atmosphere, emendas da ADR-009 e da ADR-010, playtest no
  teste-in-game.md, README e descrições do Workshop. Em teste.
- **04/10/2026** — Review: save veterano no ponto neutro da curva, `bornAt` limitado a agora,
  log `chance=-` na cor reaproveitada, tooltip da chance com carência e escalada, tabela do
  sandbox.md consertada. Verde.

## Aprendizados

- **Default novo quebra teste de mecanismo que lia o default.** Os testes do evento de névoa
  mediam `next == 136` com o 3 dias implícito. Fixar no `setup` o sandbox que o mecanismo
  mede (e deixar um teste com o sandbox do jogo) separa "o número mudou" de "a regra quebrou".
- **O alcance compensado arredonda:** `soundRadius(50)` com audição apurada dá raio 17, alcance
  51. Alcance de default que não divide por 3 não sai exato.

## Pendências que a próxima sprint herda

- Tudo do roteiro acima e o playtest dos 10 itens.
- Vermelha sem teto de variantes (item 7 do playtest decide se vira sprint).
- Sono/fast-forward atravessando a sirene (risco de produto acima).
- Achado menor 5 da review fica como está: só debug e anterior à sprint (o forçado do
  `NOM_Debug.redFog` mora só em memória).
- Save antigo continua com o sandbox antigo: pra jogar com os números do PO, mudar à mão na
  página do sandbox do save ou começar um save novo.
- Sprint 0018 (dissolve + bloom) corre em paralelo: o merge das duas mexe em
  `docs/sprints/README.md` (roadmap) e no Overview (Decisões), só com linhas acrescentadas.

## Sessões

- 2026-10-05 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — plano, defaults do PO, curva de tensão, docs
