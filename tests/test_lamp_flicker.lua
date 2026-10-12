-- Poste que pisca (sprint 0045): server/NOM_LampFlicker.lua sorteia na preta e na vermelha,
-- client/NOM_LampFlickerFx.lua toca o padrão na cor da luz, contra o mundo falso (tests/fog_world.lua).
local W = dofile("tests/fog_world.lua")

local MODS = { "NOM_LampFlicker", "NOM_LampFlickerFx", "NOM_FlickerRules", "NOM_TicaoLight", "NOM_TicaoFreeze",
    "NOM_LightRules", "NOM_World", "NOM_Players", "NOM_FogState", "NOM_SirenFreeze", "NOM_Carpideira",
    "NOM_VariantAI", "NOM_NightStats" }

-- rand 0: o sorteio passa (ZombRand(100) = 0) e começa no primeiro poste da lista
local function setup(opts)
    opts = opts or {}
    if opts.rand == nil then opts.rand = 0 end
    local G = W.new(opts)
    G.gridPower = true
    G.reload(MODS)
    require "NOM_World"
    require "NOM_FogState"
    if not opts.server then require "NOM_LampFlickerFx" end
    if not opts.client then require "NOM_LampFlicker" end
    if opts.ticao then require "NOM_TicaoLight" end
    return G
end

local function fog(red, black)
    NOM_World.setFog(true, red, black)
    NOM_FogState.set(true, 1, red, black)
end

-- ticks o bastante pra um sorteio e o padrão mais longo do poste
local function window()
    return math.floor((NOM_FlickerRules.LAMP_CHECK_MS + NOM_FlickerRules.lampMax()) / 16) + 10
end

-- quantas vezes a cor do poste apagou (r = 0) em n ticks
local function watch(G, lamp, n)
    local dark, was = 0, false
    for _ = 1, n do
        G.tick(1)
        local now = lamp.r == 0
        if now and not was then dark = dark + 1 end
        was = now
    end
    return dark
end

