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
        assert(z.x == r.x + 0.5 and z.y == r.y + 0.5, "não ficou no centro do tile: " .. z.x .. "," .. z.y)
        assert(z.lastX == z.x and z.lastY == z.y, "lastX/lastY no canto: o jogo interpola de lá")
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
    -- sprint 0034: na subida da sirene (fuga) ainda não existe Sem-rosto
    semrosto_not_while_rising = function()
        local G = setup({ fog = false })
        NOM_FogState.period = PERIOD
        local p = G.player({ x = 100, y = 100, face = 0 })
        G.zombie({ x = 112, y = 100, id = G.SEM })
        NOM_FogState.setRising(true, true)
        G.tick(NOM_SemRosto.SCAN_TICKS * 3)
        assert(#G.reports == 0 and NOM_SemRosto.nearest(p) == nil, "Sem-rosto na fuga")
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
    -- a 2 tiles ou menos de quem vê, para de sumir: ataca
    semrosto_attacks_when_close = function()
        local G = setup()
        G.player({ x = 100, y = 100, face = 0 })
        local z = G.zombie({ x = 102, y = 100, id = G.SEM })
        G.tick(NOM_SemRosto.SCAN_TICKS * 3)
        assert(#G.reports == 0, "sumiu colado no jogador")
        z.x = 103.5
        G.tick(NOM_SemRosto.SCAN_TICKS)
        assert(#G.reports == 1, "a 3 tiles devia sumir")
    end,
    -- tela dividida: o destino fica fora da vista de todos os jogadores locais
    semrosto_destination_hidden_from_all_local_players = function()
        local G = setup()
        G.player({ x = 100, y = 100, face = 0 })
        G.player({ x = 101, y = 100, face = math.pi }) -- do lado, olhando pra trás do primeiro
        G.zombie({ x = 112, y = 100, id = G.SEM })
        G.tick(NOM_SemRosto.SCAN_TICKS)
        for _, r in ipairs(G.reports) do
            for pn = 0, 1 do
                assert(not G.square(r.x, r.y, 0):isCouldSee(pn), "destino à vista do jogador " .. pn)
            end
        end
    end,
    -- água não é chão: o destino pula, e sem chão nenhum não some
    semrosto_destination_avoids_water = function()
        local G = setup()
        G.player({ x = 100, y = 100, face = 0 })
        G.zombie({ x = 112, y = 100, id = G.SEM })
        for x = 85, 115 do for y = 85, 115 do
            if x < 98 then G.water[x .. "," .. y .. ",0"] = true end
        end end
        G.tick(NOM_SemRosto.SCAN_TICKS)
        for _, r in ipairs(G.reports) do
            assert(not G.water[r.x .. "," .. r.y .. ",0"], "destino na água")
        end
        local G2 = setup()
        G2.player({ x = 100, y = 100, face = 0 })
        G2.zombie({ x = 112, y = 100, id = G2.SEM })
        for x = 80, 120 do for y = 80, 120 do G2.water[x .. "," .. y .. ",0"] = true end end
        G2.tick(NOM_SemRosto.SCAN_TICKS * 3)
        assert(#G2.reports == 0, "sumiu pra dentro da água")
    end,
    -- jogador na escada (z quebrado): compara andar, não float
    semrosto_compares_floors = function()
        local G = setup()
        local p = G.player({ x = 100, y = 100, face = 0 })
        p.z = 0.4
        G.zombie({ x = 112, y = 100, id = G.SEM })
        G.tick(NOM_SemRosto.SCAN_TICKS)
        assert(#G.reports == 1 and G.reports[1].zz == 0, "z quebrado travou o Sem-rosto")
        assert(NOM_SemRosto.nearest(p) ~= nil, "rádio comparou z float")
    end,

    -- orçamento: na névoa, a varredura faz no máximo 1 chamada por zumbi comum
    semrosto_scan_one_call_per_common_zombie = function()
        local G = setup()
        G.player({ x = 100, y = 100, face = 0 })
        local zs = {}
        for i = 1, 200 do zs[i] = G.zombie({ x = 100 + i % 20, y = 120 + math.floor(i / 20), id = G.COMMON }) end
        local c = dofile("tests/calls.lua")(zs)
        G.tick(NOM_SemRosto.SCAN_TICKS * 3)
        assert(c.n <= #zs * 3, "varredura chamou demais: " .. c.n .. " em 3 varreduras de " .. #zs)
    end,
    -- névoa vermelha (sprint 0010): o zumbi que é Sem-rosto só pela divisão da
    -- vermelha some também; na névoa normal, não
    semrosto_red_fog_counts_red_split = function()
        local G = setup({ fog = false })
        local id = W.semRostoID(PERIOD, true, nil, true)
        G.player({ x = 100, y = 100, face = 0 })
        G.zombie({ x = 112, y = 100, id = id })
        NOM_FogState.set(true, PERIOD)
        G.tick(NOM_SemRosto.SCAN_TICKS * 2)
        assert(#G.reports == 0, "Sem-rosto da vermelha na névoa normal")
        NOM_FogState.set(true, PERIOD, true)
        G.tick(NOM_SemRosto.SCAN_TICKS)
        assert(#G.reports == 1, "Sem-rosto da vermelha não sumiu")
    end,
    -- review: o servidor aceita um semRostoSeen por jogador a cada 250 ms. Dois vistos
    -- na mesma varredura: o segundo não pode ficar mudo os 4 s do cooldown dele; sai
    -- numa varredura seguinte, depois da janela do servidor
    semrosto_second_report_waits_rate_not_cooldown = function()
        local G = setup()
        G.player({ x = 100, y = 100, face = 0 })
        G.zombie({ x = 112, y = 100, id = G.SEM })
        G.zombie({ x = 112, y = 104, id = G.SEM })
        G.tick(NOM_SemRosto.SCAN_TICKS)
        assert(#G.reports == 1, "relatos na mesma varredura: " .. #G.reports)
        local first = G.now
        G.tick(NOM_SemRosto.SCAN_TICKS)
        if #G.reports == 2 then
            assert(G.now - first >= NOM_SemRostoRules.REPORT_GAP_MS, "dentro da janela do servidor")
        end
        G.tick(NOM_SemRosto.SCAN_TICKS * 2)
        assert(#G.reports == 2, "o segundo Sem-rosto ficou mudo: " .. #G.reports)
        assert(G.reports[2].z ~= G.reports[1].z)
        assert(G.reports[2].z.x ~= nil and G.now - first < NOM_SemRostoRules.COOLDOWN_MS)
        assert(NOM_SemRostoRules.REPORT_GAP_MS > NOM_SemRostoRules.RATE_MS, "cliente na margem do servidor")
    end,
    -- orçamento da névoa vermelha (review): 1/3 dos zumbis é Sem-rosto. Por varredura
    -- (a cada 10 ticks), o Sem-rosto fora de alcance custa 7 chamadas (ID, isDead,
    -- hasModData, getOutfitName, getZ, getX, getY), o resto 1 (o ID)
    semrosto_scan_budget_red_fog = function()
        local G = setup({ fog = false })
        G.player({ x = 100, y = 100, face = 0 })
        local c = NOM_VariantRules.config(function(k) return NOM_Config.DEFAULTS[k] end)
        local sem, other = {}, {}
        for seed = 1, 300 do
            local id = 11 * 65536 + seed
            local z = G.zombie({ x = 200 + seed % 20, y = 200 + math.floor(seed / 20), id = id })
            if NOM_VariantRules.variant(id, PERIOD, c, true) == "semrosto" then sem[#sem + 1] = z else other[#other + 1] = z end
        end
        NOM_FogState.set(true, PERIOD, true)
        local cs, co = dofile("tests/calls.lua")(sem), dofile("tests/calls.lua")(other)
        G.tick(NOM_SemRosto.SCAN_TICKS * 3)
        -- bíblia §7.3: vermelha 1/8 Sem-rosto (antes 1/4 → 70–130)
        assert(#sem > 25 and #sem < 55, "Sem-rostos: " .. #sem)
        assert(co.n <= #other * 3, "não Sem-rosto: " .. co.n)
        assert(cs.n <= #sem * 3 * 7, string.format("Sem-rosto: %d chamadas em 3 varreduras de %d", cs.n, #sem))
    end,

    -- sprint 0017: o tile de um sumiço fica reservado RESERVE_MS e depois volta a valer;
    -- névoa nova começa sem reserva
    semrosto_reservation_expires = function()
        local G = setup()
        G.player({ x = 100, y = 100, face = 0 })
        G.zombie({ x = 112, y = 100, id = G.SEM }) -- relato sem mover: continua à vista
        local R = NOM_SemRostoRules
        assert(R.RESERVE_MS > R.COOLDOWN_MS and R.RESERVE_MS < 2 * R.COOLDOWN_MS, "teste supõe 1 cooldown < reserva < 2")
        local function tile(r) return r.x .. "," .. r.y end
        G.tick(NOM_SemRosto.SCAN_TICKS)
        assert(#G.reports == 1)
        G.seconds(R.COOLDOWN_MS / 1000 + 0.2)
        assert(#G.reports == 2 and tile(G.reports[2]) ~= tile(G.reports[1]), "tile reservado escolhido de novo")
        G.seconds(R.COOLDOWN_MS / 1000 + 0.2)
        assert(#G.reports == 3 and tile(G.reports[3]) == tile(G.reports[1]), "reserva não expirou")
        NOM_FogState.set(false, nil)
        NOM_FogState.set(true, PERIOD)
        G.tick(NOM_SemRosto.SCAN_TICKS)
        assert(#G.reports == 4 and tile(G.reports[4]) == tile(G.reports[1]), "reserva passou pra névoa nova")
    end,
    -- review da 0017: reserva vencida sai na reserva seguinte (a tabela não cresce a névoa toda)
    semrosto_reservation_pruned = function()
        local G = setup()
        for i = 1, 10 do NOM_SemRosto.reserve(i, 0, 0) end
        assert(NOM_SemRosto.reservedCount() == 10)
        G.now = G.now + NOM_SemRostoRules.RESERVE_MS - 1
        NOM_SemRosto.reserve(50, 0, 0)
        assert(NOM_SemRosto.reservedCount() == 11, "podou antes de vencer")
        G.now = G.now + 1
        NOM_SemRosto.reserve(51, 0, 0)
        assert(NOM_SemRosto.reservedCount() == 2, "vencidas ficaram: " .. NOM_SemRosto.reservedCount())
    end,
}
