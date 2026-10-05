# Spike — Motor visual: dá pra estender o render do jogo?

| Campo | Valor |
|-------|-------|
| Status | concluída — estática; nenhum probe in-game rodou |
| Branch | `spike/motor-visual` (só doc, nada de código de mod) |
| Relacionados | [spike-shader](../spike-shader/README.md), [pz-api-notes §6 e §15](../../architecture/pz-api-notes.md#15-efeitos-de-tela-sprint-0013), [ADR-004](../../architecture/adr-004-clima-antes-de-shader.md), [ADR-013](../../architecture/adr-013-efeitos-de-tela.md), spike `spike/dissolve` (em paralelo) |

## Pergunta

Dá pra "herdar o `basicEffect`" e construir em cima dele, pra ter fumaça, fogo, luz e sombra
realistas, **bloom** e um efeito de dissolver nos modelos? Existe API pra modificar o jogo?

## Em português claro (pro Johan)

**Sim, existe um jeito, mas não é pelo Lua: é pelo ZombieBuddy, que injeta Java no jogo.** O
Lua do PZ só troca arquivos de shader que já existem; não cria shader novo, não escolhe shader por
personagem e não mexe no pipeline. Com o ZombieBuddy, um `.jar` nosso pode mudar qualquer método
Java do jogo enquanto ele roda. É assim que o ShadowZ faz as sombras dele.

"Herdar o `basicEffect`" não existe do jeito que soa. GLSL não tem herança. Na prática é **copiar a
interface**: escrever um shader novo que recebe as mesmas entradas do `basicEffect` (ossos,
texturas, luzes), acrescentar o que a gente quer e, do lado Java, mandar o jogo usar esse shader
naquele modelo. A parte Java é o que o Lua não consegue fazer.

Por desejo, em resumo:

- **Bloom:** dá. Uma versão barata sai só trocando o `screen.frag` (o mod2 já troca). A versão
  bonita (brilho que "vaza" de verdade em volta das luzes) precisa de Java. **É o melhor primeiro
  alvo.**
- **Dissolver por modelo:** dá com Java. O jogo já tem um "saco de parâmetros" por modelo
  desenhado; falta um shader nosso e um patch que o escolha só pros nossos monstros. A outra spike
  (`spike/dissolve`) vê o caminho sem Java.
- **Fogo e fumaça melhores:** o fogo de hoje é sprite animado (desenho 2D). Dá pra trocar os
  desenhos sem Java. Tem também um sistema de partículas de fogo na GPU, pronto e **desligado**, no
  jogo. Ligar isso é Java e é aposta.
- **Luz melhor:** o cálculo da luz é feito em código nativo (C++), e Java nenhum muda isso. Dá pra
  mudar como a luz *aparece* (cor, brilho, bloom), não por onde ela anda.
- **Sombras melhores:** o jogo não tem sombra de verdade, só uma "mancha" embaixo do personagem. O
  ShadowZ já faz sombra projetada. **Não vale a pena refazer:** quem quiser, usa o ShadowZ.
- **Grão e aberração cromática:** já estão feitos (overlay e mod2). Java não acrescenta nada.

O preço do Java: todo jogador precisa instalar o ZombieBuddy à mão (copiar um `.jar` e pôr uma
opção de inicialização na Steam), aprovar o nosso `.jar` numa janela na primeira vez, e **a cada
patch do jogo o nosso Java pode quebrar**. Por isso ele tem que ser um **terceiro mod, opcional,
só visual, só no cliente**: quem não tem o ZombieBuddy joga normal, só sem o enfeite.

**Recomendação:** sombra e luz ficam com o ShadowZ. Se for pra ter Java nosso, ele faz
**bloom e depois dissolver**, e nada mais. E tem um conflito que já existe: o ShadowZ também
troca o `screen.frag`, igual ao nosso mod2. Hoje os dois não convivem (o mod2 já declara
`incompatible=\ShadowZ`).

## Resultado técnico

Análise estática do B42.21 instalado (`version.txt`: `42.21.0 4a0e9546ec`): bytecode do
`projectzomboid.jar`, `media/shaders` e os logs em `~/.var/app/com.valvesoftware.Steam/Zomboid/`.
Do ZombieBuddy (2.3.2, item 3619862853): o manifesto, os nomes de classes e métodos do `.jar` e os
docs que vêm no item do Workshop (`README.md`, `doc/*.md`, `steam.txt`). Do ShadowZ (item
3800671550): **só** o `mod.info` e os **nomes** dos arquivos da pasta. Nenhuma linha de código ou
shader dele foi aberta, e nada de nenhum mod foi copiado. Legenda igual à do
[pz-api-notes](../../architecture/pz-api-notes.md#como-ler-este-documento): **CONFIRMED**
(visto rodando ou no log), **EXISTS** (está no bytecode, ninguém viu funcionar), **UNKNOWN**
(precisa de teste).

### 1. O que "estender o `basicEffect`" quer dizer

**Dois tipos de "Shader" no Java — EXISTS.**

| Classe | Uso | Herdável em Java? |
|---|---|---|
| `zombie.core.opengl.Shader` | tela, fogo, fumaça, água, poças (`WeatherShader`, `FireShader`, `SmokeShader`, `WaterShader`, `PuddlesShader` herdam dela) | **sim**: não é `final`; ganchos `protected onCompileSuccess(ShaderProgram)`, `startMainThread(TextureDraw, int)`, `startRenderThread(TextureDraw)` |
| `zombie.core.skinnedmodel.shader.Shader` | modelos 3D (personagem, roupa, item, veículo) | **não**: a classe é `final`. Mas não precisa herdar: `new Shader(nome, isStatic, isInstanced)` / `ShaderManager.instance.getOrCreateShader(nome, isStatic, isInstanced)` carrega `media/shaders/<nome>.vert/.frag` |

A "herança" de verdade só existe no Java (`WeatherShader extends opengl.Shader`). No GLSL, o
shader novo tem que **declarar os mesmos nomes** de uniform, atributo e sampler que o Java do
`skinnedmodel.Shader` envia: matriz de ossos (`setMatrixPalette`), luzes (`setLight`,
`setLightInst`), `setAmbient`, `setTint`, `setHueShift`, `setAlpha`, `setTargetDepth`,
`setDepthBias`, sangue e dano (`setMatrixBlood1/2`, `setTextureDamage*`) etc. Em outras palavras: copiar a
"forma" do `basicEffect.vert/.frag` (o arquivo do jogo, que pode ser usado como referência do
contrato) e somar a nossa parte. Variantes que o jogo espera: `basicEffect.vert`,
`basicEffect_static.vert`, `basicEffect_instanced.vert`, `basicEffect_static_instanced.vert`,
`basicEffect.frag`, `basicEffect_instanced.frag` (todas em `media/shaders`). Um shader de
dissolver completo seriam ~4–6 arquivos.

**Onde o shader do modelo é escolhido — EXISTS.**

- O shader mora no **asset** `Model` (`Model.effect`, campo público; `Model` também é `final`). O
  nome vem do script (`ModelScript.shaderName`, `shader = ...` em `media/scripts`; vanilla usa
  `vehicle*`, `animalEffect`, `door`; sem nada, `basicEffect`, string em `ModelManager`) ou da
  roupa (`ClothingItem.shader`, lido por `AnimatedModel`, `ItemModelRenderer`, `PopTemplateManager`).
  `Model.CreateShader(String)` / `EnsureEffect()` montam o `effect`.
- O desenho lê `Model.effect` **na hora**: `Model.DrawChar` (offset 43) → `Model.DrawSolid`
  (1, 15, 41) → instanciado: `RenderList.DrawQueued`; não instanciado: `effect.Start()` →
  `effect.startCharacter(ModelSlotRenderData, ModelInstanceRenderData)` → `ModelMesh.Draw(effect)`
  → `effect.End()`. Também leem `Model.effect`: `RenderList$QueuedModelList`, `AnimatedModel`,
  `ItemModelRenderer`, `IsoObjectModelDrawer`, `WorldItemAtlas$RenderJob`, `UI3DScene`.
- **Por personagem:** o `Model` é compartilhado por todo mundo que usa a mesma malha, então mudar
  `Model.effect` muda o de todos. Mas `ModelSlotRenderData` carrega `character`
  (`IsoGameCharacter`) e `object`, e `ModelInstanceRenderData` tem `properties`
  (`ShaderPropertyBlock`: `SetFloat`, `SetInt`, `SetFloatArray`, `SetMatrix3/4`, `SetVector3`), que é
  um conjunto de uniforms **por instância desenhada**. O caminho Java plausível:
  1. Carregar o nosso shader uma vez com `ShaderManager.getOrCreateShader("nom_dissolve", ...)`.
  2. Patch em `Model.DrawSolid` (ou em `ModelInstanceRenderData.RenderCharacter`): se o
     `slotData.character` é um monstro nosso (ModData), troca `effect` pelo nosso, põe
     `properties.SetFloat("NomDissolve", t)` e devolve o original na saída.
  3. O caminho instanciado (`RenderList.DrawQueued` agrupa por shader) precisa de cuidado próprio,
     ou de forçar o não-instanciado nesses personagens.
  Isso tudo é EXISTS: os métodos estão lá, mas ninguém viu funcionar. O mais frágil é o item 3.
- **Shader novo a partir do Java — EXISTS, com sinal forte.** O carregador lê por
  `ShaderProgram` → `ZomboidFileSystem.getString`, que resolve arquivos de mod (spike-shader). O
  ShadowZ traz arquivos de shader com nomes que o vanilla não tem (`solar_model_shadow.vert`,
  `solar_shadow_union.frag` etc.), então um mod com Java usa shader novo na prática. Pelo Lua,
  continua impossível (spike-shader).
- Per-item sem Java (o `ClothingItem.shader` e afins): **é o assunto da `spike/dissolve`**, não
  repetido aqui.

### 2. ZombieBuddy

**O que é — CONFIRMED.** É um agente Java (`Premain-Class: me.zed_0xff.zombie_buddy.Agent`,
`Can-Retransform-Classes: true`, versão 2.3.2 no manifesto) que roda antes do jogo e carrega
`.jar` de mods. Por dentro usa **ByteBuddy** (`net/bytebuddy/*` no jar) e ClassGraph pra achar os
patches. O console do Johan mostra ele aplicando os próprios patches (`[ZB] patching
zombie.GameWindow.init with 1 advice(s)`, `Transformed: zombie.gameStates.GameLoadingState`) e
`[ZB] Exposing class to Lua: ZombieBuddy`.

**API — EXISTS (classes públicas do jar + `doc/ModdingGuide.md`).**

- **Patch por anotação, estilo Mixin:** `@Patch(className, methodName, warmUp, isAdvice,
  strictMatch, IKnowWhatIAmDoing)` numa classe estática. Dentro: `@Patch.OnEnter(skipOn=true)`
  (devolve `true` e pula o método original), `@Patch.OnExit(onThrowable, suppress)`, e pra ler o
  contexto `@Patch.This`, `@Patch.Argument`, `@Patch.AllArguments`, `@Patch.Return`, `@Patch.Local`,
  `@Patch.Thrown`, `@Patch.SuperCall`, `@Patch.SuperMethod`. É o `Advice` do ByteBuddy por baixo.
  `isAdvice=false` troca o método inteiro (delegação). O log avisa `multiple MethodDelegation
  patches for X - only last one will apply!`. Advices de mods diferentes no mesmo método se
  empilham; delegações brigam.
- **Lua:** `@Exposer.LuaClass` numa classe expõe ela ao Lua; `@LuaMethod(name, global=true)` em
  método estático vira função global; `Exposer.exposeClass(...)` em runtime. Isso é o
  `[ZB] Exposing class to Lua`. Daria pra expor ao nosso Lua, por exemplo, um
  `NomVisual.setDissolve(zombie, t)`.
- **Utilidades:** `Accessor` (reflexão: `tryGet`, `trySet`, `callByName`, `findField`),
  `EventsAPI`, `WatchesAPI`, `Callbacks` (`onDisplayCreate`, `onGameInitComplete`),
  `ZombieBuddy.getVersion()`.
- **Entrada do mod:** classe `Main` no `javaPkgName`, com `main(String[])` opcional. Um mod só
  de patches não precisa dela.

**Como um mod ZombieBuddy é distribuído — EXISTS (docs + `JavaModInfo`).**

- `mod.info`: `require=\ZombieBuddy`, `javaJarFile=media/java/client/X.jar`, `javaPkgName=...`,
  `ZBVersionMin=`/`ZBVersionMax=` opcionais, `javaPreload=` opcional. Um jar por mod.
- Pasta `media/java/client/` = **só cliente** (`Skipping client-only mod` no servidor);
  `media/java/server/` = só servidor; sem `client/` nem `server/` = os dois.
- `.zbs` opcional ao lado do jar: assinatura Ed25519 + SteamID64, chave pública publicada no
  perfil Steam (`JavaModZBS:<hex>`). `allow_unsigned_mods=true` é o padrão.
- **Cada jogador tem que:** assinar o item ZombieBuddy (3619862853), copiar o `ZombieBuddy.jar`
  pra pasta do jogo e pôr `-javaagent:ZombieBuddy.jar --` nas opções de inicialização (no Windows,
  `-agentlib:zbNative --` ou o instalador). Na primeira carga, e a cada `.jar` novo ou mudado, uma
  janela pede aprovação (mostra o SHA-256), com `policy=prompt` por padrão. Sem o agente, o
  `require=\ZombieBuddy` só puxa a parte Lua dele, e o nosso jar não carrega. O mod segue sem o
  efeito, sem erro de jogo (EXISTS; o caminho sem agente não foi testado).

**MP — EXISTS, um sinal CONFIRMED.**

- A página diz "Works on MP? Yes". O agente é por processo Java: cada cliente e o servidor
  carregam os jars que lhes cabem.
- **CONFIRMED no log do Johan:** o `coop-console.txt` (o servidor do coop hospedado) carrega o mod
  `ZombieBuddy` como mod Lua, mas tem **zero** linhas `[ZB]`. O servidor do coop não roda o agente
  (a opção da Steam vale pro processo do cliente). Logo, Java nosso **tem que ser só cliente**.
  Visual é cliente por natureza, então serve.
- O vanilla não confere jar de mod no handshake. Um cliente sem ZombieBuddy entra no servidor e
  só não vê o efeito. UNKNOWN (não testado), mas não há código do jogo que olhe pra jar.

**Fragilidade — EXISTS.**

- O patch acha o alvo por **nome** (`className`/`methodName` em string). Se um patch do jogo
  renomear ou mudar a assinatura, o log diz `Method X not found in Y` e o patch não entra. Se mudar
  o corpo (offsets, campos), o advice pode compilar e fazer besteira. Campos lidos por reflexão
  quebram em silêncio.
- O próprio ZombieBuddy declara suporte "B41, B42.12–B42.21". A cada versão do jogo o jogador
  depende de o autor dele atualizar, e a gente depende disso também.
- Não descobri se o Java de um mod ativado **só no save** carrega na hora: no `console.txt` de
  hoje, o ShadowZ entrou como mod Lua (`mod "ShadowZ" overrides media/shaders/screen.frag`), mas não
  aparece linha `[ZB]` de jar dele. **UNKNOWN**: pode exigir que o mod esteja na lista padrão ou
  que o jogo reinicie.
- Segurança: Java de mod tem acesso total à máquina (aviso do próprio ZB). Isso pesa na
  confiança do jogador e é mais um motivo pra deixar opcional.

### 3. Mapa do pipeline de render (B42.21)

| Etapa | Onde | Java ou nativo | Dá pra mexer? |
|---|---|---|---|
| Mundo → FBO fora da tela | `Core.StartFrame` passa `Core.offscreenBuffer` (`MultiTextureFBO2`) como textura do `SceneShaderStore.weatherShader` | Java | sim |
| Chão e paredes | `FBORenderChunk`/`FBORenderCell`/`FBORenderLevels` desenham os chunks em FBOs próprios (cache; `FBORenderChunk` é um dos 2 únicos que chamam `glGenerateMipmap`); shaders `floorTile`, `wallTile`, `tileWithDepth`, `chunkShader` | Java + GLSL | arquivo (b) e Java (c) |
| **Luz (cálculo)** | `LightingJNI`: **50 métodos `native`** (`DoLightingUpdateNew`, `getVertLight`, `getSquareLighting`, `addLight`, `getDarkMulti`...); o Java só alimenta e lê | **nativo** | **não** (só as entradas: luzes, cores, raios) |
| Luz no modelo | `ModelManager.getSquareLighting(...)` → `Shader.setLight` / `setAmbient` (`EffectLight[]` por slot) | Java | sim (c), shader do modelo (b) |
| Sombras | `FBORenderShadows`: `addShadow(...)` + `media/textures/NewShadow.png`. É a **mancha** sob personagem e veículo, não sombra projetada | Java | sim (c); o ShadowZ faz isso |
| Fogo | `IsoFire`: sprites animados (`AttachAnim`, `attachedAnimSprite`, `IsoSprite.currentAnim`) + `IsoLightSource` | Java + textura | textura (b'), Java (c) |
| Fumaça de incêndio | `IsoFire` com `smoke` / `IsoFireManager.smokeTintMod`, também sprite | Java + textura | textura (b'), Java (c) |
| **Partículas de fogo na GPU** | `ParticlesFire` (+ `fire.frag`, `smoke.frag`, `vape.frag`, `FireFlame.png`, `FireSmokes.png`) → `ModelManager.RenderParticles` → `TextureDraw.drawParticles` ← `SpriteRenderer.drawParticles` ← `Particles` | Java + GLSL | **dormente**: ninguém no jar chama `Particles.render()` nem cria zona (`addZone`). Só `DebugChunkState` usa (`reloadShader`). Ligar é Java (c) e é aposta |
| Clima | `IsoWeatherFX` (`renderFog`, `renderClouds`, `renderPrecipitation`, `renderFogCircle`), chamado por `IsoCell` e `WeatherFxMask`; `fog.frag`, `fogCircle.frag` | Java + GLSL | arquivo (b), Java (c) |
| **Pós-processo** | `Core.RenderOffScreenBuffer` → `MultiTextureFBO2.render()` → `IndieGL.StartShader(weatherShader)` → `SpriteRenderer.renderi(...)` → `screen.frag` | Java + GLSL | arquivo (b) (mod2 já faz), Java (c) |
| UI | `UIManager` depois do mundo (§15) | Java | Lua (a) |

**Bloom — EXISTS (viável).**

- O `screen.frag` vanilla já tem um bloom **desligado**: `mainOriginal()` (comentado) soma
  `texture2D(DIFFUSE, UV, 4.0)` etc. com `BloomVal`, e `bloom = bloom * 0.0`. O `WeatherShader`
  ainda busca `BloomVal` (campo `bloom`). Esse truque depende de mipmap, e o FBO da tela não
  gera mipmap (os únicos `glGenerateMipmap` do jar são `FBORenderChunk` e `TextureCombiner`): o
  bias não faz nada. Por isso morreu.
- **(b) só `screen.frag`:** um bloom de uma passada (filtro de claro + 12–24 amostras em anel) é
  possível no override do mod2. Fica curto (raio pequeno), custa caro em 4K e briga com o
  ShadowZ, que também troca o `screen.frag`. Serve de protótipo.
- **(c) Java:** o jeito certo. Um patch `OnEnter` em `MultiTextureFBO2.render` (ou
  `Core.RenderOffScreenBuffer`) enfileira um `TextureDraw$GenericDrawer` (`SpriteRenderer.drawGeneric`,
  o mesmo mecanismo do `ModelSlotRenderData`) que, já na render thread: filtra o claro da textura
  do `offscreenBuffer` num `TextureFBO` de ½, desce até ¼ e ⅛ e borra (H/V, shaders próprios num
  `opengl.Shader` nosso, que é herdável). Depois, ou compõe por cima, ou passa a textura do bloom
  como sampler extra pro `screen.frag`. Custo: 4–6 FBOs pequenos, ~6 passadas de tela parcial.
  O `TextureFBO` tem `startDrawing`/`endDrawing`/`getTexture`. Tudo isso é Java do jogo, sem nativo.
- Luz mais "realista" vem quase toda daqui: bloom em lâmpada, fogo e farol dá mais impressão de
  luz do que mexer no cálculo (que é nativo).

**O que é nativo e não dá pra patchear do Java — CONFIRMED (flag `ACC_NATIVE`).** A propagação de
luz e visão inteira (`LightingJNI`: 50 `native` contra 26 Java). Física (`pzbullet`) também é
nativa. Fora disso, o render é Java + GLSL.

### 4. Viabilidade por desejo

(a) só Lua · (b) só override de arquivo (shader ou textura) · (c) Java via ZombieBuddy.

| Desejo | (a) Lua | (b) arquivo | (c) Java | Esforço (c) | Risco | ShadowZ |
|---|---|---|---|---|---|---|
| **Bloom** | não | sim, fraco (1 passada no `screen.frag`) | **sim, bom** (FBOs + blur) | ~1 sprint (3–5 dias, mais o setup de build Java) | médio: uma classe-alvo (`MultiTextureFBO2`) | conflita se os dois mexem no `screen.frag`; o bloom por Java compondo por cima pode **coexistir** (UNKNOWN) |
| Fogo melhor | não | talvez: trocar a textura dos sprites de fogo (override de texturepack por mod: UNKNOWN, não verificado) | sim: ligar `ParticlesFire` dormente ou partículas próprias | 1–2 sprints | alto: código morto do vanilla, sem garantia de funcionar | sem conflito conhecido |
| Fumaça melhor | parcial (já temos névoa por clima) | talvez: textura (idem fogo) | sim: idem fogo | 1–2 sprints | alto | sem conflito conhecido |
| Luz melhor | parcial: cor e força da luz global (ADR-008), luzes extras via `IsoLightSource` | sim: curva de cor nos shaders de tile e modelo | só a aparência (bloom, glow); propagação **não** (nativo) | via bloom | médio | ShadowZ faz luz do sol e ambiente: **sobrepõe** |
| Sombras melhores | não | não (é mancha de textura) | sim, mas é refazer o ShadowZ | 2+ sprints | alto | **usar o ShadowZ**, não competir |
| **Dissolver por modelo** | não (spike-shader) | ver `spike/dissolve` (per-item) | **sim**: shader novo + patch em `Model.DrawSolid` + `ShaderPropertyBlock` | ~1 sprint | médio-alto: caminho instanciado (`RenderList`) | provável conflito se o ShadowZ também patcheia o desenho de modelo pra "mesh shadows" (UNKNOWN) |
| Grão / aberração cromática | overlay (sprint 0013) | mod2 (`screen.frag`) | nada a ganhar | — | — | mod2 já é `incompatible=\ShadowZ` |

### 5. Recomendação

1. **Não começar o mod Java agora.** Primeiro, dois probes baratos que decidem se vale:
   - Bloom de uma passada no `screen.frag` do mod2 (b). Se ficar bom o bastante, não precisa de Java
     pra bloom.
   - Resultado da `spike/dissolve`. Se o dissolver sai sem Java (per-item), o Java perde o segundo
     motivo de existir.
2. **Se um dos dois falhar**, abrir um **terceiro mod** `NevoaEOutroMundo_Visual`: opcional, `require=\ZombieBuddy`,
   jar em `media/java/client/` (só cliente, nada de gameplay), item próprio no Workshop. Assim, quem
   não tem ZombieBuddy, ou joga em servidor sem ele, não perde nada.
   - **Sprint 1: bloom por Java** (patch em `MultiTextureFBO2.render` + 3 FBOs + shaders próprios),
     liga/desliga e intensidade nas Opções > Mods, mais forte na névoa.
   - **Sprint 2: dissolver** nos nossos monstros (shader `nom_dissolve*` com a interface do
     `basicEffect` + patch no desenho do modelo + `NomVisual.setDissolve` exposto ao Lua).
   - Fogo e fumaça: só textura (b), se um dia virar prioridade. `ParticlesFire` fica arquivado.
3. **Sombra e luz do sol: ShadowZ.** Usar ele em vez de refazer. Mas o
   conflito do `screen.frag` (mod2 × ShadowZ) continua. Se o bloom for Java e compor **por cima**,
   sem trocar o `screen.frag`, ele pode conviver com o ShadowZ. Isso precisa de teste.

**Custo de manutenção do mod Java:** toolchain nova (JDK 17 + Gradle, nada disso está instalado
aqui; compilar contra `projectzomboid.jar` e `ZombieBuddy.jar` como `compileOnly`, sem empacotar
nenhum dos dois). O `build-workshop.sh` passa a levar um jar. Opcional: assinatura `.zbs`. E a
cada versão do PZ é preciso conferir os alvos dos patches. Conta ~meio dia por patch do jogo se
nada mudou, mais se mudou. Suporte extra: jogador que não instalou o agente vai achar que o mod
"não funciona". A descrição do Workshop tem que deixar isso claro.

## Probes in-game (Johan)

1. **ZombieBuddy carrega jar de mod só do save?** Ativar o ShadowZ só num save, carregar e procurar
   linha `[ZB]` de jar dele no `console.txt` (`java mod list to load:`). Depois, com ele na lista
   padrão. Decide se o mod Java precisa de "reinicie o jogo".
2. **Bloom de uma passada (mod2):** override do `screen.frag` com filtro de claro + anel de amostras,
   à noite perto de poste e fogo. Ver FPS em 1080p e 4K.
3. **Cliente sem agente em servidor com o mod visual:** entra e joga sem erro (esperado).

Nenhum arquivo de probe foi adicionado ao repo.

## Sessões

- 2026-10-05 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — spike estática: ZombieBuddy, pipeline, viabilidade, recomendação
