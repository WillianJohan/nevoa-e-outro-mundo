# Visual das variantes — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cada monstro tem cara própria: Estalador, Corredor, Sem-rosto e Carpideira ganham pele e uma peça no rosto enquanto a névoa dura (e perdem quando ela acaba); o Eco vira cinza e fumaça. Tudo com texturas procedurais originais em modelos vanilla citados por nome.

**Architecture:** A variante continua derivada do `persistentOutfitID` (ADR-006): o outfit **não** muda. Quem renderiza o zumbi (solo: o processo; MP: cada cliente, em toda cópia local, dona ou remota) põe na própria cópia uma pele (`HumanVisual.setSkinTextureName`) e um `ItemVisual` de item do mod na lista `getItemVisuals()`, e chama `resetModelNextFrame()` — o mesmo caminho do tutorial vanilla (`client/Tutorial/Steps.lua:832-838`). O `NOM_NightStats` já calcula a variante de cada zumbi a cada passada; ele passa a chamar um gancho (`NOM_NightStats.look`) instalado pelo novo `client/NOM_VariantLook.lua`, que guarda o que aplicou numa tabela Lua (zero chamada Java quando nada muda), tira no fim da névoa, no reaproveitamento do objeto e na morte (antes do corpo nascer, sem deixar loot nem pele no save). Pele e `ItemVisual` de zumbi não viajam na rede (`ZombiePacket.set` leva só `outfitId` e `skinTextureIndex`) nem vão pro save (zumbi vivo vai pro popman só com o ID). O Eco, que é spawnado com outfit do mod, muda só nos dados: o outfit `NOM_Eco` passa a vestir itens do mod.

**Tech Stack:** Lua 5.1 (Kahlua no jogo, luajit nos testes), Python + Pillow + numpy pras texturas, XML/scripts de item do B42.

**Spec:** brief da sprint 0012 (decisão do Johan de 05/10/2026: visual por textura procedural original em modelo vanilla, sem modelo 3D novo; direção de arte aprovada), [README da sprint](README.md), [art-direction.md](../../gdd/art-direction.md).

## Global Constraints

