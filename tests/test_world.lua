-- NOM_World com o clima falso mínimo: hora do dia e estação.
local function load(tod)
    local world = { tod = tod }
    SandboxVars = {}
    getGameTime = function() return { getTimeOfDay = function() return world.tod end } end
    getClimateManager = function()
        return { getSeason = function() return { getDawn = function() return 6 end, getDusk = function() return 21 end } end }
    end
    NOM_World = nil
    package.loaded["NOM_World"] = nil
    require "NOM_World"
    return world
end

return {
    world_on_change_fires_only_on_edges = function()
        local world = load(12)
        local seen = {}
        NOM_World.onChange(function(flag, on) seen[#seen + 1] = flag .. "=" .. tostring(on) end)
        NOM_World.update()
        NOM_World.update()
        assert(#seen == 0, "avisou sem mudar: " .. table.concat(seen, ","))
        world.tod = 22
        NOM_World.update()
        NOM_World.update()
        NOM_World.setFog(true)
        NOM_World.setFog(true)
        world.tod = 7
        NOM_World.update()
        NOM_World.setFog(false)
        assert(table.concat(seen, ",") == "night=true,fog=true,night=false,fog=false", table.concat(seen, ","))
    end,
    -- primeira leitura já de noite (servidor subiu à noite) conta como borda
    world_first_update_at_night_is_an_edge = function()
        load(23)
        local seen = {}
        NOM_World.onChange(function(flag, on) seen[#seen + 1] = flag .. "=" .. tostring(on) end)
        NOM_World.update()
        assert(table.concat(seen, ",") == "night=true")
    end,
    -- NOM_Debug (só em -debug) força a noite; nil devolve pro relógio
    world_forced_overrides_clock_and_clears = function()
        local world = load(12)
        NOM_World.forced.night = true
        NOM_World.update()
        assert(NOM_World.night, "forçado ignorado")
        NOM_World.forced.night = nil
        NOM_World.update()
        assert(not NOM_World.night, "não voltou pro relógio")
        world.tod = 23
        NOM_World.forced.night = false
        NOM_World.update()
        assert(not NOM_World.night, "false forçado ignorado")
    end,
    -- a névoa é evento (ADR-009): o relógio nunca mexe nela
    world_update_never_touches_fog = function()
        local world = load(12)
        NOM_World.setFog(true)
        world.tod = 23
        NOM_World.update()
        assert(NOM_World.fog == true)
        NOM_World.setFog(false)
        NOM_World.update()
        assert(NOM_World.fog == false)
    end,
    -- névoa vermelha (sprint 0010): red só com névoa; borda "red" só quando a névoa
    -- não mudou junto (a borda "fog" já leva o red novo)
    world_red_flag_edges = function()
        load(12)
        local seen = {}
        NOM_World.onChange(function(flag, on) seen[#seen + 1] = flag .. "=" .. tostring(on) end)
        NOM_World.setFog(false, true)
        assert(NOM_World.red == false, "vermelho sem névoa")
        NOM_World.setFog(true, true)
        assert(NOM_World.red == true)
        NOM_World.setFog(true, true)
        NOM_World.setFog(true, false)
        NOM_World.setFog(true, true)
        NOM_World.setFog(false)
        assert(NOM_World.red == false)
        assert(table.concat(seen, ",") == "fog=true,red=false,red=true,fog=false", table.concat(seen, ","))
    end,
}
