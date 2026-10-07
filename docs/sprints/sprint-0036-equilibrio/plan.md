# Sprint 0036: Equilíbrio (plano de implementação)

> Para agentes: executar tarefa por tarefa, com TDD. Code review só no fim da entrega (decisão do Johan, 2026-10-06).

**Objetivo:** na névoa branca e na vermelha ([spec §5](../../superpowers/specs/2026-10-06-modelo-novo-design.md#5-comportamento-na-branca-e-na-vermelha)):
- o zumbi enxerga só ~4 tiles; a audição continua normal (som atrai);
- de tempos em tempos, grupos de 1 a 3 zumbis parados perto de cada jogador andam até pontos aleatórios da região, nunca direto ao jogador: encontro frequente, sem horda;
- o custo da visão curta com ~300 zumbis carregados é critério de aceite (spec §11).

Fora: gritos dos monstros e de gente e o crepitar (ficam pra depois, spec §5).

**Decisões do Johan (spec §5 e §10):**
- A visão menor reaproveita a cegueira do Estalador: o jogo trava o raio de visão do zumbi em 10–20 tiles (`IsoZombie.updateVisionRadius`, bytecode; pz-api-notes §3.2).
- Medir primeiro. Plano B, se o custo for inaceitável: piso de 10 tiles com o pior degrau de visão, mostrado ao Johan antes de decidir.
- O servidor decide o perambular; a escolha dos grupos e dos pontos é regra pura testada.

## Restrições globais

As do `AGENTS.md`:
- Kahlua (sem `next`, `//`, `goto`, operador de bit, `table.unpack`, `math.random`);
- o servidor decide e quem simula aplica (ADR-002/005); dono do zumbi é `z:isLocal()` (pz-api-notes §24);
- evidência de API;
- fakes fiéis;
- textos PTBR + EN;
- PT-BR com acento;
- todo comando `NOM.*` com botão no `NOM.panel()`.

## Ordem

| # | Tarefa | Depende de |
|---|---|---|
| 0 | Medição: custo da cegueira em todo zumbi comum com ~300 zumbis | — |
| 1 | Visão de ~4 tiles (em fatias, se a medição pedir) | 0 |
| 2 | Perambular: regra pura + servidor + quem simula | — |
| 3 | Debug: comandos `NOM.*` e botões no painel | 1, 2 |
| 4 | Docs da sprint, pz-api-notes, roteiro de teste | todas |

---

### Tarefa 0: medição

Saída: números nesta seção (chamadas ao Java por tick e trabalho Lua) no mundo falso com 300 zumbis, comparando:
- hoje (só variantes no `OnZombieUpdate`);
- a cegueira estendida por frame a todo zumbi comum (o jeito ingênuo);
- uma versão em fatias com orçamento.

Teto de referência: 2500 chamadas por atualização (Outro Mundo, pz-api-notes §16).

**Feito.** Script: [medicao.lua](medicao.lua) (`luajit -joff docs/sprints/sprint-0036-equilibrio/medicao.lua`). Mundo falso com 300 zumbis comuns, 600 frames. Dois cenários: "parados" (ninguém com alvo) e "multidão" (os 300 com o jogador de alvo, a 6–10 tiles, o pior caso). A pergunta por zumbi é a da cegueira: tem jogador de alvo, ele está quieto e a mais de 4 tiles?

| Versão | Parados (chamadas/tick) | Multidão (chamadas/tick) | Lua no luajit sem JIT (µs/tick, parados / multidão) |
|---|---|---|---|
| Hoje (só variantes no `OnZombieUpdate`) | 0 | 0 | 9 / 12 |
| Ingênua: todo zumbi comum, todo frame | 600 | 2700 | 27 / 80 |
| Em fatias, 20 por tick | 61 | 201 | 12 / 15 |
| Em fatias, 30 por tick | 91 | 301 | 12 / 18 |
| Em fatias, 50 por tick | 151 | 501 | 14 / 24 |

**Como o `NOM_VariantAI` itera hoje:** pelo `OnZombieUpdate`, que o jogo chama pra todo zumbi a cada frame. O zumbi comum sai na primeira linha com três consultas de tabela Lua e nenhuma chamada Java (teste `ai_common_zombie_no_java_calls`). Só variante, cego e Carpideira parada seguem.

**Conclusão:**
- A versão ingênua não serve: a multidão passa do teto de 2500 em todo frame, não só numa atualização.
- Em fatias (`OnTick`, `VISION_BATCH` zumbis por tick em volta na lista, como o rodízio da sirene) o custo fica em ~1/7 da ingênua, sem tocar no `OnZombieUpdate` do comum. A latência é uma volta na lista: 300/30 = 10 ticks (~0,17 s a 60 FPS, ~0,33 s a 30 FPS) até um zumbi que acabou de mirar no jogador ficar cego.
- Escolhido: **30 por tick**, com a posição e o "quieto" de cada jogador guardados uma vez por tick (some o custo do jogador na multidão).
- Quem já está cego não é conferido todo frame: a cada `CHECK_FRAMES` (10) frames, só a distância. Depois da janela, `WATCH_FRAMES` (30) frames de vigia por frame (só `getTarget`) pegam a volta do spot.
- O plano B (piso de 10 tiles) não é preciso. O número final com o código de verdade está na Tarefa 1.

### Tarefa 1: visão de ~4 tiles

- Teste primeiro (`tests/test_variant_ai.lua`): zumbi comum com jogador a 8 tiles, quieto, não persegue; a 3 tiles persegue; correndo persegue; tiro (som) perto acorda; variantes iguais a antes; zumbi remoto intocado; névoa desligada intocado; orçamento por tick com 300 zumbis.
- Constante do raio fácil de ajustar e opção de sandbox (`FogZombieVision`, 0 desliga), com chaves PTBR + EN.

### Tarefa 2: perambular

- Regra pura `shared/NOM_WanderRules.lua` (luajit): intervalo, grupos de 1 a 3 entre zumbis parados perto de cada jogador, ponto aleatório na região que não passa perto do jogador, rng injetável, determinístico.
- Servidor `server/NOM_Wander.lua`: decide a onda (quando e a semente); no solo aplica direto, no dedicado manda `wander` aos clientes.
- Quem simula `shared/NOM_Wander.lua`: escolhe entre os zumbis locais parados perto dos jogadores locais e manda andar (`pathToLocationF`). Pula sirene, cegos, Carpideira parada, variantes e Ecos.
- Opção de sandbox `FogWander` (ligada).

### Tarefa 3: debug

- `NOM.wander()` (força uma onda; o servidor decide) e `NOM.blind()` (contagem de cegos e vigiados neste processo), com botão no `NOM.panel()` e chaves PTBR + EN.

### Tarefa 4: docs

- Notas por tarefa aqui; pz-api-notes (seção nova); `README.md` com roteiro de teste no jogo; `docs/sprints/README.md`; HANDOFF.
