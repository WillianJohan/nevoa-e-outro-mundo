-- server/NOM_Variants.lua contra um servidor falso que imita o jogo onde importa:
-- * sendPlaySound(nome, loop, objeto): só age no dedicado, manda aos clientes perto
--   (server/Fishing/BuildingObjects/FishingNet.lua:86; bytecode sendToRelative).
-- * no solo o som toca no emitter do personagem (shared/TimedActions/ISDrinkFluidAction.lua:34).
-- * addSound(fonte, x, y, z, raio, volume) (server/Camping/SCampfireSystem.lua:162); o
--   zumbi ouve a raio × getHearingMultiplier (3.0 apurada, a da noite).
-- * getGameTime():getWorldAgeHours() (server/Vehicles/VehicleCommands.lua:240).
-- * OnClientCommand(module, command, player, args) (server/ClientCommands.lua:1296).
-- * modData do zumbi no servidor: o Eco tem NOM_eco (server/NOM_Eco.lua).
-- * Events.OnWorldSound(x, y, z, raio, volume, fonte): todo addSound dispara
--   (WorldSoundManager$WorldSound.init 129–155); som de cliente chega ao servidor como
--   WorldSoundPacket e o processServer 90–139 chama addSound com o jogador de fonte.
-- * IsoZombie.spotted(obj, forçado), setUseless, playSoundLocal (sprint 0011).
-- * character:DistTo(x, y) (client/Vehicles/TimedActions/ISDetachTrailerFromVehicle.lua:34);
--   getTimestampMs() relógio real em ms (server/ISObjectClickHandler.lua:352).
require "NOM_VariantRules"

local FILE = "mod/42/media/lua/server/NOM_Variants.lua"
local NIGHT_FILE = "mod/42/media/lua/server/NOM_Night.lua"
local HEARING_MULT = { 3.0, 1.0, 0.45 }

