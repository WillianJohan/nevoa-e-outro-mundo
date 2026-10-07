# Plano da sprint 0044: rosto censurado do Sem-rosto

**Objetivo:** com o mod3, um quadrado de censura de TV sobre a cabeça do Sem-rosto: a cena atrás
borrada em mosaico, chiando, escondido pela parede ([spec §9, item 4](../../superpowers/specs/2026-10-06-modelo-novo-design.md#9-facelift-dos-monstros)).

**Arquitetura:** é visual e local, então fica toda no cliente (mod3), sem servidor. O RenderContext
já tira um retrato por quadro na main thread e desenha os passes na render thread; a sprint
acrescenta:

1. **Main thread** (`RenderContext.collectCensors`): zumbis a até 20 tiles da câmera com a peça do
   Sem-rosto na lista de `ItemVisual` (a que o `client/NOM_VariantLook.lua` preenche), até 4, os mais
   perto. Cada um vira `x, y` relativos a `uOrigin`, `z` do meio da cabeça e o alfa do zumbi pra este
   jogador (`IsoObject.getAlpha(int)`). A conta pura fica em `Censor.java`.
2. **Render thread:** só com quadrado na tela, copia a cor da cena (o FBO do jogador) pra uma textura
   nossa na unidade 5, com o mesmo blit da profundidade.
3. **Passe `NOM_Censura`**, antes do `NOM_VolFog` (a névoa cobre o quadrado): projeta a cabeça na tela
   iso, desenha o quadrado em blocos com a cena borrada (4 amostras) misturada a chiado e varredura,
   e some onde a profundidade da cena está na frente da cabeça.
4. **Param 13** (`PARAM_CENSOR`): 0 desliga a coleta e o passe; o valor escala o quadrado.

**Evidência:** [pz-api-notes §33](../../architecture/pz-api-notes.md) (`getZombieList`,
`getItemVisuals`, `getItemType`, `getAlpha(int)`, altura da cabeça, blit de cor).

## Tarefas (TDD)

1. **Teste antes:** `tests/java/CensorTest.java` (o mais perto fica quando passa de 4; fora do
   alcance e alfa ~0 não entram; z vai pro meio da cabeça; posição relativa à origem; só os dois
   itens do Sem-rosto contam). Depois `Censor.java` até passar.
2. **Teste antes:** `tests/test_mod3_censor.lua`, contrato entre Lua, Java e GLSL:
   - os itens do `LOOKS.semrosto` aparecem em `Censor.java`;
   - `NOM_Censura` vem antes de `NOM_VolFog` em `PASSES`;
   - `PARAM_CENSOR` < 16, ligado por padrão e lido pelo shader no `uParams` certo;
   - `Censor.MAX` igual ao tamanho de `uCensor[]` no cabeçalho;
   - a coleta captura `Throwable`, não chama `fail(` (que desliga a névoa) e usa o alfa por jogador;
   - o blit de cor só roda com quadrado (`censorCount > 0`);
   - o `CensorTest` roda no `test_mod3_flow.sh`.
3. `RenderContext.java`, cabeçalho (`uScene`, `uCensorCount`, `uCensor`, `nomWorldToIso`,
   `nomIsoToFrag`, `nomDepthOf`) e `NOM_Censura.frag`. O `test_mod3_depth.py` confere que todo
   uniform do cabeçalho é ligado pelo Java; o `glslangValidator` compila o shader.
4. Evidência, docs, HANDOFF (linha do param 13), `./run-tests.sh`, review.

## Fora

- Sem o mod3 não há quadrado: o Sem-rosto continua com a casca de chiado da 0042.
- Sem som de chiado no quadrado (a sirene e os aparelhos já chiam; fica pra uma sprint de sons).
