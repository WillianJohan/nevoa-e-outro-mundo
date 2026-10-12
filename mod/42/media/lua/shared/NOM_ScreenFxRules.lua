-- Regras puras dos efeitos de tela (sprint 0013): quanto de cada camada se vê,
-- pelo estado da névoa, do Sem-rosto e do último grito de Carpideira. Sem API do
-- jogo, testável com ./run-tests.sh. Quem desenha é o client/NOM_ScreenFx.lua; o
-- canal pro shader opcional (mod NoiseOfMist_Shader) sai de R.channel.
require "NOM_AtmosphereRules"
require "NOM_Math"
require "NOM_Rules"
require "NOM_FogEventRules"
require "NOM_FogClimaxRules"

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
    -- Tontura (sprint 0035), na revelação ao vivo do Outro Mundo: sobe em DIZZY_RISE_MS, segura
    -- DIZZY_HOLD_MS e desce até DIZZY_MS reais. Sem o shader, a vinheta pulsa (DIZZY_VIGNETTE,
    -- um ciclo a cada DIZZY_PULSE_MS) e a tela escurece (DIZZY_DARK); com ele, o canal.
    DIZZY_MS = 5000,
    DIZZY_RISE_MS = 600,
    DIZZY_HOLD_MS = 1400,
    DIZZY_PULSE_MS = 1100,
    DIZZY_VIGNETTE = 0.35,
    DIZZY_DARK = 0.18,
    -- No canal a tontura vai na parte inteira do darkness (VarInfo.y): pulso (0..2) +
    -- DIZZY_BASE · round(tontura · DIZZY_STEPS). Iguais aos NOM_DIZZY_* do screen.frag.
    DIZZY_BASE = 4,
    DIZZY_STEPS = 256,
    -- Sprint 0052: vinheta que respira perto do soluço da Carpideira (ZB-free, §3.2/§3.3).
    SOB_NEAR = 3,
    SOB_FAR = 12,
    SOB_VIGNETTE = 0.22,
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
-- sob: proximidade do soluço da Carpideira (0..1, sprint 0052).
-- fogStatic/staticKind: estática da névoa (R.stepStatic); staticFadeAt/From: o fade do fim.
function R.new()
    return { fog = 0, red = 0, static = 0, sob = 0, flashAt = nil, flashStrength = 0, fogStatic = 0, staticKind = "white" }
end

-- Força da vinheta pelo soluço perto (nil / longe = 0). Mesma curva do volume do soluço.
function R.sobStrength(d)
    if d == nil or d >= R.SOB_FAR then return 0 end
    if d <= R.SOB_NEAR then return 1 end
    return (R.SOB_FAR - d) / (R.SOB_FAR - R.SOB_NEAR)
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

-- Estática da preta (sprint 0038): cinza-escura; a cor da névoa preta (quase preta) sumiria na tela.
R.BLACK_STATIC = { 0.28, 0.28, 0.3 }

-- RGB da estática pelo tipo da névoa (o alfa da cor do clima não entra). Ponto único.
function R.staticColor(kind)
    if kind == "black" then return R.BLACK_STATIC[1], R.BLACK_STATIC[2], R.BLACK_STATIC[3] end
    local c = kind == "red" and NOM_Rules.RED_FOG_COLOR or NOM_Rules.FOG_COLOR
    return c[1], c[2], c[3]
end

-- want = { fog = bool, red = bool, black = bool }: aproxima fog, red e black dos alvos em FADE_MS.
function R.step(s, want, dtMs)
    local A = NOM_AtmosphereRules
    s.fog = A.approach(s.fog, want.fog and 1 or 0, dtMs, R.FADE_MS)
    s.red = A.approach(s.red, (want.fog and want.red) and 1 or 0, dtMs, R.FADE_MS)
    s.black = A.approach(s.black or 0, (want.fog and want.black) and 1 or 0, dtMs, R.FADE_MS)
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

local function smooth(t)
    return t * t * (3 - 2 * t)
end

