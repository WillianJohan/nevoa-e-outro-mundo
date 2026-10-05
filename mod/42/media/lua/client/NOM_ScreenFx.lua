-- Efeitos de tela da névoa (sprint 0013), só no jogo de quem vê (solo e cliente de
-- MP): grão de filme, vinheta que respira (vermelha e mais forte na névoa vermelha),
-- linhas de chiado com o Sem-rosto perto e um pulso vermelho quando uma Carpideira
-- grita perto. Quanto de cada um: shared/NOM_ScreenFxRules.lua; opções do jogador:
-- client/NOM_ScreenFxOptions.lua. ADR-013.
--
-- Como desenha por cima do mundo e por baixo do HUD sem pegar clique (bytecode 42.21):
-- * Um ISUIElement de 1×1 px no canto da tela, como o ISSleepingUI vanilla
--   (client/ISUI/ISSleepingUI.lua:70-82), que desenha fora da própria caixa. O clique
--   (UIManager.updateMouseButtons 54–206) e a roda (update 867–979) só chegam a quem
--   tem o ponto dentro da caixa; o cursor forçado (UIManager.isForceCursorVisible)
--   também. Mesmo assim, setConsumeMouseEvents(false) e onMouse* devolvendo false.
-- * backMost() (FishingManager.lua:41): UIManager.update 389–454 põe o elemento no
--   índice 0 da lista, e o render (240–426) desenha a lista nessa ordem, depois do
--   mundo: o overlay fica por baixo de toda a UI.
-- * Retângulo do jogador 0 lido a cada quadro (getPlayerScreen*, ISSleepingUI.lua:16-17,
--   60-61): resolução nova e tela dividida valem no quadro seguinte. Só o jogador 0
--   (os outros da tela dividida não têm o efeito).
-- * Menu aberto (MainScreen.instance:isReallyVisible(), ISSleepingUI.lua:49) e morte:
--   não desenha. Menu principal: sai da UI (OnMainMenuEnter, MainScreen.lua:2178).
if isServer() then return end

require "NOM_Config"
require "NOM_FogState"
require "NOM_ScreenFxRules"
require "NOM_ScreenFxOptions"
require "NOM_SemRostoRules"
require "NOM_SemRosto"
require "NOM_Carpideira"

NOM_ScreenFx = {
    UPDATE_TICKS = 10,   -- distância do Sem-rosto (como o rádio, NOM_FogSound)
    MAX_STEP_MS = 1000,  -- o primeiro quadro depois de uma pausa não pula o fade inteiro
    GRAIN_JITTER = 64,   -- o grão anda até 64 px por quadro (a repetição dos ladrilhos some)
    -- fog/red (0..1, com fade), static (volume do rádio), flashAt/flashStrength (grito)
    state = NOM_ScreenFxRules.new(),
    ui = nil,
}

local S = NOM_ScreenFx
local R = NOM_ScreenFxRules
local textures = {}
local lastMs

-- getTexture devolve nil se não achar (ISSleepingUI.lua:14-15): a camada some.
-- Guarda só o que achou.
local function tex(path)
    local t = textures[path]
    if t == nil then
        t = getTexture(path)
        textures[path] = t
    end
    return t
end

function S.reset()
    S.state = R.new()
    lastMs = nil
end

-- Avança o fade até agora e devolve o estado. Quem chama: o desenho (todo quadro) e
-- o canal do shader (NOM_FogVignette, todo tick); a segunda chamada no mesmo quadro
-- anda ~0.
function S.sample(now)
    local dt = lastMs and math.max(0, math.min(now - lastMs, S.MAX_STEP_MS)) or 0
    lastMs = now
    return R.step(S.state, { fog = NOM_FogState.on, red = NOM_FogState.red }, dt)
end

local function frame(now)
    return R.layers(S.sample(now), now, NOM_ScreenFxOptions.intensity())
end

