-- shared/NOM_SirenFreeze.lua contra o mundo falso (tests/fog_world.lua): a sirene congela
-- os zumbis que este processo simula, virados pro jogador vivo mais próximo, e o fim solta.
local W = dofile("tests/fog_world.lua")
require "NOM_FogEventRules"
local GRACE_MS = NOM_FogEventRules.GRACE_MS

local function setup(opts)
    local G = W.new(opts or {})
    G.reload({ "NOM_SirenFreeze", "NOM_Carpideira", "NOM_VariantAI", "NOM_NightStats", "NOM_FogState" })
    require "NOM_Carpideira"
    require "NOM_SirenFreeze"
    return G
end

-- o fim da fuga no MP, com a posse do zumbi chegando depois: os de sempre e um Estalador que
-- ESTE processo cegou (NOM_VariantAI.blinded, o módulo de verdade)
local function lateOwners(G)
    require "NOM_VariantAI"
    local z = {
        inherited = G.zombie({ x = 1, y = 1 }),
        still = G.zombie({ x = 2, y = 2 }),
        game = G.zombie({ x = 3, y = 3, outfit = "Useless" }),
        remote = G.zombie({ x = 4, y = 4, remote = true }),
        blind = G.zombie({ x = 5, y = 5 }),
    }
    for _, v in pairs(z) do v.useless = true end
    NOM_Carpideira.still[z.still] = true
    NOM_VariantAI.blinded[z.blind] = { p = G.players[1], n = 0 }
    return z
end

local function facing(z, p)
    return z.faced ~= nil and math.abs(z.faced.x - p.x) < 1e-6 and math.abs(z.faced.y - p.y) < 1e-6
end

