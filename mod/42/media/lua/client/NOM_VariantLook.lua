-- Visual das variantes da névoa (sprint 0012, ADR-012): pele e uma peça por cima
-- enquanto a névoa dura, em toda cópia local do zumbi (solo: o processo; MP: cada
-- cliente, dona ou remota). Nada vai pela rede nem pro save, e o outfit não muda
-- (a variante sai do persistentOutfitID, ADR-006).
--
-- Como (bytecode, pz-api-notes §14):
-- * pele: HumanVisual.setSkinTextureName(nome) → media/textures/Body/<nome>.png
--   (getSkinTexture devolve o nome quando há; zumbi normal tem nil, então tirar é nil);
-- * peça: ItemVisual.new() + setItemType na lista getItemVisuals() (ArrayList), e
--   resetModelNextFrame() refaz o modelo, como o tutorial vanilla faz no zumbi
--   (client/Tutorial/Steps.lua:832-838);
-- * ZombiePacket leva só outfitId e skinTextureIndex: nada disto viaja.
-- Quem decide a variante é o NOM_NightStats, na passada em lotes: ele chama o
-- gancho NOM_NightStats.look(z, kind) instalado aqui.
if isServer() then return end

require "NOM_NightStats"
require "NOM_VariantRules"

-- Itens em media/scripts/NOM_clothing.txt; peles em media/textures/Body/.
-- Direção de arte: docs/gdd/art-direction.md.
NOM_VariantLook = {
    LOOKS = {
        estalador = { skin = "NOM_Estalador", item = "Base.NOM_EstaladorVenda" },
        corredor = { skin = "NOM_Corredor", item = "Base.NOM_CorredorBoca" },
        semrosto = { item = "Base.NOM_SemRostoEstatica" },
        carpideira = { skin = "NOM_Carpideira", item = "Base.NOM_CarpideiraCabelo" },
    },
    -- Sprint 0016 (Johan, 05/10): na variante, a roupa vanilla some; fica só o que é do
    -- monstro. Padrões (Lua) de tipo de item que continuam à mostra: as camadas de
    -- ferida do corpo (não são roupa). Exceção de roupa (a "saia estranha") entra aqui.
    KEEP = { "^Base%.ZedDmg_", "^Base%.Wound_" },
}

local LOOKS = NOM_VariantLook.LOOKS
local KEEP = NOM_VariantLook.KEEP
-- [zumbi] = { kind, id, item, iv, all }: só o que este processo pôs (all = a lista de
-- ItemVisual original, na ordem, quando alguma roupa foi escondida). A tabela evita
-- qualquer chamada Java quando nada muda. Só em memória: nada disto vai pro save.
local worn = {}

local function keep(t)
    if t == nil or t:find("%.NOM_") then return true end -- item do mod (módulo.NOM_*)
    for _, p in ipairs(KEEP) do
        if t:find(p) then return true end
    end
    return false
end

