-- server/NOM_Night.lua contra um servidor falso que imita o jogo onde importa:
-- * addSound(fonte, x, y, z, raio, volume) global (server/Camping/SCampfireSystem.lua:162);
--   no dedicado o jogo repassa aos clientes (WorldSoundManager.addSound → sendWorldSound).
-- * getActiveLightItem(): item na mão ou preso que emite luz, senão nil (bytecode IsoPlayer).
-- * square:isOutside() (server/Farming/SFarmingSystem.lua:156).
-- * EveryOneMinute uma vez por minuto de jogo; a noite vem do NOM_World (borda).
-- * quem ouve: o zumbi reage se a distância ≤ raio × getHearingMultiplier(zumbi)
--   (WorldSoundManager.getSoundAttract), 3.0 / 1.0 / 0.45 pelo degrau de audição.
--   opts.zombieHearing = degrau dos zumbis em volta (à noite, o que o NOM_NightStats
--   aplica: test_night_stats cobre).
local HEARING_MULT = { 3.0, 1.0, 0.45 }
local FILE = "mod/42/media/lua/server/NOM_Night.lua"

local function setup(opts)
    opts = opts or {}
    local G = { sounds = {}, sent = {}, world = { tod = opts.tod or 12 }, installed = 0,
        zombieHearing = opts.zombieHearing or 2, loreHearing = opts.loreHearing or 2 }
    -- alcance real do som pros zumbis em volta
    function G.reach(s) return s.radius * HEARING_MULT[G.zombieHearing] end
    G.players = opts.players or { { x = 100, y = 100, z = 0 } }
    local handlers = {}
    local function fire(name, ...)
        for _, h in ipairs(handlers[name] or {}) do h(...) end
    end
    local function player(p)
        return {
            data = p,
            getX = function() return p.x + 0.5 end,
            getY = function() return p.y + 0.5 end,
            getZ = function() return p.z end,
            isDead = function() return p.dead == true end,
            getActiveLightItem = function() return p.light and {} or nil end,
            getCurrentSquare = function()
                return { isOutside = function() return p.outside ~= false end }
            end,
        }
    end
    isClient = function() return false end
    isServer = function() return opts.server == true end
    getDebug = function() return false end
    SandboxVars = { NevoaEOutroMundo = opts.sandbox or {} }
    G.globalMD = opts.globalMD or {}
    ModData = {
        getOrCreate = function(name)
            G.globalMD[name] = G.globalMD[name] or {}
            return G.globalMD[name]
        end,
    }
    getNumActivePlayers = function() return #G.players end
    getSpecificPlayer = function(i) return player(G.players[i + 1]) end
    getOnlinePlayers = function()
        local l = { items = {} }
        for _, p in ipairs(G.players) do l.items[#l.items + 1] = player(p) end
        function l:size() return #self.items end
        function l:get(i) return self.items[i + 1] end
        return l
    end
    addSound = function(src, x, y, z, radius, volume)
        G.sounds[#G.sounds + 1] = { src = src, x = x, y = y, z = z, radius = radius, volume = volume }
    end
    sendServerCommand = function(a, b, c, d)
        if d == nil then
            G.sent[#G.sent + 1] = { module = a, command = b, args = c }
        else
            G.sent[#G.sent + 1] = { player = a, module = b, command = c, args = d }
        end
    end
    getGameTime = function()
        return { getTimeOfDay = function() return G.world.tod end, getWorldAgeHours = function() return G.world.tod end }
    end
    getSandboxOptions = function()
        return {
            getOptionByName = function(_, name)
                assert(name == "ZombieLore.Hearing", "opção inesperada: " .. name)
                return { getValue = function() return G.loreHearing end }
            end,
        }
    end
    getClimateManager = function()
        return { getSeason = function() return { getDawn = function() return 6 end, getDusk = function() return 21 end } end }
    end
    Events = setmetatable({}, {
        __index = function(t, name)
            local e = { Add = function(f) handlers[name] = handlers[name] or {}; table.insert(handlers[name], f) end }
            rawset(t, name, e)
            return e
        end,
    })
    for _, m in ipairs({ "NOM_World", "NOM_NightStats", "NOM_Players", "NOM_NightCount" }) do
        _G[m] = nil
        package.loaded[m] = nil
    end
    require "NOM_NightStats"
    NOM_NightStats.install = function() G.installed = G.installed + 1 end
    package.loaded["NOM_NightStats"] = NOM_NightStats
    dofile(FILE)
    -- o ClimateLook atualiza o NOM_World no OnClimateTick; os outros arquivos do
    -- servidor rodam depois dele na mesma volta
    function G.setTime(tod)
        G.world.tod = tod
        NOM_World.update(0)
        fire("OnClimateTick")
    end
    function G.minutes(n)
        for _ = 1, n do fire("EveryOneMinute") end
    end
    function G.clientCommand(module, command, p, args) fire("OnClientCommand", module, command, p, args) end
    function G.soundsReaching(reach)
        local n = 0
        for _, s in ipairs(G.sounds) do if G.reach(s) == reach then n = n + 1 end end
        return n
    end
    G.setTime(G.world.tod)
    return G
end

return {
    -- solo: este processo simula os zumbis e aplica
    night_sp_drives_stats = function()
        local G = setup()
        assert(G.installed == 1, "solo não instalou o aplicador")
        assert(NOM_NightStats.night == false)
        G.setTime(22)
        assert(NOM_NightStats.night == true)
        G.setTime(7)
        assert(NOM_NightStats.night == false)
        assert(#G.sent == 0, "solo mandou comando de rede")
    end,
    -- dedicado: quem simula é o cliente dono; o servidor só avisa, na borda
    night_mp_broadcasts_edge_only = function()
        local G = setup({ server = true })
        assert(G.installed == 0, "dedicado aplicou stats")
        G.setTime(22)
        G.setTime(23)
        G.setTime(7)
        assert(#G.sent == 2, "avisos: " .. #G.sent)
        assert(G.sent[1].module == "NevoaEOutroMundo" and G.sent[1].command == "night" and G.sent[1].args.on == true)
        assert(G.sent[2].args.on == false)
        assert(NOM_NightStats.night == false)
    end,
    -- calmaria (sprint 0033): dedicado avisa na borda, o cliente dono aplica
    night_mp_broadcasts_calm = function()
        local G = setup({ server = true })
        G.sent = {}
        NOM_World.setCalm(true)
        assert(#G.sent == 1, "avisos: " .. #G.sent)
        assert(G.sent[1].module == "NevoaEOutroMundo" and G.sent[1].command == "calm" and G.sent[1].args.on == true)
        NOM_World.setCalm(true) -- sem borda, sem aviso
        assert(#G.sent == 1)
        NOM_World.setCalm(false)
        assert(#G.sent == 2 and G.sent[2].command == "calm" and G.sent[2].args.on == false)
        assert(NOM_NightStats.calm == false, "dedicado aplicou stats")
    end,
    -- solo: este processo simula e aplica, sem rede
    night_sp_applies_calm = function()
        local G = setup()
        NOM_World.setCalm(true)
        assert(NOM_NightStats.calm == true)
        NOM_World.setCalm(false)
        assert(NOM_NightStats.calm == false)
        assert(#G.sent == 0, "solo mandou comando de rede")
    end,
    -- cliente que entra no meio da calmaria não viu a borda: o nightState responde com ela
    night_state_includes_calm = function()
        local G = setup({ server = true, tod = 23 })
        NOM_World.setCalm(true)
        G.sent = {}
        local who = {}
        G.clientCommand("NevoaEOutroMundo", "nightState", who, {})
        assert(#G.sent == 2, "respostas: " .. #G.sent)
        assert(G.sent[1].command == "night" and G.sent[1].player == who)
        assert(G.sent[2].command == "calm" and G.sent[2].player == who and G.sent[2].args.on == true)
        NOM_World.setCalm(false)
        G.sent = {}
        G.clientCommand("NevoaEOutroMundo", "nightState", who, {})
        assert(G.sent[2].args.on == false)
    end,
    -- o número da noite viaja com a flag: o cliente sorteia as variantes igual ao servidor
    night_mp_sends_night_number = function()
        local G = setup({ server = true })
        G.setTime(22)
        G.setTime(7)
        G.setTime(23)
        assert(G.sent[1].args.night == 1 and G.sent[3].args.night == 2, "noite: " .. tostring(G.sent[3].args.night))
        G.sent = {}
        G.clientCommand("NevoaEOutroMundo", "nightState", {}, {})
        assert(G.sent[1].args.on == true and G.sent[1].args.night == 2)
    end,
    -- o contador é o mesmo do Eco (ModData salvo): reiniciar no meio da noite não abre noite nova
    night_number_survives_restart = function()
        local G = setup({ tod = 23 })
        assert(NOM_NightStats.nightNumber == 1)
        local G2 = setup({ tod = 23, globalMD = G.globalMD })
        assert(NOM_NightStats.nightNumber == 1, "reinício abriu noite nova")
        assert(G2.globalMD.NevoaEOutroMundo.eco.night == 1)
    end,
    night_sp_passes_night_number = function()
        local G = setup()
        G.setTime(22)
        assert(NOM_NightStats.nightNumber == 1)
        G.setTime(7)
        G.setTime(22)
        assert(NOM_NightStats.nightNumber == 2)
    end,
    -- cliente que entra no meio da noite pergunta e recebe só pra ele
    night_mp_replies_state_to_client = function()
        local G = setup({ server = true, tod = 23 })
        G.sent = {}
        local who = {}
        G.clientCommand("NevoaEOutroMundo", "nightState", who, {})
        G.clientCommand("OutroMod", "nightState", who, {})
        -- noite e calmaria, as duas só pra ele
        assert(#G.sent == 2 and G.sent[1].player == who and G.sent[1].command == "night" and G.sent[1].args.on == true)
        assert(G.sent[2].player == who and G.sent[2].command == "calm" and G.sent[2].args.on == false)
    end,
    hunt_every_interval_at_night = function()
        local G = setup({ tod = 23, sandbox = { HuntIntervalMinutes = 30, HuntRadius = 25, NightSharperSenses = false },
            players = { { x = 100, y = 100, z = 0 }, { x = 300, y = 300, z = 1 }, { x = 5, y = 5, z = 0, dead = true } } })
        G.minutes(29)
        assert(#G.sounds == 0)
        G.minutes(1)
        assert(#G.sounds == 2, "chamados: " .. #G.sounds)
        local s = G.sounds[1]
        assert(s.x == 100 and s.y == 100 and s.z == 0 and s.radius == 25 and s.volume == 25)
        assert(G.sounds[2].x == 300 and G.sounds[2].z == 1)
        G.minutes(30)
        assert(#G.sounds == 4)
    end,
    hunt_resets_by_day_and_toggle = function()
        local G = setup({ tod = 23, sandbox = { HuntIntervalMinutes = 30, NightSharperSenses = false } })
        G.minutes(20)
        G.setTime(12)
        G.minutes(60)
        assert(#G.sounds == 0, "caçou de dia")
        G.setTime(23)
        G.minutes(29)
        assert(#G.sounds == 0, "contador não zerou no dia")
        G.minutes(1)
        assert(#G.sounds == 1)
        local G2 = setup({ tod = 23, sandbox = { NightHunt = false, NightSharperSenses = false } })
        G2.minutes(200)
        assert(#G2.sounds == 0, "caça desligada caçou")
    end,
    -- alcance efetivo = HuntRadius, mesmo com a audição apurada da noite (×3)
    hunt_effective_reach_is_hunt_radius = function()
        local G = setup({ tod = 23, zombieHearing = 1, sandbox = { HuntIntervalMinutes = 10, HuntRadius = 30 } })
        G.minutes(10)
        local hunts = {}
        for _, s in ipairs(G.sounds) do if s.x == 100 then hunts[#hunts + 1] = s end end
        assert(#hunts == 1 and G.reach(hunts[1]) == 30, "alcance: " .. G.reach(hunts[1]))
        -- sentidos desligados: zumbi com a audição do dia, raio passa direto
        local G2 = setup({ tod = 23, zombieHearing = 2,
            sandbox = { HuntIntervalMinutes = 10, HuntRadius = 30, NightSharperSenses = false } })
        G2.minutes(10)
        assert(#G2.sounds == 1 and G2.reach(G2.sounds[1]) == 30)
        -- raio que não divide por 3: arredonda, erro de no máximo 1.5 tile
        local G3 = setup({ tod = 23, zombieHearing = 1, sandbox = { HuntIntervalMinutes = 10, HuntRadius = 25, NightHunt = true } })
        G3.minutes(10)
        assert(math.abs(G3.reach(G3.sounds[1]) - 25) <= 1.5)
    end,
    -- getSoundAttract devolve volume × queda: volume = alcance configurado, só o raio é dividido,
    -- pra caça e lanterna não perderem pra som vanilla mais alto
    sound_volume_is_configured_reach = function()
        local G = setup({ tod = 23, zombieHearing = 1, sandbox = { HuntIntervalMinutes = 10, HuntRadius = 30, NightHunt = true },
            players = { { x = 10, y = 20, z = 0, light = true } } })
        G.minutes(10)
        assert(#G.sounds == 3, "sons: " .. #G.sounds)
        for _, s in ipairs(G.sounds) do
            assert(s.volume == 30 and s.radius == 10, "raio " .. s.radius .. " volume " .. s.volume)
        end
    end,
    -- lanterna ligada ao ar livre à noite: alcance de 20 × NightSenseMult, a cada 5 minutos
    torch_outside_at_night_attracts = function()
        local G = setup({ tod = 23, zombieHearing = 1, sandbox = { NightHunt = false },
            players = { { x = 10, y = 20, z = 0, light = true } } })
        G.minutes(4)
        assert(#G.sounds == 0, "farol antes de 5 minutos")
        G.minutes(6)
        assert(#G.sounds == 2 and G.soundsReaching(30) == 2, "farol: " .. #G.sounds)
        assert(G.sounds[1].x == 10 and G.sounds[1].y == 20)
    end,
    torch_needs_outside_light_night_and_toggle = function()
        local cases = {
            { tod = 23, p = { x = 1, y = 1, z = 0, light = true, outside = false } },
            { tod = 23, p = { x = 1, y = 1, z = 0, light = false } },
            { tod = 12, p = { x = 1, y = 1, z = 0, light = true } },
            { tod = 23, p = { x = 1, y = 1, z = 0, light = true }, sandbox = { NightSharperSenses = false } },
        }
        for i, c in ipairs(cases) do
            local sb = c.sandbox or {}
            sb.NightHunt = false
            local G = setup({ tod = c.tod, players = { c.p }, sandbox = sb })
            G.minutes(20)
            assert(#G.sounds == 0, "caso " .. i .. " atraiu")
        end
    end,
    -- save com a noite aberta carregado de dia: a primeira leitura fecha a noite,
    -- e a seguinte é outra (senão as variantes repetiriam o sorteio da velha)
    night_number_closes_stale_after_reload = function()
        local md = { NevoaEOutroMundo = { eco = { night = 3, inNight = true } } }
        local G = setup({ tod = 12, globalMD = md })
        assert(md.NevoaEOutroMundo.eco.inNight == false, "noite velha ficou aberta")
        G.setTime(22)
        assert(NOM_NightStats.nightNumber == 4, "noite nova com o número da velha: " .. tostring(NOM_NightStats.nightNumber))
    end,
    -- caça do Tição (sprint 0038): na preta, de dia também, a cada HUNT_MINUTES, alcance HUNT_REACH
    -- pra quem ouve como o Tição (audição apurada); fora da preta, nada
    hunt_ticao_in_black_fog = function()
        local G = setup({ tod = 12, zombieHearing = 1, sandbox = { NightHunt = false } })
        NOM_World.setFog(true, false, true)
        G.minutes(NOM_TicaoRules.HUNT_MINUTES - 1)
        assert(#G.sounds == 0, "caçou antes da hora")
        G.minutes(1)
        assert(#G.sounds == 1 and G.sounds[1].x == 100, "chamados: " .. #G.sounds)
        assert(math.abs(G.reach(G.sounds[1]) - NOM_TicaoRules.HUNT_REACH) <= 1.5, "alcance " .. G.reach(G.sounds[1]))
        NOM_World.setFog(true, false, false)
        G.minutes(NOM_TicaoRules.HUNT_MINUTES * 3)
        assert(#G.sounds == 1, "caçou fora da preta")
    end,
}
