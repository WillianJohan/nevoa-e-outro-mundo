-- Regras puras da atmosfera da névoa (som e vinheta): sem API do jogo,
-- testável com ./run-tests.sh.
NOM_AtmosphereRules = {}

-- Anda de cur até target em fadeMs de tempo real (fade linear, preso no alvo).
function NOM_AtmosphereRules.approach(cur, target, dtMs, fadeMs)
    local step = dtMs / fadeMs
    if cur < target then return math.min(target, cur + step) end
    return math.max(target, cur - step)
end

-- Alvos do SearchMode na intensidade 1 (o spike usou valores parecidos no probe).
-- blur/desat/darkness vão de 0 a 1 no shader; radius e gradient em tiles.
local BASE = { blur = 0.15, desat = 0.35, darkness = 0.55 }
local RADIUS, GRADIENT = 7, 4

function NOM_AtmosphereRules.vignette(intensity)
    local i = math.max(0, math.min(2, intensity or 1))
    local out = { radius = RADIUS, gradient = GRADIENT }
    for k, v in pairs(BASE) do out[k] = math.min(1, v * i) end
    return out
end

return NOM_AtmosphereRules
