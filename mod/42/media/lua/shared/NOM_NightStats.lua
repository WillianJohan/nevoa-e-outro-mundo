-- Stats noturnos (velocidade, visão, audição) e perfis das variantes da névoa
-- (Estalador, Corredor) aplicados em lotes por tick. Roda onde o zumbi é simulado
-- (ADR-005): no solo, chamado por server/NOM_Night.lua; no MP, por
-- client/NOM_NightClient.lua. Quem decide se é noite e se há névoa é o servidor:
-- a noite chega por setNight, a névoa pelo NOM_FogState (número do período, base
-- do sorteio das variantes, ADR-006).
--
-- O jogo não tem setter de velocidade/sentidos por zumbi. DoZombieStats() relê
-- sight/hearing do sandbox e doZombieSpeed(t) usa o sandbox antes do argumento
-- (bytecode IsoZombie.doZombieSpeedInternal), então o ZombieLore é trocado só
-- durante a chamada e devolvido em seguida. setValue não sincroniza nem salva
-- (IntegerConfigOption.setValue só grava o campo).
require "NOM_NightRules"
require "NOM_VariantRules"
require "NOM_Config"
require "NOM_FogState"

-- variants: { [zumbi] = "estalador" | "corredor" } das cópias locais. O
-- NOM_VariantAI olha só esta tabela no OnZombieUpdate (por zumbi, por frame)
-- antes de qualquer chamada Java.
NOM_NightStats = { night = false, BATCH = 20, variants = {} }

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
-- De dia, uma passada inteira sem nada a devolver quer dizer que ninguém tem stat
-- da noite: o tick dorme até a próxima flag. Zumbi que volta do virtual ou é
-- reaproveitado nasce limpo (objeto novo ou modData zerado), então nada novo
-- aparece de dia. Orçamento em docs/architecture/README.md.
-- O cursor é por posição: cada zumbi que sai da lista no meio da passada pode
-- fazer o cursor pular um. Rede de segurança: o tick acorda a cada hora de jogo
-- (wake) e faz uma passada a mais; um zumbi preso fica no máximo uma hora.
local idle = false
local sweep = { seen = 0, applied = 0 }

-- Passada nova (flag nova ou EveryHours).
local function wake()
    idle = false
    sweep.seen, sweep.applied = 0, 0
end

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
        variants = NOM_VariantRules.config(NOM_Config.get),
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
-- dayTier nil: degrau do dia desconhecido (sandbox aleatório visto só inativo);
-- no dia o jogo sorteia com doZombieSpeed(-1), sem trocar o Speed.
local function apply(z, md, w, dayTier, key, inactive, kind)
    local values = { [LORE.cognition] = COGNITION_KEEP, [LORE.memory] = MEMORY_KEEP }
    local speed = w.speed
    if key == "day" and dayTier == nil then speed = -1 end
    if not inactive and speed ~= -1 then values[LORE.speed] = speed end
    if w.sight then values[LORE.sight] = w.sight end
    if w.hearing then values[LORE.hearing] = w.hearing end
    local crawl = z:isCanCrawlUnderVehicle() -- DoZombieStats re-sorteia
    withLore(values, function()
        z:DoZombieStats()
        if not inactive then z:doZombieSpeed(speed) end
    end)
    z:setCanCrawlUnderVehicle(crawl)
    -- Cache só em memória: modData de zumbi não é salvo e é zerado no
    -- reaproveitamento, que é quando o jogo re-sorteia os stats.
    if key == "day" then
        md.NOM_night = nil
        md.NOM_dayTier = nil
        md.NOM_variant = nil
        md.NOM_alert = nil
        md.NOM_hunting = nil
        NOM_NightStats.variants[z] = nil
    else
        md.NOM_night = key
        md.NOM_dayTier = dayTier
        -- Lido pelo NOM_VariantAI (cego, estalo, grito). Só em memória, como o resto.
        md.NOM_variant = kind ~= "eco" and kind or nil
        NOM_NightStats.variants[z] = md.NOM_variant
    end
end

-- Visual da variante (client/NOM_VariantLook.lua, sprint 0012), se instalado. Em
-- pcall: uma surpresa da API no jogo não pode parar a passada dos stats.
local function look(z, kind, id)
    local fn = NOM_NightStats.look
    if not fn then return end
    local ok, err = pcall(fn, z, kind, id)
    if not ok then print("[NOM] visual: erro: " .. tostring(err)) end
end

