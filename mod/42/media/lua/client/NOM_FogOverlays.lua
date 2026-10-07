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
-- * LoadGridsquare: floors_burnt_01_* ou textura nossa anexados (ninguém no vanilla anexa,
--   D.own) que não são do registro são vazados de uma sessão que caiu depois de um hot save:
--   saem. Nome vanilla vazado fica (ADR-017). A textura nossa é sprite de runtime (ID 20000000):
--   o load já a descarta (pz-api-notes §26).
-- * A ação do jogador em curso segura o square do alvo limpo (pá, marreta, móvel).
-- * Nada pela rede: nenhum transmit*. No cliente de MP o chunk nem é gravado
--   (IsoChunk.Save sai com GameClient.client).
--
-- Transição descascando (sprint 0035): na borda ao vivo (a névoa abre com a fuga correndo),
-- cada square espera o atraso dele (D.reveal × REVEAL_MS) e solta lascas ao ser vestido
-- (NOM_Flakes.burst); no fim da névoa os alvos saem pelo mesmo ruído, ao contrário, ao longo de
-- UNREVEAL_MS. Só visual: o OnSave, a morte e o corte de MAX_RADIUS + SLACK tiram na hora.
--
-- Silent Hill (sprint 0035, Tarefa 4b): a regra depende da cor (D.floor/D.wall com red) e usa
-- texturas nossas, sprites de runtime que o client/NOM_OwnSprites.lua registra; o ensure roda
-- antes do primeiro anexo da sessão (depois disso, só Lua).
if isServer() then return end

require "NOM_Config"
require "NOM_FogState"
require "NOM_DressingRules"
require "NOM_ScreenFxOptions"
require "NOM_OwnSprites"

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
    -- O corte de um anel cheio custa ~1650 chamadas Java (estresse: parede N e W em todo square)
    -- e a atualização inteira, ~2300: juntos, ~3900 num tick. No tick em que o corte tirou alguma
    -- coisa a atualização vai pro seguinte; se ele também cortou (carro a 2 tiles por tick), ela
    -- veste SCAN_BUDGET ÷ LIGHT_DIV (de carro ninguém repara na borda). Quem andou MOVE_TILES
    -- desde a atualização anterior tira em lote STRIP_BUDGET ÷ LIGHT_DIV: o que saiu da tela o
    -- corte leva de qualquer jeito. O corte fica inteiro (pz-api-notes §16.6).
    LIGHT_DIV = 4,
    VERIFY_BUDGET = 20,  -- alvos conferidos por atualização (a lista mexida por baixo: põe de novo)
    DENSITY_MS = 1000,   -- densidade nova só vale parada esse tempo (o slider anda de 0,1 em 0,1)
    -- Transição descascando (sprint 0035): na borda ao vivo, cada square espera
    -- D.reveal × REVEAL_MS reais; o que espera vai pra um pendente por fatia de BUCKET_MS e
    -- não gasta o SCAN_BUDGET. A volta olha até SCAN_BUDGET × LOOK_MULT squares por atualização
    -- (o já visto e o que espera custam só Lua).
    -- A janela (atraso e rajada) fecha REVEAL_MS + REVEAL_TAIL_MS depois da borda.
    REVEAL_MS = 6000,
    REVEAL_TAIL_MS = 2000,
    BUCKET_MS = 200,
    LOOK_MULT = 4,
    IN_FLAKES = 2,       -- lascas pedidas por alvo revelado na janela (NOM_Flakes.burst, com teto)
    -- Fim da névoa: cada alvo sai depois de (1 − D.reveal) × UNREVEAL_MS (o último a abrir sai
    -- primeiro), ainda no lote de STRIP_BUDGET; até OUT_FLAKES lascas por atualização.
    UNREVEAL_MS = 4000,
    OUT_FLAKES = 6,
}

local O = NOM_FogOverlays
local D = NOM_DressingRules

-- Batente de porta ou janela no lado da parede: o anexo cairia no batente. As propriedades do
-- sprite somam nas do square (ISBuildIsoEntity.lua:195-198).
local FRAME_FLAGS = { N = { "DoorWallN", "WindowN", "doorN", "windowN" },
    W = { "DoorWallW", "WindowW", "doorW", "windowW" } }
local SIDES = { { "N", true }, { "W", false } }