local function draw(el)
    local now = getTimestampMs()
    local l = frame(now)
    if not R.visible(l) then return end -- fora da névoa: só a hora acima
    if MainScreen and MainScreen.instance and MainScreen.instance:isReallyVisible() then return end
    local p = getSpecificPlayer(0)
    if not p or p:isDead() then
        S.reset()
        return
    end
    local x, y = getPlayerScreenLeft(0), getPlayerScreenTop(0)
    local w, h = getPlayerScreenWidth(0), getPlayerScreenHeight(0)
    local T = R.TEXTURES
    -- com o mod do shader o grão é dele, de verdade (mod2, screen.frag)
    if l.grain > 0 and not NOM_ShaderMod then
        local g = tex(T.grain[R.grainFrame(now)])
        if g then
            local ox, oy = (now * 7) % S.GRAIN_JITTER, (now * 13) % S.GRAIN_JITTER
            el:drawTextureTiled(g, x - ox, y - oy, w + ox, h + oy, 1, 1, 1, l.grain)
        end
    end
    local v = tex(T.vignette)
    if v and l.vignette > 0 then el:drawTextureScaled(v, x, y, w, h, l.vignette, l.vr, l.vg, l.vb) end
    local ln = tex(T.lines)
    if ln and l.lines > 0 then
        local jump = (now * 31) % (h * 0.25) -- as linhas pulam de lugar a cada quadro
        el:drawTextureScaled(ln, x, y - jump, w, h * 1.25, l.lines, 0.85, 0.85, 0.85)
    end
    local f = tex(T.white)
    if f and l.flash > 0 then el:drawTextureScaled(f, x, y, w, h, l.flash, 0.6, 0.02, 0.02) end
end

local function updateStatic()
    local p = getSpecificPlayer(0)
    local v = 0
    if p and not p:isDead() and NOM_FogState.on and NOM_Config.get("SemRostoEnabled") then
        v = NOM_SemRostoRules.staticVolume(NOM_SemRosto.nearest(p))
    end
    S.state.static = v
end

-- O pulso: o grito mais perto ganha; um mais fraco no meio do pulso não o corta.
NOM_Carpideira.onScream(function(z)
    local p = getSpecificPlayer(0)
    if not p or p:isDead() then return end
    local dx, dy = p:getX() - z:getX(), p:getY() - z:getY()
    local k = R.screamStrength(math.sqrt(dx * dx + dy * dy))
    if k <= 0 then return end
    local now = getTimestampMs()
    if k >= R.flash(now, S.state.flashAt, S.state.flashStrength) then
        S.state.flashAt, S.state.flashStrength = now, k
    end
end)

local function remove()
    if S.ui then S.ui:removeFromUIManager() end
    S.ui = nil
end

-- A classe nasce no OnGameStart: o ISUIElement vanilla já carregou.
local function create()
    local UI = ISUIElement:derive("NOM_ScreenFxUI")
    function UI:render() draw(self) end
    function UI:onMouseDown() return false end
    function UI:onMouseUp() return false end
    function UI:onRightMouseDown() return false end
    function UI:onRightMouseUp() return false end
    function UI:onMouseMove() return false end
    function UI:onMouseWheel() return false end
    local o = ISUIElement.new(UI, 0, 0, 1, 1)
    o:instantiate()
    o.javaObject:setConsumeMouseEvents(false)
    o:backMost()
    return o
end

Events.OnGameStart.Add(function()
    remove()
    S.reset()
    S.ui = create()
    S.ui:addToUIManager()
    if getDebug() then print("[NOM] tela: overlay criado (shader=" .. tostring(NOM_ShaderMod == true) .. ")") end
end)

Events.OnMainMenuEnter.Add(remove)

local ticks = 0
Events.OnTick.Add(function()
    ticks = ticks + 1
    if ticks < S.UPDATE_TICKS then return end
    ticks = 0
    updateStatic()
end)

return NOM_ScreenFx
