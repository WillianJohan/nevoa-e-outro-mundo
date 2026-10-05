# Sprint 0028 — Névoa só nossa: sem a faixa embaixo (mod3)

Status: `em teste`.

## Por quê

Com o zoom bem afastado, a parte de baixo da tela ficava sem névoa, com uma borda reta. E na névoa
vermelha quase não se viam os rolos, só um vermelho liso.

## Causa (investigada com o Johan no jogo)

- Os diagnósticos `NOMRender_setParam(1, 2)` (profundidade) e `(1, 1)` (grade) saíram certos até a
  borda de baixo: a nossa névoa sabia onde estava cada pixel.
- A camada lisa por cima de tudo era a névoa vanilla (`ImprovedFog`). Ela é desenhada linha a linha só
  até um pouco antes da borda de baixo da tela. `ImprovedFog.setMaxYOffset(12)` e `(25)` não resolveram;
  desligar a vanilla (`setEnableEditing(true); setBaseAlpha(0)`) tirou a faixa.
- Sem a vanilla, a nossa névoa ficava rala (só os bancos e o abraço nas árvores), e na vermelha o
  véu liso da vanilla afogava os rolos.

## O que mudou

- **A vanilla sai** com o mod Volumétrica ativo: um patch na saída do `ImprovedFog.update()` zera o
  `baseAlpha` daquele quadro (evidência em `pz-api-notes.md` §19). Se o passe do shader morrer, a vanilla
  volta sozinha.
- **Véu de fundo no shader:** uma névoa baixa e uniforme, mais densa rente ao chão, por baixo dos rolos e
  dos vácuos. Não entra dentro de casa (como a vanilla), abre em volta de quem anda e onde a luz bate.
  Cobre a tela toda, sem borda.
- **Comparar:** `NOMRender_setParam(7, v)` escala o véu (padrão 1; 0 = só rolos);
  `NOMRender_setParam(8, 1)` devolve a vanilla por baixo, `(8, 0)` tira de novo.

## Roteiro in-game

1. Reiniciar depois do `dev-sync`; névoa ligada.
2. Zoom bem afastado: a névoa vai até a borda de baixo.
3. Vácuos ainda aparecem (mais limpos que o véu), e dentro de casa não tem véu.
4. Névoa vermelha: rolos vermelhos visíveis, não só um vermelho liso.
5. Se o véu ficar forte ou fraco: `NOMRender_setParam(7, 0.6)` ou `(7, 1.5)` e me diz o valor.

## Ajustes fáceis

| Onde | Constante | Efeito |
|---|---|---|
| `NOM_VolFog` | `HAZE = 0.18` | densidade do véu (param 7 multiplica) |
| `NOM_VolFog` | `exp(-1.5 * hz / layer)` | quanto o véu afina subindo |

## Aprendizado

- **Faixa reta na tela, mas a posição certa nos diagnósticos = outra camada.** Os modos de debug de
  profundidade e grade separam o que é nosso do que é do jogo em um print.
