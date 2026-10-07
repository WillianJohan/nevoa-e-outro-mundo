-- client/NOM_FogOverlays.lua (Outro Mundo anexado, sprint 0023) contra o mundo falso de
-- tests/fog_world.lua com os anexos de tests/attached_world.lua, que imitam o jogo (bytecode
-- B42.21, pz-api-notes §16.6): lista viva de IsoSpriteInstance por objeto, retirada que desloca
-- os índices e devolve a instância pro pool, nome sem sprite que não faz nada, anexos vanilla
-- (blend de grama em todo piso) que têm de sobreviver, OnSave antes da gravação do chunk,
-- LoadGridsquare ao carregar. O mod não pode chamar RemoveAttachedAnims, transmit* nem
-- AttachExistingAnim (o fake explode).
local W = dofile("tests/fog_world.lua")
local A = dofile("tests/attached_world.lua")
local FILE = "mod/42/media/lua/client/NOM_FogOverlays.lua"

local function setup(opts)
    opts = opts or {}
    local G = W.new(opts)
    G.reload({ "NOM_FogState", "NOM_DressingRules", "NOM_ScreenFxOptions", "NOM_FogOverlays" })
    PZAPI = nil
    require "NOM_FogState"
    require "NOM_ScreenFxOptions"
    if opts.density then NOM_ScreenFxOptions.overlayDensity = function() return opts.density end end
    require "NOM_DressingRules"
    A.install(G)
    local cell = getCell
    getCell = function() G.java = G.java + 1; return cell() end
    dofile(FILE)
    G.p = G.player({ x = 100, y = 100 })
    return G
end

local O = function() return NOM_FogOverlays end
local D = function() return NOM_DressingRules end

local function density()
    return D().density(NOM_ScreenFxOptions.overlayDensity(), NOM_FogState.red, NOM_FogState.black)
end

