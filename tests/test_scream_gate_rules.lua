-- Relógio global de gritos (hotfix gritos-gap): shared/NOM_ScreamGateRules.lua
require "NOM_ScreamGaps"
require "NOM_ScreamGateRules"

local SG = NOM_ScreamGateRules
local G = NOM_ScreamGaps

return {
    scream_gate_claim_blocks_second = function()
        G.setMonster(45000, 180000)
        local data = {}
        local gap1 = SG.claim(SG.gate(data), 1000, 0)
        assert(gap1 == 45000)
        assert(SG.claim(SG.gate(data), 1000 + 1000, 0) == nil, "grito dentro do gap")
        assert(SG.claim(SG.gate(data), 1000 + gap1, 0) == 45000)
    end,

    scream_gate_migrates_legacy_carpideira_next = function()
        local data = { carpideira = { period = 1, pids = {}, nextAt = 99999 } }
        assert(SG.gate(data).nextAt == 99999)
    end,

    scream_gate_client_sync_takes_max = function()
        SG.clientNextAt = 5000
        SG.syncClient(4000)
        assert(SG.clientNextAt == 5000)
        SG.syncClient(8000)
        assert(SG.clientNextAt == 8000)
    end,

    scream_gate_corredor_shares_carpideira_clock = function()
        G.setMonster(10000, 10000)
        local data = {}
        SG.claim(SG.gate(data), 0, 0)
        assert(SG.claim(SG.gate(data), 5000, 0) == nil, "corredor bloqueado pelo grito da carpideira")
        G.setMonster(45000, 180000)
    end,
}
