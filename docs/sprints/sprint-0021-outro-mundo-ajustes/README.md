# Sprint 0021 — Outro Mundo: correções vistas no jogo

| Campo | Valor |
|-------|-------|
| Status | em teste |
| Branch | `sprint/0021-outro-mundo-ajustes` |
| Plano | [plan.md](plan.md) |
| GDD | [atmosphere.md](../../gdd/atmosphere.md#outro-mundo-sangrento-só-na-névoa), [art-direction.md](../../gdd/art-direction.md#o-outro-mundo-sangrento-sprint-0015), [Overview.md](../../gdd/Overview.md#decisões-do-autor) |
| ADR | [ADR-015](../../architecture/adr-015-outro-mundo-sangrento.md#emenda-de-2026-10-05--sprint-0021-o-que-o-jogo-mostrou) (emendada) |

## Objetivo

Na névoa, o chão do Outro Mundo fica no chão: nada por cima do jogador, nada em cima do telhado,
sujeira que não lê como xadrez; as paredes ficam desligadas com o porquê escrito.

Evidência do Johan (05/10/2026, prints 6, 7, 9 e 10): a parede desenhada pintava de preto as
paredes que o jogo corta e passava por cima do jogador e dos móveis (hotfix `WALLS = false` na
main); com o jogador fora, musgo e plantas do chão de dentro da casa flutuavam em cima do telhado;
a sujeira formava losangos cinza, um por tile; um arbusto cobria o corpo do jogador e sangue e
plantas cobriam as pernas ("os sprites aparecem em cima do jogador... vc deve tá usando TODOS os
tiles do jogo").

## Critérios de aceite

- [x] **Causa com evidência** ([pz-api-notes §16.5](../../architecture/pz-api-notes.md#165-o-que-o-jogo-mostrou-sprint-0021)):
      `IsoMarker.setPos(III)` é o único setter de posição (`+0,5`, `+0,5`, `+0,01`) e
      `renderTextureWithDepth` põe a base do recorte no centro do tile; `IsoMarkers.renderIsoMarkers`
      sai em `performRenderTiles` 784, depois de `renderPlayers` (241) e `renderMovingObjects` (387);
      todo `d_plants_1_*` tem `MoveWithWind` (planta em pé, `tiledefinitions_erosion.tiles.txt`).
      Compensar o meio tile é impossível pelo Lua (sem float; tile inteiro anda 64/32 px) — bytecode
      B42.21.
- [x] **Chão só com decalque chato:** os 270 nomes de chão auditados no pack (só leitura,
      `scripts/audit_floor_sprites.py` → `tests/floor_sprites.lua`); nenhuma planta; todo sprite do
      pool com o conteúdo no diamante do chão — `dressing_rules_floor_pool_flat_only`,
      `dressing_rules_no_plants`.
- [x] **Nenhum decalque alcança um personagem:** desenhado como o marcador desenha (base no centro,
      meio tile acima), nenhum pixel do pool cai na zona de um personagem em pé nos tiles N, W ou NW
      (pela simetria, o decalque dos tiles S/E de alguém não o alcança) —
      `dressing_rules_floor_pool_reaches_no_character`; o do tile do jogador fica apagado a cada
      tick e volta quando ele sai — `overlays_player_tile_clear_every_tick`.
- [x] **Fora, nada do chão de dentro nem atrás de prédio:** `overlays_outside_player_skips_interior`,
      `overlays_outside_player_skips_building_shadow` (3 tiles na diagonal = um andar na tela,
      `IsoUtils.YToScreen`); square sem chunk na conta da sombra conta livre —
      `overlays_shadow_missing_square`.
- [x] **Dentro, o prédio dele e a rua; entrar e sair sem piscar:** `overlays_inside_player_sees_own_building`
      (o de dentro apaga com fade ao sair), `overlays_building_doorway_no_flicker` (na porta, entrando
      e saindo a cada meio segundo, nenhum marcador perto é tirado; o chão que sai da vista libera o
      teto em vez de derrubar o raio).
- [x] **Sujeira sem xadrez:** só sprites parciais (cobertura < 50%, sem faixa de borda; tabela de
      cobertura medida) — `dressing_rules_grime_partial_only`; em manchas (troca sujo/limpo entre
      vizinhos < 60% do sorteio por tile) — `dressing_rules_grime_clusters`; vizinhos com a mesma
      sujeira < 15% e nenhum sprite cheio repetido lado a lado — `dressing_rules_grime_no_checkerboard`;
      mais rara (10–35% do chão na densidade 1) — `dressing_rules_grime_rarer`; num marcador próprio
      com metade do alfa — `overlays_grime_own_marker_lighter`, `overlays_grime_marker_follows_entry`.
- [x] **Paredes: decisão com evidência** — pesquisado o recorte (`getPlayerCutawayFlag`, bits 1/2,
      `FBORenderCutaways.doCutawayVisitSquares`): resolve a laje preta, mas o evento sai depois do
      `renderPlayers` e o fantasma não tem profundidade; jogador, outros jogadores e objetos de outros
      squares na frente só sairiam por geometria aproximada. Ficam desligadas
      ([ADR-015, emenda](../../architecture/adr-015-outro-mundo-sangrento.md#emenda-de-2026-10-05--sprint-0021-o-que-o-jogo-mostrou));
      `overlays_walls_off_by_default`.
- [x] O que já valia continua: densidade, fade, teto servindo o perto, determinismo, nada no mapa,
      orçamento — suíte da sprint 0015 verde (`overlays_*`, `dressing_rules_*`); textos sem musgo,
      trepadeira e paredes — `translations_overlays_promise_only_the_floor`.
- [ ] Prints 9 e 10 sem nada por cima do jogador — **falta o jogo:** passo 2.
- [ ] Print 7 sem chão em cima do telhado, e sem xadrez — **falta o jogo:** passos 3 e 4.
- [ ] Print 6 sem laje preta (paredes desligadas) e entrar/sair de casa sem piscar — **falta o jogo:** passo 5.

`./run-tests.sh`: `total=665 passou=665 falhou=0` (Lua), `contraste total=4 passou=4 falhou=0` e `build total=25 passou=25 falhou=0`.

## Roteiro in-game

**Antes:** `scripts/dev-sync.sh` e **recarregue o save** (o Lua novo só entra ao carregar). Jogo em
`-debug`. Console em `~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt`.

1. **Névoa.** `NOM_Debug.fog(true, true)`. **Esperado:** `[NOM] outro mundo: 196 de 196 sprites
   achados` (eram 404: o pool encolheu) e nenhuma linha com `NOM_` e `ERROR`. Em ~4 s o chão em volta
   ganha poças e rastros de sangue, rachaduras e manchas de sujeira; **nenhum arbusto, folhagem ou
   planta** saindo do chão.
2. **Por cima do jogador (prints 9 e 10).** No mesmo enquadramento dos prints (zoom de longe, campo
   aberto), andar em cima das poças e parar. **Esperado:** o chão debaixo dos pés apaga na hora e
   volta quando você sai; nada cobre o corpo nem as pernas. Parar ao lado (norte, sul, leste, oeste)
   de uma poça. **Esperado:** a poça não sobe na perna. **Se** um zumbi parado numa poça ficar com
   o pé coberto de sangue: registrar com print (o tile de zumbi não é apagado; pendência).
3. **Telhado (print 7).** Do lado de fora de uma casa de um andar, no enquadramento do print 7 (casa
   à esquerda, quintal). **Esperado:** o telhado e a parede da casa limpos; o chão de fora com sangue
   até perto da casa, exceto a faixa de ~3 tiles atrás dela (norte/oeste), que fica limpa. **Se**
   aparecer sangue em cima de telhado de casa de **dois andares**: registrar (a sombra conta só 3
   tiles; subir pra 6 é o botão `NOM_FogOverlays.SHADOW`).
4. **Xadrez (print 7).** No mesmo quintal, olhar a grama e o calçamento. **Esperado:** sujeira em
   manchas irregulares, mais clara que o sangue; nenhum losango cinza do tamanho de um tile, nenhuma
   grade de tiles aparecendo.
5. **Dentro de casa (print 6).** Entrar na casa. **Esperado:** nenhuma laje preta nas paredes, nada
   desenhado em parede; o chão de dentro ganha sangue com fade em ~4 s e o quintal continua visível.
   Ficar na porta, um passo pra dentro e um pra fora, várias vezes. **Esperado:** nada pisca; o de
   dentro acende e apaga devagar. `NOM_Debug.status()` com `paredes=0`.
6. **Custo.** Densidade 2 e névoa vermelha, andar 30 s entrando e saindo de casas. **Esperado:** sem
   queda de FPS perceptível contra a densidade 0.

## Rulings do Claude

- **O meio tile não é compensado, é evitado na escolha do sprite.** Por bytecode não há posição em
  float pelo Lua; o pool fica com o que, deslocado, não alcança personagem. Custo se errado: o chão
  continua meio tile acima (como na 0015), sem tocar em ninguém.
- **Visibilidade por prédio e sombra de prédio, não por `isCouldSee`.** O cone de visão apagaria o
  chão às costas e o faria acender e apagar ao virar. Custo se errado: chão de fora atrás de prédio
  alto (2+ andares) ainda sai em cima do telhado (passo 3).
- **Só o tile do jogador é apagado, não o de zumbis.** Ler a lista de zumbis todo tick custa caro; o
  pool já não alcança tiles vizinhos. Custo se errado: zumbi parado em poça com o pé pintado (passo 2).
- **Musgo e trepadeira saem de vez** (planta em pé e parede desligada). Pra manter o enquadramento
  de 7×7 mudado, a rachadura sobe de 0,35 pra 0,45. Custo se errado: "erosão no máximo" mais fraca.
- **Paredes desligadas** (não religadas com recorte): ver ADR-015. Custo se errado: o Outro Mundo
  sem sangue nas paredes até alguém achar desenho de tile com profundidade.
- **Checkpoints datados de 05/10**, o dia da evidência (o brief pedia 04/10, antes dos prints).

## Checkpoints

- **05/10/2026** — Sprint aberta com os prints 6, 7, 9 e 10. Bytecode: posição e desenho do
  `IsoMarker`, ordem do quadro (`performRenderTiles`), recorte de parede por jogador, `YToScreen`.
  Auditoria dos sprites de chão no pack. Plano escrito.
- **05/10/2026** — Chão só de decalque chato e seguro; sujeira em manchas num marcador próprio; só o
  chão que o jogador vê (prédio, sombra de prédio); tile do jogador apagado; paredes desligadas com o
  porquê. Docs: ADR-015 emendada, pz-api-notes §16.5, GDD, traduções. Em teste.

## Aprendizados

- **`IsoMarker` é overlay, não chão.** Sai depois de jogador e zumbis e, no jogo, não é tapado por
  telhado, parede nem personagem. Tudo que ele desenha aparece: o filtro de "o que se vê" tem que ser
  do mod.
- **A posição do marcador é só inteira.** `setPos(III)` soma 0,5; não há setter em float. Erro de meio
  tile não se corrige trocando de tile (a tela anda 64/32 px por tile): se corrige escolhendo o sprite.
- **Sprite de erosão não é decalque.** `d_plants_1_*` é objeto em pé (`MoveWithWind` no
  `tiledefinitions_erosion.tiles.txt`); o recorte da textura no pack (`ox, oy, w, h` no quadro 128×256,
  diamante do chão centrado em (64, 224)) diz o que é chato sem abrir o jogo.
- **Teto que derruba o raio no square recusado** desaba quando aparece chão perto depois (entrar num
  prédio): o raio ia a 5 e tudo em volta sumia. Perder um tile por lote resolve.

## Pendências que a próxima sprint herda

- Zumbi parado em decalque: pé coberto? (passo 2). Se sim, apagar também o tile de zumbi perto, em
  rodízio.
- Prédio de 2+ andares: `SHADOW` por altura (ler o andar mais alto do prédio) se o passo 3 mostrar.
- Paredes: só voltam com desenho de sprite de tile com profundidade, ou com o recorte
  (`getPlayerCutawayFlag`) mais exclusão do jogador e dos squares da frente, aceitando o resto.

## Sessões

- 2026-10-05 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — pesquisa (bytecode, pack), plano, implementação e docs
