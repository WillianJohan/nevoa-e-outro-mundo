-- Poste que pisca (sprint 0045), lado de quem desenha: o servidor manda a posição e o padrão
-- (server/NOM_LampFlicker.lua; no MP pelo comando "lampFlicker" em client/NOM_FogClient.lua) e aqui
-- a luz da lista de postes nessa posição apaga e acende pela cor. IsoLightSource.setActive não
-- serve pro poste da rede (o LightingJNI.checkLights recalcula o active); a cor passa pro JNI
-- quando muda (pz-api-notes §34). No fim a cor volta a de antes.
require "NOM_FlickerRules"

NOM_LampFlickerFx = {}

local X = NOM_LampFlickerFx
local playing = {} -- { { light, r, g, b, start, segs, lit } }

local function find(x, y, z)
    local list = getCell():getLamppostPositions()
    for i = 0, list:size() - 1 do
        local l = list:get(i)
        if l ~= nil and l:getX() == x and l:getY() == y and l:getZ() == z and l:isHydroPowered()
            and l:getLocalToBuilding() == nil then
            return l
        end
    end
    return nil
end

local function paint(f, on)
    if on then
        f.light:setR(f.r)
        f.light:setG(f.g)
        f.light:setB(f.b)
    else
        f.light:setR(0)
        f.light:setG(0)
        f.light:setB(0)
    end
    f.lit = on
end

function X.play(x, y, z, segs)
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z or type(segs) ~= "table" or #segs == 0 then return false end
    local l = find(x, y, z)
    if l == nil then return false end
    for _, f in ipairs(playing) do
        if f.light == l then return false end
    end
    local f = { light = l, r = l:getR(), g = l:getG(), b = l:getB(), start = getTimestampMs(), segs = segs }
    paint(f, false)
    playing[#playing + 1] = f
    return true
end

function X.busy() return #playing > 0 end

-- No solo o cliente e o servidor dividem a luz, e o IsoLightSwitch.save grava a cor dela
-- (getPrimaryR/G/B, pz-api-notes §34): antes de salvar, todo poste volta à cor de antes.
-- GameWindow.save dispara "OnSave" antes de gravar o mundo.
function X.restoreAll()
    for _, f in ipairs(playing) do paint(f, true) end
    playing = {}
end

function X.tick()
    if #playing == 0 then return end
    local now = getTimestampMs()
    for i = #playing, 1, -1 do
        local f = playing[i]
        local on, done = NOM_FlickerRules.stateAt(f.segs, now - f.start)
        if done then
            paint(f, true)
            table.remove(playing, i)
        elseif on ~= f.lit then
            paint(f, on)
        end
    end
end

Events.OnTick.Add(X.tick)
Events.OnSave.Add(X.restoreAll)

return NOM_LampFlickerFx