return {
    -- solo: na branca nada pisca; na vermelha o poste perto gagueja e a cor volta no fim
    lamp_flicker_only_red_or_black = function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        local lamp = G.lamp({ x = 5, y = 0, hydro = true })
        fog(false, false)
        assert(watch(G, lamp, window()) == 0, "poste piscou na névoa branca")
        fog(true, false)
        local dark = watch(G, lamp, window())
        assert(dark >= 3, "o poste não gaguejou na vermelha: " .. dark)
        assert(lamp.r == 1 and lamp.g == 0.9 and lamp.b == 0.7, "a cor não voltou")
        NOM_World.setFog(false)
        NOM_FogState.set(false, 0)
        assert(watch(G, lamp, window()) == 0, "poste piscou sem névoa")
    end,
    -- na preta também
    lamp_flicker_black = function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        local lamp = G.lamp({ x = 5, y = 0, hydro = true })
        fog(false, true)
        assert(watch(G, lamp, window()) >= 3, "o poste não gaguejou na preta")
    end,
    -- só luz de fora, acesa e perto de jogador; o sorteio anda pela lista a partir do índice sorteado
    lamp_flicker_picks_outdoor_near_lit = function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        local inside = G.lamp({ x = 2, y = 0, building = {}, hydro = true })
        local far = G.lamp({ x = 200, y = 0, hydro = true })
        local off = G.lamp({ x = 3, y = 0, on = false, hydro = true })
        local fire = G.lamp({ x = 1, y = 0 }) -- fogo, lampião: fora da rede, o jogo reescreve a cor
        local ok = G.lamp({ x = 4, y = 0, hydro = true })
        fog(true, false)
        local seen = { [inside] = 0, [far] = 0, [off] = 0, [ok] = 0, [fire] = 0 }
        for _ = 1, window() do
            G.tick(1)
            for l in pairs(seen) do if l.r == 0 then seen[l] = seen[l] + 1 end end
        end
        assert(seen[inside] == 0 and seen[far] == 0 and seen[off] == 0 and seen[fire] == 0, "piscou poste que não devia")
        assert(seen[ok] > 0, "o poste certo não piscou")
    end,
    -- teto: no máximo LAMP_MAX postes piscando ao mesmo tempo, e o mesmo poste não repete no meio
    lamp_flicker_cap = function()
        local G = setup()
        G.player({ x = 0, y = 0 })
        for i = 1, 6 do G.lamp({ x = i, y = 0, hydro = true }) end
        local every = NOM_FlickerRules.LAMP_CHECK_MS
        NOM_FlickerRules.LAMP_CHECK_MS = 100 -- sorteio a cada 100 ms: sem o teto, 7 juntos
        fog(true, false)
        local peak = 0
        for _ = 1, 200 do
            G.tick(1)
            local n = 0
            for _, u in pairs(NOM_LampFlicker.off) do if u > G.now then n = n + 1 end end
            if n > peak then peak = n end
        end
        NOM_FlickerRules.LAMP_CHECK_MS = every -- o próximo arquivo de teste não herda os 100 ms
        assert(peak == NOM_FlickerRules.LAMP_MAX, "teto: " .. peak)
    end,
    -- dedicado: o servidor só manda (pra todos) a posição e o padrão; a cor de lá não muda
    lamp_flicker_server_broadcasts = function()
        local G = setup({ server = true })
        G.player({ x = 0, y = 0 })
        local lamp = G.lamp({ x = 5, y = 0, hydro = true })
        fog(true, false)
        G.tick(window())
        local cmds = G.commands(G.sentServer, "lampFlicker")
        assert(#cmds >= 1 and cmds[1].player == nil, "não mandou pra todos")
        local a = cmds[1].args
        assert(a.x == 5 and a.y == 0 and a.z == 0 and type(a.segs) == "table" and #a.segs % 2 == 1, "args")
        assert(lamp.r == 1, "o servidor mexeu na cor")
    end,
    -- cliente: acha a luz pela posição, toca o padrão e devolve a cor; luz de dentro não
    lamp_flicker_client_plays = function()
        local G = setup({ client = true })
        local lamp = G.lamp({ x = 5, y = 0, hydro = true })
        local inside = G.lamp({ x = 6, y = 0, building = {}, hydro = true })
        assert(NOM_LampFlickerFx.play(5, 0, 0, { 100, 60, 100 }))
        assert(not NOM_LampFlickerFx.play(6, 0, 0, { 100 }), "tocou luz de dentro")
        assert(not NOM_LampFlickerFx.play(9, 9, 0, { 100 }), "achou luz que não existe")
        G.lamp({ x = 7, y = 0 })
        assert(not NOM_LampFlickerFx.play(7, 0, 0, { 100 }), "tocou fogo")
        G.tick(1)
        assert(lamp.r == 0 and lamp.g == 0 and lamp.b == 0, "não apagou")
        G.tick(7) -- 128 ms: no trecho aceso
        assert(lamp.r == 1 and lamp.b == 0.7, "não acendeu no meio")
        G.tick(4) -- 192 ms: apagado de novo
        assert(lamp.r == 0)
        G.tick(10)
        assert(lamp.r == 1 and lamp.g == 0.9 and lamp.b == 0.7, "a cor não voltou no fim")
        assert(inside.r == 1)
        assert(not NOM_LampFlickerFx.busy(), "ficou tocando")
    end,
    -- na preta, o poste piscando não congela: o Tição que ele segurava solta na hora
    lamp_flicker_releases_ticao = function()
        local G = setup({ ticao = true })
        G.player({ x = 0, y = 0 })
        G.lamp({ x = 10, y = 0, radius = 8, hydro = true })
        local z = G.zombie({ x = 12, y = 0 })
        fog(false, true)
        local frozen, startTick, releasedAfter = false, nil, nil
        for i = 1, window() do
            G.tick(1)
            if z.useless then frozen = true end
            if startTick == nil and NOM_LampFlicker.isOff(10, 0, 0, G.now) then startTick = i end
            if startTick and releasedAfter == nil and not z.useless then releasedAfter = i - startTick end
        end
        assert(frozen, "o poste não congelou antes")
        assert(startTick, "o poste não piscou")
        local limit = math.floor(NOM_LightRules.SWEEP_MS / 16) + 2
        assert(releasedAfter and releasedAfter <= limit,
            "o Tição soltou tarde: " .. tostring(releasedAfter) .. " ticks (limite " .. limit .. ")")
    end,
    -- lista grande (a célula inteira): o poste perto no fim da lista acha pelo sorteio e pelo debug
    lamp_flicker_finds_near_in_big_list = function()
        local G = setup()
        local p = G.player({ x = 0, y = 0 })
        for i = 1, 500 do G.lamp({ x = 1000 + i, y = 0, hydro = true }) end
        local near = G.lamp({ x = 6, y = 0, hydro = true })
        local x, y = NOM_LampFlicker.force(p)
        assert(x == 6 and y == 0, "o debug não achou o poste perto")
        G.tick(math.floor(NOM_FlickerRules.lampMax() / 16) + 2)
        fog(true, false)
        assert(watch(G, near, window() * 2) >= 1, "o sorteio não achou o poste perto")
    end,
    -- salvar no meio do pisca (solo: o save grava a cor da luz) devolve a cor antes
    lamp_flicker_restores_on_save = function()
        local G = setup({ client = true })
        local lamp = G.lamp({ x = 5, y = 0, hydro = true })
        assert(NOM_LampFlickerFx.play(5, 0, 0, { 500, 50, 500 }))
        G.tick(2)
        assert(lamp.r == 0)
        G.fire("OnSave")
        assert(lamp.r == 1 and lamp.g == 0.9 and lamp.b == 0.7, "salvou o poste apagado")
        assert(not NOM_LampFlickerFx.busy(), "seguiu tocando depois do save")
        G.tick(5)
        assert(lamp.r == 1)
    end,
    -- sprint 0051: na preta o Pesadelo usa o perfil (check mais curto); na vermelha, defaults LAMP_*
    lamp_flicker_black_uses_pressure = function()
        require "NOM_BlackPressureRules"
        local pes = NOM_BlackPressureRules.profile(3)
        assert(pes.lampCheckMs < NOM_FlickerRules.LAMP_CHECK_MS)
        local G = setup({ sandbox = { BlackFogPressure = 3 }, rand = 0 })
        G.player({ x = 0, y = 0 })
        local lamp = G.lamp({ x = 5, y = 0, hydro = true })
        fog(false, true)
        local dark = watch(G, lamp, math.floor((pes.lampCheckMs + NOM_FlickerRules.lampMax(pes)) / 16) + 20)
        assert(dark >= 1, "Pesadelo na preta não piscou o poste")
        -- vermelha: perfil não manda (mesmo sandbox 3); usa LAMP_CHECK_MS
        local G2 = setup({ sandbox = { BlackFogPressure = 3 }, rand = 0 })
        G2.player({ x = 0, y = 0 })
        local lamp2 = G2.lamp({ x = 5, y = 0, hydro = true })
        fog(true, false)
        assert(watch(G2, lamp2, window()) >= 1, "vermelha parou de piscar")
    end,
}
