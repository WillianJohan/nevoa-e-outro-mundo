# Handoff — onde paramos

Atualizado em 2026-10-05. Vale pra quem continuar: Cursor, Claude ou humano. As regras do repo estão em [AGENTS.md](../AGENTS.md).

## Estado da `main`

- Sprints 0001–0022 entregues, todas `em teste`. O roadmap está em [sprints/README.md](sprints/README.md).
- 719 testes Lua, 4 de contraste e 25 de build, todos verdes.
- Mod principal em `mod/`. Shader de tela opcional em `mod2/`, incompatível com o ShadowZ.

**Confirmado no jogo pelo Johan:**
- noite, Eco, Carpideira, Sem-rosto;
- dissolve de mutação, de revert e da morte do Eco;
- overlay e shader;
- névoa vermelha com carência;
- brasa no corpo inteiro;
- comandos de debug: `NOM.help()` no console, painel no Insert.

## Em andamento (branches, sem merge)

### 1. Sprint 0023: Outro Mundo anexado (`sprint/0023-outro-mundo-anexado`)

**Problema:** o chão do Outro Mundo (sangue, sujeira, rachadura) usa `IsoMarkers`. Eles são desenhados DEPOIS dos personagens (`FBORenderCell.performRenderTiles`: `renderPlayers`@241, `IsoMarkers`@784), têm posição só inteira e cobrem o pé. O remendo atual apaga os 4 tiles em volta de cada personagem, e o Johan achou feio (deixa um buraco).

**Solução, confirmada no jogo pelo Johan via console:** prender os sprites no próprio `IsoObject` do chão e da parede, igual a erosão vanilla faz (`WallVines.update`@296 → `ErosionObjOverlay.setOverlay`). Assim o sprite entra no FBO do chunk (`renderOneChunk`@157), que é desenhado ANTES dos personagens, com luz e cutaway corretos.

- Adicionar: `obj:addAttachedAnimSpriteByName(nome)`.
- Remover só os nossos: percorrer `obj:getAttachedAnimSprite()` de trás pra frente, comparar `get(i):getParentSprite():getName()` e chamar `obj:RemoveAttachedAnim(i)`.
- **NUNCA** usar `RemoveAttachedAnims()`, que apaga as blends e a grama vanilla.
- **NUNCA** usar `AttachExistingAnim`, que altera o `IsoSprite` compartilhado.
- Testado pelo Johan: `getPlayer():getCurrentSquare():getFloor():addAttachedAnimSpriteByName("overlay_grime_floor_01_5")` fica embaixo do pé. `f_wallvines_1_2` na parede também funciona.

**Risco central, o save:** `IsoObject.save` grava a lista de anexos sem filtro.

- No MP o cliente nunca salva chunk (`IsoChunk.Save` retorna cedo com `GameClient.client`). Lá é seguro, desde que nada seja transmitido.
- No SP tem que limpar em quatro pontos:
  1. tirar tudo no `OnSave` e recolocar no `OnPostSave`;
  2. manter os anexos só num raio de ~15 tiles do player e tirar o que sair dele (o chunk que sai de vista é salvo sem evento Lua);
  3. no `LoadGridsquare`, faxinar o que for nosso com a névoa desligada (cobre hot-save e crash);
  4. tirar tudo quando a névoa acaba.
- Alvo: só floor e wall `IsoObject` comuns. Nada de `IsoThumpable`, porta ou janela.

**Escopo:**
- Chão: sangue, sujeira, rachadura, chão queimado (cara de "casa destruída"), mato em chão de fora.
- Parede: `f_wallvines_1_*`, `d_wallcracks_1_*`.
- Sai o código morto: `underfoot`, a varredura de personagens e os caminhos de `IsoMarker` do chão e das paredes.
- Adds e removes em lote, porque cada um invalida o nível do chunk.

**Como retomar:** `git worktree list`, entrar no worktree da 0023 e ler `docs/sprints/sprint-0023-outro-mundo-anexado/` (plano e README, se o agente chegou a criar). Terminar, rodar `./run-tests.sh`, fazer merge na `main` e rodar `dev-sync`.

### 2. Spike: ponte de dados GPU em Java (`spike/volumetric-fog-java`)

O Johan escolheu um **mod3 opcional em Java** carregado pelo ZombieBuddy (javaagent). O ShadowZ prova que o caminho existe: ele tem um `.jar` em `media/java/client/`. É só referência, nada copiado.

**Objetivo:** uma "ponte de dados" genérica que entrega aos shaders, todo frame:
- profundidade e cor da cena;
- câmera e projeção iso, pra reconstruir a posição no mundo;
- tempo;
- player e personagens mais perto;
- luzes próximas;
- estado da névoa vindo do Lua.

O primeiro efeito a usar a ponte é a **névoa volumétrica**: raymarch, densidade 3D, luz espalhando, névoa abrindo em volta dos personagens.

**Perguntas abertas do spike:**
- dá pra acessar a profundidade?
- como um mod se registra no ZombieBuddy?
- o que precisa pra compilar (JDK)?
- como distribuir? O Workshop sozinho não roda javaagent.

**Como retomar:** worktree em `.claude/worktrees/spike-volumetric`. Ver o que foi commitado em `mod3/`.

## Fila depois disso (decidida pelo Johan)

1. **Névoa em camadas em Lua**, pra todo mundo:
   - tufos presos no mundo em várias camadas com parallax, desenhados por cima dos personagens (aqui o `IsoMarker` serve);
   - névoa abrindo em volta de quem anda;
   - halo nas luzes.
2. **Névoa vermelha estilo Upside Down**, só inspiração em Stranger Things:
   - NÃO deixar tudo vermelho;
   - tentáculos pretos orgânicos em parede e chão, usando os anexos da 0023 com textura procedural nossa;
   - desgaste vermelho-escuro em manchas;
   - luz fria e escura pelo clima e pelo shader;
   - esporos e cinza flutuando no overlay de tela. As partículas de clima vanilla não têm cor e mexem na neve.
3. Mod3 de verdade, se o spike provar que dá.

## Decisões pendentes do Johan

- Arte da casca do Eco (`NOM_EcoFx.SHELL`) e a silhueta da casca de brasa.
- Sujeira na névoa vermelha: hoje é igual à da névoa normal, por causa do teto anti-xadrez. Ele ainda não confirmou.
- Features sugeridas pela pesquisa (rádio de bolso, sinalizador etc.): **recusadas**, não fazer.

## Contexto que não está no código

- Decisões de design: [gdd/Overview.md](gdd/Overview.md), seção "Decisões do autor".
- Balanceamento aprovado pelo PO: sprint 0019.
- Armadilhas caras: cada README de sprint tem a seção "Aprendizados".
