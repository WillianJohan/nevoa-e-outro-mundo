-- server/NOM_FogEvent.lua contra o mundo falso de tests/fog_world.lua: relógio
-- real (G.now, getTimestampMs), horas de mundo (G.world.hours, getWorldAgeHours),
-- um OnClimateTick por minuto de jogo, OnTick a 60 FPS, ModData global (G.globalMD)
-- que sobrevive à "recarga" (setup de novo com o mesmo globalMD).
local W = dofile("tests/fog_world.lua")
local FOG_FILE = "mod/42/media/lua/server/NOM_Fog.lua"

local function setup(opts)
    opts = opts or {}
    local G = W.new(opts)
    G.world.hours = opts.hours or 100
    G.reload({ "NOM_World", "NOM_FogState", "NOM_Fog", "NOM_FogEvent", "NOM_FogEventRules", "NOM_Siren", "NOM_SemRosto" })
    dofile(FOG_FILE) -- puxa o NOM_FogEvent (require), como no jogo
    function G.climate(n)
        for _ = 1, n or 1 do G.fire("OnClimateTick") end
    end
    -- h horas de jogo de uma vez (fast-forward, sono) e a leitura do minuto seguinte
    function G.advance(h)
        G.world.hours = G.world.hours + h
        G.climate()
    end
    if opts.player ~= false then G.player({ x = 0, y = 0 }) end
    G.climate()
    return G
end

local function fogMD(G) return G.globalMD.NevoaEOutroMundo.fog end

