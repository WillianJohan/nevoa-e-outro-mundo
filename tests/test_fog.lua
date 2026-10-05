-- server/NOM_Fog.lua contra o mundo falso de tests/fog_world.lua: período de
-- névoa (ModData global, conta por estado como as noites), flag pros clientes
-- e o Sem-rosto do lado do servidor.
local W = dofile("tests/fog_world.lua")
local FILE = "mod/42/media/lua/server/NOM_Fog.lua"

local function setup(opts)
    opts = opts or {}
    local G = W.new(opts)
    G.world.hours = 100
    G.reload({ "NOM_World", "NOM_FogState", "NOM_Fog", "NOM_FogEvent", "NOM_FogEventRules", "NOM_Siren", "NOM_SemRosto" })
    dofile(FILE)
    -- a névoa é evento (NOM_FogEvent, ADR-009): v ≥ 0.5 abre um (sem a espera da
    -- sirene), menos que isso fecha
    function G.setFog(v)
        if v >= 0.5 then
            NOM_FogEvent.siren(true)
            G.tick(1)
        else
            NOM_FogEvent.stop()
        end
    end
    function G.clientCommand(module, command, p, args) G.fire("OnClientCommand", module, command, p, args) end
    G.fire("OnClimateTick") -- primeira leitura: agenda e acerta a flag salva
    G.setFog(opts.fog or 0)
    return G
end