-- reg[k] (k = "x,y,z" .. "F"|"N"|"W") = { obj, sq, sk, kind, x, y, z, gen, rv, list = { {inst, name} } }
local reg, nFloor, nWall
-- seen[sk] = pack(x, y): square decidido (sem chunk: tenta de novo). Andando, a volta não esquece
-- nem recomeça do centro (o que já viu custa só a chave, e ela chega no anel de fora); a
-- atualização esquece o que passou de radius + SLACK, e o tamanho fica o da área do raio, não o
-- do caminho. nSeen: quantos, contado por cima (o esquecimento reconta). forX/Y: a posição no
-- último esquecimento.
local seen, nSeen, forX, forY
local held       -- [sk] = true: square do alvo da ação em curso (fica limpo)
local cursor, gen, cutX, cutY
local updX, updY -- a posição na atualização anterior (LIGHT_DIV)
local density, pendingD, pendingAt
local red        -- a cor do desenho em vigor (névoa vermelha)
local verifyKeys, verifyAt
local radius
-- Transição (sprint 0035). revealAt: a borda ao vivo, enquanto a janela está aberta;
-- revealSince: a mesma hora até o fim da névoa (o sinal). pend[b] = { {x, y, z, sk, rv} }:
-- squares esperando até b × BUCKET_MS; pendAt, a primeira fatia ainda não esvaziada.
-- unrevealAt: o fim da névoa, durante a retirada. tickX/Y: a posição no tick anterior.
-- lastReveal: a última borda ao vivo, que o fim da névoa não apaga (a tontura).
local revealAt, revealSince, pend, pendAt, unrevealAt, tickX, tickY, lastReveal
local puff       -- a rajada vale nesta atualização (NOM_Flakes carregado, efeitos ligados)
local revealFns = {}

local function forget()
    reg, nFloor, nWall = {}, 0, 0
    seen, nSeen, held, forX, forY = {}, 0, {}, nil, nil
    cursor, gen, cutX, cutY = 1, nil, nil, nil
    updX, updY = nil, nil
    density, pendingD, pendingAt = nil, nil, nil
    red = false
    verifyKeys, verifyAt = {}, 1
    radius = D.MIN_RADIUS
    revealAt, revealSince, pend, pendAt, unrevealAt, tickX, tickY = nil, nil, {}, 0, nil, nil, nil
    lastReveal = nil
    puff = false
end
forget()

-- Tudo de novo, do mais perto (o pendente vai junto: a volta o refaz).
local function reseen()
    seen, nSeen, cursor = {}, 0, 1
    pend, pendAt = {}, 0
end

-- x e y num número só (o valor do seen, sem tabela por square): |y| < SPAN / 2 em qualquer mapa.
local SPAN = 1048576
local HALF = SPAN / 2

local function pack(x, y)
    return x * SPAN + y + HALF
end

local visits = 0 -- chaves do "já visto" percorridas pelo esquecimento, desde o carregamento

