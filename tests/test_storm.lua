-- Tempestade da névoa preta e da vermelha (sprint 0045): server/NOM_Storm.lua contra o mundo falso.
local W = dofile("tests/fog_world.lua")

local MODS = { "NOM_Storm", "NOM_StormRules", "NOM_TicaoLight", "NOM_TicaoFreeze", "NOM_LightRules",
    "NOM_FlickerRules", "NOM_World", "NOM_Players", "NOM_FogState", "NOM_SirenFreeze", "NOM_Carpideira",
    "NOM_VariantAI", "NOM_NightStats" }

-- rand 0: o primeiro relâmpago vem em THUNDER_MIN_MS; lanterna não pisca (sem lanterna)
local function setup(opts)
    opts = opts or {}
    if opts.rand == nil then opts.rand = 0 end
    local G = W.new(opts)
    G.reload(MODS)
    require "NOM_World"
    require "NOM_FogState"
    require "NOM_Storm"
    if opts.ticao then require "NOM_TicaoLight" end
    return G
end

local function fog(on, red, black)
    NOM_World.setFog(on, red, black)
    NOM_FogState.set(on, on and 1 or 0, red, black)
end

local function untilThunder()
    return math.floor(NOM_StormRules.THUNDER_MIN_MS / 16) + 2
end

return {
    -- só na névoa aberta preta ou vermelha; relâmpago e trovão longe, sem raio caindo
    storm_only_red_black = function()
        local G = setup()
        G.player({ x = 100, y = 100 })
        fog(true, false, false)
        G.tick(untilThunder() * 2)
        assert(#G.thunders == 0, "trovão na névoa branca")
        NOM_World.rising, NOM_World.risingBlack = true, true
        fog(false, false, false)
        G.tick(untilThunder() * 2)
        assert(#G.thunders == 0, "trovão antes da névoa abrir")
        NOM_World.rising, NOM_World.risingBlack = false, false
        fog(true, true, false)
        G.tick(untilThunder())
        assert(#G.thunders == 1, "sem trovão na vermelha: " .. #G.thunders)
        local t = G.thunders[1]
        assert(t.strike == false and t.lightning == true and t.rumble == true, "raio caindo ou sem clarão/som")
        local d = math.sqrt((t.x - 100) ^ 2 + (t.y - 100) ^ 2)
        assert(d >= NOM_StormRules.DIST_MIN - 1 and d <= NOM_StormRules.DIST_MAX + 1, "distância " .. d)
        G.tick(untilThunder())
        assert(#G.thunders == 2, "não repetiu")
        fog(false, false, false)
        G.tick(untilThunder() * 2)
        assert(#G.thunders == 2, "trovão depois da névoa")
    end,
    -- dedicado: o servidor dispara (o jogo transmite pros clientes)
    storm_server = function()
        local G = setup({ server = true })
        G.player({ x = 0, y = 0 })
        fog(true, false, true)
        G.tick(untilThunder())
        assert(#G.thunders == 1, "o servidor não disparou")
    end,
    -- na preta, o clarão congela os Tições perto dos jogadores por FLASH_MS
    storm_flash_freezes_ticao = function()
        local G = setup({ ticao = true })
        G.player({ x = 0, y = 0 })
        local z = G.zombie({ x = 6, y = 0 })
        fog(true, false, true)
        G.tick(untilThunder() - 30)
        assert(not z.useless, "congelou sem luz")
        G.tick(30 + math.floor(NOM_LightRules.SWEEP_MS / 16) + 2)
        assert(#G.thunders == 1)
        assert(z.useless, "o clarão não congelou")
        G.tick(math.floor((NOM_StormRules.FLASH_MS + 2 * NOM_LightRules.SWEEP_MS) / 16))
        assert(not z.useless, "não soltou depois do clarão")
    end,
    -- Tição em cômodo aceso segue congelado do clarão pro cômodo, sem buraco
    storm_flash_keeps_lit_room = function()
        for phase = 0, 15 do
            local G = setup({ ticao = true })
            G.player({ x = 0, y = 0 })
            G.gridPower = true
            G.room({ x0 = 5, y0 = 5, x1 = 9, y1 = 9 })
            local z = G.zombie({ x = 7, y = 7 })
            for i = 1, 400 do G.zombie({ x = 500 + i, y = 500 }) end -- o rodízio leva SWEEP_MS pra voltar nele
            fog(true, false, true)
            G.tick(60 + phase)
            assert(z.useless, "o cômodo não congelou")
            NOM_Storm.force(G.players[1])
            for _ = 1, math.floor((NOM_StormRules.FLASH_MS + 4 * NOM_LightRules.SWEEP_MS) / 16) do
                G.tick(1)
                assert(z.useless, "soltou o Tição do cômodo aceso no clarão (fase " .. phase .. ")")
            end
        end
    end,
    -- sprint 0053: na preta o servidor avisa o cliente do clarão vermelho
    storm_black_tells_client_flash = function()
        local G = setup({ server = true })
        G.player({ x = 0, y = 0 })
        fog(true, false, true)
        NOM_Storm.force(G.players[1])
        local flashes = G.commands(G.sentServer, "thunderFlash")
        assert(#flashes == 1, "sem thunderFlash na preta: " .. #flashes)
        fog(true, true, false)
        NOM_Storm.force(G.players[1])
        assert(#G.commands(G.sentServer, "thunderFlash") == 1, "thunderFlash na vermelha")
    end,
    -- na vermelha não tem Tição: o clarão não congela ninguém
    storm_flash_red_no_freeze = function()
        local G = setup({ ticao = true })
        G.player({ x = 0, y = 0 })
        local z = G.zombie({ x = 6, y = 0 })
        fog(true, true, false)
        G.tick(untilThunder() + 20)
        assert(#G.thunders == 1 and not z.useless, "congelou na vermelha")
    end,
    -- debug: relâmpago já, perto do jogador, em qualquer tempo
    storm_force = function()
        local G = setup()
        local p = G.player({ x = 10, y = 10 })
        local x, y = NOM_Storm.force(p)
        assert(#G.thunders == 1 and G.thunders[1].x == x and G.thunders[1].y == y)
    end,
}