-- Leva o zumbi ao perfil certo. Devolve true se aplicou.
local function process(z, c)
    if z:isDead() then return false end
    -- useless herdado pela rede (NOM_VariantAI instala; review da 0011): toda passada,
    -- inclusive a de conferência do fim da névoa e a de hora em hora de dia
    if NOM_NightStats.unstick then NOM_NightStats.unstick(z) end
    local md = z:getModData()
    local cur = md.NOM_night
    local fog = NOM_FogState.on
    if cur == nil and not NOM_NightStats.night and not fog then -- dia sem névoa, intocado
        look(z, nil)
        return false
    end
    -- Eco primeiro: nunca é variante. A variante é derivada a cada passada do ID
    -- atual (ADR-006): o spawn por outfit troca o ID depois do OnZombieCreate. Só
    -- existe na névoa (decisão do Johan, 05/10), sorteada pelo período de névoa; na
    -- névoa vermelha, todo zumbi (sprint 0010).
    -- O Sem-rosto não tem stats: aqui ele é zumbi comum (server/NOM_Fog.lua).
    local kind, id = nil, nil
    if isEco(z, md) then
        kind = "eco"
    elseif fog then
        id = NOM_VariantRules.baseId(z:getPersistentOutfitID()) -- sem o chapéu caído (sprint 0017)
        kind = NOM_VariantRules.variant(id, NOM_FogState.period, c.variants, NOM_FogState.red)
    end
    -- o Sem-rosto tem visual mas não stats; o Eco tem o visual no outfit
    look(z, kind ~= "eco" and kind or nil, id)
    if kind == "semrosto" then kind = nil end
    -- Speed aleatória: o degrau do dia é o do zumbi, mas inativo ele está sempre
    -- em 3 (makeInactive). Aí fica desconhecido (nil) e não é guardado.
    local dayTier = md.NOM_dayTier
    if dayTier == nil and not (c.inactive and c.speed == 4) then
        dayTier = NOM_NightRules.dayTier(c.speed, z:getSpeedType())
    end
    local w = NOM_NightRules.wanted(NOM_NightStats.night, kind, dayTier or z:getSpeedType(), c)
    -- A fase entra na chave: quando ela vira, o jogo re-rola (makeInactive(false)
    -- chama DoZombieStats) e o mod reaplica.
    local key = w.key
    if key ~= "day" and c.inactive then key = key .. ":i" end
    local need = (cur or "day") ~= key
    -- O jogo re-rola os stats às vezes (addZombiesInOutfit, makeInactive). Remoto:
    -- a velocidade vem do pacote do dono (NetworkZombieAI.parse), não briga.
    if not need and key ~= "day" and not c.inactive and not z:isRemoteZombie() and not z:isCrawling() then
        need = z:getSpeedType() ~= w.speed
        -- Diagnóstico (só -debug): visto no jogo um zumbi reaplicado a cada passada.
        if need and getDebug() then
            print("[NOM] noite re-rolou id=" .. tostring(z:getPersistentOutfitID()) .. " speedType=" .. tostring(z:getSpeedType())
                .. " quer=" .. tostring(w.speed) .. " kind=" .. tostring(kind) .. " fakeDead=" .. tostring(z:isFakeDead())
                .. " sitting=" .. tostring(z:isSitOnGround()) .. " outfit=" .. tostring(z:getOutfitName()))
        end
    end
    if need then apply(z, md, w, dayTier, key, c.inactive, kind) end
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
    if idle then return end
    local list = getCell():getZombieList()
    local size = list:size()
    if size == 0 and #queue == 0 then return end
    local c = config()
    local budget, applied = NOM_NightStats.BATCH, 0
    local fromQueue = #queue
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
    if NOM_NightStats.night or NOM_FogState.on then return end
    sweep.seen = sweep.seen + n
    sweep.applied = sweep.applied + applied
    if sweep.seen >= size and fromQueue == 0 then
        idle = sweep.applied == 0 and #queue == 0
        sweep.seen, sweep.applied = 0, 0
    end
end

-- nightNumber: número da noite do servidor (NOM_NightCount), só pro status do
-- debug (as variantes usam o período de névoa). nil enquanto o cliente não souber.
function NOM_NightStats.setNight(on, nightNumber)
    wake()
    NOM_NightStats.night = on
    NOM_NightStats.nightNumber = nightNumber
end

-- OnZombieCreate: inclusive zumbi que volta do virtual com stats re-sorteados.
-- Objeto reaproveitado (resetForReuse) passa por aqui: sai do conjunto.
function NOM_NightStats.enqueue(z)
    NOM_NightStats.variants[z] = nil
    if idle then return end -- de dia e dormindo: nasce limpo, nada a devolver
    queue[#queue + 1] = z
end

-- O corpo copia o modData do zumbi (IsoDeadBody.<init>): a chave não vai pro save.
function NOM_NightStats.forget(z)
    NOM_NightStats.variants[z] = nil
    if not z:hasModData() then return end
    local md = z:getModData()
    md.NOM_night = nil
    md.NOM_dayTier = nil
    md.NOM_variant = nil
    md.NOM_hunting = nil
    md.NOM_alert = nil
    md.NOM_furia = nil -- Carpideira que gritou (NOM_Carpideira)
end

function NOM_NightStats.install()
    Events.OnTick.Add(NOM_NightStats.tick)
    -- EveryHours: shared/Foraging/forageSystem.lua:751
    Events.EveryHours.Add(wake)
    Events.OnZombieCreate.Add(NOM_NightStats.enqueue)
    Events.OnZombieDead.Add(NOM_NightStats.forget)
    -- névoa que sobe ou baixa (de dia também) acorda o tick que dormia
    NOM_FogState.onChange(wake)
end

return NOM_NightStats
