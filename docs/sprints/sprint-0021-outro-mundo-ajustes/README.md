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
      `renderTextureWithDepth` põe a base do recorte no centro do tile, com uma profundidade só pro
      quad (a do centro do tile, `calculateDepth(x+0,5, y+0,5, z+0,01)`; teste ligado em
      `renderIsoMarkers` 38); `IsoMarkers.renderIsoMarkers` sai em `performRenderTiles` 784, depois
      de `renderPlayers` (241) e `renderMovingObjects` (387);
      todo `d_plants_1_*` tem `MoveWithWind` (planta em pé, `tiledefinitions_erosion.tiles.txt`).
      Compensar o meio tile é impossível pelo Lua (sem float; tile inteiro anda 64/32 px) — bytecode
      B42.21.
- [x] **Chão só com decalque chato:** os 270 nomes de chão auditados no pack (só leitura,
      `scripts/audit_floor_sprites.py` → `tests/floor_sprites.lua`); nenhuma planta; todo sprite do
      pool com o conteúdo no diamante do chão — `dressing_rules_floor_pool_flat_only`,
      `dressing_rules_no_plants`.
- [x] **Chão apagado debaixo de personagem:** o losango deslocado fica centrado no canto N do tile,
      então com o pé em qualquer lugar do tile os decalques do próprio tile e dos S, E e SE alcançam o
      corpo (review). Esses 4 vão a alfa 0 e voltam quando o personagem sai: do jogador a cada tick —
      `overlays_player_tiles_clear_every_tick`; de zumbis a até 10 tiles, em rodízio —
      `overlays_zombie_tiles_clear`, com no máximo 8 zumbis lidos por tick —
      `overlays_zombie_scan_bounded`; de outro jogador do MP — `overlays_remote_player_tiles_clear`.
      O pool ainda não invade o centro dos tiles N, W e NW (heurística de vazamento, não garantia) —
      `dressing_rules_floor_pool_spares_tile_centres`.
- [x] **Fora, nada do chão de dentro nem atrás de prédio:** `overlays_outside_player_skips_interior`,
      `overlays_outside_player_skips_building_shadow` (3 tiles na diagonal = um andar na tela,
      `IsoUtils.YToScreen`); square sem chunk na conta da sombra conta livre —
      `overlays_shadow_missing_square`.
- [x] **Dentro, o prédio dele e a rua da frente; entrar e sair sem piscar:** `overlays_inside_player_sees_own_building`
      (o chão de fora atrás das paredes N/W do prédio dele fica escondido: o jogo não corta essas
      paredes; o de dentro apaga com fade ao sair), `overlays_building_doorway_no_flicker` (na porta, entrando
      e saindo a cada meio segundo, nenhum marcador perto é tirado; o chão que sai da vista libera o
      teto em vez de derrubar o raio).
- [x] **Sujeira sem xadrez:** só sprites parciais (cobertura < 50%, sem faixa de borda; tabela de
      cobertura medida) — `dressing_rules_grime_partial_only`; em manchas em toda densidade (troca
      sujo/limpo entre vizinhos < 60% do sorteio por tile, medido ~35%, em d 1/1,6/2/3,2 e três
      períodos) — `dressing_rules_grime_clusters`; dois vizinhos sujos nunca com o mesmo sprite —
      `dressing_rules_grime_no_checkerboard`; ~27% do chão, com teto — `dressing_rules_grime_rarer`;
      teto de 600 marcadores de verdade — `overlays_capped`; num marcador próprio
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

`./run-tests.sh`: `total=668 passou=668 falhou=0` (Lua), `contraste total=4 passou=4 falhou=0` e `build total=25 passou=25 falhou=0`.

## Roteiro in-game

**Antes:** `scripts/dev-sync.sh` e **recarregue o save** (o Lua novo só entra ao carregar). Jogo em
`-debug`. Console em `~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt`.

1. **Névoa.** `NOM_Debug.fog(true, true)`. **Esperado:** `[NOM] outro mundo: 196 de 196 sprites
   achados` (eram 404: o pool encolheu) e nenhuma linha com `NOM_` e `ERROR`. Em ~4 s o chão em volta
   ganha poças e rastros de sangue, rachaduras e manchas de sujeira; **nenhum arbusto, folhagem ou
   planta** saindo do chão.
