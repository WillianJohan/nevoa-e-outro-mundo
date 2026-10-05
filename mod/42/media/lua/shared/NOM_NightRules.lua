-- Regras puras da noite agressiva: sem API do jogo, testável com ./run-tests.sh.
-- Velocidade, visão e audição do zumbi são 3 degraus no jogo; 1 é o melhor
-- (corredor, águia, apurado), 3 o pior (arrastado, ruim, ruim).
NOM_NightRules = {}

NOM_NightRules.ECO_SPEED = 3 -- arrastado
NOM_NightRules.CORREDOR_SPEED = 1 -- corredor (sprinter)
-- Estalador: pior visão e melhor audição do jogo. Visão "ruim" ainda vê a 10
-- tiles (piso do updateVisionRadius): a cegueira de verdade é NOM_VariantAI.
NOM_NightRules.ESTALADOR_SIGHT = 3
NOM_NightRules.ESTALADOR_HEARING = 1
-- Teto do raio de visão do zumbi (bytecode IsoZombie.updateVisionRadius: PZMath.clamp(r, 10, 20)).
NOM_NightRules.VISION_MAX = 20

-- Multiplicador do sandbox em degraus: 1.0 → 0, 1.5 → 1, 2.5 → 2.
function NOM_NightRules.steps(mult)
    if not mult or mult < 1 then return 0 end
    return math.floor(mult - 0.5)
end

function NOM_NightRules.sharpen(tier, steps)
    return math.max(1, tier - steps)
end

-- Sandbox de sentidos: 1..3 fixo; 4 e 5 são sorteios por zumbi, a base é normal.
function NOM_NightRules.baseSense(v)
    if v >= 1 and v <= 3 then return v end
    return 2
end

-- Sandbox de velocidade: 1..3 vale pra todo zumbi; 4 (aleatório) usa a do zumbi.
function NOM_NightRules.dayTier(sandboxSpeed, current)
    if sandboxSpeed >= 1 and sandboxSpeed <= 3 then return sandboxSpeed end
    return current
end

-- Perfil que o zumbi deve ter. kind = nil (comum), "eco", "estalador",
-- "corredor" ou "carpideira" (variante só existe na névoa, de dia ou de noite: à noite ela vai por
-- cima dos stats da noite; de dia, por cima dos do jogo). cfg = { fasterOn, sensesOn, speedMult, senseMult, sight, hearing }
-- (sight/hearing = valores do sandbox). sight/hearing nil = os do sandbox.
-- key == "day" quando nada muda em relação ao jogo.
function NOM_NightRules.wanted(night, kind, dayTier, cfg)
    local R = NOM_NightRules
    if not night and (kind == nil or kind == "eco") then return { key = "day", speed = dayTier } end
    if kind == "eco" then return { key = "eco", speed = R.ECO_SPEED } end
    local w = { speed = dayTier }
    if night then
        if cfg.fasterOn then w.speed = R.sharpen(dayTier, R.steps(cfg.speedMult)) end
        local s = cfg.sensesOn and R.steps(cfg.senseMult) or 0
        if s > 0 then
            w.sight = R.sharpen(R.baseSense(cfg.sight), s)
            w.hearing = R.sharpen(R.baseSense(cfg.hearing), s)
        end
    end
    -- Variantes valem pelo próprio toggle, não pelos da noite.
    -- Carpideira (sprint 0011): corredora; calma está parada (useless), então só
    -- corre depois do grito.
    if kind == "corredor" or kind == "carpideira" then w.speed = R.CORREDOR_SPEED end
    if kind == "estalador" then
        w.sight, w.hearing = R.ESTALADOR_SIGHT, R.ESTALADOR_HEARING
    end
    local stats = w.speed .. "," .. (w.sight or 0) .. "," .. (w.hearing or 0)
    if kind then
        w.key = kind .. ":" .. stats
    elseif w.speed == dayTier and not w.sight then
        w.key = "day"
    else
        w.key = "n" .. stats
    end
    return w
end

-- Multiplicador de audição por degrau (bytecode WorldSoundManager.getHearingMultiplier(I)).
NOM_NightRules.HEARING_MULT = { 3.0, 1.0, 0.45 }

-- Raio a passar pro addSound pra o alcance efetivo ser reach. O jogo multiplica o
-- raio pela audição do zumbi (getSoundAttract); à noite com sentidos aguçados o
-- zumbi tem o degrau da noite. Sem bônus, o raio é o do jogo (vanilla).
-- cfg = { sensesOn, senseMult, hearing } (hearing = valor do sandbox).
function NOM_NightRules.soundRadius(reach, cfg)
    local R = NOM_NightRules
    local s = cfg.sensesOn and R.steps(cfg.senseMult) or 0
    if s == 0 then return reach end
    local mult = R.HEARING_MULT[R.sharpen(R.baseSense(cfg.hearing), s)]
    return math.max(1, math.floor(reach / mult + 0.5))
end

function NOM_NightRules.torchRadius(senseMult)
    return math.floor(NOM_NightRules.VISION_MAX * senseMult)
end

-- Um passo por minuto de jogo; due quando completa o intervalo (caça, lanterna).
function NOM_NightRules.countdown(minutes, interval)
    minutes = minutes + 1
    if minutes >= interval then return 0, true end
    return minutes, false
end

return NOM_NightRules
