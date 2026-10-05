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
    return D().density(NOM_ScreenFxOptions.overlayDensity(), NOM_FogState.red)
end

-- o que a regra pede pro objeto (kind "F", "N", "W") do square, na ordem em que o mod anexa
local function expect(G, x, y, z, kind)
    local sq = G.square(x, y, z)
    local outside = sq:isOutside()
    local per, d = NOM_FogState.period or 0, density()
    local out = {}
    if kind == "F" then
        local f = D().floor(x, y, z, per, d, outside)
        for _, l in ipairs(f or {}) do out[#out + 1] = D().name(l) end
        if f and f.grime then out[#out + 1] = D().name(f.grime) end
    else
        local w = D().wall(x, y, z, per, d, kind == "N", outside)
        if w then out[1] = D().name(w) end
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

return {
    -- o piso e as paredes N/W ganham, anexados pelo nome, exatamente o que a regra pede (fora e
    -- dentro); o blend vanilla de cada piso fica
    overlays_attach_floor_and_walls = function()
        local G = setup({ density = 1 })
        walls(G, 96, 96, 8)
        for x = 102, 110 do for y = 102, 110 do G.interior[x .. "," .. y .. ",0"] = { name = "casa" } end end
        NOM_FogState.set(true, 3)
        G.seconds(5)
        local n = laidOut(G, D().RADIUS)
        assert(n > 400, "pouco anexado: " .. n)
        local wallsDressed = 0
        for _, o in pairs(G.objs) do
            if o.kind ~= "F" and mods(G, o) ~= "" then wallsDressed = wallsDressed + 1 end
        end
        assert(wallsDressed > 40, "paredes sem nada: " .. wallsDressed)
        local fl, wl = O().count()
        assert(fl > 300 and wl == wallsDressed, "count: " .. fl .. "/" .. wl)
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
        local x, y, want = findFloor(G, function(w) return w:find("overlay_blood_floor") ~= nil end)
        local name = want:match("(overlay_blood_floor_01_%d+)")
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
                if D().own(n) then
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

    -- o chunk que sai do mapa é gravado (ChunkSaveWorker) a ≥ 48 tiles: andando de carro (meio
    -- tile por tick), nada do mod passa de RADIUS + SLACK mais o que o carro anda numa
    -- atualização, em nenhum tick; parado, de RADIUS
    overlays_leaving_radius_strips = function()
        local G = setup({ density = 2 })
        NOM_FogState.set(true, 3, true)
        G.seconds(3)
        for _ = 1, 160 do
            G.p.x = G.p.x + 0.5
            G.p.y = G.p.y + 0.25
            G.tick(1)
            local f = farthest(G, G.p.x, G.p.y)
            assert(f <= D().RADIUS + O().SLACK + 0.6 * O().UPDATE_TICKS and f < 40, "anexo a " .. f .. " tiles andando")
        end
        G.seconds(3)
        assert(farthest(G, G.p.x, G.p.y) <= D().RADIUS + 1, "parado, longe demais: " .. farthest(G, G.p.x, G.p.y))
        assert(laidOut(G, D().RADIUS - 1) > 300, "o lugar novo não encheu")
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
        laidOut(G, D().RADIUS)
        NOM_FogState.set(true, 4)
        G.seconds(8)
        laidOut(G, D().RADIUS)
        NOM_ScreenFxOptions.overlayDensity = function() return 2 end
        G.seconds(8)
        laidOut(G, D().RADIUS)
        NOM_FogState.set(true, 4, true)
        G.seconds(8)
        assert(laidOut(G, D().RADIUS) > 500, "vermelha rala")
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
        laidOut(G, D().RADIUS)
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
        laidOut(G, D().RADIUS)
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
        for i = 0, 46 do G.unknown["overlay_blood_floor_01_" .. i] = true end
        NOM_FogState.set(true, 3, true)
        G.seconds(4)
        local any = 0
        for _, o in pairs(G.objs) do
            for _, n in ipairs(G.attachedNames(o, "mod")) do
                assert(not n:find("^overlay_blood_floor"), "anexou nome sem sprite")
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
        laidOut(G, D().RADIUS)
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
        assert(laidOut(G, D().RADIUS) > 300, "o andar de cima não encheu")
    end,

    -- custo por atualização (10 ticks): enchendo e parado
    overlays_budget = function()
        local G = setup({ density = 2 })
        walls(G, 90, 90, 20)
        NOM_FogState.set(true, 3, true)
        local maxFill, maxIdle, maxInv = 0, 0, 0
        for i = 1, 60 do
            local j, inv = G.java + G.sqCalls, G.invalidations
            G.tick(O().UPDATE_TICKS)
            local cost = G.java + G.sqCalls - j
            if i <= 10 then maxFill = math.max(maxFill, cost) elseif i > 40 then maxIdle = math.max(maxIdle, cost) end
            maxInv = math.max(maxInv, G.invalidations - inv)
        end
        assert(maxFill <= 2500, "enchendo: " .. maxFill .. " chamadas por atualização")
        assert(maxIdle <= 300, "parado: " .. maxIdle .. " chamadas por atualização")
        -- ≤ 80 squares por lote, até 3 alvos e 5 anexos no piso
        assert(maxInv <= O().SCAN_BUDGET * 7, "invalidações por lote: " .. maxInv)
        print(string.format("[budget] outro mundo: enchendo %d, parado %d chamadas, %d invalidações por atualização", maxFill, maxIdle, maxInv))
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
        local n = laidOut(G, D().RADIUS)
        G.saveSnapshot()
        G.seconds(3)
        assert(laidOut(G, D().RADIUS) == n, "não voltou igual depois do save")
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

    -- teleporte (debug, mapa): o chunk velho sai do mapa no mesmo tick; o mod tira tudo no tick
    overlays_jump_strips_now = function()
        local G = setup({ density = 2 })
        NOM_FogState.set(true, 3, true)
        G.seconds(4)
        G.p.x = G.p.x + 200
        G.tick(1)
        assert(G.ours() == 0, "sobrou depois do salto: " .. G.ours())
        G.seconds(3)
        assert(laidOut(G, D().RADIUS) > 300, "não encheu no lugar novo")
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
    -- (indistinguível do mapa: custo aceito na ADR-017); o vanilla do square fica
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
}
