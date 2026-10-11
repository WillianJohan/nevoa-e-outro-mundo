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

function R.logPlayed(kind, gapMs, nextAt)
    print("[NOM] scream played kind=" .. tostring(kind)
        .. " gap=" .. tostring(gapMs) .. "ms next=" .. tostring(nextAt))
end

return NOM_ScreamGateRules
