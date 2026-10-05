# Spike: névoa volumétrica em Java (mod3)

| Status | em teste |
|---|---|
| Branch | `spike/volumetric-fog-java` |
| Mod | `mod3/` → `NevoaEOutroMundo_Volumetrica` (opcional, só cliente, ZombieBuddy) |

**Pergunta:** dá pra ter névoa volumétrica de verdade (densidade 3D, abre em volta dos
personagens, tingida de vermelho) com Java via ZombieBuddy, sem tocar no Lua do mod?
**Resposta da análise estática: sim.** A profundidade da cena existe e dá pra amostrar
(com uma cópia), e dela sai a posição de mundo de cada pixel. Falta o teste no jogo.

Nada do ShadowZ foi aberto além do `mod.info` e dos nomes de pasta. Evidência:
bytecode do B42.21 (`projectzomboid.jar` instalado) e o código-fonte do ZombieBuddy
que vem no item do Workshop (3619862853, `java/src`, `doc/ModdingGuide.md`).

## 1. Contrato do ZombieBuddy

- `mod.info`: `require=...,\ZombieBuddy`, `javaJarFile=media/java/client/X.jar`
  (`client/` = só cliente: o dedicado pula), `javaPkgName=nom.render`, `ZBVersionMin=2.3.2`.
- O jar entra no classpath do sistema (`Loader.java:512`,
  `appendToSystemClassLoaderSearch`), na carga dos mods (`onExitLoadMods`). Classe `Main`
  opcional. O ZB acha sozinho, no pacote, toda classe com `@Patch` e todo método
  estático `@LuaMethod(global = true)` (`Exposer.java:45-64, 296`).
- Hook: `@Patch(className, methodName)` + `@Patch.OnEnter`/`OnExit` (Advice do
  ByteBuddy, empilha com o de outros mods). Com `@Patch.Argument(0) int` o ZB infere a
  assinatura e casa só `EndFrame(I)V` (`PatchEngine.java:322-488`).
- Toolchain: JDK ≥ 25 (o jogo roda no Zulu 25.0.1, `jre64/release`); `brew install openjdk`
  (deu o 27; compila com `--release 25`). `scripts/build-mod3.sh`.

## 2. Ponto do render e profundidade

| Fato | Evidência |
|---|---|
| Ordem por jogador: `IsoWorld.render` → `Core.EndFrame(int)` → (todos) `Core.RenderOffScreenBuffer` → UI | `IngameState.renderFrameInternal` 83, 160; `IngameState` 192 |
| `RenderOffScreenBuffer` → `MultiTextureFBO2.render`: desenha o FBO de cada jogador com o `weatherShader` (`screen.frag`) | `MultiTextureFBO2.render` 61–204 |
| O FBO da cena (`offscreenBuffer.current`) é `new TextureFBO(tex)` → `useStencil = true` | `MultiTextureFBO2.createTexture` 35–57; `TextureFBO.<init>(ITexture)` 2–3 |
| **A profundidade dele é um renderbuffer `GL_DEPTH24_STENCIL8`**, sem textura: não dá pra amostrar direto | `TextureFBO.initInternal` 363–598 (`depthTexture` nulo → `glRenderbufferStorage(DEPTH24_STENCIL8)`) |
| **Ela tem a cena inteira**: o chão/parede dos chunks escreve `gl_FragDepth = chunkDepth + texel do mapa de profundidade do tile` ao compor; modelos e sprites escrevem pela mesma conta | `media/shaders/chunkShader.frag`, `tileWithDepth.frag`; `IsoSprite.renderTextureWithDepth` → `IsoDepthHelper.getSquareDepthData` |
| A profundidade é **afim no mundo**: `d = C − k(x+y) − 2k·z`, `k = SQUARE_DEPTH/2` | `IsoDepthHelper.calculateDepth` 0–55, `getChunkDepthData` 224–277 (`0.46187/40/8` por tile = `0.0230937/16`); `LEVEL_DEPTH = SQUARE_DEPTH` |
| A tela iso: `sx = 32T(x−y)`, `sy = 16T(x+y) − 96T·z`; `ortho2D(0, w·zoom, h·zoom, 0)`; câmera em `IsoCamera.frameState` (`offX`, `offY`, `zoom`) | `IsoUtils.XToScreen/YToScreen`; `Core.DoStartFrameStuffInternal` 205–215 |

