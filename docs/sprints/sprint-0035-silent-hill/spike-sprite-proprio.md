# Spike: sprite próprio anexado na erosão (sprint 0035, Tarefa 0)

Pergunta: dá pra anexar (`obj:addAttachedAnimSpriteByName(nome)`) uma textura **nossa**, gerada
por script, no piso e nas paredes N/W, como hoje o mod anexa sprites vanilla? Bytecode do B42.21
instalado (`projectzomboid.jar`, `javap -c -p`), Lua e arquivos de `media/` do jogo, só leitura.
Mods instalados consultados **só** no `mod.info`, pra ver como declaram.

## Resumo

**Recomendação: sprite em runtime (caminho 1b).** O PNG de 128×256 que o `gen_textures.py` gera
em `media/textures/NOM/OutroMundo/` vira sprite com `getSprite(caminho)` + `setName(caminho)` +
flags (`FloorOverlay`; `WallOverlay` + `attachedW`/`attachedN`), e o anexo continua igual ao de hoje.

- **Save:** o sprite de runtime tem ID 20000000, que nunca está no `intMap`. Um anexo nosso que
  vaze pro save é **descartado no load**, com o mod ou sem ele. É mais seguro que o vanilla de hoje
  (sujeira e rachadura vazadas ficam pra sempre).
- **Profundidade:** sai das flags, sem PNG de depth: chão pelo `setupFloorDepth`, parede pela
  profundidade da parede pai. As mesmas flags decidem o lado no recorte da parede de canto.
- **MP:** nada no servidor; o checksum só cobre Lua, scripts e animação.
- **Tile pack (1a)** também funciona (formato lido e gerável em Python), mas o anexo vazado volta
  do save enquanto o mod estiver instalado, e o número do tiledef pode colidir com outro mod.
- **Plano B (tinta por instância) não existe pelo Lua:** `IsoSpriteInstance` não tem setter de
  tinta e o Kahlua não escreve campo Java.

Confiança: a API e o comportamento de save, MP e profundidade são **CONFIRMED** no bytecode. O
resultado visual no jogo (depth e recorte certos, nitidez da textura, carga assíncrona) é
**UNKNOWN** e vai pro roteiro do Johan.

## 1. Como um mod registra sprite próprio

### 1a. Tile pack do mod (`pack=` + `tiledef=` no `mod.info`)

| Fato | Status | Evidência |
|---|---|---|
| `mod.info` aceita `pack=<nome>` (vários) e `tiledef=<nome> <número>` | CONFIRMED | `ChooseGameInfo.readModInfoAux` 764–1008 (`pack=`, `addPack`), 1016–1226 (`tiledef=`, `addTileDef`) |
| Número do `tiledef`: **100 a 8189**; fora disso o mod.info é recusado (`tiledef=%s %d file number must be from %d to %d`) | CONFIRMED | `ChooseGameInfo` 1133–1220 |
| Pack procurado em `media/texturepacks/<nome>.pack` do mod; carregado com `GameWindow.LoadTexturePack(nome, flags, modId)`; ausente → aviso e segue | CONFIRMED | `ZomboidFileSystem.loadModPackFiles` 0–207; bootstrap #21 `media/texturepacks/\u0001.pack` |
| Tiledef procurado em `media/<nome>.tiles` do mod e lido por `IsoWorld.LoadTileDefinitions(manager, caminho, fileNumber)`; ausente → erro e segue | CONFIRMED | `ZomboidFileSystem.loadModTileDefs` 0–252; bootstrap #24 `media/\u0001.tiles` |
| Dois mods com o mesmo número: o segundo é **pulado** (`tiledef fileNumber %d used by more than one mod`) | CONFIRMED | `loadModTileDefs` 83–116 |
| Ordem: tiledefs vanilla → `loadModTileDefs` → `missing-tile.png` → `ScriptManager.PostTileDefinitions` → evento Lua **`OnLoadedTileDefinitions(IsoSpriteManager)`** | CONFIRMED | `IsoWorld.init` 2517–2665 |

**Formato do `.tiles` (binário, B42)** — `IsoWorld.LoadTileDefinitions` 0–3761, `readInt(InputStream)`,
`readString(InputStream, StringBuilder)`; conferido em `media/tiledefinitions_erosion.tiles`:

