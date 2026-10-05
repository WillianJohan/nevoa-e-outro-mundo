-- Dissolve (sprint 0018, ADR-016), só no jogo de quem vê (solo e cliente de MP): dirige
-- o Alpha do zumbi a cada quadro enquanto um efeito dura. O shader das peças do mod
-- (media/shaders/NOM_Dissolve.frag, nas peças *Fx por <m_Shader>) lê esse Alpha como o
-- limiar do ruído; o tempo e a faixa vêm do shared/NOM_DissolveRules.lua.
--
-- Por que o OnTick (bytecode B42.21, spike-dissolve §C):
-- * IsoObject.setAlpha(IF)/getAlpha(I) são por jogador local e saem no servidor;
-- * o mundo anda o alfa pro alvo da visão (IsoObject.updateAlpha(IFF), no update do
--   mundo; IsoGameCharacter.isUpdateAlphaDuringRender = false) e o OnTick vem depois
--   (IngameState.updateInternal 1067 → 1331), antes do render (ModelSlotRenderData.init
--   lê getAlpha(pn)): o valor escrito aqui é o do quadro desenhado.
-- * Escreve min(efeito, alfa do jogo): quem não está à vista (alvo 0) continua sumindo,
--   o efeito nunca revela um zumbi. No fim solta, e o jogo volta a mandar.
if isServer() then return end

require "NOM_DissolveRules"
require "NOM_ScreenFxOptions"

NOM_Dissolve = {}

local D = NOM_Dissolve
local R = NOM_DissolveRules
-- [zumbi] = { e = efeito das regras, done = função(z) no fim, ou nil }
local active = {}
local count = 0

function D.enabled()
    return NOM_ScreenFxOptions.dissolve()
end

-- Começa (ou troca, partindo do limiar atual) o efeito do zumbi. false: desligado ou
-- no teto, e quem chama faz a troca instantânea.
function D.run(z, mode, done)
    if not D.enabled() then return false end
    local now = getTimestampMs()
    local old = active[z]
    if not old and count >= R.CAP then return false end
    if not old then count = count + 1 end
    active[z] = { e = R.start(mode, now, old and R.threshold(old.e, now) or nil), done = done }
    return true
end

-- Tira o efeito sem chamar o fim (o alfa fica onde estava e o jogo o leva de volta).
function D.stop(z)
    if active[z] then
        active[z] = nil
        count = count - 1
    end
end

function D.busy(z)
    return active[z] ~= nil
end

function D.count()
    return count
end

-- true = acabou (ou o zumbi saiu do mundo).
local function apply(z, a, players, now)
    if not z:getCurrentSquare() then return true end
    local alpha, done = R.step(a.e, now)
    -- morte: morto e ainda no square (animação longa), o teto não solta; soltar traria o
    -- Eco de volta. Sai quando deixa o square (o corpo nasceu), na linha de cima.
    if done and a.e.mode == "death" and z:isDead() then done = false end
    for pn = 0, players - 1 do
        z:setAlpha(pn, math.min(alpha, z:getAlpha(pn)))
    end
    return done
end

Events.OnTick.Add(function()
    if count == 0 then return end
    local now = getTimestampMs()
    local players = getNumActivePlayers()
    local finished = {}
    for z, a in pairs(active) do
        local ok, done = pcall(apply, z, a, players, now)
        if not ok then
            print("[NOM] dissolve: erro: " .. tostring(done))
            finished[#finished + 1] = { z = z }
        elseif done then
            finished[#finished + 1] = { z = z, done = a.done }
        end
    end
    -- fora do laço: o fim pode mexer na tabela (o strip do visual chama stop)
    for _, f in ipairs(finished) do
        D.stop(f.z)
        if f.done then
            local ok, err = pcall(f.done, f.z)
            if not ok then print("[NOM] dissolve: erro no fim: " .. tostring(err)) end
        end
    end
end)

-- Objeto reaproveitado (resetForReuse → OnZombieCreate): é outro zumbi.
Events.OnZombieCreate.Add(D.stop)
Events.OnMainMenuEnter.Add(function()
    active = {}
    count = 0
end)

return NOM_Dissolve
