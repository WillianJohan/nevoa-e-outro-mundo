# Sprint 0030 — Névoa em alta resolução (mod3)

## Por quê

No debug de velocidade (`NOMRender_setParam(1, 7)`) o Johan viu um xadrez colorido cobrindo a tela.
Medido fora do jogo (sonda em Java com casas de parede fina e cercas, vento com rajadas, 300 s):

- o reforço de redemoinho da 0029 lia o salto de velocidade através da parede fina como giro e
  empurrava ar pra dentro da casa (1,45 tile/s lá dentro, que devia estar parado);
- os redemoinhos que ele cria têm 1 a 3 tiles, o tamanho da própria grade (1 célula por tile): a
  grade não representa isso e vira ruído (7,5x o ruído de um tile sem o reforço).

O Johan pediu resolução maior, parametrizável.

## O que muda

1. **Reforço sem parede** (`FlowGrid.confine`): canto encostado em face fechada não tem giro;
   interior não recebe força; o giro é suavizado (média com peso de coerência), pra ruído de um
   tile não se realimentar.
2. **Escala da grade** (`FlowGrid(tiles, scale)`): `scale` células por tile, a grade cobre os
   mesmos 128 tiles. Origem, rolagem, bancos, impulso e explosão continuam em tiles; velocidade em
   tiles/s. Advecção e difusão da densidade com subpassos (o limite por face é por célula).
   API por tile (`setTile`, `setTileOpenW/N`) pro `Flow` montar a máscara.
3. **Linha própria** (`Flow`): a thread principal só lê o jogo (máscara, quem anda, sons, vento) e
   empilha entradas; uma thread da simulação aplica, avança e publica a textura. Erro em qualquer uma
   desliga só o fluido.
4. **Parâmetro 9** (`NOMRender_setParam(9, s)`, 1 a 3, padrão 2): trocar recria a grade e a textura.
   Opções > Mods ganha "Resolução da névoa fluida", mandada pelo `NOM_FogQualitySync`.
5. **Shader**: `nomFlowFlags` acha a célula pela escala da textura (`textureSize / uFlow.z`).

## TDD

- [ ] `FlowTravelTest`: casa de parede fina fica parada por dentro; reforço não pontilha a esteira.
- [ ] `FlowGridTest`: escala 2 marca 2x2 células por tile, fecha 2 faces por parede, rola em tiles.
- [ ] Escala 2: buraco viaja na mesma velocidade (tiles/s) que na escala 1; vácuo atrás do prédio.
- [ ] Custo do passo em escala 2 (meta < 6 ms, fora da thread principal).
- [ ] `test_mod3_depth.py`: `PARAM_FLOW_RES = 9` com padrão 2; shader usa `textureSize(uFlowTex`.
- [ ] `test_fog_quality_sync.lua`: manda a resolução também, só quando muda.
- [ ] Traduções PTBR + EN da opção.

## Fora

Volume por andares, névoa preta.
