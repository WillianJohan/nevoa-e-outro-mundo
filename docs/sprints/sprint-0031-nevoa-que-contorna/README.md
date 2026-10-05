# Sprint 0031 — Névoa que contorna (mod3)

Status: `em teste`. Plano e TDD em [plan.md](plan.md). Etapa 1 da
[pesquisa](../../architecture/pesquisa-nevoa-volumetrica.md).

## Por quê

No vídeo de 2026-10-05 o Johan viu "uma fumaça que passa entre os objetos": a névoa não desviava dos
obstáculos nem enchia o outro lado. A pesquisa achou as causas no nosso código. As principais:

- o vácuo atrás do prédio vinha de um sorvedouro do ar parado (`stillDecay`), sem nada que recarregasse;
- árvore e carro eram muros até o céu;
- o rolo subia onde o ar era lento, e atrás do prédio o ar também é lento;
- a textura cortava a densidade em 1, então o acúmulo contra a parede nunca chegava no desenho.

## O que mudou

- **Vácuo vira opção** (`NOMRender_setParam(10, v)`). Com 0 (padrão), a esteira enche; com 1, volta o
  vácuo da 0026. Troca na hora, com o jogo rodando.
- **Árvore porosa:** não é mais sólida. O ar que passa por ela é freado (`treeDrag`, 1,2/s).
- **Carro baixo** (`F_LOW`): arrasto forte (`lowDrag`, 4/s). O ar desvia pelos lados e pouco passa por
  cima. No debug das flags (`NOMRender_setParam(1, 5)`) o carro aparece em laranja.
- **Pressão com chute:** começa da pressão do passo anterior e só zera ao rolar a grade ou mudar a
  máscara. A divergência que sobra caiu de 0,017 para quase zero, com as mesmas 16 iterações.
- **Acúmulo visível:** a textura leva `densidade / 1,5` e o shader multiplica de volta.
- **Rolo só a barlavento:** o `pileUp` olha 1 e 2,5 tiles à frente no sentido do vento. Só sobe se
  houver parede, interior ou carro ali.

## Números (escala 2, prédio 8×8, vento 1,5 tile/s, 100 s)

| Tiles atrás do prédio | 2 | 4 | 8 | 16 |
|---|---|---|---|---|
| Vácuo desligado (padrão) | 1,00 | 1,00 | 1,00 | 1,00 |
| Vácuo ligado (`10, 1`) | 0,38 | 0,56 | 0,72 | 0,87 |

- **Bosque 6×6:** o ar passa a 0,42 tile/s (28% do vento) e a névoa atrás fica cheia (1,00).
- **Carro 5×3:** o ar dentro dele anda a 0,11 tile/s, contra 1,55 fora.
- **Custo do passo:** 5,6 ms na thread da simulação, igual à 0030.

## Roteiro in-game

1. Reiniciar o jogo depois do `dev-sync`.
2. Achar uma casa com vento e névoa. Olhar o lado de trás: a névoa deve contornar a casa e encher o
   outro lado.
3. A/B do vácuo, no console Lua do debug:
   - `NOMRender_setParam(10, 1)` liga o vácuo;
   - `NOMRender_setParam(10, 0)` volta pro padrão.

   O vácuo leva uns 20 a 30 s pra abrir ou fechar. Diga qual dos dois prefere.
4. Perto de árvores: a névoa entra no bosque e sai do outro lado, sem buraco atrás.
5. Perto de um carro parado: `NOMRender_setParam(1, 5)` mostra o carro em laranja; `(1, 7)` mostra o
   ar desviando dele. `(1, 0)` volta.
6. Contra a parede do lado do vento, o rolo deve subir. Atrás da casa, não deve.

## Ajustes fáceis

| Onde | Constante | Efeito |
|---|---|---|
| `Flow` | `STILL_DECAY = 0.08f` | força do vácuo com o param 10 em 1 |
| `FlowGrid` | `treeDrag = 1.2f` | quanto a árvore freia o ar |
| `FlowGrid` | `lowDrag = 4f` | quanto o carro freia o ar (menos = passa mais por cima) |
| `NOM_VolFog.frag` | `PILE = 0.5` | quanto o rolo sobe contra a parede |
