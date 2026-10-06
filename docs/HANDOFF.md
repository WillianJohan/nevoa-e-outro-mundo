# Handoff — onde paramos

Atualizado em 2026-10-06 (sprint 0033 implementada pelo Cursor). Vale pra quem continuar: Cursor, Claude ou humano. As regras do repo estão em [AGENTS.md](../AGENTS.md).

## Estado da `main`

- Sprints 0001–0022 entregues, todas `em teste`; 0023 concluída; **0024 (névoa fluida no mod3), 0025 (luz e volume na névoa), 0026 (névoa viajante, luz que abre a névoa), 0027 (névoa orgânica, sem vai e vem) , 0028 (névoa só nossa, sem a faixa embaixo), 0029 (ondas nos obstáculos), 0030 (névoa em alta resolução), 0031 (névoa que contorna), 0032 (névoa com altura) e 0033 (ritmo novo, na branch `sprint/0033-ritmo-novo`, ainda fora da `main`) `em teste`**. O roadmap está em [sprints/README.md](sprints/README.md).
- **Workshop:** publicado em 2026-10-05 como **não listado**, item [3814379207](https://steamcommunity.com/sharedfiles/filedetails/?id=3814379207) (ID em `docs/workshop/workshop-id.txt`), com os três mods (o principal, Shader e Volumétrica). Falta o teste da cópia baixada e abrir pra público ([publicar.md](publicar.md) §4–5).
- 791 testes Lua (na branch da 0033), 4 de contraste, os testes python do mod3 (profundidade e contrato Java/GLSL), os do núcleo da névoa fluida em Java (da 0024 à 0032, mais 3 do foco de vento da 0033) (com os shaders compilados pelo `glslangValidator`) e 29 de build, todos verdes (`./run-tests.sh`, precisa do JDK do brew).
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
| `NOMRender_setParam(9, s)` | resolução da névoa fluida: s células por tile, 1 a 3 (padrão 2; Opções > Mods manda sozinho, sprint 0030) |
| `NOMRender_setParam(10, v)` | vácuo atrás dos prédios: 1 ligado (padrão, escolhido pelo Johan no A/B), 0 a névoa enche o outro lado (sprint 0031) |
| `NOMRender_setParam(11, 1)` / `(11, 0)` | foco de vento de teste: liga sorteia um ponto a 15–30 tiles do jogador que sopra constante (2,5 tiles/s, raio 4) numa direção aleatória; desliga some; ligar de novo sorteia outro. Padrão 0. Pelo console: `NOM.wind(on)` (sprint 0033) |

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

## Estado atual: ritmo novo (sprint 0033)

**Implementada na branch `sprint/0033-ritmo-novo`, aguardando o review final e o teste do Johan no jogo.** Só depois entra na `main`, com push e `scripts/dev-sync.sh`.

O Johan mudou o mindset da névoa: ela é frequente (quase todo dia) e o fim dela é uma folga pra explorar. O mapa de tudo que vem é a spec [modelo novo](superpowers/specs/2026-10-06-modelo-novo-design.md) (sprints 0033 a 0044); o plano e o roteiro da 0033 estão em [sprints/sprint-0033-ritmo-novo/README.md](sprints/sprint-0033-ritmo-novo/README.md).

**O que a 0033 entrega:**
- **Agenda por dia** (`shared/NOM_FogEventRules.lua`): 65% subindo até 85% no dia 60, segunda névoa de 15% depois de 6 h de folga, garantia no terceiro dia sem névoa, branca de 3–5 h e vermelha (20% depois do dia 7, sem a subida da 0019) de 4–6 h. Determinística pelo número do dia e pela semente. Sandbox: `FogEventEveryDays` saiu; entraram `FogDailyChance`, `FogMaxDailyChance`, `FogEscalationDays`, `FogSecondChance`, `FogMinGapHours`, `FogMaxDaysWithout`, `RedFogMinHours`, `RedFogMaxHours` e `FogCalmHours`.
- **Sirene de 45 s com direção** (`server/NOM_FogEvent.lua`) e **congelamento** (`shared/NOM_SirenFreeze.lua`): todo zumbi para virado pra direção dela e ignora o jogador; a névoa começando solta todos. Quem simula aplica (ADR-005).
- **Calmaria** (`NOM_World.calm`, `NOM_NightRules`/`NOM_NightStats`): 2 h de jogo depois da névoa, o zumbi comum um degrau mais lento e de sentidos reduzidos.
- **Comandos de debug novos:** `NOM.setFog(skip)` (sempre branca), `NOM.setRedFog(skip)` (sempre vermelha), `NOM.setBlackFog()` (só avisa até a 0038), `NOM.setEndFog()`, `NOM.getZombie()`, `NOM.turnZombie(i)`, `NOM.godMode(on)` e `NOM.wind(on)`.
- **mod3:** foco de vento aleatório de teste, `NOMRender_setParam(11, 1)` (`WindSource.java`).
- **Docs:** GDD (`world-states.md`, `sandbox.md`, `Overview.md`) e emenda de 2026-10-06 na [ADR-009](architecture/adr-009-nevoa-evento-do-mod.md). Os presets Leve e Pesadelo da `sandbox.md` foram traduzidos sem jogar; o Johan ainda precisa confirmar.

**O que o Johan precisa conferir no jogo** (roteiro completo no README da sprint):
- a sirene de 45 s, todo mundo parado e virado pro mesmo lado, e a volta junta quando a névoa começa;
- **UNKNOWN (pz-api-notes §21):** o zumbi `useless` mantém a direção do `faceLocationF`, ou volta a girar sozinho entre as passadas do módulo (lote de 20 por tick)?
- a calmaria de 2 h e a duração de cada cor;
- o foco de vento no mod3 (precisa do `scripts/build-mod3.sh`; o jar é assinado e fica fora do git).

**Próximo passo:** a **0034 (sons)**, depois que o Johan ouvir as amostras do `scripts/gen_sounds.py` e escolher as sirenes (branca melhorada, vermelha bizarra com gritos, e um dos três conceitos da preta: fita morrendo, sirenes fora de fase ou quase silêncio). Não começar a 0034 antes da escolha. Quem pegar a 0034 também lê o resultado do UNKNOWN acima.

**Fluxo:** desde 2026-10-06 o code review acontece só no final de cada entrega ([AGENTS.md](../AGENTS.md)).

## Em teste: névoa com altura (sprint 0032)

Etapa 2 da [pesquisa](architecture/pesquisa-nevoa-volumetrica.md), enxuta:
- a densidade virou profundidade (1,0 = 0,8 andar);
- o carro tem 0,55 andar de altura e a cerca baixa (`HoppableW/N`, evidência no [pz-api-notes §20](architecture/pz-api-notes.md)) tem 0,4. Parede, prédio e cerca alta continuam fechados;
- numa face com obstáculo, só passa a parte da névoa acima dele: a rasa para, a funda empilha na frente e transborda;
- na face com obstáculo, a névoa empilhada escorre pro outro lado por gravidade. Em campo aberto não, pra não apagar os bancos nem o vácuo.

Roteiro em [sprints/sprint-0032-nevoa-com-altura/README.md](sprints/sprint-0032-nevoa-com-altura/README.md).


## Em teste: névoa que contorna (sprint 0031)

O Johan viu a névoa como fumaça passando entre os objetos, sem desviar nem encher o outro lado. A [pesquisa](architecture/pesquisa-nevoa-volumetrica.md) achou seis causas no nosso código. Esta sprint é a etapa 1 dela:
- o vácuo atrás do prédio virou opção (`NOMRender_setParam(10, v)`); no A/B o Johan preferiu com vácuo, que ficou o padrão (1);
- árvore é porosa (arrasto) e carro é obstáculo baixo (`F_LOW`, arrasto forte);
- a pressão começa da do passo anterior;
- a textura leva o acúmulo até 1,5;
- o rolo só sobe com obstáculo logo à frente no vento, não mais na esteira.

Roteiro em [sprints/sprint-0031-nevoa-que-contorna/README.md](sprints/sprint-0031-nevoa-que-contorna/README.md).


## Em teste: névoa em alta resolução (sprint 0030)

No debug de velocidade apareceu um xadrez: o reforço de redemoinho da 0029 lia a parede fina como giro (ar mexendo dentro da casa fechada) e criava redemoinhos do tamanho da célula. Agora a grade tem 1 a 3 células por tile (padrão 2), roda na thread `NOM-fluido` (a principal só lê o jogo e empilha a entrada; a grade é só da simulação, um teste estático garante) e o reforço age no giro médio de 2 tiles, sem parede nem interior. Roteiro em [sprints/sprint-0030-nevoa-em-alta-resolucao/README.md](sprints/sprint-0030-nevoa-em-alta-resolucao/README.md).


## Em teste: ondas nos obstáculos (sprint 0029)

A névoa passava lisa pela casa. Agora a esteira enrola (reforço de redemoinho no `FlowGrid`; na 0030 virou 0,6 por tile com média de 2 tiles) e o rolo sobe onde o ar freia contra a parede (`pileUp` no shader). Roteiro em [sprints/sprint-0029-ondas-nos-obstaculos/README.md](sprints/sprint-0029-ondas-nos-obstaculos/README.md).

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
