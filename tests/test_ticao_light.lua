-- A luz congela o Tição (sprint 0038): server/NOM_TicaoLight.lua decide, shared/NOM_TicaoFreeze.lua
-- aplica no dono, contra o mundo falso (tests/fog_world.lua).
local W = dofile("tests/fog_world.lua")

local MODS = { "NOM_TicaoLight", "NOM_TicaoFreeze", "NOM_LightRules", "NOM_World", "NOM_Players", "NOM_FogState",
    "NOM_SirenFreeze", "NOM_Carpideira", "NOM_VariantAI", "NOM_NightStats" }

-- rand 99: nenhuma lanterna pisca (ZombRand(100) = 99), salvo o teste do flicker
local function setup(opts)
    opts = opts or {}
    if opts.rand == nil then opts.rand = 99 end
    local G = W.new(opts)
    G.reload(MODS)
    require "NOM_World"
    require "NOM_FogState"
    if opts.client then
        require "NOM_TicaoFreeze"
        NOM_TicaoFreeze.install()
    else
        require "NOM_TicaoLight"
    end
    return G
end

local function black(on)
    NOM_World.setFog(on, false, on)
    NOM_FogState.set(on, 1, false, on)
end

return {
    -- solo: a lanterna pra leste congela quem está na frente; quem está atrás anda; virar a
    -- lanterna solta o da frente meio segundo depois e pega o de trás
    ticao_light_solo_beam_freezes_and_follows = function()
        local G = setup()
        local p = G.player({ x = 0, y = 0, face = 0, light = true })
        local front = G.zombie({ x = 8, y = 0, walking = true })
        local back = G.zombie({ x = -8, y = 0 })
        black(true)
        G.tick(20)
        assert(front.useless == true and NOM_TicaoFreeze.frozen[front], "a luz não congelou")
        assert(front.pathCancelled and front.vars.bMoving == false, "congelado continuou andando")
        assert(not back.useless, "congelou fora da luz")
        p.face = math.pi
        G.tick(10)
        assert(front.useless == true, "soltou antes do HOLD_MS")
        G.tick(40)
        assert(front.useless == false and not NOM_TicaoFreeze.frozen[front], "não soltou quem saiu da luz")
        assert(back.useless == true, "não pegou o de trás")
    end,
    -- sem lanterna, lampião fraco ou fora da preta: ninguém congela
    ticao_light_needs_light_and_black = function()
        local G = setup()
        G.player({ x = 0, y = 0, face = 0, light = { cone = false, distance = 5 } })
        local z = G.zombie({ x = 2, y = 0 })
        black(true)
        G.tick(30)
        assert(not z.useless, "isqueiro congelou")
        local G2 = setup()
        G2.player({ x = 0, y = 0, face = 0, light = true })
        local z2 = G2.zombie({ x = 5, y = 0 })
        NOM_World.setFog(true, false, false)
        NOM_FogState.set(true, 1)
        G2.tick(30)
        assert(not z2.useless, "congelou na névoa comum")
    end,
    -- lampião: raio pequeno em volta, pra todo lado
    ticao_light_lantern_radius = function()
        local G = setup()
        G.player({ x = 0, y = 0, face = 0, light = { cone = false, distance = 15 } })
        local near, far = G.zombie({ x = -3, y = 0 }), G.zombie({ x = -8, y = 0 })
        black(true)
        G.tick(30)
        assert(near.useless and not far.useless)
    end,
    -- fim da preta: todo mundo solta
    ticao_light_black_end_releases_all = function()
        local G = setup()
        G.player({ x = 0, y = 0, face = 0, light = true })
        local zs = {}
        for i = 1, 5 do zs[i] = G.zombie({ x = 3 + i, y = 0 }) end
        black(true)
        G.tick(30)
        for _, z in ipairs(zs) do assert(z.useless) end
        black(false)
        G.tick(2)
        for _, z in ipairs(zs) do assert(z.useless == false, "ficou congelado depois da preta") end
        assert(NOM_TicaoFreeze.count() == 0)
    end,
    -- dedicado: o servidor não aplica, manda a lista de onlineIDs a cada SWEEP_MS; a lista vazia
    -- vai uma vez quando esvazia
    ticao_light_server_sends_ids = function()
        local G = setup({ server = true })
        local p = G.player({ x = 0, y = 0, face = 0, light = true })
        local z = G.zombie({ x = 6, y = 0, onlineID = 77 })
        G.zombie({ x = -6, y = 0, onlineID = 78 })
        black(true)
        G.tick(30)
        assert(not z.useless, "o servidor aplicou")
        local cmds = G.commands(G.sentServer, "ticaoFrozen")
        assert(#cmds >= 1, "não mandou")
        local last = cmds[#cmds].args.ids
        assert(#last == 1 and last[1] == 77, "ids: " .. #last)
        p.face = math.pi / 2
        G.tick(120)
        cmds = G.commands(G.sentServer, "ticaoFrozen")
        local empties = 0
        for _, c in ipairs(cmds) do if #c.args.ids == 0 then empties = empties + 1 end end
        assert(#cmds[#cmds].args.ids == 0 and empties == 1, "lista vazia: " .. empties)
    end,
    -- cliente: congela os listados que são dele; a cópia remota não; silêncio solta
    ticao_freeze_client_applies_ids_and_silence_releases = function()
        local G = setup({ client = true })
        local mine = G.zombie({ x = 1, y = 0, onlineID = 5 })
        local remote = G.zombie({ x = 2, y = 0, onlineID = 6, remote = true })
        local other = G.zombie({ x = 3, y = 0, onlineID = 7 })
        NOM_FogState.set(true, 1, false, true)
        NOM_TicaoFreeze.applyIds({ 5, 6 })
        assert(mine.useless == true and not remote.useless and not other.useless)
        NOM_TicaoFreeze.applyIds({ 5 })
        assert(mine.useless == true)
        NOM_TicaoFreeze.applyIds({})
        assert(mine.useless == false, "não soltou quem saiu da lista")
        NOM_TicaoFreeze.applyIds({ 5, 7 })
        G.tick(math.floor(NOM_LightRules.SILENCE_MS / 16) + 2)
        assert(mine.useless == false and other.useless == false, "silêncio não soltou")
        NOM_TicaoFreeze.applyIds({ 5 })
        NOM_FogState.set(false, 1)
        assert(mine.useless == false, "fim da névoa não soltou")
    end,
    -- não pega o cego da visão curta, o congelado da sirene, a Carpideira parada nem o useless do jogo
    ticao_freeze_skips_other_rules = function()
        local G = setup({ client = true })
        require "NOM_VariantAI"
        local blind = G.zombie({ x = 1, y = 0 })
        local siren = G.zombie({ x = 2, y = 0 })
        local game = G.zombie({ x = 3, y = 0, outfit = "Useless" })
        blind.useless, siren.useless = true, true
        NOM_VariantAI.blinded[blind] = { p = {}, n = 0, common = true, x = 1, y = 0, t = 0 }
        NOM_SirenFreeze.frozen[siren] = true
        NOM_FogState.set(true, 1, false, true)
        NOM_TicaoFreeze.apply({ blind, siren, game })
        assert(NOM_TicaoFreeze.count() == 0, "pegou zumbi de outra regra")
        NOM_TicaoFreeze.apply({})
        assert(blind.useless and siren.useless, "soltou o que não era dele")
        NOM_VariantAI.blinded[blind] = nil
        NOM_SirenFreeze.frozen[siren] = nil
    end,
    -- o unstick do NOM_VariantAI não solta o congelado pela luz
    ticao_freeze_survives_unstick = function()
        local G = setup({ client = true })
        require "NOM_VariantAI"
        NOM_VariantAI.install(function() end)
        local z = G.zombie({ x = 1, y = 0, onlineID = 3 })
        NOM_FogState.set(true, 1, false, true)
        NOM_TicaoFreeze.applyIds({ 3 })
        NOM_NightStats.unstick(z)
        assert(z.useless == true, "o unstick soltou o congelado pela luz")
    end,
    -- a lanterna pisca: apaga no dono, quem ela segurava solta na hora, e volta acesa no fim
    ticao_light_flicker = function()
        local G = setup({ rand = 0 })
        local p = G.player({ x = 0, y = 0, face = 0, light = true })
        local z = G.zombie({ x = 6, y = 0 })
        black(true)
        G.tick(30)
        assert(z.useless, "não congelou antes do flicker")
        G.tick(math.floor(NOM_LightRules.FLICKER_CHECK_MS / 16))
        assert(p.item.on == false, "a lanterna não apagou")
        G.tick(math.floor(NOM_LightRules.SWEEP_MS / 16) + 2)
        assert(z.useless == false, "o Tição não soltou com a lanterna apagada")
        G.tick(math.floor(NOM_LightRules.FLICKER_MIN_MS / 16) + 2)
        assert(p.item.on == true, "a lanterna não voltou")
    end,
    -- quem desliga a lanterna no meio do flicker não a vê acender sozinha
    ticao_light_flicker_respects_player = function()
        local G = setup({ rand = 0 })
        local p = G.player({ x = 0, y = 0, face = 0, light = true })
        black(true)
        G.tick(math.floor(NOM_LightRules.FLICKER_CHECK_MS / 16) + 30)
        assert(p.item.on == false)
        p.item.inventory = nil
        p.item.getContainer = function() return {} end -- guardou em outra bolsa
        G.tick(math.floor(NOM_LightRules.FLICKER_MAX_MS / 16) + 2)
        assert(p.item.on == false, "acendeu a lanterna guardada")
    end,
    -- custo: 300 zumbis, 4 jogadores com lanterna; chamadas no zumbi por tick (60 FPS) abaixo de 200
    ticao_light_budget = function()
        local G = setup()
        for i = 0, 3 do G.player({ x = i * 40, y = 0, face = 0, light = true }) end
        local calls = 0
        for i = 1, 300 do
            local z = G.zombie({ x = (i * 7) % 160, y = (i * 13) % 60 - 30 })
            for _, m in ipairs({ "getX", "getY", "getZ", "isDead", "getOnlineID", "isLocal", "setUseless" }) do
                local f = z[m]
                z[m] = function(...) calls = calls + 1 return f(...) end
            end
        end
        black(true)
        G.tick(60)
        calls = 0
        G.tick(60)
        local per = calls / 60
        print(string.format("[budget] luz do Tição (300 zumbis, 4 lanternas): %.1f chamadas no zumbi por tick", per))
        assert(per < 200, "luz cara demais: " .. per)
    end,
}
