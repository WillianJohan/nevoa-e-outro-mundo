-- client/NOM_AmbientScream.lua (sprint 0048 + hotfix 0063): gritos ambiente só neste cliente.
local W = dofile("tests/fog_world.lua")
local FILE = "mod/42/media/lua/client/NOM_AmbientScream.lua"

local function setup(opts)
    opts = opts or {}
    local G = W.new(opts)
    G.reload({ "NOM_FogState", "NOM_AmbientScreamRules", "NOM_AmbientScream", "NOM_Config" })
    require "NOM_Config"
    require "NOM_AmbientScreamRules"
    -- G.rolls: sorteios em ordem (um por chamada); acabou, G.rand (igual test_sonar).
    ZombRand = function(n)
        if G.rolls and #G.rolls > 0 then return table.remove(G.rolls, 1) % n end
        return G.rand % n
    end
    G.ticksBefore = #(G.handlers.OnTick or {})
    dofile(FILE)
    G.p = G.player({ x = 100, y = 100 })
    return G
end

local function ambientPlayed(G)
    local n = 0
    for i = 1, 4 do n = n + G.played("NOM_AmbientScream" .. i) end
    return n
end

-- Avança ticks até o check do ambiente (UPDATE_TICKS = 20).
local function ambientTick(G)
    G.tick(NOM_AmbientScream.UPDATE_TICKS)
end

return {
    ambient_inert_on_dedicated = function()
        local G = setup({ server = true })
        assert(#(G.handlers.OnTick or {}) == G.ticksBefore, "servidor dedicado registrou ambiente")
    end,

    ambient_plays_in_white_fog = function()
        local G = setup()
        NOM_FogState.set(true, 1)
        local msg = NOM_AmbientScream.play(G.p)
        assert(msg and msg:find("NOM_AmbientScream", 1, true), "tocou: " .. tostring(msg))
        assert(ambientPlayed(G) >= 1, "emitter não tocou")
    end,

    ambient_off_when_ambience_disabled = function()
        local G = setup({ sandbox = { FogAmbience = false } })
        NOM_FogState.set(true, 1)
        assert(NOM_AmbientScream.play(G.p) == "ambiente off")
        assert(ambientPlayed(G) == 0)
    end,

    ambient_silent_on_black = function()
        local G = setup()
        NOM_FogState.set(true, 1, false, true)
        assert(NOM_AmbientScream.play(G.p) == "ambiente off")
    end,

    -- fuga (~30 s): risingBlack deve silenciar (não tratar como branca)
    ambient_silent_on_rising_black = function()
        local G = setup()
        NOM_FogState.set(false, nil)
        NOM_FogState.setRising(true, false, true)
        assert(NOM_FogState.visible() == true and NOM_FogState.color() == "black")
        assert(NOM_AmbientScream.play(G.p) == "ambiente off")
        assert(ambientPlayed(G) == 0)
    end,

    ambient_plays_in_red = function()
        local G = setup()
        NOM_FogState.set(true, 1, true)
        local msg = NOM_AmbientScream.play(G.p)
        assert(msg:find("dist=", 1, true))
        assert(ambientPlayed(G) >= 1)
    end,

    -- 0063: nenhum grito antes do gap mínimo (primeiro tick só agenda).
    ambient_no_scream_before_min_gap = function()
        local A = require "NOM_AmbientScreamRules"
        local G = setup({ rand = 0 }) -- gap = GAP_MIN_MS
        NOM_FogState.set(true, 1)
        ambientTick(G) -- agenda
        assert(ambientPlayed(G) == 0, "grito no primeiro schedule")
        -- quase o mínimo: ainda não
        G.now = G.now + A.GAP_MIN_MS - 1000
        ambientTick(G)
        assert(ambientPlayed(G) == 0, "grito antes do mínimo")
        G.now = G.now + 2000
        ambientTick(G)
        assert(ambientPlayed(G) >= 1, "não gritou no fim do mínimo")
    end,

    -- 0063: depois de cada grito, sorteia de novo o intervalo.
    ambient_rerolls_gap_after_each_scream = function()
        local A = require "NOM_AmbientScreamRules"
        local G = setup()
        -- 1º schedule: roll 0 → min; play usa 3 rolls (pick/dist/bearing); 2º schedule: max
        G.rolls = {
            0, -- schedule 1 (gap min)
            0, 0, 0, -- play: pick, dist, bearing
            A.GAP_ROLL - 1, -- schedule 2 (gap max)
        }
        NOM_FogState.set(true, 1)
        ambientTick(G) -- agenda min
        G.now = G.now + A.GAP_MIN_MS + 100
        ambientTick(G) -- toca + agenda max
        assert(ambientPlayed(G) == 1, "primeiro grito")
        local afterFirst = ambientPlayed(G)
        -- ainda dentro do max: não toca de novo
        G.now = G.now + A.GAP_MAX_MS - 5000
        ambientTick(G)
        assert(ambientPlayed(G) == afterFirst, "grito antes do segundo gap (max)")
        G.now = G.now + 10000
        ambientTick(G)
        assert(ambientPlayed(G) > afterFirst, "segundo grito depois do max")
    end,
}
