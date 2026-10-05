-- Morte do Eco com dissolve (sprint 0018, ADR-016), só no jogo de quem vê (solo e cliente
-- de MP): o véu vira o gêmeo com shader, uma casca de cinza (malha Hazmat vanilla com as
-- máscaras do corpo) veste o corpo, os dois queimam pelo Alpha (client/NOM_Dissolve.lua,
-- modo "death") durante a animação de morte, brasas sobem (client/NOM_Embers.lua) e o
-- corpo que nasce fica escondido até o servidor tirá-lo (server/NOM_Eco.lua, como antes).
--
-- Por que pelo WornItems (bytecode B42.21): IsoGameCharacter.Kill 35–50 liga o onKillDone
-- logo depois do onKilled (que dispara o OnZombieDead), e com ele IsoZombie.getItemVisuals
-- sai do WornItems (isUsingWornItems; getItemVisuals 0–38). O modelo refeito na animação de
-- morte (resetModelNextFrame) é o do WornItems: o véu troca no visual do item vestido, e a
-- casca entra por WornItems.setItem (local; o setWornItem do personagem mandaria
-- SyncClothing no MP). A lista de ItemVisual também troca, pro caso de o modelo ser refeito
-- antes. No solo o WornItems já veio do DoZombieInventory; no cliente de MP, do servidor.
--
-- Cliente de MP: dieNetwork 0–10 faz Kill e logo becomeCorpse, então não há janela: o
-- corpo nasce no mesmo tick e só as brasas aparecem (o console mostra "janela ms=0").
if isServer() then return end

require "NOM_Dissolve"
require "NOM_Embers"

NOM_EcoFx = {
    OUTFIT = "NOM_Eco", -- media/clothing/clothing.xml
    VEIL = "Base.NOM_EcoVeu",
    VEIL_FX = "Base.NOM_EcoVeuFx",
    SHELL_ITEM = "Base.NOM_EcoCasca",
    -- Decisão de arte do Johan pendente: a casca Hazmat muda a silhueta do Eco no segundo
    -- da morte. false = só o véu queima e o corpo some em fade.
    SHELL = true,
}

local F = NOM_EcoFx
local lastDeath

local function debugLog(msg)
    if getDebug() then print("[NOM] eco: " .. msg) end
end

local function swap(v)
    if v and v:getItemType() == F.VEIL then v:setItemType(F.VEIL_FX) end
end

local function dress(z)
    local list = z:getItemVisuals()
    for i = 0, list:size() - 1 do swap(list:get(i)) end
    local wi = z:getWornItems()
    for i = 0, wi:size() - 1 do swap(wi:get(i):getItem():getVisual()) end
    if F.SHELL then
        local it = instanceItem(F.SHELL_ITEM)
        if it then wi:setItem(it:getBodyLocation(), it) end
    end
    z:resetModelNextFrame()
end

local function dead(z)
    if z:getOutfitName() ~= F.OUTFIT or not NOM_Dissolve.enabled() then return end
    lastDeath = getTimestampMs()
    NOM_Embers.burst(z:getX(), z:getY(), z:getZ())
    if NOM_Dissolve.run(z, "death") then
        dress(z)
        debugLog("morte com dissolve")
    end
end

local function body(b)
    if b:isAnimal() or b:getOutfitName() ~= F.OUTFIT or not NOM_Dissolve.enabled() then return end
    b:setDoRender(false)
    debugLog("corpo escondido, janela ms=" .. tostring(lastDeath and math.floor(getTimestampMs() - lastDeath) or -1))
end

-- pcall: uma surpresa da API não pode quebrar o evento dos outros.
local function safe(fn)
    return function(x)
        local ok, err = pcall(fn, x)
        if not ok then print("[NOM] eco: erro: " .. tostring(err)) end
    end
end

Events.OnZombieDead.Add(safe(dead))
Events.OnDeadBodySpawn.Add(safe(body))

return NOM_EcoFx