-- Esquece o que passou de radius + SLACK (só Lua; apaga depois da volta, como o stripWhere). O
-- que volta pro raio é olhado de novo; o pendente esquecido o drain pula. Esqueceu mais do que
-- guardou (teleporte): lugar novo, a volta recomeça do mais perto.
local function forgetFar(px, py)
    local far = (radius + O.SLACK) * (radius + O.SLACK)
    local out, n = {}, 0
    for sk, v in pairs(seen) do
        local x = math.floor(v / SPAN)
        local dx, dy = x - px, v - x * SPAN - HALF - py
        if dx * dx + dy * dy > far then out[#out + 1] = sk else n = n + 1 end
    end
    for _, sk in ipairs(out) do seen[sk] = nil end
    visits = visits + n + #out
    nSeen = n
    if #out > n then cursor = 1 end
end

-- Trabalho Lua do esquecimento (testes): quantas chaves do "já visto" ele percorreu até agora.
function O.seenVisits()
    return visits
end

-- Quantos squares o "já visto" guarda (testes e debug; conta na hora).
function O.seenSize()
    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    return n
end

-- Fecha a janela: o que esperava volta pra volta, sem atraso.
local function endReveal()
    for _, l in pairs(pend) do
        for _, s in ipairs(l) do seen[s[4]] = nil end
    end
    pend, pendAt, revealAt, tickX, tickY = {}, 0, nil, nil, nil
end

-- getTimestampMs da borda ao vivo (a névoa abriu com a fuga correndo) desta névoa, ou nil
-- (entrou no meio, carregou o save com névoa, sem névoa).
function O.revealStartedAt()
    return revealSince
end

-- getTimestampMs da última borda ao vivo, mesmo depois do fim da névoa, ou nil desde o
-- carregamento. A tontura (client/NOM_ScreenFx.lua) liga aqui: a névoa que acaba no meio dela
-- não a corta seco, a curva termina sozinha.
function O.lastRevealAt()
    return lastReveal
end

-- fn(at) na borda ao vivo, com a hora (getTimestampMs).
function O.onReveal(fn)
    revealFns[#revealFns + 1] = fn
end

-- A janela da revelação está aberta (atraso e rajada valendo)?
function O.revealing()
    return revealAt ~= nil
end

function O.count()
    return nFloor, nWall -- alvos com anexo do mod: pisos e paredes
end

function O.radius()
    return radius
end

-- Os alvos vestidos agora ({ x, y, z, kind = "F"|"N"|"W" }, só leitura): as fontes das lascas
-- (client/NOM_Flakes.lua, sprint 0035). Com r, só os do andar pz a até r tiles de (px, py): a
-- lista nova a cada segundo fica do tamanho do que as lascas usam, não do registro. Só Lua.
function O.targets(px, py, pz, r)
    local out = {}
    if not r then
        for _, e in pairs(reg) do out[#out + 1] = e end
        return out
    end
    local r2 = r * r
    for _, e in pairs(reg) do
        local dx, dy = e.x - px, e.y - py
        if e.z == pz and dx * dx + dy * dy <= r2 then out[#out + 1] = e end
    end
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
    return #out
end

function O.stripAll()
    stripWhere(function() return true end)
    reseen()
end

-- Lascas a mais no alvo (client/NOM_Flakes.lua; carregado depois deste, que ele lê o registro).
local function flakes(e, n)
    if puff then NOM_Flakes.burst(e.x, e.y, e.z, e.kind, n) end
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

local function add(k, sq, sk, kind, obj, x, y, z, rv, names, grime)
    local e = { k = k, obj = obj, sq = sq, sk = sk, kind = kind, x = x, y = y, z = z, gen = gen, rv = rv,
        names = names, grime = grime, list = {} }
    attach(obj, names, grime, e.list)
    if #e.list == 0 then return end
    reg[k] = e
    count(e, 1)
    if revealAt then flakes(e, O.IN_FLAKES) end
end

local function frame(props, side)
    for _, f in ipairs(FRAME_FLAGS[side]) do
        if props:has(IsoFlagType[f]) then return true end
    end
    return false
end

-- Um square: piso e paredes N/W, a regra antes do Java. rv: D.reveal do square (a vez dele
-- na retirada), se já calculado.
local function dress(cell, x, y, z, sk, per, d, rv)
    local sq = cell:getGridSquare(x, y, z)
    if not sq then return false end -- sem chunk: tenta na próxima volta
    local outside = sq:isOutside()
    local props
    if not reg[sk .. "F"] then
        local f = D.floor(x, y, z, per, d, outside, red)
        if f then
            props = sq:getProperties()
            local obj = not props:has(IsoFlagType.water) and sq:getFloor() or nil
            if plain(obj) then
                -- o nome do piso (uma ida ao Java) só quando a regra pôs metal, ferrugem ou tinta
                if D.hasOwn(f) and D.natural(obj:getTextureName()) then
                    f = D.floor(x, y, z, per, d, outside, red, true)
                end
                if f then
                    local names = {}
                    for _, l in ipairs(f) do names[#names + 1] = D.name(l) end
                    local grime = f.grime and D.name(f.grime)
                    if grime then names[#names + 1] = grime end
                    rv = rv or D.reveal(x, y, z, per)
                    add(sk .. "F", sq, sk, "F", obj, x, y, z, rv, names, grime)
                end
            end
        end
    end
    for _, s in ipairs(SIDES) do
        local side, north = s[1], s[2]
        if not reg[sk .. side] then
            local w = D.wall(x, y, z, per, d, north, outside, red)
            if w then
                local obj = sq:getWall(north)
                props = props or (obj and sq:getProperties())
                if plain(obj) and not frame(props, side) then
                    local names = {}
                    for _, l in ipairs(w) do names[#names + 1] = D.name(l) end
                    rv = rv or D.reveal(x, y, z, per)
                    add(sk .. side, sq, sk, side, obj, x, y, z, rv, names, nil)
                end
            end
        end
    end
    return true
end

-- Revelando: veste o pendente cuja vez chegou (fatias até el / BUCKET_MS), até budget squares.
-- O que saiu do raio, de outro andar ou da ação em curso volta pra volta; o que o esquecimento tirou
-- já voltou (a volta o põe de novo no pendente, se precisar). Devolve o que sobrou.
local function drain(cell, px, py, pz, per, d, el, budget)
    local top = math.floor(el / O.BUCKET_MS)
    local r2 = radius * radius
    while pendAt <= top and budget > 0 do
        local l = pend[pendAt]
        if not l or #l == 0 then
            pend[pendAt] = nil
            pendAt = pendAt + 1
        else
            local s = l[#l]
            l[#l] = nil
            local x, y, sk = s[1], s[2], s[4]
            local dx, dy = x - px, y - py
            if seen[sk] then
                if s[3] ~= pz or held[sk] or dx * dx + dy * dy > r2 then
                    seen[sk] = nil
                else
                    budget = budget - 1
                    if not dress(cell, x, y, pz, sk, per, d, s[5]) then seen[sk] = nil end
                end
            end
        end
    end
    return budget
end

-- Um lote da varredura: mais perto primeiro (D.OFFSETS), em volta contínua até o raio (o anel
-- novo de quem anda, o square que perdeu o anexo); o square já decidido custa só a chave, fora
-- do SCAN_BUDGET. Revelando, o square cuja vez não chegou vai pro pendente (só Lua, fora dele).
local function scan(px, py, pz, per, d, now, light)
    local cell = getCell()
    local n = D.WITHIN[radius]
    local budget, looks = O.SCAN_BUDGET, O.SCAN_BUDGET * O.LOOK_MULT
    if light then budget = math.floor(budget / O.LIGHT_DIV) end
    local el = revealAt and now - revealAt
    if el then budget = drain(cell, px, py, pz, per, d, el, budget) end
    while budget > 0 and looks > 0 do
        looks = looks - 1
        if cursor > n then cursor = 1 end
        local o = D.OFFSETS[cursor]
        cursor = cursor + 1
        local x, y = px + o[1], py + o[2]
        local sk = x .. "," .. y .. "," .. pz
        if not seen[sk] and not held[sk] then
            local rv = el and D.reveal(x, y, pz, per)
            local b = rv and math.ceil(rv * O.REVEAL_MS / O.BUCKET_MS)
            if b and b * O.BUCKET_MS > el then
                local l = pend[b]
                if not l then
                    l = {}
                    pend[b] = l
                end
                l[#l + 1] = { x, y, pz, sk, rv }
                seen[sk], nSeen = pack(x, y), nSeen + 1
            else
                budget = budget - 1
                if dress(cell, x, y, pz, sk, per, d, rv) then seen[sk], nSeen = pack(x, y), nSeen + 1 end
            end
        end
    end
end

local function hardR2()
    return (D.MAX_RADIUS + O.SLACK) * (D.MAX_RADIUS + O.SLACK)
end

-- Além de MAX_RADIUS + SLACK, na hora, sem lote. Só Lua até achar o que sai. Devolve quantos
-- alvos saíram.
local function cut(px, py)
    local hard = hardR2()
    return stripWhere(function(e)
        local dx, dy = e.x - px, e.y - py
        return dx * dx + dy * dy > hard
    end)
end

-- Fora do raio, de outro andar, de outro desenho ou sem névoa: sai, em lote (light: ÷ LIGHT_DIV).
-- O que passou de MAX_RADIUS + SLACK é do corte no tick (aqui, só mais um no lote). Na
-- retirada (fim da névoa), cada alvo só na vez dele.
local function prune(on, px, py, pz, now, light)
    local r2, n, out = radius * radius, 0, 0
    local cap = light and math.floor(O.STRIP_BUDGET / O.LIGHT_DIV) or O.STRIP_BUDGET
    local el = not on and unrevealAt and now - unrevealAt
    stripWhere(function(e)
        if n >= cap then return false end
        local dx, dy = e.x - px, e.y - py
        local d2 = dx * dx + dy * dy
        local go
        if on then
            go = e.gen ~= gen or e.z ~= pz or d2 > r2
        else
            go = not el or (1 - e.rv) * O.UNREVEAL_MS <= el
        end
        if not go then return false end
        n = n + 1
        if el and out < O.OUT_FLAKES then
            flakes(e, 1)
            out = out + 1
        end
        return true
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

-- busy: o corte deste tick tirou alguma coisa (vestir ÷ LIGHT_DIV). Andou MOVE_TILES desde a
-- última atualização (carro): retirada ÷ LIGHT_DIV.
local function update(busy)
    local p = getSpecificPlayer(0) -- getPlayer() é o jogador em foco na tela dividida
    if not p or p:isDead() then
        if nFloor + nWall > 0 then O.stripAll() end
        return
    end
    local fx, fy = p:getX(), p:getY()
    local mx, my = fx - (updX or fx), fy - (updY or fy)
    local moving = mx * mx + my * my >= O.MOVE_TILES * O.MOVE_TILES
    updX, updY = fx, fy
    local now = getTimestampMs()
    if revealAt and now - revealAt >= O.REVEAL_MS + O.REVEAL_TAIL_MS then endReveal() end
    if unrevealAt and now - unrevealAt >= O.UNREVEAL_MS then unrevealAt = nil end
    puff = (revealAt or unrevealAt) and NOM_Flakes ~= nil and NOM_ScreenFxOptions.intensity() > 0 or false
    -- densidade em vigor: a nova só depois de parada DENSITY_MS (a primeira, na hora)
    local raw = D.density(NOM_ScreenFxOptions.overlayDensity(), NOM_FogState.red)
    if raw ~= pendingD then pendingD, pendingAt = raw, now end
    if density == nil or (density ~= pendingD and now - pendingAt >= O.DENSITY_MS) then density = pendingD end
    local d = density
    local on = NOM_FogState.on and NOM_Config.get("FogOverlays") and d > 0
    local px, py, pz = math.floor(p:getX()), math.floor(p:getY()), math.floor(p:getZ())
    local per = NOM_FogState.period or 0
    if on then
        NOM_OwnSprites.ensure()
        radius = screenRadius(p, px, py)
        local r = NOM_FogState.red == true
        local g = per .. ":" .. d .. (r and ":r" or "")
        if g ~= gen then -- outro desenho: o velho sai no prune
            gen, red = g, r
            reseen()
        end
        hold(p)
    end
    prune(on, px, py, pz, now, moving)
    if not on then return end
    verify()
    -- o esquecimento percorre o "já visto" inteiro: aqui, não no corte (de carro, todo tick)
    local gx, gy = fx - (forX or fx), fy - (forY or fy)
    if not forX or gx * gx + gy * gy >= O.MOVE_TILES * O.MOVE_TILES then
        forgetFar(px, py)
        forX, forY = fx, fy
    end
    scan(px, py, pz, per, d, now, busy)
end

-- Todo tick: a morte (no solo o jogo salva logo depois) tira tudo na hora; andou MOVE_TILES
-- desde o último corte (carro com qualquer FPS, teleporte), o que passou de MAX_RADIUS + SLACK
-- sai na hora. O teleporte não tem caso próprio: o lugar novo está longe e tudo passa do corte.
-- Na janela da revelação, um tick que anda mais que o corte (nenhum carro faz isso) é teleporte:
-- o lugar novo sai sem atraso. A atualização não cai no tick em que o corte tirou alguma coisa
-- (LIGHT_DIV).
local ticks = 0
Events.OnTick.Add(function()
    local p = getSpecificPlayer(0)
    local any = nFloor + nWall > 0
    local cutNow = false
    if p and (any or revealAt or nSeen > 0) then
        if p:isDead() then
            if any then O.stripAll() end
        else
            local x, y = p:getX(), p:getY()
            if revealAt then
                local jx, jy = x - (tickX or x), y - (tickY or y)
                if jx * jx + jy * jy > hardR2() then endReveal() else tickX, tickY = x, y end
            end
            local dx, dy = x - (cutX or x), y - (cutY or y)
            if (any or nSeen > 0) and (not cutX or dx * dx + dy * dy >= O.MOVE_TILES * O.MOVE_TILES) then
                cutNow = cut(math.floor(x), math.floor(y)) > 0
                cutX, cutY = x, y
            end
        end
    end
    ticks = ticks + 1
    if ticks < O.UPDATE_TICKS or (cutNow and ticks == O.UPDATE_TICKS) then return end
    ticks = 0
    update(cutNow)
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

-- Chunk carregado do disco: tira o que só o mod anexa (D.own) e não é do registro (vazado).
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

-- Borda da névoa (NOM_FogState.onChange). Ao vivo é a que chega com a fuga correndo: no solo o
-- NOM_FogEvent.begin liga a névoa antes de descer a subida; no MP o comando fog faz o set antes
-- do dropRising (client/NOM_FogClient.lua). Carregar o save com névoa (o primeiro
-- OnClimateTick liga) e entrar no MP no meio (fogState) chegam sem a fuga: sem atraso.
NOM_FogState.onChange(function(on)
    local now = getTimestampMs()
    if on then
        unrevealAt = nil
        if not NOM_FogState.rising then return end
        revealAt, revealSince, lastReveal, tickX, tickY = now, now, now, nil, nil
        reseen()
        for _, fn in ipairs(revealFns) do fn(now) end
    else
        endReveal()
        reseen() -- a próxima névoa olha tudo de novo
        revealSince, unrevealAt = nil, now
    end
end)

Events.OnGameStart.Add(forget)
Events.OnMainMenuEnter.Add(forget) -- o mundo já se foi: só esquece

return NOM_FogOverlays
