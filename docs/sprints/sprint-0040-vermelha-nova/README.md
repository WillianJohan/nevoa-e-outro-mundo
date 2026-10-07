# Sprint 0040: vermelha nova

| Campo | Valor |
|-------|-------|
| Status | `em teste` |
| Branch | `sprint/0040-vermelha-nova` (saiu da `sprint/0039-nevoa-preta-ii`, empilhada: veja abaixo) |
| Origem | [spec do modelo novo §1, §7 e §10](../../superpowers/specs/2026-10-06-modelo-novo-design.md); HANDOFF, "Névoa vermelha estilo Upside Down" |
| Plano | [plan.md](plan.md) |

## O que entrou

- **Tentáculos pretos** no Outro Mundo da vermelha, com texturas novas do `scripts/gen_tiles.py`
  (`NOM_OM_Tentaculo_F/W/N`, 5 de cada):
  - **na parede**, 2 a 4 tentáculos subindo do rodapé, com ramos finos, gomos, brilho molhado e
    uma mancha úmida em volta. São mais um tipo da vermelha: 15% fora (o sangue continua mandando,
    com 35%) e 15% dentro de casa, por cima do sangue;
  - **no chão**, um buraco escuro de onde saem 3 a 5 tentáculos que se arrastam. Aparecem como
    peça solta, nunca lado a lado (~5% do chão na vermelha), dentro e fora, nunca na grama.
- **Cinza no ar:** na vermelha, pontos de cinza nascem soltos a até 9 tiles do jogador, a meia
  altura, e flutuam devagar pra qualquer lado, com vida de 5 a 10 s, aparecendo devagar. São até 40
  de uma vez, com lugar reservado dentro do teto de 160 das lascas. Seguem a densidade do Outro
  Mundo e a intensidade dos efeitos de tela, e saem no mesmo desenho das lascas, sem ida a mais ao
  Java por quadro.
- Branca e preta não mudam.

## Decisões tomadas na ausência do Johan (fáceis de mudar)

- **Tentáculo fora da grama:** a regra do hotfix do chão da 0035 (nada nosso em piso natural)
  vale. Na preta a cinza vai na grama; aqui o decalque é centrado e virava grade de estrelas.
  Liberar: tirar o `not natural` do tentáculo em `NOM_DressingRules.floor`.
- **Peça solta no chão**, como o metal da calçada que o Johan aprovou
  (`TENTACLE`, `TENTACLE_MAX`).
- **Tentáculo parado** (sprite, sem animação), como a brasa da 0039.
- **A cinza no ar é só da vermelha.** A preta já tem a cinza que sobe do chão queimado.
- **O teto de custo do Outro Mundo enchendo subiu de 2500 pra 2600** chamadas por atualização
  (`test_fog_overlays`, `overlays_budget`). A casa na vermelha já estava em 2488 antes; com o
  tentáculo, 2584. O custo por camada não mudou: o que mudou foi o sorteio de quem ganha cada
  camada.
- **Luz fria pelo clima** (da fila antiga) não entrou: a vermelha já tem o visual de clima dela.
  Mexer nisso fica pro Johan.

## Branches empilhadas (sem merge na `staging`)

O review automático bloqueou o merge na `staging`, o push e o sync enquanto o Johan está fora
("só no final"). Então a 0040 saiu da branch da 0039, sem merge. No fim, o merge vai em ordem:
`sprint/0039-nevoa-preta-ii` → `staging`, e depois cada sprint seguinte. A última branch da pilha já
contém todas, então dá pra fazer o merge dela só.

## Testes

- `test_om_tiles.py`: tipos novos, cobertura, tentáculo escuro com brilho, gerador determinístico.
- `test_own_sprite_list`: tipos novos.
- `test_dressing_rules`: `red_tentacles` (chão em peça solta dentro e fora, nunca na grama; parede
  fora e dentro, abaixo do sangue fora; branca e preta sem tentáculo) e a ordem das camadas dentro.
- `test_fog_overlays`: orçamento.
- `test_flake_rules`: `air_floats` (perto, no andar, a meia altura, devagar pros dois lados, fade
  lento) e `air_cap_and_share` (teto próprio, não come as lascas do chão, não anda o relógio).
- `test_flakes`: `red_air` (só na vermelha, cor da paleta, some com os efeitos desligados).

## Roteiro de teste no jogo

1. Staging, de dia: `NOM.setRedFog()` (ou o botão "Sirene vermelha" no `NOM.panel()`). Espere a fuga acabar.
2. Paredes de fora: entre o sangue, tentáculos pretos subindo do rodapé, com brilho molhado.
3. Dentro de casa: tentáculos por cima do sangue em algumas paredes.
4. Calçada e chão de casa: de vez em quando um buraco com tentáculos saindo, nunca dois lado a
   lado. Na grama, nada.
5. Pare num lugar aberto: pontos de cinza flutuam devagar em volta, a meia altura, sem subir como
   as lascas.
6. Opções > Mods: com os efeitos de tela em 0, a cinza no ar some.
7. Branca e preta (`NOM.setFog()`, `NOM.setBlackFog(true)`): nada de tentáculo nem de cinza no ar.

## Code review

Sem achado que pedisse correção. Conferido:
- o ar desliga e devolve o lugar reservado no fim da névoa (`R.air(state, 0)`) e na morte (`forget`);
- o nome do piso só é lido quando o tile ganhou tentáculo (`D.hasOwn`);
- as 15 texturas novas entram sozinhas no registro (`NOM_OwnSprites`, pela lista gerada);
- as texturas antigas saíram com os mesmos bytes;
- nada fora do Kahlua (`math.min` aninhado, sem `%`).
