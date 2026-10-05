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

## Em teste no jogo (já na `main`, aguardando o Johan)

### Sprint 0023: Outro Mundo anexado
O chão e as paredes do Outro Mundo agora são sprites anexados ao `IsoObject` real, pelo mesmo caminho da erosão vanilla. Ficam embaixo do pé, sem buraco, e as paredes voltaram.
- O save seguro está na ADR-017.
- O roteiro no jogo está em `docs/sprints/sprint-0023-outro-mundo-anexado/README.md`.
- Riscos a olhar:
  - custo de FPS de invalidar o nível do chunk a cada lote;
  - chão de dentro aparecendo por cima do telhado;
  - um crash logo depois de um hot save deixa nome vanilla vazado.

### Spike da ponte GPU: mod3 opcional em Java
Código em `mod3/`, com evidências e checklist em `docs/sprints/spike-volumetrica/README.md`.
- A profundidade da cena existe: o shader copia o renderbuffer D24S8 por blit e reconstrói a posição de mundo de cada pixel.
- O passe entra com `@Patch` em `Core.EndFrame(int)`.
- Efeito novo = `media/shaders/NOM_X.frag` + o nome dele em `RenderContext.PASSES`.
- Do Lua: `NOMRender_setParam(i, v)`.
- Build: `scripts/build-mod3.sh`, com openjdk do brew e `--release 25`. O jar fica fora do git; o `dev-sync` copia o mod3 se o jar existir.
- **Primeiro teste:** `NOMRender_setParam(1, 1)`. A grade verde tem que grudar nos tiles.
- Ainda não feito: luzes, cor da cena, normais, in-scattering e cortar a névoa vanilla quando o mod3 estiver ativo.

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
