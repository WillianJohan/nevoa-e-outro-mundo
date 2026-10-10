-- Brasa permanente nos Tições na névoa preta (sprint 0067): casca BoilerSuit com
-- fissuras (Base.NOM_BrasaCasca + shader NOM_Brasa), pulso via Alpha. Só cliente.
-- Com efeitos desligados veste o gêmeo estático. Cede o Alpha ao dissolve (mutação).
if isServer() then return end

require "NOM_BrasaRules"
require "NOM_FogState"
require "NOM_ScreenFxOptions"
require "NOM_Dissolve"
require "NOM_EmberShell"
require "NOM_TicaoFreeze"

NOM_BrasaLook = {}
local L = NOM_BrasaLook
local R = NOM_BrasaRules

-- [zumbi] = { iv, seed, period, phase0, item }
local worn = {}
local count = 0

function L.count()
    return count
end

function L.has(z)
    return worn[z] ~= nil
end

local function wantFx()
    return NOM_ScreenFxOptions.bodyEmbers() == true
end

local function itemType()
    if wantFx() then return R.ITEM end
    return R.ITEM_STATIC
end

local function seedOf(z)
    local id = z.getOnlineID and z:getOnlineID() or -1
    if id and id ~= -1 then return id end
    if z.getPersistentOutfitID then
        return z:getPersistentOutfitID() or 0
    end
    return math.floor((z:getX() or 0) * 31 + (z:getY() or 0) * 17)
end

local function isTicao(z)
    if not z or not z.hasModData then return false end
    local md = z:getModData()
    if md and md.NOM_kind == "ticao" then return true end
    -- fallback: crosta vestida (VariantLook)
    local list = z.getItemVisuals and z:getItemVisuals()
    if not list then return false end
    for i = 0, list:size() - 1 do
        local t = list:get(i):getItemType()
        if t == "Base.NOM_TicaoCrosta" or t == "Base.NOM_TicaoCrostaFx" then
            return true
        end
    end
    return false
end

local function active()
    return NOM_FogState.on == true and NOM_FogState.black == true
end

local function removeIv(z, e)
    if not e or not e.iv then return end
    local list = z:getItemVisuals()
    if list then list:remove(e.iv) end
    z:resetModelNextFrame()
end

function L.remove(z)
    local e = worn[z]
    if not e then return end
    worn[z] = nil
    count = count - 1
    removeIv(z, e)
end

local function wear(z)
    if worn[z] then return true end
    if NOM_EmberShell.has and NOM_EmberShell.has(z) then return false end
    local iv = ItemVisual.new()
    local item = itemType()
    iv:setItemType(item)
    z:getItemVisuals():add(iv)
    local seed = seedOf(z)
    worn[z] = {
        iv = iv,
        seed = seed,
        period = R.periodMs(seed, false),
        phase0 = R.phase0(seed),
        item = item,
    }
    count = count + 1
    z:resetModelNextFrame()
    return true
end

local function syncItem(z, e)
    local want = itemType()
    if e.item == want then return end
    removeIv(z, e)
    local iv = ItemVisual.new()
    iv:setItemType(want)
    z:getItemVisuals():add(iv)
    e.iv = iv
    e.item = want
    z:resetModelNextFrame()
end

local function lightHold(z)
    return NOM_TicaoFreeze and NOM_TicaoFreeze.frozen and NOM_TicaoFreeze.frozen[z] == true
end

local function pulseTick(z, e, now, players)
    if not wantFx() then return end
    if NOM_Dissolve.busy and NOM_Dissolve.busy(z) then return end
    if NOM_EmberShell.has and NOM_EmberShell.has(z) then return end
    local hunting = false
    if z.hasModData then
        local md = z:getModData()
        hunting = md and md.NOM_ticaoHunt == true
    end
    local period = R.periodMs(e.seed, hunting)
    local pulse = R.pulse(now, period, e.phase0, lightHold(z))
    local a = R.alpha(pulse)
    for pn = 0, players - 1 do
        z:setAlpha(pn, math.min(a, z:getAlpha(pn)))
    end
end

-- EmberShell vai vestir NOM_Brasa: tira a casca permanente pra não empilhar BoilerSuit.
function L.yieldForShell(z)
    L.remove(z)
end

Events.OnTick.Add(function()
    if isGamePaused and isGamePaused() then return end
    local now = getTimestampMs()
    local players = getNumActivePlayers()
    if not active() then
        if count > 0 then
            local zs = {}
            for z in pairs(worn) do zs[#zs + 1] = z end
            for _, z in ipairs(zs) do L.remove(z) end
        end
        return
    end
    local cell = getCell and getCell()
    if not cell or not cell.getZombieList then return end
    local list = cell:getZombieList()
    if not list then return end
    local seen = {}
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z and (not z.isAlive or z:isAlive()) and isTicao(z) then
            seen[z] = true
            if not worn[z] then
                wear(z)
            else
                syncItem(z, worn[z])
            end
            local e = worn[z]
            if e then pulseTick(z, e, now, players) end
        end
    end
    local gone = {}
    for z in pairs(worn) do
        if not seen[z] then gone[#gone + 1] = z end
    end
    for _, z in ipairs(gone) do L.remove(z) end
end)

Events.OnZombieCreate.Add(L.remove)
Events.OnZombieDead.Add(L.remove)
Events.OnMainMenuEnter.Add(function()
    worn = {}
    count = 0
end)

return NOM_BrasaLook
