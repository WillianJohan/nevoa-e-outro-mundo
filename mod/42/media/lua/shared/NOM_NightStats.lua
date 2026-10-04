-- Stats noturnos (velocidade, visão, audição) aplicados em lotes por tick.
-- Roda onde o zumbi é simulado (ADR-005): no solo, chamado por server/NOM_Night.lua;
-- no MP, por client/NOM_NightClient.lua. Quem decide se é noite é o servidor.
--
-- O jogo não tem setter de velocidade/sentidos por zumbi. DoZombieStats() relê
-- sight/hearing do sandbox e doZombieSpeed(t) usa o sandbox antes do argumento
-- (bytecode IsoZombie.doZombieSpeedInternal), então o ZombieLore é trocado só
-- durante a chamada e devolvido em seguida. setValue não sincroniza nem salva
-- (IntegerConfigOption.setValue só grava o campo).
require "NOM_NightRules"
require "NOM_Config"

NOM_NightStats = { night = false, BATCH = 20 }

local LORE = {
    speed = "ZombieLore.Speed",
    sight = "ZombieLore.Sight",
    hearing = "ZombieLore.Hearing",
    cognition = "ZombieLore.Cognition",
    memory = "ZombieLore.Memory",
}
-- Valores neutros durante a troca: DoZombieStats só mexe na cognition com sandbox
-- 1 ou 4, e re-sorteia a memory com sandbox 5/6 (aleatório); com 2 nos dois, os
-- campos já sorteados ficam como estão.
local COGNITION_KEEP = 2
local MEMORY_KEEP = 2
local ECO_OUTFIT = "NOM_Eco" -- media/clothing/clothing.xml

local cursor = 0
local queue = {}
local pass = { seen = 0, applied = 0 }

local function option(name)
    return getSandboxOptions():getOptionByName(name)
end

local function config()
    return {
        fasterOn = NOM_Config.get("NightFaster"),
        sensesOn = NOM_Config.get("NightSharperSenses"),
        speedMult = NOM_Config.get("NightSpeedMult"),
        senseMult = NOM_Config.get("NightSenseMult"),
        speed = option(LORE.speed):getValue(),
        sight = option(LORE.sight):getValue(),
        hearing = option(LORE.hearing):getValue(),
        -- ActiveOnly vanilla: na fase inativa o jogo deixa o zumbi arrastado
        -- (IsoZombie.updateActiveState → makeInactive) e nunca reafirma.
        inactive = getGameTime():isZombieInactivityPhase(),
    }
end

-- O sandbox volta mesmo se fn falhar: o jogo salva o sandbox, e um valor
-- trocado vazaria pra todo zumbi e pro save.
local function withLore(values, fn)
    local old = {}
    for name, v in pairs(values) do
        local o = option(name)
        old[name] = o:getValue()
        o:setValue(v)
    end
    local ok, err = pcall(fn)
    for name, v in pairs(old) do
        option(name):setValue(v)
    end
    if not ok then print("[NOM] noite: erro aplicando stats: " .. tostring(err)) end
end

-- Solo: marca do server/NOM_Eco.lua. Cliente de MP: o modData do servidor não
-- chega, o outfit sim.
local function isEco(z, md)
    return md.NOM_eco == true or z:getOutfitName() == ECO_OUTFIT
end