- Kahlua: sem `//`, `goto`, operador de bit, `next()`; `unpack`, não `table.unpack`; nada de `%d` com float.
- O outfit da variante **não muda** (ADR-006): nada de `dressInNamedOutfit`/`setPersistentOutfitID` nos zumbis da névoa.
- O visual é local de cada máquina que renderiza: nada vai pela rede nem pro save.
- Toda chamada de API com evidência (Lua vanilla arquivo:linha ou bytecode `Classe.metodo` + offset).
- Nada copiado do jogo nem de outro mod: modelos vanilla por nome, texturas geradas por `scripts/gen_textures.py` (Pillow, determinístico) no tamanho da textura vanilla que o modelo usa (só o tamanho é lido). Tudo no `CREDITS.md`.
- Texto que o jogador vê por tradução PT-BR e EN (nomes dos itens em `ItemName.json`).
- Orçamento: zumbi comum não ganha chamada Java nova; custo por passada e por troca na tabela do [architecture/README.md](../../architecture/README.md#orçamento-por-sistema).

## Evidência (bytecode do B42.21 instalado)

- `HumanVisual.getSkinTexture()` 0–11: se `skinTextureName != null`, devolve ele; senão calcula a pele do zumbi. `setSkinTextureName(String)` só grava o campo. Só o `IsoMannequin` chama o setter: zumbi normal tem o campo nulo, então tirar = `setSkinTextureName(nil)`. `ModelInstanceTextureCreator.init` monta `media/textures/Body/<nome>.png`.
- `ItemVisuals` é um `ArrayList<ItemVisual>`; `ItemVisual.<init>()` deixa `textureChoice = -1`, e `getTextureChoice(ClothingItem)` sorteia na hora (14–49). `getClothingItem()` sai do item de script (`getScriptItem` → `ScriptManager.getItem(fullType)`). `ItemVisual` e `ItemVisuals` estão no `LuaManager$Exposer` (EXISTS: `ItemVisual.new()`).
- `ZombiePacket.set(IsoZombie)` grava `outfitId` e `skinTextureIndex` (o índice, não o nome): o visual do mod não viaja.
- `IsoZombie.dressInPersistentOutfitID(I)` limpa `HumanVisual` e `itemVisuals` e veste pelo ID; o `ModelManager.dressInRandomOutfit` chama ele quando `!isPersistentOutfitInit()` (veste tarde, na criação do modelo). `VirtualZombieManager.createZombieOutsideWorld` (reaproveitamento, 177–230): `HumanVisual.clear()` + `setPersistentOutfitID(I)` (init = false).
- `IsoZombie.onKilled` 45–52: `DoZombieInventory()` (itens vestidos e no inventário criados a partir de `itemVisuals`, `WornItems.setFromItemVisuals`) **antes** do `OnZombieDead`; o corpo (`IsoDeadBody.<init>`) copia `HumanVisual`, inventário e `WornItems` depois.
- `IsoZombie.helmetFallFromVisuals` só derruba item com `ChanceToFall > 0`: os itens do mod não declaram (0).
- Mod com `media/fileGuidTable.xml` próprio: `ZomboidFileSystem.loadFileGuidTable` 113–312 junta o de cada mod (`mergeFrom`); `OutfitManager.getClothingItem(guid)` resolve o caminho por ele.

## Review Focus

1. Zumbi que ainda não foi vestido (`isPersistentOutfitInit() == false`, longe da tela) vira variante — o visual não pode sumir quando o jogo veste ele depois.
2. Objeto de zumbi reaproveitado (`resetForReuse` → `OnZombieCreate`) que tinha visual — o zumbi novo nasce sem nada do mod.
3. Variante morta — o corpo não fica com a peça, a pele, nem com o item no inventário (loot e save).
4. Névoa que acaba de dia com um Sem-rosto (que não tem stats: o `NightStats` não o revisita) — o visual sai.
5. Cópia remota no MP e servidor dedicado — o cliente pinta a própria cópia; o servidor nunca pinta.

---

### Task 1: Assets — texturas, itens, clothing XML, GUIDs, nomes

**Files:**
- Create: `scripts/gen_textures.py`, `mod/42/media/textures/Body/NOM_{Estalador,Corredor,Carpideira}.png`, `mod/42/media/textures/NOM/*.png`, `mod/42/media/clothing/clothingItems/NOM_*.xml`, `mod/42/media/fileGuidTable.xml`, `mod/42/media/scripts/NOM_clothing.txt`, `Translate/{EN,PTBR}/ItemName.json`, `tests/test_look_assets.lua`
- Modify: `mod/42/media/clothing/clothing.xml` (outfit `NOM_Eco`), `CREDITS.md`, `tests/run.lua`, `tests/test_credits.lua`

**Interfaces — Produces:** itens `Base.NOM_EstaladorVenda` (óculos de esqui, `base:eyes`), `Base.NOM_CorredorBoca` (máscara cirúrgica, `base:mask`), `Base.NOM_SemRostoEstatica` (balaclava inteira, `base:mask`), `Base.NOM_CarpideiraCabelo` (véu, `base:hat`), `Base.NOM_EcoCinza` (camada sobre o corpo, sem modelo, `base:boilersuit`), `Base.NOM_EcoVeu` (véu, `base:hat`); peles `NOM_Estalador`, `NOM_Corredor`, `NOM_Carpideira`.

- [ ] `tests/test_look_assets.lua` (falha): todo item do `NOM_clothing.txt` tem `ClothingItem` com XML, o XML tem GUID na `fileGuidTable.xml` do mod com o caminho certo, toda textura citada existe com o tamanho da vanilla (PNG lido pelo cabeçalho IHDR), todo item tem nome em EN e PTBR, nenhum item tem `ChanceToFall`, e o outfit `NOM_Eco` só usa GUIDs do mod.
- [ ] `gen_textures.py` (semente fixa, sai igual byte a byte), XML, scripts, GUIDs (uuid4 gerados uma vez), traduções, `CREDITS.md`. Verde.
- [ ] Commit `feat: texturas procedurais e itens de visual das variantes e do Eco`.

### Task 2: `NOM_VariantLook` — pôr, tirar e esquecer o visual

**Files:**
- Create: `mod/42/media/lua/client/NOM_VariantLook.lua`, `tests/test_variant_look.lua`
- Modify: `mod/42/media/lua/shared/NOM_NightStats.lua` (gancho `look` na passada), `tests/run.lua`

**Interfaces:**
- Consumes: `NOM_NightStats` (passada em lotes), `NOM_FogState.onChange`.
- Produces: `NOM_VariantLook.LOOKS[kind] = { skin = nome|nil, item = fullType }`; `NOM_VariantLook.sync(z, kind)` (kind nil = sem visual); `NOM_VariantLook.count()`; `NOM_NightStats.look = NOM_VariantLook.sync` (instalado ao carregar, fora do servidor dedicado).

Código:

```lua
if isServer() then return end
require "NOM_NightStats"
require "NOM_FogState"
NOM_VariantLook = { LOOKS = { ... } }
local worn = {} -- [zumbi] = { kind = , iv = ItemVisual }
local function put(z, kind) -- só com o zumbi já vestido
    if not z:isPersistentOutfitInit() then return end
    local look = NOM_VariantLook.LOOKS[kind]
    if look.skin then z:getHumanVisual():setSkinTextureName(look.skin) end
    local iv = ItemVisual.new(); iv:setItemType(look.item)
    z:getItemVisuals():add(iv); z:resetModelNextFrame()
    worn[z] = { kind = kind, iv = iv }
end
local function strip(z)
    local w = worn[z]; if not w then return end
    worn[z] = nil
    z:getItemVisuals():remove(w.iv)
    if NOM_VariantLook.LOOKS[w.kind].skin then z:getHumanVisual():setSkinTextureName(nil) end
    z:resetModelNextFrame()
end
function NOM_VariantLook.sync(z, kind)
    local w = worn[z]
    if (w and w.kind) == kind then return end
    strip(z)
    if kind and NOM_VariantLook.LOOKS[kind] then put(z, kind) end
end
-- morte: o DoZombieInventory já fez item vestido e no inventário do ItemVisual
local function dead(z) ... strip(z); tira o item do inventário e do WornItems ... end
NOM_NightStats.look = NOM_VariantLook.sync
Events.OnZombieCreate.Add(strip); Events.OnZombieDead.Add(dead)
NOM_FogState.onChange(function(on) if not on then for z in pairs(worn) do strip(z) end end end)
```

`NOM_NightStats.process`: depois de calcular a variante (antes de trocar `semrosto` por nil), `if NOM_NightStats.look then NOM_NightStats.look(z, kind ~= "eco" and kind or nil) end`; no retorno cedo do dia sem névoa, `look(z, nil)`.

- [ ] Testes que falham, no fake que imita o jogo (pele que só o mod troca, lista Java de `ItemVisual`, veste tarde pelo ID, reaproveitamento que limpa a `HumanVisual` e veste de novo, `DoZombieInventory` antes do `OnZombieDead`, corpo que copia pele/itens/inventário): `look_applied_when_variant_starts`, `look_each_kind_distinct`, `look_removed_when_fog_ends` (lista volta igual, pele nil, ID igual), `look_semrosto_removed_at_day`, `look_common_zombie_untouched` (zero chamada de visual), `look_waits_until_dressed`, `look_reused_object_clean`, `look_dead_leaves_no_loot`, `look_remote_copy_gets_it_and_nothing_sent`, `look_not_on_dedicated_server`, `look_red_fog_everyone`, `look_debug_forced_and_undone`, `look_period_change_without_edge`, `look_budget` (aplicar ≤ 8 chamadas, tirar ≤ 5, passada sem troca 0).
- [ ] Implementar; verde (testes antigos do `NightStats` sem o gancho continuam iguais).
- [ ] Commit `feat: visual das variantes na cópia local enquanto a névoa dura`.

### Task 3: Debug conta os visuais

**Files:** `client/NOM_Debug.lua` (status: `visuais=N`), `tests/test_debug.lua`.

- [ ] `debug_status_counts_looks` falha → `visuais = NOM_VariantLook and NOM_VariantLook.count() or 0` → verde → commit `feat: status do debug conta os visuais aplicados`.

### Task 4: Docs

**Files:** `docs/gdd/art-direction.md` (novo), `docs/gdd/monsters.md`, `docs/gdd/Overview.md`, `docs/architecture/adr-012-visual-das-variantes.md` (novo), `docs/architecture/README.md` (índice, estrutura, orçamento), `docs/architecture/pz-api-notes.md` (§14), `docs/sprints/README.md`, `docs/sprints/sprint-0012-visual-variantes/README.md`, `docs/teste-in-game.md`, `README.md`, `CREDITS.md`.

- [ ] Escrever; `./run-tests.sh` verde; commit `docs: sprint 0012 em teste (visual das variantes: arte, ADR-012, pz-api-notes §14, orçamento, roteiro)`.
