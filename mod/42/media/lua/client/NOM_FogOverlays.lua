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
--   profundidade e sem luz: só parede limpa (piso + parede), de frente e à vista.
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
    LIGHT_BUDGET = 30,   -- entradas com a luz relida por atualização
    FADE_MS = 4000,      -- surgir e sumir
    RESEEN_TILES = 8,    -- andou isso desde a última varredura limpa: olha tudo de novo
    LIGHT_FLOOR = 0.5,   -- no escuro total (e sob a névoa vermelha) o sangue ainda se lê
}

local O = NOM_FogOverlays
local D = NOM_DressingRules

local valid      -- [nome] = true, só os que o jogo acha (lazy: texturas carregam depois do Lua)
local sprites = {} -- [nome] = IsoSprite
local floors, walls = {}, {} -- { m|sprite, sq, x, y, z, k, per, a, l }
local taken = {}   -- [k] = true (k com o período e o lado)
local seen = {}    -- [x,y,z] = true: já decidido nesta varredura
local cursor, period, density, anchorX, anchorY, lastMs = 1, nil, nil, nil, nil, nil
local lightAt = 1

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

function O.clear()
    for _, e in ipairs(floors) do e.m:remove() end
    floors, walls, taken, seen = {}, {}, {}, {}
    cursor, period, density, anchorX, anchorY = 1, nil, nil, nil, nil
end

function O.count()
    return #floors, #walls
end

