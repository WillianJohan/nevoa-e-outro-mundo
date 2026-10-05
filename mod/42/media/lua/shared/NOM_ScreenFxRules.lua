-- Regras puras dos efeitos de tela (sprint 0013): quanto de cada camada se vê,
-- pelo estado da névoa, do Sem-rosto e do último grito de Carpideira. Sem API do
-- jogo, testável com ./run-tests.sh. Quem desenha é o client/NOM_ScreenFx.lua; o
-- canal pro shader opcional (mod NevoaEOutroMundo_Shader) sai de R.channel.
require "NOM_AtmosphereRules"

NOM_ScreenFxRules = {
    FADE_MS = 4000,        -- tempo real do nada à névoa cheia na tela (e de volta)
    FLASH_MS = 900,        -- pulso do grito, do pico ao zero
    FLASH_NEAR = 6,        -- grito a até 6 tiles: pulso cheio
    FLASH_FAR = 30,        -- a partir de 30 tiles: nada
    BREATH_MS = 7000,      -- um ciclo da vinheta respirando
    GRAIN_FRAMES = 4,      -- media/textures/NOM/ScreenFx/NOM_Grain1..4.png
    GRAIN_FRAME_MS = 60,
    -- Gradiente do SearchMode que diz ao shader "estes floats são do mod" (o jogo
    -- manda gradient·tile/2 em ParamInfo.z e tile em ParamInfo.y; o vanilla usa
    -- raios de poucos tiles). Igual ao NOM_MARKER do screen.frag do mod2.
    MARKER = 13,
    -- geradas por scripts/gen_textures.py: branco com alfa, pintadas pela cor do desenho
    TEXTURES = {
        grain = {
            "media/textures/NOM/ScreenFx/NOM_Grain1.png", "media/textures/NOM/ScreenFx/NOM_Grain2.png",
            "media/textures/NOM/ScreenFx/NOM_Grain3.png", "media/textures/NOM/ScreenFx/NOM_Grain4.png",
        },
        vignette = "media/textures/NOM/ScreenFx/NOM_Vignette.png",
        lines = "media/textures/NOM/ScreenFx/NOM_Lines.png",
        white = "media/textures/NOM/ScreenFx/NOM_White.png",
    },
}

local R = NOM_ScreenFxRules

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

-- static: volume do rádio do Sem-rosto (0..1); flashAt/flashStrength: último grito.
function R.new()
    return { fog = 0, red = 0, static = 0, flashAt = nil, flashStrength = 0 }
end

-- want = { fog = bool, red = bool }: aproxima fog e red dos alvos em FADE_MS.
function R.step(s, want, dtMs)
    local A = NOM_AtmosphereRules
    s.fog = A.approach(s.fog, want.fog and 1 or 0, dtMs, R.FADE_MS)
    s.red = A.approach(s.red, (want.fog and want.red) and 1 or 0, dtMs, R.FADE_MS)
    return s
end

-- Força do pulso pela distância do grito (nil = longe demais ou sem jogador).
function R.screamStrength(d)
    if d == nil or d >= R.FLASH_FAR then return 0 end
    if d <= R.FLASH_NEAR then return 1 end
    return (R.FLASH_FAR - d) / (R.FLASH_FAR - R.FLASH_NEAR)
end

-- Cai do pico ao zero em FLASH_MS, mais rápido no começo (quadrático).
function R.flash(now, at, strength)
    if at == nil or now < at then return 0 end
    local t = (now - at) / R.FLASH_MS
    if t >= 1 then return 0 end
    return (strength or 0) * (1 - t) * (1 - t)
end

local function breath(now)
    return 0.5 + 0.5 * math.sin(2 * math.pi * (now % R.BREATH_MS) / R.BREATH_MS)
end

-- Alfas das camadas (0..1) e a cor da vinheta (preta; vermelha escura na vermelha).
-- i: intensidade da opção do jogador (0..2).
function R.layers(s, now, i)
    i = clamp(i or 1, 0, 2)
    local f, r = s.fog, s.red
    return {
        grain = clamp(f * (0.09 + 0.05 * r) * i, 0, 1),
        vignette = clamp(f * (0.42 + 0.16 * breath(now)) * (1 + 0.45 * r) * i, 0, 1),
        vr = 0.42 * r, vg = 0, vb = 0,
        lines = clamp(s.static * f * 0.35 * i, 0, 1),
        flash = clamp(R.flash(now, s.flashAt, s.flashStrength) * 0.45 * i, 0, 1),
    }
end

function R.visible(l)
    return l.grain > 0 or l.vignette > 0 or l.lines > 0 or l.flash > 0
end

function R.grainFrame(now)
    return math.floor(now / R.GRAIN_FRAME_MS) % R.GRAIN_FRAMES + 1
end

-- Floats do SearchMode do jogador pro shader (com override ligado e enabled
-- desligado, o jogo manda os valores todo quadro e não mexe neles, spike do shader):
-- blur → SearchMode.x = névoa, radius → SearchMode.y = chiado do Sem-rosto,
-- desat → ParamInfo.w = vermelha, darkness → VarInfo.y = pulso; 0..2 pela intensidade.
function R.channel(s, now, i)
    i = clamp(i or 1, 0, 2)
    return {
        blur = s.fog * i,
        radius = s.static * s.fog * i,
        desat = s.red * i,
        darkness = R.flash(now, s.flashAt, s.flashStrength) * i,
        gradient = R.MARKER,
    }
end

return NOM_ScreenFxRules
