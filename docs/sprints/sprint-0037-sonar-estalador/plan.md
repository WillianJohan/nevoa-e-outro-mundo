# Sprint 0037: Sonar do Estalador (plano de implementação)

> Para agentes: executar tarefa por tarefa, com TDD. Code review só no fim da entrega (decisão do Johan, 2026-10-06).

**Objetivo** ([spec §6](../../superpowers/specs/2026-10-06-modelo-novo-design.md#6-sonar-do-estalador)):
- o estalo do Estalador (em média a cada 2 min de jogo) solta um anel que avança 8 tiles;
- o anel que passa por um jogador em pé ou andando faz o Estalador achá-lo; agachado e parado, o anel passa. Quem decide é o servidor, igual pra todos;
- com o mod3, o anel empurra a névoa (fonte radial no `FlowGrid`) e a abre por um instante; sem o mod3, um anel discreto na tela;
- tempo e alcance do anel são regra pura testada (spec §11); o `FlowGrid` ganha teste da fonte radial do sonar.

Fora: som novo (o estalo já existe: `NOM_EstaladorClick`), facelift do Estalador (0041+).

## O que já existe

- **Estalo:** `NOM_VariantAI.clicks`, no `EveryOneMinute`, em todo processo que tem o zumbi (solo e cliente de MP): cada Estalador estala com chance 1/2 por minuto de jogo (média de 2 min), com `playSoundLocal`. Cada cliente sorteia o seu: no MP os estalos não batem entre clientes. Como o anel precisa ser o mesmo pra todos, **o estalo passa pro servidor** e vira o próprio sonar.
- **Cegueira do Estalador:** `estalador()` no `NOM_VariantAI`: com o alvo agachado e sem correr, `useless` + `setTarget(nil)` numa janela de 60 frames. O Estalador não entra na visão curta da 0036 (o rodízio pula variantes).
- **Caçar alguém à força:** `z:spotted(p, true)` no dono, como o grito da Carpideira (pz-api-notes §13.2).
- **Fonte radial no mod3:** `FlowGrid.blast` (tiro e explosão, achados pelo próprio Java na lista de sons). Não há canal Lua → fonte: a 0037 cria `NOMRender_sonar(x, y, z)`.

## Restrições globais

As do `AGENTS.md`:
- Kahlua (sem `next`, `//`, `goto`, operador de bit, `table.unpack`, `math.random`);
- o servidor decide e quem simula aplica (ADR-002/005); dono do zumbi é `z:isLocal()` (pz-api-notes §24);
- evidência de API; fakes fiéis; textos PTBR + EN; PT-BR com acento;
- todo comando `NOM.*` com botão no `NOM.panel()`;
- nada do mod3 derruba o jogo (captura `Throwable`, loga e se desliga).

## Ordem

| # | Tarefa | Depende de |
|---|---|---|
| 1 | Regra pura `shared/NOM_SonarRules.lua` + testes | — |
| 2 | Servidor decide (estalo, anel, quem foi achado) + quem simula aplica (Estalador acha) | 1 |
| 3 | Visual sem mod3: anel na tela (`client/NOM_SonarFx.lua`, textura por `gen_textures.py`) | 1 |
| 4 | mod3: `NOMRender_sonar`, fonte radial que se expande no `FlowGrid` + teste Java | 1 |
| 5 | Debug `NOM.sonar()` + botão no painel | 2, 3 |
| 6 | Docs: README com roteiro, pz-api-notes, `docs/sprints/README.md`, GDD | todas |
| 7 | `./run-tests.sh` verde (suíte Lua 3 vezes) | todas |

---

### Tarefa 1: regra pura

Teste primeiro (`tests/test_sonar_rules.lua`):
- raio do anel no tempo (0 no começo, 8 em 1,5 s, preso em 8 depois); fim do anel;
- o anel "passa" por quem está entre o raio do tick anterior e o de agora (inclusive no centro, no primeiro tick), só no mesmo andar;
- **em pé ou andando** é achado; **agachado e parado** passa; agachado andando é achado;
- "andando" pelo deslocamento entre amostras de posição;
- estala com chance 1/`CLICK_ODDS` por minuto (média 2 min), só com jogador perto (`SEND_RANGE`);
- validação da mensagem do servidor (número finito, andar inteiro, lista de achados);
- visual: alfa sobe, segura e some depois do fim;
- os números do Lua batem com os do Java (`Sonar.java`).

### Tarefa 2: servidor e quem simula

- `server/NOM_SonarServer.lua`: no `EveryOneMinute`, com a névoa aberta, cada Estalador vivo (sorteio pelo `persistentOutfitID`, como o grito do Corredor) estala com chance 1/2 se há jogador a até `SEND_RANGE`. O anel anda no `OnTick` em tempo real; quem ele cruza no mesmo andar é conferido (agachado pelo `isSneaking`, que viaja no pacote do jogador; andando pela posição amostrada).
- Achado: no solo, direto; no dedicado, `sonarFound { id, pl }` a todos, e o dono do Estalador aplica.
- `NOM_VariantAI.sonarFound(z, p)`: no dono, solta a cegueira, `spotted(p, true)` e abre a janela `FOUND_MS` em que o Estalador não é cegado de novo.
- O estalo (som) sai do `NOM_VariantAI.clicks` e vira parte do anel (`shared/NOM_Sonar.lua`, tocado no ponto).
- Custo travado em teste: chamadas por tick com anel e sem anel, e a passada do minuto com 300 zumbis.

### Tarefa 3: visual sem mod3

- `client/NOM_SonarFx.lua` desenha a elipse do anel no overlay de tela (`NOM_ScreenFx.extra`), com a posição projetada por `isoToScreenX/Y` (pz-api-notes §25). Uma textura de anel (`NOM_SonarAnel.png`, `scripts/gen_textures.py`), 1 desenho por anel.
- Com o mod3 aceitando o anel (`NOMRender_sonar` devolve verdadeiro), não desenha.
- Custo por quadro travado em teste (0 chamadas sem anel).

### Tarefa 4: mod3

- `Sonar.java` (puro): anéis vivos e a faixa varrida a cada lote de passos.
- `FlowGrid.sonar(x, y, rDentro, rFora)`: leva parte da névoa da faixa varrida pra logo à frente, sem criar nem sumir massa (como o `blast`), sem atravessar interior nem sólido.
- `NOMRender_sonar(x, y, z)`, com `Throwable` capturado.
- `tests/java/FlowSonarTest.java` no `tests/test_mod3_flow.sh`.

### Tarefa 5: debug

- `NOM.sonar()`: o servidor força o estalo do Estalador mais perto (mesmo andar, até 60 tiles); sem Estalador, um anel na posição do jogador (só visual). Botão no painel, chaves PTBR + EN.

### Tarefa 6: docs

- README da sprint com decisões e roteiro (botões, linhas de log), pz-api-notes §28, `docs/sprints/README.md`, GDD de monstros e HANDOFF.

---

## Resultado

| Tarefa | Commit | Testes novos |
|---|---|---|
| 0 plano | `1b720b3` | — |
| 1 regra pura | `fd01f41` | `test_sonar_rules.lua` (11, com o retângulo da tela que entrou na 3) |
| 2 servidor e quem simula | `9b79071` | `test_sonar.lua` (10, com o custo), 6 em `test_variant_ai.lua` (saíram os 4 do estalo local), 1 em `test_variants_client.lua` |
| 3 visual sem mod3 | `31c1ebe` | `test_sonar_fx.lua` (7, com o custo por quadro e o asset) |
| 4 mod3 | `361c535` | `tests/java/FlowSonarTest.java` (6), `test_mod3_sonar.lua` (3, contrato Lua ↔ Java) |
| 5 debug | `705753b` | 1 em `test_debug.lua`, 1 linha em `test_debug_rules.lua`, botão em `test_debug_panel.lua` |

- **A fonte radial move densidade, não velocidade:** um impulso radial pra fora é divergência pura e
  a projeção de pressão do `FlowGrid.step` o apaga no mesmo passo. Por isso a frente leva névoa
  como o `blast`: o monte anda com a frente porque a cada passo a faixa varrida inclui o que a frente
  de antes depositou.
- **Soma de float:** 30 passos de 0,05 s podem dar um fio abaixo de 1,5 s, e o anel do mod3 vive um
  passo a mais (o teste conta com isso).
- **`./run-tests.sh` verde:** Lua 1104/1104 (três vezes), contraste 9, Outro Mundo 11, mod3
  (profundidade, contrato, núcleo Java com 6 do sonar, shaders) e build 29. O jar do mod3 foi
  recompilado e assinado (`scripts/build-mod3.sh`).

## Code review final

Duas decisões do Johan (2026-10-06) e 11 achados do review, cada um com teste que falha antes.

| # | Achado | Correção | Commit |
|---|---|---|---|
| 4 | Ritmo (decisão): o estalo era chance 1/2 por minuto de jogo, todos no mesmo tick e preso ao tamanho do dia | cada Estalador estala num intervalo aleatório de 5 a 30 s reais, sorteado a cada estalo; relógio do `OnTick` que para na pausa; lista lida a cada 1 s (`sonar_click_rhythm_*`) | `0f73fd1` |
| 7 | Quem anda na direção do anel pulava a frente entre dois ticks | o cruzamento usa a posição do tick anterior; cada anel acha cada jogador uma vez (`sonar_runner_never_jumps_front`). Junto com o 4: o ritmo novo tirou a sorte de fase do teste do agachado andando e o expôs | `0f73fd1` |
| 1 | Teto de 8 anéis: o mais velho saía depois de anunciado e não achava ninguém | sai só anel que já não alcança jogador (além de `REACH` = 17 tiles), o mais longe; senão o novo não nasce nem é anunciado (`sonar_cap_*`, com 10 Estaladores) | `97260d5` |
| 2 | O cliente aceitava anel de qualquer lugar do mapa | o servidor manda `sonar` só a quem está a até 40 tiles (`sendServerCommand(jogador, ...)`); o cliente descarta anel longe de todo jogador local | `db0ccc4` |
| 3 | Casa protege (decisão) | `sq:isOutside()` e `sq:getBuilding()` do Estalador (no estalo) e do jogador (no cruzamento): um dentro e o outro fora, ou casas diferentes, não acha (`sonar_house_shelters`) | `48c8869` |
| 6 | Objeto do zumbi reaproveitado no meio do anel | o anel guarda o `persistentOutfitID` e confere antes de aplicar; o `sonarFound` leva o `pid` e o dono confere | `917369d` |
| 5 | Useless herdado na troca de posse engolia o `spotted` | `sonarFound` solta o useless que não é do jogo nem da sirene | `c0a4031` |
| 10 | A janela de 10 s vencia com o jogo pausado | `found[z].left` desconta pelo `NOM_FogEventRules.countdown` (parado na pausa); teste no dono e no servidor solo | `52a86f8` |
| 8 | A névoa do sonar era depositada em todo o anel à frente e saltava parede | cada célula leva a névoa na própria direção radial e para em face fechada, sólido e interior; massa conservada (`FlowSonarTest.noneBehindWall`); jar recompilado | `2db6fd8` |
| 11 | O contrato Lua ↔ Java só comparava constantes | `tests/sonar_curve.csv`, lido pelos dois testes (raio em t) | `e3591b2` |
| 9 | Custo comparado errado no pz-api-notes | o passo na escala 2 é ~5,6 ms; o sonar, ~3 % dele | docs |

- **Limite documentado:** o `Flow` roda no máximo 2 passos de 0,05 s por quadro; abaixo de 10 FPS a
  onda na névoa fluida atrasa (quem acha é o servidor, só o desenho atrasa).
- **Pausa sem anel** é conferida só na amostra (a cada 250 ms): o ritmo tem precisão de ~0,25 s.
- **`./run-tests.sh` verde depois do review:** Lua 1120/1120 (três vezes), contraste 9, Outro Mundo
  11, mod3 (profundidade, contrato, núcleo Java com 8 do sonar, shaders) e build 29. Jar do mod3
  recompilado e assinado.
