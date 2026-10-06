-- Regras puras do evento de névoa (sprint 0009, ADR-009): sem API do jogo,
-- testável com ./run-tests.sh. Quem usa é o server/NOM_FogEvent.lua.
--
-- state = { night = número do período, inNight = evento aberto,
--           next = hora de mundo da próxima sirene, endAt = hora de mundo do fim,
--           red = névoa vermelha (sprint 0010), decidida na sirene e limpa no fim,
--           bornAt = hora de mundo do nascimento do save pra curva (sprint 0019),
--           seed = semente do mundo (sorteio determinístico, sprint 0033),
--           day = último dia de jogo planejado, hadFog = teve névoa neste dia,
--           daysWithout = dias seguidos sem névoa, wantSecond = segunda no mesmo dia,
--           lastEnd = hora de fim da última névoa, calmUntil = fim da calmaria }
-- salvo no ModData global (data.fog). night/inNight são as chaves da sprint 0005
-- (névoa natural): saves antigos continuam com o mesmo número de período.
require "NOM_VariantRules"
NOM_FogEventRules = {}
local R = NOM_FogEventRules

-- Fuga (sprint 0034): da sirene até os bichos, em ms reais. A névoa visual sobe nesse tempo
-- (NOM_World.rising); o som da sirene dura 15 s e não conta aqui.
R.GRACE_MS = 30000
-- Presságio (sprint 0034): a estática na tela começa 3 s reais antes da sirene. Só em memória.
R.PRESAGE_MS = 3000
R.MAX_STEP_MS = 1000  -- um frame nunca desconta mais que isto (travada, volta da pausa)
R.DENSITY = 0.85      -- névoa do evento cheia (canal FLOAT_FOG_INTENSITY, 0..1)

-- Dias de jogo desde o bornAt (sprint 0019): contam a subida da chance do dia
-- (R.dayChance) e a carência da vermelha. Save veterano nasce NEUTRAL_DAYS atrás (R.born):
-- a carência, até 60 dias no sandbox, já passou se for menor que 30, e a chance do dia
-- começa no meio da subida (75% com o padrão, 65 → 85 em 60 dias).
R.NEUTRAL_DAYS = 30

-- Sais do sorteio do dia: cada um é um sorteio independente do mesmo dia.
R.DAY_SALT = 15485863
R.HOUR_SALT = 32452843
R.SECOND_SALT = 49979687
R.SECOND_HOUR_SALT = 67867967
R.DIR_SALT = 86028121

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

function R.config(get)
    return { dailyChance = get("FogDailyChance"), maxDailyChance = get("FogMaxDailyChance"),
        escalationDays = get("FogEscalationDays"), escalation = get("FogEscalation"),
        secondChance = get("FogSecondChance"), minGapHours = get("FogMinGapHours"),
        maxDaysWithout = get("FogMaxDaysWithout"), minHours = get("FogMinHours"), maxHours = get("FogMaxHours"),
        redMinHours = get("RedFogMinHours"), redMaxHours = get("RedFogMaxHours"),
        redGraceDays = get("RedFogGraceDays"), calmHours = get("FogCalmHours") }
end

-- Grava o bornAt uma vez. Save novo nasce agora; save veterano (já tem agenda: night ou
-- next, sem bornAt) nasce NEUTRAL_DAYS atrás, pra não sentir a curva (review da 0019).
-- bornAt no futuro (relógio voltou, save editado) vira agora.
function R.born(state, now)
    if state.bornAt == nil then
        state.bornAt = (state.night ~= nil or state.next ~= nil) and now - R.NEUTRAL_DAYS * 24 or now
    end
    if state.bornAt > now then state.bornAt = now end
end

function R.days(state, now)
    return math.max(0, now - (state.bornAt or now)) / 24
end

function R.dayOf(hours) return math.floor(hours / 24) end

-- Sorteio em [0, 1) do dia (ou período) n com a semente do mundo; sal separa sorteios.
function R.frac(seed, n, salt)
    return NOM_VariantRules.hash(seed or 0, n, salt) / NOM_VariantRules.Q
end

-- Chance (%) do dia d de save: com a curva, sobe em linha reta da chance do sandbox
-- até o teto no dia escalationDays e fica lá.
function R.dayChance(cfg, d)
    local base = cfg.dailyChance or 0
    if not cfg.escalation then return base end
    local days = cfg.escalationDays or 0
    local t = days > 0 and clamp(d / days, 0, 1) or 1
    return base + ((cfg.maxDailyChance or base) - base) * t
end

-- Hora de mundo da primeira névoa do dia D. Se já passou (save carregado no meio
-- do dia), vai pra parte do dia que sobra, na mesma proporção.
function R.firstStart(seed, D, now)
    local dayStart = D * 24
    local h = R.frac(seed, D, R.HOUR_SALT) * 24
    local start = dayStart + h
    if start < now then start = now + h / 24 * (dayStart + 24 - now) end
    return start
