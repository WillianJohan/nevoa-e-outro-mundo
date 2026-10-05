-- Morte do Eco com dissolve (sprint 0018, ADR-016), só no jogo de quem vê (solo e cliente
-- de MP): o Eco veste o véu gêmeo com shader e uma casca de cinza (malha Hazmat vanilla com
-- as máscaras do corpo), os dois queimam pelo Alpha (client/NOM_Dissolve.lua, modo "death")
-- durante a animação de morte, brasas sobem (client/NOM_Embers.lua) e o corpo que nasce fica
-- escondido e sem nada vestido até o servidor tirá-lo (server/NOM_Eco.lua, como antes).
--
-- Por que pelo WornItems e no tick seguinte (bytecode B42.21, review da 0018):
-- * IsoGameCharacter.Kill 35–50 liga o onKillDone logo depois do onKilled (que dispara o
--   OnZombieDead), e com ele IsoZombie.getItemVisuals sai do WornItems (isUsingWornItems;
--   getItemVisuals 0–38): o modelo refeito na queda (resetModelNextFrame) é o do WornItems.
-- * No solo o OnZombieDead do servidor (server/NOM_Eco.lua) roda no mesmo processo, DEPOIS
--   deste (shared → client → server), e limpa inventário e WornItems (sem loot, sprint 0002).
--   Vestir no evento seria apagado. Por isso a morte só enfileira, e o próximo OnTick veste
--   cópias novas (instanceItem) da cinza, do véu gêmeo e da casca no WornItems já limpo
--   (WornItems.setItem é local; o setWornItem do personagem mandaria SyncClothing no MP).
--   Nada vai pro inventário: o loot continua vazio. O corpo copia o WornItems
--   (IsoDeadBody.<init> 661–710), então o OnDeadBodySpawn o limpa além de escondê-lo.
-- * O modelo velho segue na tela até o reset: a limpeza do servidor não pisca.
--
-- Cliente de MP: dieNetwork 0–10 faz Kill e logo becomeCorpse, então não há janela: o
-- corpo nasce no mesmo tick e só as brasas aparecem (o console mostra "janela ms=0").
if isServer() then return end

require "NOM_Dissolve"
require "NOM_Embers"

NOM_EcoFx = {
    OUTFIT = "NOM_Eco", -- media/clothing/clothing.xml
    ASH = "Base.NOM_EcoCinza",
    VEIL = "Base.NOM_EcoVeu",
    VEIL_FX = "Base.NOM_EcoVeuFx",
    SHELL_ITEM = "Base.NOM_EcoCasca",
    -- Decisão de arte do Johan pendente: a casca Hazmat muda a silhueta do Eco no segundo da
    -- morte. false = só o véu queima e o corpo some em fade.
    SHELL = true,
    NEAR = 2,          -- tiles: o corpo pode cair no square vizinho
    FORGET_MS = 10000, -- morte sem corpo (cliente que não o viu nascer) sai da lista
}

local F = NOM_EcoFx
local deaths = {}  -- { x, y, z, at }: a janela de cada Eco, achada pelo lugar do corpo
local pending = {} -- zumbis a vestir no próximo tick

local function debugLog(msg)
    if getDebug() then print("[NOM] eco: " .. msg) end
end

local function add(wi, fullType)
    local it = instanceItem(fullType)
    if it then wi:setItem(it:getBodyLocation(), it) end
end

local function dress(z)
    local wi = z:getWornItems()
    local ash = false
    for i = wi:size() - 1, 0, -1 do
        local it = wi:get(i):getItem()
        local t = it:getFullType()
        if t == F.VEIL then wi:remove(it) elseif t == F.ASH then ash = true end
    end
    if not ash then add(wi, F.ASH) end
    add(wi, F.VEIL_FX)
    if F.SHELL then add(wi, F.SHELL_ITEM) end
    z:resetModelNextFrame()
end

local function dead(z)
    if z:getOutfitName() ~= F.OUTFIT or not NOM_Dissolve.enabled() then return end
    local now = getTimestampMs()
    local x, y, zz = z:getX(), z:getY(), z:getZ()
    deaths[#deaths + 1] = { x = x, y = y, z = zz, at = now }
    NOM_Embers.burst(x, y, zz)
    if NOM_Dissolve.run(z, "death") then
        deaths[#deaths].ours = true -- a fila veste: o corpo sai limpo mesmo com a opção desligada depois
        pending[#pending + 1] = z
        debugLog("morte com dissolve")
    end
end

-- A morte mais perto do corpo (mesmo andar, até NEAR tiles); sai da lista.
local function takeDeath(b)
    local bx, by, bz = b:getX(), b:getY(), b:getZ()
    local best, bd
    for i, d in ipairs(deaths) do
        local dx, dy = d.x - bx, d.y - by
        local dist = dx * dx + dy * dy
        if math.floor(d.z) == math.floor(bz) and dist <= F.NEAR * F.NEAR and (not bd or dist < bd) then
            best, bd = i, dist
        end
    end
    if not best then return nil end
    return table.remove(deaths, best)
end

-- Corpo de Eco: escondido e sem nada vestido se o dissolve está ligado ou se a morte veio da
-- nossa fila (a opção desligada no meio não deixa a casca no corpo, nem no save se a remoção
-- do servidor falhar).
local function body(b)
    if b:isAnimal() or b:getOutfitName() ~= F.OUTFIT then return end
    local on = NOM_Dissolve.enabled()
    if not on and #deaths == 0 then return end
    local d = takeDeath(b)
    if not (d and d.ours) and not on then return end
    b:setDoRender(false)
    b:getWornItems():clear()
    debugLog("corpo escondido, janela ms=" .. tostring(d and math.floor(getTimestampMs() - d.at) or -1))
end

local function tick()
    if #pending > 0 then
        local list = pending
        pending = {}
        for _, z in ipairs(list) do
            if z:getCurrentSquare() then dress(z) end -- sem square: o corpo já nasceu
        end
    end
    if #deaths > 0 then
        local now = getTimestampMs()
        for i = #deaths, 1, -1 do
            if now - deaths[i].at > F.FORGET_MS then table.remove(deaths, i) end
        end
    end
end

-- pcall: uma surpresa da API não pode quebrar o evento dos outros.
local function safe(fn)
    return function(x)
        local ok, err = pcall(fn, x)
        if not ok then print("[NOM] eco: erro: " .. tostring(err)) end
    end
end

Events.OnZombieDead.Add(safe(dead))
Events.OnDeadBodySpawn.Add(safe(body))
Events.OnTick.Add(safe(tick))
Events.OnMainMenuEnter.Add(function()
    deaths = {}
    pending = {}
end)

return NOM_EcoFx