```
"tdef"                        4 bytes (TDEF_FILE_MAGIC)
int32 LE  versão = 1          (só aceita 1)
int32 LE  nº de tilesets      (0..512 pra fileNumber ≠ 1)
por tileset:
  string  nome                (ex.: "d_floorleaves_1")   — bytes até '\n'; '\r' lança exceção
  string  imagem              (ex.: "d_floorleaves_1.png")
  int32   colunas (w), int32 linhas (h)
  int32   número do tileset   (1..512)
  int32   nº de tiles         (0..512)
  por tile (nome do sprite = nome + "_" + índice):
    int32 nº de propriedades
    por propriedade: string chave, string valor
```

ID do sprite (o que vai pro save): `getSpriteID(file, tileset, tile)` =
`1048576 + (file − 2)·262144 + (tileset − 1)·512 + tile` (file ≠ 1). `IsoWorld.getSpriteID` 0–36.

**Formato do `.pack` (binário, B42, versão 1)** — `TexturePackDevice.initMetaData` 0–262,
`readPage` 0–193, `TexturePackPage.ReadString` 0–43, `TexturePackPage$SubTextureInfo.<init>`;
o leitor do repo (`scripts/audit_floor_sprites.py:34-72`) lê os packs vanilla com o mesmo formato:

```
"PZPK"                        4 bytes (sem a assinatura: formato 0, PNG terminado em 0xDEADBEEF)
int32 LE  versão = 1          (só aceita 1)
int32 LE  nº de páginas
por página:
  string  nome da página      (int32 tamanho + bytes)
  int32   nº de sub-texturas
  int32   tem alfa (≠ 0)
  por sub-textura:
    string nome do sprite     (ex.: "floors_burnt_01_0")
    int32 x, y, w, h          (recorte na página)
    int32 ox, oy              (deslocamento dentro do quadro)
    int32 fx, fy              (quadro inteiro: 128, 256 no Tiles2x)
  int32   tamanho do PNG, depois os bytes do PNG da página
```

**Dá pra gerar do zero em Python:** sim, os dois são triviais (struct + PIL). A faixa livre de
número não existe oficialmente: é qualquer um de 100 a 8189 que nenhum outro mod ativo use (vistos
nos `mod.info` instalados: 830, 1013, 1632, 4048, 4827, 4848, 4864, 5484, 6985, 7001, 7280). O jogo
não reserva nada; a colisão só aparece no log (`used by more than one mod`).

Mods instalados que usam o mecanismo (só o `mod.info`, pra ver a sintaxe):
`MoreDamagedObjects/42.20/mod.info` (`tiledef=ct_more_damaged_objects_def 4864`),
`Project Seasons/42/mod.info` (`pack=Seasons`).

### 1b. Sprite em runtime, de um PNG em `media/textures` (sem tile pack)

| Fato | Status | Evidência |
|---|---|---|
| `IsoSprite`, `IsoSpriteInstance`, `IsoSpriteManager` e `PropertyContainer` são expostos ao Lua (métodos públicos chamáveis) | CONFIRMED | `LuaManager$Exposer.exposeAll` 989, 3012–3033; uso vanilla: `IsoSpriteManager.instance:getSprite(nome)` em `shared/Util/CustomTileProps.lua:320` |
| `getSprite(nome)` (global do Lua) = `IsoSpriteManager.instance.getSprite(nome)`: se o nome está no `namedMap`, devolve; senão **`AddSprite(nome)`** | CONFIRMED | `LuaManager$GlobalObject.getSprite(String)` 0–7; `IsoSpriteManager.getSprite(String)` 0–28 |
| `AddSprite(String)`: `new IsoSprite`, `LoadSingleTexture(nome)` e `namedMap.put(nome, sprite)`. **Não** põe no `intMap` e **não** chama `setName` | CONFIRMED | `IsoSpriteManager.AddSprite(String)` 0–26 |
| `LoadSingleTexture(nome)` = `texture = Texture.getSharedTexture(nome)` — a mesma função do `getTexture(caminho)` do Lua, que o mod já usa com `media/textures/NOM/...` (`NOM_Embers.lua:17`, `NOM_Flakes.lua:77`) | CONFIRMED | `IsoSprite.LoadSingleTexture` 0–16; `LuaManager$GlobalObject.getTexture(String)` 1 |
| Sem animação, o desenho usa o campo `texture` | CONFIRMED | `IsoSprite.getTextureForFrame(I,IsoDirections,Z)` 22–46 |
| ID do sprite novo: **20000000** (valor do construtor, igual pra todo sprite criado assim) | CONFIRMED | `IsoSprite.<init>(IsoSpriteManager)` 50–53 |
| `addAttachedAnimSpriteByName(nome)` lê o `namedMap` (`IsoSprite.getSprite(manager, nome, 0)`): **acha o sprite de runtime** | CONFIRMED | `IsoSprite.getSprite(IsoSpriteManager,String,I)` 0–23; `IsoObject.addAttachedAnimSpriteByName` (pz-api-notes §16.6) |
| `setName(String)` é público e só grava o campo `name` (o que `getParentSprite():getName()` lê) | CONFIRMED | `IsoSprite.setName` 0–5 |
| Flags no sprite pelo Lua: `sprite:getProperties():set(IsoFlagType.X)` | CONFIRMED | `shared/Util/CustomTileProps.lua:333-338`; `PropertyContainer.set(IsoFlagType)` público |
| O `namedMap` é esvaziado a cada carga de mundo (`IsoSpriteManager.Dispose` antes dos tiledefs): o sprite de runtime tem de ser recriado por jogo | CONFIRMED | `IsoWorld.init` 2182–2185 |

