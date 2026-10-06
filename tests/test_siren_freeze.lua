-- shared/NOM_SirenFreeze.lua contra o mundo falso (tests/fog_world.lua): a sirene congela
-- os zumbis que este processo simula, virados pra direção dela, e o fim solta.
local W = dofile("tests/fog_world.lua")

local function setup(opts)
    local G = W.new(opts or {})
    G.reload({ "NOM_SirenFreeze", "NOM_Carpideira" })
    require "NOM_Carpideira"
    require "NOM_SirenFreeze"
    return G
end

return {
    siren_freeze_holds_local_zombies_facing_dir = function()
        local G = setup()
        local a = G.zombie({ x = 10, y = 10 })
        local b = G.zombie({ x = 20, y = 20, remote = true })
        NOM_SirenFreeze.start(0, 45000)
        for _ = 1, 3 do NOM_SirenFreeze.tick() end
        assert(a.useless == true and a.target == nil and NOM_SirenFreeze.frozen[a])
        assert(math.abs(a.faced.x - (a.x + NOM_SirenFreeze.FAR)) < 1e-6 and math.abs(a.faced.y - a.y) < 1e-6, "direção 0° = +x")
        assert(not b.useless and not NOM_SirenFreeze.frozen[b], "cópia remota é do dono")
    end,
    siren_freeze_direction_90_is_plus_y = function()
        local G = setup()
        local a = G.zombie({ x = 3, y = 4 })
        NOM_SirenFreeze.start(90, 45000)
        NOM_SirenFreeze.tick()
        assert(math.abs(a.faced.x - a.x) < 1e-6 and math.abs(a.faced.y - (a.y + NOM_SirenFreeze.FAR)) < 1e-6)
    end,
    siren_freeze_drops_target_of_chasing_zombie = function()
        local G = setup()
        local p = G.player({ x = 0, y = 0 })
        local a = G.zombie({ x = 5, y = 5 })
        a:spotted(p, true)
        assert(a.target == p)
        NOM_SirenFreeze.start(0, 45000)
        NOM_SirenFreeze.tick()
        assert(a.target == nil and a:isUseless())
        a:spotted(p, true) -- o jogo tenta de novo: useless não pega alvo
        assert(a.target == nil, "voltou a perseguir durante a sirene")
    end,
    siren_freeze_stop_releases = function()
        local G = setup()
        local a = G.zombie({ x = 1, y = 1 })
        NOM_SirenFreeze.start(90, 45000)
        NOM_SirenFreeze.tick()
        NOM_SirenFreeze.stop()
        assert(a.useless == false and next(NOM_SirenFreeze.frozen) == nil and not NOM_SirenFreeze.active)
        NOM_SirenFreeze.tick()
        assert(a.useless == false, "tick sem sirene voltou a congelar")
    end,
    siren_freeze_keeps_still_carpideira = function()
        local G = setup()
        local a = G.zombie({ x = 1, y = 1 })
        NOM_SirenFreeze.start(0, 45000)
        NOM_SirenFreeze.tick()
        NOM_Carpideira.still[a] = true
        NOM_SirenFreeze.stop()
        assert(a.useless == true, "soltou a Carpideira parada")
    end,
    siren_freeze_safety_timeout = function()
        local G = setup()
        local a = G.zombie({ x = 1, y = 1 })
        NOM_SirenFreeze.start(0, 45000)
        NOM_SirenFreeze.tick()
        G.now = G.now + 45000 + NOM_SirenFreeze.SAFETY_MS + 1
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
        NOM_SirenFreeze.start(0, 45000)
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
        NOM_SirenFreeze.start(0, 45000)
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
        NOM_SirenFreeze.start(0, 45000)
        NOM_SirenFreeze.tick()
        assert(a.useless)
        NOM_SirenFreeze.stop()
        NOM_SirenFreeze.start(0, 45000)
        NOM_SirenFreeze.tick()
        G.fire("OnZombieCreate", a)
        assert(a.useless == false and not NOM_SirenFreeze.frozen[a], "objeto reaproveitado ficou useless")
    end,
    -- review final da 0033 (I2): a posse chega com o useless do dono antigo e o zumbi não
    -- passou pelo lote daqui; o stop solta todo zumbi local useless, menos a Carpideira
    -- parada, o useless do próprio jogo (outfit "Useless") e a cópia remota
    siren_freeze_stop_releases_inherited_useless = function()
        local G = setup()
        local inherited = G.zombie({ x = 1, y = 1 })
        local still = G.zombie({ x = 2, y = 2 })
        local game = G.zombie({ x = 3, y = 3, outfit = "Useless" })
        local remote = G.zombie({ x = 4, y = 4, remote = true })
        NOM_SirenFreeze.start(0, 45000)
        for _, z in ipairs({ inherited, still, game, remote }) do z.useless = true end
        NOM_Carpideira.still[still] = true
        NOM_SirenFreeze.stop()
        assert(inherited.useless == false, "zumbi herdado ficou useless")
        assert(still.useless == true, "soltou a Carpideira parada")
        assert(game.useless == true, "soltou o useless do jogo")
        assert(remote.useless == true, "mexeu na cópia remota")
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
        NOM_SirenFreeze.start(0, 45000)
        NOM_SirenFreeze.stop()
        assert(z.useless == true, "soltou zumbi do tutorial")
    end,
    -- review final da 0033 (M1): a sirene não toma o zumbi que o jogo deixou useless (outfit
    -- "Useless", modo Tutorial), o mesmo critério do NOM_VariantAI (unstick)
    siren_freeze_skips_game_useless_and_tutorial = function()
        local G = setup()
        local game = G.zombie({ x = 1, y = 1, outfit = "Useless" })
        game.useless = true
        NOM_SirenFreeze.start(0, 45000)
        NOM_SirenFreeze.tick()
        assert(not NOM_SirenFreeze.frozen[game] and game.faced == nil, "congelou o useless do jogo")
        NOM_SirenFreeze.stop()
        assert(game.useless == true)
        local T = setup({ gameMode = "Tutorial" })
        local z = T.zombie({ x = 1, y = 1 })
        NOM_SirenFreeze.start(0, 45000)
        NOM_SirenFreeze.tick()
        assert(not z.useless and not NOM_SirenFreeze.frozen[z], "congelou no tutorial")
    end,
}