return {
    -- agenda; passou da hora, a sirene toca e a névoa vem 30 s REAIS depois
    fog_event_siren_30_real_seconds_before = function()
        local G = setup()
        assert(fogMD(G).next == 136, "próxima: " .. tostring(fogMD(G).next)) -- rand 0: 0,5 × 3 dias
        G.advance(35.9)
        assert(G.played("NOM_Siren") == 0, "sirene cedo")
        G.advance(0.1)
        assert(G.played("NOM_Siren") == 1, "sirene não tocou")
        assert(G.playing("NOM_Siren")[1].volume == 1)
        assert(NOM_World.fog == false and NOM_FogState.on == false, "névoa junto com a sirene")
        G.seconds(29.9)
        assert(NOM_World.fog == false, "névoa antes de 30 s")
        G.seconds(0.2)
        assert(NOM_World.fog == true and NOM_FogState.on == true and NOM_FogState.period == 1)
        assert(fogMD(G).endAt == G.world.hours + 2, "duração") -- rand 0: FogMinHours
        assert(#G.sentServer == 0, "solo mandou comando")
    end,
    -- dedicado: sirene e névoa vão por comando pra todos
    fog_event_mp_broadcasts_siren_and_fog = function()
        local G = setup({ server = true, player = false })
        G.advance(36)
        local siren = G.commands(G.sentServer, "siren")
        assert(#siren == 1 and siren[1].player == nil and siren[1].module == "NevoaEOutroMundo")
        assert(#G.commands(G.sentServer, "fog") == 0)
        G.seconds(30.1)
        local fog = G.commands(G.sentServer, "fog")
        assert(#fog == 1 and fog[1].args.on == true and fog[1].args.period == 1)
    end,
    -- a sirene toca uma vez, por mais minutos que passem na contagem
    fog_event_siren_once_while_counting = function()
        local G = setup()
        G.advance(36)
        for _ = 1, 10 do
            G.seconds(2)
            G.advance(1 / 60)
        end
        assert(G.played("NOM_Siren") == 1, "sirenes: " .. G.played("NOM_Siren"))
        G.seconds(11)
        G.climate(5)
        assert(NOM_World.fog and G.played("NOM_Siren") == 1)
    end,
    -- dura o sorteado, desliga e agenda a próxima entre 0,5× e 1,5× a partir do fim
    fog_event_ends_after_duration_and_reschedules = function()
        local G = setup()
        G.rand = 5000 -- rand 0,5: duração 4 h, intervalo 72 h
        G.advance(72)
        G.seconds(31)
        local endAt = fogMD(G).endAt
        assert(endAt == G.world.hours + 4)
        G.advance(3.9)
        assert(NOM_World.fog == true)
        G.advance(0.1)
        assert(NOM_World.fog == false and NOM_FogState.on == false, "não acabou")
        assert(fogMD(G).inNight == false and fogMD(G).endAt == nil)
        assert(fogMD(G).next == G.world.hours + 72, "próxima: " .. tostring(fogMD(G).next))
    end,
    -- salvar/carregar no meio do evento: volta com névoa, mesmo período, mesmo fim
    fog_event_state_survives_reload = function()
        local G = setup()
        G.advance(36)
        G.seconds(31)
        local endAt = fogMD(G).endAt
        local G2 = setup({ globalMD = G.globalMD, hours = G.world.hours + 0.5 })
        assert(NOM_World.fog == true and NOM_FogState.on == true, "carregou sem névoa")
        assert(NOM_FogState.period == 1 and fogMD(G2).night == 1, "recarga abriu período novo")
        assert(fogMD(G2).endAt == endAt)
        G2.advance(1.5)
        assert(NOM_World.fog == false, "o fim salvo não valeu")
    end,
    -- recarregar no meio da contagem: a sirene toca de novo e os 30 s recomeçam
    fog_event_reload_during_siren_restarts = function()
        local G = setup()
        G.advance(36)
        G.seconds(20)
        local G2 = setup({ globalMD = G.globalMD, hours = G.world.hours })
        assert(G2.played("NOM_Siren") == 1, "sem sirene depois da recarga")
        G2.seconds(29.9)
        assert(NOM_World.fog == false, "contagem velha valeu")
        G2.seconds(0.2)
        assert(NOM_World.fog == true and fogMD(G2).night == 1)
    end,
    -- pausado (velocidade 0 / servidor vazio com PauseEmpty) a contagem para
    fog_event_paused_holds_countdown = function()
        local G = setup()
        G.advance(36)
        G.paused = true
        G.seconds(60)
        assert(NOM_World.fog == false, "pausa consumiu a sirene")
        G.paused = false
        G.seconds(29.9)
        assert(NOM_World.fog == false)
        G.seconds(0.2)
        assert(NOM_World.fog == true)
    end,
    -- sono / fast-forward / admin pulando 30 dias: um evento só, um período só
    fog_event_no_compounding_after_long_skip = function()
        local G = setup()
        G.advance(24 * 30)
        G.climate(10)
        G.seconds(31)
        assert(fogMD(G).night == 1 and NOM_World.fog)
        G.advance(24 * 30)
        assert(NOM_World.fog == false and fogMD(G).night == 1)
        G.climate(10)
        assert(G.played("NOM_Siren") == 1, "sirenes: " .. G.played("NOM_Siren"))
    end,
    -- save da sprint 0008 salvo com névoa natural aberta: fecha, conta só o próximo
    fog_event_stale_0008_save_closes = function()
        local md = { NevoaEOutroMundo = { fog = { night = 3, inNight = true } } }
        local G = setup({ globalMD = md })
        assert(NOM_World.fog == false and md.NevoaEOutroMundo.fog.inNight == false)
        G.advance(36)
        G.seconds(31)
        assert(NOM_FogState.period == 4, "período: " .. tostring(NOM_FogState.period))
    end,
    -- cliente que entra no meio do evento pergunta e recebe o estado
    fog_event_mp_join_mid_event_gets_state = function()
        local G = setup({ server = true, player = false })
        G.advance(36)
        G.seconds(31)
        G.sentServer = {}
        local who = {}
        G.fire("OnClientCommand", "NevoaEOutroMundo", "fogState", who, {})
        assert(#G.sentServer == 1 and G.sentServer[1].player == who)
        assert(G.sentServer[1].args.on == true and G.sentServer[1].args.period == 1)
    end,
    -- stop fecha o evento ou cancela a sirene; siren(skip) começa no tick seguinte
    fog_event_stop_and_skip = function()
        local G = setup()
        assert(NOM_FogEvent.siren(true))
        assert(not NOM_FogEvent.siren(true), "duas sirenes")
        G.tick(1)
        assert(NOM_World.fog == true and NOM_FogEvent.period() == 1)
        assert(not NOM_FogEvent.siren(false), "sirene com evento aberto")
        assert(NOM_FogEvent.stop())
        assert(NOM_World.fog == false and fogMD(G).next == G.world.hours + 36)
        assert(NOM_FogEvent.siren(false))
        assert(NOM_FogEvent.stop(), "não cancelou a sirene")
        G.seconds(31)
        assert(NOM_World.fog == false, "sirene cancelada trouxe névoa")
    end,
}