Ou seja: `local s = getSprite(caminho); s:setName(caminho); s:getProperties():set(IsoFlagType.FloorOverlay)`
e depois `obj:addAttachedAnimSpriteByName(caminho)` como hoje. Nada de arquivo binário novo.

### 1c. Outros caminhos

- `IsoSprite.new()` + `LoadSingleTexture` (o fantasma de construção vanilla: `ISEmptyGraves.lua:86-87`,
  `ISBuildAction.lua:139-140`) cria sprite **fora** do `namedMap`; só serve pro
  `addAttachedAnimSprite(IsoSprite)` direto. Não ganha nada sobre 1b e perde a busca por nome
  que o registro do mod já usa.
- `IsoSpriteManager.AddSprite(nome, id)` dá um ID no `intMap` (o anexo voltaria do save). É o
  contrário do que queremos (ver §5).

## 2. Profundidade

O anexo é desenhado com a profundidade **do sprite anexado**, não do objeto:
`IsoObject.renderAttachedSprites` 438 → `IsoSprite.render(inst, obj, …)` → `renderCurrentAnim` 96 →
`renderCurrentAnim_FBORender` 375 → **`IsoSprite.setupTileDepth(obj, …)`** com `this` = sprite anexado.

`setupTileDepth` (`IsoSprite` 0–781), na ordem, pra objeto comum (não árvore, fogo, personagem…):

1. `depthTexture` próprio, não vazio → usa (190–326).
2. Senão, se tem `solidfloor`, **`FloorOverlay`** ou `renderLayer == 1` → `TileDepthModifier.setupFloorDepth` (chão chato) (327–401).
3. Senão, `getParentSpriteDepthTextureToUse(obj)`: o `depthTexture` do **sprite do objeto pai**
   (a parede), mas **só** se o anexo tem `depthFlags & 1` ou `WallOverlay` + `attachedN`/`attachedW`
   (`getParentSpriteDepthTextureToUse` 0–124) (402–437).
4. Senão: janela N/W → `setupWallDepth`; **`WallOverlay` + `attachedW`** → `setupWallDepth(W)`;
   **`WallOverlay` + `attachedN`** → `setupWallDepth(N)` (438–661).
5. Senão: `getDefaultDepthTexture()` (737–781) — profundidade genérica, errada pra decalque.

| Pergunta | Resposta | Status |
|---|---|---|
| Anexo sem depth e sem flag renderiza certo? | **Não**: cai no passo 5 (genérico). | CONFIRMED (bytecode); efeito visual UNKNOWN |
| Chão: como ter depth certo? | Flag `FloorOverlay` no sprite → passo 2. É o que os decalques vanilla de chão têm (`d_streetcracks_1_*`: `FloorOverlay`, pz-api-notes §16.5) | CONFIRMED |
| Parede: como ter depth certo? | Flags `WallOverlay` + `attachedW` (ou `attachedN`) → passo 3 (depth da parede pai) ou 4 (`setupWallDepth`). É o que pichação vanilla tem (`newtiledefinitions.tiles.txt:162363`) | CONFIRMED |
| Precisa de PNG de depth nosso? | Não. Reaproveita a do pai ou a do `setupWallDepth`/`setupFloorDepth`. | CONFIRMED |
| Tile pack (1a) | As mesmas flags vão no `.tiles`. Opcional: `media/tileDepthTextureAssignments.txt` do mod (`TileDepthTextureAssignmentManager.initModData`; formato do vanilla: `nome = preset_depthmaps_01_4`) — **só** vale pra sprite com `tilesetName` (`initSprites` 45–48), ou seja, de tiledef | CONFIRMED |
| Runtime (1b) | `sprite:getProperties():set(IsoFlagType.FloorOverlay)` ou `set(IsoFlagType.WallOverlay)` + `set(IsoFlagType.attachedW/N)` | CONFIRMED (API); UNKNOWN (visual no jogo) |

