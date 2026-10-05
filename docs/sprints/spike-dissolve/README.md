# Spike — Dissolve na morte do Eco e na mutação das variantes

| Campo | Valor |
|-------|-------|
| Status | concluída — estática; probe in-game pendente |
| Branch | `spike/dissolve` (descartável) |
| GDD | [art-direction.md](../../gdd/art-direction.md), [monsters.md](../../gdd/monsters.md) |
| ADR | [ADR-012](../../architecture/adr-012-visual-das-variantes.md) (visual das variantes), [ADR-004](../../architecture/adr-004-clima-antes-de-shader.md) (shader como último recurso) |
| Base | [spike-shader](../spike-shader/README.md), [pz-api-notes §14–§15](../../architecture/pz-api-notes.md#14-visual-das-variantes-sprint-0012) |

## Pergunta

Dá pra fazer um *dissolve* (limiar sobre ruído, com borda brilhando, o do tutorial clássico
de Unity) em dois momentos?

1. Quando um Eco morre. Hoje o corpo some na hora (`server/NOM_Eco.lua`, `removeEcoCorpses`).
2. Quando um zumbi vira variante e quando volta. Hoje `client/NOM_VariantLook.lua` troca a
   pele e a peça de uma vez (ADR-012, sprints 0012/0014/0016).

Análise estática do B42.21 (o instalado): bytecode do `projectzomboid.jar`, `media/shaders` e
`media/lua`. O jogo não rodou. A legenda é a de
[pz-api-notes.md](../../architecture/pz-api-notes.md#como-ler-este-documento): CONFIRMED (uso
vanilla), EXISTS (bytecode, sem uso vanilla) e UNKNOWN (precisa de teste).

## Resultado

**Resposta curta:** dá, e sem sobrescrever nada do vanilla. O `clothingItem` aceita
`<m_Shader>`, e o jogo cria o shader pelo nome, lendo `media/shaders/<nome>.vert|.frag`
pelo sistema de arquivos dos mods. Então um shader **novo** do mod pode ser aplicado a uma peça.
Não existe uniform de tempo nem um float por peça que o Lua consiga mexer a cada quadro.
O único canal Lua → shader por quadro é o **`Alpha` do personagem**
(`setAlpha(pn, a)` no `OnTick`), e o shader do mod pode lê-lo como limiar do dissolve.
O corpo usa sempre o `basicEffect` e não muda de shader. Para dissolver o corpo inteiro, o
Eco precisa de uma "casca": uma peça de corpo inteiro com o shader do mod.

### A. Shader por peça ou por modelo — EXISTS (cadeia inteira no bytecode)

| Fato | Status | Evidência |
|---|---|---|
| Model script `model { shader = X }` grava `shaderName` | CONFIRMED | `ModelScript.Load` 171–184; uso vanilla: `shader = vehicle_multiuv` (77×), `animalEffect` (73×), `door` (44×), `vehicle` (38×) em `media/scripts` |
| O model script não serve pro corpo nem pras roupas | CONFIRMED | o corpo é `loadModel("skinned/malebody", null, mesh)`, que fixa `basicEffect` (`ModelManager.create` 151–164, `ModelManager.loadModel(3 args)` 3). Roupa não passa por `ModelScript` |
| **`clothingItem` XML aceita `<m_Shader>`** | EXISTS | `ClothingItemXML` (`@XmlElement` `m_Shader` → campo `shader`); `ClothingItemAssetManager.onFileTaskFinished` 170–173 copia para `ClothingItem.shader`. Nenhum XML vanilla usa |
| A peça com `m_Shader` monta o modelo com esse shader | EXISTS | `PopTemplateManager.addClothingItem` 100–157: lê `ClothingItem.shader` e passa para `newStaticInstance(slot, malha, tex, osso, shader)` (peça presa a osso, `m_AttachBone`) ou `newAdditionalModelInstance(..., shader)` (peça com esqueleto) |
| A chave do modelo inclui o shader | EXISTS | `ModelManager.tryGetLoadedModel(String,String,Z,String,Z)` 0–6 → `createModelKey(malha, tex, static, shader)`. A mesma malha vanilla com outro shader vira outro `Model`, e as peças vanilla não são afetadas |
| `Model` com `shaderName` cria o shader; sem ele, `basicEffect` | EXISTS | `Model.<init>` 187–202 → `CreateShader(nome)` → `ShaderManager.getOrCreateShader(nome, isStatic, false)`. `Model.DrawChar` 42–53: sem efeito, usa `basicEffect` |
| **Shader novo por nome** | EXISTS | `ShaderManager.getOrCreateShader` 0–110: procura na lista e, se não acha, faz `new Shader(nome, static, instanced)`. Nome em caixa diferente de um existente lança `IllegalArgumentException("shader filenames are case-sensitive")` (52–79) |
| Arquivos lidos: `media/shaders/<nome>[_static][_instanced].vert` e `<nome>[_instanced].frag` | EXISTS | `ShaderProgram.getRootVertFileName` 0–43, `getRootFragFileName` 0–23 e strings `media/shaders/`, `.vert`, `.frag`. Peça `m_Static=true` usa `<nome>_static.vert`; o `.frag` é o mesmo |
| Arquivo de mod que **não** existe no vanilla é achado | EXISTS | `ShaderUnit.preProcessShaderFile` 8–10 → `IndieFileLoader.getStreamReader` 30 → `ZomboidFileSystem.getString`, que consulta o `activeFileMap` (76). `ZomboidFileSystem.loadMod` 140–216 põe **todo** arquivo do mod no mapa, não só os que substituem. O spike de shader dizia "shader novo não dá" porque o Lua não cria `ShaderProgram`, mas o jogo cria a pedido do XML |
| `_instanced` não é necessário | EXISTS | `Model.SwapInstancedBasic` 35–48: só troca pro instanciado se o nome é `basicEffect` e a textura não tem alfa |

**Uniforms que a peça recebe** (`Shader.onProgramCompiled`, por nome, e o shader do mod
declara só os que usa): `Texture` (único sampler ligado, `Shader.startCharacter` 192–196),
`Alpha`, `TintColour`, `HueChange`, `LightingAmount`, `AmbientColour`, `Light0..4Colour/Direction`,
`MatrixPalette`, `transform`, `UVScale`, `FinalScale`, `targetDepth`, `DepthBias` e os de
veículo.

- **Não existe uniform de tempo**: nenhum `timer`/`time` na lista, nem em
  `ModelSlotRenderData.UpdateCharacter`/`ModelInstanceRenderData.UpdateCharacter` (strings).
- **`Alpha` é por personagem e por jogador, a cada quadro**: `ModelSlotRenderData.init` 623–626
  (`IsoGameCharacter.getAlpha(pn)`) → `UpdateCharacter` 49–53 (`"Alpha"`) e
  `Shader.startCharacter` 319–322. EXISTS. É o canal.
- `TintColour`/`HueChange` são por peça, mas só mudam com o modelo refeito.
  `PopTemplateManager.postProcessNewItemInstance` 15–34 copia a tinta para o `ModelInstance`
  na criação, e `ModelInstanceRenderData.RenderCharacter` 5–8 a relê a cada quadro.
  `ModelInstance` não está no `LuaManager$Exposer`. Quando a peça ganha textura composta
  (sangue, buraco, máscara), a tinta é queimada na textura e volta a 1
  (`ModelInstanceTextureCreator.createFullItemTexture` 21–42). Não serve de canal por quadro.
- `Model.DrawChar` 22–33: com `alpha < 0.01`, o personagem inteiro não desenha. O fim do
  dissolve é invisível de qualquer jeito.

### B. Alfa nas texturas de pele e roupa — CONFIRMED (shader) / EXISTS (composição)

| Fato | Status | Evidência |
|---|---|---|
| `basicEffect` descarta texel com alfa < 0.01 | CONFIRMED | `media/shaders/basicEffect.frag:33-38` (`discard`); saída `vec4(Alpha*col, Alpha*texSample.w)` (`:79`) |
| O jogo já usa alfa para buracos na roupa | CONFIRMED | `media/shaders/addHole.frag:20-24` (máscara corta o alfa da peça); `SmartTexture.addHole` 65–70 |
| Pele + roupa só de textura + sangue + sujeira viram **uma** textura do corpo | EXISTS | `ModelInstanceTextureCreator.createFullCharacterTexture` 11–109: `addTexture(baseTexture)` (a pele), `addDirt`, `addBlood`, `calculate()` |
| A camada base guarda o alfa da pele | EXISTS | `TextureCombinerCommand.init(Texture,SmartShader)` 15–37: cor `SRC_ALPHA, ONE_MINUS_SRC_ALPHA`; alfa `ONE, ONE_MINUS_SRC_ALPHA` → alfa final = alfa da pele |
| Sangue e sujeira **preservam** o alfa de baixo | EXISTS | `SmartTexture.addOverlay`/`addDirtOverlay`: alfa `DST_ALPHA, ONE_MINUS_SRC_ALPHA` (772/771) → alfa final = alfa de destino |
| Peça só de textura **tapa** os buracos | EXISTS | `addMaskedTexture` usa o mesmo blend da base (alfa `ONE, …`): onde a peça é opaca, o alfa volta a 1. O `NOM_EcoCinza` (`m_BaseTextures`, corpo todo) taparia tudo |
| As peles do mod são RGB, sem alfa | CONFIRMED | §14.3 do pz-api-notes. Para ter buraco, `gen_textures.py` precisa gerar RGBA |

Uma pele com buracos transparentes dissolve de verdade: o `discard` abre o corpo, e a face de
trás é cortada pelo culling. Duas ressalvas: as roupas com modelo (a maioria das vanilla) são
malhas separadas e não ganham buraco, e uma peça só de textura opaca tapa o buraco.

### C. Custo de trocar textura por quadro e alfa por personagem

| Fato | Status | Evidência |
|---|---|---|
| `resetModelNextFrame` = `ModelManager.ResetNextFrame` (fila do próximo quadro) | EXISTS | `IsoGameCharacter.resetModelNextFrame` 0–4; `ModelManager.ResetNextFrame` 12–24 |
| O reset refaz o slot inteiro | EXISTS | `ModelManager.Reset(IsoGameCharacter)` 32–178: tira os `ModelInstance` (`resetModelInstanceRecurse`), `derefModelInstances`, recria o corpo (`getBodyModel`, `newInstance`) e chama `DoCharacterModelParts` (todas as peças de novo, com nova composição de textura no render thread) |
| Alfa por personagem e por jogador já existe e é usado pelo vanilla | EXISTS | `IsoObject.setAlpha(IF)`, `setTargetAlpha(IF)`, `setAlphaAndTarget(IF)`, `getAlpha(I)` (métodos públicos; `IsoZombie` no Exposer). Sem uso no Lua vanilla |
| O vanilla reescreve o alvo a cada passada de visão | EXISTS | `IsoPlayer.updateLOS` 1097–1110: `setTargetAlpha(pn, vê ? 1 : 0)`; `IsoGameCharacter.updateSeenVisibility` 49–52 (não visto → 0) |
| E aproxima o alfa do alvo a cada update | EXISTS | `IsoObject.updateAlpha(IFF)` 79–181: passo `0.28 × multiplicador × taxa` (míope ÷2, olho de águia ×1.5, `IsoGameCharacter.getAlphaUpdateRateMul`); nunca no servidor (`updateAlpha(I)` 0–6) |
| **`OnTick` roda depois do mundo e antes do render** | EXISTS | `IngameState.updateInternal`: `IsoWorld.update` em 1067, `onTick` (`"OnTick"`) em 1331. Um `setAlpha(pn, a)` feito no `OnTick` vale para o quadro desenhado em seguida |

Custo de trocar a pele em quadros (abordagem 2): cada passo é um reset completo do slot, com
nova composição da textura do corpo. Para um Eco ou poucos zumbis, ~8 passos em 1 s não
devem pesar. O problema é a névoa vermelha, onde todo zumbi vira variante de uma vez
(sprint 0010): 8× mais resets no pico, sobre o lote do `NOM_NightStats`. **UNKNOWN:** se
entre o reset e a composição existe um quadro sem textura (piscada).

Já existe alfa por personagem, então o fade-out sempre funciona. Ele custa um `setAlpha`
por jogador por quadro e não refaz nada.

### D. Morte do Eco

| Fato | Status | Evidência |
|---|---|---|
| O corpo pode ficar ~2 s: hoje o servidor tira assim que acha (`sweepAround` a cada tick) | CONFIRMED (mod) | `server/NOM_Eco.lua` `onTick`/`dying`; basta remover N ticks depois de achar |
| Esconder o corpo localmente | EXISTS | `IsoDeadBody.setDoRender(Z)` 0–15 (chama `setInvalidateNextRender(true)`, que tira o corpo da textura de chunk); usado pelo Java (`IsoGameCharacter`, `IsoGridSquare`) |
| Trocar a pele do corpo | EXISTS | `IsoDeadBody.getHumanVisual()` + `setSkinTextureName`; `IsoDeadBody.invalidateCorpse` 0–33 (zera `atlasTex` ou invalida o chunk); a chave do atlas inclui a pele (`DeadBodyAtlas.getBodyKey` 657 `getSkinTexture`) → nova entrada a cada passo |
| O corpo é um sprite de atlas, não um modelo animado | EXISTS | `IsoDeadBody.render` 78–106 (`DeadBodyAtlas.getBodyTexture`) e 481–523 (`BodyTexture.render` com a cor/alfa recebidos). O shader de peça **não** roda no corpo depois de pronto |
| O atlas corta texel transparente | CONFIRMED | `media/shaders/DeadBodyAtlas.frag:14-23` (`discard` se `texel.a * d == 0`). Uma pele com buraco vira um corpo com buraco |
| Fade do corpo por alfa | UNKNOWN | `IsoDeadBody.render` usa o alfa do `ColorInfo` recebido (357–360, 520), mas no B42 o corpo pode estar desenhado na textura do chunk (`FBORenderDebugOptions.corpsesInChunkTexture`). Mudar o alfa a cada quadro talvez exija invalidar o chunk toda vez |
| No solo e no servidor há uma janela entre `OnZombieDead` e o corpo (a animação de morte) | CONFIRMED (mod) | comentário e `CORPSE_TICKS` de `server/NOM_Eco.lua`; `IsoZombie.onKilled` → `OnZombieDead`, corpo no fim da animação |
| **No cliente de MP talvez não haja janela** | UNKNOWN | `IsoGameCharacter.dieNetwork` 6–10: `Kill` (`OnZombieDead`) e logo `becomeCorpse` (`new IsoDeadBody`, 8–16). Não sei se o servidor manda o pacote no golpe ou no fim da animação |

**Partículas locais (cinza/brasa):**

| Caminho | Status | Serve? |
|---|---|---|
| Overlay de UI em espaço de tela (o da sprint 0013) + `isoToScreenX/Y(pn, x, y, z)` | CONFIRMED | `client/ISUI/ISButtonPrompt.lua:176`; desenho com cor/alfa `ISUIElement.lua:1032-1041`. Posição em float, quantas partículas quiser, só local. Sem profundidade: passa por cima de parede |
| `getIsoMarkers():addIsoMarker(tabela, sq, r,g,b,a)` | CONFIRMED | `client/Foraging/ISBaseIcon.lua:577-579`. Com profundidade, mas `IsoMarker.setPos(III)` só aceita tile inteiro: serve pra uma mancha/queimado no chão ou um sprite animado por troca de textura, não pra brasa voando |
| `getCell():addLamppost(x,y,z,r,g,b,raio)` / `removeLamppost` | EXISTS | `IsoCell.addLamppost(IIIFFFI)`, `IsoLightSource` no Exposer; sem uso no Lua vanilla. Um clarão laranja de 0,5 s. **UNKNOWN:** se no MP fica só local |
| `WorldFlares.launchFlare` | EXISTS | luz ambiente de área grande (`applyFlaresForPlayer`), só no painel de debug. Grande demais |
| `IsoFireManager` / fogo de verdade | — | é gameplay (queima, espalha), não efeito. Fora |
| `IsoPuddles` | — | poça global de chuva. Fora |

## Recomendação

Ordem por resultado visual e custo. Todas são locais no cliente: nada vai pela rede nem pro
save, igual à ADR-012. O servidor dedicado nunca desenha (`IsoObject.updateAlpha(I)` sai no
servidor).

### 1. Shader de dissolve numa peça, com o `Alpha` como limiar — **recomendada**

**Como.** Três arquivos novos no mod, sem sobrescrever o vanilla:
`media/shaders/NOM_Dissolve.vert` (cópia do `basicEffect.vert`), `NOM_Dissolve_static.vert`
(cópia do `basicEffect_static.vert`, para as peças presas a osso) e `NOM_Dissolve.frag`
(o `basicEffect.frag` com o limiar). As peças do mod ganham `<m_Shader>NOM_Dissolve</m_Shader>`.
O ruído é procedural, calculado do `texCoords`, porque só o sampler `Texture` vem ligado. A
borda é cor emissiva somada depois da luz, e o `Alpha` deixa de multiplicar a cor e vira o
limiar. Um `NOM_Dissolve.lua` no cliente faz `setAlpha(pn, a)` para cada jogador local no
`OnTick` enquanto o efeito dura, e depois solta (o vanilla volta a mandar).

- **Mutação/volta:** a peça da variante (venda, boca, estática, cabelo) dissolve para
  dentro e para fora. Como o `Alpha` também deixa o corpo translúcido no `basicEffect`, o
  shader mapeia só uma faixa estreita: `limiar = (Alpha − 0,85) / 0,15`. O corpo fica a no
  mínimo 85% de opacidade por ~1 s. A pele continua trocando de uma vez, no meio do efeito.
  Limite honesto: o corpo do zumbi não dissolve, porque ele é `basicEffect` fixo.
- **Morte do Eco:** o outfit `NOM_Eco` ganha uma **casca**, uma peça de corpo inteiro com
  esqueleto (malhas vanilla `Bob_Hazmat.X`/`Kate_Hazmat.X`), textura de cinza do mod e
  `m_Shader`. O `HazmatSuit.xml` vanilla esconde as partes do corpo por baixo com `m_Masks`
  (0, 3–15). Com as mesmas máscaras, o buraco da casca mostra o fundo, e não a pele: é um
  dissolve inteiro. **UNKNOWN:** se a cabeça fica coberta. No `OnZombieDead` do cliente, o
  alfa vai de 1 a 0 em ~1,5 s durante a animação de morte, e o que sobra do corpo some em fade.
  Quando o corpo aparece, o cliente faz `setDoRender(false)` nele e o servidor tira como hoje.
- **Efeito colateral:** com o shader, a peça também "dissolve" quando o zumbi sai da visão
  (o fade vanilla). É bonito e combina com a névoa. Fica registrado como comportamento.

**Custo.** Um programa de shader compilado uma vez, mais uma malha por Eco (a casca). As
peças com shader próprio não entram no instanciado, o que não importa para poucas peças.
Por quadro, um `setAlpha` por jogador por zumbi em efeito. Sem reset de modelo.

**Riscos.** O `m_Shader` não tem uso vanilla (EXISTS). O shader pode falhar no driver: o
`ShaderUnit.processShaderSyntax` troca a versão para GL 2.1, e é preciso conferir no
`glslangValidator` em 330 e em 120, como na 0013. O corpo translúcido na faixa de 0,85 pode
mostrar sobreposição de malhas. Se a janela de morte não existir no cliente de MP, o Eco
morto ali só ganha as brasas (abordagem 3). A casca `Bob_Hazmat` muda a silhueta do Eco: é
uma decisão de arte do Johan. Um nome em caixa diferente de shader existente derruba o
carregamento (por isso o prefixo `NOM_`).

**MP.** Tudo local. Cada cliente roda o próprio efeito no seu zumbi (dono ou remoto), igual ao
`NOM_VariantLook`. Os `.vert/.frag` vão no mod, que todo cliente já tem.

### 2. Pele com buracos trocada em quadros — **fallback do corpo do Eco**

**Como.** `gen_textures.py` gera N quadros RGBA de uma pele (cinza do Eco), com alfa 0 onde
`ruído > t` e uma faixa laranja na borda. Para animar, troca `setSkinTextureName` a cada passo:
no zumbi, com `resetModelNextFrame`; no corpo, com `invalidateCorpse` (a chave nova do atlas
re-renderiza e o `DeadBodyAtlas.frag` corta os buracos). O `NOM_EcoCinza` (peça só de
textura) tem de sair antes, senão tapa os buracos.

- **Serve para o corpo parado do Eco**, inclusive no cliente de MP sem janela de animação:
  o corpo fica ~2 s (o servidor atrasa o `removeCorpse`) e dissolve no chão.
- **Não serve para a mutação:** a pele "de antes" é uma das muitas vanilla, então não dá pra
  pré-gerar a transição de cada par. E as roupas com modelo não ganham buraco.

**Custo.** Um reset completo do slot (zumbi) ou uma nova entrada no atlas (corpo) por passo,
mais N texturas 256×256 RGBA por pele (8 quadros ≈ 2 MB). Ok para um Eco por vez; não
escala para a névoa vermelha.

**Riscos.** Um quadro sem textura entre os resets (UNKNOWN). Entradas de atlas acumulando por
corpo. O corpo do servidor continua vanilla. É só visual local, mas um jogador que olha o
corpo no meio do efeito o vê sem buraco se o cliente dele não rodar o efeito.

**MP.** Local. No corpo, o efeito começa quando o cliente vê o corpo nascer.

### 3. Fade por alfa + burst de brasa — **piso garantido**

**Como.** O mesmo `setAlpha(pn, a)` no `OnTick`, de 1 a 0 em ~1 s, sem shader. Para o burst,
o overlay de tela da 0013 desenha ~20 partículas de brasa/cinza (textura do mod) a partir
de `isoToScreenX/Y` do zumbi, com velocidade, gravidade negativa e alfa caindo. Um
`IsoMarker` de queimado no chão por alguns segundos e, se o probe passar, um `addLamppost`
laranja de 0,5 s.

**Custo.** Quase nada. Nenhum modelo refeito. As partículas vivem numa tabela Lua com teto.

**Riscos.** O fade puro não é dissolve: lê como "sumiu". As partículas passam por cima de
parede (sem profundidade). A luz pode não ser local no MP (UNKNOWN).

**MP.** Local, igual ao overlay da 0013.

### Probes in-game (Johan)

Num mod de teste descartável, fora do repo, como no spike de shader: uma cópia do mod com
os arquivos abaixo. Jogo com `-debug`, console Lua.

**Probe 1: o shader do mod carrega numa peça (decide a abordagem 1).**

1. `media/shaders/NOM_Dissolve.vert` = cópia do `basicEffect.vert`;
   `NOM_Dissolve_static.vert` = cópia do `basicEffect_static.vert`;
   `NOM_Dissolve.frag` = cópia do `basicEffect.frag` com `gl_FragColor = vec4(1.0, 0.0, 1.0, 1.0);`
   na última linha.
2. Em `clothing/clothingItems/NOM_EstaladorVenda.xml` (peça presa a osso) e
   `NOM_EcoVeu.xml` (peça com esqueleto), acrescentar `<m_Shader>NOM_Dissolve</m_Shader>`.
3. `NOM_Debug.fog(true, true)`, `NOM_Debug.variant("estalador")` num zumbi perto; à noite,
   `NOM_Debug.spawnEco()`.
4. Esperado: a venda e o véu **magenta**, o resto vanilla. Se ficarem normais ou sumirem, ver
   no `console.txt` erro de `Shader`/`NOM_Dissolve`. Se só a venda falhar, o problema é o
   `_static.vert`.

**Probe 2: o `Alpha` dirige o limiar.** O `.frag` vira o dissolve:

```glsl
// no lugar do discard e da saída do basicEffect.frag
float n = fract(sin(dot(floor(texCoords * 64.0), vec2(12.9898, 78.233))) * 43758.5453);
float t = Alpha;                       // 1 = inteiro, 0 = sumiu
if (texSample.w < 0.01 || n > t) discard;
float edge = 1.0 - smoothstep(0.0, 0.08, t - n);
// ...luz como no vanilla...
col = mix(col, vec3(1.0, 0.45, 0.1), edge);
gl_FragColor = vec4(col * vertColour, texSample.w);
```

No console, com o Estalador perto:

```lua
local p, best, bd = getPlayer(), nil, 1e9
local l = getCell():getZombieList()
for i = 0, l:size() - 1 do
  local z = l:get(i); local d = z:DistTo(p)
  if d < bd then best, bd = z, d end
end
local t0 = getTimestampMs()
local function tick()
  local k = math.min(1, (getTimestampMs() - t0) / 2000)
  for pn = 0, getNumActivePlayers() - 1 do best:setAlpha(pn, 1 - k) end
  if k >= 1 then Events.OnTick.Remove(tick) end
end
Events.OnTick.Add(tick)
```

Conferir:

1. A venda some em manchas com borda laranja em ~2 s, e o corpo some em fade junto.
2. Sem piscar de volta pra 1 no meio: confirma que o `OnTick` vem depois do `updateLOS`.
3. Ao terminar, o zumbi volta sozinho com o fade vanilla.
4. Repetir com `0.85 + 0.15 * (1 - k)` e o shader com `t = clamp((Alpha - 0.85) / 0.15, 0.0, 1.0)`.
   A venda dissolve inteira e o corpo quase não muda. **Decide se a faixa é aceitável na mutação.**

**Probe 3: a janela de morte.** Com o shader do probe 2 no véu do Eco:

```lua
local function dead(z)
  if z:getOutfitName() ~= "NOM_Eco" then return end
  local t0 = getTimestampMs()
  local function tick()
    local k = math.min(1, (getTimestampMs() - t0) / 1500)
    for pn = 0, getNumActivePlayers() - 1 do z:setAlpha(pn, 1 - k) end
    if k >= 1 or not z:getCurrentSquare() then
      print("[NOM] janela ms=" .. (getTimestampMs() - t0)); Events.OnTick.Remove(tick)
    end
  end
  Events.OnTick.Add(tick)
end
Events.OnZombieDead.Add(dead)
```

Matar um Eco. Anotar a janela no `console.txt` e se o véu dissolve **antes** de o corpo
aparecer. Repetir num servidor dedicado local, como cliente: se a janela for ~0, o MP usa a
abordagem 2 ou 3 no Eco.

**Probe 4: o corpo (decide a abordagem 2 e o fallback do MP).** Com um corpo qualquer perto,
`local b = getPlayer():getCurrentSquare():getDeadBodys():get(0)` (ou o corpo do square ao
lado):

1. `b:setDoRender(false)`: some? `b:setDoRender(true)`: volta?
2. `b:setAlpha(0, 0.3)` num `OnTick` por 2 s: fica translúcido? Se não, o corpo está na
   textura do chunk e o fade do corpo sai da lista.
3. `b:getHumanVisual():setSkinTextureName("NOM_Estalador"); b:invalidateCorpse()`: a pele do
   corpo troca? Com uma pele RGBA com buracos (gerar uma à mão), o corpo fica furado?

**Probe 5 (opcional): luz local.** `local L = getCell():addLamppost(x, y, z, 1, 0.5, 0.1, 4)`
e `getCell():removeLamppost(L)` 0,5 s depois. Aparece? No MP, o outro jogador vê?

## Escopo recomendado da sprint

**Sprint "Dissolve" (depois dos probes 1–3).** Objetivo jogável: o Eco queima e some com
borda de brasa ao morrer, e a peça da variante se forma e se desfaz com o mesmo efeito.

- Shader `NOM_Dissolve` (`.vert`, `_static.vert`, `.frag`) com ruído procedural, borda emissiva
  e faixa de limiar por constante. Validado no `glslangValidator` em 330 e 120.
- `<m_Shader>` nas 4 peças de variante e no véu do Eco. Casca de corpo inteiro no outfit
  `NOM_Eco`, se o Johan aprovar a silhueta (decisão de arte).
- `client/NOM_Dissolve.lua`: `run(z, de, para, ms, fim)` com `setAlpha` por jogador no
  `OnTick`, uma tabela de efeitos ativos, teto de efeitos simultâneos (névoa vermelha) e
  cancelamento quando o zumbi sai do mundo.
- `NOM_VariantLook`: o `put` dissolve para dentro e o `strip` dissolve para fora (a peça só sai
  da lista no fim). A pele troca no meio. A morte (`dead`) continua instantânea, porque o
  inventário já foi feito.
- Eco: dissolve no `OnZombieDead` do cliente, `setDoRender(false)` no corpo que nascer e
  brasas pelo overlay da 0013 (abordagem 3) em todo caso, inclusive no MP sem janela.
- Opção de cliente (ModOptions, como a 0013) para desligar o efeito: volta ao instantâneo.

**Fora da sprint:** dissolver o corpo do zumbi na mutação (o `basicEffect` é fixo) e a
abordagem 2 no corpo, que só entra se o probe 3 mostrar que o MP não tem janela **e** as
brasas sozinhas ficarem fracas. Override do `basicEffect`: arquivado (ADR-004), porque
mudaria todo personagem do jogo.

Nenhum arquivo de mod foi adicionado ao repo neste spike.

## Sessões

- 2026-10-05 — abd764e2-7a9a-416b-b9b3-1630ab9e761f — spike estático (bytecode B42.21, shaders e Lua vanilla) e recomendação
