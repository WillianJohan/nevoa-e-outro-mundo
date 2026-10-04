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
        NOM_World.update(0)
        NOM_World.update(0)
        assert(#seen == 0, "avisou sem mudar: " .. table.concat(seen, ","))
        world.tod = 22
        NOM_World.update(0)
        NOM_World.update(0)
        NOM_World.update(0.9)
        world.tod = 7
        NOM_World.update(0)
        assert(table.concat(seen, ",") == "night=true,fog=true,night=false,fog=false", table.concat(seen, ","))
    end,
    -- primeira leitura já de noite (servidor subiu à noite) conta como borda
    world_first_update_at_night_is_an_edge = function()
        load(23)
        local seen = {}
        NOM_World.onChange(function(flag, on) seen[#seen + 1] = flag .. "=" .. tostring(on) end)
        NOM_World.update(0)
        assert(table.concat(seen, ",") == "night=true")
    end,
}
