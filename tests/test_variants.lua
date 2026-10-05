-- server/NOM_Variants.lua contra um servidor falso que imita o jogo onde importa:
-- * sendPlaySound(nome, loop, objeto): só age no dedicado, manda aos clientes perto
--   (server/Fishing/BuildingObjects/FishingNet.lua:86; bytecode sendToRelative).
-- * no solo o som toca no emitter do personagem (shared/TimedActions/ISDrinkFluidAction.lua:34).
-- * addSound(fonte, x, y, z, raio, volume) (server/Camping/SCampfireSystem.lua:162); o
--   zumbi ouve a raio × getHearingMultiplier (3.0 apurada, a da noite).
-- * getGameTime():getWorldAgeHours() (server/Vehicles/VehicleCommands.lua:240).
-- * OnClientCommand(module, command, player, args) (server/ClientCommands.lua:1296).
-- * modData do zumbi no servidor: o Eco tem NOM_eco (server/NOM_Eco.lua).
-- * character:DistTo(x, y) (client/Vehicles/TimedActions/ISDetachTrailerFromVehicle.lua:34);
--   getTimestampMs() relógio real em ms (server/ISObjectClickHandler.lua:352).
require "NOM_VariantRules"

local FILE = "mod/42/media/lua/server/NOM_Variants.lua"
local NIGHT_FILE = "mod/42/media/lua/server/NOM_Night.lua"
local HEARING_MULT = { 3.0, 1.0, 0.45 }

