# Sprint 0029 — Ondas da névoa nos obstáculos (mod3)

Status: `em teste`. Vem junto com a [0028](../sprint-0028-nevoa-sem-vanilla/README.md).

## Por quê

No vídeo da casa (névoa vermelha), o Johan viu a névoa passar pela casa como se ela não existisse pro
desenho: "quando a névoa passa pela casa, deveria ter as ondas da névoa". A simulação já desviava, mas
a esteira passava lisa e os rolos tinham a mesma altura na frente da parede e longe dela.

## O que mudou

- **Reforço de redemoinho** (`FlowGrid.vorticity`, vorticity confinement): empurra o ar em volta de
  cada giro no sentido dele, devolvendo o que a grade grossa e a volta pro vento apagam. Atrás e nas
  quinas do prédio a esteira enrola e solta ondas; o desenho da névoa dobra junto (ele já seguia o desvio
  do fluido).
- **Empilhamento contra a parede** (`pileUp` no `NOM_VolFog`): onde o ar freia (mais lento que o vento
  livre) o rolo sobe até 50%; onde acelera, na quina, baixa um pouco. O volume ganhou altura (1,6 da
  camada) pra caber.

## Força do redemoinho (medida no cenário do teste: prédio 8×8, vento 1,5 tile/s, 100 s)

| Força | Giro na esteira | Névoa logo atrás do prédio |
|---|---|---|
| 0 | 32 | 0,43 |
| 0,5 | 50 | 0,47 |
| **0,8 (no jogo)** | 72 | 0,58 |
| 1,2 | 124 | 0,72 |
| 2,0 | 790 (quase instável) | 0,85 |

Acima de ~1,2 o redemoinho mistura demais e fecha o vácuo que o Johan gostou. Custo do passo com tudo
ligado: ~1,27 ms (meta 1,5).

## Roteiro in-game

1. Reiniciar depois do `dev-sync`.
2. Parado perto de uma casa com a névoa passando: do lado de onde vem o vento, os rolos sobem contra a
   parede; atrás, a névoa enrola em ondas e o vácuo ainda aparece.
3. Velocidade no debug: `NOMRender_setParam(1, 7)` mostra os giros atrás da casa; `(1, 0)` volta.

## Ajustes fáceis

| Onde | Constante | Efeito |
|---|---|---|
| `Flow` | `grid.vorticity = 0.8f` | quanto a esteira enrola (tabela acima) |
| `NOM_VolFog` | `PILE = 0.5` | quanto o rolo sobe contra a parede |
