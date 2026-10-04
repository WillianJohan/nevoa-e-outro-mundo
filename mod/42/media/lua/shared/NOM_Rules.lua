-- Lógica pura: sem API do jogo, testável com ./run-tests.sh.
NOM_Rules = {}

NOM_Rules.FOG_HYSTERESIS = 0.05
NOM_Rules.FOG_EXIT_FLOOR = 0.01
NOM_Rules.CHANNELS = { "desaturation", "light", "fog", "tint" }

-- value = alvo da camada modded do clima; weight = quanto puxar até ele (0..1).
NOM_Rules.LOOKS = {
    night = {
        desaturation = { value = 1, weight = 0.25 },
        light        = { value = 0, weight = 0.25 },
        tint         = { value = { 0.55, 0.65, 0.95 }, weight = 0.3 },
    },
    fog = {
        desaturation = { value = 1, weight = 0.6 },
        light        = { value = 0, weight = 0.15 },
        fog          = { value = 1, weight = 0.3 },
        tint         = { value = { 0.75, 0.68, 0.55 }, weight = 0.4 },
    },
}

function NOM_Rules.isNight(tod, dawn, dusk)
    return tod >= dusk or tod < dawn
end

function NOM_Rules.isFog(intensity, threshold, wasFog)
    if wasFog then
        return intensity >= math.max(threshold - NOM_Rules.FOG_HYSTERESIS, NOM_Rules.FOG_EXIT_FLOOR)
    end
    return intensity >= threshold
end

-- O jogo devolve lerp(weight, vanilla, modded). Desfaz pra ler só o clima vanilla,
-- senão a névoa que o mod adiciona realimenta a própria detecção de névoa.
function NOM_Rules.unmix(final, modded, weight)
    if weight <= 0 or weight >= 1 then
        return final
    end
    return (final - weight * modded) / (1 - weight)
end

function NOM_Rules.ramp(current, active, dt, duration)
    dt = math.max(0, math.min(1, dt))
    local step = dt / duration
    if active then
        return math.min(1, current + step)
    end
    return math.max(0, current - step)
end

local function blendColor(a, aw, b, bw)
    local total = aw + bw
    if total <= 0 then
        return a or b
    end
    a, b = a or b, b or a
    return {
        (a[1] * aw + b[1] * bw) / total,
        (a[2] * aw + b[2] * bw) / total,
        (a[3] * aw + b[3] * bw) / total,
    }
end

function NOM_Rules.mix(nightRamp, fogRamp, intensity)
    local out = {}
    for _, ch in ipairs(NOM_Rules.CHANNELS) do
        local n = NOM_Rules.LOOKS.night[ch]
        local f = NOM_Rules.LOOKS.fog[ch]
        local nw = n and n.weight * nightRamp or 0
        local fw = f and f.weight * fogRamp or 0
        local value
        if ch == "tint" then
            -- cor misturada por peso: trocar de azul pra sépia de uma vez dá pulo visível
            value = blendColor(n and n.value, nw, f and f.value, fw)
        else
            local pick = (fw > nw) and f or n
            value = pick and pick.value
        end
        out[ch] = {
            value = value,
            weight = math.min(1, math.max(nw, fw) * intensity),
        }
    end
    return out
end

return NOM_Rules