-- inactive: fase inativa do ActiveOnly. A velocidade fica com o jogo:
-- doZombieSpeed(t) ignora o inactive com t ≠ -1 (determineZombieSpeed) e acordaria
-- o zumbi. O doZombieSpeed() de dentro do DoZombieStats usa o speedType atual (3).
local function apply(z, md, w, dayTier, key, inactive)
    local values = { [LORE.cognition] = COGNITION_KEEP, [LORE.memory] = MEMORY_KEEP }
    if not inactive then values[LORE.speed] = w.speed end
    if w.sight then values[LORE.sight] = w.sight end
    if w.hearing then values[LORE.hearing] = w.hearing end
    local crawl = z:isCanCrawlUnderVehicle() -- DoZombieStats re-sorteia
    withLore(values, function()
        z:DoZombieStats()
        if not inactive then z:doZombieSpeed(w.speed) end
    end)
    z:setCanCrawlUnderVehicle(crawl)
    -- Cache só em memória: modData de zumbi não é salvo e é zerado no
    -- reaproveitamento, que é quando o jogo re-sorteia os stats.
    if key == "day" then
        md.NOM_night = nil
        md.NOM_dayTier = nil
    else
        md.NOM_night = key
        md.NOM_dayTier = dayTier
    end
end

-- Leva o zumbi ao perfil certo. Devolve true se aplicou.
local function process(z, c)
    if z:isDead() then return false end
    local md = z:getModData()
    local cur = md.NOM_night
    if cur == nil and not NOM_NightStats.night then return false end -- dia, intocado
    local dayTier = NOM_NightRules.dayTier(c.speed, md.NOM_dayTier or z:getSpeedType())
    local w = NOM_NightRules.wanted(NOM_NightStats.night, isEco(z, md), dayTier, c)
    -- A fase entra na chave: quando ela vira, o jogo re-rola (makeInactive(false)
    -- chama DoZombieStats) e o mod reaplica.
    local key = w.key
    if key ~= "day" and c.inactive then key = key .. ":i" end
    local need = (cur or "day") ~= key
    -- O jogo re-rola os stats às vezes (addZombiesInOutfit, makeInactive). Remoto:
    -- a velocidade vem do pacote do dono (NetworkZombieAI.parse), não briga.
    if not need and key ~= "day" and not c.inactive and not z:isRemoteZombie() and not z:isCrawling() then
        need = z:getSpeedType() ~= w.speed
    end
    if need then apply(z, md, w, dayTier, key, c.inactive) end
    return need
end

local function logPass(size, n, applied)
    if not getDebug() then return end
    pass.seen = pass.seen + n
    pass.applied = pass.applied + applied
    if pass.seen >= size then
        if pass.applied > 0 then
            print("[NOM] noite stats aplicados=" .. pass.applied .. " zumbis=" .. size .. " noite=" .. tostring(NOM_NightStats.night))
        end
        pass.seen, pass.applied = 0, 0
    end
end

-- Até BATCH zumbis por tick: primeiro os recém-criados, depois round-robin.
function NOM_NightStats.tick()
    local list = getCell():getZombieList()
    local size = list:size()
    if size == 0 and #queue == 0 then return end
    local c = config()
    local budget, applied = NOM_NightStats.BATCH, 0
    while budget > 0 and #queue > 0 do
        local z = table.remove(queue)
        budget = budget - 1
        if process(z, c) then applied = applied + 1 end
    end
    local n = math.min(budget, size)
    for k = 0, n - 1 do
        if process(list:get((cursor + k) % size), c) then applied = applied + 1 end
    end
    cursor = size > 0 and (cursor + n) % size or 0
    logPass(size, n, applied)
end

function NOM_NightStats.setNight(on)
    NOM_NightStats.night = on
end

-- OnZombieCreate: inclusive zumbi que volta do virtual com stats re-sorteados.
function NOM_NightStats.enqueue(z)
    queue[#queue + 1] = z
end

-- O corpo copia o modData do zumbi (IsoDeadBody.<init>): a chave não vai pro save.
function NOM_NightStats.forget(z)
    if not z:hasModData() then return end
    local md = z:getModData()
    md.NOM_night = nil
    md.NOM_dayTier = nil
end

function NOM_NightStats.install()
    Events.OnTick.Add(NOM_NightStats.tick)
    Events.OnZombieCreate.Add(NOM_NightStats.enqueue)
    Events.OnZombieDead.Add(NOM_NightStats.forget)
end

return NOM_NightStats
