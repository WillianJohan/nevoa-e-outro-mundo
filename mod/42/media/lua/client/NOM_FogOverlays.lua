-- Outro Mundo sangrento (sprint 0015; anexado ao piso e à parede desde a 0023): na névoa, o
-- chão em volta do jogador ganha sujeira, rachadura, chão queimado (dentro), mato e folha (fora;
-- sangue no chão saiu na sprint 0034), e as paredes, sangue, sujeira, rachadura, trepadeira e
-- pichação (as de dentro empilhadas, sprint 0034), só na tela de quem vê (solo e cliente de MP).
-- O que vai em cada square:
-- shared/NOM_DressingRules.lua. ADR-017, pz-api-notes §16.6.
--
-- Como (bytecode B42.21): obj:addAttachedAnimSpriteByName(nome) no piso (sq:getFloor()) e na
-- parede (sq:getWall(north)), o caminho da erosão vanilla (WallVines.update →
-- ErosionObjOverlay.setOverlay). O jogo desenha o anexo no FBO do chunk junto com o objeto
-- (renderOneChunk, antes do renderPlayers): embaixo dos personagens, com a luz, o recorte de
-- parede e o prédio apagado do jogo.
--
-- O anexo vai pro save com o objeto (IsoObject.save grava a lista inteira). Por isso:
-- * O mod guarda cada instância que pôs (registro por alvo) e tira só essas: de trás pra
--   frente, mesma instância E mesmo nome, RemoveAttachedAnim(i). Nunca RemoveAttachedAnims()
--   (apaga blend e decalque do mapa) nem AttachExistingAnim (mexe no IsoSprite compartilhado).
-- * OnSave (GameWindow.save, antes do IsoCell.save gravar os chunks): tudo sai; volta na
--   atualização seguinte. Morte: tudo sai na hora.
-- * O chunk que sai do mapa e é gravado está a ≥ 48 tiles. O raio segue a tela (sprint 0034):
--   os 4 cantos da tela do jogador 0 (getPlayerScreenWidth/Height, ISSleepingUI.lua:16-17; pixel
--   × getCore():getZoom(0), ISMenuContextWorld.lua:77) no chão do andar dele (IsoUtils.XToIso/
--   YToIso, server/ISCoordConversion.lua:19-24), + 2, entre 15 e 30 (NOM_DressingRules.radius).
--   Além de 30 + SLACK (8) = 38 sai na hora, qualquer zoom, no tick em que o jogador passa de
--   MOVE_TILES (2) desde o último corte: entre cortes nada passa de 38 + 2, e no tick do corte o
--   chunk pode sair antes dele, com o passo do tick a mais. Com 2 tiles por tick (carro a
--   ~30 tiles/s com 15 FPS): 38 + 2 + 2 + 1 (square inteiro) = 43 < 48. Aguenta até ~6 tiles
--   num tick; acima disso, só o teleporte, que já tinha esse risco.
-- * LoadGridsquare: floors_burnt_01_* anexado (ninguém no vanilla anexa) que não é nosso é
--   vazado de uma sessão que caiu depois de um hot save: sai. Nome vanilla vazado fica (ADR-017).
-- * A ação do jogador em curso segura o square do alvo limpo (pá, marreta, móvel).
-- * Nada pela rede: nenhum transmit*. No cliente de MP o chunk nem é gravado
--   (IsoChunk.Save sai com GameClient.client).
if isServer() then return end

require "NOM_Config"
require "NOM_FogState"
require "NOM_DressingRules"
require "NOM_ScreenFxOptions"

