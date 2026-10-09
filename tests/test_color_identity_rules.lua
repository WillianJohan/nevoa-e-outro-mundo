-- Identidade por cor da névoa (sprint 0049): puro, sem API do jogo.
require "NOM_ColorIdentityRules"

local R = NOM_ColorIdentityRules

return {
    color_identity_mood = function()
        assert(R.mood(false, false) == "white")
        assert(R.mood(true, false) == "red")
        assert(R.mood(false, true) == "black")
        assert(R.mood(true, true) == "black", "preta ganha da vermelha")
    end,
    color_identity_wander_only_white = function()
        assert(R.wanderAllowed("white") == true)
        assert(R.wanderAllowed("red") == false)
        assert(R.wanderAllowed("black") == false)
        assert(R.wanderAllowed(nil) == false)
    end,
    color_identity_can_wander_kind = function()
        assert(R.canWanderKind(nil, "white") == true, "comum na branca")
        assert(R.canWanderKind("estalador", "white") == true, "Estalador na branca")
        assert(R.canWanderKind("corredor", "white") == false)
        assert(R.canWanderKind("semrosto", "white") == false)
        assert(R.canWanderKind("carpideira", "white") == false)
        assert(R.canWanderKind("ticao", "white") == false)
        assert(R.canWanderKind("estalador", "red") == false)
        assert(R.canWanderKind(nil, "red") == false)
        assert(R.canWanderKind(nil, "black") == false)
    end,
    color_identity_scream_cooldown = function()
        assert(R.SCREAM_WHITE == 0.5)
        assert(R.SCREAM_RED < R.SCREAM_WHITE)
        assert(R.SCREAM_RED > 0)
        assert(R.screamCooldownHours("white") == R.SCREAM_WHITE)
        assert(R.screamCooldownHours("red") == R.SCREAM_RED)
        assert(R.screamCooldownHours("black") == R.SCREAM_WHITE, "preta não tem Corredor; default branco")
        assert(R.screamCooldownHours(nil) == R.SCREAM_WHITE)
    end,
    color_identity_estalador_speed_red = function()
        assert(R.estaladorSpeed("red") == 2)
        assert(R.estaladorSpeed("white") == nil)
        assert(R.estaladorSpeed("black") == nil)
        assert(R.estaladorSpeed(nil) == nil)
    end,
}