2. **Por cima do jogador (prints 9 e 10).** No mesmo enquadramento dos prints (zoom de longe, campo
   aberto), andar em cima das poças e parar. **Esperado:** o chão debaixo dos pés (o tile e os três
   ao sul/leste dele) apaga na hora e volta quando você sai; nada cobre o corpo nem as pernas. Olhar
   um zumbi parado numa poça a até 10 tiles. **Esperado:** o chão debaixo dele apaga em menos de um
   segundo e nada cobre a perna. **Se** aparecer o buraco limpo andando atrás dele e incomodar:
   registrar (é o rodízio de 8 zumbis por tick).
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

- **O meio tile não é compensado.** Por bytecode não há posição em float pelo Lua. O pool fica com
  decalque chato que vaza pouco, e o corpo fica limpo apagando 4 tiles por personagem. Custo se
  errado: o chão continua meio tile acima (como na 0015) e um buraco limpo anda com cada personagem.
- **Visibilidade por prédio e sombra de prédio, não por `isCouldSee`.** O cone de visão apagaria o
  chão às costas e o faria acender e apagar ao virar. Custo se errado: chão de fora atrás de prédio
  alto (2+ andares) ainda sai em cima do telhado (passo 3).
- **Zumbis em rodízio de 8 por tick, a até 10 tiles** (review). Custo por tick limitado; a volta
  velha vale até a nova fechar. Custo se errado: com centenas de zumbis na lista, o chão debaixo de
  um zumbi andando apaga com até ~2 voltas de atraso.
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
- **05/10/2026** — Review: 4 tiles apagados debaixo de jogador, zumbis e jogadores do MP (o "nenhum
  decalque alcança" valia só com o pé no centro); prédio do próprio jogador tapa o chão de fora atrás
  dele; sujeira em manchas em toda densidade, sem repetir o sprite do vizinho; teto conta marcadores.
  Merge da main.

## Aprendizados

- **`IsoMarker` sai depois de jogador e zumbis** e, no jogo, não foi tapado por telhado: o filtro
  de "o que se vê" tem que ser do mod.
- **A posição do marcador é só inteira.** `setPos(III)` soma 0,5; não há setter em float. Erro de meio
  tile não se corrige trocando de tile (a tela anda 64/32 px por tile): se corrige escolhendo o sprite.
- **Sprite de erosão não é decalque.** `d_plants_1_*` é objeto em pé (`MoveWithWind` no
  `tiledefinitions_erosion.tiles.txt`); o recorte da textura no pack (`ox, oy, w, h` no quadro 128×256,
  diamante do chão centrado em (64, 224)) diz o que é chato sem abrir o jogo.
- **`IsoMarker` testa profundidade com um valor só, o do centro do tile.** O decalque deslocado meio
  tile acima cai em cima de quem está atrás desse ponto; o filtro do pé tem que ser do mod.
- **Teto que derruba o raio no square recusado** desaba quando aparece chão perto depois (entrar num
  prédio): o raio ia a 5 e tudo em volta sumia. Perder um tile por lote resolve.

## Pendências que a próxima sprint herda

- Prédio de 2+ andares: `SHADOW` por altura (ler o andar mais alto do prédio) se o passo 3 mostrar.
- Paredes: só voltam com desenho de sprite de tile com profundidade, ou com o recorte
  (`getPlayerCutawayFlag`) mais exclusão do jogador e dos squares da frente, aceitando o resto.

### Limites conhecidos

- **Tela dividida:** o Outro Mundo é montado pro jogador 0 (posição, prédio, raio). Os jogadores
  1–3 veem os mesmos marcadores na tela deles quando estão no andar do marcador
  (`renderIsoMarkers` desenha por tela), mas com a visibilidade do 0 e sem o chão apagado debaixo
  deles.
- **Varanda e telhado sem cômodo:** square coberto sem prédio (`getBuilding` nil) nunca ganha chão,
  nem com o jogador debaixo dele.
- **Borda da sombra:** a sombra de prédio conta a diagonal (x+k, y+k); o canto da casa e telhado
  com beiral largo podem deixar um tile de fora vazar por cima da parede ou do telhado.
- **Spike possível:** `WorldMarkers.addGridSquareMarker` desenha com profundidade de chão
  (`FBORenderWorldMarkers.useGroundDepth`), mas estica a textura num quadrado (deforma decalque
  isométrico). Vale um spike se o meio tile incomodar.

## Sessões

- 2026-10-05 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — pesquisa (bytecode, pack), plano, implementação e docs; review: chão apagado debaixo de todo personagem, prédio do jogador tapa, sujeira em toda densidade, teto de marcadores