O mod hoje já se apoia nisso sem saber: os sprites vanilla que ele anexa têm essas flags no tiledef.

## 3. Dimensões, formato e offset

| Fato | Status | Evidência |
|---|---|---|
| `Core.tileScale` = 2 fixo no B42 | CONFIRMED | `Core.<clinit>` 27–28 |
| Com `tileScale` 2: textura de quadro 64×128 é desenhada em escala 2; **128×256 em escala 1** | CONFIRMED | `IsoSprite.performRenderFrame` 31–115 (`getWidthOrig`/`getHeightOrig`) |
| Desenho = `XToScreen/YToScreen` do objeto + `offX/offY` da instância + `Texture.getOffsetX/Y` | CONFIRMED | `IsoSprite.prepareToRenderSprite` 221–283; `performRenderFrame` 184, 213 |
| Quadro vanilla: 128×256. Piso: losango em y 192..256, x 0..128 (vértices (64,192), (128,224), (64,256), (0,224)); `floors_burnt_01_0` = recorte 126×64 em (0,192) | CONFIRMED (medido) | `Tiles2x.floor.pack`; pz-api-notes §16.5 |
| Parede W: metade esquerda, face de x 0 a 64, topo ≈ `32 − x/2`, base ≈ `226 − x/2`. Parede N: metade direita, x 64 a 128, topo ≈ `(x − 64)/2`, base ≈ `196 + (x − 64)/2` | CONFIRMED (medido) | `walls_exterior_house_01_0/1` no `Tiles2x.pack` (`/tmp/spike_wall.py`, só leitura) |
| Sujeira de parede vanilla (referência de tamanho): recorte 64×183 em (2,43) | CONFIRMED (medido) | `overlay_grime_wall_01_0` no `Tiles2x.pack` |

**Pro PNG de runtime:** RGBA **128×256**, quadro inteiro, transparente fora do desenho (sem
recorte: a textura de arquivo não tem `ox/oy`). Potência de 2 nas duas dimensões, então nada de
folga de textura. Chão dentro do losango; parede W só na metade esquerda e N só na direita, dentro
das faces acima (o `gen_*.py` monta a máscara pela geometria, não copiando a parede vanilla).

## 4. MP

| Fato | Status | Evidência |
|---|---|---|
| O checksum do MP só junta arquivos de `LuaManager`, `ScriptManager` e `AdvancedAnimator`; `ZomboidFileSystem` e `IsoWorld` (pack e tiledef) **não** referenciam `NetChecksum$Checksummer` | CONFIRMED | referências a `NetChecksum$Checksummer` no jar |
| Pack só é montado no cliente (`loadModPackFiles` chamado de `GameWindow`, `IngameState`, `Core`); tiledef é lido no `IsoWorld.init` também no servidor | CONFIRMED | referências a `loadModPackFiles`; `IsoWorld.init` 2617–2620 |
| Anexo do mod é só do cliente (nenhum `transmit*`, ADR-017); com 1b, se uma ação vanilla mandar a lista de anexos (`transmitUpdatedSpriteToServer`), o ID 20000000 não existe no servidor | CONFIRMED (ID); UNKNOWN (o handler do servidor não foi lido; a ação em curso já segura o square limpo, ADR-017 item 6) | `IsoSprite.getSprite(IsoSpriteManager,I)` 57–81 |

- **1b:** nada muda pro servidor. Os arquivos novos são PNG e Lua; o Lua já entra no checksum
  como sempre (cliente e servidor com a mesma versão do mod).
- **1a:** o servidor precisa do `.tiles` (mesmo mod instalado, o normal); falta de pack ou tiledef
  dá erro no log e segue (`loadModPackFiles` 112–129, `loadModTileDefs` 163–180), sem kick.

## 5. Save: o que acontece com o nome que vaza

