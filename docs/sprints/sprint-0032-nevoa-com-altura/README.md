# Sprint 0032 — Névoa com altura (mod3)

Status: `em teste`. Plano e TDD em [plan.md](plan.md). Etapa 2 da
[pesquisa](../../architecture/pesquisa-nevoa-volumetrica.md), na versão enxuta.

## Por quê

Depois da 0031 a névoa contornava os prédios, mas todo obstáculo ainda era muro até o céu. A cerca
baixa segurava a névoa como uma parede, e o carro só freava o ar.

## O que mudou

- **A densidade virou profundidade:** 1,0 equivale a 0,8 andar, o rolo que o shader já desenhava.
- **Obstáculo com altura:**
  - carro: 0,55 andar;
  - cerca baixa (a que se pula, `HoppableW/N`): 0,4 andar. A borda dela agora é aberta pro vento, com
    arrasto, e a névoa passa por cima;
  - parede, prédio, cerca alta, porta e janela fechadas continuam fechados.

  A evidência da cerca está no [pz-api-notes §20](../../architecture/pz-api-notes.md).
- **Só passa a parte de cima:** numa face com obstáculo, passa só a névoa acima dele. Névoa rasa para
  na cerca. Névoa funda empilha na frente e transborda.
- **Transbordo por gravidade:** onde há obstáculo baixo, a névoa empilhada escorre pro outro lado. Em
  campo aberto a gravidade fica desligada: ela fechava os buracos que viajam com o vento, enchia o
  vácuo atrás do prédio e custava 1,2 ms a mais por passo.
- **Carro freia menos o vento** (arrasto 4 → 1/s): a névoa por cima dele anda com o ar de cima.
- **Shader:** em cima do carro, o rolo começa no teto dele. No debug 5, a cerca baixa aparece em
  amarelo e o carro em laranja.

## Números (escala 2, vento 1,5 tile/s, vácuo ligado)

| Cena | Resultado |
|---|---|
| Cerca baixa de 20 tiles | névoa 2 tiles atrás: 1,00; vento logo atrás: 1,39 tile/s |
| Muro do mesmo tamanho | vácuo atrás (< 0,5) |
| Carro 5×3 | névoa por cima: 0,71; 2 tiles atrás: 0,72 |
| Névoa parada ao lado da cerca | rasa (80% da altura da cerca) não passa; funda (1,2) passa 0,22 em 10 s |
| Vácuo atrás do prédio | igual à 0031 |
| Passo | 5,8–6,0 ms na thread da simulação (antes 5,6) |

## Roteiro in-game

1. Reiniciar o jogo depois do `dev-sync`.
2. Achar um quintal com cerca baixa e névoa com vento. A névoa deve passar por cima da cerca, sem
   parar nela nem deixar buraco atrás.
3. `NOMRender_setParam(1, 5)`: a cerca baixa aparece em amarelo, a parede e a cerca alta em branco, o
   carro em laranja. `(1, 0)` volta.
4. Perto de um carro parado: a névoa sobe por cima dele, em vez de sumir onde ele está, e enche o lado
   de trás.
5. Contra uma parede de prédio, nada muda: a névoa para e o vácuo atrás continua.

## Ajustes fáceis

| Onde | Constante | Efeito |
|---|---|---|
| `FlowGrid` | `H_FENCE = 0.4f`, `H_LOW = 0.55f` | altura da cerca baixa e do carro, em andares |
| `FlowGrid` | `FOG_DEPTH = 0.8f` | profundidade da névoa por unidade de densidade |
| `FlowGrid` | `slump = 0.3f` | quanto a pilha transborda o obstáculo baixo |
| `FlowGrid` | `fenceDrag = 1f`, `lowDrag = 1f` | quanto a cerca e o carro freiam o vento |
| `NOM_RenderContext.glsl` | `NOM_FLOW_LOW_H` | altura do carro no desenho (igual a `H_LOW`) |
