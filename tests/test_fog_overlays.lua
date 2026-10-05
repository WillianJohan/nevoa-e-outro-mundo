-- client/NOM_FogOverlays.lua (Outro Mundo sangrento, sprint 0015) contra o mundo falso
-- de tests/fog_world.lua e fakes que imitam o jogo (bytecode B42.21, pz-api-notes §16):
-- * getIsoMarkers():addIsoMarker(tabela de nomes, square, r, g, b, a): uma textura por
--   nome (ISBaseIcon.lua:579), lista em memória, sem save nem rede; marker:setColor,
--   setAlpha, remove. Marcador só desenha no andar do jogador (renderIsoMarkers).
-- * getSprite(nome) (IsoSpriteManager.getSprite cria sprite vazio pra nome desconhecido:
--   o fake explode se o mod pedir sem ter conferido a textura); sprite:RenderGhostTileColor(
--   x, y, z, r, g, b, a) é desenho imediato, só vale dentro do RenderOpaqueObjectsInWorld
--   (FBORenderCell.renderOpaqueObjectsEvent, todo quadro, por jogador). Qualquer outro método
--   do sprite (anexar, overlay: salvos no chunk) explode.
-- * O square falso explode em escrita; addBloodSplat também.
local W = dofile("tests/fog_world.lua")
local FILE = "mod/42/media/lua/client/NOM_FogOverlays.lua"

