-- Outro Mundo sangrento (sprint 0015): na névoa, chão e paredes em volta do jogador
-- ganham sangue (poças, rastros) e a erosão no máximo (sujeira, rachadura, musgo,
-- trepadeira), só na tela de quem vê (solo e cliente de MP). O que vai em cada
-- square: shared/NOM_DressingRules.lua. ADR-015, pz-api-notes §16.
--
-- Nada vai pro mapa, pro save ou pra rede (bytecode B42.21):
-- * Chão: um IsoMarker por square com a tabela de texturas
--   (getIsoMarkers():addIsoMarker(nomes, sq, r, g, b, a), ISBaseIcon.lua:579). Lista
--   em memória do IsoMarkers, sem save/load nem pacote; o IngameState.exit faz reset().
--   Desenhado com profundidade e sem luz: a cor do marcador leva a luz do square.
-- * Parede: desenho imediato a cada quadro, no Events.RenderOpaqueObjectsInWorld
--   (FBORenderCell.renderOpaqueObjectsEvent, todo quadro; ISBuildingObject.lua:721-741),
--   com sprite:RenderGhostTileColor(x, y, z, r, g, b, a) (ISFarmingCursorMouse.lua:21):
--   o mesmo desenho do fantasma de construção, na posição de tile de verdade. Sem
--   profundidade e sem luz: só parede limpa (piso + parede, sem batente de porta ou
--   janela), de frente e à vista.
-- Proibidos (salvos ou sincronizados, §16.1): addBlood*, objetos de erosão,
-- setOverlaySprite, AttachedAnimSprite, objeto novo no square.
if isServer() then return end

require "NOM_Config"
require "NOM_FogState"
require "NOM_AtmosphereRules"
require "NOM_DressingRules"
require "NOM_ScreenFxOptions"

NOM_FogOverlays = {
    UPDATE_TICKS = 10,
    SCAN_BUDGET = 80,    -- squares olhados por atualização (a regra é o caro no Kahlua)
    LIGHT_BUDGET = 30,   -- marcadores com a luz relida por atualização
    WALL_BUDGET = 12,    -- paredes conferidas (ainda lá, limpas) e com a luz relida por atualização
    FADE_MS = 4000,      -- surgir e sumir
    RESEEN_TILES = 8,    -- andou isso desde a última varredura limpa: olha tudo de novo
    LIGHT_FLOOR = 0.5,   -- no escuro total (e sob a névoa vermelha) o sangue ainda se lê
    MIN_REACH = 5,       -- o teto nunca encolhe o raio efetivo abaixo disto
    DENSITY_MS = 1000,   -- densidade nova só vale parada esse tempo (o slider anda de 0,1 em 0,1)
    -- O marcador sai por cima do mundo (print 7: chão de dentro em cima do telhado). Um prédio
    -- de um andar cobre na tela os squares até 3 tiles atrás dele na diagonal (a altura de um
    -- andar, IsoUtils.YToScreen). Prédio mais alto cobre mais: o resto aparece (roteiro).
    SHADOW = 3,
}

local O = NOM_FogOverlays
local D = NOM_DressingRules

-- Batente de porta ou janela no lado da parede: o desenho taparia o buraco. As
-- propriedades do sprite somam nas do square (ISBuildIsoEntity.lua:195-198).
local FRAME_FLAGS = { N = { "DoorWallN", "WindowN", "doorN", "windowN" },
    W = { "DoorWallW", "WindowW", "doorW", "windowW" } }

local valid      -- [nome] = true, só os que o jogo acha (lazy: texturas carregam depois do Lua)
local frames     -- { N = { IsoFlagType... }, W = { ... } }, lazy como as texturas
local sprites = {} -- [nome] = IsoSprite
-- Duas reservas com teto, cada uma com o raio efetivo que o teto aguenta: o teto serve
-- quem está mais perto (cheio, o raio encolhe e o que fica fora cai na hora).
-- n = entradas que contam no teto: no chão, só as à vista (a que apaga ao sair da vista sai
-- em FADE_MS e não trava o chão que acabou de aparecer, ao entrar ou sair de um prédio).
local F = { list = {}, max = D.MAX_FLOOR, reach = D.RADIUS, n = 0 }
local W = { list = {}, max = D.MAX_WALL, reach = D.RADIUS }

