# Handoff — onde paramos

Atualizado em 2026-10-05 (noite, sprint 0024 entregue pelo Cursor). Vale pra quem continuar: Cursor, Claude ou humano. As regras do repo estão em [AGENTS.md](../AGENTS.md).

## Estado da `main`

- Sprints 0001–0022 entregues, todas `em teste`; 0023 concluída; **0024 (névoa fluida no mod3), 0025 (luz e volume na névoa), 0026 (névoa viajante, luz que abre a névoa), 0027 (névoa orgânica, sem vai e vem) , 0028 (névoa só nossa, sem a faixa embaixo) e 0029 (ondas nos obstáculos) `em teste`**. O roadmap está em [sprints/README.md](sprints/README.md).
- 711 testes Lua, 4 de contraste, os testes python do mod3 (profundidade e contrato Java/GLSL), 30 do núcleo da névoa fluida em Java (15 da 0024, 15 da viajante, do vento e do redemoinho) (com os shaders compilados pelo `glslangValidator`) e 25 de build, todos verdes (`./run-tests.sh`, precisa do JDK do brew).
- Mod principal em `mod/`. Shader de tela opcional em `mod2/`, incompatível com o ShadowZ. Mod Java opcional em `mod3/` (ponte GPU + névoa volumétrica + névoa fluida).

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
| `NOMRender_setParam(1, 5)` | fluido: obstáculos (sólido vermelho, árvore verde, interior azul, parede fechada branca) |
| `NOMRender_setParam(1, 6)` | fluido: densidade |
| `NOMRender_setParam(1, 7)` | fluido: velocidade |
| `NOMRender_setParam(2, h)` | altura da camada em andares (padrão 1,2) |
| `NOMRender_setParam(4, 0)` / `(4, 1)` | desliga / liga a névoa fluida (padrão ligada) |
| `NOMRender_setParam(5, 0)` / `(5, 1)` | visual antigo / rolos com sombra própria (padrão, sprint 0025) |
| `NOMRender_setParam(6, q)` | qualidade: 0 baixa, 1 média, 2 alta (padrão; Opções > Mods manda sozinho, sprint 0026) |
| `NOMRender_setParam(7, v)` | escala do véu de fundo (padrão 1; 0 = só rolos, sprint 0028) |
| `NOMRender_setParam(8, 1)` / `(8, 0)` | devolve / tira a névoa vanilla por baixo da nossa (padrão: tirada, sprint 0028) |

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

## Em teste: ondas nos obstáculos (sprint 0029)

A névoa passava lisa pela casa. Agora a esteira enrola (reforço de redemoinho no `FlowGrid`, força 0,8: acima de ~1,2 fecha o vácuo) e o rolo sobe onde o ar freia contra a parede (`pileUp` no shader). Roteiro em [sprints/sprint-0029-ondas-nos-obstaculos/README.md](sprints/sprint-0029-ondas-nos-obstaculos/README.md).

## Em teste: névoa só nossa (sprint 0028)

Com zoom afastado sobrava uma faixa sem névoa embaixo: era a névoa vanilla (`ImprovedFog`), que para antes da borda da tela. Com o mod Volumétrica ativo, ela é zerada por um patch e o shader desenha um véu de fundo. Roteiro em [sprints/sprint-0028-nevoa-sem-vanilla/README.md](sprints/sprint-0028-nevoa-sem-vanilla/README.md). A névoa vermelha funciona (rampa de 20 minutos de jogo).

## Em teste: névoa orgânica (sprint 0027)

O Johan detestou o "vai e vem" (rolos subindo e descendo juntos no lugar). Era o flow map de duas fases do shader. Agora o ruído anda pelo vento acumulado (`uDrift`, o mesmo dos bancos) e o vento vem de ruído (`Wind`). Roteiro em [sprints/sprint-0027-nevoa-organica/README.md](sprints/sprint-0027-nevoa-organica/README.md).

## Em teste: névoa viajante e luz na névoa (sprint 0026)

O Johan quer a névoa "viva", que caminha pelo mapa, desvia de objeto e faz vácuos, e a luz abrindo a névoa como a fumaça do CS2. A 0026 faz a névoa viajar em bancos com o vento (vácuo atrás de prédio, rastro que viaja), põe carro, porta, tiro e explosão empurrando, acende o facho de lanterna e farol dentro da névoa e põe a qualidade em Opções > Mods. Roteiro em [sprints/sprint-0026-nevoa-viajante/README.md](sprints/sprint-0026-nevoa-viajante/README.md).

- **Decidido:** sem partículas (a luz precisa do volume); simulação 2D por andar, altura no shader.
- **Ideia futura do Johan:** névoa preta (anotada no roadmap).
- **Se ainda faltar "vida":** volume por andares na GPU (subir escada, rolar por cima de muro), já discutido.

## Em teste: luz e volume na névoa (sprint 0025)

O Johan quer a névoa "viva", com física convincente (referência: fumaça interativa do Batman Arkham Knight). Antes de partir pra simulação 3D na GPU, a 0025 testa se o chapado vem da luz: rolos com silhueta, sombra própria e fiapos, só no shader. Roteiro e decisão que ela destrava em [sprints/sprint-0025-luz-da-nevoa/README.md](sprints/sprint-0025-luz-da-nevoa/README.md).

**Próximo, se ainda parecer chapado:** simulação 3D na GPU (OpenGL 3.3, sem compute shader: shaders de fragmento alternando entre duas texturas 3D), quebrada em spike → núcleo 3D → visual com sombra → fontes (jogador, zumbis, carros, porta, tiros e explosões) → opção de qualidade baixa/média/alta. O Johan quer todas essas fontes e aceita o custo desde que tenha opção de qualidade.

## Em teste: névoa fluida no mod3 (sprint 0024)

Tudo em [sprints/sprint-0024-nevoa-fluida/README.md](sprints/sprint-0024-nevoa-fluida/README.md): como funciona, critérios, decisões e o **roteiro in-game**. O plano e a evidência de bytecode estão no `plan.md` da mesma pasta.

**Resumo do que foi feito:**
- `FlowGrid.java` é o núcleo puro: grade escalonada de 128×128 tiles, com advecção por fluxo nas faces (parede é face fechada, nada atravessa) e projeção SOR red-black. O passo custa ~0,9 ms.
- `Flow.java` liga o núcleo ao jogo:
  - a máscara sai do `isBlockedTo`, `isSolid`, `HasTree`, `isOutside` e `getVehicleContainer`;
  - o vento vem do clima, e quem anda dá impulso;
  - roda a 20 Hz, e a textura vai pra unidade 6.
- `NOM_VolFog`:
  - densidade multiplicada pela do fluido, com o ruído levado pela velocidade;
  - mais denso no chão e mais cinza e fino em cima;
  - envolve a base das árvores;
  - modos de debug 5–7.

**O que o Johan precisa conferir no jogo:**
- o log `fluido: passo X ms, máscara Y ms/quadro`;
- o debug de obstáculos (porta abrindo e fechando);
- o rastro e a língua de névoa entrando pela porta (corrigido depois do primeiro teste: casa com uma porta só não enchia; agora escorre ~5 tiles pra dentro em ~30 s);
- o FPS com e sem a simulação (`NOMRender_setParam(4, 0/1)`).

Tudo isso é visual: os parâmetros (`outdoorRefill`, `indoorDecay`, força do impulso, cores) devem precisar de ajuste depois do primeiro print.

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
