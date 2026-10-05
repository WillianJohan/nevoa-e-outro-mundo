-- shared/NOM_SemRosto.lua (onde os jogadores veem: solo e cliente de MP) contra
-- o mundo falso de tests/fog_world.lua (visão e luz por jogador como o cliente
-- calcula; teleporte no próprio objeto).
local W = dofile("tests/fog_world.lua")

local PERIOD = 2

local function setup(opts)
    opts = opts or {}
    local G = W.new(opts)
    G.reload({ "NOM_FogState", "NOM_SemRosto" })
    require "NOM_SemRosto"
    G.reports = {}
    NOM_SemRosto.install(function(z, x, y, zz, p)
        G.reports[#G.reports + 1] = { z = z, x = x, y = y, zz = zz, p = p }
    end)
    if opts.fog ~= false then NOM_FogState.set(true, PERIOD) end
    G.SEM = W.semRostoID(PERIOD, true)
    G.COMMON = W.semRostoID(PERIOD, false)
    return G
end

local function dist(p, x, y) return math.sqrt((p.x - x) ^ 2 + (p.y - y) ^ 2) end

return {
    -- critério: olhado, some e reaparece mais perto, fora do campo de visão
    semrosto_seen_moves_closer_out_of_view = function()
        local G = setup()
        local p = G.player({ x = 100, y = 100, face = 0 })
        local z = G.zombie({ x = 112, y = 100, id = G.SEM })
        assert(z:getCurrentSquare():isCanSee(0), "o fake não vê o zumbi: teste não prova nada")
        G.tick(NOM_SemRosto.SCAN_TICKS)
        assert(#G.reports == 1, "relatos: " .. #G.reports)
        local r = G.reports[1]
        assert(r.z == z and r.p == p and r.zz == 0)
        local before, after = dist(p, z.x, z.y), dist(p, r.x + 0.5, r.y + 0.5)
        assert(after < before, string.format("não chegou mais perto: %.1f → %.1f", before, after))
        assert(after >= NOM_SemRostoRules.MIN_DIST - 0.75, "colado no jogador")
        assert(not G.square(r.x, r.y, 0):isCouldSee(0), "reapareceu à vista")
        NOM_SemRosto.move(z, r.x, r.y, r.zz)
        assert(not z:getCurrentSquare():isCanSee(0), "continua à vista depois de mover")
        -- e um zumbi comum no mesmo lugar não some
        local G2 = setup()
        G2.player({ x = 100, y = 100, face = 0 })
        G2.zombie({ x = 112, y = 100, id = G2.COMMON })
        G2.tick(NOM_SemRosto.SCAN_TICKS * 3)
        assert(#G2.reports == 0, "zumbi comum sumiu")
    end,
    -- fora do cone, ou no escuro sem luz em cima: ninguém vê, ele fica
    semrosto_unseen_stays = function()
        local G = setup()
        G.player({ x = 100, y = 100, face = 0 })
        G.zombie({ x = 90, y = 100, id = G.SEM }) -- atrás do jogador
        G.tick(NOM_SemRosto.SCAN_TICKS * 5)
        assert(#G.reports == 0, "sumiu sem ser visto")
        local D = setup({ dark = true })
        local p = D.player({ x = 100, y = 100, face = 0 })
        D.zombie({ x = 108, y = 100, id = D.SEM })
        D.tick(NOM_SemRosto.SCAN_TICKS * 3)
        assert(#D.reports == 0, "visto no escuro")
        p.light = true -- lanterna: iluminado
        D.tick(NOM_SemRosto.SCAN_TICKS)
        assert(#D.reports == 1, "iluminado e não sumiu")
    end,
    -- não pisca: o mesmo zumbi só some de novo depois do cooldown
    semrosto_cooldown_no_flicker = function()
        local G = setup()
        G.player({ x = 100, y = 100, face = 0 })
        G.zombie({ x = 112, y = 100, id = G.SEM }) -- relato sem mover: continua à vista
        G.tick(NOM_SemRosto.SCAN_TICKS)
        assert(#G.reports == 1)
        G.seconds(NOM_SemRostoRules.COOLDOWN_MS / 1000 - 0.5)
        assert(#G.reports == 1, "piscou: " .. #G.reports)
        G.seconds(1)
        assert(#G.reports == 2)
    end,
    -- corredor, porão: nenhum square livre e fora da vista → fica, sem erro
    semrosto_no_spot_no_move = function()
        local G = setup()
        G.player({ x = 100, y = 100, face = 0 })
        G.zombie({ x = 112, y = 100, id = G.SEM })
        G.noFree = true
        G.tick(NOM_SemRosto.SCAN_TICKS * 3)
        assert(#G.reports == 0)
        G.noFree = false
        G.tick(NOM_SemRosto.SCAN_TICKS) -- tenta de novo assim que houver lugar
        assert(#G.reports == 1, "não tentou de novo")
    end,
    -- só existe na névoa; quando ela baixa é zumbi comum
    semrosto_only_in_fog = function()
        local G = setup({ fog = false })
        local p = G.player({ x = 100, y = 100, face = 0 })
        local z = G.zombie({ x = 112, y = 100, id = G.SEM })
        G.tick(NOM_SemRosto.SCAN_TICKS * 3)
        assert(#G.reports == 0 and NOM_SemRosto.nearest(p) == nil, "Sem-rosto sem névoa")
        NOM_FogState.set(true, nil) -- cliente que ainda não sabe o período
        G.tick(NOM_SemRosto.SCAN_TICKS * 3)
        assert(#G.reports == 0, "sorteou sem período")
        NOM_FogState.set(true, PERIOD)
        G.tick(NOM_SemRosto.SCAN_TICKS)
        assert(#G.reports == 1 and NOM_SemRosto.isSemRosto(z, PERIOD))
        NOM_FogState.set(false, PERIOD)
        G.seconds(10)
        assert(#G.reports == 1, "sumiu depois da névoa")
        assert(NOM_SemRosto.nearest(p) == nil, "rádio ainda acha Sem-rosto")
    end,
    semrosto_eco_never = function()
        local G = setup()
        G.player({ x = 100, y = 100, face = 0 })
        G.zombie({ x = 112, y = 100, id = G.SEM, eco = true })
        G.zombie({ x = 100, y = 112, id = G.SEM, outfit = "NOM_Eco" }) -- cliente de MP: só o outfit
        G.players[1].face = math.pi / 4
        G.tick(NOM_SemRosto.SCAN_TICKS * 3)
        assert(#G.reports == 0, "Eco virou Sem-rosto")
    end,
    semrosto_disabled = function()
        local G = setup({ sandbox = { SemRostoEnabled = false } })
        local p = G.player({ x = 100, y = 100, face = 0 })
        G.zombie({ x = 112, y = 100, id = G.SEM })
        G.tick(NOM_SemRosto.SCAN_TICKS * 3)
        assert(#G.reports == 0 and NOM_SemRosto.nearest(p) == nil)
    end,
    -- distância do Sem-rosto mais perto do jogador, pro rádio
    semrosto_nearest = function()
        local G = setup()
        local p = G.player({ x = 100, y = 100, face = math.pi }) -- de costas pros dois
        G.zombie({ x = 120, y = 100, id = G.SEM })
        G.zombie({ x = 108, y = 100, id = G.SEM })
        G.zombie({ x = 102, y = 100, id = G.COMMON })
        G.tick(NOM_SemRosto.SCAN_TICKS)
        assert(math.abs(NOM_SemRosto.nearest(p) - 8) < 0.01, "mais perto: " .. tostring(NOM_SemRosto.nearest(p)))
        assert(#G.reports == 0)
    end,
}
