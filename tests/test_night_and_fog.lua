-- Noite + névoa ao mesmo tempo, no solo (o processo é servidor, dono e quem vê):
-- server/NOM_Night.lua, server/NOM_Variants.lua e server/NOM_Fog.lua carregados
-- juntos, mais o som, a vinheta e os overlays do cliente, no mundo falso de
-- tests/fog_world.lua. O zumbi falso ganha o que o NOM_NightStats e o
-- NOM_VariantAI usam (stats como em test_night_stats, alvo/useless como em
-- test_variant_ai): o sorteio da noite e o da névoa rodam de verdade.
local W = dofile("tests/fog_world.lua")

local function setup()
    local G = W.new({ tod = 12, sandbox = { EstaladorChance = 100, CorredorChance = 0 } })
    G.reload({ "NOM_World", "NOM_FogState", "NOM_Fog", "NOM_SemRosto", "NOM_NightStats", "NOM_Night", "NOM_Players",
        "NOM_NightCount", "NOM_VariantAI", "NOM_Variants", "NOM_FogSound", "NOM_FogVignette", "NOM_FogOverlays" })
    local lore = { Speed = 2, Sight = 2, Hearing = 2, Cognition = 2, Memory = 2 }
    getSandboxOptions = function()
        return { getOptionByName = function(_, name)
            local short = name:match("^ZombieLore%.(%w+)$")
            return { getValue = function() return lore[short] end, setValue = function(_, v) lore[short] = v end }
        end }
    end
    local gt = getGameTime
    getGameTime = function()
        local t = gt()
        t.getWorldAgeHours = function() return G.now / 3600000 end
        t.isZombieInactivityPhase = function() return false end
        return t
    end
    G.addSounds = {}
    addSound = function(...) G.addSounds[#G.addSounds + 1] = { ... } end
    instanceof = function(o, cls) return o.class == cls end
    G.enabled = {}
    getSearchMode = function()
        local function f() return { setTargets = function() end } end
        return {
            setEnabled = function(_, pn, b) G.enabled[pn] = b end,
            isEnabled = function(_, pn) return G.enabled[pn] == true end,
            getSearchModeForPlayer = function()
                return { getBlur = f, getDesat = f, getRadius = f, getDarkness = f, getGradientWidth = f }
            end,
        }
    end
    local managers = {}
    ISSearchManager = { getManager = function(p)
        managers[p] = managers[p] or { isOverride = false, isSearchMode = false }
        return managers[p]
    end }
    G.markers = 0
    getIsoMarkers = function()
        return { addIsoMarker = function()
            G.markers = G.markers + 1
            return { setAlpha = function() end, remove = function() end }
        end }
    end
    getTexture = function(name) return { name = name } end
    local seed = 99
    ZombRand = function(n)
        seed = (seed * 1103515245 + 12345) % 2147483648
        return math.floor(seed / 65536) % n
    end

    dofile("mod/42/media/lua/server/NOM_Night.lua")
    dofile("mod/42/media/lua/server/NOM_Variants.lua")
    dofile("mod/42/media/lua/server/NOM_Fog.lua")
    dofile("mod/42/media/lua/client/NOM_FogSound.lua")
    dofile("mod/42/media/lua/client/NOM_FogVignette.lua")
    dofile("mod/42/media/lua/client/NOM_FogOverlays.lua")

    -- zumbi falso com stats e alvo
    function G.monster(o)
        local z = G.zombie(o)
        z.class, z.speedType, z.useless = "IsoZombie", 2, false
        function z:getSpeedType() return self.speedType end
        function z:isCrawling() return false end
        function z:isCanCrawlUnderVehicle() return true end
        function z:setCanCrawlUnderVehicle() end
        function z:DoZombieStats() self.sight, self.hearing = lore.Sight, lore.Hearing end
        function z:doZombieSpeed(t) if t and t ~= -1 then self.speedType = t end end
        function z:getTarget() return self.target end
        function z:setTarget(t) self.target = t end
        function z:isUseless() return self.useless end
        function z:setUseless(b) self.useless = b end
        function z:getEmitter() return { playSound = function() end } end
        return z
    end
    -- um frame: o spot do jogo põe o alvo, depois OnZombieUpdate e o tick
    function G.frame(n)
        for _ = 1, n or 1 do
            for _, z in ipairs(G.zombies) do
                if z.class and not z.useless and z.spotted then z.target = z.spotted end
                G.fire("OnZombieUpdate", z)
            end
            G.tick(1)
        end
    end
    function G.set(tod, fog)
        G.world.tod = tod
        NOM_World.update(fog)
    end
    G.set(12, 0)
    return G
end

return {
    night_and_fog_together = function()
        local G = setup()
        local p = G.player({ x = 100, y = 100, face = 0 })
        p.class = "IsoPlayer"
        function p:isSneaking() return true end
        function p:isRunning() return false end
        function p:isSprinting() return false end
        local id = W.semRostoID(1, true)
        local z = G.monster({ x = 112, y = 100, id = id })
        z.spotted = p
        G.set(23, 0.9) -- noite e névoa na mesma leitura do clima
        assert(NOM_NightStats.night == true and NOM_NightStats.nightNumber == 1, "noite não ligou")
        assert(NOM_FogState.on == true and NOM_FogState.period == 1, "névoa não ligou")
        G.frame(3)
        -- as duas variantes no mesmo zumbi: o sorteio da noite e o da névoa não brigam
        assert(z.md.NOM_variant == "estalador", "não virou Estalador: " .. tostring(z.md.NOM_variant))
        assert(z.useless == true, "Estalador não ficou cego pro jogador agachado")
        G.frame(NOM_SemRosto.SCAN_TICKS)
        assert(z.teleports == 1, "Sem-rosto não sumiu sendo Estalador")
        assert(not z:getCurrentSquare():isCanSee(0), "reapareceu à vista")
        G.seconds(10)
        assert(#G.playing("NOM_FogDrone") == 1, "drone não tocou à noite")
        assert(#G.playing("NOM_RadioStatic") == 1, "rádio não chiou à noite")
        assert(G.enabled[0] == true, "vinheta não ligou à noite")
        assert(G.markers > 0, "sem overlays à noite")
        -- amanhece com névoa: o Estalador volta a comum, o Sem-rosto continua
        G.set(8, 0.9)
        G.frame(30)
        assert(z.md.NOM_variant == nil, "Estalador de dia")
        assert(NOM_FogState.on == true and #G.playing("NOM_FogDrone") == 1)
        -- névoa baixa: tudo sai, a noite não é afetada
        G.set(23, 0)
        G.seconds(12)
        assert(NOM_NightStats.night == true and NOM_FogState.on == false)
        assert(#G.playing("NOM_FogDrone") == 0 and #G.playing("NOM_RadioStatic") == 0, "som da névoa ficou")
        assert(G.enabled[0] == false, "vinheta ficou")
        local fog = G.commands(G.sentServer, "fog")
        assert(#fog == 0, "solo mandou comando de rede")
    end,
}
