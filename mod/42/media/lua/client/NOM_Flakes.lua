-- Lascas de tinta e cinza do Outro Mundo (sprint 0035, estilo Silent Hill), só no jogo de quem
-- vê: saem do chão e das paredes que o client/NOM_FogOverlays.lua vestiu (a parede solta mais)
-- e sobem devagar, girando. Desenho pelo overlay de tela da sprint 0013 (NOM_ScreenFx.extra),
-- como as brasas do Eco (client/NOM_Embers.lua): sem profundidade, passam por cima de parede e
-- de personagem (limite aceito, spike-dissolve §D). Só o jogador 0, como o resto do overlay.
-- O que nasce, onde e como anda: shared/NOM_FlakeRules.lua.
--
-- Liga com a névoa de jogo (NOM_FogState.on), não na subida da fuga; no fim nada nasce e as
-- vivas terminam o fade. Respeita o toggle FogOverlays do sandbox, a densidade do Outro Mundo e
-- a intensidade dos efeitos de tela (0 com eles desligados, NOM_ScreenFxOptions).
--
-- Projeção (pz-api-notes §25): isoToScreenX/Y(0, x, y, z) é afim em x, y e z dentro do quadro
-- (LuaManager$GlobalObject.isoToScreenX/Y 0–60, IsoUtils.XToScreen/YToScreen): 4 pontos por
-- quadro dão a base e cada lasca sai em Lua. Desenho: drawSubTexture recorta a célula do sprite
-- sheet em pixels da textura (ISUIElement.lua:1043-1052, ISLcdBar.lua:69-72); com cor sempre,
-- que sem r o vanilla desenha o sheet inteiro. A cinza: drawTextureScaled com cor
-- (ISUIElement.lua:1032-1041).
if isServer() then return end

require "NOM_Config"
require "NOM_FogState"
require "NOM_FlakeRules"
require "NOM_DressingRules"
require "NOM_ScreenFxOptions"
require "NOM_ScreenFx"
require "NOM_FogOverlays"

NOM_Flakes = {
    SOURCE_MS = 1000,   -- as fontes (o que o Outro Mundo vestiu) relidas a cada segundo
    MAX_STEP_MS = 250,  -- o quadro depois de um engasgo não pula a vida inteira
    -- isoToScreenX/Y devolvem float: com x, y ~10⁴ tiles o erro é ~0,06 px. Os pontos da base
    -- a BASIS tiles dividem esse erro por BASIS antes de multiplicar pela distância da lasca.
    BASIS = 16,
    -- idas ao Java por quadro com lasca, além de 1 por lasca desenhada: jogador e isDead, menu,
    -- getCore e zoom, 8 projeções, retângulo da tela (4) e, 1 vez por segundo, x, y, z
    FIXED_CALLS = 20,
}

local N = NOM_Flakes
local R = NOM_FlakeRules
local state = R.new()
local src, srcAt, lastMs, rand
local textures = {}

function N.count()
    return R.count(state)
end

function N.state()
    return state
end

function N.parts()
    return state.parts
end

local function random()
    rand = rand or R.rng(getTimestampMs())
    return rand()
end

-- Rajada de n no square (kind "F" chão, "N"/"W" parede), até o teto: a Tarefa 2 pede quando o
-- square é revelado. Devolve quantas nasceram.
function N.burst(x, y, z, kind, n)
    return R.burst(state, n, { x = x, y = y, z = z, kind = kind or "F" }, random)
end

local function forget()
    state, src, srcAt, lastMs = R.new(), nil, nil, nil
end

-- getTexture devolve nil se não achar (ISSleepingUI.lua:14-15): a camada some, e não pergunta
-- de novo a cada quadro.
local function texture(path)
    local t = textures[path]
    if t == nil then
        t = getTexture(path) or false
        textures[path] = t
    end
    return t or nil
end

local function rate()
    local F = NOM_FogState
    if not F.on or not NOM_Config.get("FogOverlays") then return 0 end
    local d = NOM_DressingRules.density(NOM_ScreenFxOptions.overlayDensity(), F.red)
    return R.rate(d, NOM_ScreenFxOptions.intensity())
end

local function refresh(p, now)
    srcAt = now
    local px, py, pz = math.floor(p:getX()), math.floor(p:getY()), math.floor(p:getZ())
    src = R.sources(NOM_FogOverlays.targets(px, py, pz, R.RADIUS), px, py, pz)
end

local function draw(el, now)
    local dt = lastMs and math.max(0, math.min(now - lastMs, N.MAX_STEP_MS)) or 0
    lastMs = now
    local r = rate()
    if r <= 0 then src, srcAt = nil, nil end
    if r <= 0 and R.count(state) == 0 then return end
    if MainScreen and MainScreen.instance and MainScreen.instance:isReallyVisible() then return end
    local p = getSpecificPlayer(0)
    if not p or p:isDead() then
        forget()
        return
    end
    if r > 0 and (not srcAt or now - srcAt >= N.SOURCE_MS) then refresh(p, now) end
    R.step(state, dt, r, src, random)
    local parts = state.parts
    if #parts == 0 then return end
    local chip, ash = texture(R.TEXTURES.lasca), texture(R.TEXTURES.cinza)
    if not chip and not ash then return end

    -- base da projeção perto das lascas
    local K = N.BASIS
    local ox, oy, oz = math.floor(parts[1].x), math.floor(parts[1].y), math.floor(parts[1].z)
    local x0, y0 = isoToScreenX(0, ox, oy, oz), isoToScreenY(0, ox, oy, oz)
    local ax, ay = (isoToScreenX(0, ox + K, oy, oz) - x0) / K, (isoToScreenY(0, ox + K, oy, oz) - y0) / K
    local bx, by = (isoToScreenX(0, ox, oy + K, oz) - x0) / K, (isoToScreenY(0, ox, oy + K, oz) - y0) / K
    local cx, cy = isoToScreenX(0, ox, oy, oz + 1) - x0, isoToScreenY(0, ox, oy, oz + 1) - y0
    local zoom = math.max(getCore():getZoom(0), 0.25)
    local left, top = getPlayerScreenLeft(0), getPlayerScreenTop(0)
    local right, bottom = left + getPlayerScreenWidth(0), top + getPlayerScreenHeight(0)
    local pal = R.palette(NOM_FogState.color())
    local cl, ca, C = pal.lasca, pal.cinza, R.CELL
    for i = 1, #parts do
        local q = parts[i]
        local dx, dy, a, f, size = R.at(q, state.t - q.born)
        if dx and a > 0.01 then
            local ux, uy, uz = q.x - ox, q.y - oy, q.z - oz
            local sx = x0 + ax * ux + bx * uy + cx * uz + dx / zoom
            local sy = y0 + ay * ux + by * uy + cy * uz + dy / zoom
            local s = math.max(1, size / zoom)
            local h = s / 2
            if sx + h >= left and sx - h <= right and sy + h >= top and sy - h <= bottom then
                if q.type == "lasca" then
                    if chip then el:drawSubTexture(chip, f * C, q.shape * C, C, C, sx - h, sy - h, s, s, a, cl[1], cl[2], cl[3]) end
                elseif ash then
                    el:drawTextureScaled(ash, sx - h, sy - h, s, s, a, ca[1], ca[2], ca[3])
                end
            end
        end
    end
end

NOM_ScreenFx.extra[#NOM_ScreenFx.extra + 1] = draw
Events.OnMainMenuEnter.Add(forget)

return NOM_Flakes
