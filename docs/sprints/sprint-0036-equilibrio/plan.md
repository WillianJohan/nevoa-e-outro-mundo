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
