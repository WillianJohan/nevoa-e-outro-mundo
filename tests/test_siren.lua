-- shared/NOM_Siren.lua contra o mundo falso (tests/fog_world.lua, com o pool de emitters):
-- 3 sirenes por jogador local, cada uma num emitter do mundo parado onde foi posto, uma
-- perto e duas longe, em coro desencontrado; o fim (sirenStop, cancelamento) para todas.
local W = dofile("tests/fog_world.lua")

local function setup(opts)
    local G = W.new(opts or {})
    G.rand = 3721 -- ZombRand fixo: rand 0,3721
    G.reload({ "NOM_SirenSpotsRules", "NOM_Siren" })
    require "NOM_Siren"
    return G
end

local function sirens(G)
    local out = {}
    for _, s in pairs(G.sounds) do
        if s.name:find("^NOM_Siren") and s.playing then out[#out + 1] = s end
    end
    return out
end

local function dist(s, p) return math.sqrt((s.at.x - p.x) ^ 2 + (s.at.y - p.y) ^ 2) end

return {
    siren_plays_three_positioned = function()
        local G = setup()
        local p = G.player({ x = 1000, y = 1000 })
        local px, py = p.x, p.y
        NOM_Siren.play(false)
        local now = sirens(G)
        assert(#now == 1 and now[1].name == "NOM_Siren", "a perto não entrou na hora")
        assert(now[1].emitter, "tocou fora de emitter do mundo")
        local d = dist(now[1], p)
        local SR = NOM_SirenSpotsRules
        assert(d >= SR.NEAR_MIN and d <= SR.NEAR_MAX, "perto a " .. d)
        p.x, p.y = px + 30, py - 20 -- o jogador anda: as sirenes ficam onde estavam
        G.seconds(SR.DELAY_MAX_MS / 1000 + 0.1)
        local all = sirens(G)
        assert(#all == 3, "sirenes: " .. #all)
        local far = 0
        for _, s in ipairs(all) do
            assert(s.emitter, "som sem emitter do mundo")
            local ds = math.sqrt((s.at.x - px) ^ 2 + (s.at.y - py) ^ 2)
            if s.name == "NOM_SirenFar" then
                far = far + 1
                assert(ds >= SR.FAR_MIN and ds <= SR.FAR_MAX, "longe a " .. ds .. " de onde tocou")
                assert(s.startedAt - now[1].startedAt >= SR.DELAY_MIN_MS, "a longe entrou junto")
            end
        end
        assert(far == 2, "longe: " .. far)
        for _, e in ipairs(G.pool) do
            local de = math.sqrt((e.x - px) ^ 2 + (e.y - py) ^ 2)
            assert(de >= SR.NEAR_MIN, "o emitter andou com o jogador")
        end
    end,
    siren_red_uses_red_sounds = function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM_Siren.play(true)
        G.seconds(3)
        assert(G.played("NOM_SirenRed") == 1 and G.played("NOM_SirenRedFar") == 2)
        assert(G.played("NOM_Siren") == 0 and G.played("NOM_SirenFar") == 0)
    end,
    -- sirenStop / cancelamento: para as que tocam e as que ainda iam entrar
    siren_stop_stops_all_and_pending = function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM_Siren.play(false)
        G.seconds(0.1)
        assert(#sirens(G) == 1)
        NOM_Siren.stop()
        assert(#sirens(G) == 0, "sirenStop deixou sirene tocando")
        G.seconds(3)
        assert(#sirens(G) == 0 and G.played("NOM_SirenFar") == 0, "a atrasada entrou depois do stop")
        NOM_Siren.stop() -- sem sirene: não faz nada
    end,
    siren_stop_after_all_started = function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM_Siren.play(false)
        G.seconds(3)
        assert(#sirens(G) == 3)
        NOM_Siren.stop()
        assert(#sirens(G) == 0)
    end,
    -- comando repetido (quem entra na fuga recebe siren de novo): nunca mais de 3 de uma vez
    siren_play_again_replaces = function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM_Siren.play(false)
        G.seconds(1)
        NOM_Siren.play(false)
        G.seconds(3)
        assert(#sirens(G) == 3, "sirenes juntas: " .. #sirens(G))
    end,
    siren_without_player_plays_nothing = function()
        local G = setup()
        assert(NOM_Siren.play(false) == nil)
        G.seconds(3)
        assert(#sirens(G) == 0 and #G.pool == 0)
    end,
    -- a sirene acaba sozinha (one-shot): o emitter volta ao pool e o stop não mexe nele
    siren_stop_ignores_finished = function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM_Siren.play(false)
        G.seconds(3)
        for _, s in ipairs(sirens(G)) do s.playing = false end
        local other = G.pool[1]
        local id = other:playSoundImpl("NOM_FogMetal", nil) -- outro sistema pegou o emitter
        NOM_Siren.stop()
        assert(other:isPlaying(id), "o stop parou o som de outro sistema")
    end,
}
