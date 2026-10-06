-- server/NOM_FogEvent.lua contra o mundo falso de tests/fog_world.lua: relógio
-- real (G.now, getTimestampMs), horas de mundo (G.world.hours, getWorldAgeHours),
-- um OnClimateTick por minuto de jogo, OnTick a 60 FPS, ModData global (G.globalMD)
-- que sobrevive à "recarga" (setup de novo com o mesmo globalMD).
local W = dofile("tests/fog_world.lua")
local FOG_FILE = "mod/42/media/lua/server/NOM_Fog.lua"

-- Os testes do mecanismo medem com a agenda da sprint 0033 fixada: névoa todo dia
-- (chance 100), sem segunda, sem subida, folga de 6 h, duração de 2 a 6 h (rand 0 = 2 h) e
-- sem carência da vermelha. Os da agenda ligam o que medem; opts.defaults = o sandbox do
-- jogo, sem fixar nada.
local BASE = { FogDailyChance = 100, FogMaxDailyChance = 100, FogSecondChance = 0, FogEscalation = false,
    FogMinGapHours = 6, FogMaxDaysWithout = 2, FogMinHours = 2, FogMaxHours = 6,
    RedFogMinHours = 2, RedFogMaxHours = 6, RedFogGraceDays = 0, FogCalmHours = 2 }

local function setup(opts)
    opts = opts or {}
    if not opts.defaults then
        local sb = {}
        for k, v in pairs(BASE) do sb[k] = v end
        for k, v in pairs(opts.sandbox or {}) do sb[k] = v end
        opts.sandbox = sb
    end
    local G = W.new(opts)
    G.world.hours = opts.hours or 100
    G.reload({ "NOM_World", "NOM_FogState", "NOM_Fog", "NOM_FogEvent", "NOM_FogEventRules", "NOM_Siren", "NOM_SemRosto", "NOM_SirenFreeze" })
    dofile(FOG_FILE) -- puxa o NOM_FogEvent (require), como no jogo
    function G.climate(n)
        for _ = 1, n or 1 do G.fire("OnClimateTick") end
    end
    -- h horas de jogo de uma vez (fast-forward, sono) e a leitura do minuto seguinte
    function G.advance(h)
        G.world.hours = G.world.hours + h
        G.climate()
    end
    -- vai à hora de mundo exata h (nunca volta no tempo) e lê o minuto
    function G.at(h)
        if h > G.world.hours then G.world.hours = h end
        G.climate()
    end
    if opts.player ~= false then G.player({ x = 0, y = 0 }) end
    G.climate()
    return G
end

local function fogMD(G) return G.globalMD.NevoaEOutroMundo.fog end

-- Vai até a hora da sirene agendada (a que o servidor sorteou) e a deixa tocar.
local function toSiren(G)
    local n = fogMD(G).next
    assert(n ~= nil, "sem sirene agendada")
    G.at(n)
end