-- Tontura (0..1) t ms depois da revelação ao vivo; nil ou fora da janela: 0.
function R.dizzy(t)
    if t == nil or t <= 0 or t >= R.DIZZY_MS then return 0 end
    if t < R.DIZZY_RISE_MS then return smooth(t / R.DIZZY_RISE_MS) end
    local fall = R.DIZZY_RISE_MS + R.DIZZY_HOLD_MS
    if t <= fall then return 1 end
    return 1 - smooth((t - fall) / (R.DIZZY_MS - fall))
end

-- A tontura pela intensidade dos efeitos (0..2): reduz, nunca passa da curva.
function R.dizzyLevel(t, i)
    return R.dizzy(t) * clamp(i or 1, 0, 1)
end

-- Alfas das camadas (0..1), a cor da vinheta (preta; vermelha escura na vermelha; na preta, maior
-- e sem vermelho, sprint 0038) e a da
-- estática da névoa (sr, sg, sb). i: intensidade da opção do jogador (0..2). dz: tontura
-- (R.dizzyLevel, 0 com o shader, que a faz no canal): a vinheta pulsa e a tela escurece.
function R.layers(s, now, i, dz)
    i = clamp(i or 1, 0, 2)
    dz = clamp(dz or 0, 0, 1)
    local f, r, b = s.fog, s.red, s.black or 0
    local sr, sg, sb = R.staticColor(s.staticKind)
    local pulse = 0.5 - 0.5 * math.cos(2 * math.pi * NOM_Math.mod(now, R.DIZZY_PULSE_MS) / R.DIZZY_PULSE_MS)
    -- fallback sem mod3 (sprint 0047): vinheta da base mais fraca; com bolsões ligados, pulso
    -- raro mais forte (não dá pra amostrar o campo espacial sem o volume)
    local vigBase = 0.42
    if f > 0 and NOM_FogClimaxRules then
        local look = NOM_FogClimaxRules.fromConfig()
        vigBase = look.fallbackBaseVignette
        if look.pocketCoverage > 0 then
            local slow = 0.5 - 0.5 * math.cos(2 * math.pi * NOM_Math.mod(now, 90000) / 90000)
            vigBase = vigBase + (look.fallbackPocketVignette - look.fallbackBaseVignette) * slow * slow
        end
    end
    local sob = clamp(s.sob or 0, 0, 1)
    local sobVig = sob * R.SOB_VIGNETTE * i * (0.7 + 0.3 * breath(now))
    -- 0060c/d: look limpo (flag de debug) — zera tudo pra isolar o ItemVisual.
    if R.lookClean() then
        return {
            grain = 0, vignette = 0, vr = 0, vg = 0, vb = 0,
            lines = 0, flash = 0, fogStatic = 0,
            sr = sr, sg = sg, sb = sb, dark = 0, edgeLines = false,
        }
    end
    -- I6: GlitchMode (off/original/bordas) + GlitchIntensity (0..200%). LookForce suaviza.
    local force = R.lookForceOn()
    local mode = R.glitchMode()
    local gI = R.glitchIntensity()
    local soft = force and 0.4 or 1
    local vMul = force and 0.45 or 1
    local fMul = force and 0.35 or 1
    local sMul = (force and 0.12 or 1) * gI
    local linesBase = 0
    local edgeLines = false
    if mode == "original" then
        linesBase = clamp(s.static * f * 0.2 * i * soft * gI, 0, 1)
    elseif mode == "bordas" then
        linesBase = clamp(s.static * f * 0.2 * i * 0.4 * soft * gI, 0, 1)
        edgeLines = linesBase > 0
    end
    -- off: grain/vinheta da #16 (mais baixos); original/bordas: staging (mais altos)
    local grainK = (mode == "off") and (0.05 + 0.03 * r + 0.03 * b) or (0.09 + 0.05 * r + 0.04 * b)
    return {
        grain = clamp(f * grainK * i * soft, 0, 1),
        vignette = clamp(f * (vigBase + 0.16 * breath(now)) * (1 + 0.45 * r + 0.8 * b) * i * vMul
            + dz * R.DIZZY_VIGNETTE * pulse * (force and 0.35 or 1) + sobVig * (force and 0.35 or 1), 0, 1),
        vr = 0.42 * r * (1 - b) * (force and 0.65 or 1), vg = 0, vb = 0,
        lines = linesBase,
        edgeLines = edgeLines,
        flash = clamp(R.flash(now, s.flashAt, s.flashStrength) * 0.45 * i * fMul, 0, 1),
        fogStatic = clamp((s.fogStatic or 0) * i * sMul, 0, 1),
        sr = sr, sg = sg, sb = sb,
        dark = dz * R.DIZZY_DARK * (force and 0.4 or 1),
    }
