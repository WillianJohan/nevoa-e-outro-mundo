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

**Feito** (`shared/NOM_VariantAI.lua`, 13 testes novos `vision_*` e 3 ajustados em `tests/test_variant_ai.lua`):
- **Quem:** todo zumbi sem mira própria: o comum e o Sem-rosto (que não tem IA de mira aqui). Estalador, Corredor e Carpideira ficam como estão; o Eco também (`modData.NOM_eco`). Na vermelha, onde todo zumbi é variante, só o Sem-rosto ganha a visão curta.
- **"Quieto":** sem correr e sem sprint (andar e agachar contam como quieto a mais de 4 tiles), e sem barulho no pé dele nos últimos 180 ticks (~3 s). Barulho = `Events.OnWorldSound` a até 3 tiles do jogador (tiro, carro).
- **Som:** o cego é surdo (`useless`), então todo `OnWorldSound` solta os cegos no raio do som. O som vive 16 atualizações (`WorldSound.init`), e quem é solto dentro disso ouve.
- **Parar quem já vinha:** o rodízio pega o zumbi até uma volta depois do spot, às vezes já andando. O `useless` não para o `PathFindState`, então o `halt` da sirene entra junto (§21).
- **Useless herdado:** na névoa, com a visão curta ligada, qualquer zumbi pode ter ficado cego. O `unstick` passa a soltar todo useless local que não é do jogo (antes: só ex-Carpideira e ex-Estalador). O de outro mod num zumbi comum também cai enquanto a névoa durar (aceito).
- **Orçamento com o código de verdade** (`vision_budget_300_zombies`, mundo falso com 300 zumbis, 600 ticks): **61 chamadas por tick** parados (30 `get` + 30 `getTarget` + 1 `size`). Na multidão, **média de 129 e pior tick de 452**, contra 600 e 2700 da versão ingênua. Teto 2500.

### Tarefa 2: perambular

- Regra pura `shared/NOM_WanderRules.lua` (luajit): intervalo, grupos de 1 a 3 entre zumbis parados perto de cada jogador, ponto aleatório na região que não passa perto do jogador, rng injetável, determinístico.
- Servidor `server/NOM_Wander.lua`: decide a onda (quando e a semente); no solo aplica direto, no dedicado manda `wander` aos clientes.
- Quem simula `shared/NOM_Wander.lua`: escolhe entre os zumbis locais parados perto dos jogadores locais e manda andar (`pathToLocationF`). Pula sirene, cegos, Carpideira parada, variantes e Ecos.
- Opção de sandbox `FogWander` (ligada).

**Feito** (9 testes em `tests/test_wander_rules.lua`, 8 em `tests/test_wander.lua`, 1 em `tests/test_variants_client.lua`):
- **Números** (`NOM_WanderRules`, todos ajustáveis lá):
  - uma onda a cada 4 a 8 minutos de jogo (10 a 20 s reais com o dia de 1 h);
  - por onda, no máximo um grupo por jogador, de 1 a 3 zumbis parados juntos (a até 5 tiles de quem puxa);
  - saem de 6 a 30 tiles do jogador e andam de 8 a 20 tiles, em formação;
  - o destino fica a 8–35 tiles de todo jogador do andar, e o caminho reto não passa a menos de 5 tiles de nenhum;
  - até 8 sorteios de ponto por grupo; sem ponto bom, o grupo não sai.
- **Quem decide e quem aplica:** o servidor decide quando e a semente (`server/NOM_WanderServer.lua`, `EveryOneMinute` com `NOM_World.fog`, que só abre depois da fuga da sirene). Quem simula escolhe entre os zumbis locais parados perto dos jogadores locais (`shared/NOM_Wander.lua`): no solo, o próprio processo; no dedicado, o comando `wander` vai a todos os clientes. O alvo do zumbi não viaja (pz-api-notes §3.3), então "parado e sem alvo" só o dono sabe.
- **Parado:** sem alvo, sem andar (`isMoving`), sem useless, local, vivo, não Eco, não variante, nem cego, nem vigiado, nem Carpideira parada, nem congelado pela sirene. Com a sirene ativa não sai onda.
- **Chão:** o destino passa pelo `NOM_SemRosto.floorOk` (carregado, livre, sem água).
- **Andar:** `z:pathToLocationF(x + 0,5, y + 0,5, z)`, com evidência no bytecode e no menu de debug vanilla (pz-api-notes §27).
- **Custo da onda com 300 zumbis:** 404 chamadas com todos perto (a coleta para em `SCAN_MAX` = 40 candidatos, a partir de um ponto sorteado da lista) e 1201 com todos longe (a lista inteira: `get`, `getTarget`, `getX`, `getY`). Abaixo do teto de 2500, uma vez a cada 4–8 minutos de jogo.

### Tarefa 3: debug

- `NOM.wander()` (força uma onda; o servidor decide) e `NOM.blind()` (contagem de cegos e vigiados neste processo), com botão no `NOM.panel()` e chaves PTBR + EN.

**Feito** (2 testes em `tests/test_debug.lua`, o parse em `tests/test_debug_rules.lua`, botões em `tests/test_debug_panel.lua`):
- `NOM.wander()` manda `op = "wander"` ao servidor (`ops.wander`), que recusa sem névoa aberta e responde `[NOM] debug perambular onda semente=N`.
- `NOM.blind()` imprime `[NOM] debug visão curta ligada=... raio=... cegos=... vigiados=... estaladores=...` e a última onda aplicada neste processo (`[NOM] debug perambular última zumbis=... candidatos=... jogadores=... lista=...`).
- Painel: linha nova com "Onda de perambular" e "Cegos da visão curta no console" (`UI_NOM_Debug_Wander`, `UI_NOM_Debug_Blind`).

### Tarefa 4: docs

- Notas por tarefa aqui; pz-api-notes (seção nova); `README.md` com roteiro de teste no jogo; `docs/sprints/README.md`; HANDOFF.

**Testes (2026-10-06):** `./run-tests.sh` verde: 1048 testes Lua (eram 1014; a suíte Lua rodou 3 vezes seguidas, sem falha de ordem do `pairs`), 9 de contraste, 11 do Outro Mundo, os do mod3 e 29 de build.

**Feito:** [pz-api-notes §27](../../architecture/pz-api-notes.md#27-visão-curta-e-perambular-na-névoa-sprint-0036) (APIs novas, linhas no resumo por mecânica, UNKNOWN 20), [README.md](README.md) com decisões e roteiro, linha da 0036 em `docs/sprints/README.md`, seção "Em andamento" no HANDOFF.
