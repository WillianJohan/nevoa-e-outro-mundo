-- Relógio global entre gritos audíveis (Corredor, Carpideira/Screamer, ambiente).
-- Puro: ModData do servidor + espelho local no cliente (ambiente não passa pelo servidor).
require "NOM_ScreamGaps"

NOM_ScreamGateRules = {
    -- Espelho no cliente: atualizado ao tocar ambiente, ao receber carpideiraScream
    -- ou screamGateSync do servidor.
    clientNextAt = nil,
}

local R = NOM_ScreamGateRules
local G = NOM_ScreamGaps

function R.gate(data)
    if data == nil then data = {} end
    local g = data.screamGate
    if g == nil then
        local legacy = data.carpideira and data.carpideira.nextAt
        g = { nextAt = legacy }
        data.screamGate = g
    end
    return g
end

function R.readyAt(nextAt, nowMs)
    if nextAt == nil then return true end
    return (tonumber(nowMs) or 0) >= nextAt
end

function R.ready(gate, nowMs)
    if gate == nil then return true end
    return R.readyAt(gate.nextAt, nowMs)
end

function R.readyClient(nowMs)
    return R.readyAt(R.clientNextAt, nowMs)
end

-- Se livre, agenda nextAt e devolve gap aplicado; senão nil.
function R.claim(gate, nowMs, u)
    if not R.ready(gate, nowMs) then return nil end
    local gap = G.monsterGapMs(u)
    gate.nextAt = (tonumber(nowMs) or 0) + gap
    return gap
end

function R.claimClient(nowMs, u)
    if not R.readyClient(nowMs) then return nil end
    local gap = G.monsterGapMs(u)
    R.clientNextAt = (tonumber(nowMs) or 0) + gap
    return gap
end

function R.syncClient(nextAt)
    if nextAt == nil then return end
    nextAt = tonumber(nextAt)
    if nextAt == nil then return end
    if R.clientNextAt == nil or nextAt > R.clientNextAt then
        R.clientNextAt = nextAt
    end
end

-- kind: corredor | carpideira | ambient (Screamer = carpideira). extra opcional: source, sound, dist, why.
function R.logPlayed(kind, gapMs, nextAt, extra)
    extra = type(extra) == "table" and extra or {}
    local source = extra.source
    if source == nil then
        source = (kind == "ambient") and "ambient" or "monster"
    end
    local line = "[NOM] scream played kind=" .. tostring(kind)
        .. " source=" .. source
        .. " gap=" .. tostring(gapMs) .. "ms next=" .. tostring(nextAt)
    if extra.sound then line = line .. " sound=" .. tostring(extra.sound) end
    if extra.dist then line = line .. " dist=" .. tostring(extra.dist) end
    if extra.why then line = line .. " why=" .. tostring(extra.why) end
    print(line)
end

function R.logBlocked(kind, reason, detail)
    if getDebug == nil or not getDebug() then return end
    local line = "[NOM] scream blocked kind=" .. tostring(kind) .. " reason=" .. tostring(reason)
    if detail ~= nil then line = line .. " " .. tostring(detail) end
    print(line)
end

return NOM_ScreamGateRules