**Conclusão:** profundidade acessível com **uma cópia por quadro** (`glBlitFramebuffer`
do renderbuffer pra uma textura `DEPTH24_STENCIL8` nossa, só o retângulo do jogador). Com
ela e a âncora `C` (a profundidade do personagem da câmera, pela mesma chamada que o
jogo usa) o shader resolve `(x, y, z)` de cada pixel: 3 equações lineares, 3 incógnitas
(`tests/test_mod3_depth.py`). Volumétrico de verdade, não falso.

Gancho: `@OnEnter Core.EndFrame(int)` enfileira um `TextureDraw.GenericDrawer`
(`SpriteRenderer.drawGeneric`), que roda no render thread com o FBO do jogador ainda
preso: depois do mundo, antes do `screen.frag` (mod2 continua por cima) e da UI.

## 3. NOM render context (o que cada canal custa)

Um cabeçalho GLSL (`mod3/42/media/shaders/NOM_RenderContext.glsl`) é o contrato; o Java
põe na frente de todo passe. **Efeito novo = um `media/shaders/NOM_X.frag` + o nome em
`RenderContext.PASSES`.**

| Canal | Status | Fonte | Custo por quadro |
|---|---|---|---|
| Profundidade (`uDepth`) | **no protótipo** | blit do renderbuffer (§2) | 1 blit D24S8 do viewport (~8 MB a 1080p, ~0,1 ms) |
| Posição de mundo (`nomWorldPos`) | **no protótipo** | `uCam` + `uDepthRef` + `uViewport` | ~10 flops/pixel |
| Normal | obtível, não feito | `cross(dFdx(P), dFdy(P))` no shader | ~0 |
| Cor da cena | obtível, não feito | segundo blit (`GL_COLOR_BUFFER_BIT`) pra textura nossa; hoje o passe só mistura por cima | 1 blit RGBA8 (~0,1 ms) |
| Tempo (`uTime`) | **no protótipo** | `System.nanoTime` | 0 |
| Personagens perto (`uChars[8]`) | **no protótipo** | `IsoPlayer.players` + `IsoCell.getZombieList()`, 8 mais perto em 20 tiles | O(zumbis carregados), µs |
| Luzes (`uLights[16]`, a fazer) | obtível | `IsoCell.getLamppostPositions()` (`IsoLightSource`: x, y, z, r, g, b, radius, active), `IsoCell.roomLights` (`IsoRoomLight`), lanternas em `IsoGameCharacter.lightInfo.torches` | O(luzes carregadas), µs; no shader 16 luzes × passos |
| Estado da névoa (`uFog`) | **no protótipo** | `ClimateManager.getFogIntensity()` + `getClimateColor(1).getFinalValue().getExterior()` — o mod principal **já escreve** os dois (`NOM_ClimateLook.lua:74, 121`), e o clima chega no cliente de MP. Vermelha = a cor | 0 |
| Params do Lua (`uParams[4]`) | **no protótipo** | `NOMRender_setParam(i, v)` (global Lua do ZB); `NOMRender_isActive()` pro Lua saber que o mod3 está vivo | 0 |
| Altura do mundo | grátis | `P.z` da reconstrução | 0 |

Custo do protótipo: blit + 1 passe de tela cheia, 12 passos × fbm de 3 oitavas × 8
personagens. Estimativa 1–2 ms a 1080p numa GPU média; se pesar, meia resolução.
CPU: ~15 `glGet` de estado por quadro (salvar e restaurar o GL do jogo).

## 4. Desenho da névoa (`NOM_VolFog.frag`)

