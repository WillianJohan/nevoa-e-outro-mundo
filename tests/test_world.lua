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
    -- calmaria (sprint 0033): flag própria, avisa só na borda
    world_calm_flag_edges = function()
        load(12)
        local seen = {}
        NOM_World.onChange(function(flag, on) seen[#seen + 1] = flag .. "=" .. tostring(on) end)
        assert(NOM_World.calm == false, "calmaria começa desligada")
        NOM_World.setCalm(false)
        assert(#seen == 0, "avisou sem mudar")
        NOM_World.setCalm(true)
        NOM_World.setCalm(true)
        assert(NOM_World.calm == true)
        NOM_World.setCalm(false)
        NOM_World.setCalm(false)
        assert(NOM_World.calm == false)
        assert(table.concat(seen, ",") == "calm=true,calm=false", table.concat(seen, ","))
    end,
    -- só true liga (nil e outros valores não): igual ao setFog
    world_calm_only_true_turns_on = function()
        load(12)
        NOM_World.setCalm(1)
        assert(NOM_World.calm == false)
        NOM_World.setCalm(nil)
        assert(NOM_World.calm == false)
    end,
    -- sprint 0034: a névoa sobe na sirene (rising), sem abrir a névoa de jogo; risingRed só
    -- com rising; borda "rising" só quando muda
    world_rising_flag_edges = function()
        load(12)
        local seen = {}
        NOM_World.onChange(function(flag, on) seen[#seen + 1] = flag .. "=" .. tostring(on) end)
        assert(NOM_World.rising == false and NOM_World.risingRed == false)
        NOM_World.setRising(false, true)
        assert(NOM_World.risingRed == false, "vermelha sem subida")
        NOM_World.setRising(true, true)
        NOM_World.setRising(true, true)
        assert(NOM_World.rising == true and NOM_World.risingRed == true)
        assert(NOM_World.fog == false, "a subida abriu a névoa de jogo")
        NOM_World.setRising(1)
        assert(NOM_World.rising == false and NOM_World.risingRed == false, "só true liga")
        NOM_World.setRising(true)
        assert(NOM_World.risingRed == false)
        NOM_World.setRising(false)
        assert(table.concat(seen, ",") == "rising=true,rising=false,rising=true,rising=false", table.concat(seen, ","))
    end,
    -- quem vê (shared/NOM_FogState): visible() é a névoa ou a subida; visibleRed() a cor de
    -- quem estiver valendo
    fog_state_visible_helpers = function()
        NOM_FogState = nil
        package.loaded["NOM_FogState"] = nil
        require "NOM_FogState"
        local S = NOM_FogState
        assert(S.visible() == false and S.visibleRed() == false)
        S.setRising(true, true)
        assert(S.rising == true and S.risingRed == true and S.on == false)
        assert(S.visible() == true and S.visibleRed() == true)
        S.setRising(false, true)
        assert(S.risingRed == false and S.visible() == false and S.visibleRed() == false)
        S.setRising(true)
        assert(S.visible() == true and S.visibleRed() == false)
        S.set(true, 1, false)
        S.setRising(false)
        assert(S.visible() == true and S.visibleRed() == false)
        S.set(true, 1, true)
        assert(S.visibleRed() == true)
        S.set(false, 1)
        assert(S.visible() == false and S.visibleRed() == false)
    end,
    -- a subida não é borda de névoa: quem ouve NOM_FogState.onChange (fog on) não dispara
    fog_state_rising_does_not_fire_on_change = function()
        NOM_FogState = nil
        package.loaded["NOM_FogState"] = nil
        require "NOM_FogState"
        local n = 0
        NOM_FogState.onChange(function() n = n + 1 end)
        NOM_FogState.setRising(true, true)
        NOM_FogState.setRising(false)
        assert(n == 0, "a subida disparou o onChange da névoa")
    end,
}
