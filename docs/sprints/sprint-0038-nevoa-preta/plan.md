# Sprint 0038: Névoa preta I (plano de implementação)

> Para agentes: executar tarefa por tarefa, com TDD. Code review só no fim da entrega (decisão do Johan, 2026-10-06).

**Objetivo** ([spec §1, §2, §8](../../superpowers/specs/2026-10-06-modelo-novo-design.md)): a escuridão, Alan Wake. Luz é tudo, o Tição congela no facho.
- o sorteio da sirene ganha o tipo **preta**: 5% das névoas, só a partir do dia 14, 2–3 h de jogo;
- na preta o clima fica escuro como noite fechada, mesmo de dia; sem luz o jogador enxerga 2–3 tiles;
- todo zumbi vira **Tição** (sem Estalador, Corredor, Sem-rosto, Carpideira nem Eco): arrastado ou arrastado rápido, vê pouco, ouve muito bem, caça;
- a luz congela: Tição no facho de lanterna, no farol de carro ou no raio de luz fixa para e não ataca; ~0,5 s fora da luz, volta;
- a lanterna pisca de vez em quando e, no piscar, solta o Tição.

Fora (0039): a névoa preta do mod3 empurrada pela luz e o Outro Mundo queimado. Ficam ganchos (`NOM_World.black`, `NOM_FogState.black`, `NOM_TicaoLight.lights()`).

## O que já existe

- **Agenda (0033):** `NOM_FogEventRules` (dia, duração por tipo, carência da vermelha), `server/NOM_FogEvent.lua` decide a cor no presságio (`decideColor`) e salva em `data.fog.red`.
- **Sons da preta:** `NOM_SirenSpotsRules.SOUNDS.black` e `NOM_DeviceRules.SOUNDS.*.black` já existem, mas nada toca.
- **Clima:** `server/NOM_ClimateLook.lua` com rampas por minuto de jogo (`eventRamp`, `redRamp`), camadas modded de `desaturation`, `ambient`, `tint` e a cor da névoa (`COLOR_NEW_FOG`).
- **Congelar:** `NOM_SirenFreeze` (`setUseless(true)`, `setTarget(nil)`, `halt`, prazo de segurança, rodízio do useless herdado) funciona no MP.
- **Cegueira:** visão curta da 0036 (`NOM_VariantAI`), com o raio do sandbox.
- **Visual:** `NOM_VariantLook` (pele + peça, casca de brasa da 0022), véu de fumaça do Eco (`Base.NOM_EcoVeu`).
- **Debug:** `NOM.setBlackFog()` é um stub; o botão "Preta" já está no painel.

## Restrições globais

As do `AGENTS.md`:
- Kahlua (sem `next`, `//`, `goto`, operador de bit, `table.unpack`, `math.random`; `%` trunca: `NOM_Math.mod`);
- o servidor decide e quem simula aplica (ADR-002/005); dono do zumbi é `z:isLocal()` (pz-api-notes §24);
- evidência de API (pz-api-notes §29, nova); fakes fiéis; textos PTBR + EN; PT-BR com acento;
- todo comando `NOM.*` com botão no `NOM.panel()`.

## Ordem

| # | Tarefa | Depende de |
|---|---|---|
| 1 | Agenda: tipo `black` no sorteio, sandbox, flag `black` do servidor até quem vê, sons | — |
| 2 | Escuridão: clima de noite fechada, névoa escura, vinheta e lascas pretas | 1 |
| 3 | Tição: variante única da preta (stats, cegueira, caça, visual), Eco fora | 1 |
| 4 | A luz congela: regra pura da luz, servidor confere, dono congela; custo medido | 3 |
| 5 | Lanterna pisca: servidor sorteia, todos apagam o visual, o Tição solta | 4 |
| 6 | Debug: `NOM.setBlackFog(skip)` de verdade, `NOM.ticao()`, botões | 1, 4 |
| 7 | Docs: pz-api-notes §29, README com roteiro, `docs/sprints/README.md`, HANDOFF | todas |
| 8 | `./run-tests.sh` verde e code review próprio do diff | todas |

---

### Tarefa 1: agenda

Teste primeiro (`tests/test_fog_event_rules.lua`, `tests/test_fog_event.lua`, `tests/test_world.lua`, `tests/test_fog_client.lua`, `tests/test_config.lua`):
- `R.blackFog(period, seed, cfg, days)`: 0 na carência (`BlackFogGraceDays`, dias desde o `bornAt`), `BlackFogChance`% dos períodos depois, desligada com `BlackFogEnabled` falso; determinística (sal próprio, não se correlaciona com a vermelha);
- `R.start(..., red, black)`: preta dura entre `BlackFogMinHours` e `BlackFogMaxHours`; preta e vermelha nunca juntas (preta ganha);
- `R.stop` e `R.cancel` limpam `black`; save antigo (sem `black`) abre como antes;
- servidor: a preta sobe preta (`risingBlack`), abre preta (`NOM_World.black`), manda `black` nos comandos `presage`, `siren`, `sirenColor`, `fog`; recarga no meio mantém a cor;
- sirene preta toca os sons `NOM_SirenBlack*`; aparelhos falam a voz preta.

Sandbox (com tradução PTBR + EN): `BlackFogEnabled` (true), `BlackFogChance` (5), `BlackFogGraceDays` (14), `BlackFogMinHours` (2), `BlackFogMaxHours` (3).

### Tarefa 2: escuridão

