-- client/NOM_FogSound.lua (solo e cliente de MP) contra o mundo falso de
-- tests/fog_world.lua: só som local (playSoundLocal/setVolume/stopSoundLocal);
-- emitter:playSound/stopSound explodem porque vão pra rede.
local W = dofile("tests/fog_world.lua")
local FILE = "mod/42/media/lua/client/NOM_FogSound.lua"

local function setup(opts)
    opts = opts or {}
    local G = W.new(opts)
    G.reload({ "NOM_FogState", "NOM_SemRosto", "NOM_FogSound" })
    require "NOM_SemRosto"
    NOM_SemRosto.install(function() end) -- no solo o server/NOM_Fog.lua instala
    G.ticksBefore = #(G.handlers.OnTick or {})
    dofile(FILE)
    G.p = G.player({ x = 100, y = 100, face = 0 })
    return G
end

local function one(G, name)
    local list = G.playing(name)
    assert(#list <= 1, "dois " .. name .. " tocando")
    return list[1]
end

return {
    sound_inert_on_dedicated = function()
        local G = setup({ server = true })
        assert(#G.handlers.OnTick == G.ticksBefore, "servidor dedicado registrou som")
    end,
    -- critério: drone entra e sai com transição
    sound_drone_fades_in_and_out = function()
        local G = setup()
        G.seconds(5)
        assert(G.played("NOM_FogDrone") == 0, "drone sem névoa")
        NOM_FogState.set(true, 1)
        G.seconds(NOM_FogSound.FADE_MS / 2000)
        local d = one(G, "NOM_FogDrone")
        assert(d and d.volume > 0.2 * NOM_FogSound.DRONE_MAX and d.volume < 0.8 * NOM_FogSound.DRONE_MAX,
            "sem fade de entrada: " .. tostring(d and d.volume))
        G.seconds(NOM_FogSound.FADE_MS / 1000)
        assert(math.abs(one(G, "NOM_FogDrone").volume - NOM_FogSound.DRONE_MAX) < 1e-6)
        NOM_FogState.set(false, 1)
        G.seconds(NOM_FogSound.FADE_MS / 2000)
        d = one(G, "NOM_FogDrone")
        assert(d and d.volume < NOM_FogSound.DRONE_MAX, "parou sem fade de saída")
        G.seconds(NOM_FogSound.FADE_MS / 1000)
        assert(one(G, "NOM_FogDrone") == nil, "drone continua depois da névoa")
        assert(G.played("NOM_FogDrone") == 1, "recomeçou o loop à toa")
    end,
    sound_metal_spread_in_fog = function()
        local G = setup()
        NOM_FogState.set(true, 1)
        G.seconds(NOM_FogSound.METAL_MIN_MS / 1000 * 3 + 1)
        local n = G.played("NOM_FogMetal")
        assert(n >= 2 and n <= 4, "metais: " .. n)
        NOM_FogState.set(false, 1)
        G.seconds(200)
        assert(G.played("NOM_FogMetal") == n, "metal fora da névoa")
    end,
    -- critério: o rádio chia mais forte quanto mais perto, sem rádio no inventário
    sound_static_follows_distance = function()
        local G = setup()
        local z = G.zombie({ x = 75, y = 100, id = W.semRostoID(1, true) }) -- atrás, a 25 tiles
        NOM_FogState.set(true, 1)
        G.seconds(2)
        local far = one(G, "NOM_RadioStatic")
        assert(far and far.volume > 0, "sem chiado com Sem-rosto a 25 tiles")
        local v1 = far.volume
        z.x = 92.5 -- 8 tiles
        G.seconds(2)
        local v2 = one(G, "NOM_RadioStatic").volume
        assert(v2 > v1, string.format("não subiu ao chegar perto: %.2f → %.2f", v1, v2))
        z.x = 40.5 -- longe: mudo
        G.seconds(2)
        assert(one(G, "NOM_RadioStatic") == nil, "chiado sem Sem-rosto por perto")
        z.x = 92.5
        G.seconds(2)
        NOM_FogState.set(false, 1)
        G.seconds(2)
        assert(one(G, "NOM_RadioStatic") == nil, "chiado depois da névoa")
    end,
    -- arquivo sem loop (ou som cortado pelo jogo): toca de novo
    sound_restarts_dead_loop = function()
        local G = setup()
        NOM_FogState.set(true, 1)
        G.seconds(2)
        one(G, "NOM_FogDrone").playing = false
        G.seconds(1)
        assert(one(G, "NOM_FogDrone") ~= nil and G.played("NOM_FogDrone") == 2, "loop morto ficou mudo")
    end,
    sound_toggles = function()
        local G = setup({ sandbox = { FogAmbience = false, SemRostoEnabled = false } })
        G.zombie({ x = 92, y = 100, id = W.semRostoID(1, true) })
        NOM_FogState.set(true, 1)
        G.seconds(70)
        assert(G.played("NOM_FogDrone") == 0 and G.played("NOM_FogMetal") == 0, "ambiente desligado tocou")
        assert(G.played("NOM_RadioStatic") == 0, "Sem-rosto desligado chiou")
    end,
}
