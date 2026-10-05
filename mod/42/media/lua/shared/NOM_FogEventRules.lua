-- Regras puras do evento de névoa (sprint 0009, ADR-009): sem API do jogo,
-- testável com ./run-tests.sh. Quem usa é o server/NOM_FogEvent.lua.
--
-- state = { night = número do período, inNight = evento aberto,
--           next = hora de mundo da próxima sirene, endAt = hora de mundo do fim,
--           red = névoa vermelha (sprint 0010), decidida na sirene e limpa no fim,
--           bornAt = hora de mundo do nascimento do save pra curva (sprint 0019) }
-- salvo no ModData global (data.fog). night/inNight são as chaves da sprint 0005
-- (névoa natural): saves antigos continuam com o mesmo número de período.
NOM_FogEventRules = {}
local R = NOM_FogEventRules

R.SIREN_MS = 30000    -- a sirene toca 30 s reais antes da névoa
R.MAX_STEP_MS = 1000  -- um frame nunca desconta mais que isto (travada, volta da pausa)
R.DENSITY = 0.85      -- névoa do evento cheia (canal FLOAT_FOG_INTENSITY, 0..1)

function R.config(get)
    return { everyDays = get("FogEventEveryDays"), minHours = get("FogMinHours"), maxHours = get("FogMaxHours"),
        escalation = get("FogEscalation"), redGraceDays = get("RedFogGraceDays") }
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- Curva de tensão (sprint 0019, análise do PO): dias de jogo desde o bornAt (save
-- anterior à curva ganha bornAt no primeiro uso: a curva dele começa ali).
function R.days(state, now)
    return math.max(0, now - (state.bornAt or now)) / 24
end

-- Média do intervalo no dia d: everyDays × clamp(1,5 − d/60, 0,75, 1,5). Com a base 2:
-- 3 dias no começo, 2 no dia 30, 1,5 do dia 45 em diante. Sem a escalada, o sandbox.
function R.everyDays(cfg, d)
    if not cfg.escalation then return cfg.everyDays end
    return cfg.everyDays * clamp(1.5 - d / 60, 0.75, 1.5)
end

-- Chance (0–100) de vermelha no dia d: 0 antes de redGraceDays (com ou sem a escalada);
-- depois chance × clamp(1 + (d − 30)/60, 1, 2): igual até o dia 30, o dobro do 90 em diante.
function R.redChance(chance, cfg, d)
    if d < (cfg.redGraceDays or 0) then return 0 end
    if not cfg.escalation then return chance end
    return chance * clamp(1 + (d - 30) / 60, 1, 2)
end

local function gap(state, now, cfg, rand)
    return R.gapHours(R.everyDays(cfg, R.days(state, now)), rand())
end

-- Horas até a próxima sirene, contadas do fim do evento anterior: uniforme entre
-- 0,5× e 1,5× de everyDays (média = everyDays). r em [0, 1).
function R.gapHours(everyDays, r)
    return everyDays * 24 * (0.5 + r)
end

-- Duração uniforme entre min e max; min > max no sandbox troca os dois.
function R.durationHours(a, b, r)
    local lo, hi = math.min(a, b), math.max(a, b)
    return lo + (hi - lo) * r
end

-- Uma vez por minuto de jogo. Devolve "siren" enquanto for hora de tocar a sirene
-- e o evento não começou (quem chama ignora se a contagem já corre), "end" na
-- borda do fim, nil no resto. Estado aberto sem endAt é save da sprint 0008 (névoa
-- natural): fecha sem contar período.
function R.update(state, now, cfg, rand)
    if state.inNight and state.endAt == nil then state.inNight = false end
    if state.inNight then
        if now < state.endAt then return nil end
        R.stop(state, now, cfg, rand)
        return "end"
    end
    if state.next == nil then state.next = now + gap(state, now, cfg, rand) end
    if now >= state.next then return "siren" end
    return nil
end

-- Abre o evento: período novo, fim sorteado. Evento dentro de evento não existe.
-- red: o que a sirene decidiu (névoa vermelha, sprint 0010).
function R.start(state, now, cfg, rand, red)
    if state.inNight then return false end
    state.night = (state.night or 0) + 1
    state.inNight = true
    state.red = red == true
    state.endAt = now + R.durationHours(cfg.minHours, cfg.maxHours, rand())
    state.next = nil
    return true
end

-- Fecha o evento e agenda a próxima sirene a partir de agora, com a média do dia de agora.
function R.stop(state, now, cfg, rand)
    state.inNight = false
    state.endAt = nil
    state.red = nil
    state.next = now + gap(state, now, cfg, rand)
end

-- Contagem regressiva da sirene em ms reais: parada com o jogo pausado, e um
-- frame conta no máximo MAX_STEP_MS (relógio que volta conta 0).
function R.countdown(remaining, dt, paused)
    if paused then return remaining end
    return remaining - math.min(math.max(dt, 0), R.MAX_STEP_MS)
end

return R