Teste primeiro (`tests/test_rules.lua`, `tests/test_climate_look.lua`, `tests/test_screen_fx_rules.lua`, `tests/test_flake_rules.lua`):
- `NOM_Rules.blacken(look, blackRamp)`: compõe o look de sempre com o da preta (`LOOKS.blackFog`) pela rampa; com rampa 1 o resultado final é o da preta (noite fechada: luz do dia 0, noite 1, ambiente 0, tint quase preto), com rampa 0 o de antes; não depende de `DarkEnabled` (é regra de jogo);
- `NOM_ClimateLook`: rampa `blackRamp` que sobe na sirene preta como a vermelha, canais `daylight` e `night` (as constantes do slider "Darkness" do admin), cor da névoa escura; tudo volta no fim;
- vinheta: na preta é preta, maior e sem vermelho; estática cinza-escura;
- lascas e cinza: paleta preta (cinza escura, brasa apagada).

### Tarefa 3: Tição

Teste primeiro (`tests/test_variant_rules.lua`, `tests/test_ticao_rules.lua`, `tests/test_night_rules.lua`, `tests/test_night_stats.lua`, `tests/test_variant_ai.lua`, `tests/test_eco.lua`, `tests/test_variant_look.lua`, `tests/test_look_assets.lua`):
- `variant(..., black)` devolve `"ticao"` pra todo zumbi com ID (forçado do debug não vale na preta);
- `NOM_TicaoRules.speed(id, period)`: 3 (arrastado) ou 2 (arrastado rápido), metade a metade, determinístico;
- `wanted("ticao")`: velocidade do sorteio, visão 3 (ruim), audição 1 (apurada); nem noite nem calmaria mudam;
- visão curta: na preta o Tição entra no rodízio com raio `NOM_TicaoRules.VISION_TILES` (3);
- o `onUpdate` do Tição sai na primeira linha (custo por frame zero);
- Eco: não nasce na preta; os carregados somem quando a preta abre;
- caça: a cada `HUNT_MINUTES` de jogo, chamado a `HUNT_REACH` tiles em volta de cada jogador (mais forte que a caça da noite: 90 min, 25 tiles);
- visual: pele `NOM_Ticao` (carvão com rachaduras de brasa, gerada por `scripts/gen_textures.py`) + véu de fumaça do Eco; a casca de brasa da 0022 faz a transição.
- fim da preta: todo Tição volta (stats, visual, useless solto).

### Tarefa 4: a luz congela

Teste primeiro (`tests/test_light_rules.lua`, `tests/test_ticao_light.lua`, `tests/test_ticao_freeze.lua`):
- regra pura (`shared/NOM_LightRules.lua`): facho (origem, direção, alcance, cone pelo `torchDot`, folga do corpo), raio fixo, cômodo aceso; lanterna de cone vira facho, lampião (sem cone, alcance ≥ 10) vira raio pequeno, isqueiro e vela (alcance 5) não contam; farol de carro; rodízio (quantos por tick pra cobrir todos a cada 250 ms);
- servidor (`server/NOM_TicaoLight.lua`): na preta, a cada tick confere uma fatia dos zumbis contra as luzes (lanternas e faróis dos jogadores lidos no servidor, luzes fixas achadas por uma varredura lenta em volta dos jogadores); aceso por luz firme = congelado até 500 ms depois; a cada 250 ms manda a lista dos congelados; solo aplica direto;
- dono (`shared/NOM_TicaoFreeze.lua`): congela os listados que são dele (o mesmo `setUseless` + `halt` da sirene), solta os que saíram; sem mensagem por 1,5 s, solta todos; fim da preta solta todos; cópia remota não mexe; posse que muda no meio não deixa zumbi preso;
- **custo:** ~300 zumbis, 4 jogadores com lanterna, luzes fixas: chamadas Java por tick abaixo do teto do repo.

### Tarefa 5: lanterna pisca

Teste primeiro (`tests/test_light_rules.lua`, `tests/test_ticao_light.lua`, `tests/test_torch_flicker.lua`):
- regra pura: próximo piscar entre `FLICKER_MIN_MS` e `FLICKER_MAX_MS` reais, duração entre 200 e 400 ms;
- servidor sorteia por jogador com lanterna acesa na preta e manda `torchFlicker { id, ms }` a todos (solo: direto);
- cada cliente apaga o visual da lanterna daquele jogador (`setActivated(false)` local, sem `syncItemActivated`: sem pacote e sem gastar pilha) e acende de novo no fim, se ninguém mexeu;
- no piscar, Tição aceso só por aquele facho solta na hora.

### Tarefa 6: debug

- `NOM.setBlackFog(skip)` = `setFog` com `black`: presságio, sirene preta, a preta sobe e abre em 30 s; `skip` abre já;
- `NOM.ticao()`: luzes, Tições congelados, custo da última volta (servidor) e congelados deste processo; botão no painel;
- status ganha `preta`; logs `[NOM] ticao ...` só em -debug.

### Tarefa 7: docs

- `docs/architecture/pz-api-notes.md` §29 (luz no servidor: lanterna, direção do jogador, farol, luzes fixas, escuridão do clima, piscar);
- `docs/sprints/sprint-0038-nevoa-preta/README.md` com roteiro de teste no jogo e decisões;
- `docs/sprints/README.md` e `docs/HANDOFF.md`.

### Tarefa 8: fechamento

`./run-tests.sh` verde; code review próprio do diff (MP, zumbi preso, custo, Kahlua, evidência) e correções.