return {
    -- solo: o mesmo processo é cliente, a flag vai direto pro estado local
    fog_sp_sets_state = function()
        local G = setup()
        local seen = {}
        NOM_FogState.onChange(function(on) seen[#seen + 1] = on end)
        assert(NOM_FogState.on == false)
        G.setFog(0.9)
        G.setFog(0.9)
        assert(NOM_FogState.on == true and NOM_FogState.period == 1)
        G.setFog(0)
        assert(NOM_FogState.on == false)
        assert(#seen == 2 and seen[1] == true and seen[2] == false, "bordas: " .. #seen)
        assert(#G.sentServer == 0, "solo mandou comando de rede")
    end,
    -- dedicado: avisa todo mundo na borda, com o número do período
    fog_mp_broadcasts_edge_with_period = function()
        local G = setup({ server = true })
        G.setFog(0.9)
        G.setFog(0.95)
        G.setFog(0)
        G.setFog(0.9)
        local fog = G.commands(G.sentServer, "fog")
        assert(#fog == 3, "avisos: " .. #fog)
        assert(fog[1].module == "NevoaEOutroMundo" and fog[1].args.on == true and fog[1].args.period == 1)
        assert(fog[2].args.on == false)
        assert(fog[3].args.on == true and fog[3].args.period == 2)
        assert(NOM_FogState.on == false, "dedicado mexeu no estado de cliente")
    end,
    -- reiniciar no meio da névoa não abre período novo (sorteio do Sem-rosto igual)
    fog_period_counts_once_per_fog = function()
        local G = setup({ fog = 0.9 })
        assert(NOM_FogState.period == 1)
        setup({ fog = 0.9, globalMD = G.globalMD })
        assert(NOM_FogState.period == 1, "reinício abriu névoa nova")
        assert(G.globalMD.NevoaEOutroMundo.fog.night == 1)
    end,
    -- cliente que entra no meio da névoa pergunta e recebe só pra ele
    fog_answers_state = function()
        local G = setup({ server = true, fog = 0.9 })
        G.sentServer = {}
        local who = {}
        G.clientCommand("NevoaEOutroMundo", "fogState", who, {})
        G.clientCommand("OutroMod", "fogState", who, {})
        assert(#G.sentServer == 1 and G.sentServer[1].player == who)
        assert(G.sentServer[1].command == "fog" and G.sentServer[1].args.on == true and G.sentServer[1].args.period == 1)
    end,
    -- solo: o processo é dono, vê e move; o servidor confere antes
    fog_sp_seen_moves_zombie = function()
        local G = setup({ fog = 0.9 })
        local p = G.player({ x = 100, y = 100, face = 0 })
        local z = G.zombie({ x = 112, y = 100, id = W.semRostoID(1, true) })
        G.tick(NOM_SemRosto.SCAN_TICKS)
        assert(z.teleports == 1, "não moveu")
        assert(not z:getCurrentSquare():isCanSee(0), "continua à vista")
        assert(math.sqrt((z.x - p.x) ^ 2 + (z.y - p.y) ^ 2) < 12, "não chegou mais perto")
        assert(#G.sentServer == 0, "solo mandou comando")
    end,
    -- o servidor não confia no cliente: período, variante, distância, cooldown
    fog_server_rejects_bad_move = function()
        local G = setup({ server = true, fog = 0.9 })
        local p = G.player({ x = 100, y = 100, face = 0 })
        local sem = G.zombie({ x = 112, y = 100, id = W.semRostoID(1, true), onlineID = 7 })
        local common = G.zombie({ x = 112, y = 101, id = W.semRostoID(1, false), onlineID = 8 })
        local function seen(id, x, y) G.clientCommand("NevoaEOutroMundo", "semRostoSeen", p, { id = id, x = x, y = y, z = 0 }) G.now = G.now + 1000 end
        seen(8, 95, 100)            -- não é Sem-rosto
        seen(7, 80, 100)            -- mais longe que o zumbi
        seen(7, 100, 100)           -- em cima do jogador
        seen(7, "x", 100)           -- lixo
        seen(-1, 95, 100)           -- sem ID de rede
        assert(sem.teleports == nil and common.teleports == nil, "aceitou movimento inválido")
        assert(#G.commands(G.sentServer, "semRostoMove") == 0)
        seen(7, 95, 100)
        assert(sem.teleports == 1, "recusou movimento bom")
        seen(7, 96, 100)            -- 1 s depois: cooldown
        assert(sem.teleports == 1, "piscou")
        G.setFog(0)
        G.now = G.now + 10000
        seen(7, 96, 100)            -- névoa acabou: zumbi comum
        assert(sem.teleports == 1, "Sem-rosto sem névoa")
    end,
    -- dedicado: move a cópia do servidor (vale se ninguém é dono) e manda o dono mover
    fog_server_relays_move = function()
        local G = setup({ server = true, fog = 0.9 })
        local p = G.player({ x = 100, y = 100, face = 0 })
        local z = G.zombie({ x = 112, y = 100, id = W.semRostoID(1, true), onlineID = 7 })
        G.clientCommand("NevoaEOutroMundo", "semRostoSeen", p, { id = 7, x = 95, y = 100, z = 0 })
        local mv = G.commands(G.sentServer, "semRostoMove")
        assert(#mv == 1 and mv[1].player == nil, "não avisou todos")
        assert(mv[1].args.id == 7 and mv[1].args.x == 95 and mv[1].args.y == 100 and mv[1].args.z == 0)
        assert(z.x == 95.5 and z.y == 100.5, "fora do centro do tile")
    end,
    -- fallback: o dono não aplicou (o pacote dele devolveu a posição velha); na
    -- próxima vez que é visto ali, o servidor troca por um zumbi com o mesmo ID
    fog_server_fallback_replaces_stuck = function()
        local G = setup({ server = true, fog = 0.9 })
        local p = G.player({ x = 100, y = 100, face = 0 })
        local id = W.semRostoID(1, true)
        local z = G.zombie({ x = 112, y = 100, id = id, onlineID = 7, female = true, outfit = "Doctor" })
        G.clientCommand("NevoaEOutroMundo", "semRostoSeen", p, { id = 7, x = 95, y = 100, z = 0 })
        G.ownerPacket(z, 112, 100)
        G.now = G.now + NOM_SemRostoRules.COOLDOWN_MS
        G.clientCommand("NevoaEOutroMundo", "semRostoSeen", p, { id = 7, x = 96, y = 101, z = 0 })
        assert(z.removed and z.offSquare, "o travado ficou")
        assert(#G.spawned == 1, "não spawnou o substituto")
        local nz = G.spawned[1]
        assert(nz.id == id, "substituto com outro ID (outra variante)")
        assert(nz.x == 96.5 and nz.y == 101.5 and nz.outfitName == "Doctor" and nz.femaleChance == 100)
        local gone = G.commands(G.sentServer, "semRostoGone")
        assert(#gone == 1 and gone[1].args.ids[1] == 7)
        -- andou de verdade: não é travado, segue o caminho normal
        local G2 = setup({ server = true, fog = 0.9 })
        local p2 = G2.player({ x = 100, y = 100, face = 0 })
        local z2 = G2.zombie({ x = 112, y = 100, id = id, onlineID = 7 })
        G2.clientCommand("NevoaEOutroMundo", "semRostoSeen", p2, { id = 7, x = 95, y = 100, z = 0 })
        G2.now = G2.now + NOM_SemRostoRules.COOLDOWN_MS
        G2.clientCommand("NevoaEOutroMundo", "semRostoSeen", p2, { id = 7, x = 97, y = 100, z = 0 })
        assert(#G2.spawned == 0 and z2.teleports == 2)
    end,
    -- o destino que o cliente mandou tem que ser chão de verdade no andar de quem viu
    fog_server_rejects_bad_destination = function()
        local G = setup({ server = true, fog = 0.9 })
        local p = G.player({ x = 100, y = 100, face = 0 })
        local z = G.zombie({ x = 112, y = 100, id = W.semRostoID(1, true), onlineID = 7 })
        local function seen(x, y, zz)
            G.clientCommand("NevoaEOutroMundo", "semRostoSeen", p, { id = 7, x = x, y = y, z = zz })
            G.now = G.now + 1000
        end
        seen(95, 100, 1)                    -- outro andar
        G.holes["95,101,0"] = true
        seen(95, 101, 0)                    -- sem square
        G.square(95, 102, 0).free = false
        seen(95, 102, 0)                    -- ocupado
        G.water["95,103,0"] = true
        seen(95, 103, 0)                    -- água
        assert(z.teleports == nil, "aceitou destino ruim")
        z.x = 101.5                          -- colado: ataca, não some
        seen(98, 100, 0)
        assert(z.teleports == nil, "sumiu colado no jogador")
        z.x = 112.5
        seen(95, 104, 0)
        assert(z.teleports == 1, "recusou destino bom")
    end,
    -- correu de volta pela origem depois da janela: não é travado, não troca
    fog_server_fallback_not_on_chase_back = function()
        local G = setup({ server = true, fog = 0.9 })
        local p = G.player({ x = 100, y = 100, face = 0 })
        local z = G.zombie({ x = 112, y = 100, id = W.semRostoID(1, true), onlineID = 7 })
        G.clientCommand("NevoaEOutroMundo", "semRostoSeen", p, { id = 7, x = 95, y = 100, z = 0 })
        assert(z.x == 95.5)
        G.now = G.now + 6000
        z.x, z.y = 112.2, 100.4 -- o jogador correu e ele voltou passando pela origem
        G.clientCommand("NevoaEOutroMundo", "semRostoSeen", p, { id = 7, x = 96, y = 100, z = 0 })
        assert(#G.spawned == 0, "trocou zumbi que andou de verdade")
        assert(z.teleports == 2)
        -- dentro da janela, no destino: o movimento pegou, não é travado
        local G2 = setup({ server = true, fog = 0.9 })
        local p2 = G2.player({ x = 100, y = 100, face = 0 })
        local z2 = G2.zombie({ x = 112, y = 100, id = W.semRostoID(1, true), onlineID = 7 })
        G2.clientCommand("NevoaEOutroMundo", "semRostoSeen", p2, { id = 7, x = 94, y = 100, z = 0 })
        G2.now = G2.now + NOM_SemRostoRules.COOLDOWN_MS
        G2.clientCommand("NevoaEOutroMundo", "semRostoSeen", p2, { id = 7, x = 97, y = 101, z = 0 })
        assert(#G2.spawned == 0 and z2.teleports == 2)
    end,
    -- névoa vermelha: o servidor confere o Sem-rosto com a divisão da vermelha
    fog_server_red_fog_accepts_red_semrosto = function()
        local G = setup({ server = true, sandbox = { RedFogChance = 100 } })
        G.setFog(0.9)
        assert(NOM_World.red == true)
        local p = G.player({ x = 100, y = 100, face = 0 })
        local sem = G.zombie({ x = 112, y = 100, id = W.semRostoID(1, true, nil, true), onlineID = 7 })
        G.clientCommand("NevoaEOutroMundo", "semRostoSeen", p, { id = 7, x = 95, y = 100, z = 0 })
        assert(sem.teleports == 1, "recusou o Sem-rosto da vermelha")
        local fog = G.commands(G.sentServer, "fog")
        assert(fog[#fog].args.red == true)
    end,
}