return {
    -- visto no jogo (solo, 2026-10-06): "congelados=0 ... pulados remoto=20". No solo ninguém
    -- é dono de rede, e o isRemoteZombie() dava true pra todo zumbi (pz-api-notes §24)
    siren_freeze_solo_freezes_all = function()
        local G = setup()
        local p = G.player({ x = 30, y = 10 })
        local zs = {}
        for i = 1, 5 do zs[i] = G.zombie({ x = i, y = 0 }) end
        NOM_SirenFreeze.start(GRACE_MS)
        NOM_SirenFreeze.tick()
        for i, z in ipairs(zs) do
            assert(z.useless == true and NOM_SirenFreeze.frozen[z], "solo: zumbi " .. i .. " não congelou")
            assert(facing(z, p), "solo: zumbi " .. i .. " não virou")
        end
        NOM_SirenFreeze.stop()
        for _, z in ipairs(zs) do assert(z.useless == false, "solo: não soltou") end
    end,
    -- review final da 0036: o cego da visão curta ou do Estalador (NOM_VariantAI.blinded) já
    -- está parado pela regra dele; a sirene não o pega, senão o stop soltaria o useless dele
    siren_freeze_hold_skips_blinded = function()
        local G = setup()
        require "NOM_VariantAI"
        G.player({ x = 30, y = 10 })
        local z = G.zombie({ x = 5, y = 5 })
        z.useless = true
        NOM_VariantAI.blinded[z] = { p = G.players[1], n = 0, common = true, x = 5, y = 5, t = 0 }
        NOM_SirenFreeze.start(GRACE_MS)
        NOM_SirenFreeze.tick()
        assert(not NOM_SirenFreeze.frozen[z] and z.faced == nil, "a sirene pegou o cego")
        NOM_SirenFreeze.stop()
        assert(z.useless == true, "o stop soltou o cego")
    end,
    -- MP: a cópia remota (dono é outro cliente) não é tocada
    siren_freeze_holds_local_zombies_facing_player = function()
        local G = setup({ client = true })
        local p = G.player({ x = 30, y = 10 })
        local a = G.zombie({ x = 10, y = 10 })
        local b = G.zombie({ x = 20, y = 20, remote = true })
        NOM_SirenFreeze.start(GRACE_MS)
        for _ = 1, 3 do NOM_SirenFreeze.tick() end
        assert(a.useless == true and a.target == nil and NOM_SirenFreeze.frozen[a])
        assert(facing(a, p), "não virou pro jogador")
        assert(not b.useless and not NOM_SirenFreeze.frozen[b] and b.faced == nil, "cópia remota é do dono")
    end,
    -- quem já andava quando a sirene tocou (perambulando, indo pra um som) para também: o
    -- useless sozinho não interrompe o PathFindState (teste no jogo, 2026-10-06)
    siren_freeze_stops_walking_zombies = function()
        local G = setup()
        local p = G.player({ x = 30, y = 10 })
        local a = G.zombie({ x = 10, y = 10, walking = true })
        NOM_SirenFreeze.start(GRACE_MS)
        NOM_SirenFreeze.tick()
        assert(not a:isMoving(), "continuou andando")
        assert(a.path == nil and a.pathCancelled, "o caminho ficou")
        assert(facing(a, p))
        -- voltou a andar no meio da sirene (o jogo refez o caminho): a passada seguinte para de novo
        a.vars.bPathfind, a.path = true, {}
        NOM_SirenFreeze.tick()
        assert(not a:isMoving() and a.path == nil, "andou de novo e ninguém parou")
    end,
    -- solo com tela dividida: cada zumbi olha pro jogador vivo mais perto dele
    siren_freeze_each_zombie_faces_nearest = function()
        local G = setup()
        local p1 = G.player({ x = 0, y = 0 })
        local p2 = G.player({ x = 100, y = 0 })
        local dead = G.player({ x = 52, y = 0 })
        dead.dead = true
        local a = G.zombie({ x = 40, y = 5 })
        local b = G.zombie({ x = 60, y = -5 })
        NOM_SirenFreeze.start(GRACE_MS)
        NOM_SirenFreeze.tick()
        assert(facing(a, p1), "a não olhou pro jogador 1")
        assert(facing(b, p2), "b não olhou pro jogador 2")
    end,
    -- o giro é refeito a cada passada do lote: acompanha o jogador andando
    siren_freeze_turn_follows_player = function()
        local G = setup()
        local p = G.player({ x = 10, y = 0 })
        local a = G.zombie({ x = 0, y = 0 })
        NOM_SirenFreeze.start(GRACE_MS)
        NOM_SirenFreeze.tick()
        assert(facing(a, p))
        p.x, p.y = -20.5, 15.5
        NOM_SirenFreeze.tick()
        assert(facing(a, p), "o giro não acompanhou o jogador")
    end,
    -- MP: o cliente dono olha também os jogadores que conhece pelo getOnlinePlayers()
    siren_freeze_client_sees_remote_players = function()
        local G = setup({ client = true })
        G.player({ x = 0, y = 0 })
        local other = G.player({ x = 50, y = 0, remote = true })
        local a = G.zombie({ x = 45, y = 0 })
        NOM_SirenFreeze.start(GRACE_MS)
        NOM_SirenFreeze.tick()
        assert(facing(a, other), "não olhou pro jogador do outro cliente")
    end,
    -- sem jogador vivo por perto: congela e fica como está
    siren_freeze_no_player_near_keeps_facing = function()
        local G = setup()
        local z = G.zombie({ x = 1, y = 1 })
        NOM_SirenFreeze.start(GRACE_MS)
        NOM_SirenFreeze.tick()
        assert(z.useless == true and z.faced == nil, "sem jogador e virou")
        local H = setup()
        H.player({ x = 0, y = 0 })
        local far = H.zombie({ x = NOM_SirenFreeze.RANGE + 10, y = 0 })
        NOM_SirenFreeze.start(GRACE_MS)
        NOM_SirenFreeze.tick()
        assert(far.useless == true and far.faced == nil, "virou pra jogador longe demais")
    end,
    siren_freeze_drops_target_of_chasing_zombie = function()
        local G = setup()
        local p = G.player({ x = 0, y = 0 })
        local a = G.zombie({ x = 5, y = 5 })
        a:spotted(p, true)
        assert(a.target == p)
        NOM_SirenFreeze.start(GRACE_MS)
        NOM_SirenFreeze.tick()
        assert(a.target == nil and a:isUseless())
        a:spotted(p, true) -- o jogo tenta de novo: useless não pega alvo
        assert(a.target == nil, "voltou a perseguir durante a sirene")
    end,
    siren_freeze_stop_releases = function()
        local G = setup()
        local a = G.zombie({ x = 1, y = 1 })
        NOM_SirenFreeze.start(GRACE_MS)
        NOM_SirenFreeze.tick()
        NOM_SirenFreeze.stop()
        assert(a.useless == false and next(NOM_SirenFreeze.frozen) == nil and not NOM_SirenFreeze.active)
        NOM_SirenFreeze.tick()
        assert(a.useless == false, "tick sem sirene voltou a congelar")
    end,
    siren_freeze_keeps_still_carpideira = function()
        local G = setup()
        local a = G.zombie({ x = 1, y = 1 })
        NOM_SirenFreeze.start(GRACE_MS)
        NOM_SirenFreeze.tick()
        NOM_Carpideira.still[a] = true
        NOM_SirenFreeze.stop()
        assert(a.useless == true, "soltou a Carpideira parada")
    end,
    siren_freeze_safety_timeout = function()
        local G = setup()
        local a = G.zombie({ x = 1, y = 1 })
        NOM_SirenFreeze.start(GRACE_MS)
        NOM_SirenFreeze.tick()
        G.now = G.now + GRACE_MS + NOM_SirenFreeze.SAFETY_MS + 1
        NOM_SirenFreeze.tick()
        assert(a.useless == false and not NOM_SirenFreeze.active, "ficou congelado sem fim")
    end,
    siren_freeze_idle_without_siren = function()
        local G = setup()
        local a = G.zombie({ x = 1, y = 1 })
        NOM_SirenFreeze.tick()
        assert(not a.useless)
    end,
    -- lote por tick: com mais zumbis que o lote, a lista toda é coberta em voltas
    siren_freeze_covers_all_in_batches = function()
        local G = setup()
        local zs = {}
        for i = 1, NOM_SirenFreeze.BATCH * 2 + 5 do zs[i] = G.zombie({ x = i, y = 0 }) end
        NOM_SirenFreeze.start(GRACE_MS)
        NOM_SirenFreeze.tick()
        local n = 0
        for _, z in ipairs(zs) do if z.useless then n = n + 1 end end
        assert(n == NOM_SirenFreeze.BATCH, "um tick passou do lote: " .. n)
        NOM_SirenFreeze.tick()
        NOM_SirenFreeze.tick()
        for _, z in ipairs(zs) do assert(z.useless, "sobrou zumbi sem congelar") end
    end,
    -- quem nasce no meio da sirene entra; o morto sai da tabela e não é tocado ao soltar
    siren_freeze_late_zombie_joins_and_dead_is_forgotten = function()
        local G = setup()
        NOM_SirenFreeze.install()
        local a = G.zombie({ x = 1, y = 1 })
        NOM_SirenFreeze.start(GRACE_MS)
        G.tick(1)
        assert(a.useless)
        local late = G.zombie({ x = 9, y = 9 })
        G.tick(2)
        assert(late.useless and NOM_SirenFreeze.frozen[late], "chegou no meio e não congelou")
        a.dead = true
        G.fire("OnZombieDead", a)
        assert(not NOM_SirenFreeze.frozen[a])
        NOM_SirenFreeze.stop()
        assert(late.useless == false)
    end,
    -- objeto reaproveitado (resetForReuse não limpa o useless): quem estava congelado volta solto
    siren_freeze_reused_object_is_released = function()
        local G = setup()
        NOM_SirenFreeze.install()
        local a = G.zombie({ x = 1, y = 1 })
        NOM_SirenFreeze.start(GRACE_MS)
        NOM_SirenFreeze.tick()
        assert(a.useless)
        NOM_SirenFreeze.stop()
        NOM_SirenFreeze.start(GRACE_MS)
        NOM_SirenFreeze.tick()
        G.fire("OnZombieCreate", a)
        assert(a.useless == false and not NOM_SirenFreeze.frozen[a], "objeto reaproveitado ficou useless")
    end,
    -- review final da 0033 (I2): a posse chega com o useless do dono antigo e o zumbi não
    -- passou pelo lote daqui; o stop solta todo zumbi local useless, menos a Carpideira
    -- parada, o useless do próprio jogo (outfit "Useless") e a cópia remota
    siren_freeze_stop_releases_inherited_useless = function()
        local G = setup({ client = true })
        local inherited = G.zombie({ x = 1, y = 1 })
        local still = G.zombie({ x = 2, y = 2 })
        local game = G.zombie({ x = 3, y = 3, outfit = "Useless" })
        local remote = G.zombie({ x = 4, y = 4, remote = true })
        NOM_SirenFreeze.start(GRACE_MS)
        for _, z in ipairs({ inherited, still, game, remote }) do z.useless = true end
        NOM_Carpideira.still[still] = true
        NOM_SirenFreeze.stop()
        assert(inherited.useless == false, "zumbi herdado ficou useless")
        assert(still.useless == true, "soltou a Carpideira parada")
        assert(game.useless == true, "soltou o useless do jogo")
        assert(remote.useless == true, "mexeu na cópia remota")
    end,
    -- review final da 0034: a posse chega com o useless do dono antigo logo DEPOIS do stop. Por
    -- SWEEP_MS reais, em lotes, o stop segue soltando zumbi local useless; nunca o Estalador que
    -- este processo cegou (a janela de cegueira dele ficaria sem o useless), a Carpideira parada,
    -- o useless do jogo nem a cópia remota
    siren_freeze_sweeps_late_inherited_useless = function()
        local G = setup({ client = true })
        G.player({ x = 0, y = 0 })
        NOM_SirenFreeze.install()
        NOM_SirenFreeze.start(GRACE_MS)
        G.tick(1)
        NOM_SirenFreeze.stop()
        G.seconds(1)
        local z = lateOwners(G)
        G.seconds(1)
        assert(z.inherited.useless == false, "zumbi herdado depois do stop ficou useless")
        assert(z.blind.useless == true, "soltou o Estalador cego")
        assert(z.still.useless == true, "soltou a Carpideira parada")
        assert(z.game.useless == true, "soltou o useless do jogo")
        assert(z.remote.useless == true, "mexeu na cópia remota")
        -- passou a janela: acabou o rodízio (custo zero na névoa)
        G.seconds(NOM_SirenFreeze.SWEEP_MS / 1000)
        local after = G.zombie({ x = 6, y = 6 })
        after.useless = true
        G.seconds(1)
        assert(after.useless == true, "o rodízio não acabou")
    end,
    siren_freeze_sweep_in_batches = function()
        local G = setup({ client = true })
        NOM_SirenFreeze.install()
        NOM_SirenFreeze.start(GRACE_MS)
        NOM_SirenFreeze.stop()
        local zs = {}
        for i = 1, NOM_SirenFreeze.BATCH * 2 + 5 do
            zs[i] = G.zombie({ x = i, y = 0 })
            zs[i].useless = true
        end
        G.tick(1)
        local n = 0
        for _, z in ipairs(zs) do if not z.useless then n = n + 1 end end
        assert(n == NOM_SirenFreeze.BATCH, "um tick do rodízio passou do lote: " .. n)
        G.tick(2)
        for _, z in ipairs(zs) do assert(z.useless == false, "o rodízio não cobriu a lista") end
    end,
    -- a passada do próprio stop também não solta o Estalador cego
    siren_freeze_stop_keeps_blinded_estalador = function()
        local G = setup({ client = true })
        G.player({ x = 0, y = 0 })
        NOM_SirenFreeze.start(GRACE_MS)
        local z = lateOwners(G)
        NOM_SirenFreeze.stop()
        assert(z.inherited.useless == false and z.blind.useless == true, "a passada do stop soltou o cego")
    end,
    -- "fog" (on) também chega com a névoa já aberta (fogState de quem renasce, vermelha
    -- trocada no debug): sem sirene ativa o stop não varre, e o Estalador cego fica cego
    siren_freeze_stop_without_siren_keeps_useless = function()
        local G = setup()
        local blind = G.zombie({ x = 1, y = 1 })
        blind.useless = true
        NOM_SirenFreeze.stop()
        assert(blind.useless == true, "stop sem sirene soltou zumbi useless")
    end,
    siren_freeze_stop_keeps_useless_in_tutorial = function()
        local G = setup({ gameMode = "Tutorial" })
        local z = G.zombie({ x = 1, y = 1 })
        z.useless = true
        NOM_SirenFreeze.start(GRACE_MS)
        NOM_SirenFreeze.stop()
        assert(z.useless == true, "soltou zumbi do tutorial")
    end,
    -- review final da 0033 (M1): a sirene não toma o zumbi que o jogo deixou useless (outfit
    -- "Useless", modo Tutorial), o mesmo critério do NOM_VariantAI (unstick)
    siren_freeze_skips_game_useless_and_tutorial = function()
        local G = setup()
        local game = G.zombie({ x = 1, y = 1, outfit = "Useless" })
        game.useless = true
        NOM_SirenFreeze.start(GRACE_MS)
        NOM_SirenFreeze.tick()
        assert(not NOM_SirenFreeze.frozen[game] and game.faced == nil, "congelou o useless do jogo")
        NOM_SirenFreeze.stop()
        assert(game.useless == true)
        local T = setup({ gameMode = "Tutorial" })
        local z = T.zombie({ x = 1, y = 1 })
        NOM_SirenFreeze.start(GRACE_MS)
        NOM_SirenFreeze.tick()
        assert(not z.useless and not NOM_SirenFreeze.frozen[z], "congelou no tutorial")
    end,
}
