# Spike — Shader próprio na névoa

| Campo | Valor |
|-------|-------|
| Status | concluída — estática; probe in-game pendente |
| Branch | `spike/shader` (descartável) |
| GDD | [atmosphere.md#shader-spike](../../gdd/atmosphere.md#shader-spike), [ADR-004](../../architecture/adr-004-clima-antes-de-shader.md) |

## Pergunta

O Project Zomboid B42 carrega um shader GLSL vindo da pasta de um mod?

## Probe

1. Achar os shaders do jogo (`media/shaders/`) e como são carregados (log, decompilação para leitura).
2. Colocar um shader de vinheta + grão no mod, com mesmo nome/caminho, e ver se substitui.
3. Se substituir: ativar só na névoa.

Orçamento: ~2h. Passou disso sem resposta, a resposta é "não".

## Resultado

**Resposta curta:** o B42 carrega GLSL da pasta do mod **só como substituição** de um
shader que já existe, e só na primeira carga de mundo da sessão. Shader novo, não. Para
a vinheta na névoa, o caminho é o `SearchMode` via Lua, sem shader. O grão de filme só
sai com override do `screen.frag`, que fica como último recurso.

Análise estática do B42.20 (bytecode do `projectzomboid.jar` + `media/shaders` +
`media/lua`). O jogo não rodou. Legenda igual à de
[pz-api-notes.md](../../architecture/pz-api-notes.md#como-ler-este-documento).

### (a) Quando os shaders compilam — CONFIRMED (estático); override EXISTS

- O pós-processo de tela é o programa `screen` (`WeatherShader`), guardado em
  `SceneShaderStore.weatherShader`. Ele nasce em `SceneShaderStore.initShaders()`
  (lambda `initShaders$4` → `new WeatherShader("screen")`), **só se o campo for null**.
- `initShaders()` só tem dois chamadores: `Core.initShaders()` ←
  `GameLoadingState.enter()` (offset 146) e `ServerGUI.init()`. **Não compila no
  boot.** O outro caminho (`SceneShaderStore.shaderOptionsChanged`, via lambda de
  `Core.shadersOptionChanged`) não tem chamador nem em Java nem em Lua.
- Em `GameLoadingState.enter()` a ordem é `LuaManager.LoadDirBase("server")` →
  `ScriptManager.LoadedAfterLua()` → `Core.initFBOs()` → **`Core.initShaders()`**. Os mods
  do save já estão ativos nesse momento: se a lista do save é diferente,
  `MainScreen.lua:1233-1237` chama `getCore():ResetLua("currentGame", ...)` antes, e
  `Core.ResetLua` faz `ZomboidFileSystem.Reset()` → `init()` → `loadMods(...)` (refaz o
  `activeFileMap`). **Um mod só do save consegue sobrescrever `screen.frag`.**
- Limitação: nada recompila depois. `ResetLua` não toca nos shaders, e
  `weatherShader` só volta a null em `IngameState.enter()` quando
  `Core.getUseShaders()` é false. Então **vale o primeiro mundo carregado na sessão**:
  voltar ao menu e abrir outro save mantém o shader anterior (com ou sem o mod). O
  `DebugFileWatcher` recarrega por mudança de arquivo, mas só no modo debug.
- O caminho de leitura (`ShaderUnit` → `ZomboidFileSystem.getString` →
  `activeFileMap`) já estava levantado na §6 do pz-api-notes. Por isso o override fica
  como EXISTS: a ordem está provada, mas ninguém viu acontecer no jogo.
- Shader **novo**: continua impossível. Ninguém cria `ShaderProgram` a partir de Lua.

### (b) Qual shader de tela cheia roda todo quadro — CONFIRMED; gatilho de névoa EXISTS (indireto)

- **`screen.frag`/`screen.vert`** é o candidato. `Core.StartFrame` usa
  `SceneShaderStore.weatherShader` em todo quadro com shaders ligados (opção padrão).
  `blur` é usado para outras coisas, e `fog.frag` (`FogShader`) desenha faixas de névoa
  no mundo, não a tela inteira. Uma vinheta ali sairia por faixa, então não serve.
- O `screen.frag` vanilla **já tem grão** (`pnoise3D` + `timer`, `grainamount = 0.0003`,
  praticamente invisível) e já escurece/desfoca fora de um círculo no ramo do SearchMode.
  O override seria pequeno: aumentar o grão e somar uma vinheta.
- Uniforms que o `WeatherShader.startRenderThread` envia: `timer`, `timerWrap`,
  `TextureSize`, `Zoom`, `Light`, `LightIntensity`, `NightValue`, `Exterior`,
  `NightVisionGoggles`, **`DesaturationVal`**, `SearchMode`, `ScreenInfo`, `ParamInfo`,
  `VarInfo`, `DrunkFactor`, `BlurFactor`.
- **Não existe uniform de névoa.** O `WeatherShader` busca a posição de `FogMod`, mas
  não envia valor. O `screen.frag` só cita `FogMod` dentro de comentário.
  `PlayerRenderSettings` calcula `fogMod = 1 - fog*0.5`, mas ele não chega ao shader.
- Como saber dentro do shader que é névoa:
  1. **`DesaturationVal`** = `ClimateManager.getDesaturation()` × (1 − darkness)
     (`PlayerRenderSettings.updateRenderSettings`, offsets 110-113 e 594-606; ×0.25 em
     interior). A nossa camada de clima já sobe a dessaturação na névoa. Funciona, mas é
     um sinal ambíguo: o vanilla também dessatura em outros climas.
  2. **Canais do SearchMode como parâmetro vindo do Lua.** Com
     `getSearchMode():setOverride(pn, true)`, o `PlayerSearchMode.update()` sai logo na
     primeira linha e não zera mais os valores. Com `enabled` = false, `VarInfo.x` = 0, e
     o ramo vanilla ignora `SearchMode.xy`/`ParamInfo.w`/`VarInfo.y`. Esses floats
     continuam sendo enviados todo quadro, e um `screen.frag` modificado pode lê-los.
     É um canal Lua → shader por jogador. EXISTS, sem uso vanilla.

### (c) SearchMode sem o forrageamento — EXISTS, com uma ressalva

- Visual e gameplay são coisas separadas. O shader só olha
  `PlayerSearchMode.isShaderEnabled()` = `enabled || doFadeIn || doFadeOut` (campo Java).
  O forrageamento de verdade (ícones, busca) é o `ISSearchManager.isSearchMode` (campo
  Lua). `getSearchMode():setEnabled(pn, true)` liga a vinheta **sem** ligar a busca.
- Valores: `getSearchModeForPlayer(pn):getRadius()/getBlur()/getDesat()/getDarkness()/getGradientWidth()`
  devolvem `SearchModeFloat` (`set`, `setTargets`, `setExterior`, `setInterior`). Com
  `enabled`, o `update()` aproxima os valores dos alvos (`equalise`, lerp de 0.01 por
  quadro), então a entrada já sai suave. Sem `enabled` e sem fade, ele zera tudo (`reset`).
  `SearchMode.update()` roda todo quadro em `IngameState.UpdateStuff`.
- O que o shader faz com isso (`screenWorld`, ramo `VarInfo.x != 0`): blur fora do
  raio, dessaturação `max(DesaturationVal, círculo*desat)` e escurecimento
  `1 - darkness*círculo`. É vinheta + escurecimento + desfoque. **Grão não**: a linha
  de grão ligada ao círculo está comentada no `screen.frag`.
- **Ressalva:** `ISSearchManager:updateOverlay()` (`ISSearchManager.lua:1055-1090`) chama
  `setEnabled(player, isSearchMode or isEffectOverlay)` e reescreve os alvos, a menos que
  `self.isOverride` seja true (linha 1056). Os dois são false por padrão, então ele
  **desligaria a nossa vinheta** sempre que rodar. Não confirmei se ele roda com o
  painel invisível (UNKNOWN). A saída é ligar `ISSearchManager.getManager(player).isOverride = true`
  enquanto durar a névoa. **Não** usar `setOverrideSearchManager`: ele bloqueia o
  forrageamento (`checkShouldDisable`, linha 1102). Se o jogador forragear na névoa, a
  vinheta dele fica com os nossos valores, e isso é aceitável.

### Recomendação

**Promover para sprint:** "Vinheta da névoa via SearchMode", só Lua, no cliente, por
jogador. Liga quando o estado de névoa do mod está ativo e desliga quando ele cai, com
`isOverride` do `ISSearchManager` ligado durante a névoa e intensidade no sandbox. Encaixa
na sprint 0005 (overlays de névoa) ou em uma sprint pequena logo depois dela.

**Override de `screen.frag` (grão): arquivado** como último recurso, conforme a
ADR-004. Funciona em tese, mas vale só para o primeiro mundo da sessão, troca o shader
de todo mundo, quebra a cada patch e briga com outros mods. Só reabrir se o probe 2
abaixo passar **e** a vinheta sem grão ficar fraca demais.

### Probe in-game (Johan)

**Probe 1: vinheta via SearchMode (decide a sprint).** Jogo com `-debug`, save
qualquer, de dia e ao ar livre. No console Lua do modo debug:

```lua
local pn = 0
local sm = getSearchMode()
local p = sm:getSearchModeForPlayer(pn)
ISSearchManager.getManager(getPlayer()).isOverride = true
p:getBlur():setTargets(0.2, 0.2)
p:getDesat():setTargets(0.3, 0.3)
p:getRadius():setTargets(6, 6)
p:getDarkness():setTargets(0.7, 0.7)
p:getGradientWidth():setTargets(3, 3)
sm:setEnabled(pn, true)
```

Conferir:

1. A vinheta aparece com fade, sem ícones nem UI de forrageamento.
2. Ela continua lá depois de 1-2 min de jogo, andando e entrando em casa (o valor de
   interior pode ser diferente).
3. A tecla de forragear ainda funciona.
4. `sm:setEnabled(pn, false)` + `ISSearchManager.getManager(getPlayer()).isOverride = false`
   desliga com fade.
5. Repetir sem a linha do `isOverride`. Se a vinheta sumir sozinha, a ressalva de (c) é
   real.

O painel debug General → Search Mode (`DebugUIs/DebugMenu/General/ISSearchMode.lua`) faz
o mesmo sem console.

**Probe 2: override de shader (só se o grão for necessário).** Um mod de teste
descartável, fora do repo, com `42/mod.info` e `42/media/shaders/screen.frag` = cópia do
vanilla com a linha `col.r = 1.0;` antes do `gl_FragColor`. Fazer **assim**:

1. Abrir o jogo do zero, ativar o mod **só no save** e carregar: a tela tem que ficar
   avermelhada. Se não ficar, o override não pega e fica arquivado de vez.
2. Voltar ao menu e carregar outro save sem o mod: se continuar vermelha, está
   confirmado que o shader fica preso ao primeiro mundo da sessão.
3. Ver `console.txt` atrás de erro de compilação do `screen`.

Nenhum arquivo de probe foi adicionado ao repo.

## Sessões