local function setup(opts)
    opts = opts or {}
    local G = W.new(opts)
    G.reload({ "NOM_FogState", "NOM_DressingRules", "NOM_ScreenFxOptions", "NOM_FogOverlays" })
    PZAPI = nil
    require "NOM_FogState"
    require "NOM_ScreenFxOptions"
    if opts.density then NOM_ScreenFxOptions.overlayDensity = function() return opts.density end end
    -- paredes ficam desligadas por padrão no mod (hotfix: sem profundidade, cobriam o jogador);
    -- os testes do mecanismo ligam; walls = "default" testa o padrão do mod
    require "NOM_DressingRules"
    if opts.walls ~= "default" then NOM_DressingRules.WALLS = opts.walls ~= false end
    G.markers, G.draws, G.inFrame = {}, {}, false
    G.java = 0 -- chamadas em marcador, sprite, célula (as do square: G.sqCalls)
    getIsoMarkers = function()
        G.java = G.java + 1
        return {
            addIsoMarker = function(_, names, sq, r, g, b, a)
                G.java = G.java + 1
                assert(type(names) == "table" and #names >= 1 and #names <= 4, "addIsoMarker sem a tabela de nomes")
                for _, n in ipairs(names) do assert(type(n) == "string") end
                assert(sq and sq.getX and a == 0, "argumento errado")
                local m = { names = names, sq = sq, a = a, color = { r, g, b }, removed = false }
                function m:setColor(rr, gg, bb, aa)
                    G.java = G.java + 1
                    self.color = { rr, gg, bb }
                    self.a = aa
                end
                function m:setAlpha(v) G.java = G.java + 1; self.a = v end
                function m:remove() G.java = G.java + 1; self.removed = true end
                G.markers[#G.markers + 1] = m
                return m
            end,
        }
    end
    G.textures = {}
    getTexture = function(name)
        G.java = G.java + 1
        if opts.noTextures or (opts.missing and name:find(opts.missing)) then return nil end
        G.textures[name] = true
        return { name = name }
    end
    getSprite = function(name)
        G.java = G.java + 1
        assert(G.textures[name], "getSprite sem conferir a textura: " .. name)
        return setmetatable({ name = name }, { __index = function(_, m)
            if m ~= "RenderGhostTileColor" then error("sprite:" .. m .. " não devia ser chamado", 2) end
            return function(self, x, y, z, r, gg, b, a, extra)
                G.java = G.java + 1
                assert(G.inFrame, "desenho fora do quadro do mundo")
                assert(extra == nil and a ~= nil, "RenderGhostTileColor com 7 argumentos")
                G.draws[#G.draws + 1] = { name = self.name, x = x, y = y, z = z, a = a, l = r }
            end
        end })
    end
    addBloodSplat = function() error("addBloodSplat salva no chunk") end
    local cell = getCell
    getCell = function() G.java = G.java + 1; return cell() end
    MainScreen = nil
    dofile(FILE)
    G.p = G.player({ x = 100, y = 100 })
    -- pickedOutside: o tile do mouse fora do mundo; o jogo não dispara o evento nesse
    -- quadro (IsoWorld.isValidSquare em FBORenderCell.renderOpaqueObjectsEvent 82–92)
    function G.frame(pickedOutside)
        G.draws = {}
        G.inFrame = true
        if not pickedOutside then G.fire("RenderOpaqueObjectsInWorld", 0, 100, 100, math.floor(G.p.z), nil) end
        G.inFrame = false
        return G.draws
    end
    return G
end

local function alive(G)
    local out = {}
    for _, m in ipairs(G.markers) do if not m.removed then out[#out + 1] = m end end
    return out
end

-- desenho por square (sangue e sujeira são dois marcadores do mesmo square)
local function layout(G)
    local out = {}
    for _, m in ipairs(alive(G)) do
        local k = m.sq.x .. "," .. m.sq.y .. "," .. m.sq.z
        local v = table.concat(m.names, "|")
        if out[k] then
            out[k] = out[k] < v and out[k] .. "+" .. v or v .. "+" .. out[k]
        else
            out[k] = v
        end
    end
    return out
end

-- squares com marcador vivo (o teto é por square)
local function squares(G)
    local n = 0
    for _ in pairs(layout(G)) do n = n + 1 end
    return n
end

local function textures(G)
    local n = 0
    for _, m in ipairs(alive(G)) do n = n + #m.names end
    return n
end

-- paredes em volta: um quarteirão com paredes N e W em todo square de uma faixa
local function addWalls(G, x0, y0, n)
    for x = x0, x0 + n - 1 do
        for y = y0, y0 + n - 1 do G.walls[x .. "," .. y .. ",0"] = "NW" end
    end
end

local O = function() return NOM_FogOverlays end
local D = function() return NOM_DressingRules end

-- Fração do quadrado (2r+1)² em volta do jogador com marcador vivo no andar dele, e a
-- fração que a regra pede (o máximo possível: o mundo falso tem todo square livre).
local function coverage(G, r)
    local set = {}
    local pz = math.floor(G.p.z)
    for _, m in ipairs(alive(G)) do if m.sq.z == pz then set[m.sq.x .. "," .. m.sq.y] = true end end
    local px, py = math.floor(G.p.x), math.floor(G.p.y)
    local d = D().density(NOM_ScreenFxOptions.overlayDensity(), NOM_FogState.red)
    local have, want, tot = 0, 0, 0
    for x = px - r, px + r do
        for y = py - r, py + r do
            tot = tot + 1
            if set[x .. "," .. y] then have = have + 1 end
            if D().floor(x, y, pz, NOM_FogState.period or 0, d) then want = want + 1 end
        end
    end
    return have / tot, want > 0 and have / want or 1
end

-- marcadores vivos por square: { main = marcador sem sujeira, grime = marcador da sujeira }
local function bySquare(G)
    local out = {}
    for _, m in ipairs(alive(G)) do
        local k = m.sq.x .. "," .. m.sq.y .. "," .. m.sq.z
        out[k] = out[k] or {}
        if #m.names == 1 and m.names[1]:find("^overlay_grime") then out[k].grime = m else out[k].main = m end
    end
    return out
end

return {
    -- print 7 (05/10): sujeira cheia, uma por tile, lia como xadrez. Ela vai num marcador
    -- próprio, mais leve que o sangue do mesmo square (o marcador tem uma cor só)
    overlays_grime_own_marker_lighter = function()
        local G = setup()
        NOM_FogState.set(true, 1)
        G.seconds(15)
        local both = 0
        for k, s in pairs(bySquare(G)) do
            local x, y, z = k:match("(-?%d+),(-?%d+),(-?%d+)")
            local f = D().floor(tonumber(x), tonumber(y), tonumber(z), 1, D().density(1, false))
            assert((s.grime ~= nil) == (f.grime ~= nil), "sujeira não bate com a regra em " .. k)
            for _, n in ipairs(s.main and s.main.names or {}) do assert(not n:find("grime"), "sujeira no marcador do sangue") end
            if s.grime and s.main then
                both = both + 1
                assert(math.abs(s.grime.a - s.main.a * D().GRIME_ALPHA) < 1e-6, "alfa da sujeira: " .. s.grime.a)
            end
        end
        assert(both > 20, "poucos squares com sujeira e sangue: " .. both)
    end,

    -- os dois marcadores de um square saem juntos (fim da névoa, densidade nova)
    overlays_grime_marker_follows_entry = function()
        local G = setup()
        NOM_FogState.set(true, 1)
        G.seconds(15)
        local grimes = 0
        for _, s in pairs(bySquare(G)) do if s.grime then grimes = grimes + 1 end end
        assert(grimes > 20, "sem sujeira: " .. grimes)
        local old = alive(G)
        NOM_FogState.set(true, 1, true) -- densidade nova (vermelha forçada): redesenha depois de 1 s
        G.seconds(1.5)
        for _, m in ipairs(old) do assert(m.removed, "marcador velho ficou") end
        NOM_FogState.set(false, 1)
        G.seconds(O().FADE_MS / 1000 + 2)
        assert(#alive(G) == 0, "sobrou marcador: " .. #alive(G))
    end,

    overlays_walls_off_by_default = function()
        -- visto no jogo (print do Johan): desenho de fantasma sem profundidade cobre o
        -- jogador e pinta de preto paredes cortadas; o padrão é não desenhar paredes
        local G = setup({ walls = "default" })
        assert(NOM_DressingRules.WALLS == false, "paredes ligadas por padrão")
        assert(#G.frame() == 0, "parede desenhada com WALLS desligado")
    end,

    overlays_inert_on_dedicated = function()
        local G = setup({ server = true })
        NOM_FogState.set(true, 1)
        G.seconds(30)
        assert(#G.markers == 0 and G.handlers.RenderOpaqueObjectsInWorld == nil)
    end,

    -- critério: chão denso em poucos segundos, nada sem névoa, com fade de entrada
    overlays_fill_dense_floor = function()
        local G = setup()
        G.seconds(10)
        assert(#G.markers == 0, "mancha sem névoa")
        NOM_FogState.set(true, 1)
        G.seconds(1)
        local first = G.markers[1]
        assert(first and first.a < 0.5, "nasceu sem fade")
        G.seconds(10)
        local n = #alive(G)
        assert(n >= 300, "chão pouco coberto: " .. n)
        assert(math.abs(first.a - 1) < 1e-6, "não chegou no alfa cheio: " .. first.a)
        for _, m in ipairs(alive(G)) do
            local dx, dy = m.sq.x - 100, m.sq.y - 100
            assert(dx * dx + dy * dy <= D().RADIUS * D().RADIUS, "fora do raio")
        end
        assert(textures(G) > n * 1.3, "poças sem camadas: " .. textures(G) .. "/" .. n)
    end,

    overlays_red_denser = function()
        local G = setup()
        NOM_FogState.set(true, 3, false)
        G.seconds(20)
        local normal = textures(G)
        local R = setup()
        NOM_FogState.set(true, 3, true)
        R.seconds(20)
        assert(textures(R) > normal * 1.15, "vermelha não é mais densa: " .. textures(R) .. " vs " .. normal)
    end,

    -- review 0015 (crítico): com o teto cheio, andar não pode deixar o jogador no limpo.
    -- O teto serve a área mais perto: o que sai do raio efetivo cai na hora.
    overlays_walk_keeps_nearby_covered = function()
        for _, red in ipairs({ false, true }) do
            local G = setup()
            NOM_FogState.set(true, 1, red)
            G.seconds(20)
            for step = 1, 25 do
                G.p.x = G.p.x + 1
                G.seconds(1)
                if step > 3 then
                    local _, rel = coverage(G, 3)
                    assert(rel >= 0.85, (red and "vermelha" or "normal") .. ": andando, 7×7 com " .. rel .. " do que a regra pede, passo " .. step)
                end
                assert(squares(G) <= D().MAX_FLOOR, "passou do teto andando")
            end
            G.seconds(2)
            local abs = coverage(G, 3)
            assert(abs >= (red and 0.8 or 0.6), (red and "vermelha" or "normal") .. ": parado, 7×7 coberto " .. abs)
        end
    end,

    overlays_teleport_and_floor_change = function()
        local G = setup()
        NOM_FogState.set(true, 1)
        G.seconds(20)
        G.p.x, G.p.y = G.p.x + 60, G.p.y - 40
        G.seconds(3)
        assert(select(2, coverage(G, 3)) >= 0.9, "teleporte: 7×7 vazio")
        G.p.z = 1.2
        G.tick(O().UPDATE_TICKS)
        for _, m in ipairs(alive(G)) do assert(m.sq.z == 1, "mancha de outro andar ficou ocupando o teto") end
        G.seconds(3)
        assert(select(2, coverage(G, 3)) >= 0.9, "andar novo: 7×7 vazio")
    end,

    -- período desconhecido (MP, antes do comando) e depois conhecido: troca na hora
    overlays_period_known_after_nil = function()
        local G = setup()
        NOM_FogState.set(true, nil)
        G.seconds(20)
        NOM_FogState.set(true, 5)
        G.seconds(3)
        assert(select(2, coverage(G, 3)) >= 0.9, "período conhecido: 7×7 vazio")
        for _, m in ipairs(alive(G)) do
            local k = m.sq.x .. "," .. m.sq.y .. "," .. m.sq.z
            local f = D().floor(m.sq.x, m.sq.y, m.sq.z, 5, D().density(1, false))
            assert(f, "mancha do período velho ficou: " .. k)
        end
    end,

    -- densidade trocada no meio da névoa (opção, ou a vermelha forçada no debug): redesenha
    overlays_density_change_redresses = function()
        local G = setup()
        NOM_FogState.set(true, 2, false)
        G.seconds(20)
        local old = alive(G)
        NOM_FogState.set(true, 2, true)
        G.seconds(5)
        for _, m in ipairs(old) do assert(m.removed, "vermelha forçada não redesenhou") end
        local d = D().density(1, true)
        for k, v in pairs(layout(G)) do
            local x, y, z = k:match("(-?%d+),(-?%d+),(-?%d+)")
            local f = D().floor(tonumber(x), tonumber(y), tonumber(z), 2, d)
            assert(f, "square sem nada na regra vermelha: " .. k)
            assert(v:find(D().SETS[(f[#f] or f.grime)[1]].prefix .. (f[#f] or f.grime)[2], 1, true), "desenho não é o da vermelha: " .. k)
        end
        assert(select(2, coverage(G, 3)) >= 0.9)
    end,

    -- review 0015: parede que não estava à vista na varredura (porta fechada) aparece depois
    overlays_walls_door_closed_then_opened = function()
        local G = setup()
        G.p.face = math.rad(225)
        addWalls(G, 92, 92, 6)
        for x = 92, 97 do for y = 92, 97 do G.blocked[x .. "," .. y .. ",0"] = true end end
        NOM_FogState.set(true, 1)
        G.seconds(15)
        assert(#G.frame() == 0, "parede sem linha de visão desenhada")
        G.blocked = {}
        G.p.x, G.p.y = 97.5, 97.5
        G.seconds(8)
        assert(#G.frame() >= 10, "porta aberta e a sala limpa: " .. #G.frame())
    end,

    overlays_walls_survive_turning_around = function()
        local G = setup()
        G.p.face = math.rad(225)
        addWalls(G, 90, 90, 8)
        NOM_FogState.set(true, 1)
        G.seconds(15)
        local first = #G.frame()
        assert(first >= 10)
        G.p.face = math.rad(45)
        G.seconds(6)
        assert(#G.frame() == 0, "de costas e desenhou")
        G.p.face = math.rad(225)
        G.seconds(6)
        assert(#G.frame() >= first * 0.9, "virou de volta e as paredes sumiram: " .. #G.frame() .. "/" .. first)
    end,

    -- batente vazio de porta ou janela: o desenho taparia o buraco
    overlays_walls_skip_door_and_window_frames = function()
        local G = setup()
        G.p.face = math.rad(225)
        addWalls(G, 85, 85, 16)
        local flags = { "DoorWallN", "WindowN", "doorN", "windowN" }
        for x = 85, 100 do
            for y = 85, 100 do
                local f = flags[(x + y) % 4 + 1]
                G.flags[x .. "," .. y .. ",0"] = { [f] = true, [f:sub(1, -2) .. "W"] = true }
            end
        end
        NOM_FogState.set(true, 1)
        G.seconds(15)
        assert(#G.frame() == 0, "parede em batente")
    end,

    -- a parede do decalque sumiu (destruída) ou ganhou móvel: o decalque sai no rodízio
    overlays_stale_wall_dropped = function()
        local G = setup()
        G.p.face = math.rad(225)
        addWalls(G, 90, 90, 8)
        NOM_FogState.set(true, 1)
        G.seconds(15)
        assert(#G.frame() > 0)
        G.walls = {}
        G.seconds(15)
        assert(#G.frame() == 0, "decalque em parede que não existe mais")
        assert(select(2, O().count()) == 0)
    end,

    -- verificação 0015: com o raio do chão encolhido, o anel de fora não é reolhado todo lote
    overlays_open_terrain_probing_stops = function()
        local G = setup({ density = 2 })
        NOM_FogState.set(true, 1, true)
        G.seconds(40)
        assert(O().reach() < D().RADIUS, "o teto nem encolheu o raio (teste não mede nada)")
        local c0 = G.java + G.sqCalls
        G.tick(O().UPDATE_TICKS * 20)
        local per = (G.java + G.sqCalls - c0) / 20
        assert(per <= O().LIGHT_BUDGET + 10, "parado e ainda sondando: " .. per .. " chamadas por atualização")
    end,

    -- parede de costas não ocupa o teto: o raio das paredes fica largo num mundo cheio delas
    overlays_back_facing_walls_skip_cap = function()
        local G = setup()
        G.p.face = math.rad(225)
        -- bairro de cômodos 4×4: parede W a cada 4 colunas, N a cada 4 linhas
        for x = 60, 140 do
            for y = 60, 140 do
                local w = (x % 4 == 0 and "W" or "") .. (y % 4 == 0 and "N" or "")
                if w ~= "" then G.walls[x .. "," .. y .. ",0"] = w end
            end
        end
        NOM_FogState.set(true, 1)
        G.seconds(40)
        local _, wr = O().reach()
        -- só as de frente cabem no teto: ~0,19·π·r² = 120 → r ≈ 14 (com as de costas, ~10)
        assert(wr >= 12, "raio das paredes encolheu: " .. wr)
        for _, d in ipairs(G.frame()) do assert(d.x <= 100 or d.y <= 100) end
        -- anda pro sudeste: as que eram de costas passam a ser de frente e entram
        local before = #G.frame()
        G.p.x, G.p.y = G.p.x + 6, G.p.y + 6
        G.seconds(15)
        assert(#G.frame() > 0 and before > 0)
    end,

    -- o slider anda de 0,1 em 0,1: só redesenha depois de ~1 s parado
    overlays_density_debounced = function()
        local G = setup()
        local dens = 1
        NOM_ScreenFxOptions.overlayDensity = function() return dens end
        NOM_FogState.set(true, 2)
        G.seconds(20)
        local removed0 = 0
        for _, m in ipairs(G.markers) do if m.removed then removed0 = removed0 + 1 end end
        for step = 1, 8 do
            dens = 1 + step * 0.1
            G.seconds(0.2)
        end
        local removed = 0
        for _, m in ipairs(G.markers) do if m.removed then removed = removed + 1 end end
        assert(removed == removed0, "redesenhou no meio do arrasto: " .. removed - removed0)
        G.seconds(3)
        removed = 0
        for _, m in ipairs(G.markers) do if m.removed then removed = removed + 1 end end
        assert(removed > removed0, "não redesenhou depois de parar")
        assert(select(2, coverage(G, 3)) >= 0.9)
    end,

    overlays_capped = function()
        local G = setup({ density = 2 })
        G.p.face = math.rad(225)
        addWalls(G, 70, 70, 60)
        NOM_FogState.set(true, 1, true)
        G.seconds(60)
        assert(squares(G) <= D().MAX_FLOOR, "passou do teto do chão: " .. squares(G))
        assert(squares(G) >= D().MAX_FLOOR * 0.8, "não encheu até perto do teto: " .. squares(G))
        local draws = G.frame()
        assert(select(2, O().count()) <= D().MAX_WALL, "passou do teto das paredes")
        -- as de costas e fora do cone ficam na reserva, apagadas (voltam ao virar)
        assert(#draws <= D().MAX_WALL and #draws > D().MAX_WALL / 4, "paredes por quadro: " .. #draws)
    end,

    -- critério: parede desenhada só no quadro do mundo, no lugar dela, de frente e visível
    overlays_walls_drawn_in_frame = function()
        local G = setup()
        G.p.face = math.rad(225) -- olhando pro noroeste (pra -x, -y)
        addWalls(G, 85, 85, 30) -- 85..114: o jogador no meio
        NOM_FogState.set(true, 1)
        G.seconds(15)
        local draws = G.frame()
        assert(#draws >= 40, "poucas paredes: " .. #draws)
        local sides = {}
        for _, set in pairs(D().SETS) do
            -- o mesmo nome não pode estar dos dois lados (o pack separa)
            for _, i in ipairs(set.idx) do
                if set.wall then sides[set.prefix .. i] = set.wall end
            end
        end
        for _, d in ipairs(draws) do
            assert(G.walls[d.x .. "," .. d.y .. "," .. d.z], "parede onde não tem")
            assert(d.name:find("_wall_") or d.name:find("wallcracks") or d.name:find("wallvines"), d.name)
            -- de frente: N só com y <= jogador, W só com x <= jogador (o resto o jogo corta)
            local side = sides[d.name]
            assert(side, "sprite de parede desconhecido: " .. d.name)
            if side == "N" then assert(d.y <= 100, "parede N de costas") else assert(d.x <= 100, "parede W de costas") end
            assert(G.square(d.x, d.y, 0):isCouldSee(0), "parede fora da visão")
            assert(d.a > 0 and d.a <= 1 and d.l > 0 and d.l <= 1)
        end
        -- quadro sem o evento (mouse fora do mapa): nada nele, e o seguinte volta normal
        assert(#G.frame(true) == 0 and #G.frame() == #draws, "quadro sem evento estragou o seguinte")
        -- outro jogador da tela dividida: nada
        G.draws, G.inFrame = {}, true
        G.fire("RenderOpaqueObjectsInWorld", 1, 0, 0, 0, nil)
        G.inFrame = false
        assert(#G.draws == 0, "desenhou pro jogador 1")
    end,

    -- só parede limpa (piso + parede): móvel na frente ficaria por baixo do desenho sem profundidade
    overlays_walls_skip_cluttered = function()
        local G = setup()
        G.p.face = math.rad(225)
        addWalls(G, 85, 85, 16)
        for x = 85, 100 do for y = 85, 100 do G.objects[x .. "," .. y .. ",0"] = 4 end end
        NOM_FogState.set(true, 1)
        G.seconds(15)
        assert(#G.frame() == 0, "parede com móvel desenhada")
    end,

    -- luz do square: escuro escurece (sem chegar no preto), claro fica claro
    overlays_follow_square_light = function()
        local G = setup()
        G.lightAll = 0
        NOM_FogState.set(true, 1)
        G.seconds(12)
        local m = alive(G)[1]
        assert(m.color[1] < 0.75 and m.color[1] >= O().LIGHT_FLOOR - 1e-6, "luz no escuro: " .. m.color[1])
        G.lightAll = 1
        G.seconds(20)
        assert(math.abs(m.color[1] - 1) < 1e-6, "luz não foi relida: " .. m.color[1])
    end,

    -- critério: some com a névoa (fade, depois remove) e não desenha mais
    overlays_fade_out_and_removed_on_fog_end = function()
        local G = setup()
        G.p.face = math.rad(225)
        addWalls(G, 85, 85, 30)
        NOM_FogState.set(true, 1)
        G.seconds(20)
        assert(#alive(G) > 0 and #G.frame() > 0)
        NOM_FogState.set(false, 1)
        G.seconds(O().FADE_MS / 2000)
        local m = alive(G)[1]
        assert(m and m.a < 1 and m.a > 0, "sumiu sem fade")
        G.seconds(O().FADE_MS / 1000)
        assert(#alive(G) == 0, "sobrou mancha: " .. #alive(G))
        assert(#G.frame() == 0, "parede depois da névoa")
        local n = #G.markers
        G.seconds(30)
        assert(#G.markers == n, "nasceu mancha sem névoa")
    end,

    overlays_cleared_on_death_and_menu = function()
        local G = setup()
        G.p.face = math.rad(225)
        addWalls(G, 85, 85, 30)
        NOM_FogState.set(true, 1)
        G.seconds(20)
        G.p.dead = true
        G.tick(O().UPDATE_TICKS)
        assert(#alive(G) == 0 and #G.frame() == 0, "morto e ainda com sangue")
        G.p.dead = false
        G.seconds(20)
        assert(#alive(G) > 0)
        G.fire("OnMainMenuEnter")
        assert(#alive(G) == 0 and #G.frame() == 0, "menu e ainda com sangue")
        assert(O().count() == 0)
    end,

    -- critério: nada no mapa nem no save nem na rede
    overlays_never_touch_the_map = function()
        local G = setup({ density = 2 })
        G.p.face = math.rad(225)
        addWalls(G, 85, 85, 30)
        NOM_FogState.set(true, 1, true)
        G.seconds(60)
        G.frame()
        NOM_FogState.set(false, 1)
        G.seconds(20)
        assert(#G.markers > 0)
        assert(#G.sentClient == 0 and #G.sentServer == 0, "mandou pacote")
        for _ in pairs(G.globalMD) do error("escreveu ModData") end
    end,

    -- critério: determinístico por square e período, estável ao andar
    overlays_deterministic_and_stable_while_walking = function()
        local A = setup()
        NOM_FogState.set(true, 4)
        A.seconds(20)
        local la = layout(A)
        local B = setup()
        NOM_FogState.set(true, 4)
        B.seconds(20)
        local lb = layout(B)
        local same = 0
        for k, v in pairs(la) do
            if lb[k] then
                assert(lb[k] == v, "mesmo square, desenho diferente: " .. k)
                same = same + 1
            end
        end
        assert(same >= 200, "pouca sobreposição: " .. same)
        -- anda 1 tile por segundo: quem fica dentro do raio efetivo (o que o teto aguenta)
        -- não troca nem pisca
        local before = {}
        for _, m in ipairs(alive(B)) do before[m] = table.concat(m.names, "|") end
        local removedNear = 0
        for _ = 1, 5 do
            B.p.x = B.p.x + 1
            B.seconds(1)
            for m in pairs(before) do
                local dx, dy = m.sq.x - math.floor(B.p.x), m.sq.y - math.floor(B.p.y)
                local reach = O().reach()
                if m.removed and dx * dx + dy * dy < (reach - 2) ^ 2 then removedNear = removedNear + 1 end
            end
        end
        assert(removedNear == 0, "mancha perto sumiu andando: " .. removedNear)
        assert(O().reach() >= 10, "raio efetivo pequeno demais: " .. O().reach())
        for k, v in pairs(layout(B)) do
            if la[k] then assert(la[k] == v, "desenho mudou andando") end
        end
    end,

    overlays_new_period_new_layout = function()
        local G = setup()
        NOM_FogState.set(true, 2)
        G.seconds(20)
        local old = layout(G)
        NOM_FogState.set(true, 3)
        G.seconds(O().FADE_MS / 1000 + 20)
        local new, diff = layout(G), 0
        for k, v in pairs(new) do if old[k] ~= v then diff = diff + 1 end end
        assert(diff > 100, "período novo com o desenho velho: " .. diff)
        -- período desconhecido (cliente de MP antes do comando): desenha, sem erro
        local M = setup()
        NOM_FogState.set(true, nil)
        M.seconds(15)
        assert(#alive(M) > 0)
    end,

    -- andar e trocar de andar: as de longe e as do outro andar saem, nascem perto
    overlays_far_and_other_floor_removed = function()
        local G = setup()
        NOM_FogState.set(true, 1)
        G.seconds(20)
        local old = alive(G)
        G.p.x = G.p.x + 80
        G.seconds(O().FADE_MS / 1000 + 25)
        for _, m in ipairs(old) do assert(m.removed, "mancha longe ficou") end
        assert(#alive(G) > 100, "parou de nascer perto do jogador novo")
        G.p.z = 1.4 -- escada
        G.seconds(O().FADE_MS / 1000 + 25)
        for _, m in ipairs(alive(G)) do assert(m.sq.z == 1, "mancha de outro andar") end
    end,

    -- square sem chunk: tenta de novo quando carrega
    overlays_missing_square_retried = function()
        local G = setup()
        for x = 75, 125 do for y = 75, 125 do G.holes[x .. "," .. y .. ",0"] = true end end
        NOM_FogState.set(true, 1)
        G.seconds(15)
        assert(#G.markers == 0)
        G.holes = {}
        G.seconds(15)
        assert(#alive(G) > 200, "não tentou de novo: " .. #alive(G))
    end,

    overlays_density_zero_and_toggle = function()
        local G = setup({ density = 0 })
        NOM_FogState.set(true, 1)
        G.seconds(20)
        assert(#G.markers == 0, "densidade 0 com mancha")
        local S = setup({ sandbox = { FogOverlays = false } })
        NOM_FogState.set(true, 1)
        S.seconds(20)
        assert(#S.markers == 0, "desligado e nasceu mancha")
        -- densidade vai a 0 no meio da névoa: some com fade
        local M = setup()
        NOM_FogState.set(true, 1)
        M.seconds(20)
        NOM_ScreenFxOptions.overlayDensity = function() return 0 end
        M.seconds(O().FADE_MS / 1000 + 2)
        assert(#alive(M) == 0, "densidade 0 e sobrou")
    end,

    overlays_missing_sprites = function()
        local G = setup({ noTextures = true })
        addWalls(G, 85, 85, 30)
        NOM_FogState.set(true, 1)
        G.seconds(20)
        assert(#G.markers == 0 and #G.frame() == 0, "desenho sem textura")
        local B = setup({ missing = "^overlay_blood" })
        NOM_FogState.set(true, 1)
        B.seconds(20)
        assert(#alive(B) > 0)
        for _, m in ipairs(alive(B)) do
            for _, n in ipairs(m.names) do assert(not n:find("^overlay_blood"), "nome sem textura: " .. n) end
        end
    end,

    -- critério: orçamento. Por atualização (a cada 10 ticks): a varredura toca no máximo
    -- SCAN_BUDGET squares; parada (tudo posto, jogador parado) quase nada. Por quadro:
    -- uma chamada por parede desenhada, zero fora da névoa.
    overlays_budget = function()
        local G = setup({ density = 2 })
        G.p.face = math.rad(225)
        addWalls(G, 70, 70, 60)
        NOM_FogState.set(true, 1, true)
        local worst, first = 0, nil
        for _ = 1, 60 do
            local c0 = G.java + G.sqCalls
            G.tick(O().UPDATE_TICKS)
            if first then worst = math.max(worst, G.java + G.sqCalls - c0) else first = G.java + G.sqCalls - c0 end
        end
        local names = 0
        for _, set in pairs(D().SETS) do names = names + #set.idx end
        -- carga dos sprites (uma vez, 404 getTexture) fica no 1º lote; o resto:
        -- ≤ 8 por square varrido + 2 por entrada (fade/luz/visão)
        local steady = 0
        G.seconds(30)
        for _ = 1, 10 do
            local c0 = G.java + G.sqCalls
            G.tick(O().UPDATE_TICKS)
            steady = math.max(steady, G.java + G.sqCalls - c0)
        end
        if os.getenv("NOM_BUDGET") then print("orçamento: 1º", first, "lote", worst, "parado", steady) end
        local bound = 8 * O().SCAN_BUDGET + 2 * (D().MAX_FLOOR + D().MAX_WALL)
        assert(steady <= O().LIGHT_BUDGET * 2 + D().MAX_WALL + 10, "parado e caro: " .. steady)
        assert(worst <= bound, "lote caro: " .. worst)
        assert(first <= bound + names, "1º lote caro: " .. first)
        local c0 = G.java + G.sqCalls
        local draws = #G.frame()
        assert(G.java + G.sqCalls - c0 == draws and draws <= D().MAX_WALL, "quadro: " .. (G.java + G.sqCalls - c0))
        NOM_FogState.set(false, 1)
        G.seconds(O().FADE_MS / 1000 + 2)
        c0 = G.java + G.sqCalls
        G.frame()
        assert(G.java + G.sqCalls - c0 == 0, "quadro fora da névoa com chamada")
    end,
}
