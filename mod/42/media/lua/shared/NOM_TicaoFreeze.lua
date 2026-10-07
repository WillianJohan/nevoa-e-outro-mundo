-- A luz congela o Tição (sprint 0038), onde o zumbi é simulado (ADR-005). Quem decide quem está
-- na luz é o servidor (server/NOM_TicaoLight.lua): no solo ele chama F.apply com os zumbis; no MP
-- manda "ticaoFrozen" com os onlineIDs a cada NOM_LightRules.SWEEP_MS e o
-- client/NOM_FogClient.lua chama F.applyIds. O dono (z:isLocal(), pz-api-notes §24) congela os
-- listados que são dele com o mesmo setUseless + halt da sirene (NOM_SirenFreeze, pz-api-notes
-- §3.2 e §21) e solta os que saíram da lista. Cópia remota não se mexe: o useless dela chega no
-- pacote do dono. Sem lista por SILENCE_MS (comando perdido, servidor caiu), solta todos; o fim
-- da preta também.
--
-- A lanterna pisca (F.flicker): o servidor sorteia o padrão (server/NOM_TicaoLight.lua,
-- NOM_FlickerRules.torch) e aqui, no dono da lanterna, ela liga e desliga sem sync
-- (InventoryItem.setActivated é local; o vanilla manda o syncItemActivated à parte,
-- client/ISUI/ISInventoryPaneContextMenu.lua:2882-2883) e termina acesa, enquanto estiver no
-- inventário dele (item:getContainer() == getInventory(), shared/TimedActions/ISEquipHeavyItem.lua:56).
-- Quem mexeu no meio (desligou num trecho aceso, acendeu num apagado, guardou) para o padrão: a
-- lanterna fica como ele deixou.
require "NOM_Carpideira"
require "NOM_SirenFreeze"
require "NOM_LightRules"
require "NOM_FlickerRules"
require "NOM_FogState"

NOM_TicaoFreeze = { frozen = {} }
local F = NOM_TicaoFreeze
local lastMsg -- getTimestampMs da última lista
local scratch = {}
local flickering = {} -- { { p, item, start, segs, lit } }: lanternas tocando o padrão; lit = o último estado posto

-- O cego do NOM_VariantAI (visão curta) já está parado pela regra dele; lido na hora (o
-- NOM_VariantAI requer este arquivo).
local function blind(z)
    return NOM_VariantAI ~= nil and NOM_VariantAI.blinded ~= nil and NOM_VariantAI.blinded[z] ~= nil
end

local function gameOwns(z)
    return getCore():getGameMode() == "Tutorial" or NOM_Carpideira.gameUseless(z)
end

local function halt(z)
    z:getPathFindBehavior2():cancel()
    z:setPath2(nil)
    z:setVariable("bPathfind", false)
    z:setVariable("bMoving", false)
end

local function release(z)
    F.frozen[z] = nil
    if not z:isDead() and z:isLocal() then z:setUseless(false) end
end

local function hold(z)
    if z:isDead() or not z:isLocal() then return end
    if blind(z) or NOM_SirenFreeze.frozen[z] or NOM_Carpideira.still[z] or gameOwns(z) then return end
    if not F.frozen[z] then
        z:setUseless(true)
        z:setTarget(nil)
        F.frozen[z] = true
    end
    halt(z)
end

-- zs: lista dos zumbis na luz agora. Fora da preta não congela ninguém.
function F.apply(zs)
    lastMsg = getTimestampMs()
    local want = {}
    if NOM_FogState.black then
        for _, z in ipairs(zs) do want[z] = true end
    end
    local n = 0
    for z in pairs(F.frozen) do
        if not want[z] then
            n = n + 1
            scratch[n] = z
        end
    end
    for i = 1, n do
        release(scratch[i])
        scratch[i] = nil
    end
    for z in pairs(want) do hold(z) end
end

-- ids: onlineIDs do servidor. Uma volta na lista local: 1 chamada por zumbi (o ID).
function F.applyIds(ids)
    local set, any = {}, false
    for _, id in ipairs(ids or {}) do
        set[id] = true
        any = true
    end
    local zs = {}
    if any then
        local list = getCell():getZombieList()
        for i = 0, list:size() - 1 do
            local z = list:get(i)
            if set[z:getOnlineID()] then zs[#zs + 1] = z end
        end
    end
    F.apply(zs)
end

function F.releaseAll()
    local n = 0
    for z in pairs(F.frozen) do
        n = n + 1
        scratch[n] = z
    end
    for i = 1, n do
        release(scratch[i])
        scratch[i] = nil
    end
    lastMsg = nil
end

function F.count()
    local n = 0
    for _ in pairs(F.frozen) do n = n + 1 end
    return n
end

-- p: jogador local dono da lanterna; segs: o padrão (NOM_FlickerRules; um número = só o escuro).
function F.flicker(p, segs)
    if p == nil then return false end
    local item = p:getActiveLightItem()
    if item == nil then return false end
    if type(segs) ~= "table" then segs = { math.max(1, math.floor(tonumber(segs) or 1)) } end
    item:setActivated(false)
    flickering[#flickering + 1] = { p = p, item = item, start = getTimestampMs(), segs = segs, lit = false }
    return true
end

local function play(now)
    for i = #flickering, 1, -1 do
        local f = flickering[i]
        local on, done = NOM_FlickerRules.stateAt(f.segs, now - f.start)
        if f.item:isActivated() ~= f.lit or f.item:getContainer() ~= f.p:getInventory() then
            table.remove(flickering, i) -- o jogador mexeu: fica como ele deixou
        elseif done then
            table.remove(flickering, i)
            if not f.lit then f.item:setActivated(true) end
        elseif on ~= f.lit then
            f.item:setActivated(on)
            f.lit = on
        end
    end
end

function F.tick()
    local now = getTimestampMs()
    if lastMsg ~= nil and now - lastMsg > NOM_LightRules.SILENCE_MS then F.releaseAll() end
    if #flickering > 0 then play(now) end
end

local function forget(z) F.frozen[z] = nil end

-- Objeto reaproveitado (OnZombieCreate): o resetForReuse não limpa o useless.
local function reused(z)
    if F.frozen[z] then release(z) end
end

function F.install()
    Events.OnTick.Add(F.tick)
    Events.OnZombieDead.Add(forget)
    Events.OnZombieCreate.Add(reused)
    NOM_FogState.onChange(function()
        if not NOM_FogState.black then F.releaseAll() end
    end)
end

return NOM_TicaoFreeze