`IsoObject.save` grava, por anexo, o **ID** do sprite (`IsoSpriteInstance.getID`), um byte de flags,
`offX/offY/offZ`, `tintr/g/b` e às vezes o alfa (`IsoObject.save(ByteBuffer,Z)` 168–400: `getID` 184, tinta 229–249). Não grava o nome.

No load (`IsoObject.load(ByteBuffer,I,Z)` 184–601), por anexo:

- lê o ID e chama `IsoSprite.getSprite(manager, id)`: só o `intMap` (com conversão de tileset do
  `WorldConverter`), **`null` se o ID não está lá** (`IsoSprite.getSprite(IsoSpriteManager,I)` 0–81);
- com `null`: em debug, `"discarding attached sprite because it has no tile properties"`; **consome os
  bytes do registro** (flags, floats) e **não** adiciona nada (221–251, 508–510). O chunk carrega normal.

| Caminho | Vazou e carregou **com** o mod | Vazou e carregou **sem** o mod |
|---|---|---|
| 1a (tile pack, ID 1048576+…) | O anexo **volta** (ID no `intMap`): precisa da limpeza por prefixo no `LoadGridsquare`, como `floors_burnt_01_*` hoje | Descartado no load. Mas se **outro** mod usar o mesmo número de tiledef, o ID vira o sprite dele |
| 1b (runtime, ID 20000000) | **Descartado no load** (20000000 nunca entra no `intMap`): o vazamento se limpa sozinho | Descartado no load |

CONFIRMED (bytecode). O "sem o mod" foi lido no código, não testado no jogo.

## 6. Plano B: sprite vanilla tingido por instância

| Fato | Status | Evidência |
|---|---|---|
| `IsoSpriteInstance` tem `tintr/tintg/tintb` (campos públicos), gravados no save por anexo | CONFIRMED | `IsoObject.save` 229–249; `IsoObject.load` 382–426 |
| Pelo Lua: só `getTintR/G/B`, `SetAlpha`, `SetTargetAlpha`, `setScale`. **Não há setter de tinta** | CONFIRMED | `javap -p IsoSpriteInstance` |
| O Kahlua não escreve campo Java: o exposer só **lê** campo estático anotado (`Field.get` em `LuaJavaClassExposer.exposeStatics` 143–222); `getClassFieldVal` é só leitura. Nenhum Lua vanilla escreve `tintr` | CONFIRMED | `se.krka.kahlua.integration.expose.LuaJavaClassExposer`; `rg tintr media/lua` vazio |
| `IsoSprite.setTintMod(ColorInfo)` existe, mas é do **sprite** (compartilhado): tingiria toda instância daquele sprite no mapa | CONFIRMED | `IsoSprite.setTintMod`; proibido pela ADR-017 (mesma razão do `AttachExistingAnim`) |

Conclusão: **tinta por instância não está disponível**. O plano B real seria só "sprites vanilla
como hoje + lascas" (sem visual novo de ferrugem/grade). Não é preciso: 1b cobre.

## 7. Riscos do caminho recomendado (1b)

| Risco | Peso | Mitigação |
|---|---|---|
| Profundidade ou recorte errado no jogo (decalque passando por cima de personagem, parede de canto no lado errado) | médio | flags iguais às dos decalques vanilla; roteiro do Johan com parede W, N e canto, com e sem recorte |
| `getSprite` com caminho que não existe cria sprite vazio (anexo invisível, sem erro) | baixo | `getTexture(caminho)` antes, como a pz-api-notes §16.2 já pede; teste de lista de arquivos (o PNG citado existe) |
| `setName` esquecido: `getParentSprite():getName()` volta nil e o `find` do registro nunca acha a instância (o mod não tira o que pôs) | alto se esquecer | registrar num lugar só (`NOM_OwnSprites.ensure`), fake de teste com `AddSprite` fiel (sem nome) |
| `namedMap` zerado a cada mundo: sprite registrado no menu some | baixo | registrar no `OnGameStart` e de novo, preguiçoso, antes do primeiro anexo da sessão |
| Textura carregada assíncrona: no primeiro quadro pode sair vazia | baixo | registrar no `OnGameStart` (bem antes da névoa); UNKNOWN visual |
| Nitidez/mipmap da textura de arquivo diferente da do pack no zoom longe | baixo | UNKNOWN visual; se ficar ruim, cai pro 1a (mesmo PNG vira página de pack) |
| Coleta (`forageSystem.getAffinitySpriteNames`) lê nomes anexados | nenhum | nomes `media/textures/NOM/...` não batem com afinidade nenhuma |
| Vazamento entre hot save e crash | nenhum | o anexo de ID 20000000 é descartado no load (§5) |

