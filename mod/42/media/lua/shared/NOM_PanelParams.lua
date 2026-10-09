-- Knobs live do NOM.panel (sprint 0058): overrides de sessão pra Almas / Estalador /
-- Cinzas / Look. Sem API do jogo. Os sistemas (0054–0057) leem via get()/helpers;
-- a UI e NOM.param escrevem via set(). Contrato: internal/panel-parametros-contrato.md
-- (store do projeto) e docs/sprints/sprint-0058-panel-parametros/.
NOM_PanelParams = {}
local P = NOM_PanelParams

-- Burst A = espelho da 0048 (NOM_SonarRules.BEAT_MS). B/C = produto 0056.
P.RHYTHMS = {
    A = { 0, 90, 165, 250, 320, 410, 490, 600, 720, 880, 1100, 1400 },
    B = { 0, 500, 1000, 1800 },
    C = { 0, 1000, 2000, 2060, 4060, 7060 },
}

P.LOOK_ARCHETYPES = { "", "pale", "misaligned", "patient", "wrong", "silhouette" }

P.DEFAULTS = {
    AlmaPopMin = 4,
    AlmaPopMax = 20,
    AlmaCrawlerPct = 68,
    AlmaFogWhite = true,
    AlmaFogRed = true,
    AlmaFogBlack = true,
    EstaladorRhythm = "rotate",
    EstaladorGapMinMs = 5000,
    EstaladorGapMaxMs = 30000,
    CinzaRateMult = 1.0,
    CinzaDensityMult = 1.0,
    LookForce = "",
}

-- type: int | float | bool | enum
P.SCHEMA = {
    AlmaPopMin = { type = "int", min = 0, max = 40, step = 1, section = "almas" },
    AlmaPopMax = { type = "int", min = 1, max = 40, step = 1, section = "almas" },
    AlmaCrawlerPct = { type = "int", min = 0, max = 100, step = 1, section = "almas" },
    AlmaFogWhite = { type = "bool", section = "almas" },
    AlmaFogRed = { type = "bool", section = "almas" },
    AlmaFogBlack = { type = "bool", section = "almas" },
    EstaladorRhythm = { type = "enum", values = { "A", "B", "C", "rotate" }, section = "estalador" },
    EstaladorGapMinMs = { type = "int", min = 500, max = 120000, step = 100, section = "estalador" },
    EstaladorGapMaxMs = { type = "int", min = 500, max = 120000, step = 100, section = "estalador" },
    CinzaRateMult = { type = "float", min = 0, max = 3, step = 0.1, section = "cinzas" },
    CinzaDensityMult = { type = "float", min = 0, max = 3, step = 0.1, section = "cinzas" },
    LookForce = { type = "enum", values = P.LOOK_ARCHETYPES, section = "look" },
}

local live = {}

-- Ordem estável pro snapshot / dump do console (sem depender de pairs).
P.KEYS = {
    "AlmaPopMin", "AlmaPopMax", "AlmaCrawlerPct",
    "AlmaFogWhite", "AlmaFogRed", "AlmaFogBlack",
    "EstaladorRhythm", "EstaladorGapMinMs", "EstaladorGapMaxMs",
    "CinzaRateMult", "CinzaDensityMult", "LookForce",
}

local function inList(list, v)
    for i = 1, #list do
        if list[i] == v then return true end
    end
    return false
end

local function roundStep(v, step)
    if not step or step <= 0 then return v end
    return math.floor(v / step + 0.5) * step
end

function P.get(key)
    if live[key] ~= nil then return live[key] end
    return P.DEFAULTS[key]
end

function P.isLive(key)
    return live[key] ~= nil
end

function P.set(key, value)
    local sch = P.SCHEMA[key]
    if not sch then return P.get(key) end
    local t = sch.type
    if t == "bool" then
        live[key] = value and true or false
    elseif t == "enum" then
        if inList(sch.values, value) then
            live[key] = value
        else
            live[key] = P.DEFAULTS[key]
        end
    elseif t == "int" then
        local n = math.floor(tonumber(value) or P.DEFAULTS[key])
        if sch.step and sch.step > 1 then
            n = math.floor(roundStep(n, sch.step) + 0.5)
        end
        if n < sch.min then n = sch.min end
        if n > sch.max then n = sch.max end
        live[key] = n
        if key == "AlmaPopMin" and n > P.get("AlmaPopMax") then
            live[key] = P.get("AlmaPopMax")
        elseif key == "AlmaPopMax" and n < P.get("AlmaPopMin") then
            live[key] = P.get("AlmaPopMin")
        elseif key == "EstaladorGapMinMs" and n > P.get("EstaladorGapMaxMs") then
            live[key] = P.get("EstaladorGapMaxMs")
        elseif key == "EstaladorGapMaxMs" and n < P.get("EstaladorGapMinMs") then
            live[key] = P.get("EstaladorGapMinMs")
        end
    elseif t == "float" then
        local n = tonumber(value) or P.DEFAULTS[key]
        n = roundStep(n, sch.step)
        -- evita 1.2000000001 em float
        n = math.floor(n * 1000 + 0.5) / 1000
        if n < sch.min then n = sch.min end
        if n > sch.max then n = sch.max end
        live[key] = n
    end
    return live[key]
end

function P.reset(key)
    if key == nil then
        live = {}
        return
    end
    live[key] = nil
end

function P.snapshot()
    local out = {}
    for i = 1, #P.KEYS do
        local k = P.KEYS[i]
        out[k] = P.get(k)
    end
    return out
end

function P.format(key, value)
    local sch = P.SCHEMA[key]
    if value == nil then value = P.get(key) end
    if not sch then return tostring(value) end
    if sch.type == "bool" then return value and "on" or "off" end
    if key == "AlmaCrawlerPct" then return tostring(value) .. "%" end
    if key == "CinzaRateMult" or key == "CinzaDensityMult" then
        return string.format("%.1f", value) .. "×"
    end
    if key == "EstaladorGapMinMs" or key == "EstaladorGapMaxMs" then
        return tostring(value) .. " ms"
    end
    if value == "" then return "auto" end
    return tostring(value)
end

function P.almaCrawlerChance()
    return P.get("AlmaCrawlerPct") / 100
end

function P.estaladorBeats(rhythm)
    if rhythm == nil then rhythm = P.get("EstaladorRhythm") end
    if rhythm == "rotate" then return nil end
    return P.RHYTHMS[rhythm]
end

function P.cinzaRate(baseRate)
    return (tonumber(baseRate) or 0) * P.get("CinzaRateMult")
end

function P.cinzaDensity(base)
    return (tonumber(base) or 0) * P.get("CinzaDensityMult")
end

function P.lookForce()
    return P.get("LookForce")
end

return NOM_PanelParams