end

-- Isolamento debug (NOM.lookClean): não confundir com LookForce do painel.
function R.setLookClean(on)
    R._lookClean = on == true
end

function R.lookClean()
    return R._lookClean == true
end

-- LookForce ≠ Auto (horror forçado no painel).
function R.lookForceOn()
    if not NOM_PanelParams or not NOM_PanelParams.lookForce then return false end
    local lf = NOM_PanelParams.lookForce()
    return lf ~= nil and lf ~= ""
end

-- I6: modo do seletor "Glitch de tela" (padrão original até o Johan decidir).
function R.glitchMode()
    if NOM_PanelParams and NOM_PanelParams.glitchMode then
        return NOM_PanelParams.glitchMode()
    end
    return "original"
end

-- Multiplicador 0..2 do slider de intensidade.
function R.glitchIntensity()
    if NOM_PanelParams and NOM_PanelParams.glitchIntensity then
        return NOM_PanelParams.glitchIntensity()
    end
    return 1
end

-- Tag no gradiente (ParamInfo) pra o screen.frag saber que é modo bordas.
-- bloom fica em MARKER..MARKER+0,5; bordas soma BORDAS_TAG (2).
R.BORDAS_TAG = 2

function R.visible(l)
    return l.grain > 0 or l.vignette > 0 or l.lines > 0 or l.flash > 0 or l.fogStatic > 0 or l.dark > 0
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
-- dz (sprint 0035): a tontura (R.dizzyLevel), na parte inteira do darkness; o pulso fica no
-- resto, preso em 2 (o shader prende igual), longe de DIZZY_BASE. Não depende de i (o sandbox).
function R.channel(s, now, i, bloom, dz)
    -- 0060c: look limpo solta o canal (fog/hiss/red/pulse → tear/aberração no screen.frag)
    if R.lookClean() then
        return { blur = 0, radius = 0, desat = 0, darkness = 0, gradient = 0 }
    end
    i = clamp(i or 1, 0, 2)
    local force = R.lookForceOn()
    local mode = R.glitchMode()
    local gI = R.glitchIntensity()
    local soft = force and 0.4 or 1
    -- radius → SearchMode.y → hiss no screen.frag (tear). off=0; original=staging; bordas=reduzido.
    local radius = 0
    if mode == "original" then
        radius = s.static * s.fog * i * soft * gI
    elseif mode == "bordas" then
        radius = s.static * s.fog * i * 0.35 * soft * gI
    end
    local pulse = clamp(R.flash(now, s.flashAt, s.flashStrength) * i * (force and 0.12 or 1), 0, 2)
    local bloomV = clamp(bloom or 0, 0, 2) * (force and 0.35 or 1)
    local grad = R.MARKER + bloomV * R.BLOOM_SCALE
    if mode == "bordas" then grad = grad + R.BORDAS_TAG end
    return {
        blur = s.fog * i * soft,
        radius = clamp(radius, 0, 2),
        desat = s.red * i * (force and 0.3 or 1),
        darkness = pulse + R.DIZZY_BASE * math.floor(clamp(dz or 0, 0, 1) * R.DIZZY_STEPS + 0.5),
        gradient = grad,
    }
end

return NOM_ScreenFxRules
