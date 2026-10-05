# Sprint 0025 — Luz e volume na névoa (mod3)

Status: `em teste`. Plano em [plan.md](plan.md).

## Por quê

O Johan quer uma névoa "viva", com física convincente, como a fumaça interativa do Batman Arkham Knight
(GameWorks). A névoa da 0024 parecia uma placa chapada. Antes de partir pra uma simulação 3D na GPU, esta
sprint testa a hipótese barata: o chapado vem mais da luz do que da simulação.

O que deixava chapado, no shader antigo:

- a cor de cada ponto dependia só da altura, sem sombra da névoa que está por cima;
- a camada tinha topo reto, sempre a 1,2 andar;
- o ruído era grande e liso (tufos de ~5 tiles, duas oitavas).

## O que mudou (só shader)

- **Rolos com silhueta:** cada coluna do chão tem a própria altura de névoa, de um ruído arredondado
  (tipo cúmulo, ~3,5 tiles por rolo) levado pela velocidade do fluido. Onde o fluido acumula, sobe mais.
- **Sombra própria:** quanto mais fundo abaixo do topo do rolo, mais escuro; uma amostra inclinada
  rumo à luz escurece o lado do rolo que fica de costas pra ela. Topo na cor do clima, barriga escura,
  mais cinza e um pouco fria.
- **Fiapos:** uma oitava de ~1 tile corrói a borda dos rolos.
- **Comparação:** `NOMRender_setParam(5, 0)` volta pro visual antigo, `(5, 1)` liga o novo (padrão).

A cor continua vindo do clima: a névoa vermelha segue vermelha.

## Roteiro in-game

1. Reiniciar o jogo depois do `dev-sync`.
2. Forçar a névoa (`NOMRender_setParam(0, 0.85)` ou `NOM_Debug.fog(true)`).
3. Na rua, olhar a névoa parado: tem que ter rolos com topo claro e vão escuro, não uma placa.
4. `NOMRender_setParam(5, 0)` e `(5, 1)` alternando, na mesma cena: print dos dois.
5. Andar e correr no meio: os rolos se abrem e andam com o fluido.
6. FPS com o 5 em 0 e em 1 (o novo faz ~2,5× as contas de ruído por pixel).
7. Névoa vermelha: continua vermelha, com o topo vermelho e a barriga escura.

## Decisão que este teste destrava

- Se com luz e rolos ainda parecer chapado, o problema é a simulação: segue pro plano da simulação 3D na
  GPU (spike primeiro), discutido com o Johan em 2026-10-05.
- Se ficar bom, os ajustes de luz entram na névoa de vez e a simulação 3D vira opcional (qualidade alta).

## Aprendizados

- **Ordem do raio importa quando a cor varia no volume.** O laço anda do ponto visível rumo à câmera,
  mas a composição "frente cobre fundo" tratava o primeiro passo como o mais perto da câmera. No visual
  antigo, a cor quase não variava e ninguém notou. No novo, apareceu no primeiro vídeo do Johan: névoa
  rala clara, funda escura e parede brilhando. Agora o visual novo percorre da câmera pro chão. O
  antigo ficou como estava, pra servir de comparação.

## Ajustes fáceis (no `NOM_VolFog.frag`)

| Constante | Efeito |
|---|---|
| `1.6` em `sun = exp(-1.6 * shade ...)` | contraste: maior, barriga mais escura |
| `xy * 1.55` em `rollTop` | tamanho dos rolos: maior, rolos menores |
| `0.35 * fiapo` | quanto os fiapos corroem a borda |
| `ROLL_SOFT` | borda dura (menor) ou macia (maior) |
| `SUN_STEP` | de onde vem a luz |