local function used(pool)
    return pool.n or #pool.list
end
local taken = {}   -- [k] = entrada do chão, ou true na parede (k = square; na parede, + o lado)
local under       -- entrada do chão no tile do jogador: apagada (prints 9 e 10)
-- Decidido nesta varredura, por reserva: [x,y,z] no chão, [x,y,z .. "N"|"W"] na parede.
-- Fora do raio efetivo, recusado pelo teto, sem chunk ou parede de costas: não entra.
local seenF, seenW = {}, {}
local cursor, gen, anchorX, anchorY, lastMs = 1, nil, nil, nil, nil
local density, pendingD, pendingAt -- densidade em vigor e a que o jogador está mexendo
local lightAt, wallAt = 1, 1
-- Telhado por square ("x,y,z"): false = de fora, o prédio (objeto do jogo) ou true =
-- coberto sem cômodo. Lido uma vez por âncora; o prédio do jogador muda o que se vê.
local roofs = {}
local NONE = {}     -- contexto ainda não lido
local ctx = NONE    -- prédio do jogador (nil = fora)

local function loadSprites()
    valid = {}
    local found, total = 0, 0
    for _, set in pairs(D.SETS) do
        for _, i in ipairs(set.idx) do
            local name = set.prefix .. i
            total = total + 1
            -- IsoMarker.init e IsoSprite acham a textura pelo nome (Texture.trygetTexture);
            -- getTexture = Texture.getSharedTexture (LuaManager.GlobalObject)
            if getTexture(name) then
                valid[name] = true
                found = found + 1
            end
        end
    end
    frames = {}
    for side, list in pairs(FRAME_FLAGS) do
        frames[side] = {}
        for _, f in ipairs(list) do frames[side][#frames[side] + 1] = IsoFlagType[f] end
    end
    if getDebug() then print("[NOM] outro mundo: " .. found .. " de " .. total .. " sprites achados") end
end

local function name(layer)
    local n = D.SETS[layer[1]].prefix .. layer[2]
    if valid[n] then return n end
    return nil
end

local function lightOf(sq)
    local l = math.max(0, math.min(1, sq:getLightLevel(0) or 1))
    return O.LIGHT_FLOOR + (1 - O.LIGHT_FLOOR) * l
end

-- Parede do lado existe, sem batente, e o square só tem piso e parede(s): nada na
-- frente do desenho sem profundidade. getWall(Z): o objeto com cutN/cutW
-- (ISDestroyStuffAction.lua:141-142); o canto NW pode ser um objeto só pros dois lados.
local function cleanWall(sq, north)
    local w = sq:getWall(north)
    if not w then return false end
    local props = sq:getProperties()
    for _, f in ipairs(frames[north and "N" or "W"]) do
        if props:has(f) then return false end
    end
    local size = sq:getObjects():size()
    if size <= 2 then return true end
    if size > 3 then return false end
    local other = sq:getWall(not north)
    return other ~= nil and other ~= w
end

local function paint(e)
    local a = e == under and 0 or e.a
    if e.m then e.m:setColor(e.l, e.l, e.l, a) end
    if e.g then e.g:setColor(e.l, e.l, e.l, a * D.GRIME_ALPHA) end
end

local function drop(pool, i)
    local e = pool.list[i]
    if e == under then under = nil end
    if e.m then e.m:remove() end
    if e.g then e.g:remove() end
    if pool.n and e.want then pool.n = pool.n - 1 end
    taken[e.k] = nil
    -- voltando pra cá, entra de novo (mesmo desenho)
    if pool == F then seenF[e.k] = nil else seenW[e.k] = nil end
    table.remove(pool.list, i)
end

local function dropAll(pool)
    for i = #pool.list, 1, -1 do drop(pool, i) end
    pool.reach = D.RADIUS
end

function O.clear()
    dropAll(F)
    dropAll(W)
    taken, seenF, seenW, roofs, ctx, under = {}, {}, {}, {}, NONE, nil
    cursor, gen, anchorX, anchorY = 1, nil, nil, nil
    density, pendingD, pendingAt = nil, nil, nil
end

function O.count()
    return #F.list, #W.list
end

-- Raio efetivo do chão e das paredes (o que o teto aguenta em volta do jogador).
function O.reach()
    return F.reach, W.reach
end

local function roofOf(cell, x, y, z, sq)
    local k = x .. "," .. y .. "," .. z
    local v = roofs[k]
    if v == nil then
        sq = sq or cell:getGridSquare(x, y, z)
        -- isOutside: server/Farming/SFarmingSystem.lua:295; getBuilding: server/ClientCommands.lua:676
        if not sq or sq:isOutside() then v = false else v = sq:getBuilding() or true end
        roofs[k] = v
    end
    return v
end

-- O jogador vê o chão do square? Dentro de um prédio, o dele (o jogo corta paredes e
-- telhado dele, ISWorldObjectContextMenu.lua:1679 compara prédios assim); de fora, se
-- nenhum prédio (que não o dele) o cobre na tela.
local function visible(e, pb)
    if e.roof then return e.roof == pb end
    for _, b in ipairs(e.occ) do
        if b ~= pb then return false end
    end
    return true
end

local function lookAt(cell, x, y, z, sq)
    local roof, occ = roofOf(cell, x, y, z, sq), {}
    if not roof then
        for k = 1, O.SHADOW do
            local b = roofOf(cell, x + k, y + k, z)
            if b then occ[#occ + 1] = b end
        end
    end
    return { roof = roof, occ = occ }
end

-- Um square, até dois marcadores: rachadura + sangue num, a sujeira no outro (alfa ×
-- GRIME_ALPHA; o marcador tem uma cor só pra todas as texturas).
local function addFloor(sq, x, y, z, sk, layers, vis)
    local names = {}
    for _, l in ipairs(layers) do names[#names + 1] = name(l) end
    local grime = layers.grime and name(layers.grime)
    if (#names == 0 and not grime) or not sq:isFree(false) then return end -- isFree: ISWorldObjectContextMenu.lua:2199
    local l = lightOf(sq)
    local markers = getIsoMarkers()
    local m = #names > 0 and markers:addIsoMarker(names, sq, l, l, l, 0) or nil
    local g = grime and markers:addIsoMarker({ grime }, sq, l, l, l, 0) or nil
    if not m and not g then return end
    F.n = F.n + 1
    F.list[#F.list + 1] = { m = m, g = g, sq = sq, x = x, y = y, z = z, k = sk, sk = sk, a = 0, l = l,
        roof = vis.roof, occ = vis.occ, want = true }
    taken[sk] = F.list[#F.list]
end

local function addWall(sq, x, y, z, sk, layer, north)
    local n = name(layer)
    -- o teto vale por parede: um square pode trazer duas (N e W)
    if not n or #W.list >= W.max or not cleanWall(sq, north) then return end
    local k = sk .. (north and "N" or "W")
    sprites[n] = sprites[n] or getSprite(n)
    taken[k] = true
    W.list[#W.list + 1] = { sprite = sprites[n], sq = sq, x = x, y = y, z = z, k = k, sk = sk, a = 0,
        l = lightOf(sq), north = north }
end

-- Cheio: o raio efetivo encolhe pra antes deste anel; o que ficar fora cai na próxima.
-- No chão, o que aparece perto depois (entrou ou saiu de um prédio) e não cabe tira um
-- tile do raio por lote: o anel de fora sai e abre lugar, sem desabar até o recusado.
local function shrink(pool, o2)
    local r = math.floor(math.sqrt(o2)) - 1
    if pool == F then
        if pool.shrunk then return end
        pool.shrunk = true
        r = math.max(r, pool.reach - 1)
    end
    pool.reach = math.max(O.MIN_REACH, math.min(pool.reach, r))
end

-- Volta completa com folga: o raio efetivo cresce um tile se o anel novo cabe (a
-- conta pela área: n·(r+1)²/r²). Sem isso enche, encolhe e cresce sem parar, e cada
-- volta põe e tira o anel inteiro.
local function sweepDone()
    for _, pool in ipairs({ F, W }) do
        local r = pool.reach
        if r < D.RADIUS and used(pool) * (r + 1) * (r + 1) / (r * r) < pool.max * 0.95 then pool.reach = r + 1 end
    end
end

-- Um lote da varredura: mais perto primeiro (D.OFFSETS, até o maior raio efetivo), a
-- regra antes do Java, cada reserva decidida uma vez por square (e por lado).
local function scan(px, py, pz, per, d)
    local cell = getCell()
    F.shrunk = nil
    for _ = 1, O.SCAN_BUDGET do
        local limit = D.WITHIN[math.max(F.reach, W.reach)]
        if cursor > limit then
            cursor = 1
            sweepDone()
        end
        local o = D.OFFSETS[cursor]
        cursor = cursor + 1
        local o2 = o[1] * o[1] + o[2] * o[2]
        local x, y = px + o[1], py + o[2]
        local sk = x .. "," .. y .. "," .. pz
        local skN, skW = sk .. "N", sk .. "W"
        local sq -- lido no máximo uma vez
        local function square()
            if sq == nil then sq = cell:getGridSquare(x, y, pz) or false end
            return sq
        end
        if o2 <= F.reach * F.reach and not seenF[sk] and not taken[sk] then
            local layers = D.floor(x, y, pz, per, d)
            local vis = layers and square() and lookAt(cell, x, y, pz, sq) -- sem chunk: tenta na próxima volta
            if not layers or (vis and not visible(vis, ctx)) then
                seenF[sk] = true -- fora da vista não ocupa o teto; mudou o prédio, a varredura recomeça
            elseif vis and F.n >= F.max then
                shrink(F, o2) -- cheio: tenta de novo quando o raio voltar
            elseif vis then
                addFloor(sq, x, y, pz, sk, layers, vis)
                seenF[sk] = true
            end
        end
        if o2 <= W.reach * W.reach then
            -- de frente (N com o jogador ao sul, W com ele a leste: a outra face o jogo
            -- corta); a de costas fica pra quando ele andar pro outro lado
            for _, side in ipairs({ { skN, true, y <= py }, { skW, false, x <= px } }) do
                local k, north, front = side[1], side[2], side[3]
                if front and not seenW[k] and not taken[k] then
                    local layer = D.wall(x, y, pz, per, d, north)
                    if not layer then
                        seenW[k] = true
                    elseif #W.list >= W.max then
                        shrink(W, o2)
                    elseif square() then
                        addWall(sq, x, y, pz, sk, layer, north)
                        seenW[k] = true
                    end
                end
            end
        end
    end
end

-- Fade de uma reserva até want(e); apagada (alfa 0, sem querer voltar) e sem keep, sai.
local function fade(pool, dt, want, keep)
    for i = #pool.list, 1, -1 do
        local e = pool.list[i]
        local target = want(e) and 1 or 0
        local a = NOM_AtmosphereRules.approach(e.a, target, dt, O.FADE_MS)
        if a <= 0 and target == 0 and not keep then
            drop(pool, i)
        else
            if pool.n and e.want ~= (target == 1) then pool.n = pool.n + target * 2 - 1 end
            e.want = target == 1
            e.changed = e.changed or a ~= e.a
            e.a = a
        end
    end
end

-- Fora do raio efetivo ou de outro andar: sai na hora (abre lugar pro que está perto).
local function prune(pool, px, py, pz)
    local r2 = pool.reach * pool.reach
    for i = #pool.list, 1, -1 do
        local e = pool.list[i]
        local dx, dy = e.x - px, e.y - py
        if e.z ~= pz or dx * dx + dy * dy > r2 then drop(pool, i) end
    end
end

-- Luz relida em rodízio (lanterna, poste, amanhecer); parede que sumiu ou ganhou
-- móvel ou batente sai.
local function refresh()
    for _ = 1, math.min(O.LIGHT_BUDGET, #F.list) do
        if lightAt > #F.list then lightAt = 1 end
        local e = F.list[lightAt]
        lightAt = lightAt + 1
        local l = lightOf(e.sq)
        if l ~= e.l then e.l, e.changed = l, true end
    end
    for _ = 1, math.min(O.WALL_BUDGET, #W.list) do
        if wallAt > #W.list then wallAt = 1 end
        local e = W.list[wallAt]
        if cleanWall(e.sq, e.north) then
            e.l = lightOf(e.sq)
            wallAt = wallAt + 1
        else
            drop(W, wallAt)
        end
    end
end

local function update()
    local now = getTimestampMs()
    local dt = lastMs and now - lastMs or 0
    lastMs = now
    local p = getSpecificPlayer(0) -- getPlayer() é o jogador em foco na tela dividida
    if not p or p:isDead() then
        if #F.list + #W.list > 0 then O.clear() end
        return
    end
    -- densidade em vigor: a nova só depois de parada DENSITY_MS (a primeira, na hora)
    local raw = D.density(NOM_ScreenFxOptions.overlayDensity(), NOM_FogState.red)
    if raw ~= pendingD then pendingD, pendingAt = raw, now end
    if density == nil or (density ~= pendingD and now - pendingAt >= O.DENSITY_MS) then density = pendingD end
    local d = density
    local on = NOM_FogState.on and NOM_Config.get("FogOverlays") and d > 0
    local px, py, pz = math.floor(p:getX()), math.floor(p:getY()), math.floor(p:getZ())
    local per = NOM_FogState.period or 0
    if on then
        if not valid then loadSprites() end
        -- período ou densidade novos (opção, vermelha forçada): outro desenho
        local g = per .. ":" .. d
        if g ~= gen then
            dropAll(F)
            dropAll(W)
            gen, seenF, seenW, cursor = g, {}, {}, 1
        end
        if not anchorX or math.abs(px - anchorX) >= O.RESEEN_TILES or math.abs(py - anchorY) >= O.RESEEN_TILES then
            anchorX, anchorY, seenF, seenW, roofs, cursor = px, py, {}, {}, {}, 1 -- recomeça do mais perto
        end
        -- entrou ou saiu de prédio: o que se vê muda; o que estava na reserva só apaga (fade)
        local pb = p:getBuilding() -- ISWorldObjectContextMenu.lua:1679
        if pb ~= ctx then ctx, seenF, cursor = pb, {}, 1 end
        prune(F, px, py, pz)
        prune(W, px, py, pz)
    end
    -- chão que saiu da vista apaga e sai: o teto fica com o que se vê
    fade(F, dt, function(e) return on and visible(e, ctx) end, false)
    fade(W, dt, function(e)
        -- de frente (N com o jogador ao sul, W com ele a leste: a outra face o jogo corta) e à
        -- vista (linha de visão do jogo, LightingJNI, no cone). Fora da vista só apaga: fica.
        return on and (e.north and e.y <= py or not e.north and e.x <= px) and e.sq:isCouldSee(0)
    end, on)
    if on then refresh() end
    for _, e in ipairs(F.list) do
        if e.changed then paint(e) end
        e.changed = nil
    end
    if on then scan(px, py, pz, per, d) end
end

-- Quadro do mundo: só o jogador 0 (tela dividida: os outros não têm), só o andar dele.
-- O jogo só dispara o evento com o tile do mouse dentro do mundo (IsoWorld.isValidSquare
-- em FBORenderCell.renderOpaqueObjectsEvent): mouse fora do mapa, sem parede nesse quadro.
Events.RenderOpaqueObjectsInWorld.Add(function(pn, _, _, z)
    if pn ~= 0 or not D.WALLS or #W.list == 0 then return end
    local drawn = 0
    for _, w in ipairs(W.list) do
        if w.a > 0 and w.z == z then
            w.sprite:RenderGhostTileColor(w.x, w.y, w.z, w.l, w.l, w.l, w.a)
            drawn = drawn + 1
            if drawn >= D.MAX_WALL then return end
        end
    end
end)

Events.OnGameStart.Add(O.clear)
Events.OnMainMenuEnter.Add(O.clear)

-- Todo tick (o marcador sai depois do jogador e por cima dele, sem esperar a atualização):
-- o chão do tile dele apaga na hora; o que ele deixou volta ao alfa da entrada.
local function underfoot()
    if #F.list == 0 then return end
    local p = getSpecificPlayer(0)
    local e = p and taken[math.floor(p:getX()) .. "," .. math.floor(p:getY()) .. "," .. math.floor(p:getZ())]
    if e == true then e = nil end
    if e == under then return end
    local old = under
    under = e
    if old then paint(old) end
    if e then paint(e) end
end

local ticks = 0
Events.OnTick.Add(function()
    underfoot()
    ticks = ticks + 1
    if ticks < O.UPDATE_TICKS then return end
    ticks = 0
    update()
end)

return NOM_FogOverlays
