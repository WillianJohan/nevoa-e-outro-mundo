-- Knobs de intervalo (hotfix gritos-gap): shared/NOM_ScreamGaps.lua
require "NOM_ScreamGaps"

local G = NOM_ScreamGaps

return {
    scream_gaps_monster_uniform = function()
        G.setMonster(45000, 180000)
        assert(G.monsterGapMs(0) == 45000)
        assert(G.monsterGapMs(1) == 180000)
    end,

    scream_gaps_ambient_roll = function()
        G.setAmbient(198000, 500000)
        assert(G.ambientGapMs(0) == 198000)
        assert(G.ambientGapMs(G.ambientRollSpan() - 1) == 500000)
    end,
}
