-- Regras puras dos efeitos de tela (sprint 0013): quanto de cada camada se vê,
-- pelo estado da névoa, do Sem-rosto e do último grito de Carpideira. Sem API do
-- jogo, testável com ./run-tests.sh. Quem desenha é o client/NOM_ScreenFx.lua; o
-- canal pro shader opcional (mod NevoaEOutroMundo_Shader) sai de R.channel.
require "NOM_AtmosphereRules"
require "NOM_Math"
require "NOM_Rules"
require "NOM_FogEventRules"

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
    -- Sprint 0018: o bloom do jogador (0..2) vai na fração do marcador, 13 + bloom·escala
    -- (até 13,5: nunca chega no próximo inteiro). Igual ao NOM_BLOOM_SCALE do screen.frag.
    BLOOM_SCALE = 0.25,
    -- Estática da névoa (sprint 0034), alfa base antes da intensidade: o presságio sobe de
    -- START a PEAK em PRESAGE_MS (t²); da sirene, desce a SUBTLE em SETTLE_MS e fica na
    -- subida e na névoa; no fim (ou cancelada), cai a 0 em FADE_MS. A textura tem alfa médio
    -- ~0,43 e é clara sobre a névoa clara: 0,22/0,05 sumiram no jogo (teste do Johan, 2026-10-06).
    STATIC_START = 0.1,
    STATIC_PEAK = 0.6,
    STATIC_SUBTLE = 0.14,
    STATIC_SETTLE_MS = 4000,
    STATIC_FADE_MS = 3000,
    -- geradas por scripts/gen_textures.py: branco com alfa, pintadas pela cor do desenho
    TEXTURES = {
        grain = {
            "media/textures/NOM/ScreenFx/NOM_Grain1.png", "media/textures/NOM/ScreenFx/NOM_Grain2.png",
            "media/textures/NOM/ScreenFx/NOM_Grain3.png", "media/textures/NOM/ScreenFx/NOM_Grain4.png",
        },
        vignette = "media/textures/NOM/ScreenFx/NOM_Vignette.png",
        lines = "media/textures/NOM/ScreenFx/NOM_Lines.png",
        white = "media/textures/NOM/ScreenFx/NOM_White.png",
        -- chiado em tons de cinza, tingido pela cor da névoa (sprint 0034)
        static = "media/textures/NOM/ScreenFx/NOM_NevoaEstatica.png",
    },
}

local R = NOM_ScreenFxRules

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

-- static: volume do rádio do Sem-rosto (0..1); flashAt/flashStrength: último grito.
-- fogStatic/staticKind: estática da névoa (R.stepStatic); staticFadeAt/From: o fade do fim.
function R.new()
    return { fog = 0, red = 0, static = 0, flashAt = nil, flashStrength = 0, fogStatic = 0, staticKind = "white" }
end

-- Alfa base da estática da névoa (0..1), sem o fade do fim. w = { omenAt, sirenAt, visible }
-- (NOM_FogState): o pico depois da sirene só vem com presságio; quem entra na fuga ou na
-- névoa, ou o debug com skip, fica no sutil.
function R.staticLevel(w, now)
    if w.omenAt and not w.sirenAt then
        local t = clamp((now - w.omenAt) / NOM_FogEventRules.PRESAGE_MS, 0, 1)
        return R.STATIC_START + (R.STATIC_PEAK - R.STATIC_START) * t * t
    end
    if not w.visible then return 0 end
    if w.omenAt then
        local t = clamp((now - w.sirenAt) / R.STATIC_SETTLE_MS, 0, 1)
        return R.STATIC_PEAK + (R.STATIC_SUBTLE - R.STATIC_PEAK) * t
    end
    return R.STATIC_SUBTLE
end

-- Segue R.staticLevel; quando ele vai a 0, desce do nível em que estava até 0 em
-- STATIC_FADE_MS, com a cor da névoa que acabou. w.kind: "white" ou "red".
function R.stepStatic(s, w, now)
    local level = R.staticLevel(w, now)
    if level > 0 then
        s.fogStatic, s.staticKind, s.staticFadeAt = level, w.kind or "white", nil
    elseif s.fogStatic > 0 then
        if not s.staticFadeAt then s.staticFadeAt, s.staticFadeFrom = now, s.fogStatic end
        local t = (now - s.staticFadeAt) / R.STATIC_FADE_MS
        s.fogStatic = t >= 1 and 0 or s.staticFadeFrom * (1 - math.max(t, 0))
    end
    return s
end

-- RGB da estática pelo tipo da névoa (o alfa da cor do clima não entra). Ponto único: a
-- preta entra aqui na 0038.
function R.staticColor(kind)
    local c = kind == "red" and NOM_Rules.RED_FOG_COLOR or NOM_Rules.FOG_COLOR
    return c[1], c[2], c[3]
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
    return 0.5 + 0.5 * math.sin(2 * math.pi * NOM_Math.mod(now, R.BREATH_MS) / R.BREATH_MS)
end

-- Alfas das camadas (0..1), a cor da vinheta (preta; vermelha escura na vermelha) e a da
-- estática da névoa (sr, sg, sb). i: intensidade da opção do jogador (0..2).
function R.layers(s, now, i)
    i = clamp(i or 1, 0, 2)
    local f, r = s.fog, s.red
    local sr, sg, sb = R.staticColor(s.staticKind)
    return {
        grain = clamp(f * (0.09 + 0.05 * r) * i, 0, 1),
        vignette = clamp(f * (0.42 + 0.16 * breath(now)) * (1 + 0.45 * r) * i, 0, 1),
        vr = 0.42 * r, vg = 0, vb = 0,
        lines = clamp(s.static * f * 0.2 * i, 0, 1),
        flash = clamp(R.flash(now, s.flashAt, s.flashStrength) * 0.45 * i, 0, 1),
        fogStatic = clamp((s.fogStatic or 0) * i, 0, 1),
        sr = sr, sg = sg, sb = sb,
    }
end

function R.visible(l)
    return l.grain > 0 or l.vignette > 0 or l.lines > 0 or l.flash > 0 or l.fogStatic > 0
end

function R.grainFrame(now)
    -- now/60 ~ 2.9e10: o % do Kahlua saturaria o (int) e o índice sairia da tabela
    return NOM_Math.mod(math.floor(now / R.GRAIN_FRAME_MS), R.GRAIN_FRAMES) + 1
end

-- Floats do SearchMode do jogador pro shader (com override ligado e enabled
-- desligado, o jogo manda os valores todo quadro e não mexe neles, spike do shader):
-- blur → SearchMode.x = névoa, radius → SearchMode.y = chiado do Sem-rosto,
-- desat → ParamInfo.w = vermelha, darkness → VarInfo.y = pulso; 0..2 pela intensidade.
-- bloom (sprint 0018): a opção do jogador, 0..2, na fração do gradiente; não depende de i.
function R.channel(s, now, i, bloom)
    i = clamp(i or 1, 0, 2)
    return {
        blur = s.fog * i,
        radius = s.static * s.fog * i,
        desat = s.red * i,
        darkness = R.flash(now, s.flashAt, s.flashStrength) * i,
        gradient = R.MARKER + clamp(bloom or 0, 0, 2) * R.BLOOM_SCALE,
    }
end

return NOM_ScreenFxRules
