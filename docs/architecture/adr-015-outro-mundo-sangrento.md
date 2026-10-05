# ADR-015 — Outro Mundo sangrento: chão por IsoMarker com camadas, paredes por desenho no quadro

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-05 |
| Emenda | [ADR-007](adr-007-sem-rosto-e-atmosfera-local.md) (os overlays da névoa deixam de ser "manchas aos poucos no chão" e viram o cenário inteiro, chão e paredes). Emendada em 2026-10-05, sprint 0021 ([abaixo](#emenda-de-2026-10-05--sprint-0021-o-que-o-jogo-mostrou)) |

Número 015 pra casar com a sprint (a 0014 corre em paralelo e pode abrir a sua ADR).

## Contexto

Johan (05/10): "o Outro Mundo eu imaginei com bastante sangue e com a erosão no máximo". As
manchas da sprint 0005 (até 40, uma a cada 1,5 s, a 3–12 tiles) passaram despercebidas. A regra
de sempre vale: nada no save nem na rede (ADR-007). O que o B42.21 dá
([pz-api-notes §16](pz-api-notes.md#16-outro-mundo-sangrento-sprint-0015)):

- Sangue e erosão de verdade (`addBlood*`, `IsoFloorBloodSplat`, `wallBloodSplats`, objetos do
  `ErosionMain`), `setOverlaySprite`, `AttachedAnimSprite` e objeto novo no square: **todos vão
  pro save** (`IsoObject.save`, `IsoGridSquare.save`, `IsoChunk`), e o overlay ainda manda pacote.
- `IsoMarkers` (já usado): lista em memória; aceita uma **tabela de texturas** por marcador
  (vanilla: `ISBaseIcon.lua:579`); desenha com profundidade, mas **centrado no meio do tile com
  a base no meio**, não na posição do tile: serve pra chão (fica meio tile pra cima), não pra
  parede (o recorte da textura de parede cai fora da parede).
- `Events.RenderOpaqueObjectsInWorld` (todo quadro, no meio do desenho do mundo) +
  `IsoSprite:RenderGhostTileColor` (o fantasma da construção): desenha um sprite de tile **na
  posição certa** de tile, com alfa e tinta, sem tocar em nada. Mas sem teste de profundidade e
  sem a luz do square.

## Decisão

1. **Regras puras** (`shared/NOM_DressingRules.lua`): por square e período de névoa, até 4
   camadas de chão (sujeira, rachadura, musgo por baixo; sangue por cima: 3 no miolo de uma poça,
   2 na borda, 1 no rastro ou respingo) e um sprite por parede N/W (sangue 45%, sujeira 25%,
   rachadura 15%, trepadeira 15%). Poças: no máximo uma por célula de 7×7, com rastro.
   Calibrado pro zoom de perto do print do Johan (névoa vermelha, ~7×7 tiles na tela): na
   densidade 1, ~85% do chão muda e todo enquadramento desses tem sangue
   (`dressing_rules_visible_at_close_zoom`). Hash do
   `NOM_VariantRules` (ADR-006): nada guardado, andar e voltar dá o mesmo desenho.
2. **Densidade** = opção do jogador `FogOverlayDensity` (0–2, padrão 1, Opções > Mods, na página
   da sprint 0013) × 1,6 na névoa vermelha. `FogOverlays` (sandbox) continua o liga/desliga do
   servidor. Por jogador porque é só tela: cada um aguenta o quanto quer.
3. **Chão:** um `IsoMarker` por square com a tabela de nomes, cor = luz do square
   (`getLightLevel`, com piso de 50% pra não sumir no escuro), relida em rodízio.
4. **Parede:** lista em Lua desenhada no `RenderOpaqueObjectsInWorld` do jogador 0, no andar dele,
   com `RenderGhostTileColor(x, y, z, l, l, l, alfa)`. Pra compensar a falta de profundidade, só
   parede **limpa** (no square só piso e parede, sem batente de porta ou janela), **de frente** (N
   com o jogador ao sul, W com ele a leste: a outra face o jogo corta) e **à vista** (`isCouldSee`,
   relido a cada atualização). Parede de costas nem entra na reserva (não ocupa o teto); entra
   quando o jogador passa pro outro lado. Fora da vista (cone, porta fechada) a parede só apaga
   (fade) e fica na reserva: ao virar, volta. Em rodízio (12 por atualização) cada parede é conferida de novo e sai
   se a parede sumiu ou ganhou móvel ou batente.
5. **Varredura** em lotes de 80 squares a cada 10 ticks, do mais perto ao mais longe no raio de
   25; a regra pura antes de qualquer chamada ao Java. Teto: 600 marcadores e 120 paredes, **a
   serviço do que está mais perto** (review): cheio, o raio efetivo encolhe pra antes do anel que
   não coube e o que fica fora dele, ou em outro andar, sai na hora; com folga ele cresce de novo.
   Andar, teleportar ou trocar de andar não deixa o jogador no limpo.
   Fade de 4 s ao surgir e ao sumir; fim da névoa ou densidade 0 → tudo some com fade; período ou
   densidade novos (a vermelha forçada no debug) → redesenha (a densidade nova vale depois de 1 s
   parada: o slider anda de 0,1 em 0,1); morte e menu → some na hora.

## Consequências

- O Outro Mundo cobre o que o jogador vê, no chão e nas paredes, e some sem deixar nada.
- O chão fica meio tile deslocado pra cima (o jeito do `IsoMarker`); como tudo desloca junto, o
  desenho não perde sentido. Roteiro confere.
- A parede pode passar por cima do que está na frente dela na tela (árvore, poste de outro
  square). A regra da parede limpa e de frente tira a maior parte; o resto é aceito.
- Custo novo por quadro: uma chamada Java por parede desenhada (≤ 120). Por atualização: até
  ~1030 chamadas enquanto enche, ~150 parado. A regra pura é o caro no Kahlua: `SCAN_BUDGET` é o
  botão. Medir no jogo.
- Some: as manchas "aos poucos" da sprint 0005 (o chão agora enche em ~4 s, com fade).

## Emenda de 2026-10-05 — sprint 0021: o que o jogo mostrou

Prints do Johan (05/10): a parede pintava de preto o que o jogo corta e passava por cima do
jogador (print 6, hotfix `WALLS = false`); o chão de dentro da casa saía em cima do telhado com o
jogador fora (7); a sujeira lia como xadrez (7); arbusto e sangue por cima do corpo e das pernas
do jogador (9, 10). Evidência no [pz-api-notes §16.5](pz-api-notes.md#165-o-que-o-jogo-mostrou-sprint-0021).

**O que mudou no "como":**

1. **O marcador pinta por cima do que fica atrás do centro do tile.** `IsoMarkers.renderIsoMarkers`
   sai em `performRenderTiles` 784, depois de `renderPlayers` (241) e `renderMovingObjects` (387),
   com o teste de profundidade ligado (38), mas o quad inteiro tem **uma** profundidade, a do
   centro do tile (`calculateDepth(x+0,5, y+0,5, z+0,01)`). O que na tela fica sob o quad e atrás
   desse ponto leva o decalque por cima: personagem do tile de trás, base de parede e, nos
   prints, o telhado. A consequência 2 desta ADR ("desenha com profundidade") vale só pra o que
   está na frente do centro do tile.
2. **O deslocamento não se compensa.** `IsoMarker.setPos(III)` é o único setter de posição
   (`+0,5`, `+0,5`, `+0,01`); `renderTextureWithDepth` põe a base do recorte no centro do tile:
   o losango sai centrado no canto N do tile. Sem float pelo Lua, nem combinação de tiles
   inteiros dá meio tile pra baixo (a tela anda de 64 e 32 px no quadro 2×). **O pool fica com
   decalque chato** (conteúdo no diamante do chão, sem `MoveWithWind`) que não invade o centro dos
   tiles de trás (N, W, NW) — heurística de vazamento, não garantia: com o pé fora do centro todo
   sprite alcança (review). Medido no pack por `scripts/audit_floor_sprites.py` (só leitura, nada
   copiado) → `tests/floor_sprites.lua`. Saem: todo `d_plants_1_*` (planta em pé, 33 do pool), 4
   sangues largos, 71 sujeiras, 100 rachaduras. Ficam 62 nomes de chão (eram 270).
3. **Chão apagado debaixo de personagem:** o decalque do tile dele e dos S, E e SE (os que
   alcançam o corpo com o pé em qualquer lugar do tile) vai a alfa 0. Do jogador, todo tick; de
   zumbis (`getCell():getZombieList()`) e jogadores do MP (`getOnlinePlayers`, só cliente) a até
   10 tiles, em rodízio de 8 zumbis por tick (a volta velha vale até a nova fechar). Volta quando
   saem.
4. **Só o chão que o jogador vê:** square de dentro só se for do prédio em que ele está
   (`getBuilding`; o jogo corta as paredes do sul e do leste e o telhado); square de fora
   (`isOutside`) só se nenhum dos 3 squares na diagonal de trás é de dentro — de **nenhum** prédio,
   nem o dele, cujas paredes N/W não são cortadas (um andar cobre 3 tiles na tela). Lido uma vez
   por square; o prédio do jogador a cada atualização. Mudou → o que saiu da vista apaga em 4 s e
   sai; o raio perde um tile por lote em vez de desabar até o square recusado.
5. **Sujeira em manchas, parcial e mais leve:** ruído de valor numa rede de 4 tiles (passa de
   `1 − min(0,4·d, 0,4)`: ~27% do chão, a chance para aí pra as manchas não se emendarem em
   densidade alta), recortado por um ruído fino de 2 tiles; só sprites com cobertura < 50% e sem
   faixa de borda, por classe `(x + 2y) mod 5` (vizinho de lado nunca repete o sprite); num
   segundo marcador do square com metade do alfa (o marcador tem uma cor pra todas as texturas).
   Rachadura sobe de 0,35 pra 0,45 pra manter o enquadramento de 7×7 mudado.
   O teto (600) é de **marcadores** vivos, inclusive os que apagam.
6. **Paredes ficam desligadas.** Pesquisado: o recorte do jogo dá pra ler
   (`IsoGridSquare.getPlayerCutawayFlag(pn, ms)`, bit 1 = N cortada, 2 = W,
   `FBORenderCutaways.doCutawayVisitSquares` 612–716) e resolveria a laje preta. Mas o
   `RenderOpaqueObjectsInWorld` sai **depois do `renderPlayers`** (241 → 374) e o fantasma
   desliga o teste de profundidade: a parede pinta por cima do jogador (e dos outros jogadores no
   MP) e de tudo que já está no FBO do chunk — móvel, poste, árvore, cerca em **outros** squares na
   frente dela. Isso só se tiraria por geometria aproximada (retângulo do jogador na tela, squares
   da frente limpos), sem ver altura de objeto nem outro jogador. Não é regra confiável: fica
   `WALLS = false`. Volta se aparecer desenho de sprite de tile com profundidade pelo Lua.

**Custo novo:** todo tick com o chão ativo, ~5 chamadas (posição do jogador, lista de zumbis) +
até 8 zumbis × 4 (get, posição); por volta completa no MP, os jogadores online. Por square novo
na varredura, até 4 leituras de telhado (em cache por âncora). Até 2 marcadores por square,
600 no total.
