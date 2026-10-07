# Handoff — onde paramos

Atualizado em 2026-10-06 (sprints 0035, com o hotfix do chão, e 0036 na `main`, sincronizadas e prontas pro teste no jogo). Vale pra quem continuar: Cursor, Claude ou humano. As regras do repo estão em [AGENTS.md](../AGENTS.md).

## Estado da `main`

- Sprints 0001–0022 entregues, todas `em teste`; 0023 concluída; **0024 (névoa fluida no mod3), 0025 (luz e volume na névoa), 0026 (névoa viajante, luz que abre a névoa), 0027 (névoa orgânica, sem vai e vem), 0028 (névoa só nossa, sem a faixa embaixo), 0029 (ondas nos obstáculos), 0030 (névoa em alta resolução), 0031 (névoa que contorna), 0032 (névoa com altura), 0033 (ritmo novo) e 0034 (sons I: sirene e fuga) `em teste`**. A **0035 (Outro Mundo estilo Silent Hill)**, com o hotfix do chão, e a **0036 (Equilíbrio: visão de ~4 tiles e perambular)** estão na `main` (`em teste`), sincronizadas pro jogo. O roadmap está em [sprints/README.md](sprints/README.md).
- **Workshop:** publicado em 2026-10-05 como **não listado**, item [3814379207](https://steamcommunity.com/sharedfiles/filedetails/?id=3814379207) (ID em `docs/workshop/workshop-id.txt`), com os três mods (o principal, Shader e Volumétrica). Falta o teste da cópia baixada e abrir pra público ([publicar.md](publicar.md) §4–5).
- 1069 testes Lua, 9 de contraste, 11 das texturas do Outro Mundo (`test_om_tiles.py`), os testes python do mod3 (profundidade e contrato Java/GLSL), os do núcleo da névoa fluida em Java (da 0024 à 0032, mais 3 do foco de vento da 0033) (com os shaders compilados pelo `glslangValidator`) e 29 de build, todos verdes (`./run-tests.sh`, precisa do JDK do brew).
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

## Em teste: Equilíbrio (sprint 0036)

Na `main` e sincronizada; falta o teste do Johan no jogo. O code review final achou 6 problemas importantes (o pior: o tiro deixava de puxar o zumbi até o jogador) e 7 menores, todos corrigidos antes do merge (seção "Code review final" do plano). Plano com a medição em [sprints/sprint-0036-equilibrio/plan.md](sprints/sprint-0036-equilibrio/plan.md); resumo, decisões e roteiro em [sprints/sprint-0036-equilibrio/README.md](sprints/sprint-0036-equilibrio/README.md).

- **Visão de ~4 tiles** na névoa branca e na vermelha (`shared/NOM_VariantAI.lua`). Vale pro zumbi comum e pro Sem-rosto: é a cegueira do Estalador, num rodízio de 30 zumbis por tick. O som acorda (`OnWorldSound`). Opção `FogZombieVision`.
- **Custo medido antes:** todo zumbi, todo frame, passava do teto (2700 chamadas por frame com a multidão). O rodízio dá média de 129 e pior tick de 452 com 300 zumbis.
- **Perambular** (`shared/NOM_WanderRules.lua`, `shared/NOM_Wander.lua`, `server/NOM_WanderServer.lua`). O servidor decide a onda a cada 4–8 min de jogo. Quem simula manda grupos de 1 a 3 parados andarem (`pathToLocationF`) pra longe do jogador. Opção `FogWander`.
- **Debug:** `NOM.wander()` e `NOM.blind()`, com botão no painel.

## Estado atual: Outro Mundo estilo Silent Hill (sprint 0035)

**Na `main` desde o merge `e73202b`, sincronizada e pronta pro teste do Johan no jogo.** O code review final não achou nada crítico; os 7 achados (o maior: o esquecimento da memória da varredura saiu do tick do carro) foram corrigidos antes do merge (seção "Code review final" do plano). Plano em [sprints/sprint-0035-silent-hill/plan.md](sprints/sprint-0035-silent-hill/plan.md); resumo, decisões e roteiro em [sprints/sprint-0035-silent-hill/README.md](sprints/sprint-0035-silent-hill/README.md).

**O que a 0035 entrega:**
- **Transição descascando:** quando a névoa abre ao vivo, a erosão se espalha em manchas ao longo de 6 s e recua do mesmo jeito em 4 s no fim. Quem carrega o save ou entra no meio vê o mundo já virado.
- **Lascas e cinza subindo** do chão e das paredes vestidas (`client/NOM_Flakes.lua`, `shared/NOM_FlakeRules.lua`), até 160 vivas, com rajada onde a erosão abre.
- **Tontura na transição** (~5 s): com o shader, a tela ondula, desdobra e turva; sem shader, a vinheta pulsa e escurece. Opção `Dizzy`, ligada por padrão.
- **50 texturas próprias Silent Hill** (`scripts/gen_tiles.py`): grade, ferrugem, chapa e tinta no chão; tinta, descasca e ferrugem nas paredes W e N. Viram sprite em runtime ([ADR-018](architecture/adr-018-sprite-proprio-em-runtime.md)).
- **Borda da tela ao andar:** a varredura lembra o que já viu; o anel de 25–30 tiles vai de 28% pra 87% vestido a 3 tiles/s.
- **Teto de custo do carro** em área densa (`LIGHT_DIV` 4): pior tick de ~3900 pra ~2250 chamadas ao Java.
- **Cobertura além da tela medida e não feita:** a margem do save não deixa (emenda da [ADR-017](architecture/adr-017-outro-mundo-anexado.md), item 11).
- **Debug:** `NOM.ownSprites()` e todo comando do `NOM.HELP` com botão no `NOM.panel()`.

**O que o Johan precisa conferir no jogo** (roteiro passo a passo no README da sprint):
- legibilidade das lascas, FPS, a tontura (duração, ondulação, imagem dupla) e a duração da transição;
- texturas: nitidez no zoom 0,5–2,5, grade em piso escuro, ferrugem de longe, profundidade na parede W, N e de canto com recorte, decalque embaixo do jogador e do zumbi, textura vazia na primeira névoa depois de carregar;
- sair e voltar ao save com névoa (nada vazado);
- pendências da 0034 no mesmo teste: congelamento da sirene depois da correção `isLocal`, IA das variantes no solo, chão sem sangue.

**Decisões tomadas em nome do Johan na 0035** (ele deu autonomia; revisar no teste):
- **Não cobrir além da tela:** a margem do save manda (raio + folga ≤ 42 com o carro a 2 tiles por tick), e o ganho é pequeno.
- **Caminho 1b** (sprite criado em runtime a partir do PNG) em vez de tile pack; o tile pack fica de plano B se a textura ficar ruim no jogo.
- **A tinta da parede só desenha o buraco:** a tinta que fica é a parede do jogo, então serve em qualquer cor.
- **Sem vermelho no chão:** a tinta de chão é amarelo industrial desbotado.
- **Preta fica pra 0038:** a regra só conhece branca e vermelha.
- **Tontura ligada por padrão**, com opção própria e presa à intensidade 1.
- **Pesos do sorteio:** branca com ~1/3 do chão vestido em metal (Grade 0,4, Ferrugem 0,25, Chapa 0,2, Tinta 0,15) e tinta como a camada mais comum da parede; vermelha com sangue de parede e ferrugem.
- **Teto de custo do carro:** trocar de desenho dirigindo tira o desenho velho mais devagar (20 alvos por atualização).

## Em teste: sons I, sirene e fuga (sprint 0034)

**Na `main` desde o merge `615df0f`.** Plano em [sprints/sprint-0034-sons/plan.md](sprints/sprint-0034-sons/plan.md); resumo, decisões e roteiro em [sprints/sprint-0034-sons/README.md](sprints/sprint-0034-sons/README.md). O mapa de tudo que vem é a spec [modelo novo](superpowers/specs/2026-10-06-modelo-novo-design.md).

**O que a 0034 entrega:**
- **Presságio:** 3 s antes da sirene, a tela ganha estática na cor da névoa (fraca no começo, forte no fim), que fica sutil a névoa toda; os aparelhos a até 25 tiles estouram em chiado.
- **Coro de sirenes ao longe** (`shared/NOM_Siren.lua`, `shared/NOM_SirenSpotsRules.lua`): 5 por jogador, a 150–500 tiles, de lados diferentes, desencontradas em até 4 s, com afinação 0,95–1,05. 31 sons nossos de 11,8 s (9 brancas, 9 vermelhas e 13 pretas, que só tocam na 0038).
- **Fuga de 30 s** (`R.GRACE_MS`): a névoa visual, a vinheta e o drone sobem na sirene (`NOM_World.rising`); bichos, Sem-rosto e Outro Mundo só no fim. Os zumbis congelados viram pro jogador vivo mais perto e acompanham ele andando.
- **Correção do solo:** dono do zumbi é `isLocal()`, não `isRemoteZombie()` (no solo a sirene não congelava ninguém, e a IA das variantes não rodava) ([pz-api-notes §24](architecture/pz-api-notes.md#24-dono-do-zumbi-islocal-não-isremotezombie-sprint-0034)).
- **Aparelhos do Outro Mundo** (`client/NOM_Devices.lua`): TV, rádio, caixa de som e carro "falam" na névoa, ligados ou não.
- **Outro Mundo:** raio pela tela (15 a 30 tiles pelo zoom), casa destruída (paredes de dentro em até 3 camadas, pichações e mensagens inteiras) e **sem sangue no chão** (o de parede fica).

**O que o Johan precisa conferir no jogo** (roteiro completo no README da sprint):
- a estática antes da sirene; o coro de 5 vindo de lados diferentes; a névoa subindo nos 30 s de fuga;
- no solo, o log `[NOM] sirene congelados=N ... pulados morto/remoto/jogo=0/0/0` (o `remoto` tem que ser 0) e os zumbis virados pra ele;
- os aparelhos chiando no presságio e falando na névoa;
- **UNKNOWNs:** audibilidade a 500 tiles e direção do som; FPS da erosão em tela toda no zoom longe; legibilidade das pichações; nível da estática; se o chão sem sangue ficou vazio demais.

## Em teste: ritmo novo (sprint 0033)

Na `main` desde o merge `cdc3331`. Névoa sorteada por dia (65% subindo até 85%, segunda névoa, garantia no terceiro dia), duração por cor, calmaria de 2 h, comandos `NOM.setFog`/`setRedFog`/`setEndFog`/`getZombie`/`turnZombie`/`godMode`/`wind` e foco de vento no mod3. A sirene de 45 s com direção única da 0033 foi trocada pela 0034. Roteiro e pendências em [sprints/sprint-0033-ritmo-novo/README.md](sprints/sprint-0033-ritmo-novo/README.md). Os presets Leve e Pesadelo da `sandbox.md` foram traduzidos sem jogar; o Johan ainda precisa confirmar.

## Próximo passo

1. **Testar a 0035 e a 0036 no jogo:** o Johan reinicia o jogo e segue os roteiros da [0035](sprints/sprint-0035-silent-hill/README.md#roteiro-de-teste-no-jogo) e da [0036](sprints/sprint-0036-equilibrio/README.md). Já confirmado no jogo em 2026-10-06: o congelamento da sirene depois da troca pra `isLocal` (97 de 97 parados), as paredes Silent Hill ("ficaram top"). O chão estranho (metal em bloco na calçada, ferrugem em grade na grama) foi corrigido no hotfix `7149d87`: falta o Johan conferir.
2. **Fila 0037–0044** ([spec §10](superpowers/specs/2026-10-06-modelo-novo-design.md#10-fila-de-sprints)):
   - **0037** — sonar do Estalador;
   - **0038** — névoa preta I: escuridão, Tição, luz que congela, lanterna piscando (e o visual preto do Outro Mundo);
   - **0039** — névoa preta II: névoa preta que a luz empurra (mod3) e Outro Mundo queimado;
   - **0040** — vermelha nova: tentáculos e cinza no ar;
   - **0041–0044** — facelift: spike, outros monstros, teste de IA no Tição, rosto censurado.

**Fluxo:** desde 2026-10-06 o code review acontece só no final de cada entrega ([AGENTS.md](../AGENTS.md)). **Branches, desde 2026-10-06 (noite):** sprints saem da `staging` e voltam pra ela; a `main` é só o mod lançado (merge `staging` → `main` quando o Johan lança uma versão). No jogo, o mod de desenvolvimento ganha ID `_Dev` e nome `[DEV]` (pendente no `dev-sync.sh`, entra na renomeação pra "NOM: Noise of Mist"). Detalhes no [AGENTS.md](../AGENTS.md).

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
   - Atualização do Johan (06/10/2026): o visual do Outro Mundo passa a ser **mais Silent Hill** (ferrugem, tinta descascando, grade metálica, lascas subindo). O item 3 (sprint 0035) tem prioridade sobre este; os tentáculos e a cinza continuam na 0040.
3. ~~**Sprint 0035 — Outro Mundo estilo Silent Hill**~~: feita (em teste). Saiu sem shader de dissolve na tela e sem máscara pelo mod3: a transição é a erosão abrindo em manchas, com lascas e tontura ([README da sprint](sprints/sprint-0035-silent-hill/README.md)). O plano original, logo depois de fechar a 0034 (decisão do Johan, 06/10/2026): Parte do Outro Mundo da 0034: raio pela tela, casa destruída e sangue no chão já tirado (parecia textura ruim de jogo antigo; o sangue de parede fica).
   - Texturas procedurais nossas (`scripts/gen_*.py`) anexadas no chão e nas paredes pela erosão: tinta descascando, ferrugem, grade. UNKNOWN: como registrar sprite próprio pro `addAttachedAnimSpriteByName` (tile pack nosso ou outra via). Conferir antes de prometer.
   - Partículas presas no mundo, saindo do chão e das paredes perto do jogador e subindo: lascas girando e cinza. Sprite sheet gerado em Python, algumas centenas por quadro.
   - Transição na chegada da névoa, logo depois da sirene: o shader dissolve a tela com ruído ("descascando") e uma leva de lascas voa pra cima.
   - Transição escondida e tontura, que eram da 0036 ([spec §7](superpowers/specs/2026-10-06-modelo-novo-design.md#7-outro-mundo)): o mundo vira enquanto a névoa está densa demais pra ver e desvira no começo da descida; ~5 s de tontura por jogador, desligável em Opções > Mods.
   - Máscara por textura de tile só pelo mod3 (Java). É o mais arriscado e fica por último.
   - Critério de desempenho: FPS, memória e tempo de save com o Outro Mundo cheio ([spec §11](superpowers/specs/2026-10-06-modelo-novo-design.md#11-testes-e-erros)).
4. ~~Mod3 de verdade~~: o spike provou que dá; ele já está em uso (ver acima). Depois da névoa fluida, as luzes da ponte (`IsoCell.getLamppostPositions`, `roomLights`, `lightInfo.torches`) abrem in-scattering e um bloom de verdade.

## Decisões pendentes do Johan

- Arte da casca do Eco (`NOM_EcoFx.SHELL`) e a silhueta da casca de brasa.
- Sujeira na névoa vermelha: hoje é igual à da névoa normal, por causa do teto anti-xadrez. Ele ainda não confirmou.
- Features sugeridas pela pesquisa (rádio de bolso, sinalizador etc.): **recusadas**, não fazer.

## Contexto que não está no código

- Decisões de design: [gdd/Overview.md](gdd/Overview.md), seção "Decisões do autor".
- Balanceamento aprovado pelo PO: sprint 0019.
- Armadilhas caras: cada README de sprint tem a seção "Aprendizados".
