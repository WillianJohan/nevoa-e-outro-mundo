-- shared/NOM_AtmosphereRules.modMusicAllowed (hotfix música × névoa, 2026-10-11)
require "NOM_AtmosphereRules"
local A = NOM_AtmosphereRules

return {
    mod_music_off_when_fog_open = function()
        assert(A.modMusicAllowed(false) == true, "subida/calma: chamados e soluço podem existir")
        assert(A.modMusicAllowed(true) == false, "névoa aberta: sem música do mod")
        assert(A.modMusicAllowed(nil) == true)
    end,
}