## Recomendação

**Caminho 1b: sprite em runtime a partir de PNG nosso em `media/textures/NOM/OutroMundo/`.**

- Sem formato binário novo, sem mexer no `mod.info`, sem número de tiledef pra colidir.
- O vazamento pro save se desfaz sozinho no próximo load (ID 20000000 fora do `intMap`), com ou
  sem o mod: mais seguro que os sprites vanilla de hoje.
- Profundidade e recorte vêm das flags, como nos decalques vanilla; nenhum PNG de depth.
- O mecanismo de anexo, registro, `OnSave`, corte e verificação da ADR-017 não muda.

**Se o teste no jogo mostrar textura ruim** (nitidez, carga), o plano é o 1a com os **mesmos PNG**:
o `gen_*.py` empacota num `.pack` + `.tiles` (formatos acima), `mod.info` ganha `pack=` e
`tiledef=`, e o `LoadGridsquare` passa a limpar o prefixo próprio (o anexo vazado voltaria do save).

## Pronto pro plano

- **Arquivos gerados** (por `scripts/gen_textures.py` ou um `gen_tiles.py` novo, commitados como os
  outros PNG):
  - `mod/42/media/textures/NOM/OutroMundo/NOM_OM_<tipo>_<lado>_<nn>.png`, RGBA **128×256**, quadro
    inteiro, sem recorte;
  - `<lado>`: `F` (chão, dentro do losango (64,192)–(128,224)–(64,256)–(0,224)), `W` (metade
    esquerda, face topo `32 − x/2`, base `226 − x/2`), `N` (metade direita, topo `(x − 64)/2`, base
    `196 + (x − 64)/2`);
  - `<tipo>`: `Ferrugem`, `Tinta` (descascando), `Grade` (só chão), por exemplo
    `NOM_OM_Grade_F_01.png`, `NOM_OM_Tinta_W_03.png`.
- **Nome do sprite** = o caminho do arquivo, igual ao que o `getTexture` usa:
  `media/textures/NOM/OutroMundo/NOM_OM_Tinta_W_03.png`.
- **Onde declarar:** módulo novo `client/NOM_OwnSprites.lua` (só cliente, `if isServer() then return end`)
  com a lista de nomes e o lado de cada um, e `ensure()`:
  ```lua
  local s = getSprite(nome)           -- AddSprite se não existe (namedMap, ID 20000000)
  s:setName(nome)                     -- sem isso getParentSprite():getName() é nil
  local p = s:getProperties()
  if lado == "F" then p:set(IsoFlagType.FloorOverlay)
  else p:set(IsoFlagType.WallOverlay); p:set(lado == "W" and IsoFlagType.attachedW or IsoFlagType.attachedN) end
  ```
  Chamado no `OnGameStart` e antes do primeiro anexo de cada sessão; confere `getTexture(nome)`.
  A lista e o lado vão em `shared/` (puro, testável), como `tests/floor_sprites.lua`.
- **Regra:** `NOM_DressingRules` ganha os sets novos (`D.name` devolve o caminho); o sorteio da
  branca favorece Silent Hill; a vermelha mantém o sangue de parede e ganha ferrugem; chão sem
  sangue.
- **Prefixo de limpeza:** `media/textures/NOM/OutroMundo/` entra no `D.own` (junto de
  `floors_burnt_01_`). Pelo §5 o `LoadGridsquare` nunca deve achar um, mas a limpeza custa nada e
  cobre um eventual ID reaproveitado.
- **Fake de teste:** o `getSprite` falso tem de modelar o jogo: nome novo cria sprite **sem nome**
  e sem flags; `addAttachedAnimSpriteByName` só acha o que está no `namedMap`; o load do save
  descarta ID 20000000.
- **Roteiro do Johan (UNKNOWN):** grade e ferrugem no chão embaixo do jogador e de zumbi; tinta na
  parede W, N e de canto, com o recorte ligado (passar atrás da casa); zoom 0,5 a 2,5 (nitidez);
  primeira névoa logo depois de carregar (textura vazia?); sair e voltar ao save com névoa (nada
  vazado).
- **Evidências pra `pz-api-notes`:** copiar as tabelas das §1b, §2, §5 e §6 deste spike numa §26
  quando a Tarefa 4 for feita.