NOM_FogOverlays = {
    UPDATE_TICKS = 10,
    SCAN_BUDGET = 80,    -- squares olhados por atualização (cada anexo invalida o nível do chunk)
    STRIP_BUDGET = 80,   -- alvos tirados por atualização (saiu do raio, fim da névoa, desenho novo)
    -- Além de MAX_RADIUS + SLACK sai na hora, sem lote (de carro o anel que sai passa do lote):
    -- o chunk gravado ao sair do mapa está a ≥ 48 tiles. Não depende do zoom: chegar o zoom
    -- perto tira o anel de fora em lote. O corte roda no tick em que o jogador passa de
    -- MOVE_TILES desde o último corte, não a cada atualização: o tick é por quadro, e a margem
    -- não pode depender do FPS (conta na pz-api-notes §16.6).
    SLACK = 8,
    MOVE_TILES = 2,
    VERIFY_BUDGET = 20,  -- alvos conferidos por atualização (a lista mexida por baixo: põe de novo)
    RESEEN_TILES = 8,    -- andou isso desde a última âncora: olha tudo de novo, do mais perto
    DENSITY_MS = 1000,   -- densidade nova só vale parada esse tempo (o slider anda de 0,1 em 0,1)
}

local O = NOM_FogOverlays
local D = NOM_DressingRules

-- Batente de porta ou janela no lado da parede: o anexo cairia no batente. As propriedades do
-- sprite somam nas do square (ISBuildIsoEntity.lua:195-198).
local FRAME_FLAGS = { N = { "DoorWallN", "WindowN", "doorN", "windowN" },
    W = { "DoorWallW", "WindowW", "doorW", "windowW" } }
local SIDES = { { "N", true }, { "W", false } }

-- reg[k] (k = "x,y,z" .. "F"|"N"|"W") = { obj, sq, sk, kind, x, y, z, gen, list = { {inst, name} } }
local reg, nFloor, nWall
local seen       -- [sk] = true: square decidido desde a âncora (sem chunk: tenta de novo)
local held       -- [sk] = true: square do alvo da ação em curso (fica limpo)
local cursor, gen, anchorX, anchorY, cutX, cutY
local density, pendingD, pendingAt
local verifyKeys, verifyAt
local radius

local function forget()
    reg, nFloor, nWall = {}, 0, 0
    seen, held = {}, {}
    cursor, gen, anchorX, anchorY, cutX, cutY = 1, nil, nil, nil, nil, nil
    density, pendingD, pendingAt = nil, nil, nil
    verifyKeys, verifyAt = {}, 1
    radius = D.MIN_RADIUS
end
forget()

function O.count()
    return nFloor, nWall -- alvos com anexo do mod: pisos e paredes
end

function O.radius()
    return radius
end

-- Os alvos vestidos agora ({ x, y, z, kind = "F"|"N"|"W" }, só leitura): as fontes das lascas
-- (client/NOM_Flakes.lua, sprint 0035). Só Lua.
function O.targets()
    local out = {}
    for _, e in pairs(reg) do out[#out + 1] = e end
    return out
end

local CORNERS = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }

-- Raio da tela do jogador 0: os cantos em pixel × zoom (a câmera do jogo trabalha no tamanho
-- do FBO, MultiTextureFBO2.getWidth = tela × zoom) levados ao chão do andar dele.
local function screenRadius(p, px, py)
    local w, h = getPlayerScreenWidth(0), getPlayerScreenHeight(0)
    local zoom, z = getCore():getZoom(0), p:getZ()
    local corners = {}
    for i, c in ipairs(CORNERS) do
        local sx, sy = c[1] * w * zoom, c[2] * h * zoom
        corners[i] = { IsoUtils.XToIso(0, sx, sy, z), IsoUtils.YToIso(0, sx, sy, z) }
    end
    return D.radius(px, py, corners)
end

local function count(e, n)
    if e.kind == "F" then nFloor = nFloor + n else nWall = nWall + n end
end

-- Posição na lista do objeto da instância r (a mesma instância e o mesmo nome: a instância
-- volta pro pool quando sai, e o vanilla pode recebê-la de novo com outro nome), ou nil.
local function find(list, r)
    for i = list:size() - 1, 0, -1 do
        local inst = list:get(i)
        if inst == r.inst and inst:getParentSprite():getName() == r.name then return i end
    end
    return nil
end

-- Tira do objeto só o que o mod pôs (de trás pra frente: os índices de trás andam).
local function detach(e)
    local list = e.obj:getAttachedAnimSprite()
    if not list then return end
    for j = #e.list, 1, -1 do
        local i = find(list, e.list[j])
        if i then e.obj:RemoveAttachedAnim(i) end
    end
end

