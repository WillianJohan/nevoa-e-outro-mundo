-- Lógica pura: sem API do jogo, testável com ./run-tests.sh.
NOM_Rules = {}

NOM_Rules.FOG_HYSTERESIS = 0.05
NOM_Rules.FOG_EXIT_FLOOR = 0.01
NOM_Rules.CHANNELS = { "desaturation", "ambient", "fog", "tint" }

-- value = alvo da camada modded do clima; weight = quanto puxar até ele (0..1).
-- Canais escolhidos pelo que o render lê de verdade (sprint 0008, pz-api-notes §10):
-- * tint = cor E alfa da luz global (r, g, b, a). O alfa é a força da cor: a luz do
--   céu é 2 × mod × ambient, mod = 1 − alfa × (1 − cor). É o único canal com folga
--   de madrugada; a vanilla já usa alfa 0.8 (VANILLA_NIGHTS), então o que escurece é
--   a cor quase preta, com um pouco mais de azul (fria). Contra a noite vanilla, com
--   e sem lua: DarkIntensity 1 tira 46% do vermelho e 39–40% do azul; 2 tira 73–89%
--   (teste rules_night_darker_and_colder_than_vanilla).
-- * ambient: de madrugada o jogo já põe 0 (quem clareia é o piso do sandbox
--   NightDarkness, somado depois do clima); vale no anoitecer e na névoa de dia.
-- * desaturation: o render multiplica por (1 − darkness), zero à noite: só na névoa de dia.
-- * a "intensidade da luz global" saiu: o render nunca lê (só o relâmpago).
NOM_Rules.LOOKS = {
    night = {
        ambient = { value = 0, weight = 0.5 },
        tint    = { value = { 0.0, 0.03, 0.06, 0.95 }, weight = 0.55 },
    },
    fog = {
        desaturation = { value = 1, weight = 0.6 },
        ambient      = { value = 0, weight = 0.3 },
        fog          = { value = 1, weight = 0.3 },
        -- sépia bem escuro: contra as três cores vanilla de névoa (VANILLA_FOGS) a luz
        -- cai 29–46% com DarkIntensity 1, o azul mais (teste rules_fog_darker_*)
        tint         = { value = { 0.14, 0.11, 0.08, 0.95 }, weight = 0.6 },
    },
}

-- Luz global (exterior) vanilla de madrugada. O construtor do ClimateManager põe
-- 0.33/alfa 0.4 (<init> 250–323), mas o server/Climate/ClimateMain.lua:14-22 troca
-- no OnClimateManagerInit (disparado no <init>, 590, a cada carga): sem lua 0.25,
-- lua cheia 0.33, alfa 0.8; o updateValues mistura as duas pela lua (1794–1841).
NOM_Rules.VANILLA_NIGHTS = {
    noMoon = { 0.25, 0.25, 0.25, 0.8 },
    moon = { 0.33, 0.33, 0.33, 0.8 },
}

-- Luz global (exterior) vanilla na névoa cheia: o updateValues (1645–1770) puxa a
-- luz pra uma de três cores pela intensidade da névoa, conforme o shader e a
-- qualidade de névoa (colFog com fogQuality 2, colFogNew, colFogLegacy sem o
-- weather shader); o server/Climate/ClimateMain.lua:24-34 põe alfa 0.8 nas três.
NOM_Rules.VANILLA_FOGS = {
    fog = { 0.2, 0.2, 0.2, 0.8 },
    new = { 0.5, 0.5, 0.55, 0.8 },
    legacy = { 0.3, 0.3, 0.3, 0.8 },
}

-- Multiplicador da luz por canal que a cor (r, g, b, alfa) da luz global dá no
-- render: rmod = lerp(1, cor, alfa) (RenderSettings$PlayerRenderSettings 662–725;
-- à noite a dessaturação da cor é ~0). A luz do céu é clamp(2 × mod × ambient)
-- (GameTime.getSkyLightLevel 10–77). Usado no log de debug e nos testes.
function NOM_Rules.skyMod(r, g, b, a)
    return 1 - a * (1 - r), 1 - a * (1 - g), 1 - a * (1 - b)
end

function NOM_Rules.isNight(tod, dawn, dusk)
    return tod >= dusk or tod < dawn
end

function NOM_Rules.isFog(intensity, threshold, wasFog)
    if wasFog then
        return intensity >= math.max(threshold - NOM_Rules.FOG_HYSTERESIS, NOM_Rules.FOG_EXIT_FLOOR)
    end
    return intensity >= threshold
end

-- Valor absoluto que o mod escreve no clima: vanilla puxado até o alvo pelo peso.
function NOM_Rules.blend(vanilla, target, weight)
    return vanilla + (target - vanilla) * weight
end

-- Um passo por minuto de jogo (cada OnClimateTick): duration em minutos de jogo.
function NOM_Rules.ramp(current, active, duration)
    local step = 1 / duration
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
    local out = {}
    for i = 1, 4 do out[i] = (a[i] * aw + b[i] * bw) / total end
    return out
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
