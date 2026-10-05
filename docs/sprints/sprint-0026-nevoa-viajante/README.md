# Sprint 0026 — Névoa viajante e luz que abre a névoa (mod3)

Status: `em teste`. Plano e evidência em [plan.md](plan.md).

## Por quê

O Johan viu a névoa da 0024/0025 e disse que ela parecia um mar parado. O que ele quer: "uma névoa
que vai caminhando pelo mapa, desviando de objeto, fazendo vácuos", reagindo a tudo (jogador, zumbi,
carro, porta, tiro, explosão), e a luz abrindo a névoa, como a fumaça volumétrica do CS2.

O que deixava parado: a rua inteira era recarregada pra névoa cheia o tempo todo (qualquer vácuo se
fechava no lugar), as quatro bordas injetavam igual e o vento era fraco (0,25 a 1 tile/s).

## Como funciona agora

- **Bancos:** a névoa entra pela borda de onde vem o vento, em bancos de ~20 tiles com vácuo entre
  eles (`FogBanks`: ruído no mundo calibrado pra cobrir ~70% do chão, levado pelo vento médio e mudando
  de forma devagar). Atravessa a grade e sai pelo outro lado. A rua não é mais recarregada.
- **Vento:** 1 a 2,2 tiles/s pela intensidade do clima, com rajadas e a direção oscilando.
- **Inércia:** a velocidade é levada por ela mesma. Atrás de prédio, carro e árvore o ar para, e onde o
  ar para a névoa se desfaz: fica um vácuo atrás do obstáculo que vai se fechando mais longe.
- **Rastro:** quem anda abre um caminho, e o caminho viaja com a névoa.
- **Carros:** empurram com raio de 3 tiles (pessoa: 1,6).
- **Porta e janela:** ao abrir, sopram parte da névoa de fora pra dentro, além da que escorre devagar.
- **Tiro e explosão:** som novo com raio ≥ 20 (fora zumbi, carro e alarme) empurra a névoa do miolo pra
  um anel em volta (sem criar nem sumir névoa), com raio pelo alcance do som (2,5 a 9 tiles).
- **Luz:** lanterna (e lampião, em volta) e farol de carro viram um facho aceso dentro da névoa e abrem
  a névoa onde batem (até 55% mais rala no meio do facho). Até 4 luzes, as dos jogadores primeiro.
- **Qualidade:** Opções > Mods > "Qualidade da névoa (mod Volumétrica)": 0 baixa (8 passos por pixel),
  1 média (12), 2 alta (16, padrão). No console: `NOMRender_setParam(6, q)`.

**Decidido com o Johan:** as partículas (bolos de fumaça desenhados como imagem) ficaram de fora,
porque a luz precisa atravessar a névoa ponto a ponto e só o volume faz isso. A simulação segue 2D por
andar, com a altura no shader.

**Futuro (ideia do Johan):** névoa preta, pra deixar o jogo mais macabro. A cor já vem de um lugar só
(`uFog.yzw`), então é uma variação de cor e de luz, não uma reescrita.

## Roteiro in-game

1. Reiniciar o jogo depois do `dev-sync`.
2. `NOM_Debug.fog(true, true)` (ou `NOMRender_setParam(0, 0.85)` pra forçar só o visual).
3. **Viaja:** parado na rua, a névoa tem que passar. Bancos chegando, vácuos entre eles. No console,
   `NOMRender_flowInfo()` mostra o `vento=(x,y)`.
4. **Vácuo atrás de prédio:** do lado de onde o vento vai, atrás de uma casa, tem que ficar mais limpo.
   No modo de densidade (`NOMRender_setParam(1, 6)`), uma sombra escura atrás das casas.
5. **Rastro:** correr no meio de um banco e ver o caminho aberto sendo levado.
6. **Carro:** dirigir no meio: rastro largo atrás.
7. **Porta:** abrir uma porta com um banco na frente: uma golfada entra.
8. **Tiro:** atirar no meio da névoa: abre um buraco em volta de quem atirou, que se fecha devagar.
9. **Lanterna:** à noite, com névoa, ligar a lanterna: facho aceso na névoa e a névoa mais rala dentro
   dele. Farol do carro: o mesmo.
10. **Qualidade:** trocar em Opções > Mods e ver o FPS (ou `NOMRender_setParam(6, 0/1/2)`).
11. Log a cada 30 s: `fluido: passo X ms` (o teste dá ~1,1 ms).

## Ajustes fáceis

| Onde | Constante | Efeito |
|---|---|---|
| `Flow` | `new FogBanks(..., 0.7f, 22f)` | cobertura e tamanho dos bancos |
| `Flow.wind` | `1f + 1.2f * intensidade`, rajada | velocidade da viagem |
| `Flow` | `stillDecay = 0.08f` | quanto o vácuo atrás do prédio limpa |
| `Flow` | `doorPuff = 0.35f` | golfada da porta |
| `Flow` | `LOUD_RADIUS`, `s.radius / 10f` | que som explode e com que raio |
| `NOM_VolFog` | `0.55 * open`, `torch * 1.6` | quanto a luz abre e quanto o facho acende |

## Aprendizados

- **O vácuo atrás do prédio precisa das duas coisas juntas.** Com inércia e sem decaimento no ar parado,
  a névoa só fica parada atrás do prédio (densidade 1,00). Com decaimento e sem inércia, o fluxo fecha
  logo atrás do bloco e quase não há ar parado (0,87). Com as duas: 0,26 logo atrás, voltando pra 0,78
  a 16 tiles. Conferido rodando o cenário do teste com cada uma desligada.
- **Explosão não pode ser velocidade pra fora.** Um campo radial é só divergência, e a projeção
  (incompressível) apaga ele inteiro. Por isso a explosão mexe direto na densidade, levando do miolo
  pro anel.