- Pixel → `P` no mundo. Raio rumo à câmera iso = `(3, 3, 1)` em (tile, tile, andar)
  (tela fixa ⇒ `ds = 6dz`, `x − y` fixo).
- Marcha de `P` até o topo da camada (andar do jogador + `uParams[0].z`, padrão 1 andar),
  12 passos com jitter. Densidade = fbm 3D com vento × queda com a altura × abertura em
  volta de cada personagem do mesmo andar. Extinção de Beer, saída pré-multiplicada.
- Vermelha: a cor vem do clima, que o mod já pinta.
- A fazer depois do teste: in-scattering das luzes (`Σ cor·exp(−dist²/r²)` por passo),
  sombra de luz (não tem: luz é nativa, `LightingJNI`), meia resolução + upsample por
  profundidade, cortar a névoa vanilla (`ImprovedFog`) quando o mod3 está ativo.

## 5. Riscos

- **MP:** só visual e só cliente; cada cliente que quer ver precisa do ZombieBuddy. O
  servidor e os outros clientes não precisam de nada (o jogo não confere jar). Quem não
  tem, vê a névoa Lua de sempre.
- **Patch do jogo:** quebra se mudar `Core.EndFrame(int)`, o formato da profundidade
  (`TextureFBO`), as constantes do `IsoDepthHelper` ou a conta do `IsoUtils`. O teste
  `test_mod3_depth.py` trava a álgebra; a constante de cada versão tem que ser conferida
  no bytecode. Erro de GL desliga o contexto e loga `[NOM-Render] ERRO` (sem travar).
- **Estado de GL:** o jogo cacheia estado (`GLStateRenderThread`); o passe salva e
  restaura tudo que mexe. Se algo ficar errado na UI, é aqui.
- **Mac:** precisa de GL 3.3; sem ele o shader não compila e o passe desliga.

## 6. Workshop

Item próprio (como o mod2), `require=NevoaEOutroMundo,\ZombieBuddy`. O jogador: assina
o ZombieBuddy (3619862853), copia o `ZombieBuddy.jar` pra pasta do jogo, põe
`-javaagent:ZombieBuddy.jar --` nas opções de inicialização, assina o mod3, ativa, e
aprova o jar na janela do ZB na primeira carga (e a cada versão nova). Assinar o jar
(`.zbs`) evita o aviso de "não assinado".

## 7. Checklist no jogo (Johan)

1. `scripts/build-mod3.sh && scripts/dev-sync.sh`; jogo com `-javaagent:ZombieBuddy.jar -- -debug`;
   ativar `NevoaEOutroMundo_Volumetrica` no save; aprovar o jar.
2. `console.txt`: `[ZB] patching zombie.core.Core.EndFrame`, `[NOM-Render] depth target WxH`,
   `[NOM-Render] pass NOM_VolFog ok`. Nenhum `[NOM-Render] ERRO`.
3. Console Lua: `NOMRender_setParam(1, 1)` (grade). As linhas verdes têm que **grudar nas
   bordas dos tiles** andando, com zoom diferente e subindo escada. Se escorregam: a
   reconstrução está errada (anotar pra onde).
4. `NOMRender_setParam(1, 2)` (profundidade em faixas): faixas em diagonal, contínuas no
   chão e cortando parede/personagem. Tela lisa = a cópia da profundidade não pegou.
5. `NOMRender_setParam(1, 0)` e `NOMRender_setParam(0, 1)` (névoa forçada, sem evento): névoa
   rente ao chão, mais fina em cima de muro e telhado, mexendo devagar, abrindo em volta do
   jogador e dos zumbis perto.
6. `NOMRender_setParam(0, 0)` e forçar um evento de névoa / névoa vermelha (`NOM.help()`):
   segue a intensidade e fica vermelha na vermelha.
7. UI, menus, mapa e o shader do mod2: iguais a antes (estado de GL restaurado).
8. FPS com e sem o mod3 (F3 ou overlay): anotar a diferença a 1080p.
9. Desativar o mod3 (ou abrir sem `-javaagent`): jogo igual ao de antes, sem erro.
