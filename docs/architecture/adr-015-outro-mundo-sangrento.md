# ADR-015 — Outro Mundo sangrento: chão por IsoMarker com camadas, paredes por desenho no quadro

| Campo | Valor |
|-------|-------|
| Status | `accepted` |
| Data | 2026-10-05 |
| Emenda | [ADR-007](adr-007-sem-rosto-e-atmosfera-local.md) (os overlays da névoa deixam de ser "manchas aos poucos no chão" e viram o cenário inteiro, chão e paredes) |

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
