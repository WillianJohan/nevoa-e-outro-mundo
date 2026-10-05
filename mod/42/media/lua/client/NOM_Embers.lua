-- Brasas e cinza da morte do Eco (sprint 0018, ADR-016), só no jogo de quem vê: um punhado
-- de partículas que sobe do corpo, desenhado pelo overlay de tela da sprint 0013
-- (client/NOM_ScreenFx.lua, lista NOM_ScreenFx.extra). As partículas vêm do
-- shared/NOM_EmberRules.lua; aqui só a projeção e o desenho.
--
-- Posição: isoToScreenX/Y(pn, x, y, z) do pé do Eco, uma vez por quadro e por morte
-- (client/ISUI/ISButtonPrompt.lua:176); as partículas andam em pixels de tela divididos
-- pelo zoom (getCore():getZoom(pn), client/Foraging/ISSearchManager.lua:103). Desenho
-- com cor e alfa (ISUIElement.lua:1032-1041), textura branca da 0013. Sem profundidade:
-- passa por cima de parede (limite aceito, spike-dissolve §D). Só o jogador 0, como o resto
-- do overlay.
if isServer() then return end

require "NOM_EmberRules"
require "NOM_ScreenFx"

NOM_Embers = { TEXTURE = "media/textures/NOM/ScreenFx/NOM_White.png" }

local E = NOM_EmberRules
local bursts = {}
local tex

-- false: no teto (a morte segue sem brasa).
function NOM_Embers.burst(x, y, z)
    if #bursts >= E.CAP then return false end
    local now = getTimestampMs()
    bursts[#bursts + 1] = { x = x, y = y, z = z, at = now, parts = E.burst(now + x * 31 + y * 17) }
    return true
end

function NOM_Embers.count()
    return #bursts
end

local function draw(el, now)
    if #bursts == 0 then return end
    for i = #bursts, 1, -1 do
        if now - bursts[i].at >= E.LIFE_MS then table.remove(bursts, i) end
    end
    if #bursts == 0 then return end
    if MainScreen and MainScreen.instance and MainScreen.instance:isReallyVisible() then return end
    if not getSpecificPlayer(0) then return end
    tex = tex or getTexture(NOM_Embers.TEXTURE)
    if not tex then return end
    local zoom = math.max(getCore():getZoom(0), 0.25)
    for _, b in ipairs(bursts) do
        local sx, sy = isoToScreenX(0, b.x, b.y, b.z), isoToScreenY(0, b.x, b.y, b.z)
        local ms = now - b.at
        for _, p in ipairs(b.parts) do
            local dx, dy, a, r, g, bl, size = E.at(p, ms)
            if dx then
                local s = math.max(1, size / zoom)
                el:drawTextureScaled(tex, sx + dx / zoom, sy + dy / zoom, s, s, a, r, g, bl)
            end
        end
    end
end

NOM_ScreenFx.extra[#NOM_ScreenFx.extra + 1] = draw
Events.OnMainMenuEnter.Add(function() bursts = {} end)

return NOM_Embers