-- o que a regra pede pro objeto (kind "F", "N", "W") do square, na ordem em que o mod anexa
local function expect(G, x, y, z, kind)
    local sq = G.square(x, y, z)
    local outside = sq:isOutside()
    local per, d, red, black = NOM_FogState.period or 0, density(), NOM_FogState.red, NOM_FogState.black
    local out = {}
    if kind == "F" then
        local o = G.objs[x .. "," .. y .. "," .. z .. "F"]
        local natural = not black and D().natural(o and (rawget(o, "sprite") or nil) or G.floorSprite(x, y, z))
        local f = D().floor(x, y, z, per, d, outside, red, natural, black)
        for _, l in ipairs(f or {}) do out[#out + 1] = D().name(l) end
        if f and f.grime then out[#out + 1] = D().name(f.grime) end
    else
        for _, l in ipairs(D().wall(x, y, z, per, d, kind == "N", outside, red, black) or {}) do
            out[#out + 1] = D().name(l)
        end
    end
    return table.concat(out, "|")
end

local function mods(G, o) return table.concat(G.attachedNames(o, "mod"), "|") end

-- paredes N e W (objetos simples) em todo square de um bloco
local function walls(G, x0, y0, n)
    for x = x0, x0 + n - 1 do
        for y = y0, y0 + n - 1 do
            G.obj(x, y, 0, "N")
            G.obj(x, y, 0, "W")
        end
    end
end

-- todo objeto carregado a até r tiles do jogador tem exatamente o que a regra pede
local function laidOut(G, r)
    local px, py, pz = math.floor(G.p.x), math.floor(G.p.y), math.floor(G.p.z)
    local n = 0
    for _, o in pairs(G.objs) do
        local dx, dy = o.x - px, o.y - py
        if o.z == pz and dx * dx + dy * dy <= r * r and o.class == "IsoObject" then
            local want = expect(G, o.x, o.y, o.z, o.kind)
            assert(mods(G, o) == want, o.kind .. " " .. o.x .. "," .. o.y .. ": tem " .. mods(G, o) .. ", pede " .. want)
            if want ~= "" then n = n + 1 end
        end
    end
    return n
end

-- os anexos vanilla de todo objeto, pra comparar depois
local function vanillaOf(G)
    local out = {}
    for k, o in pairs(G.objs) do out[k] = table.concat(G.attachedNames(o, "vanilla"), "|") end
    return out
end

local function sameVanilla(G, before, skip)
    for k, v in pairs(before) do
        if not (skip and skip[k]) then
            assert(table.concat(G.attachedNames(G.objs[k], "vanilla"), "|") == v, "anexo vanilla mexido em " .. k)
        end
    end
end

-- maior distância de um anexo do mod até (x, y)
local function farthest(G, x, y)
    local m = 0
    for _, o in pairs(G.objs) do
        if #G.attachedNames(o, "mod") > 0 then
            m = math.max(m, math.sqrt((o.x - x) ^ 2 + (o.y - y) ^ 2))
        end
    end
    return m
end

-- 0 squares errados: no raio, todo objeto tem exatamente o que a regra pede agora; fora dele,
-- nada do mod. Devolve quantos a regra veste
local function exact(G)
    local n = laidOut(G, O().radius())
    local f = farthest(G, math.floor(G.p.x), math.floor(G.p.y))
    assert(f <= O().radius(), "anexo do mod a " .. f .. " tiles (raio " .. O().radius() .. ")")
    return n
end

-- A névoa abre ao vivo (sprint 0035): a sirene sobe a névoa visual, a borda chega com a subida
-- ainda ligada e ela desce depois (solo: NOM_FogEvent.begin chama setFog antes do rise(false);
-- MP: o comando fog faz set antes do dropRising, client/NOM_FogClient.lua).
local function liveOpen(per, red)
    NOM_FogState.setRising(true, red)
    NOM_FogState.set(true, per or 3, red)
    NOM_FogState.setRising(false)
end

-- atraso de revelação do square, em ms
local function delay(x, y, per)
    return D().reveal(x, y, 0, per or NOM_FogState.period) * O().REVEAL_MS
end

-- pisos carregados num bloco (o fake só cria o objeto quando alguém pede)
local function floors(G, x0, y0, x1, y1)
    for x = x0, x1 do for y = y0, y1 do G.floorOf(x, y, 0) end end
end

-- os objetos que a regra veste a até r tiles de (100, 100): { obj, want }
local function wanted(G, r)
    local out = {}
    for _, o in pairs(G.objs) do
        if o.z == 0 and o.class == "IsoObject" and (o.x - 100) ^ 2 + (o.y - 100) ^ 2 <= r * r then
            local want = expect(G, o.x, o.y, 0, o.kind)
            if want ~= "" then out[#out + 1] = { obj = o, want = want } end
        end
    end
    return out
end

-- primeiro square perto do jogador cujo piso a regra enche com a condição pedida
local function findFloor(G, cond)
    for r = 1, 10 do
        for x = 100 - r, 100 + r do
            for y = 100 - r, 100 + r do
                local w = expect(G, x, y, 0, "F")
                if w ~= "" and cond(w, x, y) then return x, y, w end
            end
        end
    end
    error("nenhum square com a condição")
end

-- Faixas de distância do jogador, [de, até) em tiles, pra cobertura andando (Tarefa 5c).
local BANDS = { { 15, 20 }, { 20, 25 }, { 25, 30 } }

-- fração dos pisos que a regra pede, em cada faixa, que estão vestidos agora
local function coverage(G)
    local px, py = math.floor(G.p.x), math.floor(G.p.y)
    local R = BANDS[#BANDS][2]
    local want, got = {}, {}
    for i = 1, #BANDS do want[i], got[i] = 0, 0 end
    for dx = -R, R do
        for dy = -R, R do
            local d = math.sqrt(dx * dx + dy * dy)
            for i, b in ipairs(BANDS) do
                if d >= b[1] and d < b[2] then
                    local x, y = px + dx, py + dy
                    local w = expect(G, x, y, 0, "F")
                    if w ~= "" then
                        want[i] = want[i] + 1
                        local o = G.objs[x .. "," .. y .. ",0F"]
                        if o and mods(G, o) == w then got[i] = got[i] + 1 end
                    end
                end
            end
        end
    end
    local out = {}
    for i = 1, #BANDS do out[i] = got[i] / math.max(1, want[i]) end
    return out
end

-- Anda em +x a speed tiles/s (tick de 16 ms) por secs segundos; a cada segundo depois de warm,
-- uma amostra da cobertura. A cada UPDATE_TICKS (uma atualização) mede o custo e confere que
-- nada passa do corte duro. Devolve a média por faixa e o pior custo (idas ao Java) de uma
-- atualização.
local function walkCoverage(G, speed, secs, warm)
    local step = speed * 0.016
    local sum, n, worst = { 0, 0, 0 }, 0, 0
    local limit = D().MAX_RADIUS + O().SLACK + O().MOVE_TILES + 1.5
    local perSec = math.floor(1000 / 16 + 0.5)
    local j = G.java + G.sqCalls
    for t = 1, secs * perSec do
        G.p.x = G.p.x + step
        G.tick(1)
        if t % O().UPDATE_TICKS == 0 then
            worst = math.max(worst, G.java + G.sqCalls - j)
            local f = farthest(G, G.p.x, G.p.y)
            assert(f <= limit, "anexo a " .. f .. " tiles andando")
            j = G.java + G.sqCalls
        end
        if t % perSec == 0 and t / perSec > warm then
            local before = G.java + G.sqCalls
            local c = coverage(G)
            j = j + G.java + G.sqCalls - before -- a medição da cobertura não conta
            for i = 1, #BANDS do sum[i] = sum[i] + c[i] end
            n = n + 1
        end
    end
    for i = 1, #BANDS do sum[i] = sum[i] / n end
    return sum, worst
end

-- quantos squares inteiros estão a até r tiles de um ponto (teto do "já visto" em volta dele)
local function disk(r)
    local n, R = 0, math.ceil(r)
    for dx = -R, R do
        for dy = -R, R do
            if dx * dx + dy * dy <= r * r then n = n + 1 end
        end
    end
    return n
end

return {
    -- o piso e as paredes N/W ganham, anexados pelo nome, exatamente o que a regra pede (fora e
    -- dentro); o blend vanilla de cada piso fica
    overlays_attach_floor_and_walls = function()
        local G = setup({ density = 1 })
        walls(G, 96, 96, 8)
        for x = 102, 110 do for y = 102, 110 do G.interior[x .. "," .. y .. ",0"] = { name = "casa" } end end
        NOM_FogState.set(true, 3)
        G.seconds(5)
        local n = laidOut(G, D().MIN_RADIUS)
        assert(n > 400, "pouco anexado: " .. n)
        local wallsDressed = 0
        for _, o in pairs(G.objs) do
            if o.kind ~= "F" and mods(G, o) ~= "" then wallsDressed = wallsDressed + 1 end
        end
        assert(wallsDressed > 40, "paredes sem nada: " .. wallsDressed)
        local fl, wl = O().count()
        assert(fl > 300 and wl == wallsDressed, "count: " .. fl .. "/" .. wl)
    end,

    -- sprint 0039: na preta o Outro Mundo queima (cinza, brasa, fuligem; sem metal), exatamente o
    -- que a regra pede; a preta acabando em branca refaz o desenho
    overlays_black_burnt = function()
        local G = setup({ density = 1 })
        walls(G, 96, 96, 8)
        for x = 102, 110 do for y = 102, 110 do G.interior[x .. "," .. y .. ",0"] = { name = "casa" } end end
        NOM_FogState.set(true, 3, false, true)
        G.seconds(5)
        assert(laidOut(G, D().MIN_RADIUS) > 400, "pouco anexado na preta")
        local has = {}
        for _, o in pairs(G.objs) do
            for _, n in ipairs(G.attachedNames(o, "mod")) do
                local kind = n:match("NOM_OM_(%a+)_")
                if kind then has[kind] = true end
            end
        end
        assert(has.Cinza and has.Fuligem, "sem cinza ou fuligem na preta")
        assert(not has.Grade and not has.Chapa and not has.Tinta, "metal da branca na preta")
        NOM_FogState.set(true, 3)
        G.seconds(5)
        laidOut(G, D().MIN_RADIUS)
    end,

    -- sprint 0034, "casa destruída": a parede de dentro ganha as camadas empilhadas na ordem da
    -- regra (rachadura embaixo, pichação em cima); a pichação de fora também sai; nada fora do pack
    overlays_inside_walls_stacked = function()
        local G = setup({ density = 1 })
        walls(G, 90, 90, 20)
        for x = 90, 99 do for y = 90, 109 do G.interior[x .. "," .. y .. ",0"] = { name = "casa" } end end
        NOM_FogState.set(true, 3)
        G.seconds(5)
        laidOut(G, D().MIN_RADIUS)
        local stacked, writingIn, writingOut = 0, 0, 0
        for _, o in pairs(G.objs) do
            if o.kind ~= "F" then
                local names = G.attachedNames(o, "mod")
                local inside = o.x <= 99
                if inside and #names >= 2 then stacked = stacked + 1 end
                for _, n in ipairs(names) do
                    if n:find("^overlay_graffiti") or n:find("^overlay_messages") then
                        if inside then writingIn = writingIn + 1 else writingOut = writingOut + 1 end
                    end
                    if not inside then assert(#names == 1, "parede de fora empilhada") end
                end
            end
        end
        assert(stacked > 150, "parede de dentro sem camadas: " .. stacked)
        assert(writingIn > 10 and writingOut > 5, "pichação dentro " .. writingIn .. ", fora " .. writingOut)
    end,

    -- sprint 0034: o Outro Mundo espera o fim da fuga (decisão do Johan); a subida da sirene
    -- não anexa nada
    overlays_wait_for_grace = function()
        local G = setup({ density = 1 })
        NOM_FogState.period = 3
        NOM_FogState.setRising(true, true)
        G.seconds(5)
        assert(G.ours() == 0, "Outro Mundo na fuga: " .. G.ours())
    end,
    -- review focus: o anexo vanilla (blend em todo piso, trepadeira de erosão na parede, sujeira
    -- do mapa) sobrevive a todo caminho: sair do raio, voltar, ação, save, densidade, fim da névoa
    overlays_vanilla_attachments_survive_every_path = function()
        local G = setup({ density = 2 })
        walls(G, 96, 96, 8)
        G.vanillaAttach(G.objs["97,97,0N"], "f_wallvines_1_2")
        G.vanillaAttach(G.floorOf(99, 101, 0), "overlay_grime_floor_01_40")
        for x = 80, 130 do for y = 80, 130 do G.floorOf(x, y, 0) end end
        local before = vanillaOf(G)
        NOM_FogState.set(true, 3, true)
        G.seconds(4)
        assert(G.ours() > 500, "não encheu")
        sameVanilla(G, before)
        for _ = 1, 50 do G.p.x = G.p.x + 0.5; G.tick(1) end -- 25 tiles de carro
        G.seconds(3)
        for _ = 1, 50 do G.p.x = G.p.x - 0.5; G.tick(1) end
        G.seconds(3)
        sameVanilla(G, before)
        G.action(G.p, { character = G.p, square = G.square(99, 101, 0) })
        G.seconds(1)
        G.action(G.p, nil)
        G.seconds(3)
        G.saveSnapshot()
        G.seconds(3)
        NOM_ScreenFxOptions.overlayDensity = function() return 1 end
        G.seconds(5)
        sameVanilla(G, before)
        NOM_FogState.set(false)
        G.seconds(5)
        assert(G.ours() == 0, "sobrou anexo do mod: " .. G.ours())
        sameVanilla(G, before)
    end,

    -- review focus: decalque do mapa com o MESMO nome que o do mod no mesmo piso, antes e depois
    -- do do mod na lista: o mod tira só a instância que pôs
    overlays_same_name_vanilla_decal_survives = function()
        local G = setup({ density = 1 })
        NOM_FogState.set(true, 3)
        local x, y, want = findFloor(G, function(w) return w:find("d_streetcracks_1_") ~= nil end)
        local name = want:match("(d_streetcracks_1_%d+)")
        local floor = G.floorOf(x, y, 0)
        G.vanillaAttach(floor, name)
        G.seconds(3)
        assert(mods(G, floor) == want, "não anexou: " .. mods(G, floor))
        G.vanillaAttach(floor, name) -- outro, depois do do mod (erosão, mapa): o de trás pra frente o acha primeiro
        NOM_FogState.set(false)
        G.seconds(5)
        assert(mods(G, floor) == "", "sobrou do mod")
        local v = table.concat(G.attachedNames(floor, "vanilla"), "|")
        assert(select(2, v:gsub(name:gsub("_", "%%_"), "")) == 2, "decalque vanilla de mesmo nome tirado: " .. v)
    end,

    -- review focus: a pá limpa a lista (RemoveAttachedAnims: as instâncias, inclusive as do mod,
    -- voltam pro pool) e o vanilla anexa um blend novo, que reusa a instância que era do mod. O
    -- mod nunca tira esse blend
    overlays_pool_reuse_never_removes_vanilla = function()
        local G = setup({ density = 1 })
        NOM_FogState.set(true, 3)
        local x, y = findFloor(G, function() return true end)
        G.seconds(3)
        local floor = G.floorOf(x, y, 0)
        local reused = rawget(floor, "list")[#rawget(floor, "list")] -- a última instância do mod
        assert(not reused.vanilla)
        G.wipe(floor)
        G.vanillaAttach(floor, "blends_natural_01_9")
        assert(rawget(floor, "list")[1] == reused, "o fake não reusou a instância (teste não mede)")
        NOM_FogState.set(false)
        G.seconds(5)
        local v = table.concat(G.attachedNames(floor, "vanilla"), "|")
        assert(v == "blends_natural_01_9", "o blend novo sumiu: " .. v)
    end,

    -- só piso e parede simples: nada em construção do jogador (IsoThumpable), porta, janela,
    -- parede com batente de porta/janela no lado, nem piso de água
    overlays_targets_only_plain_objects = function()
        local G = setup({ density = 2 })
        G.obj(101, 100, 0, "F", { class = "IsoThumpable" })
        G.obj(101, 100, 0, "N", { class = "IsoThumpable" })
        G.obj(102, 100, 0, "N", { class = "IsoDoor" })
        G.obj(103, 100, 0, "W", { class = "IsoWindow" })
        G.obj(104, 100, 0, "N")
        G.flags["104,100,0"] = { DoorWallN = true }
        G.obj(105, 100, 0, "W")
        G.flags["105,100,0"] = { WindowW = true }
        G.water["106,100,0"] = true
        G.floorOf(106, 100, 0)
        NOM_FogState.set(true, 3, true)
        G.seconds(4)
        for _, k in ipairs({ "101,100,0F", "101,100,0N", "102,100,0N", "103,100,0W", "104,100,0N", "105,100,0W", "106,100,0F" }) do
            assert(mods(G, G.objs[k]) == "", "anexou em " .. k)
        end
        assert(mods(G, G.floorOf(105, 100, 0)) ~= "" or expect(G, 105, 100, 0, "F") == "", "o piso do square com batente também saiu")
    end,

    -- review final da 0035: as fontes das lascas pedem só o andar e o raio delas; o registro
    -- inteiro não é copiado a cada segundo
    overlays_targets_filtered = function()
        local G = setup({ density = 2, zoom = 2.5 })
        walls(G, 70, 70, 60)
        NOM_FogState.set(true, 3, true)
        G.seconds(10)
        local all, r = O().targets(), 14
        local near = O().targets(100, 100, 0, r)
        local want = 0
        for _, e in ipairs(all) do
            if e.z == 0 and (e.x - 100) ^ 2 + (e.y - 100) ^ 2 <= r * r then want = want + 1 end
        end
        assert(want > 300 and #all > 2 * want, "pouco pra medir: " .. want .. " de " .. #all)
        assert(#near == want, "filtrou " .. #near .. ", pede " .. want)
        for _, e in ipairs(near) do
            assert(e.z == 0 and (e.x - 100) ^ 2 + (e.y - 100) ^ 2 <= r * r, "fora: " .. e.k)
        end
        assert(#O().targets(100, 100, 1, r) == 0, "outro andar")
    end,

    -- a sujeira vai mais leve: a instância dela com alfa GRIME_ALPHA (e o alvo do alfa igual: o
    -- jogo não puxa de volta); o resto, 1
    overlays_grime_lighter = function()
        local G = setup({ density = 1 })
        NOM_FogState.set(true, 3)
        local x, y = findFloor(G, function(w) return w:find("overlay_grime_floor") ~= nil end)
        G.seconds(3)
        local seen = 0
        for _, inst in ipairs(rawget(G.floorOf(x, y, 0), "list")) do
            if not inst.vanilla then
                local grime = inst.name:find("^overlay_grime") ~= nil
                assert(inst.alpha == (grime and D().GRIME_ALPHA or 1) and inst.target == inst.alpha, inst.name .. " alfa " .. inst.alpha)
                if grime then seen = seen + 1 end
            end
        end
        assert(seen == 1)
    end,

    -- chão queimado só dentro, mato e folha só fora (o cliente lê isOutside do square)
    overlays_burnt_inside_plants_outside = function()
        local G = setup({ density = 2 })
        for x = 100, 115 do for y = 85, 115 do G.interior[x .. "," .. y .. ",0"] = { name = "casa" } end end
        NOM_FogState.set(true, 3)
        G.seconds(4)
        local burnt, plants = 0, 0
        for _, o in pairs(G.objs) do
            for _, n in ipairs(G.attachedNames(o, "mod")) do
                local inside = o.x >= 100 and o.x <= 115 and o.y >= 85 and o.y <= 115
                if n:find("^floors_burnt_01_") then
                    assert(inside, "queimado fora: " .. o.x .. "," .. o.y)
                    burnt = burnt + 1
                end
                if n:find("^d_plants") or n:find("^d_floorleaves") then
                    assert(not inside, "mato dentro: " .. o.x .. "," .. o.y)
                    plants = plants + 1
                end
            end
        end
        assert(burnt > 10 and plants > 10, "queimado " .. burnt .. ", mato " .. plants)
    end,

    -- o chunk que sai do mapa é gravado (ChunkSaveWorker) a ≥ 48 tiles: com o zoom mais longe
    -- (raio MAX) e andando de carro (meio tile por tick), nada do mod passa de MAX_RADIUS +
    -- SLACK mais MOVE_TILES (o corte na hora roda a cada MOVE_TILES andados), em nenhum tick;
    -- parado, do raio. 1,5: o anexo é do square (inteiro) e o jogador está no meio do tile
    overlays_leaving_radius_strips = function()
        local G = setup({ density = 2, zoom = 2.5 })
        NOM_FogState.set(true, 3, true)
        G.seconds(8)
        assert(O().radius() == D().MAX_RADIUS, "raio " .. O().radius())
        assert(farthest(G, G.p.x, G.p.y) > D().MAX_RADIUS - 2, "não encheu até o raio (teste não mede)")
        for _ = 1, 240 do
            G.p.x = G.p.x + 0.5
            G.p.y = G.p.y + 0.25
            G.tick(1)
            local f = farthest(G, G.p.x, G.p.y)
            assert(f <= D().MAX_RADIUS + O().SLACK + O().MOVE_TILES + 1.5 and f < 48, "anexo a " .. f .. " tiles andando")
        end
        G.seconds(10)
        local r = O().radius()
        assert(farthest(G, G.p.x, G.p.y) <= r + 0.75, "parado, longe demais: " .. farthest(G, G.p.x, G.p.y))
        assert(laidOut(G, r - 1) > 1500, "o lugar novo não encheu")
    end,

    -- o fake é o jogo: o centro da tela cai no jogador (PlayerCamera.center), 0,875 tile pra
    -- trás (playerOffsetY −56 px); o canto de cima à esquerda, ~16 tiles a oeste no zoom 1
    overlays_fake_camera_matches_game = function()
        local G = setup({ density = 1 })
        local w, h = G.screenW * G.zoom, G.screenH * G.zoom
        local cx, cy = IsoUtils.XToIso(0, w / 2, h / 2, 0), IsoUtils.YToIso(0, w / 2, h / 2, 0)
        assert(math.abs(cx - (G.p.x - 0.875)) < 1e-6 and math.abs(cy - (G.p.y - 0.875)) < 1e-6, cx .. "," .. cy)
        local x0, y0 = IsoUtils.XToIso(0, 0, 0, 0), IsoUtils.YToIso(0, 0, 0, 0)
        assert(math.abs(x0 - (G.p.x - 0.875 - 2040 / 128)) < 1e-6 and math.abs(y0 - (G.p.y - 0.875 - 120 / 128)) < 1e-6, x0 .. "," .. y0)
        -- a direção do mapa: x cresce pra direita e pra baixo na tela
        assert(IsoUtils.XToIso(0, w, h, 0) > cx and IsoUtils.YToIso(0, 0, h, 0) > cy)
    end,

    -- o raio segue a tela: zoom de perto fica no mínimo; zoom longe leva o Outro Mundo além de
    -- MIN_RADIUS, até o raio calculado pelos cantos e não além
    overlays_radius_follows_zoom = function()
        for _, c in ipairs({ { zoom = 0.5, min = 15, max = 15 }, { zoom = 1, min = 18, max = 20 },
            { zoom = 1.5, min = 25, max = 28 }, { zoom = 2.5, min = 30, max = 30 } }) do
            local G = setup({ density = 2, zoom = c.zoom })
            NOM_FogState.set(true, 3, true)
            G.seconds(8)
            local r = O().radius()
            assert(r >= c.min and r <= c.max, "zoom " .. c.zoom .. ": raio " .. r)
            local f = farthest(G, G.p.x, G.p.y)
            assert(f <= r + 0.75, "zoom " .. c.zoom .. ": anexo a " .. f .. " (raio " .. r .. ")")
            assert(f > r - 1.5, "zoom " .. c.zoom .. ": não chegou no raio, só a " .. f)
            laidOut(G, r)
        end
    end,

    -- o carro olha pra frente (deferedX/Y) ou o jogador mira (rightClick): a câmera sai do
    -- centro e o raio cobre o canto que ficou mais longe
    overlays_radius_off_center_camera = function()
        local G = setup({ density = 1, zoom = 1 })
        NOM_FogState.set(true, 3)
        G.tick(O().UPDATE_TICKS)
        local centered = O().radius()
        G.camera.deferX, G.camera.deferY = 6, 6
        G.tick(O().UPDATE_TICKS)
        assert(O().radius() >= centered + 5, "câmera adiantada: " .. centered .. " → " .. O().radius())
    end,

    -- zoom chegando perto: o que passou do raio novo sai em lotes de STRIP_BUDGET (não tudo de
    -- uma vez), e nada passa de MAX_RADIUS + SLACK
    overlays_zoom_in_strips_in_batches = function()
        local G = setup({ density = 2, zoom = 2.5 })
        NOM_FogState.set(true, 3, true)
        G.seconds(8)
        local function beyond(r)
            local n = 0
            for _, o in pairs(G.objs) do
                if #G.attachedNames(o, "mod") > 0 and (o.x - 100) ^ 2 + (o.y - 100) ^ 2 > r * r then n = n + 1 end
            end
            return n
        end
        local outside = beyond(D().MIN_RADIUS)
        assert(outside > 3 * O().STRIP_BUDGET, "pouco além do mínimo (teste não mede o lote): " .. outside)
        G.zoom = 0.5
        local updates, stillThere = 0, false
        while beyond(D().MIN_RADIUS) > 0 do
            local a, b = O().count()
            G.tick(O().UPDATE_TICKS)
            updates = updates + 1
            local c, e = O().count()
            assert(a + b - (c + e) <= O().STRIP_BUDGET, "lote grande demais: " .. (a + b - c - e))
            assert(farthest(G, G.p.x, G.p.y) <= D().MAX_RADIUS + O().SLACK, "passou da folga")
            if updates == 1 and beyond(D().MIN_RADIUS) > 0 then stillThere = true end
            assert(updates < 80, "não esvaziou o anel de fora")
        end
        assert(stillThere, "arrancou tudo de uma vez")
        assert(O().radius() == D().MIN_RADIUS)
        laidOut(G, D().MIN_RADIUS)
    end,

    -- fim da névoa: tudo do mod sai, em lotes de STRIP_BUDGET alvos por atualização
    overlays_fog_end_strips_all = function()
        local G = setup({ density = 2 })
        walls(G, 95, 95, 10)
        NOM_FogState.set(true, 3, true)
        G.seconds(4)
        local fl, wl = O().count()
        local total = fl + wl
        assert(total > 2 * O().STRIP_BUDGET, "pouco pra medir o lote: " .. total)
        NOM_FogState.set(false)
        local updates = 0
        while true do
            local a, b = O().count()
            if a + b == 0 then break end
            G.tick(O().UPDATE_TICKS)
            updates = updates + 1
            local c, e = O().count()
            assert(a + b - (c + e) <= O().STRIP_BUDGET, "lote grande demais: " .. (a + b - c - e))
            assert(updates < 40, "não esvaziou")
        end
        assert(G.ours() == 0, "registro vazio mas sobrou anexo: " .. G.ours())
    end,

    -- período ou densidade novos: outro desenho, sem duplicar nada
    overlays_period_and_density_redraw = function()
        local G = setup({ density = 1 })
        walls(G, 96, 96, 8)
        NOM_FogState.set(true, 3)
        G.seconds(4)
        laidOut(G, D().MIN_RADIUS)
        NOM_FogState.set(true, 4)
        G.seconds(8)
        laidOut(G, D().MIN_RADIUS)
        NOM_ScreenFxOptions.overlayDensity = function() return 2 end
        G.seconds(8)
        laidOut(G, D().MIN_RADIUS)
        NOM_FogState.set(true, 4, true)
        G.seconds(8)
        assert(laidOut(G, D().MIN_RADIUS) > 500, "vermelha rala")
    end,

    -- o slider anda de 0,1 em 0,1: a densidade nova só vale parada DENSITY_MS
    overlays_density_debounced = function()
        local G = setup({ density = 1 })
        NOM_FogState.set(true, 3)
        G.seconds(4)
        local x, y = findFloor(G, function() return true end)
        local before = mods(G, G.floorOf(x, y, 0))
        for i = 1, 6 do
            NOM_ScreenFxOptions.overlayDensity = function() return 1 + i / 10 end
            G.seconds(0.4)
            assert(mods(G, G.floorOf(x, y, 0)) == before, "redesenhou com o slider andando")
        end
        G.seconds(8)
        laidOut(G, D().MIN_RADIUS)
    end,

    -- a lista mexida por baixo (pá do vanilla limpa tudo; MP: o servidor manda a lista dele):
    -- o mod põe de novo o que falta, sem duplicar e sem nada explodir
    overlays_reapply_after_list_wiped = function()
        local G = setup({ density = 1 })
        NOM_FogState.set(true, 3)
        local x, y, want = findFloor(G, function() return true end)
        G.seconds(3)
        local floor = G.floorOf(x, y, 0)
        G.wipe(floor)
        G.seconds(15)
        assert(mods(G, floor) == want, "não voltou: " .. mods(G, floor) .. " / " .. want)
        laidOut(G, D().MIN_RADIUS)
    end,

    -- o objeto trocado (pacote do servidor no MP): o novo ganha o desenho; o velho, fora do
    -- mundo, não é tocado
    overlays_reapply_after_object_replaced = function()
        local G = setup({ density = 1 })
        NOM_FogState.set(true, 3)
        local x, y, want = findFloor(G, function() return true end)
        G.seconds(3)
        local old = G.floorOf(x, y, 0)
        local oldNames = table.concat(G.attachedNames(old), "|")
        local new = G.replace(x, y, 0, "F")
        G.seconds(15)
        assert(mods(G, new) == want, "o novo ficou sem: " .. mods(G, new))
        assert(table.concat(G.attachedNames(old), "|") == oldNames, "mexeu no objeto velho")
        NOM_FogState.set(false)
        G.seconds(5)
        assert(mods(G, new) == "", "sobrou no novo")
    end,

    -- review focus: nome sem sprite (pack diferente): nada anexado com ele, nada explode, o
    -- resto sai normal
    overlays_missing_sprites = function()
        local G = setup({ density = 2 })
        for i = 0, 111 do G.unknown["d_streetcracks_1_" .. i] = true end
        NOM_FogState.set(true, 3, true)
        G.seconds(4)
        local any = 0
        for _, o in pairs(G.objs) do
            for _, n in ipairs(G.attachedNames(o, "mod")) do
                assert(not n:find("^d_streetcracks"), "anexou nome sem sprite")
                any = any + 1
            end
        end
        assert(any > 100, "o resto não saiu")
        NOM_FogState.set(false)
        G.seconds(5)
        assert(G.ours() == 0)
    end,

    overlays_inert_on_dedicated = function()
        local G = setup({ server = true })
        assert(G.handlers.OnTick == nil and G.handlers.OnSave == nil and G.handlers.LoadGridsquare == nil,
            "o cliente roda no dedicado")
    end,

    -- nada pela rede (o fake de objeto explode em transmit*)
    overlays_never_touch_the_network = function()
        local G = setup({ density = 2, client = true })
        walls(G, 96, 96, 8)
        NOM_FogState.set(true, 3, true)
        G.seconds(4)
        G.saveSnapshot()
        NOM_FogState.set(false)
        G.seconds(5)
        assert(#G.sentServer == 0 and #G.sentClient == 0, "mandou comando")
    end,

    -- andar e voltar: o mesmo desenho; o que fica no raio não é tirado e posto de novo
    overlays_deterministic_and_stable_while_walking = function()
        local G = setup({ density = 1 })
        NOM_FogState.set(true, 3)
        G.seconds(4)
        -- a instância de cada anexo do mod a até 8 tiles (fica no raio o caminho todo)
        local near = {}
        for _, o in pairs(G.objs) do
            if (o.x - 100) ^ 2 + (o.y - 100) ^ 2 <= 64 then
                for _, inst in ipairs(rawget(o, "list") or {}) do
                    if not inst.vanilla then near[inst] = o end
                end
            end
        end
        assert(next(near), "nada perto (teste não mede)")
        for _ = 1, 4 do G.p.x = G.p.x + 1; G.seconds(0.5) end
        for _ = 1, 4 do G.p.x = G.p.x - 1; G.seconds(0.5) end
        G.seconds(3)
        for inst, o in pairs(near) do
            local still = false
            for _, i in ipairs(rawget(o, "list")) do if i == inst then still = true end end
            assert(still, "o anexo perto foi tirado e posto de novo andando: " .. o.x .. "," .. o.y)
        end
        laidOut(G, D().MIN_RADIUS)
    end,

    -- trocou de andar: o andar velho sai, o novo enche
    overlays_other_floor_stripped = function()
        local G = setup({ density = 1 })
        NOM_FogState.set(true, 3)
        G.seconds(4)
        G.p.z = 1
        G.seconds(5)
        for _, o in pairs(G.objs) do
            if o.z == 0 then assert(mods(G, o) == "", "sobrou no andar de baixo") end
        end
        assert(laidOut(G, D().MIN_RADIUS) > 300, "o andar de cima não encheu")
    end,

    -- custo por atualização (10 ticks): enchendo e parado, no zoom 1 e no mais longe (raio MAX:
    -- a volta da varredura tem #OFFSETS squares); e com as paredes dentro de casa (camadas
    -- empilhadas, sprint 0034)
    overlays_budget = function()
        for _, c in ipairs({ { zoom = 1 }, { zoom = 2.5 }, { zoom = 1, inside = true }, { zoom = 2.5, reveal = true } }) do
            local zoom = c.zoom
            local G = setup({ density = 2, zoom = zoom })
            walls(G, 90, 90, 20)
            if c.inside then
                for x = 90, 109 do for y = 90, 109 do G.interior[x .. "," .. y .. ",0"] = { name = "casa" } end end
            end
            if c.reveal then liveOpen(3, true) else NOM_FogState.set(true, 3, true) end
            -- revelando (sprint 0035), o enchimento vai até o fim do REVEAL_MS
            local fillEnd = c.reveal and 50 or 10
            local maxFill, maxIdle, maxInv = 0, 0, 0
            for i = 1, 90 do
                local j, inv = G.java + G.sqCalls, G.invalidations
                G.tick(O().UPDATE_TICKS)
                local cost = G.java + G.sqCalls - j
                if i <= fillEnd then maxFill = math.max(maxFill, cost) elseif i > 60 then maxIdle = math.max(maxIdle, cost) end
                maxInv = math.max(maxInv, G.invalidations - inv)
            end
            local laps = math.ceil(D().WITHIN[O().radius()] / O().SCAN_BUDGET)
            assert(maxFill <= 2500, "enchendo: " .. maxFill .. " chamadas por atualização")
            assert(maxIdle <= 300, "parado: " .. maxIdle .. " chamadas por atualização")
            -- ≤ 80 squares por lote: MAX_LAYERS + sujeira no piso e WALL_LAYERS em cada parede
            assert(maxInv <= O().SCAN_BUDGET * (D().MAX_LAYERS + 1 + 2 * D().WALL_LAYERS), "invalidações por lote: " .. maxInv)
            print(string.format("[budget] outro mundo (zoom %.1f%s, raio %d, volta %d squares = %d atualizações): enchendo %d, parado %d chamadas, %d invalidações por atualização",
                zoom, c.inside and ", casa" or c.reveal and ", revelando" or "", O().radius(), D().WITHIN[O().radius()], laps, maxFill, maxIdle, maxInv))
        end
    end,

    -- SAVE (Task 4) ------------------------------------------------------------------------

    -- o OnSave sai antes do IsoCell.save gravar os chunks (GameWindow.save 302 → 364): o que o
    -- save grava não tem nada do mod; o vanilla fica
    overlays_on_save_nothing_ours = function()
        local G = setup({ density = 2 })
        walls(G, 96, 96, 8)
        NOM_FogState.set(true, 3, true)
        G.seconds(4)
        local before = vanillaOf(G)
        assert(G.ours() > 500)
        local snap = G.saveSnapshot()
        assert(snap.ours == 0, "o save gravaria " .. snap.ours .. " anexos do mod")
        sameVanilla(G, before)
    end,

    -- volta depois do save, igual, sem precisar do OnPostSave (só sai na saída do jogo; acordar
    -- salva sem ele: SleepingEvent.wakeUp)
    overlays_back_after_save = function()
        local G = setup({ density = 1 })
        walls(G, 96, 96, 8)
        NOM_FogState.set(true, 3)
        G.seconds(4)
        local n = laidOut(G, D().MIN_RADIUS)
        G.saveSnapshot()
        G.seconds(3)
        assert(laidOut(G, D().MIN_RADIUS) == n, "não voltou igual depois do save")
    end,

    -- review focus: save no meio do lote (fim da névoa tirando, ou enchendo): nada do mod
    overlays_save_mid_batch_clean = function()
        local G = setup({ density = 2 })
        NOM_FogState.set(true, 3, true)
        G.tick(O().UPDATE_TICKS * 3) -- enchendo
        assert(G.ours() > 0)
        assert(G.saveSnapshot().ours == 0, "save enchendo")
        G.seconds(4)
        NOM_FogState.set(false)
        G.tick(O().UPDATE_TICKS)
        assert(G.ours() > 0, "esvaziou de uma vez (teste não mede o lote)")
        assert(G.saveSnapshot().ours == 0, "save no meio do fim")
        G.seconds(3)
        assert(G.ours() == 0, "voltou depois da névoa")
    end,

    -- review final da 0034: o tick é por quadro, e a 15–30 FPS o carro anda 1 a 2 tiles por
    -- tick (~30 tiles/s). A margem do save não pode depender disso: depois de todo tick, nada
    -- do mod passa de MAX_RADIUS + SLACK + MOVE_TILES, e somado ao passo do tick seguinte
    -- fica abaixo dos 48 tiles do chunk que sai do mapa
    overlays_fast_car_low_fps_never_past_hard = function()
        for _, step in ipairs({ { 1, 0 }, { 2, 0 }, { 2, 1 } }) do
            local G = setup({ density = 2, zoom = 2.5 })
            NOM_FogState.set(true, 3, true)
            G.seconds(8)
            assert(farthest(G, G.p.x, G.p.y) > D().MAX_RADIUS - 2, "não encheu até o raio (teste não mede)")
            local len = math.sqrt(step[1] * step[1] + step[2] * step[2])
            local worst, cost = 0, 0
            for _ = 1, 90 do
                G.p.x, G.p.y = G.p.x + step[1], G.p.y + step[2]
                local j = G.java + G.sqCalls
                G.tick(1)
                cost = math.max(cost, G.java + G.sqCalls - j)
                local f = farthest(G, G.p.x, G.p.y)
                worst = math.max(worst, f)
                assert(f <= D().MAX_RADIUS + O().SLACK + O().MOVE_TILES + 1.5,
                    "carro a " .. len .. " tiles/tick: anexo a " .. f .. " tiles")
                assert(f + len < 48, "carro a " .. len .. " tiles/tick: o tick seguinte grava anexo a " .. (f + len))
            end
            assert(cost <= 2500, "carro a " .. len .. " tiles/tick: " .. cost .. " chamadas Java num tick")
            G.seconds(5)
            assert(laidOut(G, D().MIN_RADIUS) > 300, "parou e não encheu")
            print(string.format("[margem] carro a %.2f tiles/tick: anexo mais longe %.1f tiles, até %d chamadas Java por tick",
                len, worst, cost))
        end
    end,

    -- trava a margem do save (sprint 0035, Tarefa 5): o chunk que sai do mapa e é gravado está a
    -- ≥ 48 tiles (IsoChunkMap.chunkGridWidth 13 × 8, pz-api-notes §16.6). Entre cortes nada passa
    -- de MAX_RADIUS + SLACK + MOVE_TILES; no tick do corte o chunk pode sair antes do OnTick, com
    -- o passo do tick a mais (carro a 2 tiles por tick) e 1 do square inteiro. Raio, folga ou
    -- passo maiores que isso gravam anexo do mod no save
    overlays_save_margin_invariant = function()
        setup()
        local CHUNK_SAVE_TILES, CAR_STEP, SQUARE = 48, 2, 1
        local worst = D().MAX_RADIUS + O().SLACK + O().MOVE_TILES + CAR_STEP + SQUARE
        assert(worst < CHUNK_SAVE_TILES, string.format("MAX_RADIUS %d + SLACK %d + MOVE_TILES %d + %d = %d: o save grava a %d",
            D().MAX_RADIUS, O().SLACK, O().MOVE_TILES, CAR_STEP + SQUARE, worst, CHUNK_SAVE_TILES))
        assert(D().MIN_RADIUS <= D().MAX_RADIUS and #D().OFFSETS == D().WITHIN[D().MAX_RADIUS], "OFFSETS não vai até MAX_RADIUS")
    end,

    -- teleporte (debug, mapa): tudo sai no tick, pelo corte de MAX_RADIUS + SLACK
    overlays_teleport_strips_now = function()
        local G = setup({ density = 2 })
        NOM_FogState.set(true, 3, true)
        G.seconds(4)
        G.p.y = G.p.y - 200
        G.tick(1)
        assert(G.ours() == 0, "sobrou depois do teleporte: " .. G.ours())
        G.seconds(3)
        assert(laidOut(G, D().MIN_RADIUS) > 300, "não encheu no lugar novo")
    end,

    -- engasgo de FPS no carro (um tick com 10 tiles) não é teleporte: não tira tudo; só o que
    -- passou de MAX_RADIUS + SLACK sai na hora
    overlays_fps_hitch_not_jump = function()
        local G = setup({ density = 2, zoom = 2.5 })
        NOM_FogState.set(true, 3, true)
        G.seconds(8)
        local before = G.ours()
        G.p.x = G.p.x + 10
        G.tick(1)
        assert(G.ours() > before / 2, "o engasgo tirou tudo: " .. before .. " → " .. G.ours())
        local f = farthest(G, G.p.x, G.p.y)
        assert(f <= D().MAX_RADIUS + O().SLACK + 1.5, "anexo a " .. f .. " depois do engasgo")
    end,

    -- morte (no solo o jogo salva logo depois): tudo sai na hora
    overlays_death_strips_now = function()
        local G = setup({ density = 2 })
        NOM_FogState.set(true, 3, true)
        G.seconds(4)
        G.p.dead = true
        G.tick(1)
        assert(G.ours() == 0, "sobrou na morte: " .. G.ours())
        local fl, wl = O().count()
        assert(fl + wl == 0)
    end,

    -- crash depois de um hot save: o chunk volta do disco com anexos do mod. floors_burnt_01_*
    -- (ninguém no vanilla anexa) sai no LoadGridsquare, com e sem névoa; nome vanilla vazado fica
    -- (indistinguível do mapa: custo aceito na ADR-017), inclusive o sangue de chão de antes da
    -- sprint 0034; o vanilla do square fica
    overlays_load_scrub_removes_own_prefix = function()
        local G = setup({ density = 1 })
        for _, fog in ipairs({ false, true }) do
            NOM_FogState.set(fog, 3)
            local x = fog and 300 or 310
            G.loadSquare(x, 300, 0, { F = { "floors_burnt_01_14", "overlay_blood_floor_01_3" },
                vanillaF = { "blends_natural_01_1", "overlay_grime_floor_01_5" }, N = { "floors_burnt_01_2" },
                vanillaN = { "f_wallvines_1_3" } })
            local f, n = G.objs[x .. ",300,0F"], G.objs[x .. ",300,0N"]
            assert(mods(G, f) == "overlay_blood_floor_01_3", "piso: " .. mods(G, f))
            assert(mods(G, n) == "", "parede: " .. mods(G, n))
            assert(table.concat(G.attachedNames(f, "vanilla"), "|") == "blends_natural_01_1|overlay_grime_floor_01_5")
            assert(table.concat(G.attachedNames(n, "vanilla"), "|") == "f_wallvines_1_3")
        end
    end,

    -- a ação do jogador em curso (pá, marreta, pegar móvel: mexem nos anexos e, no MP, mandam a
    -- lista pro servidor): o square do alvo fica limpo enquanto ela é a atual e volta depois; o
    -- personagem da ação não conta
    overlays_timed_action_holds_square = function()
        local G = setup({ density = 2 })
        walls(G, 96, 96, 10)
        NOM_FogState.set(true, 3, true)
        G.seconds(4)
        local cases = {
            { field = "square", value = G.square(102, 101, 0), sq = "102,101,0" },
            { field = "object", value = G.objs["103,99,0N"], sq = "103,99,0" },
            { field = "thumpable", value = G.objs["98,103,0W"], sq = "98,103,0" },
        }
        for _, c in ipairs(cases) do
            local want = {}
            for _, kind in ipairs({ "F", "N", "W" }) do
                local o = G.objs[c.sq .. kind]
                if o then want[kind] = mods(G, o) end
            end
            assert(want.F ~= "" or want.N ~= "" or want.W ~= "", "o square do alvo estava vazio (teste não mede)")
            G.action(G.p, { character = G.p, [c.field] = c.value, maxTime = 100 })
            G.tick(O().UPDATE_TICKS)
            for kind in pairs(want) do assert(mods(G, G.objs[c.sq .. kind]) == "", c.field .. ": " .. kind .. " não limpou") end
            assert(mods(G, G.floorOf(100, 100, 0)) == expect(G, 100, 100, 0, "F"), "limpou o square do personagem")
            G.seconds(2)
            for kind in pairs(want) do assert(mods(G, G.objs[c.sq .. kind]) == "", c.field .. ": voltou com a ação em curso") end
            G.action(G.p, nil)
            G.seconds(3)
            for kind, v in pairs(want) do assert(mods(G, G.objs[c.sq .. kind]) == v, c.field .. ": " .. kind .. " não voltou") end
        end
    end,

    -- TRANSIÇÃO DESCASCANDO (sprint 0035) -----------------------------------------------------

    -- a névoa abre ao vivo: nenhum square é vestido antes do atraso dele (ruído × REVEAL_MS); no
    -- meio do caminho, parte vestida e parte esperando (a erosão se espalha em manchas)
    overlays_reveal_waits_for_the_noise = function()
        local G = setup({ density = 2 })
        walls(G, 96, 96, 8)
        floors(G, 80, 80, 120, 120)
        liveOpen()
        local t0 = G.now
        assert(O().revealStartedAt() == t0, "sem o sinal da revelação")
        assert(O().revealing(), "não está revelando")
        local list = wanted(G, D().MIN_RADIUS)
        assert(#list > 500, "pouco pra medir: " .. #list)
        local partial = false
        for _ = 1, 40 do
            G.tick(O().UPDATE_TICKS)
            local el = G.now - t0
            local dressed = 0
            for _, w in ipairs(list) do
                if mods(G, w.obj) ~= "" then
                    assert(delay(w.obj.x, w.obj.y) <= el, w.obj.kind .. " " .. w.obj.x .. "," .. w.obj.y .. " vestido a "
                        .. el .. " ms, atraso " .. delay(w.obj.x, w.obj.y))
                    dressed = dressed + 1
                end
            end
            if el > 1500 and el < 4500 and dressed > #list * 0.15 and dressed < #list * 0.85 then partial = true end
        end
        assert(partial, "não passou pela metade (tudo de uma vez ou nada)")
    end,

    -- depois de REVEAL_MS (mais o orçamento), tudo vestido como sem a transição, também no zoom
    -- mais longe (raio MAX, a volta maior); a janela fecha
    overlays_reveal_complete_after_reveal_ms = function()
        for _, zoom in ipairs({ 1, 2.5 }) do
            local G = setup({ density = 2, zoom = zoom })
            walls(G, 96, 96, 8)
            liveOpen()
            G.seconds(O().REVEAL_MS / 1000 + 2)
            local r = O().radius()
            assert(laidOut(G, r - 1) > 500, "zoom " .. zoom .. ": pouco vestido")
            G.seconds(O().REVEAL_TAIL_MS / 1000)
            assert(not O().revealing(), "a janela não fechou")
            assert(O().revealStartedAt(), "o sinal sumiu antes do fim da névoa")
        end
    end,

    -- squares esperando não travam a fila: a revelação olha cada square uma vez por volta (o que
    -- espera vai pro pendente), não o anel inteiro a cada atualização
    overlays_reveal_pending_is_cheap = function()
        local G = setup({ density = 2, zoom = 2.5 })
        local real, calls = D().reveal, 0
        D().reveal = function(...) calls = calls + 1; return real(...) end
        liveOpen()
        local worst, total = 0, 0
        for _ = 1, 50 do
            local c = calls
            G.tick(O().UPDATE_TICKS)
            worst = math.max(worst, calls - c)
            total = total + calls - c
        end
        assert(O().radius() == D().MAX_RADIUS)
        local ring = D().WITHIN[D().MAX_RADIUS]
        assert(worst <= O().SCAN_BUDGET * O().LOOK_MULT, "ruído por atualização: " .. worst)
        -- cada square: uma vez ao chegar, uma ao ser vestido (o rv do alvo); folga pros sem chunk
        assert(total <= 3 * ring, "o anel olhado de novo: " .. total .. " pra " .. ring .. " squares")
        D().reveal = real
        print(string.format("[budget] revelação (raio %d, %d squares): ruído até %d squares por atualização, %d em 50 atualizações",
            D().MAX_RADIUS, ring, worst, total))
    end,

    -- carregou o save com névoa ou entrou no MP no meio (a borda chega sem a fuga): sem atraso,
    -- sem o sinal
    overlays_mid_fog_entry_no_delay = function()
        local G = setup({ density = 2 })
        NOM_FogState.set(true, 3)
        G.tick(O().UPDATE_TICKS * 2)
        assert(O().revealStartedAt() == nil and not O().revealing(), "revelou pra quem entrou no meio")
        local late = 0
        for x = 98, 102 do
            for y = 98, 102 do
                local want = expect(G, x, y, 0, "F")
                assert(mods(G, G.floorOf(x, y, 0)) == want, x .. "," .. y .. " esperando")
                if want ~= "" and delay(x, y) > 2 * O().UPDATE_TICKS * 16 then late = late + 1 end
            end
        end
        assert(late > 0, "nenhum square de atraso longo perto (teste não mede)")
    end,

    -- o sinal sai uma vez, na borda ao vivo, com a hora (a tontura da Tarefa 3 liga nele)
    overlays_reveal_signal = function()
        local G = setup({ density = 1 })
        local got = {}
        O().onReveal(function(at) got[#got + 1] = at end)
        NOM_FogState.set(true, 3)
        NOM_FogState.set(false)
        G.seconds(6)
        assert(#got == 0, "sinal na entrada no meio")
        liveOpen()
        G.seconds(1)
        NOM_FogState.set(true, 3) -- sem borda
        assert(#got == 1 and got[1] == O().revealStartedAt(), "sinal: " .. #got)
        NOM_FogState.set(false)
        assert(O().revealStartedAt() == nil, "o sinal ficou depois do fim")
    end,

    -- review final da 0035: a hora da tontura é a da última borda ao vivo e não some no fim da
    -- névoa (a curva termina sozinha); a borda nova troca, carregar ou ir pro menu apaga.
    -- revealStartedAt continua sendo o desta névoa
    overlays_last_reveal_survives_fog_end = function()
        local G = setup({ density = 1 })
        assert(O().lastRevealAt() == nil)
        NOM_FogState.set(true, 3)
        assert(O().lastRevealAt() == nil, "borda pra quem entrou no meio")
        NOM_FogState.set(false)
        liveOpen()
        local t0 = G.now
        G.seconds(1)
        NOM_FogState.set(false)
        assert(O().lastRevealAt() == t0, "o fim da névoa apagou a hora da tontura")
        assert(O().revealStartedAt() == nil and not O().revealing(), "o sinal da revelação ficou depois do fim")
        NOM_FogState.set(true, 3)
        assert(O().lastRevealAt() == t0, "a entrada no meio mexeu na hora")
        NOM_FogState.set(false)
        G.seconds(1)
        liveOpen()
        assert(O().lastRevealAt() == G.now and G.now > t0, "a borda nova não trocou")
        G.fire("OnGameStart")
        assert(O().lastRevealAt() == nil, "carregar não apagou")
    end,

    -- teleporte no meio da revelação: o lugar novo sai sem atraso
    overlays_teleport_mid_reveal_no_delay = function()
        local G = setup({ density = 2 })
        liveOpen()
        G.seconds(0.5)
        G.p.y = G.p.y - 200
        G.tick(1)
        assert(not O().revealing(), "continuou revelando depois do teleporte")
        G.tick(O().UPDATE_TICKS * 2)
        local late = 0
        for x = 98, 102 do
            for y = -102, -98 do
                local want = expect(G, x, y, 0, "F")
                assert(mods(G, G.floorOf(x, y, 0)) == want, x .. "," .. y .. " esperando no lugar novo")
                if want ~= "" and delay(x, y) > 1500 then late = late + 1 end
            end
        end
        assert(late > 0, "nenhum square de atraso longo (teste não mede)")
        assert(O().revealStartedAt(), "o sinal sumiu (a tontura já começou)")
    end,

    -- andando na revelação: no fim, tudo vestido em volta do lugar novo, nada duplicado
    overlays_reveal_while_walking = function()
        local G = setup({ density = 2 })
        walls(G, 96, 96, 30)
        liveOpen()
        for _ = 1, 40 do G.p.x = G.p.x + 0.25; G.tick(O().UPDATE_TICKS / 2) end -- 10 tiles em 3,2 s
        G.seconds(O().REVEAL_MS / 1000)
        laidOut(G, D().MIN_RADIUS)
    end,

    -- fim da névoa: os squares saem pelo mesmo ruído, ao contrário (o que abriu por último sai
    -- primeiro), ao longo de UNREVEAL_MS; no meio, parte ainda lá
    overlays_fog_end_in_patches = function()
        local G = setup({ density = 2 })
        walls(G, 95, 95, 10)
        NOM_FogState.set(true, 3, true)
        G.seconds(4)
        local before = {}
        for _, o in pairs(G.objs) do
            if mods(G, o) ~= "" then before[#before + 1] = o end
        end
        assert(#before > 500)
        NOM_FogState.set(false)
        local t0, partial = G.now, false
        for _ = 1, 40 do
            G.tick(O().UPDATE_TICKS)
            local el, gone = G.now - t0, 0
            for _, o in ipairs(before) do
                if mods(G, o) == "" then
                    gone = gone + 1
                    local at = (1 - D().reveal(o.x, o.y, 0, 3)) * O().UNREVEAL_MS
                    assert(at <= el, o.kind .. " " .. o.x .. "," .. o.y .. " saiu a " .. el .. " ms, vez " .. at)
                end
            end
            if el > 1000 and el < 3000 and gone > #before * 0.15 and gone < #before * 0.85 then partial = true end
        end
        assert(partial, "não saiu em manchas")
        assert(G.ours() == 0, "sobrou: " .. G.ours())
    end,

    -- save no meio da retirada: tudo sai na hora e não volta (ADR-017)
    overlays_save_mid_unreveal_clean = function()
        local G = setup({ density = 2 })
        NOM_FogState.set(true, 3, true)
        G.seconds(4)
        NOM_FogState.set(false)
        G.seconds(1)
        assert(G.ours() > 100, "esvaziou cedo (teste não mede)")
        assert(G.saveSnapshot().ours == 0, "o save gravaria anexo da retirada")
        G.seconds(1)
        assert(G.ours() == 0, "voltou depois do save")
    end,

    -- a retirada não segura nada além do corte duro: de carro, nenhum tick passa de
    -- MAX_RADIUS + SLACK + MOVE_TILES
    overlays_unreveal_keeps_hard_cut = function()
        local G = setup({ density = 2, zoom = 2.5 })
        NOM_FogState.set(true, 3, true)
        G.seconds(8)
        NOM_FogState.set(false)
        local had = false
        for _ = 1, 160 do
            G.p.x = G.p.x + 0.5
            G.tick(1)
            if G.ours() > 0 then had = true end
            local f = farthest(G, G.p.x, G.p.y)
            assert(f <= D().MAX_RADIUS + O().SLACK + O().MOVE_TILES + 1.5, "anexo a " .. f .. " tiles na retirada")
        end
        assert(had)
    end,

    -- morte no meio da retirada: tudo na hora
    overlays_death_mid_unreveal = function()
        local G = setup({ density = 2 })
        NOM_FogState.set(true, 3, true)
        G.seconds(4)
        NOM_FogState.set(false)
        G.seconds(0.5)
        assert(G.ours() > 0)
        G.p.dead = true
        G.tick(1)
        assert(G.ours() == 0, "sobrou na morte: " .. G.ours())
    end,

    -- BORDA AO ANDAR (sprint 0035, Tarefa 5c) -------------------------------------------------

    -- "quero tela toda" (Johan): andando, a varredura chega no anel de fora do raio. No zoom
    -- mais longe (raio MAX), a 3 tiles/s, os pisos que a regra pede vestidos por faixa; a
    -- 6 tiles/s, a faixa de perto. O custo a pé fica no teto do enchimento
    overlays_walking_covers_screen_edge = function()
        for _, c in ipairs({ { speed = 3, min = { 0.95, 0.9, 0.8 } }, { speed = 6, min = { 0.9, 0.8, 0.6 } } }) do
            local G = setup({ density = 2, zoom = 2.5 })
            NOM_FogState.set(true, 3, true)
            G.seconds(8)
            assert(O().radius() == D().MAX_RADIUS)
            local cov, cost = walkCoverage(G, c.speed, 20, 10)
            print(string.format("[borda] andando a %d tiles/s: 15–20 %.0f%%, 20–25 %.0f%%, 25–30 %.0f%%; até %d chamadas por atualização",
                c.speed, cov[1] * 100, cov[2] * 100, cov[3] * 100, cost))
            for i, b in ipairs(BANDS) do
                assert(cov[i] >= c.min[i], string.format("a %d tiles/s, %d–%d tiles: %.0f%% vestido (pede %.0f%%)",
                    c.speed, b[1], b[2], cov[i] * 100, c.min[i] * 100))
            end
            assert(cost <= 2500, "a pé: " .. cost .. " chamadas por atualização")
        end
    end,

    -- o "já visto" não cresce com o caminho: depois de 500+ tiles em linha e em círculo, só o
    -- que está a até o corte (raio + SLACK, mais o que andou desde o último corte). Sem piso
    -- (nada a vestir), o lote não tira nada: só o corte esquece
    overlays_seen_memory_bounded = function()
        for _, c in ipairs({ { "linha" }, { "círculo" }, { "linha", true }, { "círculo", true } }) do
            local path, bare = c[1], c[2]
            local G = setup({ density = 2, zoom = 2.5 })
            G.noFloor = bare
            NOM_FogState.set(true, 3, true)
            G.seconds(8)
            local cap = disk(D().MAX_RADIUS + O().SLACK + O().MOVE_TILES + 1.5)
            local cx, cy, R, a = G.p.x, G.p.y + 50, 50, -math.pi / 2
            local worst, walked = 0, 0
            while walked < 520 do
                local step = 0.1 -- 6 tiles/s
                if path == "linha" then
                    G.p.x = G.p.x + step
                else
                    a = a + step / R
                    G.p.x, G.p.y = cx + R * math.cos(a), cy + R * math.sin(a)
                end
                walked = walked + step
                G.tick(1)
                worst = math.max(worst, O().seenSize())
            end
            print(string.format("[memória] %s%s, %d tiles a pé: \"já visto\" até %d squares (teto %d, a volta do raio %d)",
                path, bare and " sem piso" or "", walked, worst, cap, D().WITHIN[D().MAX_RADIUS]))
            assert(worst > D().WITHIN[D().MAX_RADIUS] / 2, path .. ": quase nada visto (teste não mede): " .. worst)
            assert(worst <= cap, path .. ": \"já visto\" com " .. worst .. " squares (teto " .. cap .. ")")
            G.seconds(10)
            laidOut(G, O().radius())
        end
    end,

    -- o square vestido que sai do raio e volta é vestido de novo: dentro da folga do corte (o
    -- lote tira) e além dela (o corte tira e o "já visto" esquece)
    overlays_leave_and_return_redressed = function()
        for _, away in ipairs({ 25, 60 }) do
            local G = setup({ density = 2, zoom = 1 })
            NOM_FogState.set(true, 3, true)
            G.seconds(5)
            local x, y, want = findFloor(G, function() return true end)
            local floor = G.floorOf(x, y, 0)
            assert(mods(G, floor) == want, "não vestiu (teste não mede)")
            assert(away > O().radius() + 2, "não sai do raio (teste não mede)")
            for _ = 1, away * 10 do G.p.x = G.p.x + 0.1; G.tick(1) end
            G.seconds(5)
            assert(mods(G, floor) == "", away .. " tiles: ficou vestido fora do raio")
            for _ = 1, away * 10 do G.p.x = G.p.x - 0.1; G.tick(1) end
            G.seconds(8)
            assert(mods(G, floor) == want, away .. " tiles: não voltou: " .. mods(G, floor))
            laidOut(G, O().radius())
        end
    end,

    -- custo andando com parede N e W em todo square do caminho (estresse): a pé, no teto do
    -- enchimento; de carro (2 tiles por tick), por tick, nada além do corte duro.
    -- Margem (review final da 0035): o pior "a pé" varia com a ordem do pairs no registro do
    -- próprio mod (que alvo entra primeiro no lote de retirada e na conferência). No luajit a
    -- ordem muda a cada processo (hash com semente); no jogo é a do KahluaTableImpl, outra
    -- ordem qualquer. Fixar a ordem no fake não tira a variação, e ordenar no mod custaria no
    -- jogo. Em 12 rodadas: 2341–2423 contra o teto de 2500 (folga de ~3%). Passou do teto: o
    -- custo subiu de verdade (orçamento, regra), não é azar da ordem.
    overlays_walking_cost_stress = function()
        local G = setup({ density = 2, zoom = 2.5 })
        for x = 60, 200 do
            for y = 60, 140 do
                G.obj(x, y, 0, "N")
                G.obj(x, y, 0, "W")
            end
        end
        NOM_FogState.set(true, 3, true)
        G.seconds(8)
        local _, foot = walkCoverage(G, 3, 10, 10)
        local car = 0
        for _ = 1, 25 do
            G.p.x = G.p.x + 2
            local j = G.java + G.sqCalls
            G.tick(1)
            car = math.max(car, G.java + G.sqCalls - j)
            assert(farthest(G, G.p.x, G.p.y) + 2 < 48, "o tick seguinte grava anexo")
        end
        print(string.format("[budget] estresse andando: a pé até %d chamadas por atualização, carro até %d por tick", foot, car))
        assert(foot <= 2500, "a pé: " .. foot)
    end,

    -- de carro na área densa (parede N e W em todo square), saindo do disco cheio: nenhum tick
    -- passa de 2500 chamadas Java (o corte duro de um anel cheio já custa ~1600; a atualização
    -- não cai em cima dele com o lote inteiro), e a margem do save vale em todo tick. A 0,5 tile
    -- por tick o corte roda a cada 4 ticks; a 1, a cada 2; a 2, em todo tick. Parado, enche
    overlays_car_cost_stress = function()
        for _, step in ipairs({ 0.5, 1, 2 }) do
            local ticks = 220
            local G = setup({ density = 2, zoom = 2.5 })
            for x = 55, 100 + math.ceil(step * ticks) + 45 do
                for y = 55, 145 do
                    G.obj(x, y, 0, "N")
                    G.obj(x, y, 0, "W")
                end
            end
            NOM_FogState.set(true, 3, true)
            G.seconds(8)
            assert(farthest(G, G.p.x, G.p.y) > D().MAX_RADIUS - 2, "não encheu até o raio (teste não mede)")
            local limit = D().MAX_RADIUS + O().SLACK + O().MOVE_TILES + 1.5
            local cost, worst = 0, 0
            local passes, visited, pass = 0, 0, 0
            for _ = 1, ticks do
                G.p.x = G.p.x + step
                local j, v = G.java + G.sqCalls, O().seenVisits()
                G.tick(1)
                cost = math.max(cost, G.java + G.sqCalls - j)
                v = O().seenVisits() - v
                if v > 0 then passes = passes + 1 end
                visited, pass = visited + v, math.max(pass, v)
                local f = farthest(G, G.p.x, G.p.y)
                worst = math.max(worst, f)
                assert(f <= limit, "carro a " .. step .. " tiles/tick: anexo a " .. f .. " tiles")
                assert(f + step < 48, "carro a " .. step .. " tiles/tick: o tick seguinte grava anexo a " .. (f + step))
            end
            print(string.format("[budget] estresse de carro a %.1f tiles/tick: até %d chamadas Java por tick, anexo mais longe %.1f tiles;"
                .. " \"já visto\" percorrido %d vezes em %d ticks (até %d chaves, média %.0f por tick)",
                step, cost, worst, passes, ticks, pass, visited / ticks))
            assert(cost <= 2500, "carro a " .. step .. " tiles/tick: " .. cost .. " chamadas Java num tick")
            -- review final da 0035: o esquecimento é só Lua e o teste de chamadas Java não o vê.
            -- No máximo uma volta no "já visto" por atualização, nunca por tick
            local most = math.ceil(ticks / O().UPDATE_TICKS) + 1
            assert(passes <= most, string.format("carro a %.1f tiles/tick: \"já visto\" percorrido %d vezes em %d ticks (teto %d)",
                step, passes, ticks, most))
            local cap = disk(D().MAX_RADIUS + O().SLACK + O().MOVE_TILES + 1.5)
            assert(pass <= cap, string.format("carro a %.1f tiles/tick: %d chaves numa volta (teto %d)", step, pass, cap))
            G.seconds(8)
            assert(laidOut(G, O().radius() - 1) > 1500, "carro a " .. step .. " tiles/tick: parou e não encheu")
        end
    end,

    -- revelação andando pra longe: o pendente que ficou pra trás (esquecido no corte) não duplica
    -- nem trava; no fim, o lugar novo vestido como pede a regra
    overlays_reveal_walking_far = function()
        local G = setup({ density = 2, zoom = 2.5 })
        liveOpen()
        for _ = 1, 400 do G.p.x = G.p.x + 0.1; G.tick(1) end -- 40 tiles em 6,4 s
        G.seconds((O().REVEAL_MS + O().REVEAL_TAIL_MS) / 1000 + 6)
        assert(not O().revealing())
        laidOut(G, O().radius())
    end,

    -- SILENT HILL (sprint 0035, Tarefa 4b) ----------------------------------------------------

    -- na branca o Outro Mundo ganha as texturas nossas (sprites de runtime registrados pelo
    -- NOM_OwnSprites antes do primeiro anexo): cada uma no objeto do lado dela, com a flag do
    -- lado (profundidade, spike §2) e com textura; o resto do desenho é o que a regra pede
    overlays_white_fog_own_sprites = function()
        local G = setup({ density = 1 })
        walls(G, 90, 90, 20)
        for x = 90, 99 do for y = 90, 109 do G.interior[x .. "," .. y .. ",0"] = { name = "casa" } end end
        NOM_FogState.set(true, 3)
        G.seconds(5)
        laidOut(G, D().MIN_RADIUS)
        local own = { F = 0, N = 0, W = 0 }
        for _, o in pairs(G.objs) do
            for _, n in ipairs(G.attachedNames(o, "mod")) do
                if n:sub(1, #NOM_OwnSpriteList.DIR) == NOM_OwnSpriteList.DIR then
                    own[o.kind] = own[o.kind] + 1
                    assert(n:find("_" .. o.kind .. "_%d+%.png$"), n .. " no objeto " .. o.kind)
                end
            end
        end
        -- hotfix do chão: metal só dentro (quebrado) e peça solta no asfalto; na grama, nada
        assert(own.F > 25 and own.N > 30 and own.W > 30, "pouco Silent Hill: " .. own.F .. "/" .. own.N .. "/" .. own.W)
        assert(#G.badFlags == 0, "sprite sem a flag do lado: " .. table.concat(G.badFlags, ", "))
        assert(#G.emptyAttached == 0, "sprite vazio anexado: " .. table.concat(G.emptyAttached, ", "))
    end,

    -- hotfix do chão (teste do Johan, 06/10): na grama (piso blends_natural_01_*), nada de metal,
    -- ferrugem nem tinta, nas duas cores; no asfalto, peça solta, sem outra ao lado. O nome do
    -- piso (getTextureName, uma ida ao Java) só é lido no square em que a regra pôs textura nossa
    overlays_natural_floor_no_metal = function()
        for _, red in ipairs({ false, true }) do
            local G = setup({ density = 2 })
            local DIR = NOM_OwnSpriteList.DIR
            NOM_FogState.set(true, 3, red)
            G.seconds(5)
            laidOut(G, D().MIN_RADIUS)
            local grass, own, asked, at = 0, 0, 0, {}
            for _, o in pairs(G.objs) do
                if o.kind == "F" then
                    local natural = D().natural(rawget(o, "sprite"))
                    local names = G.attachedNames(o, "mod")
                    if natural and #names > 0 then grass = grass + 1 end
                    for _, n in ipairs(names) do
                        if n:sub(1, #DIR) == DIR then
                            assert(not natural, "textura nossa na grama: " .. n .. " em " .. o.x .. "," .. o.y)
                            own = own + 1
                            at[o.x .. "," .. o.y] = true
                        end
                    end
                    if D().hasOwn(D().floor(o.x, o.y, 0, NOM_FogState.period, density(), true, red)) then
                        asked = asked + 1
                    end
                end
            end
            assert(grass > 100, "grama sem nada (teste não mede): " .. grass)
            assert(own > 5, "asfalto sem textura nossa (teste não mede): " .. own)
            if not red then
                for k in pairs(at) do
                    local x, y = k:match("^(-?%d+),(-?%d+)$")
                    x, y = tonumber(x), tonumber(y)
                    assert(not at[(x + 1) .. "," .. y] and not at[x .. "," .. (y + 1)], "metal vizinho no asfalto em " .. k)
                end
            end
            assert(G.textureNames > 0 and G.textureNames <= asked,
                "nome do piso lido " .. G.textureNames .. " vezes (a regra pôs textura nossa em " .. asked .. ")")
        end
    end,

    -- o sprite próprio sai antes do save como o vanilla do mod (o registro acha a instância pelo
    -- nome: depende do setName) e volta depois; no fim da névoa, tudo sai
    overlays_own_sprites_out_before_save = function()
        local G = setup({ density = 2 })
        walls(G, 96, 96, 8)
        NOM_FogState.set(true, 3)
        G.seconds(4)
        local function own()
            local n = 0
            for _, o in pairs(G.objs) do
                for _, name in ipairs(G.attachedNames(o, "mod")) do
                    if D().own(name) and not name:find("^floors_burnt") then n = n + 1 end
                end
            end
            return n
        end
        local before = own()
        assert(before > 50, "pouco sprite próprio: " .. before)
        assert(G.saveSnapshot().ours == 0, "o save gravaria anexo do mod")
        G.seconds(3)
        assert(own() == before, "não voltou igual: " .. own() .. " de " .. before)
        NOM_FogState.set(false)
        G.seconds(5)
        assert(G.ours() == 0, "sobrou: " .. G.ours())
    end,

    -- o mundo falso pega o setName esquecido (spike §7, risco alto): sem nome o
    -- getParentSprite():getName() é nil, o mod não acha o que pôs e o save grava. Com o
    -- NOM_OwnSprites certo, o teste de cima dá 0
    overlays_fake_catches_missing_set_name = function()
        local G = setup({ density = 2 })
        G.ignoreSetName = true
        NOM_FogState.set(true, 3)
        G.seconds(4)
        assert(G.saveSnapshot().ours > 0, "o fake não mede o setName esquecido")
    end,

    -- PNG que falta: o sprite não é criado (nada de sprite vazio no namedMap) e o nome não
    -- entra; o resto do Silent Hill sai normal e limpa igual
    overlays_own_missing_texture_skipped = function()
        local G = setup({ density = 2 })
        for _, s in ipairs(NOM_OwnSpriteList.SPRITES) do
            if s.kind == "Grade" then G.missingTex[s.name] = true end
        end
        -- hotfix do chão: a chapa, a ferrugem e a tinta em painel são de dentro de casa
        for x = 85, 114 do for y = 85, 114 do G.interior[x .. "," .. y .. ",0"] = { name = "casa" } end end
        NOM_FogState.set(true, 3)
        G.seconds(4)
        local other = 0
        for _, o in pairs(G.objs) do
            for _, n in ipairs(G.attachedNames(o, "mod")) do
                assert(not n:find("_Grade_"), "anexou sem textura: " .. n)
                if n:sub(1, #NOM_OwnSpriteList.DIR) == NOM_OwnSpriteList.DIR then other = other + 1 end
            end
        end
        assert(other > 50, "o resto não saiu: " .. other)
        assert(#G.emptyAttached == 0, "sprite vazio: " .. table.concat(G.emptyAttached, ", "))
        for name in pairs(G.sprites) do assert(not name:find("_Grade_"), "sprite vazio no namedMap: " .. name) end
        assert(G.saveSnapshot().ours == 0)
        NOM_FogState.set(false)
        G.seconds(5)
        assert(G.ours() == 0)
    end,

    -- vazou pro save (crash depois de hot save): o anexo próprio tem ID 20000000, fora do
    -- intMap, e o load o descarta (spike §5). Um anexo próprio que o registro não conhece sai no
    -- LoadGridsquare pelo prefixo (D.own), como o floors_burnt_01_*
    overlays_own_leak_gone_on_load = function()
        local G = setup({ density = 1 })
        NOM_FogState.set(true, 3)
        G.seconds(1)
        local name = NOM_OwnSpriteList.SPRITES[1].name
        G.loadSquare(300, 300, 0, { F = { name }, vanillaF = { "blends_natural_01_1" } })
        assert(G.discarded == 1, "o load não descartou o ID 20000000")
        assert(mods(G, G.objs["300,300,0F"]) == "")
        assert(table.concat(G.attachedNames(G.objs["300,300,0F"], "vanilla"), "|") == "blends_natural_01_1")
        local o = G.floorOf(301, 300, 0)
        o:addAttachedAnimSpriteByName(name)
        assert(mods(G, o) == name, "o fake não anexou (teste não mede)")
        G.fire("LoadGridsquare", G.square(301, 300, 0))
        assert(mods(G, o) == "", "o LoadGridsquare não limpou o prefixo próprio")
        assert(table.concat(G.attachedNames(o, "vanilla"), "|") ~= "", "tirou o vanilla")
    end,

    -- vermelha: sangue na parede, ferrugem na parede e no chão; sem a grade, a chapa e a tinta
    -- da branca e sem sangue no chão
    overlays_red_fog_blood_walls_and_rust = function()
        local G = setup({ density = 1 })
        walls(G, 90, 90, 20)
        NOM_FogState.set(true, 3, true)
        G.seconds(5)
        laidOut(G, D().MIN_RADIUS)
        local blood, rustWall, rustFloor = 0, 0, 0
        for _, o in pairs(G.objs) do
            for _, n in ipairs(G.attachedNames(o, "mod")) do
                if o.kind == "F" then
                    assert(not n:lower():find("blood"), "sangue no chão: " .. n)
                    assert(not n:find("_Grade_") and not n:find("_Chapa_") and not n:find("_Tinta_"), "metal da branca: " .. n)
                    if n:find("_Ferrugem_F_") then rustFloor = rustFloor + 1 end
                else
                    if n:find("blood") then blood = blood + 1 end
                    if n:find("_Ferrugem_") then rustWall = rustWall + 1 end
                end
            end
        end
        assert(blood > 30 and rustWall > 10 and rustFloor > 30, "sangue " .. blood .. ", ferrugem " .. rustWall .. "/" .. rustFloor)
        assert(#G.badFlags == 0, table.concat(G.badFlags, ", "))
    end,

    -- a cor muda no meio (debug setRedFog com a névoa aberta): outro desenho, mesmo com a mesma
    -- densidade; o velho sai, o novo é o que a regra pede pra vermelha
    overlays_color_change_redraws = function()
        local G = setup({ density = 1 })
        D().density = function() return 1 end
        NOM_FogState.set(true, 3)
        G.seconds(5)
        laidOut(G, D().MIN_RADIUS)
        NOM_FogState.set(true, 3, true)
        G.seconds(8)
        assert(laidOut(G, D().MIN_RADIUS) > 300, "não redesenhou na vermelha")
    end,

    -- o registro roda uma vez por sessão, antes do primeiro anexo; não por tick nem por névoa
    overlays_own_sprites_registered_once = function()
        local G = setup({ density = 1 })
        local calls, gs = 0, getSprite
        getSprite = function(n)
            calls = calls + 1
            return gs(n)
        end
        NOM_FogState.set(true, 3)
        G.seconds(6)
        NOM_FogState.set(false)
        G.seconds(5)
        NOM_FogState.set(true, 4)
        G.seconds(4)
        getSprite = gs
        assert(calls == #NOM_OwnSpriteList.SPRITES, "getSprite " .. calls .. " vezes")
    end,

    -- JANELA AO VIVO (review final da 0035) ----------------------------------------------------
    -- O que muda no meio da revelação ao vivo (atraso e rajada valendo) termina igual ao jogo
    -- sem a transição: 0 squares errados.

    -- a cor muda aos 2 s da janela (debug setRedFog): só o desenho vermelho fica
    overlays_live_color_change_mid_window = function()
        local G = setup({ density = 1 })
        D().density = function() return 1 end
        walls(G, 90, 90, 20)
        liveOpen(3, false)
        G.seconds(2)
        assert(O().revealing() and G.ours() > 0, "a janela não estava no meio (teste não mede)")
        NOM_FogState.set(true, 3, true)
        G.seconds((O().REVEAL_MS + O().REVEAL_TAIL_MS) / 1000 + 4)
        assert(not O().revealing(), "a janela não fechou")
        assert(exact(G) > 300, "não redesenhou na vermelha")
    end,

    -- a névoa acaba aos 2,5 s da janela: a janela fecha, o sinal sai, o que esperava não é
    -- vestido e tudo do mod sai
    overlays_live_fog_end_mid_window = function()
        local G = setup({ density = 2 })
        walls(G, 90, 90, 20)
        liveOpen()
        G.seconds(2.5)
        assert(O().revealing() and G.ours() > 0, "a janela não estava no meio (teste não mede)")
        NOM_FogState.set(false)
        assert(not O().revealing(), "a janela ficou aberta sem névoa")
        assert(O().revealStartedAt() == nil, "o sinal ficou depois do fim")
        G.seconds(O().UNREVEAL_MS / 1000 + 2)
        local fl, wl = O().count()
        assert(fl + wl == 0 and G.ours() == 0, "sobrou: " .. G.ours())
        G.seconds(O().REVEAL_MS / 1000)
        assert(G.ours() == 0, "o pendente foi vestido sem névoa: " .. G.ours())
    end,

    -- a névoa volta (ao vivo) no meio da retirada: o que ainda estava lá fica, o resto volta
    overlays_live_fog_back_mid_unreveal = function()
        local G = setup({ density = 2 })
        walls(G, 90, 90, 20)
        liveOpen()
        G.seconds((O().REVEAL_MS + O().REVEAL_TAIL_MS) / 1000 + 1)
        local before = G.ours()
        NOM_FogState.set(false)
        G.seconds(O().UNREVEAL_MS / 2000)
        assert(G.ours() > 0 and G.ours() < before, "não estava no meio da retirada (teste não mede)")
        liveOpen()
        assert(O().revealing(), "a volta não abriu a janela")
        G.seconds((O().REVEAL_MS + O().REVEAL_TAIL_MS) / 1000 + 4)
        assert(not O().revealing(), "a janela não fechou")
        assert(exact(G) > 500, "não voltou")
    end,

    -- a densidade vai a 0 no meio da janela e depois volta: tudo sai e volta como pede a regra
    overlays_live_density_zero_and_back = function()
        local G = setup({ density = 2 })
        walls(G, 90, 90, 20)
        liveOpen()
        G.seconds(2)
        assert(O().revealing() and G.ours() > 0, "a janela não estava no meio (teste não mede)")
        NOM_ScreenFxOptions.overlayDensity = function() return 0 end
        G.seconds(O().DENSITY_MS / 1000 + 3)
        assert(G.ours() == 0, "densidade 0 e sobrou: " .. G.ours())
        NOM_ScreenFxOptions.overlayDensity = function() return 2 end
        G.seconds((O().REVEAL_MS + O().REVEAL_TAIL_MS) / 1000 + 4)
        assert(not O().revealing(), "a janela não fechou")
        assert(exact(G) > 500, "não voltou")
    end,
}
