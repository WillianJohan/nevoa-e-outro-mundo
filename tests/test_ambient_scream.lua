-- client/NOM_AmbientScream.lua (sprint 0048): gritos ambiente só neste cliente.
local W = dofile("tests/fog_world.lua")
local FILE = "mod/42/media/lua/client/NOM_AmbientScream.lua"

local function setup(opts)
    opts = opts or {}
    local G = W.new(opts)
    G.reload({ "NOM_FogState", "NOM_AmbientScreamRules", "NOM_AmbientScream", "NOM_Config" })
    require "NOM_Config"
    require "NOM_AmbientScreamRules"
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

    ambient_plays_in_red = function()
        local G = setup()
        NOM_FogState.set(true, 1, true)
        local msg = NOM_AmbientScream.play(G.p)
        assert(msg:find("dist=", 1, true))
        assert(ambientPlayed(G) >= 1)
    end,
}
