# Handoff — onde paramos

Atualizado em 2026-10-05 (fim do dia, passagem pro Cursor). Vale pra quem continuar: Cursor, Claude ou humano. As regras do repo estão em [AGENTS.md](../AGENTS.md).

## Estado da `main`

- Sprints 0001–0022 entregues, todas `em teste`. O roadmap está em [sprints/README.md](sprints/README.md).
- 707 testes Lua, 4 de contraste, os testes python do mod3 e 25 de build, todos verdes (`./run-tests.sh`).
- Mod principal em `mod/`. Shader de tela opcional em `mod2/`, incompatível com o ShadowZ. Mod Java opcional em `mod3/` (ponte GPU + névoa volumétrica).

**Confirmado no jogo pelo Johan:**
- noite, Eco, Carpideira, Sem-rosto;
- dissolve de mutação, de revert e da morte do Eco;
- overlay e shader;
- névoa vermelha com carência;
- brasa no corpo inteiro;
- comandos de debug: `NOM.help()` no console, painel no Insert.

## Concluído e confirmado no jogo

### Sprint 0023: Outro Mundo anexado
O chão e as paredes do Outro Mundo são sprites anexados ao `IsoObject` real, pelo mesmo caminho da erosão vanilla: embaixo do pé, sem buraco, com as paredes de volta.
- **Confirmado pelo Johan:** chão, telhado, save e FPS.
- O save seguro está na ADR-017.

### mod3: ponte GPU + névoa volumétrica (confirmado no jogo, print bonito)
Código em `mod3/`. Evidências, achados e checklist em `docs/sprints/spike-volumetrica/README.md`.

**Como funciona:**
- O jar Java é carregado pelo ZombieBuddy (javaagent).
- `@Patch` em `Core.EndFrame(int)` enfileira um `GenericDrawer` que roda depois do mundo e antes do `screen.frag` e da UI.
- A profundidade da cena (renderbuffer D24S8) é copiada por blit pra uma textura nossa.
- O shader reconstrói a posição de mundo de cada pixel. As contas são relativas a uma origem perto da câmera (`uOrigin`) pra não perder precisão em float32.
- **Confirmado no jogo:** a grade fica presa nos tiles e a névoa forçada aparece.

**Efeito novo:**
- `media/shaders/NOM_X.frag`, com o cabeçalho `NOM_RenderContext.glsl`.
- Mais o nome dele em `RenderContext.PASSES`.

**Console:** `NOMRender_setParam(i, v)`. Os parâmetros ficam em `uParams[0]`:

| Comando | O que faz |
|---|---|
| `NOMRender_setParam(0, d)` | densidade forçada; 0 usa a névoa do clima |
| `NOMRender_setParam(1, 0)` | sem debug |
| `NOMRender_setParam(1, 1)` | grade |
| `NOMRender_setParam(1, 2)` | profundidade |
| `NOMRender_setParam(1, 3)` | andar |
| `NOMRender_setParam(1, 4)` | `abs(z)`: chão preto liso = certo |

**Build e instalação (armadilhas que custaram caro):**
1. `scripts/build-mod3.sh` compila com o openjdk do brew (`--release 25`; o jogo roda no Zulu 25) e **assina** o jar.
   - A assinatura gera um `.jar.zbs` (Ed25519) com a chave em `~/.signing/nom-zbs-ed25519.pem`, que fica FORA do repo.
   - A chave pública já está no perfil Steam do Johan (`JavaModZBS:2b648abc…`). Sem ela no perfil, o ZB **exclui** o jar (assinatura inválida é pior que sem assinatura).
   - O Johan marcou Trust author, então build novo passa sem perguntar.
2. Depois, `scripts/dev-sync.sh`. O jar fica fora do git.
3. **ZombieBuddy:**
   - O jar do jogo foi atualizado pra 2.3.4 (backup em `ZombieBuddy.jar.2.3.2.bak`).
   - Docs e fonte estão no Workshop 3619862853.
   - Pra ver o log detalhado: `-javaagent:ZombieBuddy.jar=verbosity=2 -- -debug`.
4. **O advice é inlinado dentro da classe do jogo.** Todo método do mod3 chamado do `@Patch` precisa ser `public`, senão dá `IllegalAccessError` e o jogo crasha. Há um teste pra isso em `tests/test_mod3_depth.py`.
5. **Mod ativado só no save** carrega o jar depois do `exposeAll`, e aí os `@LuaMethod` globais não existem. O `Main.java` registra na hora do load. Pra a janela de aprovação aparecer no startup, ative o mod no menu Mods do menu principal.
6. **ShadowZ:** deixar desligado na janela do ZB, porque briga com o shader do mod2.