return {
    -- agenda do dia (shared/NOM_FogEventRules): a sirene toca na hora sorteada do dia, a
    -- névoa vem 45 s REAIS depois
    fog_event_siren_45_real_seconds_before = function()
        local G = setup()
        local want = NOM_FogEventRules.firstStart(fogMD(G).seed, NOM_FogEventRules.dayOf(100), 100)
        assert(fogMD(G).next == want, "próxima: " .. tostring(fogMD(G).next))
        G.at(want - 0.1)
        assert(G.played("NOM_Siren") == 0, "sirene cedo")
        G.at(want)
        assert(G.played("NOM_Siren") == 1, "sirene não tocou")
        assert(G.playing("NOM_Siren")[1].volume == 1)
        assert(NOM_World.fog == false and NOM_FogState.on == false, "névoa junto com a sirene")
        G.seconds(44.9)
        assert(NOM_World.fog == false, "névoa antes de 45 s")
        G.seconds(0.2)
        assert(NOM_World.fog == true and NOM_FogState.on == true and NOM_FogState.period == 1)
        assert(fogMD(G).endAt == G.world.hours + 2, "duração") -- rand 0: FogMinHours
        assert(#G.sentServer == 0, "solo mandou comando")
    end,
    -- dedicado: sirene e névoa vão por comando pra todos
    fog_event_mp_broadcasts_siren_and_fog = function()
        local G = setup({ server = true, player = false })
        toSiren(G)
        local siren = G.commands(G.sentServer, "siren")
        assert(#siren == 1 and siren[1].player == nil and siren[1].module == "NevoaEOutroMundo")
        assert(#G.commands(G.sentServer, "fog") == 0)
        G.seconds(45.1)
        local fog = G.commands(G.sentServer, "fog")
        assert(#fog == 1 and fog[1].args.on == true and fog[1].args.period == 1)
    end,
    -- a sirene leva a direção do período que vem (a mesma em toda máquina) e a cor
    fog_event_siren_sends_dir = function()
        local G = setup({ server = true, player = false })
        local period = NOM_FogEvent.period()
        toSiren(G)
        local siren = G.commands(G.sentServer, "siren")
        assert(#siren == 1)
        local want = NOM_FogEventRules.sirenDir(fogMD(G).seed, period + 1)
        assert(siren[1].args.dir == want, "dir: " .. tostring(siren[1].args.dir) .. " esperado " .. want)
        assert(siren[1].args.dir >= 0 and siren[1].args.dir < 360)
        assert(siren[1].args.red == false, "red: " .. tostring(siren[1].args.red))
        assert(NOM_FogEvent.status().sirenDir == want, "status sem a direção")
        G.seconds(45.1)
        assert(NOM_FogEvent.status().sirenDir == nil, "direção depois da sirene")
    end,
    -- a sirene toca uma vez, por mais minutos que passem na contagem
    fog_event_siren_once_while_counting = function()
        local G = setup()
        toSiren(G)
        for _ = 1, 10 do
            G.seconds(2)
            G.advance(1 / 60)
        end
        assert(G.played("NOM_Siren") == 1, "sirenes: " .. G.played("NOM_Siren"))
        G.seconds(26)
        G.climate(5)
        assert(NOM_World.fog and G.played("NOM_Siren") == 1)
    end,
    -- dura o sorteado, desliga; sem segunda névoa no dia, a próxima vem só amanhã (depois da folga)
    fog_event_ends_after_duration_and_reschedules = function()
        local G = setup()
        G.rand = 5000 -- rand 0,5: duração 4 h
        toSiren(G)
        G.seconds(46)
        local endAt = fogMD(G).endAt
        assert(endAt == G.world.hours + 4)
        G.at(endAt - 0.1)
        assert(NOM_World.fog == true)
        G.at(endAt)
        assert(NOM_World.fog == false and NOM_FogState.on == false, "não acabou")
        assert(fogMD(G).inNight == false and fogMD(G).endAt == nil)
        assert(fogMD(G).lastEnd == endAt)
        G.advance(24)
        assert(fogMD(G).next ~= nil, "sem névoa no dia seguinte")
        assert(fogMD(G).next >= endAt + 6, "sem folga: " .. tostring(fogMD(G).next - endAt))
    end,
    -- salvar/carregar no meio do evento: volta com névoa, mesmo período, mesmo fim
    fog_event_state_survives_reload = function()
        local G = setup()
        toSiren(G)
        G.seconds(46)
        local endAt = fogMD(G).endAt
        local G2 = setup({ globalMD = G.globalMD, hours = G.world.hours + 0.5 })
        assert(NOM_World.fog == true and NOM_FogState.on == true, "carregou sem névoa")
        assert(NOM_FogState.period == 1 and fogMD(G2).night == 1, "recarga abriu período novo")
        assert(fogMD(G2).endAt == endAt)
        G2.at(endAt)
        assert(NOM_World.fog == false, "o fim salvo não valeu")
    end,
    -- salvar/carregar não muda a agenda do dia: mesma semente, mesmo dia, mesma sirene
    fog_event_plan_survives_reload_and_is_deterministic = function()
        local G = setup({ rand = 4242 })
        local next1, seed = fogMD(G).next, fogMD(G).seed
        assert(next1 ~= nil)
        local G2 = setup({ globalMD = G.globalMD, hours = 100.5 })
        assert(fogMD(G2).next == next1, "recarga trocou a sirene")
        -- save sem a agenda (mesma semente e mesmo dia, de novo): sorteio igual ao do outro mundo
        local G3 = setup({ globalMD = { NevoaEOutroMundo = { fog = { seed = seed } } } })
        assert(fogMD(G3).next == next1, "o sorteio não é puro do dia e da semente")
    end,
    -- recarregar no meio da contagem: a sirene toca de novo e os 45 s recomeçam
    fog_event_reload_during_siren_restarts = function()
        local G = setup()
        toSiren(G)
        G.seconds(20)
        local G2 = setup({ globalMD = G.globalMD, hours = G.world.hours })
        assert(G2.played("NOM_Siren") == 1, "sem sirene depois da recarga")
        G2.seconds(44.9)
        assert(NOM_World.fog == false, "contagem velha valeu")
        G2.seconds(0.2)
        assert(NOM_World.fog == true and fogMD(G2).night == 1)
    end,
    -- pausado (velocidade 0 / servidor vazio com PauseEmpty) a contagem para
    fog_event_paused_holds_countdown = function()
        local G = setup()
        toSiren(G)
        G.paused = true
        G.seconds(60)
        assert(NOM_World.fog == false, "pausa consumiu a sirene")
        G.paused = false
        G.seconds(44.9)
        assert(NOM_World.fog == false)
        G.seconds(0.2)
        assert(NOM_World.fog == true)
    end,
    -- sono / fast-forward / admin pulando 30 dias: um evento só, um período só
    fog_event_no_compounding_after_long_skip = function()
        local G = setup()
        G.advance(24 * 30)
        G.climate(10)
        G.seconds(46)
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
        toSiren(G)
        G.seconds(46)
        assert(NOM_FogState.period == 4, "período: " .. tostring(NOM_FogState.period))
    end,
    -- save antigo com a sirene já agendada (data.fog.next): ela vale e conta como a do dia
    fog_event_old_save_next_still_valid = function()
        local md = { NevoaEOutroMundo = { fog = { night = 4, next = 110, seed = 3 } } }
        local G = setup({ globalMD = md, hours = 100, sandbox = { FogDailyChance = 0, FogMaxDaysWithout = 99 } })
        assert(md.NevoaEOutroMundo.fog.next == 110, "reagendou a sirene do save antigo")
        G.at(110)
        assert(G.played("NOM_Siren") == 1)
        G.seconds(46)
        assert(NOM_World.fog and NOM_FogState.period == 5)
    end,
    -- cliente que entra no meio do evento pergunta e recebe o estado
    fog_event_mp_join_mid_event_gets_state = function()
        local G = setup({ server = true, player = false })
        toSiren(G)
        G.seconds(46)
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
        assert(NOM_World.fog == false and fogMD(G).next == nil, "próxima: " .. tostring(fogMD(G).next))
        assert(NOM_FogEvent.siren(false))
        assert(NOM_FogEvent.stop(), "não cancelou a sirene")
        G.seconds(46)
        assert(NOM_World.fog == false, "sirene cancelada trouxe névoa")
    end,
    -- review 1: NOM_Debug.fog(false) cancela a sirene que a AGENDA tocou; o next some,
    -- senão o minuto seguinte tocaria de novo e a névoa viria
    fog_event_stop_cancels_scheduled_siren = function()
        local G = setup()
        toSiren(G)
        assert(G.played("NOM_Siren") == 1)
        assert(NOM_FogEvent.stop(), "não cancelou")
        G.climate()
        G.seconds(46)
        assert(NOM_World.fog == false, "névoa veio depois de cancelar")
        assert(G.played("NOM_Siren") == 1, "sirene tocou de novo: " .. G.played("NOM_Siren"))
        assert(fogMD(G).next == nil and fogMD(G).night == nil)
    end,
    -- dedicado: cancelar a sirene avisa todo mundo (o congelamento para) e não toca de novo
    fog_event_cancel_sends_siren_stop = function()
        local G = setup({ server = true, player = false })
        assert(not NOM_FogEvent.stop(), "cancelou sem sirene")
        assert(#G.commands(G.sentServer, "sirenStop") == 0, "sirenStop sem sirene")
        toSiren(G)
        assert(#G.commands(G.sentServer, "siren") == 1)
        assert(NOM_FogEvent.stop())
        local stop = G.commands(G.sentServer, "sirenStop")
        assert(#stop == 1 and stop[1].player == nil and stop[1].module == "NevoaEOutroMundo", "sem sirenStop")
        G.advance(1 / 60)
        G.climate(2)
        G.seconds(46)
        assert(#G.commands(G.sentServer, "siren") == 1, "tocou de novo no minuto seguinte")
        assert(#G.commands(G.sentServer, "fog") == 0 and NOM_World.fog == false)
        -- evento aberto: o stop fecha a névoa e não manda sirenStop
        local G2 = setup({ server = true, player = false })
        toSiren(G2)
        G2.seconds(46)
        assert(NOM_FogEvent.stop())
        assert(#G2.commands(G2.sentServer, "sirenStop") == 0)
    end,
    -- solo: o congelamento (shared/NOM_SirenFreeze) começa com a sirene, vira pra direção
    -- dela e solta quando ela é cancelada ou a névoa abre
    fog_event_solo_siren_freezes = function()
        local G = setup()
        local a = G.zombie({ x = 10, y = 10 })
        toSiren(G)
        G.tick(1)
        assert(NOM_SirenFreeze.active and a.useless == true, "a sirene não congelou")
        local dir = math.rad(NOM_FogEventRules.sirenDir(fogMD(G).seed, 1))
        assert(math.abs(a.faced.x - (a.x + NOM_SirenFreeze.FAR * math.cos(dir))) < 1e-6, "virou pra outra direção")
        assert(math.abs(a.faced.y - (a.y + NOM_SirenFreeze.FAR * math.sin(dir))) < 1e-6)
        assert(NOM_FogEvent.stop())
        assert(a.useless == false and not NOM_SirenFreeze.active, "cancelar não soltou")
        G.at(G.world.hours + 24)
        toSiren(G)
        G.tick(1)
        assert(a.useless == true)
        G.seconds(46)
        assert(NOM_World.fog and a.useless == false and not NOM_SirenFreeze.active, "a névoa não soltou")
    end,
    -- dedicado: o servidor não simula zumbi; quem congela é o cliente dono (nada instalado aqui)
    fog_event_dedicated_does_not_freeze = function()
        local G = setup({ server = true, player = false })
        local a = G.zombie({ x = 10, y = 10 })
        toSiren(G)
        G.tick(2)
        assert(not NOM_SirenFreeze.active and not a.useless)
        assert(#G.handlers.OnTick == 1, "o servidor registrou o tick do congelamento")
    end,
    -- review 2: quem entra no MP durante a contagem ouve a sirene (com a direção)
    fog_event_mp_join_during_siren_hears_it = function()
        local G = setup({ server = true, player = false })
        toSiren(G)
        G.seconds(10)
        G.sentServer = {}
        local who = {}
        G.fire("OnClientCommand", "NevoaEOutroMundo", "fogState", who, {})
        local siren = G.commands(G.sentServer, "siren")
        assert(#siren == 1 and siren[1].player == who, "entrou na contagem sem sirene")
        assert(siren[1].args.dir == NOM_FogEventRules.sirenDir(fogMD(G).seed, 1), "sirene atrasada sem a direção")
        assert(siren[1].args.red == false)
        G.seconds(36)
        G.sentServer = {}
        G.fire("OnClientCommand", "NevoaEOutroMundo", "fogState", who, {})
        assert(#G.commands(G.sentServer, "siren") == 0, "sirene depois da névoa aberta")
    end,
    -- calmaria (sprint 0033): vale por FogCalmHours depois do fim, nunca durante a névoa
    fog_event_calm_after_end = function()
        local G = setup()
        assert(NOM_World.calm == false)
        toSiren(G)
        G.seconds(46)
        assert(NOM_World.calm == false, "calmaria durante a névoa")
        local endAt = fogMD(G).endAt
        G.at(endAt - 0.1)
        assert(NOM_World.fog and NOM_World.calm == false)
        G.at(endAt)
        assert(NOM_World.fog == false and NOM_World.calm == true, "sem calmaria depois do fim")
        G.at(endAt + 1.99)
        assert(NOM_World.calm == true, "calmaria acabou cedo")
        G.at(endAt + 2.01)
        assert(NOM_World.calm == false, "calmaria não acabou")
    end,
    -- a calmaria avisa só na borda
    fog_event_calm_notifies_edges = function()
        local G = setup()
        local seen = {}
        NOM_World.onChange(function(flag, on) if flag == "calm" then seen[#seen + 1] = tostring(on) end end)
        toSiren(G)
        G.seconds(46)
        local endAt = fogMD(G).endAt
        G.at(endAt)
        G.climate(3)
        G.at(endAt + 2.01)
        G.climate(3)
        assert(table.concat(seen, ",") == "true,false", table.concat(seen, ","))
    end,
    -- fechar o evento no debug (stop) também liga a calmaria
    fog_event_calm_after_debug_stop = function()
        local G = setup()
        assert(NOM_FogEvent.siren(true))
        G.tick(1)
        assert(NOM_FogEvent.stop())
        assert(NOM_World.calm == true, "debug stop sem calmaria")
    end,
    -- calmaria salva: recarregar logo depois do fim continua em calmaria
    fog_event_calm_survives_reload = function()
        local G = setup()
        toSiren(G)
        G.seconds(46)
        local endAt = fogMD(G).endAt
        G.at(endAt)
        local G2 = setup({ globalMD = G.globalMD, hours = endAt + 1 })
        assert(NOM_World.calm == true, "recarga perdeu a calmaria")
    end,
    -- névoa vermelha (sprint 0010): decidida na sirene (período que vem), sirene
    -- própria, flag no mundo e no FogState, salva no ModData
    fog_event_red_decided_at_siren = function()
        local G = setup({ sandbox = { RedFogChance = 100 } })
        toSiren(G)
        assert(G.played("NOM_SirenRed") == 1 and G.played("NOM_Siren") == 0, "sirene errada")
        assert(NOM_FogEvent.status().sirenRed == true)
        assert(NOM_World.red == false, "vermelha antes da névoa")
        G.seconds(46)
        assert(NOM_World.fog and NOM_World.red == true and NOM_FogState.red == true)
        assert(fogMD(G).red == true)
    end,
    -- a vermelha tem duração própria (RedFogMinHours..RedFogMaxHours)
    fog_event_red_has_own_duration = function()
        local G = setup({ sandbox = { RedFogChance = 100, RedFogMinHours = 4, RedFogMaxHours = 6 } })
        toSiren(G)
        G.seconds(46)
        assert(NOM_World.red and fogMD(G).endAt == G.world.hours + 4, "duração da vermelha")
    end,
    fog_event_red_chance_zero_or_disabled_is_normal = function()
        for _, sb in ipairs({ { RedFogChance = 0 }, { RedFogEnabled = false, RedFogChance = 100 } }) do
            local G = setup({ sandbox = sb })
            toSiren(G)
            G.seconds(46)
            assert(G.played("NOM_Siren") == 1 and G.played("NOM_SirenRed") == 0)
            assert(NOM_World.fog and NOM_World.red == false and fogMD(G).red == false)
        end
    end,
    -- recarregar no meio da vermelha: continua vermelha, mesmo com o sandbox mudado
    fog_event_red_reload_mid_fog_stays_red = function()
        local G = setup({ sandbox = { RedFogChance = 100 } })
        toSiren(G)
        G.seconds(46)
        local G2 = setup({ globalMD = G.globalMD, hours = G.world.hours + 0.5, sandbox = { RedFogChance = 0 } })
        assert(NOM_World.fog and NOM_World.red == true and NOM_FogState.red == true, "recarga perdeu o vermelho")
        assert(NOM_FogState.period == 1)
        assert(G2.played("NOM_SirenRed") == 0 and G2.played("NOM_Siren") == 0, "recarga tocou sirene")
    end,
    -- o sorteio é do período: o mesmo período dá a mesma resposta pelo sorteio puro
    fog_event_red_matches_pure_roll = function()
        require "NOM_VariantRules"
        local c = NOM_VariantRules.config(function(k) return ({ RedFogEnabled = true, RedFogChance = 50 })[k] end)
        local G = setup({ sandbox = { RedFogChance = 50 } })
        local seed = fogMD(G).seed
        for p = 1, 6 do
            G.advance(48)
            toSiren(G)
            G.seconds(46)
            assert(NOM_FogEvent.period() == p, "período " .. NOM_FogEvent.period() .. " esperado " .. p)
            assert(NOM_World.red == NOM_VariantRules.redFog(p, c, seed), "período " .. p)
            G.advance(10)
        end
    end,
    -- fim da vermelha: flag limpa; o próximo evento sorteia de novo
    fog_event_red_ends_clean = function()
        local G = setup({ sandbox = { RedFogChance = 100 } })
        toSiren(G)
        G.seconds(46)
        G.advance(3)
        assert(NOM_World.fog == false and NOM_World.red == false and NOM_FogState.red == false)
        assert(fogMD(G).red == nil)
        SandboxVars.NevoaEOutroMundo.RedFogChance = 0
        G.advance(24)
        toSiren(G)
        G.seconds(46)
        assert(NOM_World.fog and NOM_World.red == false)
        assert(G.played("NOM_Siren") == 1 and G.played("NOM_SirenRed") == 1)
    end,
    -- dedicado: siren e fog levam o red; quem entra recebe
    fog_event_red_mp_broadcast = function()
        local G = setup({ server = true, player = false, sandbox = { RedFogChance = 100 } })
        toSiren(G)
        local siren = G.commands(G.sentServer, "siren")
        assert(#siren == 1 and siren[1].args.red == true)
        local who = {}
        G.sentServer = {}
        G.fire("OnClientCommand", "NevoaEOutroMundo", "fogState", who, {})
        siren = G.commands(G.sentServer, "siren")
        assert(#siren == 1 and siren[1].player == who and siren[1].args.red == true, "entrou na contagem sem a sirene vermelha")
        G.seconds(46)
        local fog = G.commands(G.sentServer, "fog")
        assert(fog[#fog].args.on == true and fog[#fog].args.red == true)
        G.sentServer = {}
        G.fire("OnClientCommand", "NevoaEOutroMundo", "fogState", who, {})
        assert(G.sentServer[1].args.red == true and G.sentServer[1].args.on == true)
    end,
    -- NOM_Debug.redFog: sem evento, toca a sirene vermelha e abre vermelha; com o
    -- evento aberto, troca na hora (e avisa); false desfaz
    fog_event_set_red_starts_red_event = function()
        local G = setup({ sandbox = { RedFogChance = 0 } })
        assert(NOM_FogEvent.setRed(true))
        assert(G.played("NOM_SirenRed") == 1, "sem sirene vermelha")
        G.seconds(46)
        assert(NOM_World.fog and NOM_World.red and fogMD(G).red == true)
        -- o forçado vale só pra esse evento
        NOM_FogEvent.stop()
        G.advance(24)
        toSiren(G)
        G.seconds(46)
        assert(NOM_World.fog and NOM_World.red == false, "forçado vazou pro evento seguinte")
    end,
    fog_event_set_red_flips_open_event = function()
        local G = setup({ server = true, player = false, sandbox = { RedFogChance = 0 } })
        toSiren(G)
        G.seconds(46)
        assert(NOM_World.red == false)
        G.sentServer = {}
        assert(NOM_FogEvent.setRed(true))
        assert(NOM_World.red and fogMD(G).red == true)
        local fog = G.commands(G.sentServer, "fog")
        assert(#fog == 1 and fog[1].args.on == true and fog[1].args.red == true, "não avisou os clientes")
        G.climate(3)
        assert(NOM_World.red, "o minuto seguinte desfez")
        assert(NOM_FogEvent.setRed(false))
        assert(NOM_World.red == false and fogMD(G).red == false)
        assert(#G.commands(G.sentServer, "fog") == 2)
    end,
    -- durante a contagem: a névoa que vem segue o pedido
    fog_event_set_red_during_siren = function()
        local G = setup({ sandbox = { RedFogChance = 0 } })
        toSiren(G)
        assert(NOM_FogEvent.setRed(true))
        assert(G.played("NOM_Siren") == 1 and G.played("NOM_SirenRed") == 0, "tocou duas sirenes")
        G.seconds(46)
        assert(NOM_World.red == true)
    end,
    -- NOM_FogEvent.force (sprint 0033, debug setFog/setRedFog): a cor pedida vale sempre,
    -- mesmo com a chance sorteando o contrário
    fog_event_force_white_beats_red_chance = function()
        local G = setup({ sandbox = { RedFogChance = 100 } })
        assert(NOM_FogEvent.force(false))
        assert(G.played("NOM_Siren") == 1 and G.played("NOM_SirenRed") == 0, "sirene vermelha com branco forçado")
        assert(NOM_FogEvent.status().sirenMs == 45000, "sem a contagem de 45 s")
        G.seconds(46)
        assert(NOM_World.fog and NOM_World.red == false and fogMD(G).red == false, "saiu vermelha")
        -- o forçado vale só pra esse evento: o seguinte sorteia (100% vermelha)
        NOM_FogEvent.stop()
        G.advance(24)
        toSiren(G)
        G.seconds(46)
        assert(NOM_World.fog and NOM_World.red == true, "forçado branco vazou")
    end,
    fog_event_force_red_beats_white_chance = function()
        local G = setup({ sandbox = { RedFogChance = 0 } })
        assert(NOM_FogEvent.force(true))
        assert(G.played("NOM_SirenRed") == 1 and G.played("NOM_Siren") == 0)
        G.seconds(46)
        assert(NOM_World.fog and NOM_World.red == true)
    end,
    -- skip: a sirene toca e a névoa abre no próximo tick, sem a contagem de 45 s
    fog_event_force_skip_opens_without_countdown = function()
        local G = setup({ sandbox = { RedFogChance = 0 } })
        assert(NOM_FogEvent.force(true, true))
        assert(G.played("NOM_SirenRed") == 1, "sem sirene vermelha")
        assert(NOM_FogEvent.status().sirenMs == 0 and NOM_World.fog == false)
        G.tick(1)
        assert(NOM_World.fog and NOM_World.red == true and NOM_FogState.red == true, "não abriu vermelha")
        assert(NOM_FogEvent.status().sirenMs == nil, "contagem sobrou")
    end,
    -- névoa aberta (vermelha ou branca): termina e abre de novo na cor pedida, com período novo
    fog_event_force_reopens_open_fog_in_other_color = function()
        local G = setup({ sandbox = { RedFogChance = 100 } })
        toSiren(G)
        G.seconds(46)
        assert(NOM_World.fog and NOM_World.red == true and NOM_FogState.period == 1)
        assert(NOM_FogEvent.force(false, true))
        G.tick(1)
        assert(NOM_World.fog and NOM_World.red == false and NOM_FogState.period == 2, "não reabriu branca")
        assert(NOM_FogState.red == false)
        assert(NOM_FogEvent.force(true, true))
        G.tick(1)
        assert(NOM_World.fog and NOM_World.red == true and NOM_FogState.period == 3, "não reabriu vermelha")
    end,
    -- o stop do evento aberto liga a calmaria; a névoa nova não pode herdá-la
    fog_event_force_reopen_has_no_calm = function()
        local G = setup()
        toSiren(G)
        G.seconds(46)
        assert(NOM_FogEvent.force(false)) -- fecha (calmaria ligaria) e toca a sirene nova
        assert(NOM_World.calm == false, "calmaria durante a sirene da névoa forçada")
        G.seconds(46)
        assert(NOM_World.fog and NOM_World.calm == false, "névoa aberta em calmaria")
        assert(fogMD(G).calmUntil == nil)
        G.climate(3)
        assert(NOM_World.fog and NOM_World.calm == false)
    end,
    -- sirene contando: cancela (sirenStop no dedicado) e toca de novo na cor pedida
    fog_event_force_restarts_counting_siren = function()
        local G = setup({ server = true, player = false, sandbox = { RedFogChance = 0 } })
        toSiren(G)
        G.seconds(10)
        G.sentServer = {}
        assert(NOM_FogEvent.force(true))
        assert(#G.commands(G.sentServer, "sirenStop") == 1, "não cancelou a sirene que contava")
        local siren = G.commands(G.sentServer, "siren")
        assert(#siren == 1 and siren[1].args.red == true, "nova sirene sem a cor pedida")
        assert(NOM_FogEvent.status().sirenMs == 45000, "contagem não recomeçou")
        G.seconds(46)
        assert(NOM_World.fog and NOM_World.red == true)
    end,
    -- semente do mundo (review): sorteada uma vez com ZombRand, salva no data.fog,
    -- a mesma depois de recarregar; save antigo sem ela ganha uma no primeiro uso
    fog_event_world_seed_saved_once = function()
        local G = setup({ rand = 777777 })
        local seed = fogMD(G).seed
        assert(seed == 777777 % 67108859 and seed == math.floor(seed), "semente: " .. tostring(seed))
        local G2 = setup({ globalMD = G.globalMD, rand = 5 })
        assert(fogMD(G2).seed == seed, "recarga trocou a semente")
        local old = { NevoaEOutroMundo = { fog = { night = 4, next = 500 } } }
        local G3 = setup({ globalMD = old, rand = 99 })
        assert(old.NevoaEOutroMundo.fog.seed == 99, "save antigo sem semente")
        assert(old.NevoaEOutroMundo.fog.night == 4)
    end,
    -- semente diferente, vermelha diferente: o mesmo período sai vermelho num mundo e não no outro
    fog_event_red_depends_on_world_seed = function()
        require "NOM_VariantRules"
        local c = NOM_VariantRules.config(function(k) return ({ RedFogEnabled = true, RedFogChance = 50 })[k] end)
        local a, b
        for s = 1, 100 do
            if NOM_VariantRules.redFog(1, c, s) and not a then a = s end
            if not NOM_VariantRules.redFog(1, c, s) and not b then b = s end
        end
        assert(a and b, "a semente não muda o período 1")
        for _, s in ipairs({ a, b }) do
            local G = setup({ sandbox = { RedFogChance = 50 }, globalMD = { NevoaEOutroMundo = { fog = { seed = s } } } })
            toSiren(G)
            G.seconds(46)
            assert(NOM_World.red == NOM_VariantRules.redFog(1, c, s), "semente " .. s)
        end
    end,
    -- bornAt (sprint 0019, agora só pra carência da vermelha) -------------------------

    -- bornAt gravado uma vez (como a semente); save antigo ganha no primeiro uso, e a
    -- carência dele começa ali
    fog_event_born_at_saved_once = function()
        local G = setup({ hours = 100 })
        assert(fogMD(G).bornAt == 100, "bornAt: " .. tostring(fogMD(G).bornAt))
        setup({ globalMD = G.globalMD, hours = 900 })
        assert(fogMD(G).bornAt == 100, "recarga trocou o bornAt")
        -- save veterano (já tem agenda, sem bornAt): nasce 30 dias atrás, longe da carência
        local old = { NevoaEOutroMundo = { fog = { night = 4, next = 5000, seed = 3 } } }
        setup({ globalMD = old, hours = 4800 })
        assert(old.NevoaEOutroMundo.fog.bornAt == 4800 - 30 * 24, "veterano: " .. tostring(old.NevoaEOutroMundo.fog.bornAt))
        assert(old.NevoaEOutroMundo.fog.next == 5000, "save antigo reagendado")
        local only = { NevoaEOutroMundo = { fog = { night = 2, seed = 3 } } }
        setup({ globalMD = only, hours = 800 })
        assert(only.NevoaEOutroMundo.fog.bornAt == 800 - 30 * 24, "veterano só com night")
    end,
    -- bornAt no futuro (relógio voltou, save editado): vira agora
    fog_event_born_at_clamped_to_now = function()
        local md = { NevoaEOutroMundo = { fog = { bornAt = 9000, seed = 3 } } }
        setup({ globalMD = md, hours = 100 })
        assert(md.NevoaEOutroMundo.fog.bornAt == 100, "bornAt: " .. tostring(md.NevoaEOutroMundo.fog.bornAt))
    end,
    -- veterano não sente a carência (nasce 30 dias atrás, a carência é no máximo 60 mas aqui 7)
    fog_event_veteran_no_grace_no_change = function()
        local md = { NevoaEOutroMundo = { fog = { night = 4, next = 110, seed = 3 } } }
        local G = setup({ globalMD = md, hours = 100,
            sandbox = { FogEscalation = true, RedFogGraceDays = 7, RedFogChance = 100 } })
        G.advance(10)
        assert(G.played("NOM_SirenRed") == 1, "veterano caiu na carência")
        G.seconds(46)
        assert(NOM_World.fog and NOM_World.red == true)
    end,
    -- critério 2: carência 7, chance 100: 50 névoas forçadas antes do dia 7, nenhuma
    -- vermelha; no dia 7 já pode (a chance é só a do sandbox, sem a subida da 0019)
    fog_event_red_grace = function()
        local G = setup({ sandbox = { FogEscalation = true, RedFogGraceDays = 7, RedFogChance = 100 }, hours = 100 })
        for i = 1, 50 do
            G.world.hours = 100 + i * 3.3 -- até o dia 6,9
            assert(NOM_FogEvent.siren(true))
            G.tick(1)
            assert(NOM_World.fog and NOM_World.red == false, "vermelha na carência, névoa " .. i)
            NOM_FogEvent.stop()
        end
        assert(G.played("NOM_SirenRed") == 0)
        G.world.hours = 100 + 7 * 24
        assert(NOM_FogEvent.siren(true))
        G.tick(1)
        assert(NOM_World.red == true, "dia 7 sem vermelha")
    end,
    -- o debug vence a carência: NOM_Debug.redFog(true) no dia 0 abre vermelha
    fog_event_debug_red_ignores_grace = function()
        local G = setup({ sandbox = { RedFogGraceDays = 7, RedFogChance = 100 }, hours = 100 })
        assert(NOM_FogEvent.setRed(true))
        G.seconds(46)
        assert(NOM_World.fog and NOM_World.red == true)
    end,
    -- critério 3: a vermelha é decidida na sirene e salva; recarregar durante a sirene
    -- toca a vermelha de novo e abre vermelha, mesmo com a chance zerada no sandbox
    -- (ou pela carência: maior que o dia)
    fog_event_red_saved_at_siren_survives_reload = function()
        for _, sb in ipairs({ { RedFogChance = 0 }, { RedFogChance = 100, RedFogGraceDays = 60 } }) do
            local G = setup({ sandbox = { RedFogChance = 100 } })
            toSiren(G)
            assert(G.played("NOM_SirenRed") == 1 and fogMD(G).red == true, "não salvou na sirene")
            G.seconds(10)
            local G2 = setup({ globalMD = G.globalMD, hours = G.world.hours, sandbox = sb })
            assert(G2.played("NOM_SirenRed") == 1 and G2.played("NOM_Siren") == 0, "recarga tocou a sirene errada")
            assert(NOM_FogEvent.status().sirenRed == true)
            G2.seconds(46)
            assert(NOM_World.fog and NOM_World.red == true, "recarga perdeu a vermelha da sirene")
        end
    end,
    -- sirene cancelada esquece a vermelha: a próxima sorteia de novo
    fog_event_cancelled_siren_forgets_red = function()
        local G = setup({ sandbox = { RedFogChance = 100 } })
        toSiren(G)
        assert(fogMD(G).red == true)
        NOM_FogEvent.stop()
        assert(fogMD(G).red == nil, "vermelha da sirene cancelada ficou salva")
        SandboxVars.NevoaEOutroMundo.RedFogChance = 0
        G.advance(24)
        toSiren(G)
        G.seconds(46)
        assert(NOM_World.fog and NOM_World.red == false)
    end,
    -- review da 0019: o log da sirene diz a chance sorteada; na recarga durante a sirene a
    -- cor salva é reaproveitada e a chance sai "-" (não houve sorteio)
    fog_event_siren_log_reused_colour = function()
        local realPrint, lines = print, {}
        print = function(m) lines[#lines + 1] = m end
        local ok, err = pcall(function()
            local G = setup({ sandbox = { RedFogChance = 100 }, debug = true })
            toSiren(G)
            G.seconds(10)
            setup({ globalMD = G.globalMD, hours = G.world.hours, debug = true })
        end)
        print = realPrint
        assert(ok, err)
        local sirens = {}
        for _, l in ipairs(lines) do
            if l:find("nevoa sirene", 1, true) then sirens[#sirens + 1] = l end
        end
        assert(sirens[1] and sirens[1]:find("vermelha=true", 1, true) and sirens[1]:find("chance=100.00", 1, true),
            "primeira sirene: " .. tostring(sirens[1]))
        assert(#sirens == 2 and sirens[2]:find("vermelha=true", 1, true) and sirens[2]:find("chance=-", 1, true),
            "sirene da recarga: " .. tostring(sirens[2]))
    end,
}