local function addFloor(sq, x, y, z, per, layers)
    local names = {}
    for _, l in ipairs(layers) do names[#names + 1] = name(l) end
    if #names == 0 then return end
    local k = x .. "," .. y .. "," .. z .. ":" .. per
    if taken[k] or not sq:isFree(false) then return end -- isFree: ISWorldObjectContextMenu.lua:2199
    local l = lightOf(sq)
    local m = getIsoMarkers():addIsoMarker(names, sq, l, l, l, 0)
    if not m then return end
    taken[k] = true
    floors[#floors + 1] = { m = m, sq = sq, x = x, y = y, z = z, k = k, per = per, a = 0, l = l }
end

local function addWall(sq, x, y, z, per, layer, north)
    local n = layer and name(layer)
    if not n then return end
    local k = x .. "," .. y .. "," .. z .. ":" .. per .. (north and "N" or "W")
    if taken[k] then return end
    sprites[n] = sprites[n] or getSprite(n)
    taken[k] = true
    walls[#walls + 1] = { sprite = sprites[n], sq = sq, x = x, y = y, z = z, k = k, per = per, a = 0,
        l = lightOf(sq), north = north }
end

-- Um lote da varredura: mais perto primeiro (D.OFFSETS), a regra antes do Java.
local function scan(px, py, pz, per, d)
    local cell = getCell()
    local total = #D.OFFSETS
    for _ = 1, math.min(O.SCAN_BUDGET, total) do
        local o = D.OFFSETS[cursor]
        cursor = cursor % total + 1
        local x, y = px + o[1], py + o[2]
        local sk = x .. "," .. y .. "," .. pz
        if not seen[sk] then
            local floorFull, wallFull = #floors >= D.MAX_FLOOR, #walls >= D.MAX_WALL
            local layers = not floorFull and D.floor(x, y, pz, per, d) or nil
            -- de frente pro jogador: parede N com o jogador ao sul dela, W com ele a leste
            -- (a outra face o jogo corta quando o jogador chega perto)
            local wn = not wallFull and y <= py and D.wall(x, y, pz, per, d, true) or nil
            local ww = not wallFull and x <= px and D.wall(x, y, pz, per, d, false) or nil
            if layers or wn or ww then
                local sq = cell:getGridSquare(x, y, pz)
                if sq then -- sem chunk: tenta na próxima volta
                    if layers then addFloor(sq, x, y, pz, per, layers) end
                    if wn or ww then
                        -- getWall(Z): o objeto com cutN/cutW (ISDestroyStuffAction.lua:141-142);
                        -- canto NW pode ser um objeto só pros dois lados
                        local n, w = sq:getWall(true), sq:getWall(false)
                        local count = 1 + (n and 1 or 0) + ((w and w ~= n) and 1 or 0)
                        -- só piso e parede no square: nada na frente do desenho sem profundidade
                        if (n or w) and sq:getObjects():size() <= count then
                            if n then addWall(sq, x, y, pz, per, wn, true) end
                            if w then addWall(sq, x, y, pz, per, ww, false) end
                        end
                    end
                    if not floorFull and not wallFull then seen[sk] = true end
                end
            elseif not floorFull and not wallFull then
                seen[sk] = true
            end
        end
    end
end

-- Fade de uma lista; entra em 0 e alvo 0 sai. want(e) = alvo 1?
local function fade(list, dt, want, onRemove)
    for i = #list, 1, -1 do
        local e = list[i]
        local target = want(e) and 1 or 0
        local a = NOM_AtmosphereRules.approach(e.a, target, dt, O.FADE_MS)
        if a <= 0 and target == 0 then
            onRemove(e)
            taken[e.k] = nil
            table.remove(list, i)
        else
            e.changed = e.changed or a ~= e.a
            e.a = a
        end
    end
end

local function update()
    local now = getTimestampMs()
    local dt = lastMs and now - lastMs or 0
    lastMs = now
    local p = getSpecificPlayer(0) -- getPlayer() é o jogador em foco na tela dividida
    if not p or p:isDead() then
        if #floors + #walls > 0 then O.clear() end
        return
    end
    local d = D.density(NOM_ScreenFxOptions.overlayDensity(), NOM_FogState.red)
    local on = NOM_FogState.on and NOM_Config.get("FogOverlays") and d > 0
    local px, py, pz = math.floor(p:getX()), math.floor(p:getY()), math.floor(p:getZ())
    local per = NOM_FogState.period or 0
    if per ~= period or d ~= density then -- desenho novo: o velho sai com fade
        period, density, seen, cursor = per, d, {}, 1
    end
    if not anchorX or math.abs(px - anchorX) >= O.RESEEN_TILES or math.abs(py - anchorY) >= O.RESEEN_TILES then
        anchorX, anchorY, seen, cursor = px, py, {}, 1
    end
    local r2 = (D.RADIUS + 1) * (D.RADIUS + 1)
    local function near(e)
        local dx, dy = e.x - px, e.y - py
        return on and e.per == per and e.z == pz and dx * dx + dy * dy <= r2
    end
    fade(floors, dt, near, function(e) e.m:remove() end)
    fade(walls, dt, function(e)
        -- à vista: a linha de visão do jogo (LightingJNI), no cone
        return near(e) and e.sq:isCouldSee(0) and (e.north and e.y <= py or not e.north and e.x <= px)
    end, function() end)
    -- luz relida em rodízio (lanterna, poste, amanhecer)
    local n = #floors + #walls
    for _ = 1, math.min(O.LIGHT_BUDGET, n) do
        if lightAt > n then lightAt = 1 end
        local e = lightAt <= #floors and floors[lightAt] or walls[lightAt - #floors]
        lightAt = lightAt + 1
        local l = lightOf(e.sq)
        if l ~= e.l then e.l, e.changed = l, true end
    end
    for _, e in ipairs(floors) do
        if e.changed then e.m:setColor(e.l, e.l, e.l, e.a) end
        e.changed = nil
    end
    if on then
        if not valid then loadSprites() end
        scan(px, py, pz, per, d)
    end
end

-- Quadro do mundo: só o jogador 0 (tela dividida: os outros não têm), só o andar dele.
Events.RenderOpaqueObjectsInWorld.Add(function(pn, _, _, z)
    if pn ~= 0 or #walls == 0 then return end
    local drawn = 0
    for _, w in ipairs(walls) do
        if w.a > 0 and w.z == z then
            w.sprite:RenderGhostTileColor(w.x, w.y, w.z, w.l, w.l, w.l, w.a)
            drawn = drawn + 1
            if drawn >= D.MAX_WALL then return end
        end
    end
end)

Events.OnGameStart.Add(O.clear)
Events.OnMainMenuEnter.Add(O.clear)

local ticks = 0
Events.OnTick.Add(function()
    ticks = ticks + 1
    if ticks < O.UPDATE_TICKS then return end
    ticks = 0
    update()
end)

return NOM_FogOverlays