end

-- Nenhuma névoa começa antes de minGapHours depois do fim da anterior (a folga).
local function afterGap(state, t, cfg)
    if state.lastEnd == nil then return t end
    return math.max(t, state.lastEnd + (cfg.minGapHours or 0))
end

-- Planeja o dia D uma vez: conta os dias sem névoa, sorteia se tem névoa (a garantia
-- força) e se vai querer segunda. Sirene pendente que cai até o fim do dia (empurrada da
-- véspera pela folga, vencida, ou de save antigo) vale pelo dia: sem sorteio novo. A de
-- save antigo marcada pra depois do dia sai: o dia sorteia, e a garantia conta.
function R.planDay(state, D, now, cfg)
    if state.day ~= nil then
        local missed = math.max(0, D - state.day - 1)
        if state.hadFog then
            state.daysWithout = missed
        else
            state.daysWithout = (state.daysWithout or 0) + 1 + missed
        end
    else
        state.daysWithout = state.daysWithout or 0
    end
    state.day, state.hadFog, state.wantSecond = D, false, false
    if state.next ~= nil and state.next < (D + 1) * 24 then return end
    state.next = nil
    local forced = state.daysWithout >= (cfg.maxDaysWithout or 2)
    if not forced and R.frac(state.seed, D, R.DAY_SALT) * 100 >= R.dayChance(cfg, R.days(state, now)) then return end
    state.next = afterGap(state, R.firstStart(state.seed, D, now), cfg)
    state.wantSecond = R.frac(state.seed, D, R.SECOND_SALT) * 100 < (cfg.secondChance or 0)
end

-- Duração uniforme entre min e max; min > max no sandbox troca os dois.
function R.durationHours(a, b, r)
    local lo, hi = math.min(a, b), math.max(a, b)
    return lo + (hi - lo) * r
end

-- Uma vez por minuto de jogo. "siren" enquanto for hora e o evento não começou,
-- "end" na borda do fim, nil no resto. Estado aberto sem endAt é save da 0008: fecha.
function R.update(state, now, cfg, rand)
    if state.inNight and state.endAt == nil then state.inNight = false end
    if state.inNight then
        if now < state.endAt then return nil end
        R.stop(state, now, cfg)
        if R.dayOf(now) ~= state.day then R.planDay(state, R.dayOf(now), now, cfg) end
        return "end"
    end
    local D = R.dayOf(now)
    if state.day ~= D then R.planDay(state, D, now, cfg) end
    if state.next ~= nil and now >= state.next then return "siren" end
    return nil
end

-- Abre o evento com a duração do tipo. red: o que a sirene decidiu.
function R.start(state, now, cfg, rand, red)
    if state.inNight then return false end
    state.night = (state.night or 0) + 1
    state.inNight, state.red, state.hadFog = true, red == true, true
    local lo, hi = cfg.minHours, cfg.maxHours
    if state.red then lo, hi = cfg.redMinHours, cfg.redMaxHours end
    state.endAt = now + R.durationHours(lo, hi, rand())
    state.next, state.calmUntil = nil, nil
    return true
end

-- Fecha o evento: calmaria, folga e, se o dia quis e couber, a segunda névoa
-- (começa antes da meia-noite, depois de minGapHours).
function R.stop(state, now, cfg)
    state.inNight, state.endAt, state.red = false, nil, nil
    state.lastEnd = now
    state.calmUntil = now + (cfg.calmHours or 0)
    if state.next ~= nil then state.next = afterGap(state, state.next, cfg) end
    if state.next == nil and state.wantSecond and state.day == R.dayOf(now) then
        local from, to = now + (cfg.minGapHours or 0), (state.day + 1) * 24
        if from < to then state.next = from + R.frac(state.seed, state.day, R.SECOND_HOUR_SALT) * (to - from) end
    end
    state.wantSecond = false
end

-- Sirene cancelada (debug): a pendente sai, o dia não ganha outra, e a cor que ela
-- tinha decidido some (a próxima sorteia de novo).
function R.cancel(state)
    state.next, state.red = nil, nil
end

function R.calm(state, now)
    return not state.inNight and state.calmUntil ~= nil and now < state.calmUntil
end

-- Vermelha: 0 na carência, a chance do sandbox depois. A curva é só da chance do dia.
function R.redChance(chance, cfg, d)
    if d < (cfg.redGraceDays or 0) then return 0 end
    return chance
end

-- De onde a sirene "vem" no período: graus em [0, 360), igual em toda máquina.
function R.sirenDir(seed, period)
    return R.frac(seed, period, R.DIR_SALT) * 360
end

-- Contagem regressiva da sirene em ms reais: parada com o jogo pausado, e um
-- frame conta no máximo MAX_STEP_MS (relógio que volta conta 0).
function R.countdown(remaining, dt, paused)
    if paused then return remaining end
    return remaining - math.min(math.max(dt, 0), R.MAX_STEP_MS)
end

return R