local function strip(e)
    detach(e)
    reg[e.k] = nil
    count(e, -1)
    seen[e.sk] = nil -- de volta à varredura (mesmo desenho, se ainda vale)
end

-- Alvos do registro que pedem saída (tirados depois da volta: o KahluaTableImpl é um Map do
-- Java percorrido por iterador; nada de apagar chave no meio do pairs).
local function stripWhere(want)
    local out = {}
    for _, e in pairs(reg) do
        if want(e) then out[#out + 1] = e end
    end
    for _, e in ipairs(out) do strip(e) end
end

function O.stripAll()
    stripWhere(function() return true end)
    seen, cursor = {}, 1
end

function O.clear()
    O.stripAll()
    forget()
end

-- Anexa os nomes e guarda as instâncias que entraram (nome sem sprite não entra: o jogo não
-- cria nada, IsoSprite.getSprite volta nil). grime: o nome que vai mais leve.
local function attach(obj, names, grime, rec)
    local list = obj:getAttachedAnimSprite() -- a ArrayList viva do objeto (nil até o 1º anexo)
    local size = list and list:size() or 0
    for _, name in ipairs(names) do
        obj:addAttachedAnimSpriteByName(name)
        list = list or obj:getAttachedAnimSprite()
        local now = list and list:size() or 0
        if now > size then
            size = now
            local inst = list:get(now - 1)
            if name == grime then
                inst:SetAlpha(D.GRIME_ALPHA)
                inst:SetTargetAlpha(D.GRIME_ALPHA)
            end
            rec[#rec + 1] = { inst = inst, name = name }
        end
    end
end

-- Alvo que o mod pode vestir: piso ou parede do mapa, não construção do jogador, porta ou janela.
local function plain(obj)
    return obj ~= nil and not instanceof(obj, "IsoThumpable") and not instanceof(obj, "IsoDoor")
        and not instanceof(obj, "IsoWindow")
end

local function add(k, sq, sk, kind, obj, x, y, z, names, grime)
    local e = { k = k, obj = obj, sq = sq, sk = sk, kind = kind, x = x, y = y, z = z, gen = gen, names = names,
        grime = grime, list = {} }
    attach(obj, names, grime, e.list)
    if #e.list == 0 then return end
    reg[k] = e
    count(e, 1)
end

local function frame(props, side)
    for _, f in ipairs(FRAME_FLAGS[side]) do
        if props:has(IsoFlagType[f]) then return true end
    end
    return false
end

-- Um square: piso e paredes N/W, a regra antes do Java.
local function dress(cell, x, y, z, sk, per, d)
    local sq = cell:getGridSquare(x, y, z)
    if not sq then return false end -- sem chunk: tenta na próxima volta
    local outside = sq:isOutside()
    local props
    if not reg[sk .. "F"] then
        local f = D.floor(x, y, z, per, d, outside)
        if f then
            props = sq:getProperties()
            local obj = not props:has(IsoFlagType.water) and sq:getFloor() or nil
            if plain(obj) then
                local names = {}
                for _, l in ipairs(f) do names[#names + 1] = D.name(l) end
                local grime = f.grime and D.name(f.grime)
                if grime then names[#names + 1] = grime end
                add(sk .. "F", sq, sk, "F", obj, x, y, z, names, grime)
            end
        end
    end
    for _, s in ipairs(SIDES) do
        local side, north = s[1], s[2]
        if not reg[sk .. side] then
            local w = D.wall(x, y, z, per, d, north, outside)
            if w then
                local obj = sq:getWall(north)
                props = props or (obj and sq:getProperties())
                if plain(obj) and not frame(props, side) then
                    local names = {}
                    for _, l in ipairs(w) do names[#names + 1] = D.name(l) end
                    add(sk .. side, sq, sk, side, obj, x, y, z, names, nil)
                end
            end
        end
    end
    return true
end

-- Um lote da varredura: mais perto primeiro (D.OFFSETS), em volta contínua até o raio (o anel
-- novo de quem anda, o square que perdeu o anexo); o square já decidido custa só a chave.
local function scan(px, py, pz, per, d)
    local cell = getCell()
    local n = D.WITHIN[radius]
    for _ = 1, O.SCAN_BUDGET do
        if cursor > n then cursor = 1 end
        local o = D.OFFSETS[cursor]
        cursor = cursor + 1
        local x, y = px + o[1], py + o[2]
        local sk = x .. "," .. y .. "," .. pz
        if not seen[sk] and not held[sk] and dress(cell, x, y, pz, sk, per, d) then seen[sk] = true end
    end
end

local function hardR2()
    return (D.MAX_RADIUS + O.SLACK) * (D.MAX_RADIUS + O.SLACK)
end

-- Além de MAX_RADIUS + SLACK, na hora, sem lote. Só Lua até achar o que sai.
local function cut(px, py)
    local hard = hardR2()
    stripWhere(function(e)
        local dx, dy = e.x - px, e.y - py
        return dx * dx + dy * dy > hard
    end)
end

-- Fora do raio, de outro andar, de outro desenho ou sem névoa: sai, em lote; além de
-- MAX_RADIUS + SLACK, na hora.
local function prune(on, px, py, pz)
    local hard = hardR2()
    local r2, n = radius * radius, 0
    stripWhere(function(e)
        local dx, dy = e.x - px, e.y - py
        local d2 = dx * dx + dy * dy
        if d2 > hard or (n < O.STRIP_BUDGET and (not on or e.gen ~= gen or e.z ~= pz or d2 > r2)) then
            n = n + 1
            return true
        end
        return false
    end)
end

-- Em rodízio: o objeto ainda é o piso/parede do square e as instâncias do mod ainda estão lá?
-- Objeto trocado (MP: pacote do servidor): esquece o velho (fora do mundo) e veste o novo. Lista
-- mexida (pá, erosão, servidor): põe de novo só o que falta.
local function verify()
    for _ = 1, O.VERIFY_BUDGET do
        if verifyAt > #verifyKeys then
            -- volta nova: as chaves de agora (a lista não cresce com o que entra e sai)
            verifyKeys, verifyAt = {}, 1
            for k in pairs(reg) do verifyKeys[#verifyKeys + 1] = k end
            if #verifyKeys == 0 then return end
        end
        local k = verifyKeys[verifyAt]
        verifyAt = verifyAt + 1
        local e = reg[k]
        if e then
            local cur
            if e.kind == "F" then cur = e.sq:getFloor() else cur = e.sq:getWall(e.kind == "N") end
            if cur ~= e.obj then
                reg[k] = nil
                count(e, -1)
                seen[e.sk] = nil
            else
                local list = e.obj:getAttachedAnimSprite()
                local missing, keep = {}, {}
                for _, r in ipairs(e.list) do
                    if list and find(list, r) then keep[#keep + 1] = r else missing[#missing + 1] = r.name end
                end
                if #missing > 0 then
                    e.list = keep
                    attach(e.obj, missing, e.grime, e.list)
                end
            end
        end
    end
end

-- O square do alvo da ação atual do jogador (ISTimedActionQueue.queues[p].queue[1]): campos
-- que são square ou objeto do mapa (square, object, item, thumpable...); o personagem não conta.
local function actionSquares(p)
    local out = {}
    local q = ISTimedActionQueue and ISTimedActionQueue.queues and ISTimedActionQueue.queues[p]
    local act = q and q.queue and q.queue[1]
    if type(act) ~= "table" then return out end
    for _, v in pairs(act) do
        if v ~= p and type(v) ~= "number" and type(v) ~= "string" and type(v) ~= "boolean" and type(v) ~= "function" then
            local sq
            if instanceof(v, "IsoGridSquare") then
                sq = v
            elseif instanceof(v, "IsoObject") and not instanceof(v, "IsoMovingObject") then
                sq = v:getSquare()
            end
            if sq then out[sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ()] = true end
        end
    end
    return out
end

local function hold(p)
    local now = actionSquares(p)
    for sk in pairs(now) do
        if not held[sk] then
            for _, kind in ipairs({ "F", "N", "W" }) do
                local e = reg[sk .. kind]
                if e then strip(e) end
            end
        end
    end
    for sk in pairs(held) do
        if not now[sk] then
            seen[sk] = nil -- acabou a ação: volta
            cursor = 1
        end
    end
    held = now
end

local function update()
    local p = getSpecificPlayer(0) -- getPlayer() é o jogador em foco na tela dividida
    if not p or p:isDead() then
        if nFloor + nWall > 0 then O.stripAll() end
        return
    end
    local now = getTimestampMs()
    -- densidade em vigor: a nova só depois de parada DENSITY_MS (a primeira, na hora)
    local raw = D.density(NOM_ScreenFxOptions.overlayDensity(), NOM_FogState.red)
    if raw ~= pendingD then pendingD, pendingAt = raw, now end
    if density == nil or (density ~= pendingD and now - pendingAt >= O.DENSITY_MS) then density = pendingD end
    local d = density
    local on = NOM_FogState.on and NOM_Config.get("FogOverlays") and d > 0
    local px, py, pz = math.floor(p:getX()), math.floor(p:getY()), math.floor(p:getZ())
    local per = NOM_FogState.period or 0
    if on then
        radius = screenRadius(p, px, py)
        local g = per .. ":" .. d
        if g ~= gen then gen, seen, cursor = g, {}, 1 end -- outro desenho: o velho sai no prune
        if not anchorX or math.abs(px - anchorX) >= O.RESEEN_TILES or math.abs(py - anchorY) >= O.RESEEN_TILES then
            anchorX, anchorY, seen, cursor = px, py, {}, 1 -- recomeça do mais perto
        end
        hold(p)
    end
    prune(on, px, py, pz)
    if not on then return end
    verify()
    scan(px, py, pz, per, d)
end

-- Todo tick: a morte (no solo o jogo salva logo depois) tira tudo na hora; andou MOVE_TILES
-- desde o último corte (carro com qualquer FPS, teleporte), o que passou de MAX_RADIUS + SLACK
-- sai na hora. O teleporte não tem caso próprio: o lugar novo está longe e tudo passa do corte.
local ticks = 0
Events.OnTick.Add(function()
    local p = getSpecificPlayer(0)
    if p and nFloor + nWall > 0 then
        if p:isDead() then
            O.stripAll()
        else
            local x, y = p:getX(), p:getY()
            local dx, dy = x - (cutX or x), y - (cutY or y)
            if not cutX or dx * dx + dy * dy >= O.MOVE_TILES * O.MOVE_TILES then
                cut(math.floor(x), math.floor(y))
                cutX, cutY = x, y
            end
        end
    end
    ticks = ticks + 1
    if ticks < O.UPDATE_TICKS then return end
    ticks = 0
    update()
end)

-- Antes do IsoCell.save gravar os chunks (GameWindow.save: OnSave 302, IsoCell.save 364).
Events.OnSave.Add(function()
    local n = nFloor + nWall
    O.stripAll()
    if getDebug() and n > 0 then print("[NOM] outro mundo: " .. n .. " alvos limpos pro save") end
end)

-- A instância é uma que o mod pôs neste objeto?
local function mine(e, obj, inst)
    if not e or e.obj ~= obj then return false end
    for _, r in ipairs(e.list) do
        if r.inst == inst then return true end
    end
    return false
end

-- Chunk carregado do disco: tira floors_burnt_01_* anexado que não é do registro (vazado).
Events.LoadGridsquare.Add(function(sq)
    local sk = sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ()
    local removed = 0
    for _, kind in ipairs({ "F", "N", "W" }) do
        local obj
        if kind == "F" then obj = sq:getFloor() else obj = sq:getWall(kind == "N") end
        local list = obj and obj:getAttachedAnimSprite()
        if list and list:size() > 0 then
            for i = list:size() - 1, 0, -1 do
                local inst = list:get(i)
                if D.own(inst:getParentSprite():getName()) and not mine(reg[sk .. kind], obj, inst) then
                    obj:RemoveAttachedAnim(i)
                    removed = removed + 1
                end
            end
        end
    end
    if removed > 0 and getDebug() then
        print("[NOM] outro mundo: " .. removed .. " anexos vazados limpos em " .. sk)
    end
end)

Events.OnGameStart.Add(forget)
Events.OnMainMenuEnter.Add(forget) -- o mundo já se foi: só esquece

return NOM_FogOverlays