## Próximo: névoa fluida no mod3 (pedido do Johan, NÃO iniciado)

O Johan quer a névoa interagindo com os objetos **como um líquido**:
- contorna prédios, paredes, árvores e carros em vez de atravessar;
- acumula nos abertos e escorre por frestas e portas abertas;
- é empurrada por quem anda, deixando rastro.

**Desenho proposto** (ajustar com evidência):
1. **Grade.** Simulação de fluido 2D (stable fluids: advect, diffuse, project; ou só advecção, se justificar) numa grade de ~96–128 tiles em volta do personagem da câmera, com 1–2 células por tile.
   - Ancorada em tile inteiro do mundo e rolada quando o jogador anda, pra ficar presa no mundo.
2. **Máscara de obstáculos**, montada na thread principal a cada N frames a partir dos squares do `IsoCell`.
   - Bloqueiam: square sólido, paredes N/W, árvores e carros, se for barato.
   - Porta e janela fechadas bloqueiam; abertas não.
   - Square não carregado conta como aberto.
   - Achar as APIs no bytecode. O disassembler da sessão anterior pode não existir mais; use `javap -c` do openjdk do brew.
3. **Forças:**
   - vento ambiente lento, com a direção mudando com o tempo;
   - impulso de cada personagem que se move (as posições já são coletadas no `RenderContext`);
   - densidade entrando pelas bordas;
   - dentro de prédio a densidade decai, a não ser que entre por abertura.
4. **Upload** da densidade (e da velocidade, se precisar) como textura pequena a cada passo, na thread de render.
   - O `NOM_VolFog` multiplica o ruído 3D pela densidade amostrada no xy do mundo (`uOrigin` + origem da grade).
   - O ruído 3D continua, advectado pela velocidade.
5. **Custo:** 15–30 Hz desacoplado do FPS, com meta de menos de 1 ms na CPU em 128x128. GPU com FBO ping-pong é aceitável se a CPU não der conta.
6. **Controles:** um índice no `NOMRender_setParam` liga e desliga a simulação, e um modo de debug mostra obstáculos, densidade e velocidade.
7. **Testes** (Java puro ou python) do núcleo da simulação:
   - não entra em caixa fechada;
   - passa por fresta de 1 tile;
   - a rolagem preserva a densidade no mundo;
   - o impulso desloca densidade.

**Ajustes visuais vistos no print do Johan:**
- A névoa está branca e chapada demais. Deixar mais densa no chão, mais cinza e suave em cima, com a cor ainda vinda do clima.
- As árvores ficam acima da névoa, porque o sprite tem profundidade única e o z reconstruído sobe. Aceitar, ou usar a máscara de obstáculos pra envolver a base.

**Regra de ouro:** nada no mod3 pode derrubar o jogo. Todo caminho chamado do patch ou da thread de render captura `Throwable`, loga `[NOM-Render] ERRO` e se desliga.

**Pra testar com o Johan:** depois do `dev-sync`, ele reinicia o jogo. Acompanhe com:
```bash
tail -F ~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt | grep -E "NOM-Render|ZBS verification|IllegalAccess|uncaughtException"
```

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
3. ~~Mod3 de verdade~~: o spike provou que dá; ele já está em uso (ver acima). Depois da névoa fluida, as luzes da ponte (`IsoCell.getLamppostPositions`, `roomLights`, `lightInfo.torches`) abrem in-scattering e um bloom de verdade.

## Decisões pendentes do Johan

- Arte da casca do Eco (`NOM_EcoFx.SHELL`) e a silhueta da casca de brasa.
- Sujeira na névoa vermelha: hoje é igual à da névoa normal, por causa do teto anti-xadrez. Ele ainda não confirmou.
- Features sugeridas pela pesquisa (rádio de bolso, sinalizador etc.): **recusadas**, não fazer.

## Contexto que não está no código

- Decisões de design: [gdd/Overview.md](gdd/Overview.md), seção "Decisões do autor".
- Balanceamento aprovado pelo PO: sprint 0019.
- Armadilhas caras: cada README de sprint tem a seção "Aprendizados".
