-- Spike Arrasto / Rastejante (sprint 0059, refinamento §3.5): regras puras.
require "NOM_ArrastoRules"
local A = NOM_ArrastoRules

return {
    arrasto_only_red_or_black = function()
        assert(A.enabled("red") == true)
        assert(A.enabled("black") == true)
        assert(A.enabled("white") == false)
        assert(A.enabled(nil) == false)
        assert(A.enabled("purple") == false)
    end,

    arrasto_always_crawler = function()
        assert(A.alwaysCrawler() == true)
    end,

    arrasto_speed_is_slow_shambler = function()
        -- doZombieSpeed degrau 3 = shambler lento (almas / ADR velocidade)
        assert(A.speedDeg() == 3)
    end,

    arrasto_attack_close = function()
        assert(A.ATTACK_RANGE == 2)
        assert(A.inAttackRange(1.5) == true)
        assert(A.inAttackRange(2.0) == true)
        assert(A.inAttackRange(2.1) == false)
    end,

    arrasto_sounds_are_drag_not_scream = function()
        assert(A.SOUND_LOOP == "NOM_ArrastoDrag")
        assert(A.SOUND_ATTACK == "NOM_ArrastoLunge")
        assert(A.SOUND_LOOP ~= "NOM_CorredorScream")
    end,

    arrasto_mark_and_is = function()
        local md = {}
        A.mark(md)
        assert(md.NOM_arrasto == true)
        assert(A.isArrasto(md) == true)
        assert(A.isArrasto({}) == false)
        assert(A.isArrasto(nil) == false)
        A.clear(md)
        assert(md.NOM_arrasto == nil)
    end,
}
