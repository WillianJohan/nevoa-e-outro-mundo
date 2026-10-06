-- shared/NOM_Siren.lua contra o mundo falso (tests/fog_world.lua, com o pool de emitters):
-- 5 sirenes por jogador local, todas longe (150 a 500 tiles), cada uma num emitter do mundo
-- parado onde foi posto, em coro desencontrado; o fim (sirenStop, cancelamento) para todas.
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
    table.sort(out, function(a, b) return a.startedAt < b.startedAt end)
    return out
end

local function playedOf(G, kind)
    local n = 0
    for _, name in ipairs(NOM_SirenSpotsRules.SOUNDS[kind]) do n = n + G.played(name) end
    return n
end

local function inList(kind, name)
    for _, x in ipairs(NOM_SirenSpotsRules.SOUNDS[kind]) do if x == name then return true end end
    return false
end

local function allIn(G) return G.seconds(NOM_SirenSpotsRules.DELAY_MAX_MS / 1000 + 0.1) end

return {
    siren_plays_five_far_positioned = function()
        local G = setup()
        local p = G.player({ x = 1000, y = 1000 })
        local px, py = p.x, p.y
        local SR = NOM_SirenSpotsRules
        assert(NOM_Siren.play(false) == SR.COUNT)
        local now = sirens(G)
        assert(#now == 1 and inList("white", now[1].name), "a primeira não entrou na hora")
        assert(now[1].emitter, "tocou fora de emitter do mundo")
        p.x, p.y = px + 30, py - 20 -- o jogador anda: as sirenes ficam onde estavam
        allIn(G)
        local all = sirens(G)
        assert(#all == SR.COUNT, "sirenes: " .. #all)
        local seen = {}
        for i, s in ipairs(all) do
            assert(s.emitter, "som sem emitter do mundo")
            assert(inList("white", s.name), "branca com som de outra névoa: " .. s.name)
            assert(not seen[s.name], "repetiu no coro: " .. s.name)
            seen[s.name] = true
            local ds = math.sqrt((s.at.x - px) ^ 2 + (s.at.y - py) ^ 2)
            assert(ds >= SR.DIST_MIN - 1e-6 and ds <= SR.DIST_MAX + 1e-6, "sirene a " .. ds .. " de onde tocou")
            if i > 1 then
                assert(s.startedAt - all[i - 1].startedAt >= SR.DELAY_MIN_GAP_MS - 20, "duas entraram juntas")
            end
        end
        for _, e in ipairs(G.pool) do
            local de = math.sqrt((e.x - px) ^ 2 + (e.y - py) ^ 2)
            assert(de >= SR.DIST_MIN - 1e-6, "o emitter andou com o jogador")
        end
    end,
    siren_red_uses_red_sounds = function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM_Siren.play(true)
        allIn(G)
        assert(playedOf(G, "red") == 5 and playedOf(G, "white") == 0 and playedOf(G, "black") == 0)
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
        allIn(G)
        assert(#sirens(G) == 0 and playedOf(G, "white") == 1, "a atrasada entrou depois do stop")
        NOM_Siren.stop() -- sem sirene: não faz nada
    end,
    siren_stop_after_all_started = function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM_Siren.play(false)
        allIn(G)
        assert(#sirens(G) == 5)
        NOM_Siren.stop()
        assert(#sirens(G) == 0)
    end,
    -- comando repetido (quem entra na fuga recebe siren de novo): nunca mais de 5 de uma vez
    siren_play_again_replaces = function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM_Siren.play(false)
        G.seconds(1.5)
        NOM_Siren.play(false)
        allIn(G)
        assert(#sirens(G) == 5, "sirenes juntas: " .. #sirens(G))
    end,
    siren_without_player_plays_nothing = function()
        local G = setup()
        assert(NOM_Siren.play(false) == nil)
        allIn(G)
        assert(#sirens(G) == 0 and #G.pool == 0)
    end,
    -- a sirene acaba sozinha (one-shot): o emitter volta ao pool e o stop não mexe nele
    siren_stop_ignores_finished = function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        NOM_Siren.play(false)
        allIn(G)
        for _, s in ipairs(sirens(G)) do s.playing = false end
        local other = G.pool[1]
        local id = other:playSoundImpl("NOM_FogMetal", false, nil) -- outro sistema pegou o emitter
        NOM_Siren.stop()
        assert(other:isPlaying(id), "o stop parou o som de outro sistema")
    end,
}
