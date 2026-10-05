-- shared/NOM_Carpideira.lua (sprint 0011) contra o mundo falso de tests/fog_world.lua:
-- quem tem a Carpideira carregada (solo: o processo; MP: cada cliente) toca o soluço
-- local enquanto ela está calma e avisa quando um jogador local a acorda (perto, ou
-- lanterna acesa com ela vista). Quem é Carpideira vem do NOM_NightStats.variants
-- (o laço da noite aplica o perfil; aqui o teste põe direto, como o apply faz).
-- * isCanSee(pn) do square dela: linha de visão + cone + luz; no escuro, só a até 10
--   tiles da lanterna do jogador (fog_world).
-- * O soluço é local (playSoundLocal no zumbi) e o emitter não para sozinho quando o
--   zumbi sai do mundo (IsoZombie.removeFromWorld não chama stopAll).
local W = dofile("tests/fog_world.lua")

local ID = 5 * 65536 + 77

local function setup(opts)
    opts = opts or {}
    local G = W.new({ dark = opts.dark, sandbox = opts.sandbox, client = opts.client })
    G.reload({ "NOM_FogState", "NOM_NightStats", "NOM_Carpideira", "NOM_CarpideiraRules" })
    require "NOM_NightStats"
    require "NOM_Carpideira"
    NOM_FogState.set(opts.fog ~= false, 1)
    G.reports = {}
    NOM_Carpideira.install(function(z, p, why) G.reports[#G.reports + 1] = { z = z, p = p, why = why } end)
    function G.carpideira(o)
        o.id = o.id or ID
        local z = G.zombie(o)
        NOM_NightStats.variants[z] = "carpideira"
        z.md.NOM_variant = "carpideira"
        return z
    end
    function G.scan() G.tick(NOM_Carpideira.SCAN_TICKS) end
    return G
end

-- conta as chamadas Java de um zumbi do fake
local function counted(z)
    z.calls = 0
    for k, v in pairs(z) do
        if type(v) == "function" then
            z[k] = function(...) z.calls = z.calls + 1; return v(...) end
        end
    end
    return z
end

return {
    -- calma, ela soluça: som local no emitter dela, um loop só (não recomeça a cada varredura)
    carpideira_sobs_locally_while_calm = function()
        local G = setup()
        local z = G.carpideira({ x = 0, y = 0 })
        G.player({ x = 10, y = 0 })
        G.scan()
        local s = G.playing(NOM_Carpideira.SOB)
        assert(#s == 1 and s[1].src == z, "não soluçou")
        G.scan()
        G.scan()
        assert(G.played(NOM_Carpideira.SOB) == 1, "recomeçou o loop: " .. G.played(NOM_Carpideira.SOB))
        -- loop cortado pelo jogo: toca de novo
        s[1].playing = false
        G.scan()
        assert(#G.playing(NOM_Carpideira.SOB) == 1)
        -- zumbi comum não soluça
        G.zombie({ x = 3, y = 3, id = ID + 1 })
        G.scan()
        assert(#G.playing(NOM_Carpideira.SOB) == 1)
    end,
    -- o soluço para no grito, no fim da névoa, na morte e quando ela sai do mundo
    carpideira_sob_stops_on_scream_fog_end_and_unload = function()
        local G = setup()
        local z = G.carpideira({ x = 0, y = 0 })
        G.player({ x = 10, y = 0 })
        G.scan()
        NOM_Carpideira.scream(z, nil)
        assert(#G.playing(NOM_Carpideira.SOB) == 0, "soluço depois do grito")
        assert(G.played(NOM_Carpideira.SCREAM) == 1, "grito não tocou")
        G.scan()
        assert(#G.playing(NOM_Carpideira.SOB) == 0, "voltou a soluçar furiosa")

        local G2 = setup()
        G2.carpideira({ x = 0, y = 0 })
        G2.player({ x = 10, y = 0 })
        G2.scan()
        NOM_FogState.set(false, 1)
        G2.scan()
        assert(#G2.playing(NOM_Carpideira.SOB) == 0, "soluço depois da névoa")

        local G3 = setup()
        local z3 = G3.carpideira({ x = 0, y = 0 })
        G3.player({ x = 10, y = 0 })
        G3.scan()
        z3:removeFromWorld() -- foi pro virtual: o emitter não para sozinho
        G3.scan()
        assert(#G3.playing(NOM_Carpideira.SOB) == 0, "loop preso de quem descarregou")

        local G4 = setup()
        local z4 = G4.carpideira({ x = 0, y = 0 })
        G4.player({ x = 10, y = 0 })
        G4.scan()
        z4.dead = true
        G4.scan()
        assert(#G4.playing(NOM_Carpideira.SOB) == 0, "morta soluçando")
    end,
    -- perto (até CarpideiraTriggerRadius, padrão 4), mesmo agachado e de costas: acorda
    carpideira_reports_proximity = function()
        local G = setup()
        local z = G.carpideira({ x = 0, y = 0 })
        local p = G.player({ x = 6, y = 0, face = 0 }) -- de costas, longe
        G.scan()
        assert(#G.reports == 0, "acordou de longe")
        p.x = 3.5
        G.scan()
        assert(#G.reports == 1 and G.reports[1].z == z and G.reports[1].p == p and G.reports[1].why == "near")
        -- outro andar não conta
        local G2 = setup()
        G2.carpideira({ x = 0, y = 0, z = 1 })
        G2.player({ x = 1, y = 0 })
        G2.scan()
        assert(#G2.reports == 0, "acordou do andar de baixo")
    end,
    -- lanterna: acesa e ela vista (no cone, iluminada), a até 10 tiles
    carpideira_reports_light_only_when_lit_and_seen = function()
        local function try(o)
            local G = setup({ dark = true })
            G.carpideira({ x = 0, y = 0 })
            G.player(o)
            G.scan()
            return G.reports[1] and G.reports[1].why
        end
        local west = math.pi -- olhando pro zumbi em (0, 0)
        assert(try({ x = 8, y = 0, face = west, light = true }) == "light", "lanterna apontada não acordou")
        assert(try({ x = 8, y = 0, face = west, light = false }) == nil, "sem lanterna acordou")
        assert(try({ x = 8, y = 0, face = 0, light = true }) == nil, "lanterna pro outro lado acordou")
        assert(try({ x = 12, y = 0, face = west, light = true }) == nil, "lanterna a 12 tiles acordou")
    end,
    -- o cliente espaça os avisos da mesma Carpideira (o servidor pode ter recusado)
    carpideira_report_gap = function()
        local G = setup()
        G.carpideira({ x = 0, y = 0 })
        G.player({ x = 2, y = 0 })
        G.scan()
        G.scan()
        assert(#G.reports == 1, "avisou de novo logo em seguida")
        G.seconds(NOM_CarpideiraRules.REPORT_GAP_MS / 1000)
        G.scan()
        assert(#G.reports == 2, "não avisou de novo depois do intervalo")
    end,
    -- quem já gritou neste período (o servidor avisou) não soluça nem é avisada,
    -- inclusive um objeto novo com o mesmo ID (voltou do virtual)
    carpideira_furious_is_silent = function()
        local G = setup()
        NOM_Carpideira.screamed[ID] = true
        G.carpideira({ x = 0, y = 0 })
        G.player({ x = 2, y = 0 })
        G.scan()
        assert(#G.playing(NOM_Carpideira.SOB) == 0 and #G.reports == 0)
        -- a névoa acaba: a lista de quem gritou é da névoa que passou
        NOM_FogState.set(false, 1)
        assert(NOM_Carpideira.screamed[ID] == nil, "grito passou pra próxima névoa")
    end,
    -- sandbox: Carpideira desligada não soluça nem acorda (o sorteio já a tira; isto
    -- cobre a variante forçada pelo debug e o meio da troca)
    carpideira_disabled_does_nothing = function()
        local G = setup({ sandbox = { CarpideiraEnabled = false } })
        G.carpideira({ x = 0, y = 0 })
        G.player({ x = 2, y = 0 })
        G.scan()
        assert(#G.playing(NOM_Carpideira.SOB) == 0 and #G.reports == 0)
    end,
    -- orçamento: a varredura (a cada SCAN_TICKS, na névoa) não chama nada no zumbi que
    -- não é Carpideira; cada Carpideira calma custa um punhado de chamadas
    carpideira_scan_budget = function()
        local G = setup()
        local commons = {}
        for i = 1, 300 do commons[i] = counted(G.zombie({ x = i, y = 40, id = ID + i })) end
        local cs = {}
        for i = 1, 20 do cs[i] = counted(G.carpideira({ x = i * 3, y = 0, id = ID + 1000 + i })) end
        G.player({ x = 100, y = 100 })
        G.scan()
        for _, z in ipairs(commons) do assert(z.calls == 0, "zumbi comum tocado: " .. z.calls) end
        for _, z in ipairs(cs) do
            z.calls = 0
        end
        G.scan()
        for _, z in ipairs(cs) do assert(z.calls <= 10, "Carpideira calma: " .. z.calls .. " chamadas") end
    end,
    -- review: sem teto, cada Carpideira carregada (a célula inteira) tocava um loop.
    -- Só soluça quem está a até SOB_RANGE de um jogador local; longe, para.
    carpideira_sob_only_near_a_local_player = function()
        local G = setup()
        local near = G.carpideira({ x = 0, y = 0 })
        local far = G.carpideira({ x = 40, y = 0, id = ID + 2 })
        local p = G.player({ x = 10, y = 0 })
        G.scan()
        local s = G.playing(NOM_Carpideira.SOB)
        assert(#s == 1 and s[1].src == near, "soluçou longe de todo mundo: " .. #s)
        p.x = 40 - NOM_Carpideira.SOB_RANGE - 1 -- longe das duas
        G.scan()
        assert(#G.playing(NOM_Carpideira.SOB) == 0, "não parou quem ficou longe")
        p.x = 30
        G.scan()
        s = G.playing(NOM_Carpideira.SOB)
        assert(#s == 1 and s[1].src == far)
    end,
    -- review: um aviso por varredura (o servidor aceita um por segundo por jogador:
    -- vários de uma vez atrasariam o enésimo); a outra vai na varredura seguinte
    carpideira_one_report_per_scan = function()
        local G = setup()
        local a = G.carpideira({ x = 0, y = 0 })
        local b = G.carpideira({ x = 0, y = 2, id = ID + 3 })
        G.player({ x = 1, y = 1 })
        G.scan()
        assert(#G.reports == 1, "avisos na mesma varredura: " .. #G.reports)
        G.scan()
        assert(#G.reports == 2 and G.reports[2].z ~= G.reports[1].z, "a segunda não foi na seguinte")
        assert((G.reports[1].z == a or G.reports[1].z == b) and (G.reports[2].z == a or G.reports[2].z == b))
    end,
    -- review: a marca da fúria é do período; a mesma Carpideira na névoa seguinte (o
    -- objeto ficou carregado) volta calma
    carpideira_furia_is_per_fog = function()
        local G = setup()
        local z = G.carpideira({ x = 0, y = 0 })
        G.player({ x = 10, y = 0 })
        NOM_Carpideira.scream(z, nil)
        assert(z.md.NOM_furia == 1, "marca sem o período")
        NOM_FogState.set(false, 1)
        NOM_FogState.set(true, 2)
        G.scan()
        assert(#G.playing(NOM_Carpideira.SOB) == 1, "fúria passou pra névoa seguinte")
    end,
}