local function setup(opts)
    opts = opts or {}
    local G = { zombies = {}, sounds = {}, played = {}, hours = 100, world = { tod = opts.tod or 23 },
        globalMD = opts.globalMD or {}, aiReport = nil, ms = 0, sent = {} }
    local handlers = {}
    local function fire(name, ...)
        for _, h in ipairs(handlers[name] or {}) do h(...) end
    end
    G.sandbox = opts.sandbox or { CorredorChance = 100, EstaladorChance = 0 }
    function G.zombie(o)
        local z = { x = o.x or 10, y = o.y or 10, z = o.z or 0, md = o.md or {}, id = o.id, onlineID = o.onlineID or 7,
            outfitName = o.outfit, dead = false, class = "IsoZombie", local_ = {}, calls = 0 }
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
        function z:playSoundLocal(name) self.local_[#self.local_ + 1] = name; return 1 end
        function z:isRemoteZombie() return false end
        function z:setUseless(b) self.useless = b end
        function z:spotted(p, forced) if not self.useless then self.target, self.forced = p, forced end end
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
        G.worldSound(x, y, z, radius, volume, src)
    end
    function G.worldSound(x, y, z, radius, volume, src) fire("OnWorldSound", x, y, z, radius, volume, src) end
    instanceof = function(o, cls) return type(o) == "table" and o.class == cls end
    sendPlaySound = function(name, loop, obj)
        if not isServer() then return end -- bytecode: só no GameServer
        G.played[#G.played + 1] = { name = name, src = obj, loop = loop }
    end
    sendServerCommand = function(a, b, c, d)
        if d == nil then G.sent[#G.sent + 1] = { module = a, command = b, args = c }
        else G.sent[#G.sent + 1] = { player = a, module = b, command = c, args = d } end
    end
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
    for _, m in ipairs({ "NOM_World", "NOM_NightStats", "NOM_Players", "NOM_NightCount", "NOM_Night", "NOM_VariantAI",
        "NOM_FogState", "NOM_SemRosto", "NOM_Fog", "NOM_FogEvent", "NOM_FogEventRules", "NOM_Siren",
        "NOM_Carpideira", "NOM_CarpideiraRules" }) do
        _G[m] = nil
        package.loaded[m] = nil
    end
    require "NOM_NightStats"
    NOM_NightStats.install = function() end
    require "NOM_VariantAI"
    NOM_VariantAI.install = function(fn) G.aiReport = fn end
    require "NOM_Carpideira"
    NOM_Carpideira.install = function(fn) G.carpReport = fn end
    dofile(NIGHT_FILE)
    package.loaded["NOM_Night"] = NOM_Night
    dofile(FILE)
    -- névoa forte por padrão: o Corredor só existe na névoa (Johan, 05/10)
    G.fog = opts.fog or 0.9
    function G.setTime(tod)
        G.world.tod = tod
        NOM_World.update()
        -- névoa é evento (NOM_FogEvent, ADR-009): o estado salvo abre pela regra
        -- do evento (período novo) e a flag vai pro NOM_World
        local md = ModData.getOrCreate("NevoaEOutroMundo")
        md.fog = md.fog or {}
        if G.fog >= 0.5 then
            NOM_FogEventRules.start(md.fog, G.hours, { minHours = 2, maxHours = 6 }, function() return 0 end)
        else
            md.fog.inNight = false
        end
        NOM_World.setFog(G.fog >= 0.5)
    end
    -- jogador que manda o comando: perto do zumbi (10, 10) por padrão
    function G.player(x, y)
        G.nextPlayer = (G.nextPlayer or 50) + 1
        local p = { x = x or 12, y = y or 10, z = 0, class = "IsoPlayer", onlineID = G.nextPlayer }
        function p:DistTo(tx, ty) return math.sqrt((self.x - tx) ^ 2 + (self.y - ty) ^ 2) end
        function p:getX() return self.x end
        function p:getY() return self.y end
        function p:getZ() return self.z end
        function p:getOnlineID() return self.onlineID end
        function p:getActiveLightItem() if self.light then return {} end return nil end
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
    function G.commandsSent(command)
        local out = {}
        for _, c in ipairs(G.sent) do if c.command == command then out[#out + 1] = c end end
        return out
    end
    G.setTime(G.world.tod)
    return G
end

-- sandbox em que todo zumbi sorteado é Carpideira (os outros tipos zerados)
local CARP = { CarpideiraChance = 100, EstaladorChance = 0, CorredorChance = 0, SemRostoChance = 0 }

-- ID (formato do jogo) que dá a variante pedida no período de névoa (except: pula esse)
local function idFor(want, night, sandbox, except)
    local c = NOM_VariantRules.config(function(k)
        local v = sandbox[k]
        if v == nil then v = NOM_Config.DEFAULTS[k] end
        return v
    end)
    for seed = 1, 500 do
        local id = 9 * 65536 + seed
        if id ~= except and NOM_VariantRules.variant(id, night, c) == want then return id end
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
    -- o servidor não confia no aviso: confere a variante dele, a névoa, o toggle e o morto
    variants_server_rejects_non_corredor_and_day = function()
        local G = setup({ server = true, sandbox = { CorredorChance = 50, EstaladorChance = 0 } })
        G.zombie({ id = idFor(nil, 1, G.sandbox), onlineID = 1 })
        local dead = G.zombie({ id = idFor("corredor", 1, G.sandbox), onlineID = 2 })
        dead.dead = true
        G.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 1 })
        G.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 2 })
        assert(#G.played == 0, "zumbi comum ou morto gritou")
        local G2 = setup({ server = true, fog = 0 })
        G2.zombie({ id = idFor("corredor", 1, G2.sandbox), onlineID = 5 })
        G2.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 5 })
        assert(#G2.played == 0, "gritou sem névoa")
        local sb = { CorredorEnabled = false, CorredorChance = 100, EstaladorChance = 0 }
        local G3 = setup({ server = true, sandbox = sb })
        G3.zombie({ id = idFor("corredor", 1, { CorredorChance = 100, EstaladorChance = 0 }), onlineID = 5 })
        G3.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 5 })
        assert(#G3.played == 0, "toggle desligado gritou")
    end,
    -- de dia na névoa ele grita, e o alcance é o configurado sem a compensação da
    -- audição da noite (de dia ninguém tem o degrau a mais)
    variants_scream_by_day_in_fog = function()
        local G = setup({ server = true, tod = 12, sandbox = { CorredorChance = 100, EstaladorChance = 0, CorredorScreamRadius = 60 } })
        G.zombie({ id = idFor("corredor", 1, G.sandbox), onlineID = 8 })
        G.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 8 })
        assert(#G.played == 1, "não gritou de dia na névoa")
        assert(G.sounds[1].radius == 60, "raio de dia " .. G.sounds[1].radius)
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
    -- névoa vermelha: o servidor reconhece o Corredor da divisão da vermelha, mesmo
    -- com CorredorChance 0
    variants_red_fog_corredor_screams = function()
        local sb = { CorredorChance = 0, EstaladorChance = 0, SemRostoChance = 0 }
        local G = setup({ server = true, sandbox = sb })
        local c = NOM_VariantRules.config(function(k) local v = sb[k]; if v == nil then v = NOM_Config.DEFAULTS[k] end return v end)
        local id
        for seed = 1, 500 do
            id = 9 * 65536 + seed
            if NOM_VariantRules.variant(id, 1, c, true) == "corredor" then break end
        end
        G.zombie({ id = id, onlineID = 3 })
        G.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 3 })
        assert(#G.played == 0, "gritou na névoa normal com chance 0")
        NOM_World.setFog(true, true)
        G.clientCommand("NevoaEOutroMundo", "corredorSaw", { id = 3 })
        assert(#G.played == 1, "Corredor da vermelha não gritou")
    end,

    -- Carpideira (sprint 0011) ---------------------------------------------------

    -- solo: o processo vê, avisa e decide. Grito local, horda chamada com o alcance
    -- compensado (CarpideiraScreamRadius), solta e caça quem acordou; um por névoa.
    carpideira_sp_scream_once_per_period = function()
        local G = setup({ sandbox = CARP })
        assert(G.carpReport, "solo não instalou a varredura da Carpideira")
        local z = G.zombie({ id = idFor("carpideira", 1, CARP) })
        z.useless = true -- calma (NOM_Carpideira.hold)
        NOM_Carpideira.still[z] = true
        local p = G.player(12, 10)
        G.carpReport(z, p, "near")
        assert(z.local_[1] == "NOM_CarpideiraScream", "grito não tocou")
        assert(#G.sounds == 1 and G.sounds[1].src == z and G.reach(G.sounds[1]) == 60, "horda não chamada a 60")
        assert(z.useless == false and z.target == p and z.forced == true, "não caçou quem a acordou")
        G.carpReport(z, p, "near")
        assert(#z.local_ == 1 and #G.sounds == 1, "gritou duas vezes na mesma névoa")
        -- névoa seguinte: outro período, ela pode gritar de novo (se ainda for Carpideira)
        G.fog = 0
        G.setTime(23)
        G.fog = 0.9
        G.setTime(23)
        if NOM_VariantRules.variant(z.id, NOM_Fog.period(), NOM_VariantRules.config(function(k)
            local v = CARP[k]; if v == nil then v = NOM_Config.DEFAULTS[k] end return v end)) == "carpideira" then
            G.carpReport(z, p, "near")
            assert(#z.local_ == 2, "não gritou na névoa seguinte")
        end
    end,
    -- salvar e carregar no meio da névoa não deixa gritar de novo (ModData)
    carpideira_scream_survives_reload = function()
        local G = setup({ sandbox = CARP })
        local z = G.zombie({ id = idFor("carpideira", 1, CARP) })
        G.carpReport(z, G.player(12, 10), "near")
        assert(#G.sounds == 1)
        dofile(FILE) -- o Lua do servidor recomeça; o ModData global é o mesmo
        G.carpReport(z, G.player(12, 10), "near")
        assert(#G.sounds == 1, "gritou de novo depois de recarregar")
    end,
    -- dedicado: o aviso do cliente é conferido (variante, névoa, distância com folga,
    -- andar, lanterna acesa, Eco, morto, motivo) e o grito vai pra todos os clientes
    carpideira_mp_validates_report = function()
        local G = setup({ server = true, sandbox = CARP })
        local id = idFor("carpideira", 1, CARP)
        G.zombie({ id = id, onlineID = 2, outfit = "NOM_Eco" })
        local dead = G.zombie({ id = id, onlineID = 3 })
        dead.dead = true
        local far = G.zombie({ id = id, onlineID = 4, x = 10, y = 10 })
        local function woke(onlineID, why, p) G.clientCommand("NevoaEOutroMundo", "carpideiraWoke", { id = onlineID, why = why }, p) end
        local function screams() return G.commandsSent("carpideiraScream") end
        woke(2, "near", G.player(11, 10))
        woke(3, "near", G.player(11, 10))
        woke(4, "noise", G.player(11, 10))
        woke(4, "near", G.player(10, 17.5)) -- 7 tiles: além de 4 + folga 2
        local up = G.player(11, 10); up.z = 1
        woke(4, "near", up)
        woke(4, "light", G.player(10, 19)) -- lanterna apagada
        assert(#screams() == 0, "aviso inválido gritou: " .. (screams()[1] and tostring(screams()[1].args.id) or ""))
        local p = G.player(10, 15.5) -- 5 tiles: dentro de 4 + folga
        woke(4, "near", p)
        local s = screams()
        assert(#s == 1 and s[1].args.pid == id and s[1].args.id == 4 and s[1].args.pl == p.onlineID and s[1].player == nil)
        assert(#G.sounds == 1 and G.sounds[1].src == far, "horda não chamada")
        -- lanterna acesa a 9 tiles vale (outra Carpideira, outro ID)
        local id2 = idFor("carpideira", 1, CARP, id)
        G.zombie({ id = id2, onlineID = 5, x = 10, y = 10 })
        local lit = G.player(10, 19); lit.light = true
        woke(5, "light", lit)
        assert(#screams() == 2, "lanterna acesa não valeu")
        -- zumbi que não é Carpideira (metade é, com 50%)
        local half = { CarpideiraChance = 50, EstaladorChance = 0, CorredorChance = 0, SemRostoChance = 0 }
        local G1 = setup({ server = true, sandbox = half })
        G1.zombie({ id = idFor(nil, 1, half), onlineID = 1 })
        G1.clientCommand("NevoaEOutroMundo", "carpideiraWoke", { id = 1, why = "near" }, G1.player(11, 10))
        assert(#G1.commandsSent("carpideiraScream") == 0, "zumbi comum gritou")
        -- sem névoa, nada
        local G2 = setup({ server = true, sandbox = CARP, fog = 0 })
        G2.zombie({ id = id, onlineID = 4 })
        G2.clientCommand("NevoaEOutroMundo", "carpideiraWoke", { id = 4, why = "near" }, G2.player(11, 10))
        assert(#G2.commandsSent("carpideiraScream") == 0, "gritou sem névoa")
    end,
    -- um aviso por jogador a cada RATE_MS reais (contando os inválidos); outro jogador livre
    carpideira_rate_limit_per_player = function()
        local G = setup({ server = true, sandbox = CARP })
        local id = idFor("carpideira", 1, CARP)
        G.zombie({ id = id, onlineID = 4 })
        G.zombie({ id = idFor("carpideira", 1, CARP, id), onlineID = 5 })
        local a, b = G.player(11, 10), G.player(11, 10)
        G.clientCommand("NevoaEOutroMundo", "carpideiraWoke", { id = 99, why = "near" }, a)
        G.clientCommand("NevoaEOutroMundo", "carpideiraWoke", { id = 4, why = "near" }, a, 500)
        assert(#G.commandsSent("carpideiraScream") == 0, "passou do limite")
        G.clientCommand("NevoaEOutroMundo", "carpideiraWoke", { id = 4, why = "near" }, b, 0)
        assert(#G.commandsSent("carpideiraScream") == 1, "limite de um travou o outro")
        G.clientCommand("NevoaEOutroMundo", "carpideiraWoke", { id = 5, why = "near" }, a, NOM_CarpideiraRules.RATE_MS)
        assert(#G.commandsSent("carpideiraScream") == 2, "não liberou depois do intervalo")
    end,
    -- barulho: o servidor ouve sozinho (OnWorldSound). Tiro perto acorda e ela caça
    -- quem atirou; longe, baixo, de zumbi ou chamado do próprio mod (caça) não
    carpideira_noise_wakes = function()
        local id = idFor("carpideira", 1, CARP)
        local G = setup({ sandbox = CARP })
        local z = G.zombie({ id = id })
        local shooter = G.player(15, 10)
        G.worldSound(15, 10, 0, 60, 60, shooter)
        assert(#z.local_ == 1 and z.target == shooter, "tiro a 5 tiles não acordou")
        for _, case in ipairs({
            { x = 25, r = 150, why = "tiro a 15 tiles" },
            { x = 13, r = 20, why = "tarefa barulhenta (raio 20)" },
        }) do
            local G2 = setup({ sandbox = CARP })
            local z2 = G2.zombie({ id = id })
            G2.worldSound(case.x, 10, 0, case.r, case.r, G2.player(case.x, 10))
            assert(#z2.local_ == 0, case.why .. " acordou")
        end
        local G3 = setup({ sandbox = CARP })
        local z3 = G3.zombie({ id = id })
        local other = G3.zombie({ id = id + 1, x = 30 })
        G3.worldSound(12, 10, 0, 60, 60, other) -- fonte zumbi (ex.: grito do Corredor)
        NOM_Night.call(G3.player(12, 10), 30) -- caça da noite: addSound com o jogador de fonte
        assert(#z3.local_ == 0, "chamado do mod ou barulho de zumbi acordou")
        local G4 = setup({ sandbox = CARP })
        local z4 = G4.zombie({ id = id, z = 1 })
        G4.worldSound(12, 10, 0, 60, 60, G4.player(12, 10))
        assert(#z4.local_ == 0, "tiro do andar de baixo acordou")
    end,
    -- orçamento: cada barulho alto dá uma volta na lista com 1 chamada por zumbi comum
    carpideira_noise_scan_one_call_per_common_zombie = function()
        local G = setup({ sandbox = { CarpideiraChance = 0, EstaladorChance = 0, CorredorChance = 0, SemRostoChance = 0 } })
        local commons = {}
        for i = 1, 300 do
            local z = G.zombie({ id = 9 * 65536 + i, x = i, y = 10 })
            local real = z.getPersistentOutfitID
            for k, v in pairs(z) do
                if type(v) == "function" then z[k] = function(...) z.calls = z.calls + 1; return v(...) end end
            end
            commons[i] = z
        end
        G.worldSound(50, 10, 0, 100, 100, G.player(50, 10))
        for _, z in ipairs(commons) do assert(z.calls <= 1, "chamadas: " .. z.calls) end
        -- barulho baixo nem dá a volta
        for _, z in ipairs(commons) do z.calls = 0 end
        G.worldSound(50, 10, 0, 10, 10, G.player(50, 10))
        for _, z in ipairs(commons) do assert(z.calls == 0) end
    end,
    -- quem entra no meio da névoa recebe quem já gritou
    carpideira_joiner_gets_list = function()
        local G = setup({ server = true, sandbox = CARP })
        local id = idFor("carpideira", 1, CARP)
        G.zombie({ id = id, onlineID = 4 })
        G.clientCommand("NevoaEOutroMundo", "carpideiraWoke", { id = 4, why = "near" }, G.player(11, 10))
        local joiner = G.player(80, 80)
        G.clientCommand("NevoaEOutroMundo", "fogState", {}, joiner)
        local l = G.commandsSent("carpideiraList")
        assert(#l == 1 and l[1].player == joiner and l[1].args.pids[1] == id, "lista não foi pra quem entrou")
        -- ninguém gritou: nada a mandar
        local G2 = setup({ server = true, sandbox = CARP })
        G2.clientCommand("NevoaEOutroMundo", "fogState", {}, G2.player(80, 80))
        assert(#G2.commandsSent("carpideiraList") == 0)
    end,
}
