-- Sonar do Estalador (sprint 0037 + 0048 + 0053), o desenho. Cada estalo (NOM_Sonar.onRing)
-- agenda N ripples curtos nos BEAT_MS do burst. Em cada batida tenta o mod3
-- (NOMRender_sonarRipple). Sprint 0053: SCREEN_DRAW=false — sem anéis brancos na tela
-- (quebravam imersão); se o mod3 recusar, o ripple some. O achado continua no servidor.
if isServer() then return end

require "NOM_SonarRules"
require "NOM_Sonar"
require "NOM_FogState"
require "NOM_ScreenFx"

NOM_SonarFx = { rings = {}, mod3 = 0 }
local R = NOM_SonarRules
local F = NOM_SonarFx
local tex -- nil: não pediu; false: não achou

-- getTexture devolve nil se não achar (ISSleepingUI.lua:14-15): não pergunta de novo.
local function texture()
    if tex == nil then tex = getTexture(R.TEXTURE) or false end
    return tex or nil
end

-- O mod3 diz true quando pegou o ripple; false ou erro: a tela.
local function mod3(x, y, z)
    local fn = NOMRender_sonarRipple or NOMRender_sonar
    if fn == nil then return false end
    local ok, took = pcall(fn, x, y, z)
    return ok and took == true
end

-- Agenda um ripple por batida do burst (presença). Cap = MAX_RIPPLES.
function F.add(x, y, z)
    local now = getTimestampMs()
    local rings = F.rings
    local beats = R.BEAT_MS
    for i = 1, #beats do
        while #rings >= R.MAX_RIPPLES do table.remove(rings, 1) end
        rings[#rings + 1] = { x = x, y = y, z = z, born = now + beats[i], sent = false }
    end
end

local function prune(now)
    local rings = F.rings
    for i = #rings, 1, -1 do
        local g = rings[i]
        local age = now - g.born
        if g.sent and R.rippleDone(age) then table.remove(rings, i) end
    end
end

-- Dispara o mod3 no instante da batida; se pegou (ou SCREEN_DRAW off), some da lista.
local function fire(now)
    local rings = F.rings
    for i = #rings, 1, -1 do
        local g = rings[i]
        if not g.sent and now >= g.born then
            g.sent = true
            if mod3(g.x, g.y, g.z) then
                F.mod3 = F.mod3 + 1
                table.remove(rings, i)
            elseif not R.SCREEN_DRAW then
                table.remove(rings, i) -- 0053: sem anel branco na tela
            end
        end
    end
end

local function draw(el, now)
    fire(now)
    local rings = F.rings
    if #rings == 0 then return end
    prune(now)
    if #rings == 0 or not R.SCREEN_DRAW then return end
    if MainScreen and MainScreen.instance and MainScreen.instance:isReallyVisible() then return end
    local p = getSpecificPlayer(0)
    if not p or p:isDead() then return end
    local t = texture()
    if not t then return end
    local px, py, pz = p:getX(), p:getY(), math.floor(p:getZ())
    local c = R.COLOR[NOM_FogState.red and "red" or "white"]
    local view2 = R.VIEW * R.VIEW
    for i = 1, #rings do
        local g = rings[i]
        local age = now - g.born
        if age > 0 then
            local dx, dy = g.x - px, g.y - py
            if g.z == pz and dx * dx + dy * dy <= view2 then
                local r, a = R.rippleRadius(age), R.rippleAlpha(age)
                if r > 0 and a > 0 then
                    local cx, cy = isoToScreenX(0, g.x, g.y, g.z), isoToScreenY(0, g.x, g.y, g.z)
                    local ox, oy = R.edge(g.x, g.y, r)
                    local ex = isoToScreenX(0, ox, oy, g.z)
                    local x, y, w, h = R.rect(cx, cy, ex)
                    if x then el:drawTextureScaled(t, x, y, w, h, a, c[1], c[2], c[3]) end
                end
            end
        end
    end
end

NOM_Sonar.onRing(F.add)
NOM_ScreenFx.extra[#NOM_ScreenFx.extra + 1] = draw

return NOM_SonarFx