-- Esconde a roupa vanilla: ItemVisual não tem flag de esconder (bytecode, pz-api-notes
-- §14.4), então sai da lista e a lista original fica guardada. Só depois da peça do
-- mod estar na lista: ela é a prova, no strip, de que o jogo não vestiu de novo.
local function hide(list, w)
    local all, gone = {}, {}
    for i = 0, list:size() - 1 do
        local iv = list:get(i)
        if iv ~= w.iv then
            all[#all + 1] = iv
            if not keep(iv:getItemType()) then gone[#gone + 1] = iv end
        end
    end
    if #gone == 0 then return end
    w.all = all
    for _, iv in ipairs(gone) do list:remove(iv) end
end

-- Chapéu caído: PersistentOutfits.setFallenHat liga o bit 0x8000 do persistentOutfitID
-- (isHatFallen(I) testa esse bit). O baseId tira o bit; se tirou, estava ligado. Aqui o
-- ID cru: o bit é o que se quer ler (o sorteio e o worn.id usam o ID sem ele).
local function hatFallen(id)
    return id ~= nil and NOM_VariantRules.baseId(id) ~= id
end

-- Devolve a lista original, na ordem. Se a peça do mod já não está lá, o jogo vestiu
-- de novo (dressInPersistentOutfitID limpa a lista) e a lista nova é a verdade.
-- Cliente de MP: o servidor derruba o chapéu (ZombieHelmetFallingPacket.processClient
-- 130–238 não acha o escondido, mas cria a roupa caindo e liga o bit). Com o bit ligado,
-- o que tem ChanceToFall > 0 não volta, como o PersistentOutfits.removeFallenHat faz
-- (18–92) ao vestir.
local function unhide(z, list, w)
    if not list:remove(w.iv) then return end
    if not w.all then return end
    local fallen = hatFallen(z:getPersistentOutfitID())
    for _, iv in ipairs(w.all) do list:remove(iv) end -- os que ficaram à mostra
    for _, iv in ipairs(w.all) do
        local item = fallen and iv:getScriptItem()
        if not (item and item:getChanceToFall() > 0) then list:add(iv) end
    end
end

-- Zumbi ainda não vestido (longe da tela): o ModelManager veste pelo ID na criação do
-- modelo e dressInPersistentOutfitID limpa pele e lista. Pinta na próxima passada.
-- Jogador reanimado: o ReanimatedPlayers salva o zumbi (IsoZombie.save →
-- HumanVisual.save, com o skinTextureName); a pele do mod iria pro save.
-- A marca vem antes de tocar no zumbi: se a API falhar no meio, o fim da névoa tira.
local function put(z, kind, id)
    if not z:isPersistentOutfitInit() or z:isReanimatedPlayer() then return end
    local look = LOOKS[kind]
    local w = { kind = kind, id = id, item = look.item }
    worn[z] = w
    if look.skin then z:getHumanVisual():setSkinTextureName(look.skin) end
    local iv = ItemVisual.new()
    iv:setItemType(look.item)
    local list = z:getItemVisuals()
    list:add(iv)
    w.iv = iv
    hide(list, w)
    z:resetModelNextFrame()
end

local function strip(z)
    local w = worn[z]
    if not w then return end
    worn[z] = nil
    if w.iv then unhide(z, z:getItemVisuals(), w) end -- remove(Object): os objetos que este processo tirou e pôs
    if LOOKS[w.kind].skin then z:getHumanVisual():setSkinTextureName(nil) end
    z:resetModelNextFrame()
    return w
end

-- kind: variante na névoa ou nil (comum, Eco, fora da névoa). id: o
-- persistentOutfitID que deu a variante (o NightStats já leu): o jogo vestir de novo
-- com outro ID apaga a pele e a lista, e aí pinta de novo.
function NOM_VariantLook.sync(z, kind, id)
    local w = worn[z]
    if w and w.kind == kind and w.id == id then return end
    if not w and kind == nil then return end
    strip(z)
    if kind and LOOKS[kind] then put(z, kind, id) end
end

-- Pro status do debug: só os zumbis carregados nesta tela. Quem saiu do mundo fica na
-- tabela até ser reaproveitado ou morrer, e ninguém o desenha.
function NOM_VariantLook.count()
    local list = getCell():getZombieList()
    local n = 0
    for i = 0, list:size() - 1 do
        if worn[list:get(i)] then n = n + 1 end
    end
    return n
end

-- Morte. Solo (IsoZombie.onKilled 38–52): o DoZombieInventory já fez vestidos e
-- inventário da lista escondida (só a peça do mod e o que ficou à mostra) antes do
-- OnZombieDead, e o corpo copia pele, WornItems e inventário depois. Devolve a lista e
-- refaz só a parte vestida pelo próprio WornItems, como o DoZombieInventory faz
-- (setFromItemVisuals + addItemsToItemContainer): o loot fica o do zumbi vanilla. Chamar
-- o DoZombieInventory de novo perderia os itemsToSpawnAtDeath (ele limpa a lista).
-- A peça do mod no inventário é a prova de que o DoZombieInventory rodou: no fogo
-- (FireCheck: OnZombieDead sem inventário) e no cliente de MP (vestidos e inventário
-- vêm do servidor, que nunca pinta) só a lista e a pele voltam.
-- WornItems e ItemContainer.Remove são locais (o removeWornItem do personagem manda
-- SyncClothing no cliente de MP).
local function dead(z)
    local w = worn[z]
    if not w then return end
    local inv = z:getInventory()
    local ran = inv:FindAndReturn(w.item)
    strip(z)
    if not ran then return end
    local wi = z:getWornItems()
    for i = 0, wi:size() - 1 do inv:Remove(wi:get(i):getItem()) end
    wi:setFromItemVisuals(z:getItemVisuals())
    wi:addItemsToItemContainer(inv)
end

NOM_NightStats.look = NOM_VariantLook.sync
-- Objeto reaproveitado (resetForReuse → OnZombieCreate): o jogo limpa a pele e só
-- veste de novo quando cria o modelo; a peça sai agora.
Events.OnZombieCreate.Add(strip)
Events.OnZombieDead.Add(dead)
-- Fim da névoa: a passada do NightStats, que a borda acorda, chama o gancho com nil em
-- cada zumbi, BATCH por tick (sprint 0016): devolver todo mundo no mesmo tick refazia
-- todos os modelos de uma vez. Quem saiu da lista sai da tabela quando o objeto for
-- reaproveitado (OnZombieCreate) ou morrer; até lá ninguém o desenha.

return NOM_VariantLook
