# Sprint 0030 — Névoa em alta resolução (mod3)

Status: `em teste`. Plano e TDD em [plan.md](plan.md).

## Por quê

No debug de velocidade (`NOMRender_setParam(1, 7)`) o Johan viu um xadrez colorido na tela inteira e
sugeriu que a resolução da névoa era baixa. Medido fora do jogo (casas de parede fina, cercas, vento
com rajadas):

- o reforço de redemoinho da 0029 lia o salto de velocidade através da parede fina como giro e
  empurrava ar pra dentro da casa fechada (1,45 tile/s lá dentro);
- os redemoinhos que ele criava tinham o tamanho da célula (1 tile): ruído de célula 7,5x maior.

## O que mudou

- **Grade com escala** (`FlowGrid(tiles, scale)`): 1 a 3 células por tile, cobrindo os mesmos 128
  tiles. Tudo de fora continua em tiles (origem, rolagem, bancos, impulso, explosão, velocidade).
  Advecção e difusão em subpassos: a névoa anda e espalha igual em qualquer escala (testado).
- **Thread própria** (`NOM-fluido`): a thread principal só lê o jogo (máscara, quem anda, sons,
  vento) e empilha; a simulação aplica, avança e publica. O deslocamento dos bancos que o shader usa
  é espelhado na thread principal com a mesma conta, então o ruído segue grudado na densidade.
- **Reforço de redemoinho sem xadrez:** canto encostado em parede não tem giro, interior não recebe
  força, e o reforço age no giro médio de 2 tiles (com peso de coerência: ruído que troca de sinal
  não se realimenta). Força por tile (0,6), igual em qualquer escala.
- **Parâmetro 9** e **Opções > Mods > "Resolução da névoa fluida"** (1 a 3, padrão 2). Trocar recria
  a grade e a textura.
- **Shader:** `nomFlowFlags` acha a célula pela escala da textura.

## Números (escala 2, prédio 8×8, vento 1,5 tile/s)

| Raio da média | Força (por célula) | Ruído de célula | Giro em tiles | Névoa atrás do prédio |
|---|---|---|---|---|
| sem reforço | 0 | 1x | 1x | 0,34 |
| 0,5 tile | 0,8 | 3,3x | 1,55x | 0,41 |
| 2 tiles | 0,8 | 1,7x | 1,66x | 0,35 |
| **2 tiles (no jogo)** | **1,2** | **2,4x** | **2,2x** | **0,43** |

Ar dentro da casa fechada: 0 em todas. Passo na escala 2: ~5,7 ms na thread da simulação (16% de um
núcleo a 20 Hz); escala 3 deve dar ~2,5x isso.

## Roteiro in-game

1. Reiniciar depois do `dev-sync`.
2. `NOMRender_setParam(1, 7)` perto de casas: sem xadrez; dentro da casa cinza (parado); atrás, giros
   largos. `(1, 0)` volta.
3. Névoa normal passando pela casa: ondas atrás, vácuo ainda visível, borda do vácuo mais fina.
4. Opções > Mods > "Resolução da névoa fluida": 1, 2 e 3 trocam na hora (até 1 minuto de jogo pra
   sincronizar; ou `NOMRender_setParam(9, s)` direto). Olhar o FPS em 3.
5. `NOMRender_flowInfo()` mostra a escala, a grade e o tamanho da textura; o log a cada 30 s traz o
   custo do passo na thread da simulação.

## Ajustes fáceis

| Onde | Constante | Efeito |
|---|---|---|
| `Flow.newGrid` | `g.vorticity = 0.6f` | quanto a esteira enrola (o dobro fecha o vácuo) |
| `FlowGrid` | `vorticityRadius = 2f` | tamanho mínimo das ondas, em tiles |
| `RenderContext` | `luaParams[PARAM_FLOW_RES] = 2f` | resolução padrão sem o Lua |
