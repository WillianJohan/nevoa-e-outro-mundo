# Sprint 0044: rosto censurado do Sem-rosto

| Campo | Valor |
|-------|-------|
| Status | `em teste` |
| Branch | `sprint/0044-rosto-censurado` (saiu da `sprint/0043-ticao-ia`, empilhada) |
| Origem | [spec do modelo novo §9](../../superpowers/specs/2026-10-06-modelo-novo-design.md#9-facelift-dos-monstros), item 4 da ordem (era a 0033 antiga) |
| Plano | [plan.md](plan.md) |

## O que entrou

- **Com o mod3, a cabeça do Sem-rosto ganha um quadrado de censura de TV:**
  - a cena atrás em blocos (mosaico), borrada;
  - chiado que troca 12 vezes por segundo e linhas de varredura descendo;
  - borda levemente suavizada.
- O quadrado:
  - acompanha a cabeça (em pé, andando, no andar de cima);
  - some atrás de parede e de poste: a profundidade da cena na frente da cabeça esconde;
  - some com o zumbi fora da vista do jogador e aparece com o fade-in dele (usa o alfa do zumbi);
  - fica **por baixo da névoa**: o passe vem antes do `NOM_VolFog`, então na névoa densa ele some
    junto com o zumbi.
- Até 4 Sem-rosto a até 20 tiles da câmera, os mais perto. **Sem Sem-rosto na tela não há custo:**
  não copia a cor da cena e pula o passe.
- **Desligar ou mudar o tamanho:** `NOMRender_setParam(13, s)`, com 0 desligado, 1 normal (padrão)
  e 1,5 maior.
- Sem o mod3, nada muda: o Sem-rosto fica com a casca de chiado da 0042.

## Decisões tomadas na ausência do Johan (fáceis de mudar)

Tudo em `mod3/42/media/shaders/NOM_Censura.frag` (constantes no topo) e `mod3/java/nom/render/Censor.java`:

- **Tamanho:** meio lado de 9 px iso por escala de tile, ou seja, a cabeça com folga (`HALF`). Os
  blocos do mosaico têm 3 px (`BLOCK`).
- **Mistura:** 60% chiado e 40% cena borrada (`STATIC`). Com mais cena, parece vidro fosco; com
  menos, vira um quadrado cinza.
- **Altura da cabeça:** `z + 0,52` andar (`Censor.HEAD_Z`). O alto do personagem pra UI do jogo é
  +0,6.
- **Cor da tela, sem tinta de névoa:** o chiado é cinza neutro. A cor vem da névoa por cima.
- **Teto de 4 quadrados e 20 tiles** (`Censor.MAX`, `Censor.RANGE`). Mudar o `MAX` pede mudar também
  o `uCensor[4]` no cabeçalho; um teste confere.

## Testes

- `tests/java/CensorTest.java` (5): fica o mais perto quando passa de 4; fora do alcance e invisível
  não entram; z no meio da cabeça; posição relativa à origem; só as duas peças do Sem-rosto contam.
- `tests/test_mod3_censor.lua`: contrato entre Lua, Java e GLSL (itens do `LOOKS.semrosto` no Java,
  ordem dos passes, param 13 ligado e lido no `uParams` certo, `MAX` igual ao `uCensor[]`, coleta que
  captura `Throwable` sem desligar a névoa, blit de cor só com quadrado).
- `tests/test_mod3_depth.py`: todo uniform novo do cabeçalho é ligado pelo Java.
- `glslangValidator` compila o shader novo (`test_mod3_flow.sh`).
- **O `RenderContext` compilou:** `scripts/build-mod3.sh` rodou na branch (o jar fica fora do git).

## Code review (fim da entrega)

- **Achado e corrigido:** `half` é palavra reservada em GLSL; o shader não compilava. Virou `side`.
- **Conferido:** o `ItemVisual.getItemType()` devolve o nome com módulo (`Base.`), por bytecode; a
  comparação com os itens do `LOOKS.semrosto` vale.
- **Conferido:** erro na coleta só apaga o quadrado daquele quadro e loga uma vez; a névoa segue (não
  chama o `fail` do RenderContext).
- **Conferido:** a textura da unidade 5 é salva e devolvida, como a 7 da profundidade.

## Roteiro de teste no jogo

1. `scripts/dev-sync.sh`, reiniciar o jogo, `-debug`, com o mod Volumétrica ativo.
2. Névoa branca (`NOM.setFog()`), `NOM.spawn(5)` e `NOM.variant("semrosto")` no zumbi mais perto (ou
   os botões do `NOM.panel()`).
3. Conferir: o quadrado fica na cabeça (nem no peito, nem flutuando), chia e mostra a cena borrada;
   some quando o zumbi passa atrás de uma parede; a névoa cobre; com zoom perto e longe continua do
   tamanho da cabeça.
4. `NOMRender_setParam(13, 0)` apaga; `1.5` aumenta; `1` volta.
5. FPS com três Sem-rosto na tela, com e sem o param 13.
6. Sem quadrado: procurar `rosto censurado` ou `NOM-Render` no `console.txt` e me mandar a linha.