local function setup(opts)
    opts = opts or {}
    local G = { zombies = {}, sounds = {}, played = {}, hours = 100, world = { tod = opts.tod or 23 },
        globalMD = {}, aiReport = nil, ms = 0 }
    local handlers = {}
    local function fire(name, ...)
        for _, h in ipairs(handlers[name] or {}) do h(...) end
    end
    G.sandbox = opts.sandbox or { CorredorChance = 100, EstaladorChance = 0 }
    function G.zombie(o)
        local z = { x = o.x or 10, y = o.y or 10, z = 0, md = o.md or {}, id = o.id, onlineID = o.onlineID or 7,
            outfitName = o.outfit, dead = false }
        function z:getX() return self.x + 0.5 end
        function z:getY() return self.y + 0.5 end
        function z:getZ() return self.z end
        function z:getModData() return self.md end
        function z:getPersistentOutfitID() return self.id end
        function z:getOutfitName() return self.outfitName end
        function z:getOnlineID() return self.onlineID end
        function z:isDead() return self.dead end
        function z:getEmitter()
            return { playSound = function(_, name) G.played[#G.played + 1] = { name = name, src = z, local_ = true } end }
        end
        G.zombies[#G.zombies + 1] = z
        return z
    end
    isClient = function() return false end
    isServer = function() return opts.server == true end
    getDebug = function() return false end
    SandboxVars = { NevoaEOutroMundo = G.sandbox }
    ModData = {
        getOrCreate = function(name)
            G.globalMD[name] = G.globalMD[name] or {}
            return G.globalMD[name]
        end,
    }
    getNumActivePlayers = function() return 0 end
    getOnlinePlayers = function() return { size = function() return 0 end } end
    addSound = function(src, x, y, z, radius, volume)
        G.sounds[#G.sounds + 1] = { src = src, x = x, y = y, z = z, radius = radius, volume = volume }
    end
    sendPlaySound = function(name, loop, obj)
        if not isServer() then return end -- bytecode: só no GameServer
        G.played[#G.played + 1] = { name = name, src = obj, loop = loop }
    end
    sendServerCommand = function() end
    getGameTime = function()
        return {
            getTimeOfDay = function() return G.world.tod end,
            getWorldAgeHours = function() return G.hours end,
        }
    end
    getTimestampMs = function() return G.ms end
    getClimateManager = function()
        return { getSeason = function() return { getDawn = function() return 6 end, getDusk = function() return 21 end } end }
    end
    getSandboxOptions = function()
        return { getOptionByName = function() return { getValue = function() return 2 end } end }
    end
    getCell = function()
        return {
            getZombieList = function()
                return { size = function() return #G.zombies end, get = function(_, i) return G.zombies[i + 1] end }
            end,
        }
    end
    Events = setmetatable({}, {
        __index = function(t, name)
            local e = { Add = function(f) handlers[name] = handlers[name] or {}; table.insert(handlers[name], f) end }
            rawset(t, name, e)
            return e
        end,
    })
    for _, m in ipairs({ "NOM_World", "NOM_NightStats", "NOM_Players", "NOM_NightCount", "NOM_Night", "NOM_VariantAI" }) do
        _G[m] = nil
        package.loaded[m] = nil
    end
    require "NOM_NightStats"
    NOM_NightStats.install = function() end
    require "NOM_VariantAI"
    NOM_VariantAI.install = function(fn) G.aiReport = fn end
    dofile(NIGHT_FILE)
    package.loaded["NOM_Night"] = NOM_Night
    dofile(FILE)
    function G.setTime(tod)
        G.world.tod = tod
        NOM_World.update(0)
    end
    -- jogador que manda o comando: perto do zumbi (10, 10) por padrão
    function G.player(x, y)
        local p = { x = x or 12, y = y or 10 }
        function p:DistTo(tx, ty) return math.sqrt((self.x - tx) ^ 2 + (self.y - ty) ^ 2) end
        return p
    end
    G.sender = G.player()
    -- cada comando chega 2 s depois do anterior, salvo o teste dizer outra coisa
    function G.clientCommand(module, command, args, player, gapMs)
        G.ms = G.ms + (gapMs or 2000)
        fire("OnClientCommand", module, command, player or G.sender, args)
    end
    -- alcance real do grito pros zumbis em volta (audição apurada da noite)
    function G.reach(s) return s.radius * HEARING_MULT[1] end
    G.setTime(G.world.tod)
    return G
end

-- ID (formato do jogo) que dá a variante pedida na noite
local function idFor(want, night, sandbox)
    local c = NOM_VariantRules.config(function(k)
        local v = sandbox[k]
        if v == nil then v = NOM_Config.DEFAULTS[k] end
        return v
    end)
    for seed = 1, 500 do
        local id = 9 * 65536 + seed
        if NOM_VariantRules.variant(id, night, c) == want then return id end
    end
    error("nenhum ID dá " .. tostring(want))
end

return {
    -- solo: o processo simula e decide; grito toca local e chama a horda
    variants_sp_scream_sound_and_call = function()
        local G = setup()
        assert(G.aiReport, "solo não instalou a IA das variantes")
        local z = G.zombie({ id = idFor("corredor", 1, G.sandbox) })
        G.aiReport(z)
        assert(#G.played == 1 and G.played[1].name == "NOM_CorredorScream" and G.played[1].local_)
        assert(#G.sounds == 1 and G.sounds[1].src == z and G.sounds[1].x == 10 and G.sounds[1].y == 10)
    end,
    -- alcance efetivo = CorredorScreamRadius, com a audição apurada da noite (×3) compensada
    variants_scream_reach_is_radius = function()
        local G = setup({ sandbox = { CorredorChance = 100, EstaladorChance = 0, CorredorScreamRadius = 60 } })
        G.aiReport(G.zombie({ id = idFor("corredor", 1, G.sandbox) }))
        assert(G.reach(G.sounds[1]) == 60 and G.sounds[1].volume == 60, "alcance " .. G.reach(G.sounds[1]))
    end,
    -- dedicado: o cliente dono avisa pelo onlineID; o servidor manda o som pros clientes
    variants_mp_command_finds_zombie = function()
        local G = setup({ server = true })
        assert(G.aiReport == nil, "dedicado instalou a IA (quem simula é o cliente)")
        G.zombie({ id = idFor(nil, 1, { CorredorChance = 0, EstaladorChance = 0 }), onlineID = 3 })
        local z = G.zombie({ id = idFor("corredor", 1, G.sandbox), onlineID = 8 })
        G.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 8 })
        assert(#G.played == 1 and G.played[1].src == z and not G.played[1].local_ and G.played[1].loop == false)
        assert(#G.sounds == 1 and G.sounds[1].src == z)
        G.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 99 })
        G.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = "8" })
        G.clientCommand("NevoaEOutroMundo", "corredorSaw", {})
        G.clientCommand("OutroMod", "corredorSaw", { id = 8 })
        assert(#G.played == 1, "comando inválido gritou")
    end,
    -- alvo que pisca não vira sirene: um grito por zumbi a cada meia hora de jogo
    variants_scream_cooldown = function()
        local G = setup({ server = true })
        local z = G.zombie({ id = idFor("corredor", 1, G.sandbox), onlineID = 8 })
        for _ = 1, 5 do G.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 8 }) end
        assert(#G.played == 1, "gritos: " .. #G.played)
        G.hours = G.hours + NOM_VariantRules.SCREAM_COOLDOWN_HOURS
        G.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 8 })
        assert(#G.played == 2 and #G.sounds == 2)
        assert(z.md.NOM_screamAt == G.hours)
    end,
    variants_server_ignores_eco = function()
        local G = setup({ server = true })
        local id = idFor("corredor", 1, G.sandbox)
        G.zombie({ id = id, onlineID = 1, md = { NOM_eco = true } })
        G.zombie({ id = id, onlineID = 2, outfit = "NOM_Eco" })
        G.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 1 })
        G.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 2 })
        assert(#G.played == 0 and #G.sounds == 0, "Eco gritou")
    end,
    -- o servidor não confia no aviso: confere a variante dele, a noite, o toggle e o morto
    variants_server_rejects_non_corredor_and_day = function()
        local G = setup({ server = true, sandbox = { CorredorChance = 50, EstaladorChance = 0 } })
        G.zombie({ id = idFor(nil, 1, G.sandbox), onlineID = 1 })
        local dead = G.zombie({ id = idFor("corredor", 1, G.sandbox), onlineID = 2 })
        dead.dead = true
        G.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 1 })
        G.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 2 })
        assert(#G.played == 0, "zumbi comum ou morto gritou")
        local G2 = setup({ server = true, tod = 12 })
        G2.zombie({ id = idFor("corredor", 1, G2.sandbox), onlineID = 5 })
        G2.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 5 })
        assert(#G2.played == 0, "gritou de dia")
        local sb = { CorredorEnabled = false, CorredorChance = 100, EstaladorChance = 0 }
        local G3 = setup({ server = true, sandbox = sb })
        G3.zombie({ id = idFor("corredor", 1, { CorredorChance = 100, EstaladorChance = 0 }), onlineID = 5 })
        G3.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 5 })
        assert(#G3.played == 0, "toggle desligado gritou")
    end,
    -- o aviso vem do cliente: só vale de quem está perto do Corredor (25 tiles)
    variants_rejects_far_sender = function()
        local G = setup({ server = true })
        G.zombie({ id = idFor("corredor", 1, G.sandbox), onlineID = 8 })
        G.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 8 }, G.player(10, 36))
        assert(#G.played == 0, "jogador a 26 tiles fez o Corredor gritar")
        G.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 8 }, G.player(10, 35))
        assert(#G.played == 1, "jogador a 25 tiles não valeu")
    end,
    -- no máximo um corredorSaw a cada 2 s reais por jogador; outro jogador não é afetado
    variants_rate_limit_per_player = function()
        local G = setup({ server = true })
        G.zombie({ id = idFor("corredor", 1, G.sandbox), onlineID = 8 })
        G.zombie({ id = idFor("corredor", 1, G.sandbox), onlineID = 9 })
        local a, b = G.player(), G.player()
        G.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 99 }, a) -- inválido, mas conta
        G.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 8 }, a, 500)
        assert(#G.played == 0, "passou do limite")
        G.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 8 }, b, 0)
        assert(#G.played == 1, "limite de um jogador travou o outro")
        G.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 9 }, a, 1500)
        assert(#G.played == 2, "não liberou depois de 2 s")
    end,
}
