-- client/NOM_FogOverlays.lua contra o mundo falso de tests/fog_world.lua e um
-- IsoMarkers falso que imita o jogo: getIsoMarkers():addIsoMarker(nome, square,
-- r, g, b, a) (client/Foraging/ISBaseIcon.lua:577) guarda o marcador numa lista
-- em memória (sem save/load, sem rede: bytecode IsoMarkers), marker:setAlpha(a),
-- marker:remove(). O square falso explode em qualquer chamada que não seja de
-- leitura, e addBloodSplat (que salva no chunk) também.
local W = dofile("tests/fog_world.lua")
local FILE = "mod/42/media/lua/client/NOM_FogOverlays.lua"

local function setup(opts)
    opts = opts or {}
    local G = W.new(opts)
    G.reload({ "NOM_FogState", "NOM_FogOverlays" })
    require "NOM_FogState"
    local seed = 12345
    ZombRand = function(n)
        seed = (seed * 1103515245 + 12345) % 2147483648
        return math.floor(seed / 65536) % n
    end
    G.markers = {}
    getIsoMarkers = function()
        return {
            addIsoMarker = function(_, name, sq, r, g, b, a)
                assert(type(name) == "string" and sq and sq.getX, "addIsoMarker com argumento errado")
                local m = { name = name, sq = sq, a = a, color = { r, g, b }, removed = false }
                function m:setAlpha(v) self.a = v end
                function m:remove() self.removed = true end
                G.markers[#G.markers + 1] = m
                return m
            end,
        }
    end
    getTexture = function(name)
        if opts.noTextures then return nil end
        return { name = name }
    end
    addBloodSplat = function() error("addBloodSplat salva no chunk") end
    dofile(FILE)
    G.p = G.player({ x = 100, y = 100 })
    return G
end

local function alive(G)
    local out = {}
    for _, m in ipairs(G.markers) do if not m.removed then out[#out + 1] = m end end
    return out
end

local O = function() return NOM_FogOverlays end

return {
    overlays_inert_on_dedicated = function()
        local G = setup({ server = true })
        NOM_FogState.set(true, 1)
        G.seconds(30)
        assert(#G.markers == 0)
    end,
    -- critério: surgem aos poucos perto do jogador
    overlays_grow_slowly = function()
        local G = setup()
        G.seconds(10)
        assert(#G.markers == 0, "mancha sem névoa")
        NOM_FogState.set(true, 1)
        G.seconds(1)
        assert(#G.markers <= 1, "muitas de uma vez: " .. #G.markers)
        local first = G.markers[1]
        assert(first and first.a < O().ALPHA, "nasceu sem fade")
        G.seconds(14)
        local n = #alive(G)
        assert(n >= 6 and n <= 12, "manchas em 15 s: " .. n)
        assert(math.abs(first.a - O().ALPHA) < 1e-6, "não chegou no alpha cheio")
        local keys = {}
        for _, m in ipairs(alive(G)) do
            local d = math.sqrt((m.sq.x + 0.5 - G.p.x) ^ 2 + (m.sq.y + 0.5 - G.p.y) ^ 2)
            assert(d >= O().MIN_R - 1 and d <= O().MAX_R + 1, "longe do jogador: " .. d)
            local k = m.sq.x .. "," .. m.sq.y
            assert(not keys[k], "duas no mesmo tile")
            keys[k] = true
            assert(m.name:find("^overlay_blood_floor_01_") or m.name:find("^overlay_grime_floor_01_"), m.name)
        end
    end,
    overlays_capped = function()
        local G = setup()
        NOM_FogState.set(true, 1)
        G.seconds(300)
        assert(#alive(G) <= O().MAX, "passou do teto: " .. #alive(G))
    end,
    -- critério: somem com a névoa (fade, depois remove)
    overlays_fade_out_and_removed_on_fog_end = function()
        local G = setup()
        NOM_FogState.set(true, 1)
        G.seconds(30)
        local before = #alive(G)
        assert(before > 0)
        NOM_FogState.set(false, 1)
        G.seconds(O().FADE_MS / 2000)
        local m = alive(G)[1]
        assert(m and m.a < O().ALPHA and m.a > 0, "sumiu sem fade")
        G.seconds(O().FADE_MS / 1000)
        assert(#alive(G) == 0, "sobrou mancha depois da névoa: " .. #alive(G))
        local n = #G.markers
        G.seconds(30)
        assert(#G.markers == n, "nasceu mancha sem névoa")
    end,
    -- critério: nada no mapa (o square falso explode em escrita; addBloodSplat também)
    overlays_never_touch_the_map = function()
        local G = setup()
        NOM_FogState.set(true, 1)
        G.seconds(120)
        NOM_FogState.set(false, 1)
        G.seconds(20)
        assert(#G.markers > 0)
    end,
    -- andou pra longe: as de trás somem (custo local limitado)
    overlays_far_ones_removed = function()
        local G = setup()
        NOM_FogState.set(true, 1)
        G.seconds(20)
        local old = alive(G)
        G.p.x = G.p.x + 60
        G.seconds(O().FADE_MS / 1000 + 2)
        for _, m in ipairs(old) do assert(m.removed, "mancha longe ficou") end
        assert(#alive(G) > 0, "parou de nascer perto do jogador novo")
    end,
    overlays_toggle_and_missing_sprites = function()
        local G = setup({ sandbox = { FogOverlays = false } })
        NOM_FogState.set(true, 1)
        G.seconds(30)
        assert(#G.markers == 0, "desligado e nasceu mancha")
        local G2 = setup({ noTextures = true })
        NOM_FogState.set(true, 1)
        G2.seconds(30)
        assert(#G2.markers == 0, "marcador sem textura")
    end,
}
